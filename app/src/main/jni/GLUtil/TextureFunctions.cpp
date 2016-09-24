// TextureFunctions.cpp

#include "GL_Includes.h"

#include "TextureFunctions.h"
#include "Logging.h"
#include <stdio.h>
#include <fstream>

/// Load a square, power-of-two sized texture file from raw format.
/// Assume file is luminance(grayscale) format, 8 bits per pixel.
///@param pFilename Fully qualified path name
///@param dimension Size in pixels of one dimension of the square image
///@return TextureID of created texture (0 for none)
GLuint CreateTextureFromRawFile(const char* pFilename, unsigned int dimension, int offset)
{
    if (pFilename == NULL)
        return 0;

    GLuint textureId = 0;

    LOG_INFO("Opening %d px square file %s ...", dimension, pFilename);
    std::ifstream fs;
    fs.open(pFilename, std::ios::in|std::ios::binary);
    if (!fs.is_open())
    {
        LOG_ERROR("File %s not found.", pFilename);
        return 0;
    }

    fs.seekg(offset, fs.beg);

    const unsigned int dimx = dimension;
    const unsigned int dimy = dimension;
    const unsigned int sz = dimx * dimy;
    const unsigned int szBytes = sz;
    GLubyte* pPixels = new GLubyte[szBytes];
    fs.read(reinterpret_cast<char*>(pPixels), szBytes);

    /// Create an OpenGL texture
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glGenTextures(1, &textureId);
    if (textureId != 0)
    {
        glBindTexture(GL_TEXTURE_2D, textureId);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);

        glTexImage2D(GL_TEXTURE_2D,
            0,
            GL_R8,
            dimx,
            dimy,
            0,
            GL_RED,
            GL_UNSIGNED_BYTE,
            pPixels);
    }
    else
    {
        LOG_INFO("Failed to create GL texture.");
    }

    delete [] pPixels;
    fs.close();
    if (textureId != 0)
    {
        LOG_INFO("success.");
    }
    else
    {
        LOG_INFO("FAILURE.");
    }
    return textureId;
}


/// Load a color texture file from raw format.
///@param pFilename Fully qualified path name
///@param x Size in pixels of horizontal dimension of the image
///@param y Size in pixels of vertical dimension of the image
///@return TextureID of created texture (0 for none)
GLuint CreateColorTextureFromRawFile(
    const char* pFilename,
    unsigned int x,
    unsigned int y)
{
    if (pFilename == NULL)
        return 0;

    GLuint textureId = 0;

    LOG_INFO_NONEWLINE("Opening %d x %d px texture file %s ...", x, y, pFilename);
    std::ifstream fs;
    fs.open(pFilename, std::ios::in|std::ios::binary);
    if (!fs.is_open())
    {
        LOG_ERROR("File %s not found.", pFilename);
        return 0;
    }

    const unsigned int sz = x * y * 3; ///< RGB
    const unsigned int szBytes = sz;
    GLubyte* pPixels = new GLubyte[szBytes];
    fs.read(reinterpret_cast<char*>(pPixels), szBytes);

    /// Create an OpenGL texture
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glGenTextures(1, &textureId);
    if (textureId != 0)
    {
        glBindTexture(GL_TEXTURE_2D, textureId);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        glTexImage2D(GL_TEXTURE_2D,
            0,
            GL_RGB,
            x,
            y,
            0,
            GL_RGB,
            GL_UNSIGNED_BYTE,
            pPixels);
    }
    else
    {
        LOG_ERROR("Failed to create GL texture.");
    }

    delete [] pPixels;
    fs.close();
    if (textureId != 0)
    {
        LOG_INFO("success.");
    }
    return textureId;
}
