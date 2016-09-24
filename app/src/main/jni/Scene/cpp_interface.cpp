// cpp_interface.cpp

#include "cpp_interface.h"

#include "TabletWindow.h"
#include "shader_utils.h"
#include "Logging.h"

int g_winw;
int g_winh;
TabletWindow g_window;
Timer g_timer;
double g_lastFrameTime = 0.;

bool initScene()
{
    LOG_INFO("initScene()");
    printSomeGLInfo();

    g_window.initGL();
    g_timer.reset();

    return true;
}

void surfaceChangedScene(int w, int h)
{
    LOG_INFO("setupGraphics(%d, %d)", w, h);
    g_winw = w;
    g_winh = h;
}

void drawScene()
{
    g_window.display(g_winw, g_winh);
    const double now = g_timer.seconds();
    g_window.timestep(now, now - g_lastFrameTime);
    g_lastFrameTime = now;
}

void onSingleTouchEvent(int pointerid, int action, float x, float y)
{
    LOG_INFO("onSingleTouchEvent( @%f: %d, %d, %f, %f)\n", g_timer.seconds(), pointerid, action, x, y);
    g_window.OnSingleTouch(pointerid, action, x, y);
}

void onWheelEvent(double dx, double dy)
{
    g_window.OnWheelEvent(dx, dy);
}

void setLoaderFunc(void* pFunc)
{
    g_window.m_pLoaderFunc = pFunc;
}
