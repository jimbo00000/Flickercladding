#version 310 es
// basictex.frag

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D s_texture;

in vec2 vfTex;
out vec4 fragColor;

void main()
{
    float lum = texture(s_texture, vfTex).x;
    vec3 texCol = vec3(lum);
    fragColor = vec4(texCol, 1.);
}
