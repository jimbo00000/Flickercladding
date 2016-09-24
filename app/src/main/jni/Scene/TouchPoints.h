// TouchPoints.h

#pragma once

#include "GL_Includes.h"
#include <vector>

struct touchState {
    int id;
    int state;
    int x;
    int y;
};

class TouchPoints
{
public:
    TouchPoints();
    virtual ~TouchPoints();

    void initGL();
    void exitGL();
    void display(float* mview, float* proj, const std::vector<touchState>&);

protected:
    GLuint g_progBasic;
    GLuint g_attrLocPos;
    GLuint g_attrLocCol;
    GLuint g_uniLocMvmtx;
    GLuint g_uniLocPrmtx;

private:
    TouchPoints(const TouchPoints&);              ///< disallow copy constructor
    TouchPoints& operator = (const TouchPoints&); ///< disallow assignment operator
};
