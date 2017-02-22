-- nbody07.lua
--
-- same as 05 but with 04's variable block sizes
--
-- began as comp_scene.lua (c) 2015 James Susinno
-- portions (c) 2016 Mark Stock (markjstock@gmail.com)

nbody07 = {}

nbody07.__index = nbody07

function nbody07.new(...)
    local self = setmetatable({}, nbody07)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function nbody07:init()
    self.vbos = {}
    self.vao = 0
    self.prog_display = 0
    self.prog_accel = 0
    self.prog_acceltiled = 0
    self.prog_integrate = 0
end

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local mm = require("util.matrixmath")

-- Types from:
-- https://github.com/nanoant/glua/blob/master/init.lua
local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glCharv    = ffi.typeof('GLchar[?]')
local glSizeiv   = ffi.typeof('GLsizei[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')
local glConstCharpp = ffi.typeof('const GLchar *[1]')

local pt_vert = [[
#version 310 es
layout(location = 0) uniform mat4 View;
layout(location = 1) uniform mat4 Projection;
layout(location = 0) in vec4 vposition;
layout(location = 1) in vec4 vattribute;
layout(location = 2) in vec4 quadAttr;
out vec2 radbrite;
out vec2 txcoord;
void main() {
   radbrite = vattribute.wz;
   float rad = radbrite.x;
   float brite = radbrite.y;

   vec4 pos = View*vposition;
   vec4 ppos = Projection*pos;
   // their apparent radius
   //float fudge = rad * 0.02 * ppos.z;
   // minimum radius
   float fudge = 0.003 * ppos.z;
   float newrad = max(rad, fudge);
   brite = brite * rad / newrad;

   txcoord = quadAttr.xy;
   gl_Position = Projection * vec4((View * vposition).xyz + newrad*quadAttr.xyz, 1.);
}
]]

local rad_frag = [[
#version 310 es
#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif
in vec2 txcoord;
in vec2 radbrite;
layout(location = 0) out vec4 FragColor;
void main() {
   float rs = dot(txcoord, txcoord);
   float s = 1./(1.+16.*rs*rs*rs) - 0.06;
   float brite = radbrite.y;
   FragColor = s*vec4(brite, brite, brite, 1.0);
}
]]

local accel_comp = [[
#version 310 es
layout(local_size_x=128) in;

layout(location = 0) uniform float dt;
layout(std430, binding=0) restrict readonly buffer pblock { vec4 positions[]; };
layout(std430, binding=1) restrict readonly buffer mblock { vec4 attributes[]; };
layout(std430, binding=2) restrict buffer vblock { vec4 velocities[]; };
layout(std430, binding=3) restrict buffer ablock { vec4 accelerations[]; };

void main() {
   int N = int(gl_NumWorkGroups.x*gl_WorkGroupSize.x);
   int index = int(gl_GlobalInvocationID);

   vec3 position = positions[index].xyz;
   vec3 acceleration = vec3(0,0,0);
   for(int i = 0;i<N;++i) {
       vec3 other = positions[i].xyz;
       vec2 othermass = attributes[i].xy;
       vec3 diff = position - other;
       float invdist = 1.0/(length(diff)+othermass.y);
       acceleration -= diff * (othermass.x*invdist*invdist*invdist);
   }
   vec3 velocity = velocities[index].xyz;
   velocities[index] = vec4(velocity+0.5*dt*(acceleration+accelerations[index].xyz),0);
   accelerations[index] = vec4(acceleration,0);
}
]]

local accel_tiled_comp = [[
#version 310 es
layout(local_size_x=128) in;

layout(location = 0) uniform float dt;
layout(std430, binding=0) restrict readonly buffer pblock { vec4 positions[]; };
layout(std430, binding=1) restrict readonly buffer mblock { vec4 attributes[]; };
layout(std430, binding=2) restrict buffer vblock { vec4 velocities[]; };
layout(std430, binding=3) restrict buffer ablock { vec4 accelerations[]; };

shared vec4 tmp[gl_WorkGroupSize.x];
shared vec4 tmpmass[gl_WorkGroupSize.x];
void main() {
   int N = int(gl_NumWorkGroups.x*gl_WorkGroupSize.x);
   int index = int(gl_GlobalInvocationID);
   vec3 position = positions[index].xyz;
   vec3 acceleration = vec3(0,0,0);
   for(int tile = 0;tile<N;tile+=int(gl_WorkGroupSize.x)) {
       tmp[gl_LocalInvocationIndex] = positions[tile + int(gl_LocalInvocationIndex)];
       tmpmass[gl_LocalInvocationIndex] = attributes[tile + int(gl_LocalInvocationIndex)];
       groupMemoryBarrier();
       barrier();

       int wsz = int(gl_WorkGroupSize.x);
       for(int i = 0;i<wsz;++i) {
           vec3 other = tmp[i].xyz;
           vec2 othermass = tmpmass[i].xy;
           vec3 diff = position - other;
           float invdist = 1.0/(length(diff)+othermass.y);
           acceleration -= diff * (othermass.x*invdist*invdist*invdist);
       }
       groupMemoryBarrier();
       barrier();
   }
   vec3 velocity = velocities[index].xyz;
   velocities[index] = vec4(velocity+0.5*dt*(acceleration+accelerations[index].xyz),0);
   accelerations[index] = vec4(acceleration,0);
}
]]

