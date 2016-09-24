// TextureFunctions.h

#pragma once

#include "GL_Includes.h"

/// Load a square, power-of-two sized texture file from raw format
GLuint CreateTextureFromRawFile(const char* pFilename, unsigned int dimension, int offset = 0);

GLuint CreateColorTextureFromRawFile(
    const char* pFilename,
    unsigned int x,
    unsigned int y);
