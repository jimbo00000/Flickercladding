--[[ gridcube_scene.lua

    Create subdivided cube geometry using compute shaders.

    Generates the six faces of a cube, each subdivided into subdivs*subdivs
    squares(2 triangles each). Initialization is very fast as no CPU loops
    are used to create geometry, only compute shaders which assign positions
    and connectivity by index in the list.

    Also includes display shader with basic diffuse and specular lighting
    and a gray material.
]]
gridcube_scene = {}

local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local vao = 0
local vbos = {}
local progs = {}
local num_verts = 0
local num_tri_idxs = 0

-- Number of subdivisions per cube dimension
local subdivs = 256

--[[
    Display the grid with diffuse and specular lighting.
]]
local basic_vert = [[
#version 310 es

in vec4 vPosition;
in vec4 vNormal;

out vec3 vfPos;
out vec3 vfNormal;

uniform mat4 modelmtx;
uniform mat4 viewmtx;
uniform mat4 projmtx;

void main()
{
    mat4 mvmtx = viewmtx * modelmtx;
    vfPos = (mvmtx * vPosition).xyz;
    //vfNormal = normalize(transpose(inverse(mat3(modelmtx))) * vNormal.xyz);
    vfNormal = normalize(mat3(mvmtx) * vNormal.xyz);
    gl_Position = projmtx *  mvmtx * vPosition;
}
]]

local basic_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec3 vfPos;
in vec3 vfNormal;
out vec4 fragColor;

vec3 lightPos = vec3(0., 20., 10.);
float shininess = 125.;
void main()
{
    //fragColor = vec4(normalize(abs(vfNormal)), 1.0);

    vec3 N = normalize(vfNormal);
    vec3 L = normalize(lightPos - vfPos); // direction *to* light
    vec3 E = -vfPos;

    // One-sided lighting
    vec3 spec = vec3(0.);
    float bright = max(dot(N,L), 0.);

    if (bright > 0.)
    {
        // Specular lighting
        vec3 H = normalize(L + E);
        float specBr = max(dot(H,N), 0.);
        spec = vec3(1.) * pow(specBr, shininess);
    }

    //fragColor = vec4(egNormal, 0.);
    vec3 basecol = vec3(.4);
    fragColor = vec4(abs(basecol) * bright + spec, 1.);
}
]]

-- Init display shader attributes
local function init_gridmesh_display_attribs(prog)
    local vpos_loc = gl.glGetAttribLocation(prog, "vPosition")
    local vnorm_loc = gl.glGetAttribLocation(prog, "vNormal")
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vbos.vertices[0])
    gl.glVertexAttribPointer(vpos_loc, 4, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vbos.normals[0])
    gl.glVertexAttribPointer(vnorm_loc, 4, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vnorm_loc)
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
local function init_vertex_positions(facets)
    local vvbo = vbos.vertices
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
        gl.glDispatchCompute(num_verts/128+1, 1, 1)
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
local function set_face_indices(facets)
    local ivbo = vbos.elements
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
local function clear_normals()
    local nvbo = vbos.normals
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 0, nvbo[0])
    local prog = progs.clearnorms
    gl.glUseProgram(prog)
    gl.glDispatchCompute(num_verts/128+1, 1, 1)
    gl.glUseProgram(0)
end

--[[
    Calculate normals in compute shader
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
local function recalculate_normals()
    clear_normals()

    local vvbo = vbos.vertices
    local nvbo = vbos.normals
    local fvbo = vbos.elements
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 0, vvbo[0])
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 1, nvbo[0])
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 2, fvbo[0])
    local prog = progs.calcnorms
    gl.glUseProgram(prog)

    local unt_loc = gl.glGetUniformLocation(prog, "numTris")
    local uti_loc = gl.glGetUniformLocation(prog, "triidx")
    local utm_loc = gl.glGetUniformLocation(prog, "trimod")
    local uto_loc = gl.glGetUniformLocation(prog, "uTriOffset")

    local num_tris = subdivs * subdivs * 2
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
                gl.glDispatchCompute(num_tri_idxs/128+1, 1, 1)
                gl.glMemoryBarrier(GL.GL_ALL_BARRIER_BITS)
            end
        end
    end
    gl.glUseProgram(0)

    gl.glMemoryBarrier(GL.GL_ALL_BARRIER_BITS)
