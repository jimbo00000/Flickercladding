#version 310 es
// basictex.vert

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec2 vPosition;
in vec2 vTexCoord;

out vec2 vfTex;

uniform mat4 mvmtx;
uniform mat4 prmtx;

void main()
{
    vfTex = vTexCoord;
    gl_Position = prmtx * mvmtx * vec4(vPosition, 0., 1.);
}
