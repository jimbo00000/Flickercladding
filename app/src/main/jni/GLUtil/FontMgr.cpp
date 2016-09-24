// FontMgr.cpp

#include "FontMgr.h"

#include "Logging.h"
#include "FontRenderer.h"

FontMgr::FontMgr()
: m_windowHeight(0)
, m_pFontRender10(NULL)
, m_pFontRender13(NULL)
, m_pFontRender18(NULL)
, m_pFontRender24(NULL)
{
}

FontMgr::~FontMgr()
{
    /// Destroy() should be called before the context is torn down.
}

/// Release GL data before context is torn down.
/// Be sure to assign NULL to all values being destroyed if we are going to put
/// a call to this in the destructor! They will be double-deleted if not.
void FontMgr::Destroy()
{
    delete m_pFontRender10, m_pFontRender10 = NULL;
    delete m_pFontRender13, m_pFontRender13 = NULL;
    delete m_pFontRender18, m_pFontRender18 = NULL;
    delete m_pFontRender24, m_pFontRender24 = NULL;
}

FontRenderer* FontMgr::GetFontOfSize(int pts) const
{
    switch(pts)
    {
    default:
    case 10:
    case 11:
        if (m_pFontRender10 != NULL)
        {
            return m_pFontRender10;
        }
    case 12:
    case 13:
    case 14:
    case 15:
        if (m_pFontRender13 != NULL)
        {
            return m_pFontRender13;
        }
    case 16:
    case 17:
    case 18:
    case 19:
    case 20:
        if (m_pFontRender18 != NULL)
        {
            return m_pFontRender18;
        }
    case 21:
    case 22:
    case 23:
    case 24:
    case 25:
    case 26:
    case 27:
    case 28:
        if (m_pFontRender24 != NULL)
        {
            return m_pFontRender24;
        }
        break;
    }

    /// Return whatever's not NULL
    if (m_pFontRender18) return m_pFontRender18;
    if (m_pFontRender13) return m_pFontRender13;
    if (m_pFontRender10) return m_pFontRender10;
    return NULL;
}

void FontMgr::LoadLanguageFonts(Language lang)
{
    Destroy();

    switch(lang)
    {
    default:
        LOG_INFO(" ERROR: Language %d not recognized in FontMgr...", lang);
        break;

        // The English font contains characters with accent marks.
    case USEnglish : _LoadEnglishFonts(); break;
    case French    : _LoadEnglishFonts(); break;
    case Portuguese: _LoadEnglishFonts(); break;
    case Spanish   : _LoadEnglishFonts(); break;
    case Japanese  : _LoadJapaneseFonts(); break;
    case Chinese   : _LoadChineseFonts(); break;
    }
}

///@todo Consolidate shaders, move windowheight out of fontrend, multi-lang
///@note Depends on the member variable m_windowHeight
bool FontMgr::_LoadEnglishFonts()
{
    m_pFontRender10 = new FontRenderer("SegoeUI_10px", m_windowHeight);
    if (m_pFontRender10 == NULL)
        return false;

    m_pFontRender13 = new FontRenderer("SegoeUI_13px", m_windowHeight);
    if (m_pFontRender13 == NULL)
        return false;

    m_pFontRender18 = new FontRenderer("SegoeUI_18px", m_windowHeight);
    if (m_pFontRender18 == NULL)
        return false;

    m_pFontRender24 = new FontRenderer("SegoeUI_24px", m_windowHeight);
    if (m_pFontRender24 == NULL)
        return false;

    return true;
}

bool FontMgr::_LoadJapaneseFonts()
{
    m_pFontRender13 = new FontRenderer("MeiryoUI_24px", m_windowHeight);
    if (m_pFontRender13 == NULL)
        return false;

    m_pFontRender18 = new FontRenderer("MeiryoUI_36px", m_windowHeight);
    if (m_pFontRender18 == NULL)
        return false;

    return true;
}

bool FontMgr::_LoadChineseFonts()
{
    m_pFontRender13 = new FontRenderer("FangSong_24px", m_windowHeight);
    if (m_pFontRender13 == NULL)
        return false;

    m_pFontRender18 = new FontRenderer("FangSong_36px", m_windowHeight);
    if (m_pFontRender18 == NULL)
        return false;

    return true;
}
