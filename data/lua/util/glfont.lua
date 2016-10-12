-- glfont.lua

require("opengl")
require("util.bmfont")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local mm = require("util.matrixmath")

-- Types from:
-- https://github.com/nanoant/glua/blob/master/init.lua
local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glCharv    = ffi.typeof('GLchar[?]')
local glSizeiv   = ffi.typeof('GLsizei[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')
local glConstCharpp = ffi.typeof('const GLchar *[1]')

local vao = 0
local prog = 0
local tex = 0
local vbos = {}
local texs = {}
local font
local string_vbo_table = {}

local dataDir = nil
local tex_w, tex_h

local basic_vert = [[
#version 310 es

layout(location = 0) in vec4 vPosition;
layout(location = 1) in vec4 vColor;
out vec3 vfColor;

layout(location = 0) uniform mat4 mvmtx;
layout(location = 1) uniform mat4 prmtx;

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

layout(location = 2) uniform sampler2D tex;
layout(location = 3) uniform vec3 uColor;

void main()
{
    vec3 texCol = texture(tex, vfColor.xy).xyz;
    float lum = length(texCol);
    fragColor = vec4(uColor, lum);
}
]]

-- this is our GLFont class
GLFont = {}
GLFont.__index = GLFont

-- and its new function
function GLFont.new(...)
    local self = setmetatable({}, GLFont)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function GLFont:init(fontfile, imagefile)
    self.fontfile = fontfile
    self.imagefile = imagefile
    -- read glyphs from font.txt and store them in chars table
    self.chars = {}

    self.vao = 0
    self.prog = 0
    self.tex = 0
    self.vbos = {}
    self.texs = {}
    self.string_vbo_table = {}
    self.dataDir = nil
end

function GLFont:setDataDirectory(dir)
    self.dataDir = dir
end

function GLFont:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(vao)

    self.prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    gl.glEnableVertexAttribArray(0)
    gl.glEnableVertexAttribArray(1)
    gl.glBindVertexArray(0)

    local texId = ffi.new("GLuint[1]")
    gl.glGenTextures(1, texId);
    self.tex = texId[0]

    -- $ convert papyrus_512_0.png  -size 512x512 -depth 32 -channel RGBA gray:papyrus_512_0.raw
    local fontname, texname, tw, th, td, format = self.fontfile, self.imagefile, 512, 512, 4, GL.GL_RGBA
    self.tex_w = tw
    self.tex_h = th
    if self.dataDir then fontname = self.dataDir .. "/" .. fontname end
    if self.dataDir then texname = self.dataDir .. "/" .. texname end

    self.font = BMFont.new(fontname, nil)
    local inp = io.open(texname, "rb")
    if inp then
        local data = inp:read("*all")
        local pixels = glCharv(self.tex_w*self.tex_h*td, data)

        gl.glBindTexture(GL.GL_TEXTURE_2D, self.tex)
        gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR)
        gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR)
        gl.glTexImage2D(GL.GL_TEXTURE_2D, 0, format, self.tex_w, self.tex_h, 0, format, GL.GL_UNSIGNED_BYTE, pixels)
        gl.glBindTexture(GL.GL_TEXTURE_2D, 0)
        table.insert(self.texs, texId)
    end
end

function GLFont:exitGL()
    for k,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    for k,v in pairs(self.texs) do
        gl.glDeleteTextures(1,v)
    end
    self.vbos = {}
    self.texs = {}
    gl.glDeleteProgram(self.prog)

    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)

    for k,v in pairs(self.string_vbo_table) do
        local vv,vt = v[1], v[2]
        gl.glDeleteBuffers(1,vv)
        gl.glDeleteBuffers(1,vt)
    end
    self.font.chars = {}
end

