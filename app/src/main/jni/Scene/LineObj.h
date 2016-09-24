// LineObj.h

#pragma once

#include "GL_Includes.h"
#include "ShaderWithVariables.h"
#include "vectortypes.h"
#include <string>
#include <vector>

struct lineGroup {
    int count;
    int base;
};

class LineObj
{
public:
    LineObj();
    virtual ~LineObj();

    void initGL();
    void exitGL();
    int loadFromFile(const std::string& filename);
    void display(float* mview, float* proj);

protected:
    std::vector<float3> m_verts;
    std::vector<unsigned int> m_idxs;
    std::vector<lineGroup> m_groups;
    ShaderWithVariables m_lineprog;

private:
    LineObj(const LineObj&);              ///< disallow copy constructor
    LineObj& operator = (const LineObj&); ///< disallow assignment operator
};
