// glfw_main.cpp

#include <iostream>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#if defined(_WIN32)
#  include <Windows.h>
#endif

#include "GL_Includes.h"
#include <GLFW/glfw3.h>

#include "cpp_interface.h"
#include "AndroidTouchEnums.h"
#include "TouchReplayer.h"
#include "Timer.h"
#include "Logging.h"

GLFWwindow* g_pWindow = NULL;
int winw = 800;
int winh = 1000;
bool portrait = true;

TouchReplayer g_trp;
Timer g_playbackTimer;

void initGL()
{
    initScene();
}

void exitGL()
{
    exitScene();
}

void display()
{
    drawScene();
}

void setAppScreenSize()
{
    int w = portrait ? winw : winh;
    int h = portrait ? winh : winw;
    surfaceChangedScene(w, h);
    glfwSetWindowSize(g_pWindow, w, h);
    glViewport(0, 0, w, h);
}

void keyboard(GLFWwindow* pWindow, int key, int codes, int action, int mods)
{
    (void)pWindow;
    (void)codes;

    if (action == GLFW_PRESS)
    {
    switch (key)
    {
        default:
            onKeyEvent(key, codes, action, mods);
            break;

        case GLFW_KEY_F1:
            winw = 1000;
            winh = 800;
            portrait = !portrait;
            setAppScreenSize();
            break;

        case GLFW_KEY_F2:
            winw = 2560/2;
            winh = 1440/2;
            portrait = !portrait;
            setAppScreenSize();
            break;
            
        case GLFW_KEY_F3:
            winw = 2048/2;
            winh = 1440/2;
            portrait = !portrait;
            setAppScreenSize();
            break;

        case GLFW_KEY_F4:
            winw = 640;
            winh = 480;
            portrait = !portrait;
            setAppScreenSize();
            break;

        case GLFW_KEY_ESCAPE:
            glfwSetWindowShouldClose(g_pWindow, GL_TRUE);
            break;
    }
    }
}

void mouseDown(GLFWwindow* pWindow, int button, int action, int mods)
{
    (void)pWindow;
    (void)mods;

    double xd, yd;
    glfwGetCursorPos(pWindow, &xd, &yd);
    const float x = static_cast<float>(xd);
    const float y = static_cast<float>(yd);

    if (button == GLFW_MOUSE_BUTTON_1)
    {
        if (action == GLFW_PRESS)
        {
            onSingleTouchEvent(0, ActionDown, x, y);
        }
        else if (action == GLFW_RELEASE)
        {
            onSingleTouchEvent(0, ActionUp, x, y);
        }
    }
    else if (button == GLFW_MOUSE_BUTTON_RIGHT)
    {
        if (action == GLFW_PRESS)
        {
            onSingleTouchEvent(1, ActionDown, x, y);
        }
        else if (action == GLFW_RELEASE)
        {
            onSingleTouchEvent(1, ActionUp, x, y);
        }
    }
}

void mouseMove(GLFWwindow* pWindow, double xd, double yd)
{
    (void)pWindow;
    const float x = static_cast<float>(xd);
    const float y = static_cast<float>(yd);
    onSingleTouchEvent(0, ActionMove, x, y);
}

void mouseWheel(GLFWwindow* pWindow, double xoffset, double yoffset)
{
    (void)pWindow;
    onWheelEvent(xoffset, yoffset);
}

void resizeWindow(GLFWwindow* pWindow, int w, int h)
{
    (void)pWindow;
    winw = w;
    winh = h;
    surfaceChangedScene(w, h);
}

void drop(GLFWwindow* pWindow, int count, const char** paths)
{
    if (count < 1)
        return;

    const std::string touchFile(paths[0]);
    g_trp.LoadTouchLogFromFile(touchFile);
    g_playbackTimer.reset();
}

void printGLContextInfo(GLFWwindow* pW)
{
    // Print some info about the OpenGL context...
    const int l_Major = glfwGetWindowAttrib(pW, GLFW_CONTEXT_VERSION_MAJOR);
    const int l_Minor = glfwGetWindowAttrib(pW, GLFW_CONTEXT_VERSION_MINOR);
    const int l_Profile = glfwGetWindowAttrib(pW, GLFW_OPENGL_PROFILE);
    if (l_Major >= 3) // Profiles introduced in OpenGL 3.0...
    {
        if (l_Profile == GLFW_OPENGL_COMPAT_PROFILE)
        {
            LOG_INFO("GLFW_OPENGL_COMPAT_PROFILE");
        }
        else
        {
            LOG_INFO("GLFW_OPENGL_CORE_PROFILE");
        }
    }
    (void)l_Minor;
    LOG_INFO("OpenGL: %d.%d\n", l_Major, l_Minor);
    LOG_INFO("Vendor: %s\n", reinterpret_cast<const char*>(glGetString(GL_VENDOR)));
    LOG_INFO("Renderer: %s\n", reinterpret_cast<const char*>(glGetString(GL_RENDERER)));
}