local integ_comp = [[
#version 310 es
layout(local_size_x=128) in;

layout(location = 0) uniform float dt;
layout(std430, binding=0) restrict buffer pblock { vec4 positions[]; };
layout(std430, binding=1) restrict readonly buffer mblock { vec4 attributes[]; };
layout(std430, binding=2) restrict readonly buffer vblock { vec4 velocities[]; };
layout(std430, binding=3) restrict readonly buffer ablock { vec4 accelerations[]; };

void main() {
   int index = int(gl_GlobalInvocationID);
   vec4 position = positions[index];
   vec4 velocity = velocities[index];
   vec4 accel = accelerations[index];
   position.xyz += dt*(velocity.xyz + 0.5*dt*accel.xyz);
   positions[index] = position;
}
]]

local particles = 24*1024/2
local galaxysize = 10.0
local aspect = 0.1

function nbody07:init_point_attributes()
    -- attribute array: mass, radsq, brite, rad
    -- position array: x, y, z, 1
    pos_array = ffi.new("float[?]", particles*4)
    --   this is to allow creation of dark matter (dark, heavy, large radius)
    att_array = ffi.new("float[?]", particles*4)
    -- velocity array: dx/dt, dy/dt, dz/dt, 1
    vel_array = ffi.new("float[?]", particles*4)
    -- acceleration array
    acc_array = ffi.new("float[?]", particles*4)

    -- initialize particles

    -- first attributes
    for i=0,particles-1 do
        if math.random() < -0.1 then
            -- dark matter
            -- mass from 1 to 10
            att_array[4*i+0] = 1. + 9. * math.random()
            -- brite is always zero
            att_array[4*i+2] = 0.0
            -- radius follows mass
            att_array[4*i+3] = 0.2 * att_array[4*i+0]
            -- rad squared is self-explanatory
            att_array[4*i+1] = att_array[4*i+3] * att_array[4*i+3]
        else
            -- bright star
            -- brite from 0.1 to 1.0
            --att_array[4*i+2] = 0.05 + 0.9 * math.random()
            att_array[4*i+2] = math.pow(0.1 + 0.9 * math.random(), 2)
            -- mass from 0.01 to 1.0
            --att_array[4*i+0] = att_array[4*i+2] * att_array[4*i+2]
            att_array[4*i+0] = att_array[4*i+2]
            -- radius follows brite, but smaller
            --att_array[4*i+3] = 0.2 * att_array[4*i+2]
            att_array[4*i+3] = 0.06 + 0.3 * math.random()
            --att_array[4*i+3] = 0.1 + 0.25 * math.random()
            -- rad squared is self-explanatory
            att_array[4*i+1] = 10. * att_array[4*i+3] * att_array[4*i+3]
            -- nah, totally redo brite
            --att_array[4*i+2] = 1.0 - att_array[4*i+2]
        end
    end

    -- then positions
    for i=0,particles-1 do
        local x = 2*math.random()-1
        local y = 2*math.random()-1
        local dist = x*x + y*y
        while dist > 1.0 do
            x = 2*math.random()-1
            y = 2*math.random()-1
            dist = x*x + y*y
        end
        pos_array[4*i+0] = galaxysize * x
        pos_array[4*i+1] = galaxysize * y
        pos_array[4*i+2] = galaxysize * aspect * (2*math.random()-1)
        pos_array[4*i+3] = 1
    end

    -- then velocities
    for i=0,particles-1 do
        local dist = math.sqrt(pos_array[4*i+0]*pos_array[4*i+0] + pos_array[4*i+1]*pos_array[4*i+1])
        local scale = 3.5
        vel_array[4*i+0] = -pos_array[4*i+1] * scale
        vel_array[4*i+1] = pos_array[4*i+0] * scale
        vel_array[4*i+2] = scale * (2*math.random()-1)
        vel_array[4*i+3] = 0
    end
    for i=0,4*particles-1 do
        acc_array[i] = 0
    end

    -- set up buffers to contain this data
    local vboIds = ffi.new("int[4]")
    gl.glGenBuffers(4, vboIds)
    
    local vboP = vboIds[0]
    local vboM = vboIds[1]
    local vboV = vboIds[2]
    local vboA = vboIds[3]
    --local vboV1 = vboIds[2]

    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vboP)
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(pos_array), pos_array, GL.GL_DYNAMIC_COPY)
    
    gl.glEnableVertexAttribArray(0)
    gl.glVertexAttribPointer(0, 4, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glVertexAttribDivisor(0, 1)
    
    -- what do I map this to to get the data passed into the draw pipeline?
    --   the particle radius and brightness need to be used
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vboM)
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(att_array), att_array, GL.GL_DYNAMIC_COPY)
    
    gl.glEnableVertexAttribArray(1)
    gl.glVertexAttribPointer(1, 4, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glVertexAttribDivisor(1, 1)
    

    -- now one or more velocity arrays
    gl.glBindBuffer(GL.GL_SHADER_STORAGE_BUFFER, vboV)
    gl.glBufferData(GL.GL_SHADER_STORAGE_BUFFER, ffi.sizeof(vel_array), vel_array, GL.GL_DYNAMIC_COPY)
    
    gl.glBindBuffer(GL.GL_SHADER_STORAGE_BUFFER, vboA)
    gl.glBufferData(GL.GL_SHADER_STORAGE_BUFFER, ffi.sizeof(acc_array), acc_array, GL.GL_DYNAMIC_COPY)
    
    -- and get these ready for the compute shaders
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 0, vboP)
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 1, vboM)
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 2, vboV)
    gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 3, vboA)
    --gl.glBindBufferBase(GL.GL_SHADER_STORAGE_BUFFER, 1, vboV1)

    table.insert(self.vbos, vboP)
    table.insert(self.vbos, vboM)
    table.insert(self.vbos, vboV)
    table.insert(self.vbos, vboA)
    
    local dt = 1/1000
    
    gl.glUseProgram(self.prog_accel)
    gl.glUniform1f(0, dt)
    gl.glUseProgram(self.prog_acceltiled)
    gl.glUniform1f(0, dt)
    gl.glUseProgram(self.prog_integrate)
    gl.glUniform1f(0, dt)
