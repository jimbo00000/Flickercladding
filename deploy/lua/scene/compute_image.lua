-- compute_image.lua
--

compute_image = {}
compute_image.__index = compute_image

function compute_image.new(...)
    local self = setmetatable({}, compute_image)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function compute_image:init()
    self.vao = 0
    self.vbos = {}
    self.prog = 0

    self.texs = {}
    self.rule = 30
end

function compute_image:setDataDirectory(dir)
    self.data_dir = dir
end

local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")
require("util.glfont")
local glFloatv = ffi.typeof('GLfloat[?]')

local basic_vert = [[
#version 310 es

in vec4 vPosition;
in vec4 vColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

out vec3 vfColor;

void main()
{
    vfColor = vColor.xyz;
    gl_Position = prmtx * mvmtx * vPosition;
}
]]

local basic_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec3 vfColor;
out vec4 fragColor;

uniform sampler2D sTex;
uniform float texOff;

void main()
{
    vec2 tc = vfColor.xy;
    tc.y = 1.-tc.y;
    tc.y = fract(tc.y + texOff);
    vec4 col = texture(sTex, tc);
    fragColor = vec4(col.xyz, 1.);
}
]]


local combined_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
precision mediump sampler2D;
#endif

in vec3 vfColor;
out vec4 fragColor;

uniform sampler2D sTex0;
uniform sampler2D sTex1;
uniform sampler2D sTex2;
uniform sampler2D sTex3;
uniform float texOff;

void main()
{
    vec2 tc = vfColor.xy;
    tc.y = 1.-tc.y;
    tc.y = fract(tc.y + texOff);
    tc.x *= 3.;

    vec4 col = vec4(.5);

    col += .125*texture(sTex0, tc);
    col += .125*texture(sTex1, tc);
    col += .125*texture(sTex2, tc);
    col += .125*texture(sTex3, tc);

    fragColor = vec4(col.xyz, 1.);
}
]]



local img_init = [[
#version 310 es
precision mediump int;
precision mediump float;
precision mediump image2D;

layout(local_size_x = 1, local_size_y = 1) in;
layout(rgba8, binding = 0) uniform image2D img_output;

uniform int uFillType;

float hash( float n ) { return fract(sin(n)*43758.5453); }

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(43.232, 75.876)))*4526.3257);   
}

void main() {
    vec4 pixel = vec4(0.0);
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

    if (uFillType == 0)
    {
        // Init image to checkerboard
        if (((pixel_coords.x & 1) == 0)
         != ((pixel_coords.y & 1) == 0))
        {
            pixel = vec4(1.);
        }

        if (pixel_coords.x < 5)
            pixel = vec4(1.);
    }
    else if (uFillType == 1)
    {
        // Random init
        vec2 coord = vec2(
            float(pixel_coords.x)/float(imageSize(img_output).x),
            float(pixel_coords.y)/float(imageSize(img_output).y));
        float hval = hash(coord);
        pixel = hval > .5 ? vec4(1.) : vec4(0.);
    }
    else if (uFillType == 2)
    {
        // Single black pixel in center init
        pixel = vec4(1.);
        if (pixel_coords.x == imageSize(img_output).x/2)
            pixel = vec4(0.);
    }

    imageStore(img_output, pixel_coords, pixel);
}
]]

local img_comp = [[
#version 310 es

precision mediump int;
precision mediump float;
precision mediump image2D;

layout(local_size_x = 1, local_size_y = 1) in;
layout(rgba8, binding = 0) uniform image2D img_output;

uniform int uRow;
uniform int uRule;

void main() {
    vec4 pixel = vec4(0.0);

    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    pixel_coords.y += uRow;

    int prevRow = uRow - 1;
    if (prevRow < 0) prevRow += imageSize(img_output).y;

    int Leftx = pixel_coords.x - 1;
    if (Leftx < 0) Leftx += imageSize(img_output).x;
    int Rightx = pixel_coords.x + 1;
    Rightx %= imageSize(img_output).x;

    vec4 lval = imageLoad(img_output, ivec2(Leftx, prevRow));
    vec4 cval = imageLoad(img_output, ivec2(pixel_coords.x, prevRow));
    vec4 rval = imageLoad(img_output, ivec2(Rightx, prevRow));

    bool lbit = (lval.r > .5);
    bool cbit = (cval.r > .5);
    bool rbit = (rval.r > .5);
    int combined = 0;
    if (lbit) combined |= 1;
    if (cbit) combined |= 2;
    if (rbit) combined |= 4;

    int flag = 1 << combined;
    if ((uRule & flag) != 0)
    {
        pixel = vec4(1.);
    }

    //if (pixel_coords.y == uRow)
    imageStore(img_output, pixel_coords, pixel);
}
]]

