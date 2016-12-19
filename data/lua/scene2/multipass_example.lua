--[[ multipass_example.lua

    A scene that contains its own fbo, performing its own
    render pass so it can display the output in itself.

    This scene is almost a strange loop; prepare for things to
    get a little weird.
]]
multipass_example = {}

multipass_example.__index = multipass_example

function multipass_example.new(...)
    local self = setmetatable({}, multipass_example)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function multipass_example:init()
    self.vbos = {}
    self.vao = 0
    self.prog = 0
    self.fw,self.fh = 512,512
    self.dataDir = nil
    self.scene_idx = 0
end

local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local mm = require("util.matrixmath")
local SceneLibrary = require("scene2.hybrid_scene") -- any scene here
local EffectLibrary = require("effect2.effect_chain")
local FrustumLibrary = require("scene2.frustum") -- for visualization

local glIntv = ffi.typeof('GLint[?]')
local glUintv = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

-- duplicated from main
function multipass_example:switch_to_scene(name)
    if self.subject and self.subject.exitGL then
        self.subject:exitGL()
    end
    package.loaded[name] = nil
    self.subject = nil

    if not self.subject then
        SceneLibrary = require(name)
        self.subject = SceneLibrary.new()
        if self.subject then
            if self.subject.setDataDirectory then self.subject:setDataDirectory(self.dataDir) end
            self.subject:initGL()
        end
    end
end

local basic_vert = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

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

uniform sampler2D sTex;

void main()
{
    vec4 tc = texture(sTex, vfColor.xy);
    fragColor = vec4(tc.xyz, 1.);
}
]]

function multipass_example:init_quad_attributes()
    local verts = glFloatv(4*3, {
        0,0,0,
        1,0,0,
        1,1,0,
        0,1,0,
        })

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
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(self.vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)
end

function multipass_example:setDataDirectory(dir)
    self.dataDir = dir
    --if self.subject.setDataDirectory then self.subject:setDataDirectory(dir) end
end

function multipass_example:initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    self.vao = vaoId[0]
    gl.glBindVertexArray(self.vao)

    self.prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    self:init_quad_attributes()
    gl.glBindVertexArray(0)

    self.frustum = FrustumLibrary.new()
    self.frustum:initGL()

    self:switch_to_scene("scene2.hybrid_scene")

    self.PostFX = EffectLibrary.new()
    if self.PostFX then self.PostFX:initGL(self.fw, self.fh) end
end

function multipass_example:exitGL()
    gl.glBindVertexArray(self.vao)
    for _,v in pairs(self.vbos) do
        gl.glDeleteBuffers(1,v)
    end
    self.vbos = {}
    gl.glDeleteProgram(self.prog)
    local vaoId = ffi.new("GLuint[1]", self.vao)
    gl.glDeleteVertexArrays(1, vaoId)

    self.subject:exitGL()
    self.frustum:exitGL()
    if self.PostFX then self.PostFX:exitGL() end
end

-- This is the "scene within a scene" that will appear in the FBO
function multipass_example:render_scene(view, proj)
    gl.glClearColor(0.3,0.3,0.3,0)
    gl.glClear(GL.GL_COLOR_BUFFER_BIT + GL.GL_DEPTH_BUFFER_BIT)
    self.subject:render_for_one_eye(view, proj)
end

-- Render to the internal buffer owned by this scene
-- View is determined by the scene's "internal camera" and
-- is set by the caller, render_for_one_eye.
function multipass_example:render_pre_pass(view, proj)
    -- Save viewport dimensions
    -- TODO: this is very inefficient; store them manually, restore at caller
    local vp = ffi.new("GLuint[4]", 0,0,0,0)
    gl.glGetIntegerv(GL.GL_VIEWPORT, vp)
    -- Save bound FBO
    local boundfbo = ffi.new("int[1]")
    gl.glGetIntegerv(GL.GL_FRAMEBUFFER_BINDING, boundfbo)

    -- Draw quad scene to this scene's first internal fbo
    if self.PostFX then self.PostFX:bind_fbo() end
    gl.glEnable(GL.GL_DEPTH_TEST)
    self:render_scene(view, proj)
    if self.PostFX then self.PostFX:unbind_fbo() end
    gl.glEnable(GL.GL_DEPTH_TEST)

    -- Restore viewport
    gl.glViewport(vp[0],vp[1],vp[2],vp[3])
    -- Restore FBO binding
    if boundfbo[0] ~= 0 then
        gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, boundfbo[0])
    end
end

-- Return a list of textures from the filter chain
function multipass_example:get_fbo_tex_sources()
    texs = {}
    if self.PostFX.get_filters then
        local filts = self.PostFX:get_filters()
        if filts then
            for _,v in pairs(filts) do
                table.insert(texs, v.fbo.tex)
            end
        end
    elseif self.PostFX.fbo then
        table.insert(self.PostFX.fbo.tex)
    end
    return texs
