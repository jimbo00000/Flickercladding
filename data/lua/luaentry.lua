-- luaentry.lua
local appDir = "/sdcard/Android/data/com.android.flickercladding"
package.path = appDir.."/lua/?.lua;../data/lua/?.lua;" .. "?.lua;" .. package.path
package.path = "../data/lua/;" .. package.path

local ffi = require("ffi")
local openGL -- @todo select GL or GLES header
local s = require("scene.colorquad")

local ANDROID = false
local win_w,win_h = 800,800

local scene_modules = {
    "scene.colorquad",
    "scene.clockface",
}
local scene_module_idx = 1
function switch_scene(reverse)
    if reverse then
        scene_module_idx = scene_module_idx - 1
        if scene_module_idx < 1 then scene_module_idx = #scene_modules end
    else
        scene_module_idx = scene_module_idx + 1
        if scene_module_idx > #scene_modules then scene_module_idx = 1 end
    end
    switch_to_scene(scene_modules[scene_module_idx])
end

function switch_to_scene(name)
    print("switch_to_scene", name)
    if s and s.exitGL then
        s.exitGL()
    end
    package.loaded[name] = nil
    s = nil

    if not s then
        s = require(name)
        if s then
            -- Instruct the scene where to load data from. Dir is relative to app's working dir.
            local dir = ""
            if ANDROID then
                dir = appDir.."/lua"
            else
                dir = "../data/lua"
            end
            if s.setDataDirectory then s.setDataDirectory(dir) end
            if s.setWindowSize then s.setWindowSize(win_w, win_h) end
            s.initGL()
        end
    end
end

-- Cast the array cdata ptr(passes from glm::value_ptr(glm::mat4),
-- which gives a float[16]) to a table for further manipulation here in Lua.
function array_to_table(array)
    local m0 = ffi.cast("float*", array)
    -- The cdata array is 0-indexed. Here we clumsily jam it back
    -- into a Lua-style, 1-indexed table(array portion).
    local tab = {}
    for i=0,15 do tab[i+1] = m0[i] end
    return tab
end

function on_lua_draw(pmv, ppr)
    local mv = array_to_table(pmv)
    local pr = array_to_table(ppr)
    s.render_for_one_eye(mv, pr)
    if s.set_origin_matrix then s.set_origin_matrix(mv) end
end

function on_lua_initgl(pLoaderFunc)
    print("on_lua_initgl")
    if pLoaderFunc == 0 then
        print("No loader function - initializing GLES 3")
        openGL = require("opengles3")
    else
        --[[
            Now, the GL function loading business...
            Everything in GL 1.2 or older has names in OpenGL32.dll/opengl32.dll (Windows),
            while pointers to all newer functions must be obtained from a loader function.
            Using the wglGetProcAddress provided by that dll will return NULL pointers for
            all the old functions. Using glfwGetProcAddress takes care of both cases, but
            pulling it in via the ffi would be a redundant copy of GLFW, and would require
            an init of the second GLFW, which it might not even do. Instead, just pass the
            pointer to to C++ app's GLFW's glfwGetProcAddress.

            https://www.opengl.org/wiki/Load_OpenGL_Functions
            https://www.opengl.org/wiki/Talk%3aPlatform_specifics%3a_Windows
            http://stackoverflow.com/questions/25214519/opengl-1-0-and-1-1-function-pointers-on-windows
        ]]
        print("Desktop path - initializing full OpenGL")
        ffi.cdef[[
        typedef void (*GLFWglproc)();
        GLFWglproc glfwGetProcAddress(const char* procname);
        typedef GLFWglproc (*GLFWGPAProc)(const char*);
        ]]
        openGL = require("opengl")
        openGL.loader = ffi.cast('GLFWGPAProc', pLoaderFunc)
    end
    openGL:import()

    if s then
        -- Instruct the scene where to load data from. Dir is relative to app's working dir.
        local dir = ""
        if pLoaderFunc == 0 then -- Assuming this means Android
            dir = appDir.."/lua"
            ANDROID = true
        else
            dir = "../data/lua"
        end
        if s.setDataDirectory then s.setDataDirectory(dir) end
        s.initGL()
    end
