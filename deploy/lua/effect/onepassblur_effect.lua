-- onepassblur_effect.lua
onepassblur_effect = {}

local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

local vao = 0
local prog = 0
local vbos = {}

local basic_vert = [[
#version 410 core

in vec4 vPosition;
out vec3 vfTexCoord;

void main()
{
    vfTexCoord = vec3(.5*(vPosition.xy+1.),0.);
    gl_Position = vec4(vPosition.xy, 0., 1.);
}
]]

local basic_frag = [[
#version 330

in vec3 vfTexCoord;
out vec4 fragColor;
uniform sampler2D tex;

void main()
{
    fragColor = texture(tex, vfTexCoord.xy);
}
]]
function make_quad_vbos(prog)
    local verts = glFloatv(4*2, {
        -1,-1,
        1,-1,
        1,1,
        -1,1,
        })

    local vpos_loc = gl.glGetAttribLocation(prog, "vPosition")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, vvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
end

function onepassblur_effect.initGL(w, h)
    vbos = {}
    texs = {}
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })
    make_quad_vbos(prog)

    onepassblur_effect.resize_fbo(w,h)

    gl.glBindVertexArray(0)
end

function onepassblur_effect.exitGL()
    for k,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog)

    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)

    fbf.deallocate_fbo(onepassblur_effect.fbo)
end

function onepassblur_effect.present_texture(texId, resx, resy)
    gl.glUseProgram(prog)

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, texId)
    local tx_loc = gl.glGetUniformLocation(prog, "tex")
    gl.glUniform1i(tx_loc, 0)

    gl.glPolygonMode(GL.GL_FRONT_AND_BACK, GL.GL_FILL)
    gl.glBindVertexArray(vao)
    gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function onepassblur_effect.bind_fbo()
    local f = onepassblur_effect.fbo
    if not f then return end
    fbf.bind_fbo(f)
    gl.glViewport(0,0, f.w, f.h)
end

function onepassblur_effect.unbind_fbo()
    fbf.unbind_fbo()
end

function onepassblur_effect.resize_fbo(w,h)
    local e = onepassblur_effect
    if e.fbo then fbf.deallocate_fbo(e.fbo) end
    local d = 8
    e.fbo = fbf.allocate_fbo(w/d, h/d, true)
end

function onepassblur_effect.present()
    local e = onepassblur_effect
    local f = e.fbo
    e.present_texture(f.tex, f.w, f.h)
end

return onepassblur_effect
