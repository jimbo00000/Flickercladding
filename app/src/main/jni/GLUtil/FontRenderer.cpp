// FontRenderer.cpp

#include "FontRenderer.h"

#include "DataDirectoryLocation.h"
#include "ShaderFunctions.h"
#include "TextureFunctions.h"

#include "Logging.h"
#include "MatrixMath.h"
#include <fstream>
#include <string.h>

/// Static map of all unrecognize characters so we print each message only once.
static std::map<wchar_t,int> s_unrecognizedChars;

FontRenderer::FontRenderer(const char* pFontName, int windowHeight)
: m_texDimension(0)
, m_charTable()
, m_kernTable()
, m_pageFilenames()
, m_pageTextures()
, m_windowHeight(windowHeight)
, m_lineHeight(0)
, m_basePx(0)
, m_shader()
{
    const std::string fontName = pFontName;
    const std::string dataHome = APP_DATA_DIRECTORY;
    std::string homedir = dataHome;

    homedir.append("fonts/");
    const std::string fntFilename = homedir + fontName + ".fnt";
    _LoadFntFile(fntFilename.c_str());

    _AddCustomKerningEntries(fntFilename.c_str());
    //PrintKerningPairs(0,0);
    //PrintKerningPairs((int)'t',0);
    //PrintKerningPairs(0,(int)'t');

    /// Load all pages of font
    for (std::vector<std::string>::iterator it=m_pageFilenames.begin();
         it != m_pageFilenames.end();
         ++it)
    {
        const std::string pageName = *it;
        const std::string suffixless = pageName.substr(0, pageName.length()-4);
        ///@todo png support
        const std::string texFilename = homedir + suffixless + ".raw";
        const GLuint tex = CreateTextureFromRawFile(texFilename.c_str(), m_texDimension);
        m_pageTextures.push_back(tex);
    }

    m_shader.initProgram("fontrenderer");
    m_shader.bindVAO();
    {
        GLuint vertVbo = 0;
        glGenBuffers(1, &vertVbo);
        m_shader.AddVbo("a_position", vertVbo);
        glBindBuffer(GL_ARRAY_BUFFER, vertVbo);
        glBufferData(GL_ARRAY_BUFFER, 4*3*sizeof(GLfloat), NULL, GL_STATIC_DRAW);
        glVertexAttribPointer(m_shader.GetAttrLoc("a_position"), 3, GL_FLOAT, GL_FALSE, 0, NULL);

        GLuint colVbo = 0;
        glGenBuffers(1, &colVbo);
        m_shader.AddVbo("a_texCoord", colVbo);
        glBindBuffer(GL_ARRAY_BUFFER, colVbo);
        glBufferData(GL_ARRAY_BUFFER, 4*2*sizeof(GLfloat), NULL, GL_STATIC_DRAW);
        glVertexAttribPointer(m_shader.GetAttrLoc("a_texCoord"), 2, GL_FLOAT, GL_FALSE, 0, NULL);

        glEnableVertexAttribArray(m_shader.GetAttrLoc("a_position"));
        glEnableVertexAttribArray(m_shader.GetAttrLoc("a_texCoord"));
    }
    glBindVertexArray(0);
}


FontRenderer::~FontRenderer()
{
    if (!m_pageTextures.empty())
        glDeleteTextures(m_pageTextures.size(), &m_pageTextures[0]);
}


/// Utility function for BMF binary font reading
/// Blocks are preceded by 1 byte identifier and 4 byte size.
/// Allocates and returns a block of memory to be frreed by the caller.
unsigned char* GetBlock(std::ifstream& fin, unsigned char& id, unsigned int& sz)
{
    fin.read(reinterpret_cast<char*>(&id), 1);
    fin.read(reinterpret_cast<char*>(&sz), sizeof(unsigned int));

    unsigned char* pBlock = new unsigned char[sz];
    fin.read(reinterpret_cast<char*>(pBlock), sz);

    return pBlock;
}


