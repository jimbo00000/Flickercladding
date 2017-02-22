--[[ iir_effect.lua

]]
iir_effect = {}

iir_effect.__index = iir_effect

function iir_effect.new(...)
    local self = setmetatable({}, iir_effect)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function iir_effect:init()
    self.vbos = {}
    self.vao = 0
    self.fbos = {}
    self.pingpong = 1
    self.lastSwapTime = 0
    self.firstTime = true
    self.mix_coeff = 0.95
    self.prog_mix = 0
    self.prog_pres = 0
end

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glUintv  = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local src_vert = [[
#version 300 es

in vec4 vPosition;
in vec4 vColor;
out vec2 uv;

void main()
{
    uv = .5 * (vPosition.xy + vec2(1.)); // map [-1,1] to [0,1]
    gl_Position = vec4(vPosition.xy, 0., 1.);
}
]]

local mix_frag = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec2 uv;
out vec4 fragColor;
uniform sampler2D tex1;
uniform sampler2D tex2;
uniform float u_coeff;

void main()
{
    vec4 col1 = texture(tex1, uv);
    vec4 col2 = texture(tex2, uv);
    fragColor = mix(col1, col2, u_coeff);
}
]]

local pres_frag = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec2 uv;
out vec4 fragColor;
uniform sampler2D tex1;

void main()
{
    vec4 col1 = texture(tex1, uv);
    fragColor = col1;
}
]]

function iir_effect:init_quad_attributes()
    local verts = glFloatv(4*2, {
        -1,-1,
        1,-1,
        1,1,
        -1,1,
        })

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    table.insert(self.vbos, vvbo)
end

function iir_effect:initGL(w,h)
    self.vbos = {}
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog_mix = sf.make_shader_from_source({
        vsrc = src_vert,
        fsrc = mix_frag,
        })
    self.prog_pres = sf.make_shader_from_source({
        vsrc = src_vert,
        fsrc = pres_frag,
        })

    self:init_quad_attributes()

    -- Re-use the VBO for each program
    local vpos_loc = gl.glGetAttribLocation(self.prog_mix, "vPosition")
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glEnableVertexAttribArray(vpos_loc)

    local vpos_loc = gl.glGetAttribLocation(self.prog_pres, "vPosition")
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glEnableVertexAttribArray(vpos_loc)

    self:resize_fbo(w,h)
    gl.glBindVertexArray(0)
end

function iir_effect:exitGL()
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog_mix)
    gl.glDeleteProgram(self.prog_pres)

    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)

    for _,v in pairs(self.fbos) do
        if v then fbf.deallocate_fbo(v) end
    end
end

function iir_effect:resize_fbo(w,h)
    for _,v in pairs(self.fbos) do
        if v then fbf.deallocate_fbo(v) end
    end
    for i=1,3 do
        self.fbos[i] = fbf.allocate_fbo(w,h,true)
    end

    self:clear_fbos()
end

-- Mix the two given textures into the front buffer
function iir_effect:mix_textures(texId1, texId2, mix)
    local fron = self:getfrontfbo()
    fbf.bind_fbo(fron)
    do
        gl.glUseProgram(self.prog_mix)

        gl.glActiveTexture(GL.GL_TEXTURE0)
        gl.glBindTexture(GL.GL_TEXTURE_2D, texId1)
        local tx_loc1 = gl.glGetUniformLocation(self.prog_mix, "tex1")
        gl.glUniform1i(tx_loc1, 0)
        
        gl.glActiveTexture(GL.GL_TEXTURE1)
        gl.glBindTexture(GL.GL_TEXTURE_2D, texId2)
        local tx_loc2 = gl.glGetUniformLocation(self.prog_mix, "tex2")
        gl.glUniform1i(tx_loc2, 1)

        local mc_loc = gl.glGetUniformLocation(self.prog_mix, "u_coeff")
        gl.glUniform1f(mc_loc, mix)

        gl.glBindVertexArray(self.vao)
        gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
        gl.glBindVertexArray(0)

        gl.glUseProgram(0)
    end
    fbf.unbind_fbo()
end

function iir_effect:bind_fbo()
    local f = self.fbos[3]
    if f then fbf.bind_fbo(f) end
end

function iir_effect:unbind_fbo()
    fbf.unbind_fbo()
end

function iir_effect:clear_fbos()
    for _,v in pairs(self.fbos) do
        fbf.bind_fbo(v)
        gl.glClearColor(0,0,0,0)
        gl.glClear(GL.GL_COLOR_BUFFER_BIT + GL.GL_DEPTH_BUFFER_BIT)
        fbf.unbind_fbo()
    end
end

function iir_effect:present()
    -- First, mix new and old images into front buffer
    local f = self.fbos[3]
    local f2 = self:getbackfbo()

    local mix = self.mix_coeff
    if self.firstTime == true then
        -- Buffers are cleared to black, this prevents a
        -- leading black frame when switching on the effect.
        self.firstTime = false
        mix = 0.0
    end
    self:mix_textures(f.tex, f2.tex, mix)
    
    -- Then, Present front buffer
    local fron = self:getfrontfbo()
    gl.glUseProgram(self.prog_pres)

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, fron.tex)
    local tx_loc1 = gl.glGetUniformLocation(self.prog_pres, "tex1")
    gl.glUniform1i(tx_loc1, 0)

    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function iir_effect:getfrontfbo()
    return self.fbos[self.pingpong]
end

function iir_effect:getbackfbo()
    local other = 3 - self.pingpong
    return self.fbos[other]
end

-- Swap buffers
function iir_effect:swap()
    self.pingpong = self.pingpong + 1
    if self.pingpong > 2 then
        self.pingpong = 1
    end
end

function iir_effect:timestep(absTime, dt)
    self.time = absTime
    if absTime - self.lastSwapTime > 1/60 then
        self:swap()
        self.lastSwapTime = absTime
    end
end

return iir_effect
