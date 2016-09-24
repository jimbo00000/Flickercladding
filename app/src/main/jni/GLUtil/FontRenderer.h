// FontRenderer.h

#pragma once

#include "Renderer.h"
#include "ShaderWithVariables.h"
#include "GL_Includes.h"
#include <string>
#include <vector>
#include <map>
#include "vectortypes.h"

#include "BMFont_structs.h"

/// Loads bitmap fonts created by AngelSoft's BMFont and displays text
/// using textured triangles in OpenGLES.
class FontRenderer : public Renderer
{
public:
    FontRenderer(const char* pFontName, int windowHeight);
    virtual ~FontRenderer();

    void DrawString(
        const char* pStr,
        int x,
        int y,
        float3 color,
        const float* pProjMtx,
        bool doKerning,
        const float* pMvMtx=NULL) const;

    void DrawWString(
        const wchar_t* pStr,
        int x,
        int y,
        float3 color,
        const float* pProjMtx,
        bool doKerning,
        const float* pMvMtx=NULL) const;

    void PrintKerningPairs(int firstChar=0, int secondChar=0) const;

    /// const Accessors
    int StringLengthPixels(const char* pStr) const;
    int StringLengthPixels(const wchar_t* pWStr) const;
    int GetWindowHeight() const { return m_windowHeight; }
    int GetLineHeight  () const { return m_lineHeight; }
    int GetBase        () const { return m_basePx; }

protected:
    void _LoadFntFile(const char* pFilename);
    void _ProcessBlock(unsigned char id, unsigned int sz, unsigned char* pBlock);
    void _AddKerningEntry(int chprev, int ch, short amount);
    int _AddCustomKerningEntries(const char* pFilename);

    GLuint                            m_texDimension; ///< Square power-of-two dimension textures preferred
    std::map<wchar_t, BMF_char>       m_charTable;
    std::map<
        std::pair<int,int>,
        short >                       m_kernTable;
    std::vector<std::string>          m_pageFilenames;
    std::vector<GLuint>               m_pageTextures;
    int                               m_windowHeight;
    int                               m_lineHeight;
    int                               m_basePx;

    ShaderWithVariables m_shader;

private:
    FontRenderer();                                 ///< disallow default constructor
    FontRenderer(const FontRenderer&);              ///< disallow copy constructor
    FontRenderer& operator = (const FontRenderer&); ///< disallow assignment operator
};
