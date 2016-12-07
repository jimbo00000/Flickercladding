--[[ hybrid_scene.lua

    A combination of two scenes with two different rendering
    techniques and a font renderer to label each type of object.

    All rendering code is owned by the respective scene types and
    is simply invoked from this module.
]]
hybrid_scene = {}

local sts = require("scene.shadertoy_scene2")
local cbs = require("scene.textured_cubes")
local glfont = nil
require("util.glfont")
local mm = require("util.matrixmath")

local dataDir = nil

function hybrid_scene.setDataDirectory(dir)
    cbs.setDataDirectory(dir)
    dataDir = dir
end

function hybrid_scene.initGL()
    sts.initGL()
    cbs.initGL()

    dir = "fonts"
    if dataDir then dir = dataDir .. "/" .. dir end
    glfont = GLFont.new('papyrus_512.fnt', 'papyrus_512_0.raw')
    glfont:setDataDirectory(dir)
    glfont:initGL()
end

function hybrid_scene.exitGL()
    sts.exitGL()
    cbs.exitGL()
    glfont:exitGL()
end

function hybrid_scene.render_for_one_eye(view, proj)
    sts.render_for_one_eye(view, proj)
    cbs.render_for_one_eye(view, proj)

    local col = {1, 1, 1}
    local m = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
    local s = .002
    mm.glh_translate(m, -1, .8, .5)
    mm.glh_scale(m, s, -s, s)
    mm.pre_multiply(m, view)
    glfont:render_string(m, proj, col, "Raymarched CSG Shape")

    local m = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
    local s = .002
    mm.glh_translate(m, 1, 0.2, -.5)
    mm.glh_scale(m, s, -s, s)
    mm.pre_multiply(m, view)
    glfont:render_string(m, proj, col, "Rasterized cubes")
end

function hybrid_scene.timestep(absTime, dt)
    sts.timestep(absTime, dt)
    cbs.timestep(absTime, dt)
end

return hybrid_scene
