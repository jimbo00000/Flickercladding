--[[ moon.lua

    Spherical moon with randomly generated surface craters.

    Uses gridcube_scene.lua to create a fine subdivided mesh topologically
    homeomorphic to a sphere(starts life as a cube), then applies a compute
    shader on vertex positions to cumulatively deform the mesh.
]]
moon = {}
moon.__index = moon

function moon.new(...)
    local self = setmetatable({}, moon)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

local GridLib = require("scene2.gridcube")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

function moon:init()
    self.progs = {}
    self.grid = GridLib.new()
end

--[[
    Perturb all vertices with a function.
]]
local perturbverts_comp_src = [[
#version 310 es
#line 22
layout(local_size_x=128) in;
layout(std430, binding=0) buffer pblock { vec4 positions[]; };

vec3 displacePoint(vec3 p)
{
    vec3 center = vec3(.5);
    float radius = 1.;
    return center + radius*normalize(p-center);
}

void main()
{
    uint index = gl_GlobalInvocationID.x;
    vec4 p = positions[index];

    p.xyz = displacePoint(p.xyz);

    positions[index] = p;
}
]]

function moon:perturbVertexPositions()
    local vvbo = self.grid:get_vertices_vbo()
    local num_verts = self.grid:get_num_verts()
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 0, vvbo[0])
    local prog = self.progs.perturbverts
    gl.glUseProgram(prog)

    gl.glDispatchCompute(num_verts/128+1, 1, 1)
    gl.glUseProgram(0)
end


local pushout_sphere_src = [[
#version 310 es
#line 58
layout(local_size_x=128) in;
layout(std430, binding=0) buffer pblock { vec4 positions[]; };

uniform vec3 crater_center;
uniform float radius;
uniform float strength;

vec3 sphere_center = vec3(.5);

float profile_function(float r)
{
    float x = pow(r,2.);
    return mix(.75*smoothstep(0.,1.,x), -smoothstep(0.,1.,x), smoothstep(0.3,.6,x));
    return .1* -sin(-2.*3.14159*3./4.*x);
}

vec3 displacePoint(vec3 p)
{
    float ltc = length(p - crater_center);
    if (ltc < radius)
    {
        float r_1 = 1. - (ltc/radius);
        vec3 disp = strength * profile_function(r_1) * normalize(p-sphere_center);
        return p + disp;
    }
    return p;
}

void main()
{
    uint index = gl_GlobalInvocationID.x;
    vec4 p = positions[index];

    p.xyz = displacePoint(p.xyz);

    positions[index] = p;
}
]]

function moon:initGL()
    self.progs.perturbverts= sf.make_shader_from_source({
        compsrc = perturbverts_comp_src,
        })

    self.progs.make_crater = sf.make_shader_from_source({
        compsrc = pushout_sphere_src,
        })

    self.grid:initGL()
    self:perturbVertexPositions()
    self.grid:recalc_normals()
end

function moon:exitGL()
    self.grid:exitGL()
    for _,v in pairs(self.progs) do
        gl.glDeleteProgram(v)
    end
end

function moon:render_for_one_eye(view, proj)
    self.grid:render_for_one_eye(view, proj)
end

function random_variance(center, variance)
    -- Return a random value centered on center, with += variance
    return center - variance + variance*2*math.random()
end

function moon:create_random_crater()
    -- Monte Carlo random on sphere
    local cc = {}
    repeat
        local c,v = 0,1
        cc = {random_variance(c,v), random_variance(c,v), random_variance(c,v), }
    until mm.length(cc) < 1
    --mm.normalize(cc)
    for i=1,3 do cc[i] = 2.*cc[i] + 1. end -- Map [-.5,.5] to [0,2]? or [0,1]?

    local r = random_variance(.2, .1)
    local strength = .1

    -- Set uniforms for sphere locations - program must be active.
    local prog = self.progs.make_crater
    gl.glUseProgram(prog)
    local ucc_loc = gl.glGetUniformLocation(prog, "crater_center")
    gl.glUniform3f(ucc_loc, cc[1], cc[2], cc[3])
    local ucr_loc = gl.glGetUniformLocation(prog, "radius")
    gl.glUniform1f(ucr_loc, r)

    local vvbo = self.grid:get_vertices_vbo()
    local num_verts = self.grid:get_num_verts()

    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 0, vvbo[0])
    local ust_loc = gl.glGetUniformLocation(prog, "strength")
    gl.glUniform1f(ust_loc, strength)

    gl.glDispatchCompute(num_verts/128, 1, 1)
    gl.glUseProgram(0)
end

function moon:add_craters(n)
    for i=0,n do self:create_random_crater() end
    gl.glMemoryBarrier(GL.GL_SHADER_STORAGE_BARRIER_BIT)
    self.grid:recalc_normals()
    gl.glMemoryBarrier(GL.GL_SHADER_STORAGE_BARRIER_BIT)
end

function moon:keypressed(ch)
    self:add_craters(30)
end

function moon:onSingleTouch(pointerid, action, x, y)
    self:add_craters(30)
end

return moon
