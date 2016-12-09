--[[ cubemesh.lua

]]

local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")
local ffi = require("ffi")

local glIntv   = ffi.typeof('GLint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

CubeMesh = {}
CubeMesh.__index = CubeMesh

function CubeMesh.new(...)
    local self = setmetatable({}, CubeMesh)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function CubeMesh:init()
    self.num_verts = 0
    self.num_tri_idxs = 0
    self.subdivs = 256
    self.vbos = {}
    self.progs = {}
end

--[[
    Set up initial vertex values by index to a subdivided square grid.
]]
local initverts_comp_src = [[
#version 310 es
#line 115
layout(local_size_x=128) in;
layout(std430, binding=0) buffer nblock { vec4 positions[]; };

uniform int uFacets;
uniform int uOffset;
uniform mat4 uMatrix;

void main()
{
    int index = int(gl_GlobalInvocationID.x);
    int f_1 = uFacets + 1;
    ivec2 gridIdx = ivec2(index % f_1, index / f_1);
    vec4 v = vec4(
        float(gridIdx.x)/float(uFacets),
        float(gridIdx.y)/float(uFacets),
        0.,
        1.);
    positions[index + uOffset] = uMatrix * v;
}
]]
function CubeMesh:init_vertex_positions(facets)
    local vvbo = self.vbos.vertices
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 0, vvbo[0])

    local prog = sf.make_shader_from_source({
        compsrc = initverts_comp_src,
        })
    gl.glUseProgram(prog)

    local uf_loc = gl.glGetUniformLocation(prog, "uFacets")
    gl.glUniform1i(uf_loc, facets)

    -- Manually create transformation matrices to move the
    -- unit square in xy to each face of a cube.
    local matrices = {}
    for i=1,6 do
        local m = {}
        mm.make_identity_matrix(m)
        table.insert(matrices, m)
    end
    mm.glh_rotate(matrices[2], 90, 0,1,0)
    mm.glh_translate(matrices[2], -1, 0, 0)

    mm.glh_rotate(matrices[3], -90, 1,0,0)
    mm.glh_translate(matrices[3], 0, -1, 0)

    mm.glh_rotate(matrices[4], 180, 1,0,0)
    mm.glh_translate(matrices[4], 0,-1,-1)

    mm.glh_rotate(matrices[5], -90, 0,1,0)
    mm.glh_translate(matrices[5], 0, 0, -1)

    mm.glh_rotate(matrices[6], 90, 1,0,0)
    mm.glh_translate(matrices[6], 0, 0, -1)

    local uo_loc = gl.glGetUniformLocation(prog, "uOffset")
    local um_loc = gl.glGetUniformLocation(prog, "uMatrix")
    local f_1 = facets + 1
    for i=1,6 do
        local off = (i-1) * f_1 * f_1
        gl.glUniform1i(uo_loc, off)
        gl.glUniformMatrix4fv(um_loc, 1, GL.GL_FALSE, glFloatv(16, matrices[i]))
        gl.glDispatchCompute(self.num_verts/128+1, 1, 1)
    end

    gl.glUseProgram(0)
    gl.glDeleteProgram(prog) -- Program is single-use
end

--[[
    Set up initial face values by index to a subdivided square grid.
]]
local initfaces_comp_src = [[
#version 310 es
#line 190
layout(local_size_x=128) in;
layout(std430, binding=0) buffer iblock { uint indices[]; };

uniform int uFacets;
uniform int uOffset;
uniform int uVertexOffset;

int getFaceFromXY(int i, int j)
{
    return (uFacets+1) * j + i + uVertexOffset;
}

void main()
{
    int index = int(gl_GlobalInvocationID.x);
    int gridIdx = index / 6;
    int i = gridIdx % uFacets;
    int j = gridIdx / uFacets;

    int triIdx = index % 6;
    int tris[6] = int[6](
        getFaceFromXY(i,j),
        getFaceFromXY(i+1,j),
        getFaceFromXY(i,j+1),
        getFaceFromXY(i,j+1),
        getFaceFromXY(i+1,j),
        getFaceFromXY(i+1,j+1)
    );

    indices[index + uOffset] = uint(tris[triIdx]);
}
]]
function CubeMesh:set_face_indices(facets)
    local ivbo = self.vbos.elements
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 0, ivbo[0])

    local prog = sf.make_shader_from_source({
        compsrc = initfaces_comp_src,
        })
    gl.glUseProgram(prog)

    local uf_loc = gl.glGetUniformLocation(prog, "uFacets")
    local uo_loc = gl.glGetUniformLocation(prog, "uOffset")
    local uv_loc = gl.glGetUniformLocation(prog, "uVertexOffset")
    local tri_idxs_per_face = 2 * 3 * facets * facets
    local f_1 = facets + 1
    local verts_per_face = f_1 * f_1
    gl.glUniform1i(uf_loc, facets)

    -- Stitch together a mesh for each cube face
    for g=0,5 do
        gl.glUniform1i(uo_loc, g * tri_idxs_per_face)
        gl.glUniform1i(uv_loc, g * verts_per_face)
        gl.glDispatchCompute(tri_idxs_per_face/128+1, 1, 1)
        gl.glMemoryBarrier(GL.GL_SHADER_STORAGE_BARRIER_BIT)
    end
    gl.glUseProgram(0)
    gl.glDeleteProgram(prog) -- Program is single-use
