#version 310 es
// basicplane.vert

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec3 vPosition;
in vec2 vTexCoord;

out vec2 vfTexCoord;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    vfTexCoord = vTexCoord;
    gl_Position = prmtx * mvmtx * vec4(vPosition, 1.0);
}
