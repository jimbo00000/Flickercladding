-- fonttest_scene.lua
fonttest_scene = {}

local glfont = nil
require("util.glfont")
local mm = require("util.matrixmath")
local dataDir = nil
local lines = {}

function fonttest_scene.setDataDirectory(dir)
    dataDir = dir
end

function fonttest_scene.initGL()
    -- Load text file
    local filename = "loremipsumbreaks.txt"
    if dataDir then filename = dataDir .. "/" .. filename end
    local file = io.open(filename)
    if file then
        for line in file:lines() do
            table.insert(lines, line)
        end
    end

    local dir = "fonts"
    if dataDir then dir = dataDir .. "/" .. dir end
    glfont = GLFont.new('courier_512.fnt', 'courier_512_0.raw')
    glfont:setDataDirectory(dir)
    glfont:initGL()
end

function fonttest_scene.exitGL()
    glfont:exitGL()
end

function fonttest_scene.render_for_one_eye(view, proj)
    local m = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
    local s = .002
    mm.glh_translate(m, -1, .8, .5)
    mm.glh_scale(m, s, -s, s)
    mm.pre_multiply(m, view)

    local col = {1, 1, 1}
    local lh = 90
    for k,v in pairs(lines) do
        glfont:render_string(m, proj, col, v)
        mm.glh_translate(m, 0, lh, 0)
    end
end

function fonttest_scene.timestep(absTime, dt)
end

return fonttest_scene
