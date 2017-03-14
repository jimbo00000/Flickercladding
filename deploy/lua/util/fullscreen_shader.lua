--[[ fullscreen_shader.lua

    The basics of a frag shader that fills the screen.

    A main frag shader function can be passed into the constructor
    similar to Shadertoy for easy shader coding.
]]

local ffi = require("ffi")
local sf = require("util.shaderfunctions")

FullscreenShader = {}
FullscreenShader.__index = FullscreenShader

function FullscreenShader.new(...)
    local self = setmetatable({}, FullscreenShader)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

local basic_vert = [[
#version 300 es

in vec2 vPosition;

out vec2 uv;

void main()
{
    uv = .5*vPosition + vec2(.5);
    gl_Position = vec4(vPosition, 0., 1.);
}
]]

--[[
    The standard shader header.
]]
local frag_header = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec2 uv;
out vec4 fragColor;
]]

--[[
    Another main body can be passed in place of this default one.
    Input: uv  vec2  screen position in [0,1]
    Output: fragColor vec4  pixel color 
]]
local frag_body = [[
void main()
{
    vec3 col = vec3(uv, 0.);
    fragColor = vec4(col, 1.0);
}
]]

function FullscreenShader:initTriAttributes()
    local glIntv   = ffi.typeof('GLint[?]')
    local glFloatv = ffi.typeof('GLfloat[?]')

    -- One big tri to avoid some overdraw on the seam
    local verts = glFloatv(3*2, {
        -1,-1,
        3,-1,
        -1,3,
        })

    local vpos_loc = gl.glGetAttribLocation(self.prog, "vPosition")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, vvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
end

function FullscreenShader:init(fragshader_main)
    self.vbos = {}
    self.vao = 0
    self.prog = 0
    self.fragsrc = frag_body
    if fragshader_main then self.fragsrc = fragshader_main end
end

function FullscreenShader:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = frag_header..self.fragsrc,
        })

    self:initTriAttributes()
    gl.glBindVertexArray(0)
end

function FullscreenShader:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

-- Pass in an optional closure to set uniform variables in self.prog.
function FullscreenShader:render(view, proj, setvars)
    gl.glUseProgram(self.prog)

    if setvars then setvars(self.prog) end

    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end