/// See BMF docs
/// http://www.angelcode.com/products/bmfont/doc/file_format.html
void FontRenderer::_ProcessBlock(unsigned char id, unsigned int sz, unsigned char* pBlock)
{
    switch(id)
    {
    default: break;

    case 1: // info
        BMF_blockInfo bi;
        memcpy(&bi, pBlock, sizeof(BMF_blockInfo));
        {
            //unsigned int namelen = sz - sizeof(BMF_blockInfo);
            //const unsigned char* pName = pBlock + sizeof(BMF_blockInfo);
        }
        break;

    case 2: // common
        BMF_blockCommon b;
        memcpy(&b, pBlock, sizeof(BMF_blockCommon));
        {
            m_texDimension = b.scaleW;
            if (b.scaleW != b.scaleH)
            {
                LOG_INFO("WARNING: Non-square font scale dimensions\n");
                ///@todo NPOT warning? Padding?
            }
            m_lineHeight = b.lineHeight;
            m_basePx = b.base;
        }
        break;

    case 3: // pages
        {
            const char* pName = reinterpret_cast<const char*>(pBlock);
            if (pName != NULL)
            {
                std::string name(reinterpret_cast<const char*>(pName));
                const unsigned int len = name.length()+1; // include terminator
                const unsigned int num = sz / len;
                for (unsigned int i=0; i<num; ++i)
                {
                    m_pageFilenames.push_back(name);
                    pName += len;
                    name.assign(pName);
                }
            }
        }
        break;

    case 4: // chars
        {
            const size_t charCount = sz / sizeof(BMF_char);
            //m_charTable.resize(charCount);
            //memcpy(&m_charTable[0], pBlock, charCount * sizeof(BMF_char));
            const BMF_char* pCharBlock = reinterpret_cast<const BMF_char*>(pBlock);
            for(int i=0; i<static_cast<int>(charCount); ++i)
            {
                const BMF_char& pC = pCharBlock[i];
                m_charTable[pC.id] = pC;
            }
        }
        break;

    case 5: /// kerning pairs
        {
            const size_t kernCount = sz / sizeof(BMF_kern);
            //m_kernTable.resize(kernCount);
            //memcpy(&m_kernTable[0], pBlock, kernCount * sizeof(BMF_kern));
            const BMF_kern* pKernBlock = reinterpret_cast<const BMF_kern*>(pBlock);
            for(int i=0; i<static_cast<int>(kernCount); ++i)
            {
                const BMF_kern& bk = pKernBlock[i];
                _AddKerningEntry(bk.first, bk.second, bk.amount);
            }
        }
        break;
    }
}


/// Load a bitmap font file created by:
/// http://www.angelcode.com/products/bmfont/
///@param pFilename Filename of .fnt binary file exported by BMFont
void FontRenderer::_LoadFntFile(const char* pFilename)
{
    if (pFilename == NULL)
        return;

    LOG_INFO_NONEWLINE("Opening font file %s ...", pFilename);
    std::ifstream fin(pFilename, std::ios::binary);

    if (fin)
    {
        // Header is 4 bytes, BMF followed by 3.
        unsigned char header[4];
        fin.read(reinterpret_cast<char*>(header), 4);
        if ((header[0] == 'B') &&
            (header[1] == 'M') &&
            (header[2] == 'F') &&
            (header[3] == 3))
        {
            for (unsigned int i=0; i<5; ++i)
            {
                unsigned char id;
                unsigned int sz;
                unsigned char* pBlock = GetBlock(fin, id, sz);

                _ProcessBlock(id, sz, pBlock);

                delete [] pBlock;
            }
        }

        fin.close();
        LOG_INFO("success.");
    }
    else
    {
        LOG_ERROR("Font file %s not found.\n", pFilename);
    }
}


/// Just for curiosity, print a list of the font's kerning pairs to stdout.
void FontRenderer::PrintKerningPairs(int firstChar, int secondChar) const
{
    LOG_INFO("___Kerning pairs(%d):___", m_kernTable.size());
    for (std::map< std::pair<int,int>,short >::const_iterator it = m_kernTable.begin();
        it != m_kernTable.end();
        ++it)
    {
        const std::pair<int,int>& key = it->first;
        const short& val = it->second;

        if ((firstChar != 0) && (key.first != firstChar))
            continue;
        if ((secondChar != 0) && (key.second != secondChar))
            continue;

        LOG_INFO("  %c %c  %dpx", key.first, key.second, val);
    }
}

void FontRenderer::_AddKerningEntry(int chprev, int ch, short amount)
{
    const std::pair<int,int> kp(chprev, ch);
    m_kernTable[kp] = amount;
}

