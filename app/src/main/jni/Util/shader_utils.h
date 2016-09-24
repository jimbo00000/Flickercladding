// shader_utils.h

#pragma once

#include "GL_Includes.h"

void printGLString(const char *name, GLenum s);
void checkGlError(const char* op);
void printSomeGLInfo();

GLuint loadShader(GLenum shaderType, const char* pSource);
GLuint createProgram(const char* pVertexSource, const char* pFragmentSource);