function compute_image:initTriAttributes()
    local glIntv = ffi.typeof('GLint[?]')
    local glUintv = ffi.typeof('GLuint[?]')

    local verts = glFloatv(4*3, {
        0,0,0,
        1,0,0,
        1,1,0,
        0,1,0,
    })

    local vpos_loc = gl.glGetAttribLocation(self.prog, "vPosition")
    local vcol_loc = gl.glGetAttribLocation(self.prog, "vColor")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, vvbo)

    local cvbo = glIntv(0)
    gl.glGenBuffers(1, cvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)
end

function compute_image:initTextureImage(w, h)
    gl.glActiveTexture(GL.GL_TEXTURE0)
    local dtxId = ffi.new("GLuint[1]")
    gl.glGenTextures(1, dtxId)
    local texID = dtxId[0]
    gl.glBindTexture(GL.GL_TEXTURE_2D, texID)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_S, GL.GL_REPEAT)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_T, GL.GL_REPEAT)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_NEAREST)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_NEAREST)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAX_LEVEL, 0)
    gl.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_RGBA,
                  w, h, 0,
                  GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, nil)
    gl.glBindTexture(GL.GL_TEXTURE_2D, 0)
    gl.glBindImageTexture(0, texID, 0, GL.GL_FALSE, 0, GL.GL_WRITE_ONLY, GL.GL_RGBA8)

    return texID
end

function compute_image:initializeTextures()
    local octaves = 4
    local d = 16*2
    for i=1,octaves do
        local texID = self:initTextureImage(d,d)
        table.insert(self.texs, {texID, d, d, 0})
        d = d * 2
    end
end

function compute_image:clearTextures(condition)
    for _,v in pairs(self.texs) do
        local tex = v
        local texID = tex[1]
        local w,h = tex[2], tex[3]
        local row = tex[4]

        gl.glBindImageTexture(0, texID, 0, GL.GL_FALSE, 0, GL.GL_WRITE_ONLY, GL.GL_RGBA8)
        gl.glUseProgram(self.prog_init)

        local sfill_loc = gl.glGetUniformLocation(self.prog_init, "uFillType")
        gl.glUniform1i(sfill_loc, condition)

        gl.glDispatchCompute(w, h, 1)
        gl.glMemoryBarrier(GL.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT)
    end
end

function compute_image:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    self.prog_combined = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = combined_frag,
        })

    self.prog_comp = sf.make_shader_from_source({
        compsrc = img_comp,
        })

    self.prog_init = sf.make_shader_from_source({
        compsrc = img_init,
        })

    self:initTriAttributes()
    self:initializeTextures(0)
    self:clearTextures(0)

    gl.glBindVertexArray(0)

    dir = "fonts"
    if self.data_dir then dir = self.data_dir .. "/" .. dir end
    self.glfont = GLFont.new('segoe_ui128.fnt', 'segoe_ui128_0.raw')
    self.glfont:setDataDirectory(dir)
    self.glfont:initGL()
end

function compute_image:calculateRows(n)
    print('rows',self.prog_comp,n)
    local base = self.texs[1][2]

    for _,v in pairs(self.texs) do
        local tex = v
        local w,h = tex[2], tex[3]
        local row = tex[4]

        gl.glBindImageTexture(0, tex[1], 0, GL.GL_FALSE, 0, GL.GL_WRITE_ONLY, GL.GL_RGBA8)

        gl.glUseProgram(self.prog_comp)
        local srule_loc = gl.glGetUniformLocation(self.prog_comp, "uRule")
        gl.glUniform1i(srule_loc, self.rule)

        local srow_loc = gl.glGetUniformLocation(self.prog_comp, "uRow")

        local numrows = n * (w/base)
        for i=1,numrows do
            gl.glUniform1i(srow_loc, row)
            gl.glDispatchCompute(w, 1, 1)
            gl.glMemoryBarrier(GL.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT)
            row = row + 1
            if row >= h then row = 0 end
        end
        gl.glUseProgram(0)

        v[4] = row
    end
end

function compute_image:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
    gl.glBindVertexArray(0)

    self.glfont:exitGL()
