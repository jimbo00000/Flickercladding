// ShaderMgr.h

#pragma once

#include "Singleton.h"
#include <string>
#include <map>
#include "ShaderFunctions.h"

///@brief A list of all shaders for use in the UI
///@warning Do not attempt to access this object outside of the GL thread!
class ShaderMgr : public Singleton
{
public:
    static ShaderMgr& Instance()
    {
        static ShaderMgr instance;
        return instance;
    }
    void Destroy()
    {
        typedef std::map<std::string, GLuint>::iterator it_type;
        for(it_type it = m_shaderTable.begin(); it != m_shaderTable.end(); ++it)
        {
            GLuint prog = it->second;
            if (prog != 0)
                glDeleteProgram(prog);
        }
    }

    GLuint GetShaderByName(const char* pKey)
    {
        if (pKey == NULL)
            return 0;

        std::string key(pKey);

        /// Return a NULL shader for an empty string
        if (key.empty())
            return 0;

        if (m_shaderTable.count(key) == 0)
        {
            m_shaderTable[key] = makeShaderByName(pKey);
        }

        return m_shaderTable[key];
    }

protected:
    std::map<std::string, GLuint>  m_shaderTable;

private:
    ShaderMgr() : m_shaderTable() {}
    ~ShaderMgr() {} /// Destroy() should be called before the context is torn down.
    ShaderMgr(ShaderMgr const& copy);            // Not Implemented
    ShaderMgr& operator=(ShaderMgr const& copy); // Not Implemented
};
