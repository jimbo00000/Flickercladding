// TabletWindow.cpp

#include "TabletWindow.h"

#include "DataDirectoryLocation.h"
#include "AndroidTouchEnums.h"
#include "FontMgr.h"
#include "FontRenderer.h"
#include "MatrixMath.h"
#include "VectorMath.h"
#include "Logging.h"
#include <sstream>
#include <fstream>

TabletWindow::TabletWindow()
: m_luaScene()
, m_fps()
, m_logDumpTimer()
, m_iconx(20)
, m_icony(240)
, m_iconScale(1.f)
, m_glVersion()
, m_glRenderer()
, m_glSLVersion()
, m_holding(false)
, m_holdingMask(0)
, m_pointerStates(8)
, m_scaleAtPinchStart(1.f)
, m_lastTouchPoint(0,0)
, m_chassisYaw(0.f)
, m_chassisYawAtTouch(0.f)
, m_movingChassisFlag(false)
{
    m_chassisPos.x = 0.f;
    m_chassisPos.y = -.6f;
    m_chassisPos.z = -5.f;
}

TabletWindow::~TabletWindow()
{
}


void FileWriteTest()
{
    const std::string dataHome = APP_DATA_DIRECTORY;
    const std::string outFilename = dataHome + "writtenFromApp.txt";

    LOG_INFO("Attempting to open file %s", outFilename.c_str());
    std::ofstream ofs;
    ofs.open(outFilename.c_str(), std::ios::out);
    if (ofs.is_open())
    {
        LOG_INFO("Open successful.");
        ofs << "Writing text..." << std::endl;
        ofs.close();
    }
    else
    {
        LOG_ERROR("Could not open");
    }
}

void TabletWindow::initGL()
{
    const std::string v(reinterpret_cast<const char*>(glGetString(GL_VERSION)));
    m_glVersion = v;

    const std::string r(reinterpret_cast<const char*>(glGetString(GL_VENDOR)));
    m_glRenderer = r;

    const std::string s(reinterpret_cast<const char*>(glGetString(GL_RENDERER)));
    m_glSLVersion = s;

    m_tp.initGL();

    const Language lang = USEnglish;
    FontMgr::Instance().LoadLanguageFonts(lang);

    m_luaScene.m_pLoaderFunc = m_pLoaderFunc;
    m_luaScene.initGL();
}

void TabletWindow::exitGL()
{
    m_luaScene.exitGL();
    m_tp.exitGL();
}

void TabletWindow::setWindowSize(int w, int h)
{
    m_winw = w;
    m_winh = h;
    m_luaScene.setWindowSize(w, h);
}

void TabletWindow::_DrawText(int winw, int winh)
{
    float mview[16];
    float proj[16];

    MakeIdentityMatrix(mview);
    // Flip window coordinates vertically so origin is upper-left
    glhOrtho(proj,
        0.f, static_cast<float>(winw),
        static_cast<float>(winh), 0.f,
        -1.f, 1.f);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    const FontRenderer* pFont24 = FontMgr::Instance().GetFontOfSize(24);
    if (pFont24 != NULL)
    {
        const int lineh = 40;
        int y = 40 - lineh;
        const float3 col = {.5f, 1.f, .5f};
        const bool doKerning = true;

        if (m_movingChassisFlag)
        {
            pFont24->DrawWString(
#ifdef __ANDROID__
                L"Flickercladding - Android",
#else
                L"Flickercladding - Desktop",
#endif
                10,
                y += lineh,
                col,
                proj,
                doKerning);

            pFont24->DrawString(
                m_glVersion.c_str(),
                10,
                y += lineh,
                col,
                proj,
                doKerning);

            pFont24->DrawString(
                m_glRenderer.c_str(),
                10,
                y += lineh,
                col,
                proj,
                doKerning);

            pFont24->DrawString(
                m_glSLVersion.c_str(),
                10,
                y += lineh,
                col,
                proj,
                doKerning);
        }

        std::ostringstream oss;
        oss << m_fps.GetFPS() << " fps";
        pFont24->DrawString(
            oss.str().c_str(),
            10,
            y += lineh,
            col,
            proj,
            doKerning);

        const float3 red = { 1.f, .8f, .8f };
        std::string err = m_luaScene.ErrorText();
        const int cols = 40;
        std::string chunk = err.substr(0, cols);
        while (chunk.length() > 0)
        {
            chunk = err.substr(0, cols);
            pFont24->DrawString(
                chunk.c_str(),
                10,
                y += lineh,
                red,
                proj,
                doKerning);
            err = err.substr(chunk.length());
        }
    }
    glDisable(GL_BLEND);
}