end

--[[
    Clear normals using compute shader to prepare for normal calculation
    which accumulates, averaging normals from each face adjacent to
    each vertex.
]]
local clear_normals_comp_src = [[
#version 310 es

#define THREADS_PER_BLOCK 128
layout(local_size_x=128) in;
layout(std430, binding=0) buffer nblock { vec4 normals[]; };

void main()
{
    uint index = gl_GlobalInvocationID.x;
    vec4 n = normals[index];
    n.xyz = vec3(0.);
    normals[index] = n;
}
]]
function CubeMesh:clear_normals()
    local nvbo = self.vbos.normals
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 0, nvbo[0])
    local prog = self.progs.clearnorms
    gl.glUseProgram(prog)
    gl.glDispatchCompute(self.num_verts/128+1, 1, 1)
    gl.glUseProgram(0)
end

--[[
    Calculate normals in compute shader:
    Trigger shader on element indices, indexing into positions and
    normals attribute buffers. Sum up the contributions from each
    face including each vertex indexed.
]]
local calc_normals_comp_src = [[
#version 310 es
#line 288
layout(local_size_x=128) in;
layout(std430, binding=0) buffer vblock { vec4 positions[]; };
layout(std430, binding=1) coherent buffer nblock { vec4 normals[]; };

struct faceData {
    int a;
    int b;
    int c;
};
layout(std430, binding=2) coherent buffer iblock { faceData indices[]; };

uniform int numTris;
uniform int triidx;
uniform int trimod;
uniform int uTriOffset;

void main()
{
    int index = int(gl_GlobalInvocationID.x);
    if (index >= numTris)
        return;

    // Handle only one triangle per quad at a time to avoid data races
    if ((index % 2) != trimod)
        return;

    faceData fd = indices[index + uTriOffset];

    vec3 pos = positions[fd.a].xyz;
    vec3 posx = positions[fd.b].xyz;
    vec3 posy = positions[fd.c].xyz;

    vec3 v1 = posx - pos;
    vec3 v2 = posy - pos;
    vec3 norm = cross(v2, v1);

    if (triidx == 0)
    {
        normals[fd.a].xyz += norm;
    }
    else if (triidx == 1)
    {
        normals[fd.b].xyz += norm;
    }
    else
    {
        normals[fd.c].xyz += norm;
    }
}
]]
function CubeMesh:recalculate_normals()
    self:clear_normals()

    local vvbo = self.vbos.vertices
    local nvbo = self.vbos.normals
    local fvbo = self.vbos.elements
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 0, vvbo[0])
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 1, nvbo[0])
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 2, fvbo[0])
    local prog = self.progs.calcnorms
    gl.glUseProgram(prog)

    local unt_loc = gl.glGetUniformLocation(prog, "numTris")
    local uti_loc = gl.glGetUniformLocation(prog, "triidx")
    local utm_loc = gl.glGetUniformLocation(prog, "trimod")
    local uto_loc = gl.glGetUniformLocation(prog, "uTriOffset")

    local num_tris = self.subdivs * self.subdivs * 2
    gl.glUniform1i(unt_loc, num_tris)

    -- Calculate each cube face individually
    for t=0,5 do
        local triOffset = t * num_tris
        gl.glUniform1i(uto_loc, triOffset)

        -- Interlace face indices to avoid data races
        for m=0,1 do
            gl.glUniform1i(utm_loc, m)
            for i=0,2 do
                gl.glUniform1i(uti_loc, i)
                gl.glDispatchCompute(self.num_tri_idxs/128+1, 1, 1)
                gl.glMemoryBarrier(GL.GL_ALL_BARRIER_BITS)
            end
        end
    end
    gl.glUseProgram(0)

    gl.glMemoryBarrier(GL.GL_ALL_BARRIER_BITS)
end

-- Allocate vertex, normal and index data
function CubeMesh:allocate_gridmesh_verts(facets)
    local s_1 = facets + 1
    self.num_verts = 6 * s_1 * s_1 -- 6 cube faces
    self.num_tri_idxs = 6 * 3 * 2 * facets * facets -- 6 faces, 2 triangles per square

    local sz = self.num_verts * ffi.sizeof('float') * 4 -- xyzw
    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, sz, nil, GL.GL_STATIC_COPY)
    self.vbos.vertices = vvbo

    local nvbo = glIntv(0)
    gl.glGenBuffers(1, nvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, nvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, sz, nil, GL.GL_STATIC_COPY)
    self.vbos.normals = nvbo

    local sz = self.num_tri_idxs * ffi.sizeof('GLuint')
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, sz, nil, GL.GL_STATIC_COPY)
    self.vbos.elements = qvbo
end

function CubeMesh:initGL()
    self.progs.clearnorms = sf.make_shader_from_source({
        compsrc = clear_normals_comp_src,
        })

    self.progs.calcnorms= sf.make_shader_from_source({
        compsrc = calc_normals_comp_src,
        })

    self:allocate_gridmesh_verts(self.subdivs)
    self:init_vertex_positions(self.subdivs)
    self:set_face_indices(self.subdivs)
    self:recalculate_normals()
end

function CubeMesh:exitGL()
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}

    for _,p in pairs(self.progs) do
        gl.glDeleteProgram(p)
    end
    self.progs = {}
end
