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

require("util.cubemesh")
local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local cubemesh = nil -- Will hold our class instance
local vao = 0
local progs = {}

--[[
    Display the mesh with diffuse and specular lighting.
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
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cubemesh.vbos.vertices[0])
    gl.glVertexAttribPointer(vpos_loc, 4, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cubemesh.vbos.normals[0])
    gl.glVertexAttribPointer(vnorm_loc, 4, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vnorm_loc)
end



-- GL_INVALID_VALUE is generated if any of num_groups_x, num_groups_y,
-- or num_groups_z is greater than or equal to the maximum work-group
-- count for the corresponding dimension.
local function check_compute_group_size()
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

    cubemesh = CubeMesh.new()
    cubemesh:initGL()

    progs.meshvsfs = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })
    init_gridmesh_display_attribs(progs.meshvsfs)

    gl.glBindVertexArray(0)
end

function gridcube_scene.exitGL()
    gl.glBindVertexArray(vao)

    for _,p in pairs(progs) do
        gl.glDeleteProgram(p)
    end
    progs = {}

    cubemesh:exitGL()

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
        cubemesh.num_tri_idxs,
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
        cubemesh:recalculate_normals()
    end
end

function gridcube_scene.get_cubemesh() return cubemesh end
function gridcube_scene.get_vertices_vbo() return cubemesh.vbos.vertices end
function gridcube_scene.get_num_verts() return cubemesh.num_verts end
function gridcube_scene.recalc_normals() cubemesh:recalculate_normals() end

return gridcube_scene
