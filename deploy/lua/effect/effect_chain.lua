--[[ effect_chain.lua

    Holds a list of post-processing shaders.
    Call bind and unbind to draw into the buffer and present to flush.
    This file contains a list of example filter shader sources that can
    be included in the filters table with table.insert.
]]

effect_chain = {}

effect_chain.__index = effect_chain

function effect_chain.new(...)
    local self = setmetatable({}, effect_chain)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function effect_chain:init(params)
    self.vbos = {}
    self.vao = 0
    self.time = 0
    self.filters = {}

    -- Default filter selection
    self.filter_names = {

        "sidebyside_double",
        "lenswarp",
        "beamrace",

    --[[
        "invert",
        "hueshift",
        "wiggle",
        "wobble",
        "convolve",
        "scanline",]]
        "passthrough",
    }

    if not params then return end
    if params.filter_names then
        self.filter_names = params.filter_names
    end
end

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")
local spf = require("effect.single_pass_filters")

local glIntv   = ffi.typeof('GLint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

require("util.filter")

function effect_chain:insert_effect_by_name(name,w,h)
    if not name then return end

    local params = {}
    -- Recognize the filter name 'downsample' and manually add in
    -- a smaller texture downsampling stage.
    if name:sub(0,10) == "downsample" then
        local factor = 4
        name = "passthrough"
        params.sample_factor = 1/factor
    end
    params.name = name
    params.source = spf[name]

    local filt = Filter.new(params)
    filt:initGL()

    -- Get w,h from the first fbo in the list if not specified.
    if not w then
        local first = self.filters[1].fbo
        w,h = first.w, first.h
    end
    filt:resize(w,h)

    -- Re-use the VBO for each program
    local vpos_loc = gl.glGetAttribLocation(filt.prog, "vPosition")
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glEnableVertexAttribArray(vpos_loc)

    table.insert(self.filters, filt)
end

function effect_chain:remove_effect_at_index(index)
    if #self.filters <= 1 then return end
    if index < 1 or index > #self.filters then return end
    table.remove(self.filters, index)
end

function effect_chain:remove_all_effects(index)
    local num = #self.filters
    for i=1,num do
        effect_chain:remove_effect_at_index(1)
    end
end

-- For accessing filter list outside of module
function effect_chain:get_filters()
    return self.filters
end

function effect_chain:make_quad_vbos()
    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    table.insert(self.vbos, vvbo)

    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    local verts = glFloatv(4*2, {
        -1,-1,
        1,-1,
        1,1,
        -1,1,
        })
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
end

function effect_chain:initGL(w,h)
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self:make_quad_vbos()

    --table.insert(filters, Filter.new({name="Downsample",source=spf["passthrough"],sample_factor=1/4}))
    for _,n in pairs(self.filter_names) do
        self:insert_effect_by_name(n,w,h)
    end

    gl.glBindVertexArray(0)
end

function effect_chain:exitGL()
    for k,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}

    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)

    for _,f in pairs(self.filters) do
        f:exitGL()
    end
end

function effect_chain:resize_fbo(w,h)
    for _,f in pairs(self.filters) do
        f:resize(w,h)
    end
end

function effect_chain:bind_fbo()
    local filter = self.filters[1]
    if not filter then return end
    if filter.fbo then
        fbf.bind_fbo(filter.fbo)
        gl.glViewport(0,0, filter.fbo.w, filter.fbo.h)
    end
end

function effect_chain:draw(prog, w, h, srctex)
    gl.glUseProgram(prog)

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, srctex)
    local tx_loc = gl.glGetUniformLocation(prog, "tex")
    gl.glUniform1i(tx_loc, 0)

    -- If these uniforms are not present, we get location -1.
    -- Calling glUniform on that location doesn't hurt, apparently...
    local rx_loc = gl.glGetUniformLocation(prog, "ResolutionX")
    gl.glUniform1i(rx_loc, w)
    local ry_loc = gl.glGetUniformLocation(prog, "ResolutionY")
    gl.glUniform1i(ry_loc, h)

    local t_loc = gl.glGetUniformLocation(prog, "time")
    gl.glUniform1f(t_loc, self.time)

    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function effect_chain:flush()
    gl.glDisable(GL.GL_DEPTH_TEST)
    for i=1,#self.filters-1 do
        local source = self.filters[i]
        local dest = self.filters[i+1]
        if not source or not dest then return end

        local f = dest.fbo
        if f then
            fbf.bind_fbo(f)
            gl.glViewport(0,0, f.w, f.h)
        end

        self:draw(source.prog, f.w, f.h, source.fbo.tex)
    end
end

function effect_chain:unbind_fbo()
    -- We could flush here, or at the start of present.
    -- Let's do it here.
    self:flush()
    fbf.unbind_fbo()
end

function effect_chain:present()
    -- if list empty, do nothing
    local filter = self.filters[#self.filters]
    if not filter then return end

    -- Display last effect's output to screen(bind fbo 0)
    local f = filter.fbo
    self:draw(filter.prog, f.w, f.h, f.tex)
end

function effect_chain:timestep(absTime, dt)
    self.time = absTime
end

return effect_chain
