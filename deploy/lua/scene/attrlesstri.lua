-- attrlesstri.lua
attrlesstri = {}

local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

local vao = 0
local vbos = {}
local progs = {}
local g_time = 0.0
local numInstances = 10

local basic_vert = [[
#version 330
#line 19

in vec4 instancePosition;
in vec4 instanceOrientation;

out vec3 vfColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;
uniform float uPhase;
uniform int uNumBasePairs;

mat3 rotx(float th)
{
    return mat3(
        1., 0., 0.,
        0., cos(th), -sin(th),
        0., sin(th), cos(th)
        );
}

mat3 roty(float th)
{
    return mat3(
        cos(th), 0., sin(th),
        0., 1., 0.,
        -sin(th), 0., cos(th)
        );
}

mat3 rotz(float th)
{
    return mat3(
        cos(th), -sin(th), 0.,
        sin(th), cos(th), 0.,
        0., 0., 1.
        );
}

// http://www.iquilezles.org/www/articles/functions/functions.htm
float cubicPulse( float c, float w, float x )
{
    x = abs(x - c);
    if( x>w ) return 0.0;
    x /= w;
    return 1.0 - x*x*(3.0-2.0*x);
}

// [0,.5]
float tri(float x)
{
    return (round(x-.5)-floor(x-.5))*(fract(x)) + (round(x)-floor(x))*(1.-fract(x));
}

float rand(vec2 n)
{ 
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

// Quaternion rotation of a vector
vec3 qtransform(vec4 q, vec3 v)
{
    return v + 2.0*cross(cross(v, q.xyz) + q.w*v, q.xyz);
}

#define PI 3.14159265359

// Mutually exclusive
//#define ANEMONE
//#define HELIX
#define OTHER

void main()
{
    const int n = 18;
    int i = gl_VertexID % n;
    int j = gl_VertexID / n;

    const float a = .5;
    const float b = .5 * sqrt(3.);
    const float c = 1.7;
    const vec3 hexpts[n] = vec3[n](
        // A hexagon
        vec3(0., 0., 0.),
        vec3(1., 0., 0.),
        vec3(a, b, 0.),

        vec3(0., 0., 0.),
        vec3(a, b, 0.),
        vec3(-a, b, 0.),

        vec3(0., 0., 0.),
        vec3(-a, b, 0.),
        vec3(-1, 0, 0.),

        vec3(0., 0., 0.),
        vec3(-1, 0, 0.),
        vec3(-a, -b, 0.),

        vec3(0., 0., 0.),
        vec3(-a, -b, 0.),
        vec3(a, -b, 0.),

        vec3(0., 0., 0.),
        vec3(a, -b, 0.),
        vec3(1, 0, 0.)
    );
    const vec3 tubepts[n] = vec3[n](
        // a tube
        vec3(1., 0., -c),
        vec3(1., 0., c),
        vec3(-a, b, -c),

        vec3(-a, b, -c),
        vec3(1., 0., c),
        vec3(-a, b, c),

        vec3(-a, b, -c),
        vec3(-a, b, c),
        vec3(-a, -b, c),

        vec3(-a, b, -c),
        vec3(-a, -b, c),
        vec3(-a, -b, -c),

        vec3(-a, -b, -c),
        vec3(-a, -b, c),
        vec3(1., 0., -c),

        vec3(1., 0., -c),
        vec3(-a, -b, c),
        vec3(1., 0., c)
    );

    // double helix
    int type = 2;
    int o = j % type;
    int p = j / type;

    bool hex = ((o & 1) == 0);

    float sz = .1;
    vec3 pos = sz * hexpts[i].yxz;
    vec3 col = hexpts[i];

#ifdef HELIX
    if (hex == false)
    {
        pos = .8* sz * tubepts[i].yxz;
        col = tubepts[i];
    }
#endif

#ifdef ANEMONE
    // radial anemone
    int order = 12;
    int k = j % order;
    int l = j / order;

    pos *= 3.;

    pos.z -= .5;
    float r = 2. * PI / float(order);

    for (int f=0; f<l; ++f)
    {
        pos *= rotx(-.25+ .125*sin(uPhase));
        pos *= rotz(.125*sin(.5*uPhase));
        pos.y += .5;
        pos *= .8;
    }
    pos *= roty(float(k) * r);
#endif


#ifdef OTHER
    // A binary tree structure
    for (int i=j; i>0; i=((i-1)/2))
    {
        vec3 off = .5*vec3(.2, .25, 0.);
        float rx = .15 * (1.2+sin(.25*uPhase));
        float ry = .25 * (1.2+sin(1.5*uPhase));

        int lr = i & 1;
        if (lr == 1)
        {
            off.x *= -1.;
            rx *= -1.;
        }
        //if (hex == false)
        if (i == 1)
        {
            ry = -.5*PI;
            rx = 1.;
        }
        if (i == 2)
        {
            rx = -1.;
            ry = -.5*PI;
        }

        pos *= rotx(rx) * //rotx(.5*sin(.5*uPhase)) * 
        roty(ry);
        pos += off;
        pos *= .7;
    }
    pos *= 3.;
#endif


#ifdef HELIX
    // double helix
    int order = 2;
    int k = p % order;
    int l = p / order;

    // climb up the zipper
    float bph = .15;
    pos.y += bph * float(l);

    if (hex == false)
    {
        // base pair
        pos.z += .15;
    }
    else
    {
        // backbone
        pos.z = .3;
    }


    // zippering animation
    //float zp = 5.*abs(sin(.5*uPhase));
    float zp = 10.* 2.*tri(.1*uPhase);
    zp *= float(uNumBasePairs);

#if 0
    float widest01 = 
        .1*zp; // bottom to top
        // abs(sin(.5*uPhase));
    float widestPair = float(uNumBasePairs) * widest01;
    float zipPulse = cubicPulse(fract(.03*widestPair), .09, float(l)/float(uNumBasePairs));
    float spread = 0.;
    //spread *= (1.+.05*sin(uPhase));
        spread += .4 * zipPulse;
    pos.z += spread;
#else
    float s = max(0., .1*pow(max(0.,float(l) - .1*zp), 1.5) );
    float scatt = rand(vec2( float(k), float(l) ));
    pos.z += s * scatt;
#endif



    // Center zipper point on local origin
    pos.y -= .1*bph * zp;


    // chirality
    bool left = ((k & 1) == 0);
    if (left == true)
    {
        pos.z *= -1.;
    }
    pos *= roty(.3*float(l));

#endif

    // Instance
    vec4 q = normalize(instanceOrientation);
    pos = qtransform(q, pos);
    pos += instancePosition.xyz;

    vfColor = col;
    gl_Position = prmtx * mvmtx * vec4(pos,1.);
}
]]

local basic_frag = [[
#version 330

in vec3 vfColor;
out vec4 fragColor;

void main()
{
    fragColor = vec4(vfColor, 1.0);
}
]]

local function init_instance_attributes()
    local prog = progs.draw
    local sz = 4 * numInstances * ffi.sizeof('GLfloat') -- xyzw

    local insp_loc = gl.glGetAttribLocation(prog, "instancePosition")
    local ipvbo = glIntv(0)
    gl.glGenBuffers(1, ipvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, ipvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, sz, nil, GL.GL_STATIC_COPY)
    gl.glVertexAttribPointer(insp_loc, 4, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    vbos.inst_positions = ipvbo
    gl.glVertexAttribDivisor(insp_loc, 1)
    gl.glEnableVertexAttribArray(insp_loc)

    local inso_loc = gl.glGetAttribLocation(prog, "instanceOrientation")
    local iovbo = glIntv(0)
    gl.glGenBuffers(1, iovbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, iovbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, sz, nil, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(inso_loc, 4, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    vbos.inst_orientations = iovbo
    gl.glVertexAttribDivisor(inso_loc, 1)
    gl.glEnableVertexAttribArray(inso_loc)
end

--[[
    Scatter instance positions randomly in particles array.
]]
local randomize_instance_positions_comp_src = [[
#version 430

layout(local_size_x=256) in;
layout(std430, binding=0) buffer pblock { vec4 positions[]; };
layout(std430, binding=1) buffer oblock { vec4 orientations[]; };
uniform int numInstances;

float hash( float n ) { return fract(sin(n)*43758.5453); }

void main()
{
    uint index = gl_GlobalInvocationID.x;
    if (index >= numInstances)
        return;
    float fi = float(index+1) / float(numInstances);

    positions[index] = vec4(
        50.*
          (vec3(-.5) + vec3(hash(fi), hash(fi*3.), hash(fi*17.)) ),
         1.);

    orientations[index] = vec4(hash(fi*11.), hash(fi*5.), hash(fi*7.), hash(fi*19.));

#if 1
    if (index == 0)
    {
        // Manually reset the first instance
        positions[0] = vec4(vec3(0.), 1.);
        orientations[0] = vec4(0., 0., 0., 1.);
    }
#endif

}
]]
local function randomize_instance_positions()
    if progs.scatter_instances == nil then
        progs.scatter_instances = sf.make_shader_from_source({
            compsrc = randomize_instance_positions_comp_src,
            })
    end
    local pvbo = vbos.inst_positions
    local ovbo = vbos.inst_orientations
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 0, pvbo[0])
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 1, ovbo[0])
    local prog = progs.scatter_instances
    local function uni(name) return gl.glGetUniformLocation(prog, name) end
    gl.glUseProgram(prog)
    gl.glUniform1i(uni("numInstances"), numInstances)
    gl.glDispatchCompute(numInstances/256+1, 1, 1)
    gl.glUseProgram(0)
end


function attrlesstri.initGL()
    progs.draw = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)
    do
        init_instance_attributes()
        randomize_instance_positions()
    end
    gl.glBindVertexArray(0)

end

function attrlesstri.exitGL()
    gl.glBindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}

    for _,p in pairs(progs) do
        gl.glDeleteProgram(p)
    end
    progs = {}

    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

function attrlesstri.render_for_one_eye(view, proj)
    local prog = progs.draw
    local umv_loc = gl.glGetUniformLocation(prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(prog, "prmtx")
    local up_loc = gl.glGetUniformLocation(prog, "uPhase")
    local ubp_loc = gl.glGetUniformLocation(prog, "uNumBasePairs")
    gl.glUseProgram(prog)
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    local phase = 2 * math.pi * g_time
    phase = phase * .125
    gl.glUniform1f(up_loc, phase)
    local basePairs = 32*4
    gl.glUniform1i(ubp_loc, basePairs)
    gl.glDisable(GL.GL_CULL_FACE)
    gl.glBindVertexArray(vao)
    gl.glDrawArraysInstanced(GL.GL_TRIANGLES, 0, 6*3*2*2*basePairs, numInstances)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end

function attrlesstri.timestep(absTime, dt)
    g_time = absTime
end

return attrlesstri
