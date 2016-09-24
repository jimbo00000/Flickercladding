// TouchPoints.cpp

#include "TouchPoints.h"
#include "ShaderFunctions.h"
#include "MatrixMath.h"
#include "Logging.h"
#include "AndroidTouchEnums.h"
#include <string>

TouchPoints::TouchPoints()
: g_progBasic(0)
, g_attrLocPos(-1)
, g_attrLocCol(-1)
, g_uniLocMvmtx(-1)
, g_uniLocPrmtx(-1)
{
}

TouchPoints::~TouchPoints()
{
}

void TouchPoints::initGL()
{
    g_progBasic = makeShaderByName("basic");
    LOGI("g_progBasic = %d", g_progBasic);

    g_attrLocPos = glGetAttribLocation(g_progBasic, "vPosition");
    g_attrLocCol = glGetAttribLocation(g_progBasic, "vColor");
    g_uniLocMvmtx = glGetUniformLocation(g_progBasic, "mvmtx");
    g_uniLocPrmtx = glGetUniformLocation(g_progBasic, "prmtx");
    LOGI("glGetAttribLocation(\"g_attrLocPos\") = %d\n", g_attrLocPos);
    //LOGI("glGetAttribLocation(\"g_attrLocCol\") = %d\n", g_attrLocCol);
}

void TouchPoints::exitGL()
{
    glDeleteProgram(g_progBasic);
}

void TouchPoints::display(float* mview, float* proj, const std::vector<touchState>& touches)
{
    glUseProgram(g_progBasic);

    glUniformMatrix4fv(g_uniLocMvmtx, 1, false, mview);
    glUniformMatrix4fv(g_uniLocPrmtx, 1, false, proj);

    const GLfloat pointCols[] = {
        1.f, 0.f, 0.f,
        1.f, 1.f, 0.f,
        1.f, 0.f, 1.f,
        1.f, 1.f, 1.f,
        0.f, 0.f, 0.f,
        0.f, 1.f, 0.f,
        0.f, 0.f, 1.f,
        0.f, 1.f, 1.f,
    };

    // The Galaxy Tab 4 Vivante device does not like GL_INT type here, but GL_FLOAT is OK.
    glEnableVertexAttribArray(g_attrLocPos);
    glEnableVertexAttribArray(g_attrLocCol);

    int i=0;
    for (std::vector<touchState>::const_iterator it = touches.begin();
        it != touches.end();
        ++it, ++i)
    {
        const touchState& ts = *it;
        if (ts.state == ActionUp)
            continue;
        if (ts.state == ActionPointerUp)
            continue;
        glVertexAttribPointer(g_attrLocPos, 2, GL_INT, GL_FALSE, sizeof(touchState), &ts.x);
        glVertexAttribPointer(g_attrLocCol, 3, GL_FLOAT, GL_FALSE, 0, &pointCols[3*i]);
        glDrawArrays(GL_POINTS, 0, 1);
    }
}