function GLFont:render_string(mview, proj, color, str)
    if not str then return end
    if #str == 0 then return end
    if self.prog == 0 then return end

    gl.glUseProgram(self.prog)
    gl.glUniformMatrix4fv(0, 1, GL.GL_FALSE, glFloatv(16, mview))
    gl.glUniformMatrix4fv(1, 1, GL.GL_FALSE, glFloatv(16, proj))

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, self.tex)
    gl.glUniform1i(2, 0)

    gl.glUniform3f(3, color[1], color[2], color[3])

    gl.glEnable(GL.GL_BLEND)
    gl.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA);
    gl.glBindVertexArray(self.vao)

    if self.string_vbo_table[str] == nil then
        --print("First time seeing "..str)
        -- Accumulate a whole string's worth of vertex array data.
        local stringv = {}
        local stringt = {}

        x,y = 0,0
        for i=1,#str do
            local ch = str:byte(i)
            if ch ~= nil then
                local v, t, xa = self.font:getcharquad(ch, x, y, self.tex_w, self.tex_h)
                if v and t then
                    local quadv = {
                        v[1], v[2], v[3], v[4], v[5], v[6],
                        v[5], v[6], v[7], v[8], v[1], v[2],
                    }
                    local quadt = {
                        t[1], t[2], t[3], t[4], t[5], t[6],
                        t[5], t[6], t[7], t[8], t[1], t[2],
                    }
                    for i=1,#quadv do table.insert(stringv, quadv[i]) end
                    for i=1,#quadt do table.insert(stringt, quadt[i]) end
                    x = x + xa
                end
            end
        end

        if #stringv > 0 then
            local verts = glFloatv(#stringv, stringv)
            local texs  = glFloatv(#stringt, stringt)

            local newvbov = glIntv(0)
            gl.glGenBuffers(1, newvbov)
            gl.glBindBuffer(GL.GL_ARRAY_BUFFER, newvbov[0])
            gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
            gl.glVertexAttribPointer(0, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
            table.insert(self.vbos, newvbov)

            local newvbot = glIntv(0)
            gl.glGenBuffers(1, newvbot)
            gl.glBindBuffer(GL.GL_ARRAY_BUFFER, newvbot[0])
            gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(texs), texs, GL.GL_STATIC_DRAW)
            gl.glVertexAttribPointer(1, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
            table.insert(self.vbos, newvbot)

            self.string_vbo_table[str] = {newvbov, newvbot}
        else
            gl.glBindVertexArray(0)
            gl.glDisable(GL.GL_BLEND)
            gl.glUseProgram(0)
            return
        end
    else
        local strVBO = self.string_vbo_table[str]
        strVBO.age = 0
        gl.glBindBuffer(GL.GL_ARRAY_BUFFER, strVBO[1][0])
        gl.glVertexAttribPointer(0, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
        gl.glBindBuffer(GL.GL_ARRAY_BUFFER, strVBO[2][0])
        gl.glVertexAttribPointer(1, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    end

    gl.glEnableVertexAttribArray(0)
    gl.glEnableVertexAttribArray(1)

    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3*2*#str)

    gl.glBindVertexArray(0)
    gl.glDisable(GL.GL_BLEND)

    gl.glUseProgram(0)
end

function GLFont:get_string_width(str)
    if #str == 0 then return 0 end

    local w = 0
    for i=1,#str do
        local ch = str:byte(i)
        if ch ~= nil then
            local v, t, xa = self.font:getcharquad(ch, x, y, self.tex_w, self.tex_h)
            if v and t then
                w = w + xa
            end
        end
    end
    return w
end

function GLFont:get_max_char_width()
    local mx = 0
    for k,v in pairs(self.font.chars) do
        mx = math.max(mx, v.xadvance)
    end
    return mx
end

function GLFont:stringcount()
    local count = 0
    for _ in pairs(self.string_vbo_table) do count = count + 1 end
    return count
end

function GLFont:deleteoldstrings()
    for k,v in pairs(self.string_vbo_table) do
        if v.age and v.age > 100 then
            local vv,vt = v[1], v[2]
            gl.glDeleteBuffers(1,vv)
            gl.glDeleteBuffers(1,vt)
            self.string_vbo_table[k] = nil
        end
        if v.age then
            v.age = v.age + 1 or 1
        else
            v.age = 1
        end
    end
end