void TabletWindow::_DisplayOverlay(int winw, int winh)
{
    _DrawText(winw, winh);

#if 0 //ndef __ANDROID__
    // Draw pointer states
    glPointSize(10.f);
    glDisable(GL_DEPTH_TEST);
    float mview[16];
    float proj[16];
    MakeIdentityMatrix(mview);
    // Flip window coordinates vertically so origin is upper-left
    glhOrtho(proj,
        0.f, static_cast<float>(winw),
        static_cast<float>(winh), 0.f,
        -1.f, 1.f);

    m_tp.display(mview, proj, m_pointerStates);
#endif
}

///@brief draws a 3D scene from a camera location
void TabletWindow::_DisplayScene(int winw, int winh)
{
    float mvmtx[16];
    float prmtx[16];
    MakeIdentityMatrix(mvmtx);

    glhTranslate(mvmtx, m_chassisPos.x, m_chassisPos.y, m_chassisPos.z);

    glhRotate(mvmtx, m_chassisYaw, 0.f, 1.f, 0.f);

    glhPerspectivef2(prmtx,
        80.f,
        static_cast<float>(winw) / static_cast<float>(winh),
        .1f, 100.f);

    m_luaScene.RenderForOneEye(mvmtx, prmtx);
}

void TabletWindow::display(int winw, int winh)
{
    glViewport(0, 0, winw, winh);
    const float g = .1f;
    glClearColor(g, g, g, 0.f);
    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    _DisplayScene(winw, winh);

    glDisable(GL_DEPTH_TEST);
    _DisplayOverlay(winw, winh);
}

void TabletWindow::timestep(double absT, double dt)
{
    m_fps.OnFrame();

#if 1
    // Log fps at regular intervals
    const float dumpInterval = 1.f;
    if (m_logDumpTimer.seconds() > dumpInterval)
    {
        LOG_INFO("Frame rate: %d fps", static_cast<int>(m_fps.GetFPS()));
        m_logDumpTimer.reset();
}
#endif

    m_luaScene.timestep(absT, dt);
}

int getNumPointersDown(int mask)
{
    int num = 0;
    const int maxPointers = 10;
    for (int i=0; i<maxPointers; ++i)
    {
        const int flag = 1 << i;
        if ((mask & flag) != 0)
            ++num;
    }
    return num;
}

