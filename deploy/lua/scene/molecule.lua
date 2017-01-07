--[[
molecule.lua
2016 Piotr Rotkiewicz
Loads molecules from PDB files and displays them using imposters. 
]]

molecule = {}

--local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

local vbos = {}
local vao = 0
local prog = 0
local mol = nil
local num_atoms = 0
local dataDir

local basic_vert = [[
#version 310 es

#ifdef GL_ES
precision highp float;
precision mediump int;
#endif

layout(location = 0) in vec4 vPosition;
layout(location = 1) in vec4 vColor;

layout(location = 0) uniform mat4 mvmtx;
layout(location = 1) uniform mat4 prmtx;

out vec3  v_color;
out float v_sqrradius;
out vec3  v_direction;
out vec3  v_center;

const int N_VERT = 3;

vec2 u_corners[N_VERT] = vec2[N_VERT](
    vec2(-1.732,-1.0),
    vec2(1.732,-1.0),
    vec2(0.0, 2.0)
    );

void main()
{
    mat4 mv = mvmtx;
    vec2 corner = u_corners[gl_VertexID % N_VERT];
    mat3 tmv = transpose(mat3(mvmtx));
    vec3 offset = 2.0 * (corner.x * tmv[0] + corner.y * tmv[1]);
    vec4 vertex_position = vec4(vPosition.xyz + offset, 1);

    v_color = vColor.rgb;
    v_sqrradius = vPosition.w * vPosition.w;

    vec4 tmppos = mv * vec4(vPosition.xyz, 1.0);
    v_center = tmppos.xyz;

    // Calculate vertex position in eye space
    vec4 eye_space_position = mv * vertex_position;
    v_direction = eye_space_position.xyz;
    gl_Position = prmtx * eye_space_position;
}
]]

local basic_frag = [[
#version 310 es

#ifdef GL_ES
precision highp float;
precision mediump int;
#endif

layout(location = 1) uniform mat4 prmtx;

in vec3  v_color;
in float v_sqrradius;
in vec3  v_direction;
in vec3  v_center;

out vec4 fragColor;

void main()
{
    vec3 ray_origin = vec3(0,0,0);
    vec3 ray_direction = normalize(v_direction);
    vec3 sphere_direction = (v_center - ray_origin);

    float b = dot(sphere_direction, ray_direction);
    float position = b*b + v_sqrradius - dot(sphere_direction, sphere_direction);

    int frag_discard = 0;
    frag_discard |= int(position < 0.0);
    frag_discard != int(b*b < position);

    float t = b - sqrt(position);

    if (t < 0.001) {
        discard;
    }

    // ray-sphere intersection point
    vec3 ipoint = ray_origin + t * ray_direction;

    vec3 normal = normalize(ipoint - v_center);

    // depth
    vec2 clip = ipoint.z * prmtx[2].zw + prmtx[3].zw;
    float depth =  0.5 + 0.5 * (clip.x) / (clip.y);

    vec3 L = -normalize(ipoint);

    fragColor = vec4(v_color,1) * max(dot(normal, L), 0.0);
    fragColor += vec4(vec3(pow(dot(normal, L), 60.0)), 0.0);

//    f_color = vec4(vec3(-ipoint.z/100.0), 1.0);

    float C = 1.0;
    float Far = 1000000.0;
//    depth = -(2*log(C*depth + 1) / log(C*Far + 1) - 1) * depth;
    gl_FragDepth = depth;

    if (frag_discard > 0) {
        discard;
    }
}
]]