end

function multipass_example:render_fbo_quad(view, proj, tex)
    gl.glUseProgram(self.prog)
    local umv_loc = gl.glGetUniformLocation(self.prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(self.prog, "prmtx")
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, tex)
    local tx_loc = gl.glGetUniformLocation(self.prog, "tex")
    gl.glUniform1i(tx_loc, 0)

    gl.glBindVertexArray(self.vao)
    gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end

-- Draw the 3D scene within a scene with a textured quad showing
-- the content of the first fbo floating right there in space.
function multipass_example:render_scene_in_space(view, proj)
    gl.glEnable(GL.GL_DEPTH_TEST)
    local m = {}
    for i=1,16 do m[i] = view[i] end

    -- Render a stack of fbo quads in space behind the view frustum
    local q = {}
    for i=1,16 do q[i] = m[i] end
    local s = 3.5
    mm.glh_scale(q, s,s,1)
    --mm.glh_translate(q, 1,1,0)
    mm.glh_translate(q, -.5,-.5,-1.01)
    local texs = self:get_fbo_tex_sources()
    for _,t in pairs(texs) do
        self:render_fbo_quad(q, proj, t)
        mm.glh_translate(q, -.2,.1,-1)
    end

    -- Render the scene from an external perspective
    self.subject:render_for_one_eye(m, proj)

    -- Render a representation of the viewing frustum of the other camera
    local z =2
    mm.glh_translate(m, 0,0,z)
    self.frustum:render_for_one_eye(m, proj)
end

-- Draw each fbo quad in the filter chain as a HUD in screen space.
-- Try to fit them in sort of neatly, but perfection is out of scope here
-- without developing a whole GUI system.
function multipass_example:render_hud(view, proj)
    gl.glDisable(GL.GL_DEPTH_TEST)

    local p = {}
    mm.make_identity_matrix(p)
    local v = {}
    mm.make_identity_matrix(v)
    -- Line up all quads along the right side of the screen
    local s = .5
    mm.glh_scale(v,s,s,s)
    mm.glh_translate(v,1,1,0)

    local texs = self:get_fbo_tex_sources()
    for _,t in pairs(texs) do
        self:render_fbo_quad(v, p, t)
        mm.glh_translate(v, 0,-4/(#texs),0)
    end
    gl.glEnable(GL.GL_DEPTH_TEST)
end

-- The normal entry point where we draw the scene in space
-- with an extra preceding step
function multipass_example:render_for_one_eye(view, proj)
    -- Fixed camera view for the scene within a scene
    local cam = {}
    mm.make_identity_matrix(cam)
    mm.glh_translate(cam, 0,0,-1)
    self:render_pre_pass(cam, proj)

    -- Here is a view of the scene within a scene:
    -- External camera transform; move the whole scene
    -- back a bit and turn.
    local txfm = {}
    mm.make_identity_matrix(txfm)
    mm.glh_rotate(txfm, 60, 0,1,0)
    mm.glh_translate(txfm, 1,0,-2)
    mm.post_multiply(view, txfm)
    
    self:render_scene_in_space(view, proj)

    -- TODO: draw these first with depth written out as topmost
    self:render_hud(view, proj)
end

function multipass_example:timestep(absTime, dt)
    if self.subject and self.subject.timestep then self.subject:timestep(absTime, dt) end
    if self.PostFX and self.PostFX.timestep then self.PostFX:timestep(absTime, dt) end
end

--
-- This section below is almost a straight copy of what's in main.
-- Could we factor this out into a module? Then things could get
-- really weird...
--
local scene_names = {
    "scene2.vsfstri",
    "scene2.clockface",
    "scene2.colorcube",
    "scene2.font_test",
    "scene2.eyetest",
    "scene2.julia_set",
    "scene2.hybrid_scene",
    "scene2.cubemap",
    "scene2.moon",
    "scene2.nbody07",
};

function multipass_example:keypressed(key)
    -- 49 == '1' in glfw
    local name = scene_names[key - 49 + 1]
    if name then self:switch_to_scene(name) return end

    -- 290 == F1 in glfw
    self.PostFX:remove_effect_at_index(key - 290 + 1)

    -- 70 == 'f' in glfw
    local filter_names = {
        "invert",
        "hueshift",
        "wiggle",
        "wobble",
        "convolve",
        "scanline",
        "passthrough",
    }
    self.PostFX:insert_effect_by_name(filter_names[key - 70 + 1])
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

function multipass_example:onSingleTouch(pointerid, action, x, y)
    local actionflag = action % 255
    local a = action_types[actionflag]
    if a == "Down" or a == "PointerDown" then
        self.scene_idx = self.scene_idx + 1
        if self.scene_idx > #scene_names then self.scene_idx = 1 end
        self:switch_to_scene(scene_names[self.scene_idx])
    end
end

return multipass_example
