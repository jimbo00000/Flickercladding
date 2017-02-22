--[[
    cubemap_scene.lua

    Draws cube geometry textured with a cubemap loaded from six
    individual face images. Makes an easy backdrop(from a single
    point perspective).
]]
cubemap_scene = {}

local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glUintv  = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local vbos = {}
local vao = 0
local prog = 0
local texID = 0

local cubemap_vert = [[
#version 300 es

in vec4 vPosition;

out vec3 vfColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    vec3 rawPos = vPosition.xyz - vec3(.5);
    vfColor = normalize(rawPos);

    gl_Position = prmtx * mvmtx * vPosition;
}
]]

local cubemap_frag = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec3 vfColor;
out vec4 fragColor;

uniform samplerCube sTex;

void main()
{
    vec3 tc = texture(sTex, vfColor.xyz).rgb;
    fragColor = vec4(tc.xyz, 1.);
}
]]

function cubemap_scene.setDataDirectory(dir)
    dataDir = dir
end

local function loadtextures()
    local texfilenames = {
        "posx_",
        "negx_",
        "posy_",
        "negy_",
        "posz_",
        "negz_",
    }
    local dtxId = ffi.new("GLuint[1]")
    gl.glGenTextures(1, dtxId)
    texID = dtxId[0]
    gl.glBindTexture(GL.GL_TEXTURE_CUBE_MAP, texID)
    local dim = 128
    for i,name in ipairs(texfilenames) do
        local fn = name..dim..".raw"
        if dataDir then fn = dataDir .. "/" .. fn end
        local w,h = dim,dim
        local inp = assert(io.open(fn, "rb"))
        local data = inp:read("*all")
        assert(inp:close())
        gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR)
        gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR)
        gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_WRAP_S, GL.GL_CLAMP_TO_EDGE)
        gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_WRAP_T, GL.GL_CLAMP_TO_EDGE)
        gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_WRAP_R, GL.GL_CLAMP_TO_EDGE)
        gl.glTexParameteri(GL.GL_TEXTURE_CUBE_MAP, GL.GL_TEXTURE_MAX_LEVEL, 0)
        gl.glTexImage2D(GL.GL_TEXTURE_CUBE_MAP_POSITIVE_X + i - 1,
            0, GL.GL_RGB,
            w, h, 0,
            GL.GL_RGB, GL.GL_UNSIGNED_BYTE, data)
    end
    gl.glBindTexture(GL.GL_TEXTURE_CUBE_MAP, 0)
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

    local vpos_loc = gl.glGetAttribLocation(prog, "vPosition")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, vvbo)

    gl.glEnableVertexAttribArray(vpos_loc)

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

function cubemap_scene.initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = cubemap_vert,
        fsrc = cubemap_frag,
        })

    init_cube_attributes()
    loadtextures()
    gl.glBindVertexArray(0)
end

function cubemap_scene.exitGL()
    gl.glBindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog)
    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)

    local dtexId = ffi.new("GLuint[1]", texID)
    gl.glDeleteTextures(1, dtexId)
end

function cubemap_scene.render_for_one_eye(view, proj)
    local umv_loc = gl.glGetUniformLocation(prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(prog, "prmtx")
    gl.glUseProgram(prog)
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_CUBE_MAP, texID)
    local stex_loc = gl.glGetUniformLocation(prog, "sTex")
    gl.glUniform1i(stex_loc, 0)

    local m = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
    local s = 15
    mm.glh_scale(m, s, s, s)
    mm.glh_translate(m, -.5,-.5,-.5)
    mm.pre_multiply(m, view)
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))

    gl.glBindVertexArray(vao)
    gl.glDrawElements(GL.GL_TRIANGLES, 6*3*2, GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function cubemap_scene.timestep(absTime, dt)
end

return cubemap_scene
