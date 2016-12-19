--[[ textured_cubes.lua

    A simple texturing example.

    Loads a texture image from raw data to eliminate the image format
    parsing process. The data can be saved out from Gimp or ImageMagick.
    We have to know the pixel dimensions and color depth ahead of time
    to get the right image.

    We also have to know the directory where the image file resides.
    The standard entry point setDataDirectory takes a directory string
    to be used as the path when opening the raw image file.
]]
textured_cubes = {}

textured_cubes.__index = textured_cubes

function textured_cubes.new(...)
    local self = setmetatable({}, textured_cubes)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function textured_cubes:init()
    -- Object-internal state: hold a list of VBOs for deletion on exitGL
    self.vbos = {}
    self.vao = 0
    self.prog = 0
    self.texID = 0
    self.dataDir = nil
end

local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glUintv  = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

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

function textured_cubes:setDataDirectory(dir)
    self.dataDir = dir
end

function textured_cubes:loadtextures()
    local texfilename = "stone_128x128.raw"
    if self.dataDir then texfilename = self.dataDir .. "/" .. texfilename end
    local w,h = 128,128
    local inp = io.open(texfilename, "rb")
    local data = nil
    if inp then
        data = inp:read("*all")
        assert(inp:close())
    end

    local dtxId = ffi.new("GLuint[1]")
    gl.glGenTextures(1, dtxId)
    print(dtxId[0])
    self.texID = dtxId[0]
    gl.glBindTexture(GL.GL_TEXTURE_2D, self.texID)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_S, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_T, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_NEAREST)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_NEAREST)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAX_LEVEL, 0)
    gl.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_RGB,
                  w, h, 0,
                  GL.GL_RGB, GL.GL_UNSIGNED_BYTE, data)
    gl.glBindTexture(GL.GL_TEXTURE_2D, 0)

end

function textured_cubes:init_cube_attributes()
    local v = { -- Vertex positions, 6 faces of a cube
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

    local c = { -- Texture coordinates, all 6 faces are identical
        0,0, 1,0, 1,1, 0,1,
        0,0, 1,0, 1,1, 0,1,
        0,0, 1,0, 1,1, 0,1,
        0,0, 1,0, 1,1, 0,1,
        0,0, 1,0, 1,1, 0,1,
        0,0, 1,0, 1,1, 0,1,
    }
    local cols = glFloatv(#c,c)

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
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(cols), cols, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)

    local q = { -- Vertex indices for drawing triangles of faces
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
    table.insert(self.vbos, qvbo)
end

function textured_cubes:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    self:init_cube_attributes()
    self:loadtextures()
    gl.glBindVertexArray(0)
end

function textured_cubes:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}

    gl.glDeleteProgram(self.prog)
    local texdel = ffi.new("GLuint[1]", self.texID)
    gl.glDeleteTextures(1,texdel)

    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
    gl.glBindVertexArray(0)
end

function textured_cubes:render_for_one_eye(view, proj)
    local umv_loc = gl.glGetUniformLocation(self.prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog, "prmtx")
    gl.glUseProgram(self.prog)
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, self.texID)
    local stex_loc = gl.glGetUniformLocation(self.prog, "sTex")
    gl.glUniform1i(stex_loc, 0)
    
    -- A grid of cubes arranged on the xz plane
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
            gl.glBindVertexArray(self.vao)
            gl.glDrawElements(GL.GL_TRIANGLES, 6*3*2, GL.GL_UNSIGNED_INT, nil)
            gl.glBindVertexArray(0)
        end
    end

    gl.glUseProgram(0)
end

return textured_cubes
