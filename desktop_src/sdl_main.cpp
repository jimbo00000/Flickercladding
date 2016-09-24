// sdl_main.cpp

#ifdef _WIN32
#  define WINDOWS_LEAN_AND_MEAN
#  define NOMINMAX
#  include <windows.h>
#endif
#include "Logger.h"

#include <SDL.h>
#undef main

const int SCREEN_WIDTH = 640;
const int SCREEN_HEIGHT = 480;
const int SCREEN_BPP = 32;

SDL_Window* g_pWindow = NULL;

void display()
{
    SDL_GL_SwapWindow(g_pWindow);
}

bool init()
{
    if (SDL_Init(SDL_INIT_EVERYTHING) < 0)
        return false;

    g_pWindow = SDL_CreateWindow(
        "GL Skeleton - SDL2",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        SCREEN_WIDTH, SCREEN_HEIGHT,
        SDL_WINDOW_SHOWN | SDL_WINDOW_OPENGL);
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


bool initGL(int argc, char **argv)
{
    return true;// g_app.initGL(argc, argv);
}

int main(int argc, char *argv[])
{
    if (init() == false)
        return 1;

    if (!initGL(argc, argv))
        return 0;

    SDL_Event event;
    int quit = 0;
    while (quit == 0)
    {
        while (SDL_PollEvent(&event))
        {
            if (event.type == SDL_KEYDOWN)
            {
                if (event.key.keysym.sym == SDLK_ESCAPE)
                    quit = 1;
            }
            else if (event.type == SDL_MOUSEBUTTONDOWN)
            {
                //g_app.mouseDown(event.button.button, event.button.state, event.button.x, event.button.y);
            }
            else if (event.type == SDL_MOUSEMOTION)
            {
                //g_app.mouseMove(event.motion.x, event.motion.y);
            }
            else if (event.type == SDL_QUIT)
            {
                quit = 1;
            }
        }

        display();
    }

    SDL_Quit();
    return 0;
}
