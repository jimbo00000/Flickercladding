-- iir_effect.lua
iir_effect = {}

local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glUintv  = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local vao = 0
local vbos = {}
local fbos = {}
local pingpong = 1
local lastSwapTime = 0
local firstTime = true

iir_effect.mix_coeff = 0.95


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

local function init_quad_attributes()
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
    table.insert(vbos, vvbo)
end

function iir_effect.initGL(w,h)
    vbos = {}
    texs = {}
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog_mix = sf.make_shader_from_source({
        vsrc = src_vert,
        fsrc = mix_frag,
        })
    prog_pres = sf.make_shader_from_source({
        vsrc = src_vert,
        fsrc = pres_frag,
        })

    init_quad_attributes()

    -- Re-use the VBO for each program
    local vpos_loc = gl.glGetAttribLocation(prog_mix, "vPosition")
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glEnableVertexAttribArray(vpos_loc)

    local vpos_loc = gl.glGetAttribLocation(prog_pres, "vPosition")
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glEnableVertexAttribArray(vpos_loc)

    iir_effect.resize_fbo(w,h)
    gl.glBindVertexArray(0)
end

function iir_effect.exitGL()
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog_mix)
    gl.glDeleteProgram(prog_pres)

    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)

    for _,v in pairs(fbos) do
        if v then fbf.deallocate_fbo(v) end
    end
end

function iir_effect.resize_fbo(w,h)
    for _,v in pairs(fbos) do
        if v then fbf.deallocate_fbo(v) end
    end
    for i=1,3 do
        fbos[i] = fbf.allocate_fbo(w,h,true)
    end

    iir_effect.clear_fbos()
end

-- Mix the two given textures into the front buffer
function iir_effect.mix_textures(texId1, texId2, mix)
    local fron = iir_effect.getfrontfbo()
    fbf.bind_fbo(fron)
    do
        gl.glUseProgram(prog_mix)

        gl.glActiveTexture(GL.GL_TEXTURE0)
        gl.glBindTexture(GL.GL_TEXTURE_2D, texId1)
        local tx_loc1 = gl.glGetUniformLocation(prog_mix, "tex1")
        gl.glUniform1i(tx_loc1, 0)
        
        gl.glActiveTexture(GL.GL_TEXTURE1)
        gl.glBindTexture(GL.GL_TEXTURE_2D, texId2)
        local tx_loc2 = gl.glGetUniformLocation(prog_mix, "tex2")
        gl.glUniform1i(tx_loc2, 1)

        local mc_loc = gl.glGetUniformLocation(prog_mix, "u_coeff")
        gl.glUniform1f(mc_loc, mix)

        gl.glBindVertexArray(vao)
        gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
        gl.glBindVertexArray(0)

        gl.glUseProgram(0)
    end
    fbf.unbind_fbo()
end

function iir_effect.bind_fbo()
    local f = fbos[3]
    if f then fbf.bind_fbo(f) end
end

function iir_effect.unbind_fbo()
    fbf.unbind_fbo()
end

function iir_effect.clear_fbos()
    for _,v in pairs(fbos) do
        fbf.bind_fbo(v)
        gl.glClearColor(0,0,0,0)
        gl.glClear(GL.GL_COLOR_BUFFER_BIT + GL.GL_DEPTH_BUFFER_BIT)
        fbf.unbind_fbo()
    end
end

function iir_effect.present()
    -- First, mix new and old images into front buffer
    local f = fbos[3]
    local f2 = iir_effect.getbackfbo()

    local mix = iir_effect.mix_coeff
    if firstTime == true then
        -- Buffers are cleared to black, this prevents a
        -- leading black frame when switching on the effect.
        firstTime = false
        mix = 0.0
    end
    iir_effect.mix_textures(f.tex, f2.tex, mix)
    
    -- Then, Present front buffer
    local fron = iir_effect.getfrontfbo()
    gl.glUseProgram(prog_pres)

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, fron.tex)
    local tx_loc1 = gl.glGetUniformLocation(prog_pres, "tex1")
    gl.glUniform1i(tx_loc1, 0)

    gl.glBindVertexArray(vao)
    gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function iir_effect.getfrontfbo()
    return fbos[pingpong]
end

function iir_effect.getbackfbo()
    local other = 3 - pingpong
    return fbos[other]
end

-- Swap buffers
function iir_effect.swap()
    pingpong = pingpong + 1
    if pingpong > 2 then
        pingpong = 1
    end
end

function iir_effect.timestep(absTime, dt)
    time = absTime
    if absTime - lastSwapTime > 1/60 then
        iir_effect.swap()
        lastSwapTime = absTime
    end
end

return iir_effect