///@brief Load custom kerning entries from .kern file.
/// One entry per line, first 2 wide chars are the pair, then a space, then the pixel displacement.
/// e.g.: "it -2"
int FontRenderer::_AddCustomKerningEntries(const char* pFilename)
{
#if 0
    std::string narrowFilename(pFilename);
    const std::string fntSuffix = ".fnt";
    size_t suffixFound = narrowFilename.rfind(fntSuffix);
    if (suffixFound != narrowFilename.length() - fntSuffix.length())
        return -1;
    const std::string suffixless = narrowFilename.substr(0, narrowFilename.length() - fntSuffix.length());
    const std::string kernFilename = suffixless + ".kern";

    // http://www.cplusplus.com/forum/beginner/75503/
    std::wstring wFilename(kernFilename.begin(), kernFilename.end());

    FILE *file;
    _wfopen_s(&file,
        wFilename.c_str(),
        L"rb,ccs=UTF-16LE" /// Be sure to open the UTF-16 file in binary mode
        );

    if (file == NULL)
        return 2;

    while(!feof(file) && !ferror(file))
    {
        const size_t bufSz = 512;
        wchar_t LineOfChars[bufSz];
        fgetws(LineOfChars, bufSz, file);
        std::wstring line(LineOfChars);

        if (line.empty()) // Blank lines ignored
            continue;
        if (line.at(0) == L'#') // comment lines ignored
            continue;
        if (line.length() < 4)
            continue;

        ///@note First line of file should be blank or we get a bad entry here.
        const int c1 = line[0];
        const int c2 = line[1];
        const std::string numstr(line.begin()+3, line.end());
        const int amt = atoi(numstr.c_str());
        _AddKerningEntry(c1, c2, static_cast<short>(amt));
    }

    fclose(file);
#endif

    return 0;
}


///@param pWStr [in] Wide-character string to determine the length of
///@return The length of the string as rendered on screen, in pixels
int FontRenderer::StringLengthPixels(const wchar_t* pWStr) const
{
    int totalPx = 0;
    // Let's hope that the string is properly NULL terminated here.
    const unsigned int len = wcslen(pWStr);
    for (unsigned int i=0; i<len; ++i)
    {
        const wchar_t ch = pWStr[i];
        const std::map<wchar_t, BMF_char>::const_iterator it = m_charTable.find(ch);
        if (it != m_charTable.end())
        {
            const BMF_char& charInfo = it->second;
            totalPx += charInfo.xadv;
        }
    }
    return totalPx;
}

///@brief Convert narrow string to wide and call into that function for compatibility.
int FontRenderer::StringLengthPixels(const char* pStr) const
{
    const std::string s(pStr);
    const std::wstring ws(s.begin(), s.end());

    return StringLengthPixels(ws.c_str());
}

///@brief Convert narrow string to wide and call into that function for compatibility.
void FontRenderer::DrawString(
    const char* pStr,
    int x,
    int y,
    float3 color,
    const float* pProjMtx,
    bool doKerning,
    const float* pMvMtx) const
{
    const std::string s(pStr);
    const std::wstring ws(s.begin(), s.end());

    DrawWString(ws.c_str(),
        x,
        y,
        color,
        pProjMtx,
        doKerning,
        pMvMtx);
}


