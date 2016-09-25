// sdl_main.cpp

#ifdef _WIN32
#  define WINDOWS_LEAN_AND_MEAN
#  define NOMINMAX
#  include <windows.h>
#endif

#include "GL_Includes.h"

#include "cpp_interface.h"
#include "AndroidTouchEnums.h"
#include "TouchReplayer.h"
#include "Timer.h"
#include "Logging.h"

#include <SDL.h>
#undef main

SDL_Window* g_pWindow = NULL;
int winw = 800;
int winh = 800;
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
    SDL_SetWindowSize(g_pWindow, w, h);
    glViewport(0, 0, w, h);
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

bool init()
{
    if (SDL_Init(SDL_INIT_EVERYTHING) < 0)
        return false;

    g_pWindow = SDL_CreateWindow(
        "GL Skeleton - SDL2",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        winw, winh,
        SDL_WINDOW_SHOWN | SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (g_pWindow == NULL)
    {
        LOG_ERROR("%s\n", SDL_GetError());
        SDL_Quit();
    }

    // thank you http://www.brandonfoltz.com/2013/12/example-using-opengl-3-0-with-sdl2-and-glew/
    SDL_GLContext glContext = SDL_GL_CreateContext(g_pWindow);
    if (glContext == NULL)
    {
        printf("There was an error creating the OpenGL context!\n");
        return 0;
    }

    SDL_GL_MakeCurrent(g_pWindow, glContext);

    //SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    //SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);

    return true;
}

void drop(const char* path)
{
    if (path == NULL)
        return;

    const std::string touchFile(path);
    g_trp.LoadTouchLogFromFile(touchFile);
    g_playbackTimer.reset();

    //SDL_free(path);
}

int main(int argc, char *argv[])
{
    if (init() == false)
        return 1;

    if (!gladLoadGLLoader((GLADloadproc)SDL_GL_GetProcAddress))
    {
        LOG_ERROR("Failed to initialize OpenGL context");
        return -1;
    }

    setLoaderFunc((void*)&SDL_GL_GetProcAddress);
    initGL();
    surfaceChangedScene(winw, winh);

    SDL_Event event;
    int quit = 0;
    while (quit == 0)
    {
        g_trp.PlaybackRecentEvents(g_playbackTimer.seconds(), onSingleTouchEvent);

        const int w = portrait ? winw : winh;
        const int h = portrait ? winh : winw;

        while (SDL_PollEvent(&event))
        {
            switch (event.type)
            {
            default: break;

            case SDL_KEYDOWN:
            {
                if (event.key.keysym.sym == SDLK_ESCAPE)
                    quit = 1;

                if (event.key.keysym.sym  == SDLK_F1)
                {
                    winw = 1000;
                    winh = 800;
                    portrait = !portrait;
                    setAppScreenSize();
                }

                onKeyEvent(event.key.keysym.sym, 0, event.key.state, event.key.keysym.mod);
            }
            break;

            case SDL_MOUSEBUTTONDOWN:
            {
                onSingleTouchEvent(0, ActionDown, event.motion.x, event.motion.y);
            }
            break;

            case SDL_MOUSEBUTTONUP:
            {
                onSingleTouchEvent(0, ActionUp, event.motion.x, event.motion.y);
            }
            break;

            case  SDL_MOUSEWHEEL:
            {
                onWheelEvent(event.wheel.x, event.wheel.y);
            }
            break;

            case SDL_MOUSEMOTION:
            {
                onSingleTouchEvent(0, ActionMove, event.motion.x, event.motion.y);
            }
            break;

            case SDL_FINGERDOWN:
                {
                    const float ex = event.tfinger.x * (float)w;
                    const float ey = event.tfinger.y * (float)h;
                    onSingleTouchEvent(event.tfinger.fingerId, ActionDown, ex, ey);
                }
                break;

            case SDL_FINGERUP:
                {
                    const float ex = event.tfinger.x * (float)w;
                    const float ey = event.tfinger.y * (float)h;
                    onSingleTouchEvent(event.tfinger.fingerId, ActionUp, ex, ey);
                }
                break;

            case SDL_FINGERMOTION:
                {
                    const float ex = event.tfinger.x * (float)w;
                    const float ey = event.tfinger.y * (float)h;
                    onSingleTouchEvent(event.tfinger.fingerId, ActionMove, ex, ey);
                }
                break;

            case SDL_WINDOWEVENT_RESIZED:
                break;

            case SDL_DROPFILE:
                drop(event.drop.file);
                break;

            case SDL_QUIT:
            {
                quit = 1;
            }
            break;
            }
        }

        display();
        SDL_GL_SwapWindow(g_pWindow);
    }

    SDL_Quit();
    return 0;
}
