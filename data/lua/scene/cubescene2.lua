-- cubescene2.lua
scene = {}

local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

local bounce = 0
local vbos = {}
local vao = 0
local prog = 0
local texID = 0
local dataDir = nil

local basic_vert = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec4 vPosition;
in vec4 vColor;

out vec3 vfColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

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

void main()
{
    vec4 tc = texture(sTex, vfColor.xy);
    fragColor = vec4(tc.xyz, 1.);
}
]]

function scene.setDataDirectory(dir)
    dataDir = dir
end

local function loadtextures()
    local texfilename = "stone_128x128.raw"
    if dataDir then texfilename = dataDir .. "/" .. texfilename end
    local w,h = 128,128
    local inp = io.open(texfilename, "rb")
    local data = nil
    if inp then
        data = inp:read("*all")
        assert(inp:close())
    end
    local dtxId = ffi.new("GLuint[1]")
    gl.glGenTextures(1, dtxId)
    texID = dtxId[0]
    gl.glBindTexture(GL.GL_TEXTURE_2D, texID)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_S, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_T, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_NEAREST)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_NEAREST)
    --gl.glTexParameteri( GL.GL_TEXTURE_2D, GL.GL_DEPTH_TEXTURE_MODE, GL.GL_INTENSITY ); --deprecated, out in 3.1
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAX_LEVEL, 0)
    gl.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_RGB,
                  w, h, 0,
                  GL.GL_RGB, GL.GL_UNSIGNED_BYTE, data)
    gl.glBindTexture(GL.GL_TEXTURE_2D, 0)
end

local function init_cube_attributes()
    local v = {
        0,0,0,
        1,0,0,
        1,1,0,
        0,1,0,

        0,0,1,
        1,0,1,
        1,1,1,
        0,1,1,

        0,0,0,
        1,0,0,
        1,0,1,
        0,0,1,

        0,1,0,
        1,1,0,
        1,1,1,
        0,1,1,

        0,0,0,
        0,1,0,
        0,1,1,
        0,0,1,

        1,0,0,
        1,1,0,
        1,1,1,
        1,0,1,
    }
    local verts = glFloatv(#v,v)

    local c = {
        0,0, 1,0, 1,1, 0,1,
        0,0, 1,0, 1,1, 0,1,
        0,0, 1,0, 1,1, 0,1,
        0,0, 1,0, 1,1, 0,1,
        0,0, 1,0, 1,1, 0,1,
        0,0, 1,0, 1,1, 0,1,
    }
    local cols = glFloatv(#c,c)

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
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(cols), cols, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)

    local q = {
        0,3,2, 1,0,2,
        4,5,6, 7,4,6,
        8,11,10, 9,8,10,
        12,15,14, 13,12,14,
        16,19,18, 17,16,18,
        20,23,22, 21,20,22
    }
    local quads = glUintv(#q,q)
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.GL_STATIC_DRAW)
    table.insert(vbos, qvbo)
end

function scene.initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    init_cube_attributes()
    loadtextures()
    gl.glBindVertexArray(0)
end

function scene.exitGL()
    gl.glBindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog)
    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

local function draw_color_cube()
    gl.glBindVertexArray(vao)
    gl.glDrawElements(GL.GL_TRIANGLES, 6*3*2, GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)
end

function scene.render_for_one_eye(view, proj)
    local umv_loc = gl.glGetUniformLocation(prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(prog, "prmtx")
    gl.glUseProgram(prog)
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, texID)
    local stex_loc = gl.glGetUniformLocation(prog, "sTex")
    gl.glUniform1i(stex_loc, 0)
    
    -- grid of cubes
    local s = 2
    for j=-s,s do
        for i=-s,s do
            local m = {}
            mm.make_identity_matrix(m)
            mm.glh_translate(m, .1, 0., .2)
            mm.glh_translate(m, i, -.6, -j)
            mm.glh_scale(m, .5, .5, .5)

            mm.pre_multiply(m, view)

            gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))
            draw_color_cube()
        end
    end

    gl.glUseProgram(0)
end

function scene.timestep(absTime, dt)
    bounce = bounce + dt * 2 * (180/math.pi)
end

return scene