-- floorquad.lua
floorquad = {}

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

local vbos = {}
local vao = 0
local prog = 0

local basic_vert = [[
#version 300 es

in vec4 vPosition;
in vec4 vColor;

out vec2 vfTexCoord;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    vfTexCoord = vColor.xz;
    gl_Position = prmtx * mvmtx * vPosition;
}
]]


local basic_frag = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec2 vfTexCoord;
out vec4 fragColor;

float pi = 3.14159265358979323846;

void main()
{
    float freq = 16.0 * pi;
    float lum = floor(1.0 + 2.0*sin(freq*vfTexCoord.x) * sin(freq*vfTexCoord.y));
    fragColor = vec4(vec3(lum), 1.0);
}

]]


local function init_cube_attributes()
    local s = 10
    local verts = glFloatv(4*3, {
        0,0,0,
        s,0,0,
        s,0,s,
        0,0,s,
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

    local quads = glUintv(6*6, {
        0,1,2,
        0,2,3,
    })
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.GL_STATIC_DRAW)
    table.insert(vbos, qvbo)
end

function floorquad.initGL()
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

function floorquad.exitGL()
    gl.glBindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog)
    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

function floorquad.render_for_one_eye(view, proj)
    local umv_loc = gl.glGetUniformLocation(prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(prog, "prmtx")
    gl.glUseProgram(prog)
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))
    gl.glBindVertexArray(vao)
    gl.glDrawElements(GL.GL_TRIANGLES, 3*2, GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end

function floorquad.timestep(absTime, dt)
end

function floorquad.onSingleTouch(pointerid, action, x, y)
    --print("floorquad.onSingleTouch",pointerid, action, x, y)
end

return floorquad
