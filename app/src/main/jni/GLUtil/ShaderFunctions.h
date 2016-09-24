// ShaderFunctions.h

#pragma once

#include "GL_Includes.h"

#include <string>
typedef char GLchar;

GLint getUniLoc(const GLuint program, const GLchar *name);
void  printShaderInfoLog(GLuint obj);
void  printProgramInfoLog(GLuint obj);

const std::string GetShaderSource(const char* filename);
GLuint loadShaderFile(const char* filename, const unsigned long Type);
GLuint makeShaderByName(const char* name);

GLuint makeShaderFromSource(
    const char* vertSrc,
    const char* fragSrc);
