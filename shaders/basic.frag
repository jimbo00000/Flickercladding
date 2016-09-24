#version 310 es
// basic.frag

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec3 vfColor;
out vec4 fragColor;

void main()
{
    fragColor = vec4(vfColor, 1.0);
}
