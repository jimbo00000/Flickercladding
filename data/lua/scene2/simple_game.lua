--[[ simple_game.lua

    A rudimentary example of a game engine:
    Includes an audio library to play a sound sample on key press,
    receives input from keyboard and controller, and a simple
    collision check between shots and target objects.
]]
simple_game = {}

simple_game.__index = simple_game

function simple_game.new(...)
    local self = setmetatable({}, simple_game)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function simple_game:init()
    -- Object-internal state: hold a list of VBOs for deletion on exitGL
    self.vbos = {}
    self.vao = 0
    self.prog = 0
    self.texID = 0
    self.dataDir = nil
    self.bounce = 0
    self.shots = {}
    self.targets = {}
    self.origin = nil
    self.origin_matrix = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
    self.last_controllerstate = nil
end

function simple_game:setDataDirectory(dir)
    self.dataDir = dir
end

--local openGL = require("opengl")
local ffi = require("ffi")
local mm = require("util.matrixmath")
local sf = require("util.shaderfunctions")
local OriginLibrary = require("scene2.origin")

-- http://stackoverflow.com/questions/17877224/how-to-prevent-a-lua-script-from-failing-when-a-require-fails-to-find-the-scri
local function prequire(m) 
  local ok, err = pcall(require, m) 
  if not ok then return nil, err end
  return err
end

local bass, err = prequire("bass")
if bass == nil then
    print("Could not load Bass library: "..err)
end

local glIntv   = ffi.typeof('GLint[?]')
local glUintv  = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local basic_vert = [[
#version 310 es

in vec4 vPosition;
in vec4 vColor;

out vec3 vfColor;

uniform mat4 mvmtx;
uniform mat4 prmtx;

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

function simple_game:init_cube_attributes()
    local v = {
        0,0,0,
        1,0,0,
        1,1,0,
        0,1,0,
        0,0,1,
        1,0,1,
        1,1,1,
        0,1,1
    }
    local cols = glFloatv(#v, v)
    for i=1,#v do
        v[i] = v[i] - .5
    end
    local verts = glFloatv(#v, v)

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
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(cols), cols, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)

    local quads = glUintv(6*6, {
        0,3,2, 1,0,2,
        4,5,6, 7,4,6,
        1,2,6, 5,1,6,
        2,3,7, 6,2,7,
        3,0,4, 7,3,4,
        0,1,5, 4,0,5
    })
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.GL_STATIC_DRAW)
    table.insert(self.vbos, qvbo)
end

function simple_game:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    self:init_cube_attributes()
    gl.glBindVertexArray(0)

    -- Create an array of targets
    for i=0,10 do
        for j=0,10 do
            pos = {i*1.2,j*1.2,-5}
            target = {p=pos}
            table.insert(self.targets, target)
        end
    end

    -- Initialize audio library - BASS
    if bass then
        local init_ret = bass.BASS_Init(-1, 44100, 0, 0, nil)
        local sndfilename = "Blip5.wav"
        if self.dataDir then sndfilename = self.dataDir .. "/" .. sndfilename end
        self.sample = bass.BASS_SampleLoad(false, sndfilename, 0, 0, 16, 0)
        bass.BASS_Start()
        self.channel = bass.BASS_SampleGetChannel(self.sample, false)
    end

    self.origin = OriginLibrary.new()
    self.origin:initGL()
end

function simple_game:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)

    self.origin:exitGL()
end

function simple_game:draw_color_cube()
    gl.glBindVertexArray(self.vao)
    gl.glDrawElements(GL.GL_TRIANGLES, 6*3*2, GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)
end

function simple_game:render_for_one_eye(mview, proj)
    local umv_loc = gl.glGetUniformLocation(self.prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog, "prmtx")
    gl.glUseProgram(self.prog)
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    
    -- draw shots
    for _,s in pairs(self.shots) do
        local m = {}
        for i=1,16 do m[i] = mview[i] end
        local p = s.p
        mm.glh_translate(m, p[1], p[2], p[3])
        local z = s.r
        mm.glh_scale(m, z, z, z)

        gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))
        self:draw_color_cube()
    end

    -- draw targets
    for _,t in pairs(self.targets) do
        local m = {}
        for i=1,16 do m[i] = mview[i] end
        local p = t.p
        mm.glh_translate(m, p[1], p[2], p[3])

        gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))
        self:draw_color_cube()
    end

    -- Draw tracking origin markers over hands
    do
        local mx = {}
        for i=1,16 do mx[i] = mview[i] end
        if self.origin_matrix[1] ~= nil then
            mm.post_multiply(mx, self.origin_matrix)
        end
        self.origin:render_for_one_eye(mx, proj)
    end

    gl.glUseProgram(0)
