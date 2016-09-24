#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform mat4 mvmtx;
uniform mat4 prmtx;
uniform int uVertexBase;
uniform int uVertexCount;

in vec4 vPosition;
out float vfVertexIdx;

void main()
{
    vfVertexIdx = float(gl_VertexID-uVertexBase) / float(uVertexCount);
    vec4 mvPos = mvmtx * vec4(vPosition.xyz, 1.);
    float a = vPosition.w;
    vec3 thickVec = vec3(cos(a), sin(a), 0.);
    mvPos.xyz += thickVec * float(gl_VertexID % 2) * .05;
    gl_Position = prmtx * mvPos;
}
