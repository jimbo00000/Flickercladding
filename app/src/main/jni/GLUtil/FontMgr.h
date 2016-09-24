// FontMgr.h

#pragma once

#include "Singleton.h"
#include "GL_Includes.h"
#include "LanguageEnums.h"

class FontRenderer;

///@brief Holds all font files(catalogued texture maps) and is initialized by GraphicalUI.
///@warning Do not attempt to access this object outside of the GL thread!
class FontMgr : public Singleton
{
public:
    static FontMgr& Instance()
    {
        static FontMgr instance;
        return instance;
    }
    void Destroy();

    void SetWindowHeight(int windowHeight) { m_windowHeight = windowHeight; }
    void LoadLanguageFonts(Language lang);

    FontRenderer* GetFontOfSize(int pts) const;

protected:
    bool _LoadEnglishFonts();
    bool _LoadJapaneseFonts();
    bool _LoadChineseFonts();

    int            m_windowHeight;
    FontRenderer*  m_pFontRender10;
    FontRenderer*  m_pFontRender13;
    FontRenderer*  m_pFontRender18;
    FontRenderer*  m_pFontRender24;

private:
    FontMgr();
    ~FontMgr();
    FontMgr(FontMgr const& copy);            // Not Implemented
    FontMgr& operator=(FontMgr const& copy); // Not Implemented
};
