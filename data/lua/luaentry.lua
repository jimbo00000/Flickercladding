-- luaentry.lua
local appDir = "/sdcard/Android/data/com.android.flickercladding"
package.path = appDir.."/lua/?.lua;../data/lua/?.lua;" .. "?.lua;" .. package.path
--package.path = "../data/lua/;" .. package.path

local ffi = require("ffi")
local openGL -- @todo select GL or GLES header
local Scene = nil
require("util.glfont")
local mm = require("util.matrixmath")
local kc = require("util.glfw_keycodes")

local ANDROID = false
local win_w,win_h = 800,800
local lastSceneChangeTime = 0

local scene_modules = {
    "scene.colorcube",
    "scene.fbo_scene",
    "scene.cubemap_scene",
    "scene.moon_scene3",
    "scene.tunnel_frag",
    "scene.tunnel_vert",
    "scene.stringedit_scene",
    "scene.fullscreen_quad",
    "scene.touch_shader2",
    "scene.vsfstri",
    "scene.clockface",
    "scene.textured_cubes",
    "scene.stringedit_scene",
    "scene.fonttest_scene",
    "scene.shadertoy_scene2",
    "scene.hybrid_scene",
    --"scene.floorquad",
    "scene.touchtris",
    "scene.touch_shader",
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
    if s and Scene.exitGL then
        Scene.exitGL()
    end
    package.loaded[name] = nil
    Scene = nil

    if not Scene then
        Scene = require(name)
        if Scene then
            local now = os.clock()
            -- Instruct the scene where to load data from. Dir is relative to app's working dir.
            local dir = ""
            if ANDROID then
                dir = appDir.."/lua"
            else
                dir = "../data/lua"
            end
            if Scene.setDataDirectory then Scene.setDataDirectory(dir) end
            if Scene.setWindowSize then Scene.setWindowSize(win_w, win_h) end
            Scene.initGL()
            local initTime = os.clock() - now
            print(name.." initGL: "..math.floor(1000*initTime).."ms")
            lastSceneChangeTime = now
        end
    end
end

local function display_scene_overlay()
    if not glfont then return end

    local showTime = 2
    local age = os.clock() - lastSceneChangeTime
    -- TODO a nice fade or something
    if age > showTime then return end

    local m = {}
    local p = {}
    mm.make_identity_matrix(m)
    local s = .5
    mm.glh_scale(m, s, s, s)

    local yoff = 0
    local tin = .15
    local tout = .5
    local yslide = -250
    if age < tin then yoff = yslide * (1-age/tin) end
    if age > showTime - tout then yoff = yslide * (age-(showTime-tout)) end
    mm.glh_translate(m, 30, yoff, 0)
    -- TODO getStringWidth and center text
    mm.glh_ortho(p, 0, win_w, win_h, 0, -1, 1)
    gl.glDisable(GL.GL_DEPTH_TEST)
    glfont:render_string(m, p, scene_modules[scene_module_idx])
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
    Scene.render_for_one_eye(mv, pr)
    if Scene.set_origin_matrix then Scene.set_origin_matrix(mv) end
    display_scene_overlay()
end

function on_lua_initgl(pLoaderFunc)
    print("on_lua_initgl")
    if pLoaderFunc == 0 then
        print("No loader function - initializing GLES 3")
        openGL = require("opengles3")
        ANDROID = true -- an assumption
    else
        --[[
            Now, the GL function loading businesScene...
            Everything in GL 1.2 or older has names in OpenGL32.dll/opengl32.dll (Windows),
            while pointers to all newer functions must be obtained from a loader function.
            Using the wglGetProcAddress provided by that dll will return NULL pointers for
            all the old functionScene. Using glfwGetProcAddress takes care of both cases, but
            pulling it in via the ffi would be a redundant copy of GLFW, and would require
            an init of the second GLFW, which it might not even do. Instead, just pass the
            pointer to to C++ app's GLFW's glfwGetProcAddresScene.

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

    switch_to_scene(scene_modules[scene_module_idx])


    -- Instruct the scene where to load data from. Dir is relative to app's working dir.
    local dir = ""
    if ANDROID then
        dir = appDir.."/lua"
    else
        dir = "../data/lua"
    end
    dir = dir .. "/fonts"
    glfont = GLFont.new('segoe_ui128.fnt', 'segoe_ui128_0.raw')
    glfont:setDataDirectory(dir)
    glfont:initGL()

    if fnt then
        if fnt.setDataDirectory then fnt.setDataDirectory(dir) end
        fnt.initGL()
    end
end

function on_lua_exitgl()
    Scene.exitGL()
    glfont:exitGL()
end

function on_lua_timestep(absTime, dt)
    Scene.timestep(absTime, dt)
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

local pointers = {}
local switched_flag = false

function on_lua_singletouch(pointerid, action, x, y)
    --print("on_lua_singletouch", pointerid, action, x, y)
    if Scene.onSingleTouch then Scene.onSingleTouch(pointerid, action, x, y) end

    pointers[pointerid] = {x=x/win_w, y=y/win_h}

    local actionflag = action % 255
    local a = action_types[actionflag]
    if a == "Up" or a == "PointerUp" then
        pointers[pointerid] = nil
    end

    -- Check for >4 touches active at once to switch scene,
    -- only because it is a very simple conditional.
    local i = 0
    for k,v in pairs(pointers) do
        i = i+1
    end
    if i > 4 then
        if not switched_flag then switch_scene(false) end
        switched_flag = true
    else
        switched_flag = false
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

function on_lua_keypressed(key, scancode, action, mods)

    --TODO: Set some flag in CMake, send it here via a new entry point
    local lookup = kc.glfw_keycodes_map[key]
    --local lookup = kc.sdl_keycodes_map[key]

    if ANDROID then
        lookup = kc.android_keycodes_map[key]
    end
    print("KEY: "..key.." "..scancode.." "..action.." "..mods.." -> "..lookup)

    -- TODO an escape sequence here?
    if key == 298 then -- F9
        connect_to_debugger()
    end

    if action == 1 then
        if Scene.keypressed then
            local consumed = Scene.keypressed(key, scancode, action, mods)
            if consumed then return end
        end

        if Scene.charkeypressed then
            Scene.charkeypressed(string.char(scancode))
        end
    end
end

function on_lua_accelerometer(x,y,z,accuracy)
    if Scene.accelerometer then Scene.accelerometer(x,y,z,accuracy) end
end

function on_lua_setTimeScale(t)
end

function on_lua_setwindowsize(w, h)
    win_w,win_h = w,h
    if Scene.setWindowSize then Scene.setWindowSize(w, h) end
end

function on_lua_changescene(d)
    switch_scene(d ~= 0)
end