end

function compute_image:render_for_one_eye(view, proj)
    local initialview = {}
    for i=1,16 do initialview[i] = view[i] end
    mm.glh_translate(view, -3,0,-.5)

    gl.glUseProgram(self.prog)
    local umv_loc = gl.glGetUniformLocation(self.prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog, "prmtx")
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))

    gl.glBindVertexArray(self.vao)

    for _,v in pairs(self.texs) do
        local tex = v
        local texID = tex[1]
        local w,h = tex[2], tex[3]
        local row = tex[4]

        gl.glActiveTexture(GL.GL_TEXTURE0)
        gl.glBindTexture(GL.GL_TEXTURE_2D, texID)
        local stex_loc = gl.glGetUniformLocation(self.prog, "sTex")
        gl.glUniform1i(stex_loc, 0)

        local to_loc = gl.glGetUniformLocation(self.prog, "texOff")
        gl.glUniform1f(to_loc, row/h)

        gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))
        gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)

        mm.glh_translate(view, 1.1,0,0)
    end

    gl.glBindVertexArray(0)
    gl.glUseProgram(0)


    -- Draw the combined texture
    gl.glUseProgram(self.prog_combined)
    local umv_loc = gl.glGetUniformLocation(self.prog_combined, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog_combined, "prmtx")
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))

    gl.glBindVertexArray(self.vao)

        local tex = self.texs[1]
        local texID = tex[1]
        local w,h = tex[2], tex[3]
        local row = tex[4]

        mm.glh_translate(view, -4.6,-2.1,0)
        mm.glh_scale(view,3*2,2,2)

        gl.glActiveTexture(GL.GL_TEXTURE0)
        gl.glBindTexture(GL.GL_TEXTURE_2D, self.texs[1][1])
        local stex_loc0 = gl.glGetUniformLocation(self.prog_combined, "sTex0")
        gl.glUniform1i(stex_loc0, 0)

        gl.glActiveTexture(GL.GL_TEXTURE1)
        gl.glBindTexture(GL.GL_TEXTURE_2D, self.texs[2][1])
        local stex_loc1 = gl.glGetUniformLocation(self.prog_combined, "sTex1")
        gl.glUniform1i(stex_loc1, 1)

        gl.glActiveTexture(GL.GL_TEXTURE2)
        gl.glBindTexture(GL.GL_TEXTURE_2D, self.texs[3][1])
        local stex_loc2 = gl.glGetUniformLocation(self.prog_combined, "sTex2")
        gl.glUniform1i(stex_loc2, 2)

        gl.glActiveTexture(GL.GL_TEXTURE3)
        gl.glBindTexture(GL.GL_TEXTURE_2D, self.texs[4][1])
        local stex_loc3 = gl.glGetUniformLocation(self.prog_combined, "sTex3")
        gl.glUniform1i(stex_loc3, 3)

        local to_loc = gl.glGetUniformLocation(self.prog_combined, "texOff")
        gl.glUniform1f(to_loc, row/h)

        gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))
        gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)

    gl.glUseProgram(0)


    -- Text in scene
    local col = {1, 1, 1}
    local m = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
    local s = .002
    mm.glh_translate(m, -1, 1.3, -.5)
    mm.glh_scale(m, s, -s, s)
    mm.pre_multiply(m, initialview)
    self.glfont:render_string(m, proj, col, "Rule "..tostring(self.rule))
end

function compute_image:timestep(absTime, dt)
    --self:calculateRows(16)
end

function compute_image:keypressed(ch)
    if ch == string.byte('-') then
        self.rule = self.rule - 1
        return
    elseif ch == string.byte('=') then
        self.rule = self.rule + 1
        return
    end
    --89, 101

    local ruleidx = ch - 49
    local rules = {
        [0] = 30,
        [1] = 105,
        [2] = 106,
        [3] = 126,
        [4] = 150,
        [5] = 184,
        [6] = 41,
        [7] = 45,
        [8] = 110,
    }
    local r = rules[ruleidx]
    if r then self.rule = r return end

    local initials = {
        [string.byte('Z')] = 0,
        [string.byte('X')] = 1,
        [string.byte('C')] = 2,
    }
    local initc = initials[ch]
    if initc then self:clearTextures(initc) return end

    self:calculateRows(1)
end

function compute_image:onSingleTouch(pointerid, action, x, y)
    --print("compute_image.onSingleTouch",pointerid, action, x, y)
end

return compute_image