end

-- Allocate vertex, normal and index data
local function allocate_gridmesh_verts(facets)
    local s_1 = facets + 1
    num_verts = 6 * s_1 * s_1 -- 6 cube faces
    num_tri_idxs = 6 * 3 * 2 * facets * facets -- 6 faces, 2 triangles per square

    local sz = num_verts * ffi.sizeof('float') * 4 -- xyzw
    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, sz, nil, GL.GL_STATIC_COPY)
    vbos.vertices = vvbo

    local nvbo = glIntv(0)
    gl.glGenBuffers(1, nvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, nvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, sz, nil, GL.GL_STATIC_COPY)
    vbos.normals = nvbo

    local sz = num_tri_idxs * ffi.sizeof('GLuint')
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, sz, nil, GL.GL_STATIC_COPY)
    vbos.elements = qvbo
end

-- GL_INVALID_VALUE is generated if any of num_groups_x, num_groups_y,
-- or num_groups_z is greater than or equal to the maximum work-group
-- count for the corresponding dimension.
function check_compute_group_size()
    print("GL_MAX_COMPUTE_WORK_GROUP_COUNT:")
    local int_buffer = ffi.new("GLint[1]")
    for i=0,2 do
        gl.glGetIntegeri_v(GL.GL_MAX_COMPUTE_WORK_GROUP_COUNT, i, int_buffer)
        print(' ',i,int_buffer[0])
    end
end

function gridcube_scene.initGL()
    check_compute_group_size()

    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    progs.meshvsfs = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    progs.clearnorms = sf.make_shader_from_source({
        compsrc = clear_normals_comp_src,
        })

    progs.calcnorms= sf.make_shader_from_source({
        compsrc = calc_normals_comp_src,
        })

    allocate_gridmesh_verts(subdivs)
    init_vertex_positions(subdivs)
    set_face_indices(subdivs)

    recalculate_normals()

    init_gridmesh_display_attribs(progs.meshvsfs)
    gl.glBindVertexArray(0)
end

function gridcube_scene.exitGL()
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

function gridcube_scene.render_for_one_eye(view, proj)
    gl.glDisable(GL.GL_CULL_FACE)

    local prog = progs.meshvsfs
    local um_loc = gl.glGetUniformLocation(prog, "modelmtx")
    local uv_loc = gl.glGetUniformLocation(prog, "viewmtx")
    local up_loc = gl.glGetUniformLocation(prog, "projmtx")
    gl.glUseProgram(prog)
    gl.glUniformMatrix4fv(uv_loc, 1, GL.GL_FALSE, glFloatv(16, view))
    gl.glUniformMatrix4fv(up_loc, 1, GL.GL_FALSE, glFloatv(16, proj))

    local m = {}
    mm.make_identity_matrix(m)
    local s = .5
    mm.glh_scale(m,s,s,s)
    mm.glh_translate(m, -.5, -.5, -.5)
    gl.glUniformMatrix4fv(um_loc, 1, GL.GL_FALSE, glFloatv(16, m))
    gl.glBindVertexArray(vao)
    --gl.glPolygonMode(GL.GL_FRONT_AND_BACK, GL.GL_LINE)
    gl.glDrawElements(GL.GL_TRIANGLES,
        num_tri_idxs,
        GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function gridcube_scene.timestep(absTime, dt)
end

function gridcube_scene.keypressed(ch)
    if ch == 'f' then return end
    if ch == 'l' then return end

    if ch == 'n' then
        recalculate_normals()
    end
end

function gridcube_scene.get_vertices_vbo() return vbos.vertices end
function gridcube_scene.get_num_verts() return num_verts end
function gridcube_scene.recalc_normals() recalculate_normals() end

return gridcube_scene
