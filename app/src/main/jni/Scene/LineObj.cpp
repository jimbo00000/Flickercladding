// LineObj.cpp

#include "LineObj.h"
#include "VectorMath.h"
#include "StringFunctions.h"
#include "Logging.h"
#include <fstream>
#include <stdlib.h>
#include <math.h>

LineObj::LineObj()
 : m_verts()
 , m_groups()
 , m_lineprog()
{
}

LineObj::~LineObj()
{
}

///@return 0 for success, non-zero otherwise
int LineObj::loadFromFile(const std::string& filename)
{
    LOG_INFO("Loading obj %s", filename.c_str());
    std::ifstream infile(filename.c_str());
    if (infile.is_open() == false)
    {
        LOG_ERROR("Could not open file.");
        return 1;
    }

    int basevert = 0;
    int numverts = 0;

    std::string line;
    while (std::getline(infile, line))
    {
        std::vector<std::string> toks = split(line, ' ');
        if (toks.size() < 2)
            continue;

        const std::string& t = toks[0];
        if (t.empty())
            continue;

        switch(t[0])
        {
        default:
            break;

        case 'o':
            {
                numverts = m_idxs.size() - basevert - 1;
                if (!m_verts.empty())
                {
                    lineGroup g = {numverts, basevert};
                    m_groups.push_back(g);
                }
                basevert = m_idxs.size();
            }
            break;

        case 'v':
            if (toks.size() >= 4)
            {
                float3 f;
                f.x = static_cast<float>(strtod(toks[1].c_str(), NULL));
                f.y = static_cast<float>(strtod(toks[2].c_str(), NULL));
                f.z = static_cast<float>(strtod(toks[3].c_str(), NULL));
                m_verts.push_back(f);
            }
            break;

        case 'l':
            {
                for (std::vector<std::string>::const_iterator it = toks.begin() + 1;
                    it != toks.end();
                    ++it)
                {
                    const std::string& s = *it;
                    const int i = static_cast<int>(strtol(s.c_str(), NULL, 0));
                    m_idxs.push_back(i);
                }
            }
            break;
        }
    }

    numverts = m_idxs.size() - basevert - 1;
    lineGroup g = { numverts, basevert };
    m_groups.push_back(g);
    LOG_INFO("...loaded %d groups, %d verts %d idxs", m_groups.size(), m_verts.size(), m_idxs.size());

    return 0;
}

void LineObj::initGL()
{
    m_lineprog.initProgram("basicline");
    m_lineprog.bindVAO();

    if (m_verts.empty())
        return;
    if (m_idxs.empty())
        return;

    std::vector<float4> m_doubledVerts;
    float lastAtan = 0.f;
    for (int i = 0; i < m_verts.size(); ++i)
    {
        const float3& p = m_verts[i];
        float4 p4 = {
            p.x, p.y, p.z, 0.f
        };
        if (i > 0)
        {
            // Calculate segment direction and store angle in w component
            const float3 o = m_verts[i - 1];
            const float3 delta = {
                p.x - o.x,
                p.y - o.y,
                p.z - o.z,
            };
            if (length(delta) == 0)
            {
                continue;
            }
            const float th = atan2(delta.x, delta.y);
            p4.w = th;
        }
        m_doubledVerts.push_back(p4);
        m_doubledVerts.push_back(p4);
    }

    std::vector<unsigned int> doubledIdxs;
    for (std::vector<unsigned int>::const_iterator it = m_idxs.begin();
        it != m_idxs.end();
        ++it)
    {
        const unsigned int& p = *it;
        doubledIdxs.push_back(2 * (p-1));
        doubledIdxs.push_back(2 * (p-1) + 1);
    }

    GLuint vertVbo = 0;
    glGenBuffers(1, &vertVbo);
    m_lineprog.AddVbo("vPosition", vertVbo);
    glBindBuffer(GL_ARRAY_BUFFER, vertVbo);
    glBufferData(GL_ARRAY_BUFFER, m_doubledVerts.size() *sizeof(float4), &m_doubledVerts[0].x, GL_STATIC_DRAW);
    glVertexAttribPointer(m_lineprog.GetAttrLoc("vPosition"), 4, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(m_lineprog.GetAttrLoc("vPosition"));

    GLuint quadVbo = 0;
    glGenBuffers(1, &quadVbo);
    m_lineprog.AddVbo("elements", quadVbo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, quadVbo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, doubledIdxs.size() * sizeof(GLuint), &doubledIdxs[0], GL_STATIC_DRAW);

    glBindVertexArray(0);
}

void LineObj::exitGL()
{
}

void LineObj::display(float* mview, float* proj)
{
    const ShaderWithVariables& swv = m_lineprog;
    glUseProgram(swv.prog());

    glUniformMatrix4fv(swv.GetUniLoc("mvmtx"), 1, false, mview);
    glUniformMatrix4fv(swv.GetUniLoc("prmtx"), 1, false, proj);
    //glUniform3f(swv.GetUniLoc("uColor"), 1.f, 0.f, 0.f);

    swv.bindVAO();
    for (std::vector<lineGroup>::const_iterator it = m_groups.begin();
        it != m_groups.end();
            ++it)
    {
        const lineGroup& g = *it;
        const int start = 2 * g.base;
        const int end = (start + 2 * g.count);
        glUniform1i(swv.GetUniLoc("uVertexBase"), 2 * g.base);
        glUniform1i(swv.GetUniLoc("uVertexCount"), 2 * g.count);
        glDrawElements(GL_TRIANGLE_STRIP,
            2*(g.count-1),
            GL_UNSIGNED_INT,
            (void*)(start * sizeof(GLuint)));
    }
    glBindVertexArray(0);
}