end

function nbody07:init_quad_attributes()
    local verts = glFloatv(4*3, {
        -1,-1,0,
        1,-1,0,
        1,1,0,
        -1,1,0,
        })

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(2, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, vvbo[0])

    gl.glEnableVertexAttribArray(2)
end

function nbody07:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog_display = sf.make_shader_from_source({
        vsrc = pt_vert,
        fsrc = rad_frag,
        })

    self.prog_accel = sf.make_shader_from_source({
        compsrc = accel_comp,
        })
    self.prog_acceltiled = sf.make_shader_from_source({
        compsrc = accel_tiled_comp,
        })
    self.prog_integrate = sf.make_shader_from_source({
        compsrc = integ_comp,
        })

    self:init_point_attributes()
    self:init_quad_attributes()
    gl.glBindVertexArray(0)
end

function nbody07:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        local vboId = ffi.new("GLuint[1]", v)
        gl.glDeleteBuffers(1,vboId)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog_display)
    gl.glDeleteProgram(self.prog_accel)
    gl.glDeleteProgram(self.prog_acceltiled)
    gl.glDeleteProgram(self.prog_integrate)
    local vaoId = ffi.new("GLuint[2]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

function nbody07:render_for_one_eye(mview, proj)
    gl.glUseProgram(self.prog_display)
    gl.glClearColor(0,0,0,0)
    gl.glClear(GL.GL_COLOR_BUFFER_BIT)
    
    gl.glUniformMatrix4fv(0, 1, GL.GL_FALSE, glFloatv(16, mview))
    gl.glUniformMatrix4fv(1, 1, GL.GL_FALSE, glFloatv(16, proj))

    gl.glDisable(GL.GL_DEPTH_TEST)
    gl.glEnable(GL.GL_BLEND)
    --gl.glBlendFunc(GL.GL_ONE, GL.GL_ONE)
    --gl.glBlendFunc(GL.GL_ONE, GL.GL_ONE_MINUS_SRC_COLOR)
    gl.glBlendFunc(GL.GL_SRC_COLOR, GL.GL_ONE_MINUS_SRC_COLOR)
    gl.glBindVertexArray(self.vao)
    --gl.glDrawArrays(GL.GL_POINTS, 0, particles)
    gl.glDrawArraysInstanced(GL.GL_TRIANGLE_FAN, 0, 4, particles)
    gl.glBindVertexArray(0)
    gl.glEnable(GL.GL_DEPTH_TEST)
    gl.glDisable(GL.GL_BLEND)

    gl.glUseProgram(0)
end

function nbody07:timestep(absTime, dt)
    
    gl.glUseProgram(self.prog_acceltiled)
    --gl.glUseProgram(prog_accel)
    gl.glDispatchCompute(particles/128, 1, 1)

    gl.glUseProgram(self.prog_integrate)
    gl.glDispatchCompute(particles/128, 1, 1)
    gl.glUseProgram(0)
end

return nbody07
