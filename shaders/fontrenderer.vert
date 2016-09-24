#version 310 es
// fontrenderer.vert
// Shader for FontRenderer class
// Vertex shader simply takes quads textured to unit interval and scales them to pixel coordinates.

in vec3 a_position;
in vec2 a_texCoord;

out vec2 v_texCoord;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    gl_Position = prmtx * mvmtx * vec4(a_position, 1.0);
    v_texCoord = a_texCoord;
}
