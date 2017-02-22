--[[ tunnel_vert.lua

    Generate a cylindrical mesh on the CPU using a loop and displace
    vertex locations in the vertex shader during draw for a wavy
    tunnel effect.
]]
tunnel_frag = {}

local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

local vbos = {}
local vao = 0
local prog = 0
local absT = 0
local texID = 0

local numTris = 6*3*2

local basic_vert = [[
#version 310 es

#ifdef GL_ES
precision highp float;
#endif

in vec4 vPosition;
in vec2 vColor;

out vec2 vfColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

uniform float absTime;

void main()
{
    vfColor = vColor.xy;
    vec4 pos = vPosition;
    pos.xy += .18 * vec2(
        sin(15.*pos.z + 6.*absTime),
        sin(15.*pos.z + 5.*absTime)
        );
    pos.z *= 15.;
    pos.z -= 10.;
    gl_Position = prmtx * mvmtx * pos;
}
]]

local basic_frag = [[
#version 310 es

#ifdef GL_ES
precision highp float;
precision mediump int;
#endif

in vec2 vfColor;
out vec4 fragColor;

uniform float absTime;
uniform sampler2D sTex;
float speed = 1.;

void main()
{
    //vec3 col = vec3(vfColor.x, vfColor.y, sin(100.*vfColor.z - 10.*absTime));

    // Map texture to the walls
    vec2 tc = fract(vec2(vfColor.x, 10.*vfColor.y - speed*absTime));
    vec3 col = texture(sTex, tc).xyz;

    fragColor = vec4(col, 1.0);
}
]]

function tunnel_frag.setDataDirectory(dir)
    dataDir = dir
end

local function load_textures()
    local texfilename = "stone_128x128.raw"
    if dataDir then texfilename = dataDir .. "/" .. texfilename end
    local w,h = 128,128
    local inp = io.open(texfilename, "rb")
    local data = nil
    if inp then
        data = inp:read("*all")
        assert(inp:close())
    end
    local dtxId = ffi.new("GLuint[1]")
    gl.glGenTextures(1, dtxId)
    texID = dtxId[0]
    gl.glBindTexture(GL.GL_TEXTURE_2D, texID)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_S, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_T, GL.GL_CLAMP_TO_EDGE)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_NEAREST)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_NEAREST)
    gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAX_LEVEL, 0)
    gl.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_RGB,
                  w, h, 0,
                  GL.GL_RGB, GL.GL_UNSIGNED_BYTE, data)
    gl.glBindTexture(GL.GL_TEXTURE_2D, 0)
end

local function generate_cylinder(slices, stacks)
    local n = slices
    local m = stacks
    local r = .3

    local v = {}
    local t = {}
    for j=0,m do
        for i=0,n do
            local phase = i / n
            local rot = 2 * math.pi * (phase+.5)
            local x,y = math.sin(rot), math.cos(rot)
            table.insert(v, r*x)
            table.insert(v, r*y)
            table.insert(v, j/m)
            table.insert(t, phase)
            table.insert(t, j/m)
        end
    end

    local f = {}
    for i=0,m*n-2 do
        table.insert(f, i+1)
        table.insert(f, i)
        table.insert(f, i+n+1)
        table.insert(f, i+1)
        table.insert(f, i+n+1)
        table.insert(f, i+n+2)
    end

    return v,t,f
end


local function init_cube_attributes()
    local v,t,f = generate_cylinder(64,64)
    local verts = glFloatv(#v, v)
    local texs = glFloatv(#t, t)
    local vpos_loc = gl.glGetAttribLocation(prog, "vPosition")
    local vcol_loc = gl.glGetAttribLocation(prog, "vColor")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, vvbo)

    local cvbo = glIntv(0)
    gl.glGenBuffers(1, cvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(texs), texs, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)

    numTris = #f
    local quads = glUintv(#f, f)
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.GL_STATIC_DRAW)
    table.insert(vbos, qvbo)
end

function tunnel_frag.initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    init_cube_attributes()
    load_textures()
    gl.glBindVertexArray(0)
end

function tunnel_frag.exitGL()
    gl.glBindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog)
    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)
    local texdel = ffi.new("GLuint[1]", texID)
    gl.glDeleteTextures(1,texdel)
end

function tunnel_frag.render_for_one_eye(view, proj)
    gl.glUseProgram(prog)

    local umv_loc = gl.glGetUniformLocation(prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(prog, "prmtx")
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))
    --gl.glPolygonMode(GL.GL_FRONT_AND_BACK, GL.GL_LINE)
    --gl.glEnable(GL.GL_CULL_FACE)

    local tloc = gl.glGetUniformLocation(prog, "absTime")
    gl.glUniform1f(tloc, absT)

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, texID)
    local stex_loc = gl.glGetUniformLocation(prog, "sTex")
    gl.glUniform1i(stex_loc, 0)

    gl.glBindVertexArray(vao)
    gl.glDrawElements(GL.GL_TRIANGLES, numTris, GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function tunnel_frag.timestep(absTime, dt)
    absT = absTime
end

return tunnel_frag
