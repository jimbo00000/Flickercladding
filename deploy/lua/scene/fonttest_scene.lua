--[[ fonttest_scene.lua

    A font rendering example, drawing 139 lines of lorem ipsum text.

    Uses the glfont class in util, which uses the bmfont module 
    to load font texture and glyphs. glfont handles rendering,
    trying to cache as much data as possible for rendering speed.
]]
fonttest_scene = {}

local glfont = nil -- Will hold our class instance
require("util.glfont")
local mm = require("util.matrixmath")
local dataDir = nil
local lines = {}

-- Since data files must be loaded from disk, we have to know
-- where to find them. Set the directory with this standard entry point.
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
    local fontname = "courier_512"
    if dataDir then dir = dataDir .. "/" .. dir end
    glfont = GLFont.new(fontname..'.fnt', fontname..'_0.raw')
    glfont:setDataDirectory(dir)
    glfont:initGL()
end

function fonttest_scene.exitGL()
    glfont:exitGL()
end

function fonttest_scene.render_for_one_eye(view, proj)
    local m = {}
    local s = .002
    mm.make_identity_matrix(m)
    mm.glh_translate(m, -2, 1.2, 0)
    mm.glh_scale(m, s, -s, s)
    mm.pre_multiply(m, view)

    local col = {1, 1, 1}
    local lineh = glfont.font.common.lineHeight
    for k,v in pairs(lines) do
        glfont:render_string(m, proj, col, v)
        mm.glh_translate(m, 0, lineh, 0)
    end
end

function fonttest_scene.timestep(absTime, dt)
end

return fonttest_scene
