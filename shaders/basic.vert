#version 310 es
// basic.vert

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec3 vPosition;
in vec3 vColor;

out vec3 vfColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    vfColor = vColor;
    gl_Position = prmtx * mvmtx * vec4(vPosition, 1.);
}