end

function simple_game:timestep(absTime, dt)
    self.bounce = self.bounce + dt * 2 * (180/math.pi)

    -- advance shots
    for _,s in pairs(self.shots) do
        local p = s.p
        local v = s.v
        -- TODO: vector math is sounding good here
        for i=1,3 do
            p[i] = p[i] + dt * v[i]
        end
        s.age = s.age + dt
    end

    -- Check shot-target intersections
    for is,s in pairs(self.shots) do
        for it,t in pairs(self.targets) do
            local sp = s.p
            local tp = t.p
            -- get distance between the 2
            local dvec = {sp[1]-tp[1], sp[2]-tp[2], sp[3]-tp[3], }
            local dist = mm.length(dvec)
            local rsph = .73
            if dist < (rsph + s.r) then
                table.remove(self.targets, it)
            end
        end
        if s.age > 10 then
            table.remove(self.shots, is)
        end
    end
end

function simple_game:shoot(mtx)
    local pos = {0,0,0, 1}
    local vel = {0,0,-10, 0}
    pos = mm.transform(pos, mtx)
    vel = mm.transform(vel, mtx)

    shot = {p=pos, v=vel, r=.1, age=0}
    table.insert(self.shots, shot)
end

function simple_game:set_origin_matrix(m)
    if m then
        mm.affine_inverse(m)
        for i=1,16 do self.origin_matrix[i] = m[i] end
    end
end

function simple_game:keypressed(key)
    if bass then
        bass.BASS_ChannelPlay(self.channel, false)
    end

    self:shoot(self.origin_matrix)
end

-- Cast the array cdata ptr(passes from glm::value_ptr(glm::mat4),
-- which gives a float[16]) to a table for further manipulation here in Lua.
function array_to_table2(array)
    local m0 = ffi.cast("float*", array)
    -- The cdata array is 0-indexed. Here we clumsily jam it back
    -- into a Lua-style, 1-indexed table(array portion).
    local tab = {}
    for i=0,15 do tab[i+1] = m0[i] end
    return tab
end

function simple_game:settracking(absTime, controllerstate)
    if controllerstate == nil then return end
    if self.last_controllerstate ~= nil then
        local c1 = controllerstate[1]
        local c0 = self.last_controllerstate[1]
        if c0 ~= nil and c1 ~= nil then
            local m = array_to_table2(c1.mtx)
            for i=1,16 do origin_matrix[i] = m[i] end
            if c1.buttons ~= 0  and c0.buttons == 0 then
                scene.shoot(m)
            end
        end
    end
    self.last_controllerstate = controllerstate
end

local action_types = {
  [0] = "Down",
  [1] = "Up",
  [2] = "Move",
  [3] = "Cancel",
  [4] = "Outside",
  [5] = "PointerDown",
  [6] = "PointerUp",
}

function simple_game:onSingleTouch(pointerid, action, x, y)
    local actionflag = action % 255
    local a = action_types[actionflag]
    if a == "Down" or a == "PointerDown" then
        if bass then
            bass.BASS_ChannelPlay(self.channel, false)
        end

        self:shoot(self.origin_matrix)
    end
end


return simple_game
