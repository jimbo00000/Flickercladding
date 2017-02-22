--[[ tunnel_frag.lua

    Draws a single colored quad covering the entire screen(viewport).

    Creates a tunnel effect in pure fragment shader using atan(). Maps a
    repeating texture to the tunnel wall and applies some fog to the area
    around the vanishing point where aliasing dominates.

    http://benryves.com/tutorials/tunnel/2
    http://lodev.org/cgtutor/tunnel.html
]]
tunnel_frag = {}

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glUintv  = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local vbos = {}
local vao = 0
local prog = 0
local absT = 0
local texID = 0

local basic_vert = [[
#version 300 es

in vec2 vPosition;
in vec2 vColor;

out vec2 vfUV;

void main()
{
    vfUV = vColor.yx;
    gl_Position = vec4(vPosition, 0., 1.);
}
]]

local basic_frag = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec2 vfUV;
out vec4 fragColor;

uniform float absTime;
uniform sampler2D sTex;
float speed = 10.;

#define PI 3.14159265359    

void main()
{
    float angle_11 = atan(vfUV.y, vfUV.x) / PI; // atan range in [-PI,PI]
    float angle01 = .5*(1. + angle_11);
    float radial = 1. / (vfUV.x*vfUV.x + vfUV.y*vfUV.y);

    //vec3 col = vec3(0., sin(2.*radial + speed*absTime), 0.);
    //col *= 2.*pow(length(vfUV), 3.);

    // Map texture to the walls
    float z = radial + speed*absTime;
    vec2 tc = fract(vec2(2.*angle01, .1*z));
    vec3 col = texture(sTex, tc).xyz;

    // Put some fog/darkness at the end of the tunnel to
    // obscure a rather unsightly infinity.
    col = mix(col, vec3(0.), 1.-clamp(length(vfUV), 0., 1.));

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

local function init_quad_attributes()
    local verts = glFloatv(4*2, {
        -1,-1,
        1,-1,
        1,1,
        -1,1,
        })

    local vpos_loc = gl.glGetAttribLocation(prog, "vPosition")
    local vcol_loc = gl.glGetAttribLocation(prog, "vColor")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, vvbo)

    local cvbo = glIntv(0)
    gl.glGenBuffers(1, cvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)

    local quads = glUintv(6*2, {
        0,1,2,
        0,2,3,
    })
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

    init_quad_attributes()
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
    gl.glBindVertexArray(vao)

    local tloc = gl.glGetUniformLocation(prog, "absTime")
    gl.glUniform1f(tloc, absT)

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, texID)
    local stex_loc = gl.glGetUniformLocation(prog, "sTex")
    gl.glUniform1i(stex_loc, 0)

    gl.glDrawElements(GL.GL_TRIANGLES, 6, GL.GL_UNSIGNED_INT, nil)

    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end

function tunnel_frag.timestep(absTime, dt)
    absT = absTime
end

return tunnel_frag