end

function on_lua_exitgl()
    s.exitGL()
end

function on_lua_setscene(name)
    print("Lua Setting the scene to "..name)

    s.exitGL()

    package.loaded[name] = nil
    s = nil

    if not s then
        base = string.sub(name, 0, -5)
        print("Base: "..base)
        s = require("scene/"..base)
        if s then
            -- Instruct the scene where to load data from. Dir is relative to app's working dir.
            if s.setDataDirectory then s.setDataDirectory(appDir.."/lua") end
            if s.setWindowSize then s.setWindowSize(w, h) end
            s.initGL()
        end
    end
end

function on_lua_timestep(absTime, dt)
    s.timestep(absTime, dt)
end

local action_types = {
  [0] = "Down",
  [1] = "Up",
  [2] = "Move",
  [3] = "Cancel",
  [4] = "Outside",
  [5] = "PointerDown",
  [6] = "PointerUp",
}

local pointer_states = { }

function on_lua_singletouch(pointerid, action, x, y)
    --print("on_lua_singletouch", pointerid, action, x, y)
    if s.onSingleTouch then s.onSingleTouch(pointerid, action, x, y) end

    local func_table = {
        ["Down"] = function (pointerid, x, y)
            pointer_states[pointerid] = {x=x, y=y, tx=x, ty=y, down=true}
        end,
        ["Up"] = function (pointerid, x, y)
            local p = pointer_states[pointerid]
            if p then p.down = false end
        end,
        ["PointerUp"] = function (pointerid, x, y)
            local p = pointer_states[pointerid]
            if p then p.down = false end
        end,
        ["Move"] = function (pointerid, x, y)
            local p = pointer_states[pointerid]
            if not p then
                pointer_states[pointerid] = { x=x, y=y, tx=x, ty=y, down=true}
                p = pointer_states[pointerid]
            end
            p.x,p.y = x,y
        end,
    }
    local actionflag = action % 255
    local a = action_types[actionflag]
    if not a then return end
    local f = func_table[a]
    if f then f(pointerid, x, y) end


    -- Pinch distance
    local p0 = pointer_states[0]
    local p1 = pointer_states[1]
    if p0 and p1 then
        local pdx = p0.x - p1.x
        local pdy = p0.y - p1.y
        local pd = math.sqrt(pdx*pdx + pdy+pdy)
        --print("dist: "..pd)

        if s.setBrightness then
            s.setBrightness((pd-200) / 1000)
        end
    end
end

function connect_to_debugger()
        --[[
        Connect to a running debugger server in ZeroBrane Studio.
          - Choose Project->Start Debugger Server
          - Include mobdebug.lua in lua/ next to scenebridge.lua
          - Include socket/core.dll in the working directory of the app
             TODO: set package.path to get this from within the source tree
          TODO: Can only trigger bp once per reload of lua state.
          One copy of socket/core.dll looks for lua.lib by name - the quick
          fix is to copy lua51.dll to lua.dll. Hex editing the dll is also an option.
        ]]
        if (ffi.os == "Windows") then
            --TODO: how do I link to socket package on Linux?
            package.loadlib("socket/core.dll", "luaopen_socket_core")
            local socket = require("socket.core")
        end
        require('mobdebug').start()
end

function on_lua_keypressed(key)
    --print("Heard key "..key)
    if key == 298 then -- F9
        connect_to_debugger()
    end
end

function on_lua_setwindowsize(w, h)
    win_w,win_h = w,h
    if s.setWindowSize then s.setWindowSize(w, h) end
end

function on_lua_changescene(d)
    switch_scene(d)
end