/// Draw an ASCII string of text using font texture and data.
///@param pStr [in] The ASCII string to display
///@param x The x location on screen
///@param y The y location on screen
///@param pProjMtx [in] The projection matrix (typically to indicate pixel coordinates on screen)
///@param doKerning If true, adjust letter positions based on kerning pairs list
///@param pMvMtx [in] An optional pointer to modelview matrix(default NULL)
///@todo Reorder DrawString parameters to put 2 matrices together.
///@note When pMvMtx != NULL, projection matrix will not be ortho pixel coordinates.
void FontRenderer::DrawWString(const wchar_t* pStr,
                              int x,
                              int y,
                              float3 color,
                              const float* pProjMtx,
                              bool doKerning,
                              const float* pMvMtx) const
{
    const float tracking = 1.0f;

    if (m_charTable.empty())
        return;

    const GLuint prog = m_shader.prog();
    glUseProgram(prog);

    if (pMvMtx == NULL)
    {
        // The old 2D path - assume an identity mv matrix
        float mvmtx[16];
        MakeIdentityMatrix(mvmtx);
        glUniformMatrix4fv(m_shader.GetUniLoc("mvmtx"), 1, false, mvmtx);
        glUniformMatrix4fv(m_shader.GetUniLoc("prmtx"), 1, false, pProjMtx);
    }
    else
    {
        glUniformMatrix4fv(m_shader.GetUniLoc("mvmtx"), 1, false, pMvMtx);
        glUniformMatrix4fv(m_shader.GetUniLoc("prmtx"), 1, false, pProjMtx);
    }

    const int texDim = m_texDimension;
    const float fTexDim = static_cast<float>(texDim);

    float currx = static_cast<float>(x); // incremented with each character drawn

    // Let's hope that the string is properly NULL terminated here.
    const unsigned int len = wcslen(pStr);
    for (unsigned int i=0; i<len; ++i)
    {
        const wchar_t ch = pStr[i];
        if (ch == 0xfeff) // Skip byte order mark
            continue;
        if (ch == 0x0d) // Skip carriage returns
            continue;
        if (ch == 0x0a) // Skip line feeds
            continue;
        //if (ch == 0x09) ///<@todo Handle tab characters?
        //    continue;

        if (m_charTable.find(ch) == m_charTable.end())
        {
            // Since the draw function is const, we use a static table to hold
            // unrecognized chars for just one print each.
            if (s_unrecognizedChars.find(ch) == s_unrecognizedChars.end())
            {
                s_unrecognizedChars[ch] = 1;
                LOG_ERROR("Unrecognized Char: %d  %x", ch, ch);
            }
            continue;
        }

        const std::map<wchar_t, BMF_char>::const_iterator it = m_charTable.find(ch);
        if (it == m_charTable.end())
            continue;
        const BMF_char& charInfo = it->second;

        ///@todo Cache the value so we don't have to rebind it if it doesn't change.
        /// This is probably exactly what the driver does...
        const unsigned int tIdx = charInfo.page;
        if (tIdx >= m_pageTextures.size())
            continue;
        const GLuint texID = m_pageTextures[tIdx];
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, texID);
        glUniform1i(m_shader.GetUniLoc("s_texture"), 0);

        glUniform3f(m_shader.GetUniLoc("u_fontColor"), color.x, color.y, color.z);

        int kernamt = 0;
        if (doKerning)
        {
            //if (i < (len-1))
            if (i > 0)
            {
                const wchar_t chprev = pStr[i-1];
                //const wchar_t chnext = pStr[i+1];

                // Find kern delta value for this specific character pair.
                std::pair<int,int> kpair(chprev, ch);
                const std::map<std::pair<int,int>,short>::const_iterator kit = m_kernTable.find(kpair);
                if (kit != m_kernTable.end())
                {
                    const short& val = kit->second;
                    kernamt = val;
                }
            }
        }

        // Shrink down some characters to 2/3 width
        const bool isKatakana = (ch >= 0x30a0) && (ch <= 0x30ff);
        const bool isCJK = (ch >= 0x4e00) && (ch <= 0x9fff);
        const bool shrink = isCJK | isKatakana;
        const float widthScale = shrink ? 2.f/3.f : 1.f;

        const float xoff = currx + static_cast<float>(kernamt);
        const float yoff = static_cast<float>(y + charInfo.yoff); ///@note Characters are top-aligned
        const float xf = static_cast<float>(charInfo.x);
        const float yf = static_cast<float>(charInfo.y);
        const float wf = static_cast<float>(charInfo.w);
        const float hf = static_cast<float>(charInfo.h);
        const GLfloat vVertices[] = {
            xoff                , yoff + hf, 0.0f,
            xoff                , yoff     , 0.0f,
            xoff + wf*widthScale, yoff     , 0.0f,
            xoff + wf*widthScale, yoff + hf, 0.0f,
        };

        const GLfloat vTexCoords[] = {
            (xf     )/fTexDim,  (yf + hf)/fTexDim,
            (xf     )/fTexDim,  (yf     )/fTexDim,
            (xf + wf)/fTexDim,  (yf     )/fTexDim,
            (xf + wf)/fTexDim,  (yf + hf)/fTexDim
        };

        const GLushort indices[] = { 0,1,2, 3,0,2 }; // CCW triangles by default

        m_shader.bindVAO();
        {
            glBindBuffer(GL_ARRAY_BUFFER, m_shader.GetVboLoc("a_position"));
            glBufferData(GL_ARRAY_BUFFER, 4*3*sizeof(GLfloat), vVertices, GL_STATIC_DRAW);
            glBindBuffer(GL_ARRAY_BUFFER, m_shader.GetVboLoc("a_texCoord"));
            glBufferData(GL_ARRAY_BUFFER, 4*2*sizeof(GLfloat), vTexCoords, GL_STATIC_DRAW);
            glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, indices);
        }
        glBindVertexArray(0);

        currx += tracking * static_cast<float>(charInfo.xadv) * widthScale;
    }
}
