--[[ hybrid_scene.lua

    A combination of two scenes with two different rendering
    techniques and a font renderer to label each type of object.

    All rendering code is owned by the respective scene types and
    is simply invoked from this module.
]]
hybrid_scene = {}

hybrid_scene.__index = hybrid_scene

function hybrid_scene.new(...)
    local self = setmetatable({}, hybrid_scene)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end


local RasterLib = require("scene2.textured_cubes")
local RaymarchLib = require("scene2.raymarch_csg")
require("util.glfont")
local mm = require("util.matrixmath")

function hybrid_scene:init()
    self.vbos = {}
    self.vao = 0
    self.prog = 0
    self.dataDir = nil
    self.glfont = nil

    self.Raster = RasterLib.new()
    self.Raymarch = RaymarchLib.new()
end
function hybrid_scene:setDataDirectory(dir)
    self.Raster:setDataDirectory(dir)
    self.dataDir = dir
end

function hybrid_scene:initGL()
    self.Raster:initGL()
    self.Raymarch:initGL()

    dir = "fonts"
    if self.dataDir then dir = self.dataDir .. "/" .. dir end
    self.glfont = GLFont.new('papyrus_512.fnt', 'papyrus_512_0.raw')
    self.glfont:setDataDirectory(dir)
    self.glfont:initGL()
end

function hybrid_scene:exitGL()
    self.Raster:exitGL()
    self.Raymarch:exitGL()
    self.glfont:exitGL()
end

function hybrid_scene:render_for_one_eye(view, proj)
    self.Raster:render_for_one_eye(view, proj)
    self.Raymarch:render_for_one_eye(view, proj)

    local col = {1, 1, 1}
    local m = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
    local s = .002
    mm.glh_translate(m, -1, .8, .5)
    mm.glh_scale(m, s, -s, s)
    mm.pre_multiply(m, view)
    self.glfont:render_string(m, proj, col, "Raymarched CSG Shape")

    local m = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
    local s = .002
    mm.glh_translate(m, 1, 0.2, -.5)
    mm.glh_scale(m, s, -s, s)
    mm.pre_multiply(m, view)
    self.glfont:render_string(m, proj, col, "Rasterized cubes")
end

return hybrid_scene
