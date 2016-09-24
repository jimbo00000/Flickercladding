// SimpleIcon.cpp

#include "SimpleIcon.h"
#include "DataDirectoryLocation.h"
#include "ShaderFunctions.h"
#include "TextureFunctions.h"
#include "MatrixMath.h"
#include "Logging.h"
#include <string>

SimpleIcon::SimpleIcon()
: m_progBasic()
, m_texID(0)
{
}

SimpleIcon::~SimpleIcon()
{
}

void SimpleIcon::initGL()
{
    m_progBasic.initProgram("basictex");

    m_progBasic.bindVAO();
    _InitIconAttributes();
    glBindVertexArray(0);

    const int dim = 128;
    const std::string dataHome = APP_DATA_DIRECTORY;
    const std::string texFilename = dataHome + "3dcube1.raw";
    m_texID = CreateTextureFromRawFile(texFilename.c_str(), dim);
}

void SimpleIcon::exitGL()
{
    m_progBasic.destroy();
    glDeleteTextures(1, &m_texID);
}

void SimpleIcon::_InitIconAttributes()
{
    const float sz = 100.f;
    const GLfloat QuadVerts[] = {
        0.f, 0.f,
        sz, 0.f,
        sz, sz,
        0.f, sz,
   };

    const GLfloat QuadCols[] = {
        0.f, 0.f,
        1.f, 0.f,
        1.f, 1.f,
        0.f, 1.f,
    };
    GLuint vertVbo = 0;
    glGenBuffers(1, &vertVbo);
    m_progBasic.AddVbo("vPosition", vertVbo);
    glBindBuffer(GL_ARRAY_BUFFER, vertVbo);
    glBufferData(GL_ARRAY_BUFFER, 4*2*sizeof(GLfloat), QuadVerts, GL_STATIC_DRAW);
    glVertexAttribPointer(m_progBasic.GetAttrLoc("vPosition"), 2, GL_FLOAT, GL_FALSE, 0, NULL);

    GLuint colVbo = 0;
    glGenBuffers(1, &colVbo);
    m_progBasic.AddVbo("vColor", colVbo);
    glBindBuffer(GL_ARRAY_BUFFER, colVbo);
    glBufferData(GL_ARRAY_BUFFER, 4*2*sizeof(GLfloat), QuadCols, GL_STATIC_DRAW);
    glVertexAttribPointer(m_progBasic.GetAttrLoc("vTexCoord"), 2, GL_FLOAT, GL_FALSE, 0, NULL);

    glEnableVertexAttribArray(m_progBasic.GetAttrLoc("vPosition"));
    glEnableVertexAttribArray(m_progBasic.GetAttrLoc("vTexCoord"));
}

void SimpleIcon::display(float* mview, float* proj)
{
    glUseProgram(m_progBasic.prog());

    glUniformMatrix4fv(m_progBasic.GetUniLoc("mvmtx"), 1, false, mview);
    glUniformMatrix4fv(m_progBasic.GetUniLoc("prmtx"), 1, false, proj);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, m_texID);
    glUniform1i(m_progBasic.GetUniLoc("s_texture"), 0);

    m_progBasic.bindVAO();
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glBindVertexArray(0);
}
