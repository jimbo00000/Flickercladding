-- colorquad.lua
colorquad = {}

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

local vbos = {}
local vao = 0
local prog = 0

local tx,ty = 0,0

local basic_vert = [[
#version 300 es

in vec4 vPosition;
in vec4 vColor;

out vec3 vfColor;

void main()
{
    vfColor = vColor.xyz;
    gl_Position = vPosition;
}
]]


local basic_frag = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec3 vfColor;
out vec4 fragColor;

uniform vec2 uTouchPt;

void main()
{
    vec3 col = vfColor;
    float d = length(col.xy - uTouchPt);
    col *= 1. - d;
    fragColor = vec4(col, 1.0);
}
]]


local function init_cube_attributes()
    local verts = glFloatv(4*3, {
        -1,-1,0,
        1,-1,0,
        1,1,0,
        -1,1,0,
        })

    local vpos_loc = gl.glGetAttribLocation(prog, "vPosition")
    local vcol_loc = gl.glGetAttribLocation(prog, "vColor")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, vvbo)

    local cvbo = glIntv(0)
    gl.glGenBuffers(1, cvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)

    local quads = glUintv(6*2, {
        0,1,2,
        0,2,3,
    })
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.GL_STATIC_DRAW)
    table.insert(vbos, qvbo)
end

function colorquad.initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    init_cube_attributes()
    gl.glBindVertexArray(0)
end

function colorquad.exitGL()
    gl.glBindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog)
    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

local bright = 0
function colorquad.render_for_one_eye(view, proj)
    local utp_loc = gl.glGetUniformLocation(prog, "uTouchPt")
    gl.glUseProgram(prog)
    gl.glUniform2f(utp_loc, tx, ty)
    gl.glBindVertexArray(vao)
    gl.glDrawElements(GL.GL_TRIANGLES, 6, GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end

function colorquad.timestep(absTime, dt)
end

function colorquad.onSingleTouch(pointerid, action, x, y)
    --print("colorquad.onSingleTouch",pointerid, action, x, y)
    local winw, winh = 1000,1000
    tx,ty = x/winw, y/winh
end

function colorquad.setBrightness(b)
    bright = b
end

return colorquad
