#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

//uniform vec3 uColor;
in float vfVertexIdx;
out vec4 fragColor;

void main()
{
    vec3 col = mix(vec3(1.,0.,0.), vec3(0.,1.,0.), vfVertexIdx);
    fragColor = vec4(col, 1.);
}