// OpenGL debug callback
void APIENTRY myCallback(
    GLenum source, GLenum type, GLuint id, GLenum severity,
    GLsizei length, const GLchar *msg,
    const void *data)
{
    switch (severity)
    {
    case GL_DEBUG_SEVERITY_HIGH:
    case GL_DEBUG_SEVERITY_MEDIUM:
    case GL_DEBUG_SEVERITY_LOW:
        LOG_INFO("[[GL Debug]] %x %x %x %x %s\n", source, type, id, severity, msg);
        break;
    case GL_DEBUG_SEVERITY_NOTIFICATION:
        break;
    }
}

const char* getStringFromGlfwErrorCode(int code)
{
    switch(code)
    {
        default: return "Unknown code"; break;
        case GLFW_NOT_INITIALIZED: return "GLFW_NOT_INITIALIZED"; break;
        case GLFW_NO_CURRENT_CONTEXT: return "GLFW_NO_CURRENT_CONTEXT"; break;
        case GLFW_INVALID_ENUM: return "GLFW_INVALID_ENUM"; break;
        case GLFW_INVALID_VALUE: return "GLFW_INVALID_VALUE"; break;
        case GLFW_OUT_OF_MEMORY: return "GLFW_OUT_OF_MEMORY"; break;
        case GLFW_API_UNAVAILABLE: return "GLFW_API_UNAVAILABLE"; break;
        case GLFW_VERSION_UNAVAILABLE: return "GLFW_VERSION_UNAVAILABLE"; break;
        case GLFW_PLATFORM_ERROR: return "GLFW_PLATFORM_ERROR"; break;
        case GLFW_FORMAT_UNAVAILABLE: return "GLFW_FORMAT_UNAVAILABLE"; break;
    }
}

void error_callback(int error, const char* description)
{
    LOG_ERROR("Glfw error 0x%x(%s): %s\n", error, getStringFromGlfwErrorCode(error), description);
}

int main(int argc, char** argv)
{
    glfwSetErrorCallback(error_callback);
    LOG_INFO("Compiled against GLFW %i.%i.%i\n",
        GLFW_VERSION_MAJOR,
        GLFW_VERSION_MINOR,
        GLFW_VERSION_REVISION);
    int major, minor, revision;
    glfwGetVersion(&major, &minor, &revision);
    LOG_INFO("Running against GLFW %i.%i.%i\n", major, minor, revision);
    LOG_INFO("glfwGetVersionString: %s\n", glfwGetVersionString());

    GLFWwindow* l_Window = NULL;
    if (!glfwInit())
    {
        exit(EXIT_FAILURE);
    }

    // Context setup - before window creation
    glfwWindowHint(GLFW_DEPTH_BITS, 16);

    bool useGLES = false;
    if (useGLES)
    {
        glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    }
    else
    {
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    }

#ifdef _MACOS
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
//    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

#ifdef _DEBUG
    glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GL_TRUE);
#endif

    l_Window = glfwCreateWindow(winw, winh, "GLFW desktop GL", NULL, NULL);
    if (!l_Window)
    {
        glfwTerminate();
        exit(EXIT_FAILURE);
    }

    major = glfwGetWindowAttrib(l_Window, GLFW_CONTEXT_VERSION_MAJOR);
    minor = glfwGetWindowAttrib(l_Window, GLFW_CONTEXT_VERSION_MINOR);
    revision = glfwGetWindowAttrib(l_Window, GLFW_CONTEXT_REVISION);
    LOG_INFO("OpenGL version received: %d.%d.%d", major, minor, revision);

    g_pWindow = l_Window;

    glfwSetKeyCallback(l_Window, keyboard);
    glfwSetMouseButtonCallback(l_Window, mouseDown);
    glfwSetCursorPosCallback(l_Window, mouseMove);
    glfwSetScrollCallback(l_Window, mouseWheel);
    glfwSetWindowSizeCallback(l_Window, resizeWindow);
#if defined(_WIN32)
    glfwSetDropCallback(l_Window, drop);
#endif
    glfwMakeContextCurrent(l_Window);

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        LOG_ERROR("Failed to initialize OpenGL context");
        return -1;
    }

    if (useGLES)
    {
        ///@todo: GLES requires the KHR_debug extension to set up debug callbacks.
    }
    else
    {
#ifndef _MACOS
        // Debug callback initialization
        // Must be done *after* glew initialization.
        glDebugMessageCallback(myCallback, NULL);
        glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, NULL, GL_TRUE);
        glDebugMessageInsert(GL_DEBUG_SOURCE_APPLICATION, GL_DEBUG_TYPE_MARKER, 0,
            GL_DEBUG_SEVERITY_NOTIFICATION, -1 , "Start debugging");
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
#endif
    }

    printGLContextInfo(l_Window);
    setLoaderFunc((void*)&glfwGetProcAddress);
    initGL();
    surfaceChangedScene(winw, winh);

    while (!glfwWindowShouldClose(l_Window))
    {
        g_trp.PlaybackRecentEvents(g_playbackTimer.seconds(), onSingleTouchEvent);
        glfwPollEvents();
        display();
        glfwSwapBuffers(l_Window);
    }

    exitGL();
    glfwDestroyWindow(l_Window);
    glfwTerminate();
    exit(EXIT_SUCCESS);
}
