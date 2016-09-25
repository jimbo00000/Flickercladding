// LuajitScene.cpp

#include "LuajitScene.h"
#include "DataDirectoryLocation.h"
#include "Logging.h"

#ifdef USE_SIXENSE
#include <sixense.h>
#include <sixense_utils/controller_manager/controller_manager.hpp>
#endif // USE_SIXENSE

LuajitScene::LuajitScene()
: m_pLoaderFunc(NULL)
, m_Lua(NULL)
, m_errorOccurred(false)
, m_errorText()
, m_changeSceneOnNextTimestep(false)
, m_queuedEvents()
{
}

LuajitScene::~LuajitScene()
{
    exitLua();
}

void LuajitScene::exitLua()
{
    if (m_Lua != NULL)
    {
        lua_close(m_Lua);
    }
    m_errorOccurred = false;
    m_errorText = "";
}

int LuajitScene::SetSceneName(const std::string& sceneName)
{
    lua_State *L = m_Lua;
    lua_getglobal(L, "on_lua_setscene");
    lua_pushlstring(L, sceneName.c_str(), sceneName.length());
    if (lua_pcall(L, 1, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_setscene': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
        return 1;
    }
    return 0;
}

// http://stackoverflow.com/questions/4508119/redirecting-redefining-print-for-embedded-lua
static int l_my_print(lua_State* L) {
    int nargs = lua_gettop(L);

    for (int i=1; i <= nargs; i++) {
        if (lua_isstring(L, i)) {
            /* Pop the next arg using lua_tostring(L, i) and do your print */
            const char* pStr = lua_tostring(L, i);
            LOG_INFO("LuaJIT> %s", pStr);
        }
        else {
            /* Do something with non-strings if you like */
        }
    }

    return 0;
}

static const struct luaL_Reg printlib [] = {
    {"print", l_my_print},
    {NULL, NULL} /* end of array */
};

extern void luaopen_luamylib(lua_State *L)
{
    lua_getglobal(L, "_G");
    luaL_register(L, NULL, printlib);
    lua_pop(L, 1);
}

void LuajitScene::initGL()
{
    LOG_INFO("--- Lua ---");

    m_Lua = luaL_newstate();
    luaL_openlibs(m_Lua);
    if (m_Lua == NULL)
        return;

    lua_State *L = m_Lua;
    luaopen_luamylib(L);

    const std::string dataHome = APP_DATA_DIRECTORY;
    const std::string scriptName = dataHome + "lua/luaentry.lua";
    if (luaL_dofile(L, scriptName.c_str()))
    {
        const std::string out(lua_tostring(L, -1));
        LOG_INFO("Error in scenebridge: %s", out.c_str());
        m_errorOccurred = true;
        m_errorText += out;
    }

    lua_getglobal(L, "on_lua_initgl");
    // Pass in a (GL function loader) function pointer. See scenebridge.lua.
    lua_Number LpLoaderFunc = (double)((intptr_t)m_pLoaderFunc);
    lua_pushnumber(L, LpLoaderFunc);
    if (lua_pcall(L, 1, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_initgl': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
    }

#ifdef _LINUX
    lua_getglobal(L, "on_lua_setTimeScale");
    lua_Number LtimeScale = .1;
    lua_pushnumber(L, LtimeScale);
    if (lua_pcall(L, 1, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_keypressed': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
    }
#endif
}

void LuajitScene::exitGL()
{
    if (m_Lua == NULL)
        return;

    lua_State *L = m_Lua;
    lua_getglobal(L, "on_lua_exitgl");
    if (lua_pcall(L, 0, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_exitgl': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
    }
}

void LuajitScene::keypressed(int key)
{
    if (m_errorOccurred == true)
        return;

    if (m_bDraw == false)
        return;

    if (m_Lua == NULL)
        return;

    lua_State *L = m_Lua;
    lua_getglobal(L, "on_lua_keypressed");
    lua_Number LabsTime = key;
    lua_pushnumber(L, LabsTime);
    if (lua_pcall(L, 1, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_keypressed': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
    }
}

void LuajitScene::timestep(double absTime, double dt)
{
    if (m_errorOccurred == true)
        return;

    if (m_bDraw == false)
        return;

    if (m_Lua == NULL)
        return;

    lua_State *L = m_Lua;
    lua_getglobal(L, "on_lua_timestep");
    lua_Number LabsTime = absTime;
    lua_Number Ldt = dt;
    lua_pushnumber(L, LabsTime);
    lua_pushnumber(L, Ldt);
    if (lua_pcall(L, 2, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_timestep': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
    }

    if (m_queuedEvents.empty() == false)
    {
        while (m_queuedEvents.empty() == false)
        {
            const queuedTouchEvent e = m_queuedEvents.front();
            lua_getglobal(L, "on_lua_singletouch");
            lua_pushinteger(L, e.pointerid);
            lua_pushinteger(L, e.action);
            lua_pushinteger(L, e.x);
            lua_pushinteger(L, e.y);
            if (lua_pcall(L, 4, 0, 0) != 0)
            {
                LOG_INFO("Error running function `on_lua_singletouch': %s", lua_tostring(L, -1));
                m_errorOccurred = true;
            }

            m_queuedEvents.pop();
        }
    }

    if (m_changeSceneOnNextTimestep)
    {
        lua_getglobal(L, "on_lua_changescene");
        lua_pushinteger(L, 1);
        if (lua_pcall(L, 1, 0, 0) != 0)
        {
            LOG_INFO("Error running function `on_lua_changescene': %s", lua_tostring(L, -1));
            m_errorOccurred = true;
        }

        m_changeSceneOnNextTimestep = false;
    }

}

#ifdef USE_SIXENSE
void createHydraTable(const sixenseControllerData& cd, lua_State *L, int idx, float* mtx)
{
    if (mtx != NULL)
    {
        mtx[0] = cd.rot_mat[0][0];
        mtx[1] = cd.rot_mat[0][1];
        mtx[2] = cd.rot_mat[0][2];
        mtx[3] = 0.0f;
        mtx[4] = cd.rot_mat[1][0];
        mtx[5] = cd.rot_mat[1][1];
        mtx[6] = cd.rot_mat[1][2];
        mtx[7] = 0.0f;
        mtx[8] = cd.rot_mat[2][0];
        mtx[9] = cd.rot_mat[2][1];
        mtx[10] = cd.rot_mat[2][2];
        mtx[11] = 0.0f;
        const float posS = 0.001f; // These units are apparently millimeters
        mtx[12] = cd.pos[0] * posS;
        mtx[13] = cd.pos[1] * posS;
        mtx[14] = cd.pos[2] * posS;
        mtx[15] = 1.0f;
    }

    lua_pushnumber(L, idx);
    lua_createtable(L, 0, 3);

    lua_pushlightuserdata(L, (void*)(mtx));
    lua_setfield(L, -2, "mtx");

    lua_pushnumber(L, cd.joystick_x);
    lua_setfield(L, -2, "joystick_x");
    lua_pushnumber(L, cd.joystick_y);
    lua_setfield(L, -2, "joystick_y");
    lua_pushnumber(L, cd.trigger);
    lua_setfield(L, -2, "trigger");
    lua_pushnumber(L, cd.which_hand);
    lua_setfield(L, -2, "which_hand");
    lua_pushnumber(L, cd.buttons);
    lua_setfield(L, -2, "buttons");

    lua_pushnumber(L, cd.firmware_revision);
    lua_setfield(L, -2, "firmware_revision");

    lua_pushnumber(L, cd.sequence_number);
    lua_setfield(L, -2, "sequence_number");

    lua_pushnumber(L, cd.sequence_number);
    lua_setfield(L, -2, "sequence_number");

    lua_pushnumber(L, cd.sequence_number);
    lua_setfield(L, -2, "sequence_number");

    lua_pushnumber(L, cd.sequence_number);
    lua_setfield(L, -2, "sequence_number");

    lua_pushnumber(L, cd.hardware_revision);
    lua_setfield(L, -2, "hardware_revision");

    lua_pushnumber(L, cd.packet_type);
    lua_setfield(L, -2, "packet_type");

    lua_pushnumber(L, cd.magnetic_frequency);
    lua_setfield(L, -2, "magnetic_frequency");

    lua_pushnumber(L, cd.sequence_number);
    lua_setfield(L, -2, "sequence_number");

    lua_pushnumber(L, cd.enabled);
    lua_setfield(L, -2, "enabled");

    lua_pushnumber(L, cd.controller_index);
    lua_setfield(L, -2, "controller_index");

    lua_pushnumber(L, cd.is_docked);
    lua_setfield(L, -2, "is_docked");

    lua_pushnumber(L, cd.hemi_tracking_enabled);
    lua_setfield(L, -2, "hemi_tracking_enabled");

    lua_settable(L, -3);
}

void LuajitScene::setTracking_Hydra(double absTime, const void* pData) ///@todo Hydra state
{
    if (m_errorOccurred == true)
        return;

    if (m_bDraw == false)
        return;

    if (m_Lua == NULL)
        return;

    lua_State *L = m_Lua;
    lua_getglobal(L, "on_lua_settracking");
    lua_Number LabsTime = absTime;
    lua_pushnumber(L, LabsTime);

    std::vector<std::vector<float> > matrices;
    lua_createtable(L, 2, 0);
    {
        const sixenseAllControllerData* acd = reinterpret_cast<const sixenseAllControllerData*>(pData);
        if (acd != NULL)
        {
            const int maxControllers = sixenseGetMaxControllers();
            matrices.resize(maxControllers);
            for (int c = 0; c < maxControllers; c++)
            {
                if (!sixenseIsControllerEnabled(c))
                    continue;
                matrices[c].resize(16);
                createHydraTable(acd->controllers[c], L, c+1, &matrices[c][0]);
            }
        }
    }

    if (lua_pcall(L, 2, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_settracking': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
    }
}
#else
// Silence linker error
void LuajitScene::setTracking_Hydra(double absTime, const void* pData) {}
#endif // USE_SIXENSE


#ifdef USE_OPENVR
#include <openvr.h>

void createViveWandTable(lua_State *L, int idx, const float* mtx, const vr::VRControllerState_t* pState)
{
    if (L == NULL)
        return;
    if (mtx == NULL)
        return;
    if (pState == NULL)
        return;

    lua_pushnumber(L, idx);
    lua_createtable(L, 0, 3);

    lua_pushlightuserdata(L, (void*)(mtx));
    lua_setfield(L, -2, "mtx");

    const uint64_t pressed = pState->ulButtonPressed;
    const uint32_t lo = (uint32_t)(pressed >> 32);
    const uint32_t hi = (uint32_t)pressed;
    lua_pushnumber(L, lo);
    lua_setfield(L, -2, "ulButtonPressedLo");
    lua_pushnumber(L, hi);
    lua_setfield(L, -2, "ulButtonPressedHi");

    lua_pushnumber(L, pState->ulButtonTouched);
    lua_setfield(L, -2, "ulButtonTouched");

    const vr::VRControllerAxis_t& ax0 = pState->rAxis[0];
    lua_pushnumber(L, ax0.x);
    lua_setfield(L, -2, "ax0x");
    lua_pushnumber(L, ax0.y);
    lua_setfield(L, -2, "ax0y");


    lua_settable(L, -3);
}

void LuajitScene::setTracking_ViveWand(double absTime, int idx, const void* pPose, const void* pState)
{
    if (m_errorOccurred == true)
        return;

    if (m_bDraw == false)
        return;

    if (m_Lua == NULL)
        return;

    lua_State *L = m_Lua;
    lua_getglobal(L, "on_lua_settracking");
    lua_Number LabsTime = absTime;
    lua_pushnumber(L, LabsTime);

    std::vector<std::vector<float> > matrices;
    lua_createtable(L, 2, 0);
    {
        std::vector<std::vector<float> > matrices;
        matrices.resize(2);
        const vr::VRControllerState_t* ps = reinterpret_cast<const vr::VRControllerState_t*>(pState);
        if (ps != NULL)
        {
            createViveWandTable(L, idx, reinterpret_cast<const float*>(pPose), ps);
        }
    }

    if (lua_pcall(L, 2, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_settracking': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
    }
}
#else
void LuajitScene::setTracking_ViveWand(double absTime, int idx, const void* pPose, const void* pState) {}
#endif

void LuajitScene::RenderForOneEye(const float* pMview, const float* pPersp) const
{
    if (m_errorOccurred == true)
        return;

    if (m_bDraw == false)
        return;

    if (m_Lua == NULL)
        return;

    lua_State *L = m_Lua;
    lua_getglobal(L, "on_lua_draw");
    lua_pushlightuserdata(L, (void*)(pMview));
    lua_pushlightuserdata(L, (void*)(pPersp));
    if (lua_pcall(L, 2, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_draw': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
    }
}


void LuajitScene::onSingleTouch(int pointerid, int action, int x, int y)
{
    if (m_errorOccurred == true)
        return;

    if (m_bDraw == false)
        return;

    if (m_Lua == NULL)
        return;

    lua_State *L = m_Lua;

#if 1
    queuedTouchEvent e = {pointerid, action, x, y};
    m_queuedEvents.push(e);
#else
    lua_getglobal(L, "on_lua_singletouch");
    lua_pushinteger (L, pointerid);
    lua_pushinteger (L, action);
    lua_pushinteger (L, x);
    lua_pushinteger (L, y);
    if (lua_pcall(L, 4, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_singletouch': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
    }
#endif
}

// Check for hits against floor plane
bool LuajitScene::RayIntersects(
    const float* pRayOrigin,
    const float* pRayDirection,
    float* pTParameter, // [inout]
    float* pHitLocation, // [inout]
    float* pHitNormal // [inout]
    ) const
{
    return false; ///@todo
}

void LuajitScene::setWindowSize(int w, int h)
{
    if (m_errorOccurred == true)
        return;

    if (m_bDraw == false)
        return;

    if (m_Lua == NULL)
        return;

    lua_State *L = m_Lua;

    lua_getglobal(L, "on_lua_setwindowsize");
    lua_pushinteger(L, w);
    lua_pushinteger(L, h);
    if (lua_pcall(L, 2, 0, 0) != 0)
    {
        LOG_INFO("Error running function `on_lua_setwindowsize': %s", lua_tostring(L, -1));
        m_errorOccurred = true;
    }
}

void LuajitScene::ChangeScene(int d)
{
    if (m_errorOccurred == true)
        return;

    if (m_bDraw == false)
        return;

    if (m_Lua == NULL)
        return;

    m_changeSceneOnNextTimestep = true;
}
