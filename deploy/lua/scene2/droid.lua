--[[ droid.lua

    Generate some simple geometry procedurally.
]]
disc = {}

disc.__index = disc

function disc.new(...)
    local self = setmetatable({}, disc)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function disc:init()
    self.vbos = {}
    self.vao = 0
    self.prog = 0
end

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local Geom_Lib = require("util.geometry_functions")

local glIntv = ffi.typeof('GLint[?]')
local glUintv = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local basic_vert = [[
#version 310 es

in vec4 vPosition;
in vec4 vColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

out vec3 vfColor;

void main()
{
    vfColor = vColor.xyz;
    gl_Position = prmtx * mvmtx * vPosition;
}
]]


local basic_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec3 vfColor;
out vec4 fragColor;

void main()
{
    fragColor = vec4(vfColor, 1.0);
}
]]

function get_geometry()
    local slices, stacks = 16,32
    local bodyLen = 1.5
    local sc = 0.2

    local cylL = {Geom_Lib.generate_capsule(slices,stacks,6*3*sc)}
    local v = cylL[1]
    local num = #v/3
    for i=1,num do
        v[3*i-2] = v[3*i-2] * sc
        v[3*i-1] = v[3*i-1] * sc
        v[3*i-0] = v[3*i-0] * sc
        v[3*i-2] = v[3*i-2] + (1 + sc)
        v[3*i-0] = v[3*i-0] + sc
    end

    local cylR = {Geom_Lib.generate_capsule(slices,stacks,6*3*sc)}
    local v = cylR[1]
    local num = #v/3
    for i=1,num do
        v[3*i-2] = v[3*i-2] * sc
        v[3*i-1] = v[3*i-1] * sc
        v[3*i-0] = v[3*i-0] * sc
        v[3*i-2] = v[3*i-2] - (1 + sc)
        v[3*i-0] = v[3*i-0] + sc
    end

    local legOut = .4

    local legL = {Geom_Lib.generate_capsule(slices,stacks,3*3*sc)}
    local v = legL[1]
    local num = #v/3
    for i=1,num do
        v[3*i-2] = v[3*i-2] * sc
        v[3*i-1] = v[3*i-1] * sc
        v[3*i-0] = v[3*i-0] * sc
        v[3*i-0] = v[3*i-0] + bodyLen
        v[3*i-2] = v[3*i-2] - legOut
    end

    local legR = {Geom_Lib.generate_capsule(slices,stacks,3*3*sc)}
    local v = legR[1]
    local num = #v/3
    for i=1,num do
        v[3*i-2] = v[3*i-2] * sc
        v[3*i-1] = v[3*i-1] * sc
        v[3*i-0] = v[3*i-0] * sc
        v[3*i-0] = v[3*i-0] + bodyLen
        v[3*i-2] = v[3*i-2] + legOut
    end

    local meshes = {
        cylL,
        cylR,
        legL,
        legR,
        {Geom_Lib.generate_capped_cylinder(slices, stacks, bodyLen)},
    }

    local v,t,f = Geom_Lib.combine_meshes(meshes)
    -- Swap y and z
    local num = #v/3
    for i=1,num do
        v[3*i-1],v[3*i-0] = -v[3*i-0],v[3*i-1]
    end
    return v,t,f
end

function disc:init_attributes()
    local v,t,f = get_geometry()
    local verts = glFloatv(#v, v)
    local texs = glFloatv(#t, t)
    local vpos_loc = gl.glGetAttribLocation(self.prog, "vPosition")
    local vcol_loc = gl.glGetAttribLocation(self.prog, "vColor")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, vvbo)

    local cvbo = glIntv(0)
    gl.glGenBuffers(1, cvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(texs), texs, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)

    self.numTris = #f
    local quads = glUintv(#f, f)
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.GL_STATIC_DRAW)
    table.insert(self.vbos, qvbo)
end

function disc:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    self:init_attributes()
    gl.glBindVertexArray(0)
end

function disc:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
    gl.glBindVertexArray(0)
end

function disc:render_for_one_eye(view, proj)
    gl.glUseProgram(self.prog)
    --gl.glPolygonMode(GL.GL_FRONT_AND_BACK, GL.GL_LINE)
    --gl.glEnable(GL.GL_CULL_FACE)
    local umv_loc = gl.glGetUniformLocation(self.prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog, "prmtx")
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    gl.glBindVertexArray(self.vao)
    gl.glDrawElements(GL.GL_TRIANGLES, self.numTris, GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end

return disc