local function init_molecule(mol)
    num_atoms = #mol
    print(#mol)

    local coords_array = {}
    local colors_array = {}
    local cx, cy, cz = 0,0,0
    local total = 0
    for i, atom in pairs(mol) do
        local element = atom[1]
        local rad,r,g,b = 1,1,1,1
        if element == "C" then
            rad,r,g,b = 1.70, 0.2, 0.9, 0.2
        elseif element == "N" then
            rad,r,g,b = 1.55, 0.2, 0.2, 0.8
        elseif element == "O" then
            rad,r,g,b = 1.52, 0.8, 0.3, 0.3
        elseif element == "S" then
            rad,r,g,b = 1.80, 0.9, 0.9, 0.2
        elseif element == "H" then
            rad = 1.2
        end
        local x = tonumber(atom[2])
        local y = tonumber(atom[3])
        local z = tonumber(atom[4])
        cx = cx + x
        cy = cy + y
        cz = cz + z
        total = total + 1
        for i=0,2 do
            coords_array[#coords_array+1] = x
            coords_array[#coords_array+1] = y
            coords_array[#coords_array+1] = z
            coords_array[#coords_array+1] = rad
            colors_array[#colors_array+1] = r
            colors_array[#colors_array+1] = g
            colors_array[#colors_array+1] = b
        end
    end

    cx = cx / total
    cy = cy / total
    cz = cz / total

    print("CENTER",cx, cy, cz)
    print("TOTAL", total)

    for i=0, total*3-1 do
        coords_array[4*i+1] = coords_array[4*i+1] - cx
        coords_array[4*i+2] = coords_array[4*i+2] - cy
        coords_array[4*i+3] = coords_array[4*i+3] - cz
    end

    local verts = glFloatv(4*3*num_atoms, coords_array)
    local colors = glFloatv(3*3*num_atoms, colors_array)

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(0, 4, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, vvbo)

    local cvbo = glIntv(0)
    gl.glGenBuffers(1, cvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(colors), colors, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(1, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, cvbo)

    gl.glEnableVertexAttribArray(0)
    gl.glEnableVertexAttribArray(1)
end

function molecule.setDataDirectory(dir)
    dataDir = dir
end

local function read_xyz(file_name)
    if dataDir then file_name = dataDir .. "/" .. file_name end

    local file = io.open(file_name, "r")
    print(file, file_name)

    file:read() -- number of atoms
    file:read() -- molecule name

    mol = {}
    while (true) do
        local line = file:read()
        if not line then break end
        t = {}

        for s in string.gmatch(line, "%S+") do
            table.insert(t, s)
        end
        table.insert(mol, t)
    end
    return mol
end

local function read_pdb(file_name)
    if dataDir then file_name = dataDir .. "/" .. file_name end

    local file = io.open(file_name, "r")
    print(file, file_name)

    mol = {}
    while (true) do
        local line = file:read()
        if not line then break end
        if string.find(line, "ATOM") ~= nil then
            element = string.sub(line, 78, 80)
            element = element:match "^%s*(.-)%s*$"
            if element == "" then
                element = string.sub(line, 24, 25)
            end
            if element ~= "" then
                x = string.sub(line, 32, 38)
                y = string.sub(line, 39, 46)
                z = string.sub(line, 47, 54)
                t = {}
                table.insert(t, element)
                table.insert(t, x)
                table.insert(t, y)
                table.insert(t, z)
                table.insert(mol, t)
            end
        end
    end
    return mol
end

function molecule.initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    arg = 'mol_diff_gear.pdb'
    mol = read_pdb(arg)
    print("Loaded", arg)

    init_molecule(mol)
    gl.glBindVertexArray(0)
end

function molecule.exitGL()
    gl.glBindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog)
    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

local function draw_color_cube()
    gl.glBindVertexArray(vao)
    gl.glDrawElements(GL.GL_TRIANGLES, 6*3*2, GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)
end

local function draw_molecule()
    gl.glBindVertexArray(vao)
    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3 * num_atoms)
    gl.glBindVertexArray(0)
end

function molecule.render_for_one_eye(mview, proj)
    gl.glUseProgram(prog)
    gl.glUniformMatrix4fv(0, 1, GL.GL_FALSE, glFloatv(16, mview))
    gl.glUniformMatrix4fv(1, 1, GL.GL_FALSE, glFloatv(16, proj))

    draw_molecule()

    gl.glUseProgram(0)
end

function molecule.timestep(absTime, dt)
end

return molecule
