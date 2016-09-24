// SimpleIcon.h

#pragma once

#include "GL_Includes.h"
#include "ShaderWithVariables.h"

class SimpleIcon
{
public:
    SimpleIcon();
    virtual ~SimpleIcon();

    void initGL();
    void exitGL();
    void display(float* mview, float* proj);

protected:
    void _InitIconAttributes();

    ShaderWithVariables m_progBasic;
    GLuint m_texID;

private:
    SimpleIcon(const SimpleIcon&);              ///< disallow copy constructor
    SimpleIcon& operator = (const SimpleIcon&); ///< disallow assignment operator
};