void TabletWindow::OnSingleTouch(int pointerid, int action, int x, int y)
{
    const int actionflag = action & 0xff;

    if (m_movingChassisFlag == false)
    {
        m_luaScene.onSingleTouch(pointerid, actionflag, x, y);
    }

    const int pointerflag = 1 << pointerid;

    if (pointerid >= m_pointerStates.size())
        return;

    touchState& ts = m_pointerStates[pointerid];
    ts.state = actionflag;
    ts.x = x;
    ts.y = y;

    if (actionflag == ActionDown) {
        m_holdingMask |= pointerflag;
        m_chassisPosAtTouch = m_chassisPos;
        m_chassisYawAtTouch = m_chassisYaw;
        m_lastTouchPoint = int2( x,y );
    }
    else if (actionflag == ActionPointerDown) {
        m_holdingMask |= pointerflag;
        // Get current pinch size
        m_chassisPosAtTouch = m_chassisPos;
    }
    else if (actionflag == ActionUp) {
        m_holdingMask &= ~pointerflag;
    }
    else if (actionflag == ActionPointerUp) {
        m_holdingMask &= ~pointerflag;
        if (getNumPointersDown(m_holdingMask) == 1)
        {
            m_scaleAtPinchStart *= m_iconScale;
            m_iconScale = 1.f;
        }
    }

    // Handle a pinch event
    if (actionflag == ActionPointerDown)
    {
        if (getNumPointersDown(m_holdingMask) == 2)
        {
            const touchState& p0 = m_pointerStates[0];
            const touchState& p1 = m_pointerStates[1];
            m_pinchStart.first = p0;
            m_pinchStart.second = p1;

            // Check for double touch on lower corners of screen
            const touchState& leftPt = p0.x < p1.x ? p0 : p1;
            const touchState& rightPt = p0.x < p1.x ? p1 : p0;
            const int xm = m_winw / 10;
            const int ym = m_winh / 10;
            if (
                (leftPt.x < xm) &&
                (leftPt.y > m_winh - ym) &&
                (rightPt.x > m_winw - xm) &&
                (rightPt.y > m_winh - ym)
                )
            {
                m_movingChassisFlag = !m_movingChassisFlag;
            }
        }
    }
    else if (actionflag == ActionMove)
    {
        if (getNumPointersDown(m_holdingMask) == 2)
        {
            if (m_movingChassisFlag)
            {
                const touchState& t0 = m_pinchStart.first;
                const touchState& t1 = m_pinchStart.second;
                const float3 a0 = { static_cast<float>(t0.x),static_cast<float>(t0.y),0 };
                const float3 a1 = { static_cast<float>(t1.x),static_cast<float>(t1.y),0 };
                const float initialDist = length(a1 - a0);
                const touchState& u0 = m_pointerStates[0];
                const touchState& u1 = m_pointerStates[1];
                const float3 b0 = { static_cast<float>(u0.x),static_cast<float>(u0.y),0 };
                const float3 b1 = { static_cast<float>(u1.x),static_cast<float>(u1.y),0 };
                const float curDist = length(b1 - b0);
                if (initialDist != 0.f)
                {
                    //m_iconScale = curDist / initialDist;
                    const float dz = .02f * (curDist - initialDist);
                    m_chassisPos.z = m_chassisPosAtTouch.z + dz;
                }
            }
        }
    }



    if (m_holdingMask == 1)
    {
        if (getNumPointersDown(m_holdingMask) == 1)
        {
            if ((actionflag == ActionDown) || (actionflag == ActionMove))
            {
                if (m_movingChassisFlag)
                {
                    const int dx = x - m_lastTouchPoint.x;
                    const int dy = y - m_lastTouchPoint.y;
                    //m_chassisPos.x = m_chassisPosAtTouch.x + (.01f * (float)dx);
                    m_chassisPos.y = m_chassisPosAtTouch.y - (.01f * (float)dy);
                    m_chassisYaw = m_chassisYawAtTouch + (.1f * (float)dx);
                }
            }
        }
    }

}

void TabletWindow::OnWheelEvent(double dx, double dy)
{
    m_chassisPos.z += .4f * dy;
}

void TabletWindow::onKeyEvent(int key, int codes, int action, int mods)
{
    m_luaScene.keypressed(key);

    switch (key)
    {
    default: break;

    case 258: // Tab in GLFW3
    case 9: // Tab in SDL2
        m_luaScene.ChangeScene(1);
        break;

    case 96: // ` in SDL2
        m_movingChassisFlag = !m_movingChassisFlag;
        break;

    case 1073741886: // F5 in SDL2
        // Refresh Lua state
        m_luaScene.exitLua();
        m_luaScene.initGL();
        m_luaScene.setWindowSize(m_winw, m_winh);
        break;
    }
}
