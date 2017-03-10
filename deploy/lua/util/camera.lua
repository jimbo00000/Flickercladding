--[[ camera.lua

	Camera controls and state.
	Plugs into glfw for input.
]]
camera = {}

local ffi = require("ffi")
local glfw = require("glfw")
local SDL = require "lib/sdl"
local mm = require("util.matrixmath")

camera.__index = camera

function camera.new(...)
    local self = setmetatable({}, camera)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function camera:init()
    self.clickpos = {0,0}
    self.clickrot = {0,0}
    self.holding = false
    self.objrot = {0,0}
    self.camerapan = {0,0,0}
    self.chassis = {0,0,1}
    self.keymove = {0,0,0}
    self.altdown = false
    self.ctrldown = false
    self.shiftdown = false
    self.keystates = {}
    for i=0, glfw.GLFW.KEY_LAST do
        self.keystates[i] = glfw.GLFW.RELEASE
    end
end

function camera:reset()
    self.chassis = {0,0,1}
    self.objrot = {0,0}
    self.camerapan = {0,0,0}
end

function camera:onkey(key, scancode, action, mods)
    self.keystates[key] = action
    self.altdown = 0 ~= bit.band(mods, glfw.GLFW.MOD_ALT)
    self.ctrldown = 0 ~= bit.band(mods, glfw.GLFW.MOD_CONTROL)
    self.shiftdown = 0 ~= bit.band(mods, glfw.GLFW.MOD_SHIFT)

    if ffi.os == "OSX" then
        -- Glfw on OSX does not seem to capture Ctrl modifier state correctly.
        self.ctrldown = 0 ~= bit.band(mods, glfw.GLFW.MOD_ALT)
    end

    -- Skip key nav if entering text
    --if Scene.charkeypressed then return end
    local mag = 1
    local spd = 10
    local km = {0,0,0}
    if self.keystates[glfw.GLFW.KEY_W] ~= glfw.GLFW.RELEASE then km[3] = km[3] + -spd end -- -z forward
    if self.keystates[glfw.GLFW.KEY_S] ~= glfw.GLFW.RELEASE then km[3] = km[3] - -spd end
    if self.keystates[glfw.GLFW.KEY_A] ~= glfw.GLFW.RELEASE then km[1] = km[1] - spd end
    if self.keystates[glfw.GLFW.KEY_D] ~= glfw.GLFW.RELEASE then km[1] = km[1] + spd end
    if self.keystates[glfw.GLFW.KEY_Q] ~= glfw.GLFW.RELEASE then km[2] = km[2] - spd end
    if self.keystates[glfw.GLFW.KEY_E] ~= glfw.GLFW.RELEASE then km[2] = km[2] + spd end
    if self.keystates[glfw.GLFW.KEY_UP] ~= glfw.GLFW.RELEASE then km[3] = km[3] + -spd end
    if self.keystates[glfw.GLFW.KEY_DOWN] ~= glfw.GLFW.RELEASE then km[3] = km[3] - -spd end
    if self.keystates[glfw.GLFW.KEY_LEFT] ~= glfw.GLFW.RELEASE then km[1] = km[1] - spd end
    if self.keystates[glfw.GLFW.KEY_RIGHT] ~= glfw.GLFW.RELEASE then km[1] = km[1] + spd end

    if self.keystates[SDL.SDLK_w] ~= 0 then km[3] = km[3] + -spd end -- -z forward
    if self.keystates[SDL.SDLK_s] ~= 0 then km[3] = km[3] - -spd end
    if self.keystates[SDL.SDLK_a] ~= glfw.GLFW.RELEASE then km[1] = km[1] - spd end
    if self.keystates[SDL.SDLK_d] ~= glfw.GLFW.RELEASE then km[1] = km[1] + spd end
    if self.keystates[SDL.SDLK_q] ~= glfw.GLFW.RELEASE then km[2] = km[2] - spd end
    if self.keystates[SDL.SDLK_e] ~= glfw.GLFW.RELEASE then km[2] = km[2] + spd end
    if self.keystates[SDL.SDLK_UP] ~= glfw.GLFW.RELEASE then km[3] = km[3] + -spd end
    if self.keystates[SDL.SDLK_DOWN] ~= glfw.GLFW.RELEASE then km[3] = km[3] - -spd end
    if self.keystates[SDL.SDLK_LEFT] ~= glfw.GLFW.RELEASE then km[1] = km[1] - spd end
    if self.keystates[SDL.SDLK_RIGHT] ~= glfw.GLFW.RELEASE then km[1] = km[1] + spd end


    if self.keystates[glfw.GLFW.KEY_LEFT_CONTROL] ~= glfw.GLFW.RELEASE then mag = 10 * mag end
    if self.keystates[glfw.GLFW.KEY_LEFT_SHIFT] ~= glfw.GLFW.RELEASE then mag = .1 * mag end
    for i=1,3 do
        self.keymove[i] = km[i] * mag
    end
end

function camera:onclick(button, action, mods, x, y)
    if action == 1 then
        self.holding = button
        self.clickpos = {x,y}
        self.clickrot = {self.objrot[1], self.objrot[2]}
    elseif action == 0 then
        self.holding = nil
    end
end

function camera:onmousemove(x, y)
    if self.holding == 0 then
        self.objrot[1] = self.clickrot[1] + x-self.clickpos[1]
        self.objrot[2] = self.clickrot[2] + y-self.clickpos[2]
    elseif self.holding == 1 then
        local s = .01
        if self.ctrldown then s = s * 10 end
        if self.shiftdown then s = s / 10 end
        self.camerapan[1] = s * (x-self.clickpos[1])
        self.camerapan[2] = -s * (y-self.clickpos[2])
    end
end

function camera:onwheel(x,y)
    local s = 1
    if self.ctrldown then s = s * 10 end
    if self.shiftdown then s = s / 10 end
    self.camerapan[3] = self.camerapan[3] - s * y
end

function camera:timestep(absTime, dt)
    for i=1,3 do
        self.chassis[i] = self.chassis[i] + dt * self.keymove[i]
    end
end

function camera:getmatrix()
    local v = {}
    mm.make_identity_matrix(v)

    if self.altdown then
        -- Lookaround camera
        mm.glh_translate(v, self.chassis[1], self.chassis[2], self.chassis[3])
        mm.glh_translate(v, self.camerapan[1], self.camerapan[2], self.camerapan[3])
        mm.glh_rotate(v, -self.objrot[1], 0,1,0)
        mm.glh_rotate(v, -self.objrot[2], 1,0,0)
    else
        -- Flyaround camera
        mm.glh_rotate(v, self.objrot[1], 0,1,0)
        mm.glh_rotate(v, self.objrot[2], 1,0,0)
        mm.glh_translate(v, self.chassis[1], self.chassis[2], self.chassis[3])
        mm.glh_translate(v, self.camerapan[1], self.camerapan[2], self.camerapan[3])
    end
    return v
end

return camera
