// ShaderWithVariables.cpp

#include "ShaderWithVariables.h"
#include "ShaderFunctions.h"
#include "StringFunctions.h"
#include "Logging.h"

#include <iostream>
#include <string>
#include <sstream>
#include <vector>

ShaderWithVariables::ShaderWithVariables()
: m_program(0)
, m_vao(0)
, m_attrs()
, m_unis()
, m_vbos()
{
}

ShaderWithVariables::~ShaderWithVariables()
{
    destroy();
}

void ShaderWithVariables::destroy()
{
    if (m_program != 0)
    {
        glDeleteProgram(m_program);
        m_program = 0;
    }

    if (m_vao != 0)
    {
        glDeleteVertexArrays(1, &m_vao);
        m_vao = 0;
    }

    for (std::map<std::string, GLuint>::iterator it = m_vbos.begin();
        it != m_vbos.end();
        ++it)
    {
        GLuint vbo = it->second;
        glDeleteBuffers(1, &vbo);
    }

    m_attrs.clear();
    m_unis.clear();
    m_vbos.clear();
}

void ShaderWithVariables::initProgram(const char* shadername)
{
    glGenVertexArrays(1, &m_vao);

    LOG_INFO("Shader [%s]", shadername);

    std::string vs = shadername;
    std::string fs = shadername;
    vs += ".vert";
    fs += ".frag";

    m_program = makeShaderFromSource(vs.c_str(), fs.c_str());
    if (m_program == 0)
        return;

    const std::string vsrc = GetShaderSource(vs.c_str());
    findVariables(vsrc.c_str());
    const std::string fsrc = GetShaderSource(fs.c_str());
    findVariables(fsrc.c_str());

    LOG_INFO(" %d uniforms, %d attributes", m_unis.size(), m_attrs.size());
}

void ShaderWithVariables::initComputeShader(const char* shadername)
{
    GLuint comp_shader = 0;
    comp_shader = glCreateShader(GL_COMPUTE_SHADER);
    const std::string comp_src = GetShaderSource(shadername);
    const GLchar* pSS = &comp_src[0];
    glShaderSource(comp_shader, 1, &pSS, NULL);

    glCompileShader(comp_shader);
    GLint status;
    glGetShaderiv(comp_shader, GL_COMPILE_STATUS, &status);
    bool errors = false;
    if (status == GL_FALSE)
    {
        GLint length;
        glGetShaderiv(comp_shader, GL_INFO_LOG_LENGTH, &length);
        std::vector<char> log(length);
        glGetShaderInfoLog(comp_shader, length, &length, &log[0]);
        LOG_ERROR("Shader error(%d): %s", length, &log[0]);
        errors = true;
    }

    GLuint comp_prog = glCreateProgram();
    glAttachShader(comp_prog, comp_shader);
    glLinkProgram(comp_prog);

    glGetProgramiv(comp_prog, GL_LINK_STATUS, &status);
    if (status == GL_FALSE)
    {
        GLint length;
        glGetProgramiv(comp_prog, GL_INFO_LOG_LENGTH, &length);
        std::vector<char> log(length);
        glGetProgramInfoLog(comp_prog, length, &length, &log[0]);
        LOG_ERROR("Program error(%d): %s", length, &log[0]);
        errors = true;
    }

    m_program = comp_prog;
    findVariables(comp_src.c_str());
    if (errors == false)
    {
        std::cout << "Compute shader compiled successfully." << std::endl;
    }
}

void ShaderWithVariables::findVariables(const char* vertsrc)
{
    ///@todo handle all kinds of line breaks?
    std::vector<std::string> vtoks = split(vertsrc, '\n');

    for (std::vector<std::string>::const_iterator it = vtoks.begin();
        it != vtoks.end();
        ++it)
    {
        const std::string& line = *it;
        ///@todo Handle tabs, etc.
        std::vector<std::string> tokens = split(line, ' ');
        if (tokens.size() < 3)
            continue;

        // We are assuming this will strip off the trailing semicolon.
        std::string var = tokens[2];
        var = var.substr(0, var.length()-1);

        if (!tokens[0].compare("uniform"))
        {
            m_unis[var] = glGetUniformLocation(m_program, var.c_str());
        }
        else if (!tokens[0].compare("in"))
        {
            m_attrs[var] = glGetAttribLocation(m_program, var.c_str());
        }
        else if (!tokens[0].compare("attribute")) // deprecated keyword
        {
            m_attrs[var] = glGetAttribLocation(m_program, var.c_str());
        }
    }
}

GLint ShaderWithVariables::GetAttrLoc(const std::string name) const
{
    std::map<std::string, GLint>::const_iterator it = m_attrs.find(name);
    if (it == m_attrs.end()) // key not found
        return -1;
    return it->second;
}

GLint ShaderWithVariables::GetUniLoc(const std::string name) const
{
    std::map<std::string, GLint>::const_iterator it = m_unis.find(name);
    if (it == m_unis.end()) // key not found
        return -1; // -1 values are ignored silently by GL
    return it->second;
}

GLuint ShaderWithVariables::GetVboLoc(const std::string name) const
{
    std::map<std::string, GLuint>::const_iterator it = m_vbos.find(name);
    if (it == m_vbos.end()) // key not found
        return 0; // -1 values are ignored silently by GL
    return it->second;
}
