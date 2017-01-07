--[[ filter.lua

    A post-procesing image filter in GLSL.
]]

local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")

--[[
    Standard vertex shader for quad over NDC [-1,1].
    Outputs texture coordinates in [0,1].
]]
local fullscreen_vert = [[
#version 300 es

in vec4 vPosition;
out vec2 uv;

void main()
{
    uv = .5 * (vPosition.xy + vec2(1.)); // map [-1,1] to [0,1]
    gl_Position = vec4(vPosition.xy, 0., 1.);
}
]]

--[[
    Standard header prepended onto all filter frag shaders
]]
local fullscreen_frag_header = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D tex;
in vec2 uv;
out vec4 fragColor;
]]


Filter = {}
Filter.__index = Filter

function Filter.new(...)
    local self = setmetatable({}, Filter)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end
    return self
end

function Filter:init(strings)
    self.name = strings.name
    self.source = strings.source
    self.samplefac = strings.sample_factor or 1
end

function Filter:initGL(strings)
    self.prog = sf.make_shader_from_source({
        vsrc = fullscreen_vert,
        fsrc = fullscreen_frag_header..self.source,
        })
end

function Filter:exitGL()
    fbf.deallocate_fbo(self.fbo)
    gl.glDeleteProgram(self.prog)
end

function Filter:resize(w,h)
    fbf.deallocate_fbo(self.fbo)
    self.fbo = fbf.allocate_fbo(w*self.samplefac, h*self.samplefac, true)
end
