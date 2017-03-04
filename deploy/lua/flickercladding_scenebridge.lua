-- flickercladding_scenebridge.lua
print(jit.version, jit.os, jit.arch)

local appDir = "/sdcard/Android/data/com.android.flickercladding"
package.path = appDir.."/lua/?.lua;" .. package.path
package.path = "../deploy/lua/?.lua;" .. package.path

local ffi = require("ffi")
local openGL -- @todo select GL or GLES header

local clock = os.clock

local Scene = nil
require("util.glfont")
local mm = require("util.matrixmath")
local kc = require("util.glfw_keycodes")
local snd = require("util.soundfx")

local ANDROID = false
local win_w,win_h = 800,800
local lastSceneChangeTime = 0

local scenedir = "scene"

function switch_to_scene(name)
    local fullname = scenedir.."."..name
    if Scene and Scene.exitGL then
        Scene:exitGL()
    end
    -- Do we need to unload the module?
    package.loaded[fullname] = nil
    Scene = nil

    if not Scene then
        SceneLibrary = require(fullname)
        Scene = SceneLibrary.new()
        if Scene then
            local now = clock()
            -- Instruct the scene where to load data from. Dir is relative to app's working dir.
            local dir = ""
            if ANDROID then
                dir = appDir.."/data"
            else
                dir = "../deploy/data"
            end
            if Scene.setDataDirectory then Scene:setDataDirectory(dir) end
            if Scene.setWindowSize then Scene:setWindowSize(win_w, win_h) end
            Scene:initGL()
            local initTime = clock() - now
            lastSceneChangeTime = now
            collectgarbage()
            print(name,
                "init time: "..math.floor(1000*initTime).." ms",
                "memory: "..math.floor(collectgarbage("count")).." kB")
        end
    end
end

local scene_modules = {
    "key_check",
    "shadertoy_editor",
    "clockface",
    "droid",
    "colorcube",
    "font_test",
    "eyetest",
    "julia_set",
    "hybrid_scene",
    "cubemap",
    "moon",
    "nbody07",
    "multipass_example",
    "molecule",
    "simple_game",

--[[
   "scene.postprocessingslides_scene",
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
    ]]
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

    snd.playSound("pop_drip.wav")
end

local function display_scene_overlay()
    if not glfont then return end

    local showTime = 2
    local age = clock() - lastSceneChangeTime
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
    Scene:render_for_one_eye(mv, pr)
    if Scene.set_origin_matrix then Scene:set_origin_matrix(mv) end
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

    switch_to_scene(scene_modules[scene_module_idx])


    -- Instruct the scene where to load data from. Dir is relative to app's working dir.
    local dir = ""
    if ANDROID then
        dir = appDir.."/data"
    else
        dir = "../deploy/data"
    end

    glfont = GLFont.new('segoe_ui128.fnt', 'segoe_ui128_0.raw')
    glfont:setDataDirectory(dir.."/fonts")
    glfont:initGL()

    snd.setDataDirectory(dir)

    if fnt then
        if fnt.setDataDirectory then fnt.setDataDirectory(dir) end
        fnt.initGL()
    end
end

function on_lua_exitgl()
    Scene:exitGL()
    glfont:exitGL()
end

function on_lua_timestep(absTime, dt)
    if Scene.timestep then Scene:timestep(absTime, dt) end
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
    if Scene.onSingleTouch then Scene:onSingleTouch(pointerid, action, x, y) end

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

local function is_printable(code)
    if code < 0x20 then return false end
    if code > 0x7e then return false end
    return true
end

local keymap_glfw = {
    [39] = {'"', "'"},
    [44] = {'<', ','},
    [46] = {'>', '.'},
    [47] = {'?', '/'},
    [59] = {':', ';'},
    [65] = {'A', 'a'},
    [66] = {'B', 'b'},
    [67] = {'C', 'c'},
    [68] = {'D', 'd'},
    [69] = {'E', 'e'},
    [70] = {'F', 'f'},
    [71] = {'G', 'g'},
    [72] = {'H', 'h'},
    [73] = {'I', 'i'},
    [74] = {'J', 'j'},
    [75] = {'K', 'k'},
    [76] = {'L', 'l'},
    [77] = {'M', 'm'},
    [78] = {'N', 'n'},
    [79] = {'O', 'o'},
    [80] = {'P', 'p'},
    [81] = {'Q', 'q'},
    [82] = {'R', 'r'},
    [83] = {'S', 's'},
    [84] = {'T', 't'},
    [85] = {'U', 'u'},
    [86] = {'V', 'v'},
    [87] = {'W', 'w'},
    [88] = {'X', 'x'},
    [89] = {'Y', 'y'},
    [90] = {'Z', 'z'},
    [91] = {'{', '['},
    [92] = {'|', '\\'},
    [93] = {'}', ']'},
}

local function map_keycode(key, mods)
    -- Platform dependent bits for modifiers
    local shift = 1
    if ANDROID then shift = 65 end
    local shiftheld = bit.band(mods,shift) ~= shift
    local sh12 = 1
    if shiftheld then sh12 = 2 end

    local keymap = keymap_glfw
    if keymap[key] then
        return string.byte(keymap[key][sh12])
    end

    return key
end

function on_lua_keypressed(key, scancode, action, mods)
    local shift = 1
    local ctrl = 2
    if ANDROID then
        shift = 65
        ctrl = 12288

        -- Android udlr 19,20,21,22
        if scancode == 19 then key = 265 end
        if scancode == 20 then key = 264 end
        if scancode == 21 then key = 263 end
        if scancode == 22 then key = 262 end
        if scancode == 67 then key = 259 end -- bksp
        if scancode == 66 then key = 257 end -- enter
    end

    -- TODO an escape sequence here?
    if key == 298 then -- F9
        connect_to_debugger()
    end

    if action == 1 then
        -- Check for scene switch
        if bit.band(mods,ctrl) ~= 0 then
            if key == 9 or key == 258 or scancode == 61 then
                switch_scene(bit.band(mods,shift) ~= 0)
            end
        end

        if Scene.keypressed then
            local consumed = Scene:keypressed(key, scancode, action, mods)
            if key == 96 then return end -- toggle with ` handled in Scene

            local ch = map_keycode(key, mods)
            if is_printable(ch) then
                Scene:charkeypressed(string.char(ch))
            end

            if consumed then return end
        end

        if Scene.charkeypressed then
            --Scene:charkeypressed(string.char(scancode))
        end
    elseif action == 0 then
        if Scene.keyreleased then
            Scene:keyreleased(key, scancode, action, mods)
        end
    end
end

function on_lua_accelerometer(x,y,z,accuracy)
    if Scene.accelerometer then Scene:accelerometer(x,y,z,accuracy) end
end

function on_lua_setTimeScale(t)
end

function on_lua_setwindowsize(w, h)
    win_w,win_h = w,h
    if Scene.setWindowSize then Scene:setWindowSize(w, h) end
end

function on_lua_changescene(d)
    switch_scene(d ~= 0)
end
