-- stringedit_scene.lua
stringedit_scene = {}

require("util.glfont")
require("util.editbuffer")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local mm = require("util.matrixmath")
local fbf = require("util.fbofunctions")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

--[[
    Module-scope variables
]]
local glfont = nil
local editbuf = nil

local dataDir = nil
local lineh = 0
local scroll = 0

local vbos = {}
local vao = 0
local prog = 0

local fbo = nil
local fbw, fbh = 2048/2,1024/2
local textscale = .0008
local max_charw = 0
local editFilename = '../data/lua/scene/vsfstri.lua'
local draw_fbo = true
local visibleLines = 26 -- TODO: figure this out based on size


--[[
    Cursor drawing
    Program, VAO, font dimensions to match GLFont.
]]
local basic_vert = [[
#version 310 es

in vec4 vPosition;

layout(location = 0) uniform mat4 mvmtx;
layout(location = 1) uniform mat4 prmtx;

void main()
{
    gl_Position = prmtx * mvmtx * vPosition;
}
]]

local basic_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

layout(location = 2) uniform vec3 uColor;
out vec4 fragColor;

void main()
{
    fragColor = vec4(uColor, .5);
}
]]

local function init_cursor_attributes()
    -- Make sure font has been loaded to get these variables
    local x = max_charw
    local y = lineh
    local verts = glFloatv(6*3, {
        0,0,0,
        x,0,0,
        x,y,0,
        0,0,0,
        x,y,0,
        0,y,0,
        })

    local vpos_loc = gl.glGetAttribLocation(prog, "vPosition")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, vvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
end

function stringedit_scene.initGL_cursor()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    init_cursor_attributes()
    gl.glBindVertexArray(0)
end

function stringedit_scene.exitGL_cursor()
    gl.glBindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog)
    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)
end


function stringedit_scene.render_cursor(view, proj)
    local m = {}
    mm.make_identity_matrix(m)
    local aspect = fbw/fbh
    mm.glh_translate(m, -aspect, 1, 0) -- align to upper left corner
    mm.glh_translate(m, .25, 0, 0) -- show line numbers
    mm.glh_translate(m, 0, 0, .0002) -- put cursor in front
    local s = textscale
    mm.glh_scale(m, s, -s, s)

    local ccol, cline = editbuf.curcol, editbuf.curline
    mm.glh_translate(m, ccol*max_charw, (cline-1)*lineh, 0)
    mm.glh_translate(m, 0, -scroll * lineh, 0)
    mm.pre_multiply(m, view)

    gl.glEnable(GL.GL_BLEND)
    gl.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA);

    local umv_loc = 0
    local upr_loc = 1
    gl.glUseProgram(prog)
    local color = {1,0,0}
    gl.glUniform3f(2, color[1], color[2], color[3])
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, m))
    gl.glBindVertexArray(vao)
    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3*2)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)

    gl.glDisable(GL.GL_BLEND)
end






local vbos_quad = {}
local vao_quad = 0
local prog_quad = 0

local texquad_vert = [[
#version 310 es

layout(location = 0) in vec4 vPosition;
layout(location = 1) in vec4 vTexCoord;

layout(location = 0) uniform mat4 mvmtx;
layout(location = 1) uniform mat4 prmtx;

out vec3 vfTexCoord;

void main()
{
    vfTexCoord = vTexCoord.xyz;
    gl_Position = prmtx * mvmtx * vPosition;
}
]]


local texquad_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

layout(location = 2) uniform sampler2D sTex;

in vec3 vfTexCoord;
out vec4 fragColor;

void main()
{
    vec4 tcol = texture(sTex, vfTexCoord.xy);
    fragColor = vec4(tcol.xyz, .5);
}
]]

local function init_quad_attributes()
    local x = 1
    local y = 1
    local verts = glFloatv(6*3, {
        0,0,0,
        x,0,0,
        x,y,0,
        0,0,0,
        x,y,0,
        0,y,0,
        })

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(0, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos_quad, vvbo)

    local tvbo = glIntv(0)
    gl.glGenBuffers(1, tvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, tvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(1, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos_quad, tvbo)

    gl.glEnableVertexAttribArray(0)
    gl.glEnableVertexAttribArray(1)
end

function stringedit_scene.initGL_quad()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao_quad = vaoId[0]
    gl.glBindVertexArray(vao_quad)

    prog_quad = sf.make_shader_from_source({
        vsrc = texquad_vert,
        fsrc = texquad_frag,
        })

    init_quad_attributes()
    gl.glBindVertexArray(0)
end

function stringedit_scene.exitGL_quad()
    gl.glBindVertexArray(vao_quad)
    for _,v in pairs(vbos_quad) do
        gl.glDeleteBuffers(1,v)
    end
    vbos_quad = {}
    gl.glDeleteProgram(prog_quad)
    local vaoId = ffi.new("GLuint[1]", vao_quad)
    gl.glDeleteVertexArrays(1, vaoId)
end

function stringedit_scene.render_quad(view, proj)
    local umv_loc = 0
    local upr_loc = 1
    gl.glUseProgram(prog_quad)
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, proj))
    gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, view))

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, fbo.tex)
    gl.glUniform1i(2, 0)
    
    gl.glBindVertexArray(vao_quad)
    gl.glDrawArrays(GL.GL_TRIANGLES, 0, 3*2)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end








function stringedit_scene.setDataDirectory(dir)
    dataDir = dir
end

function stringedit_scene.initGL()
    local dir = "fonts"
    if dataDir then dir = dataDir .. "/" .. dir end
    glfont = GLFont.new('courier_512.fnt', 'courier_512_0.raw')
    glfont:setDataDirectory(dir)
    glfont:initGL()
    max_charw = glfont:get_max_char_width()
    lineh = glfont.font.common.lineHeight

    stringedit_scene.initGL_cursor()
    stringedit_scene.initGL_quad()

    editbuf = EditBuffer.new()
    editbuf:loadfromfile(editFilename)

    fbo = fbf.allocate_fbo(fbw, fbh)

    local vpdims = ffi.new("int[2]")
    gl.glGetIntegerv(GL.GL_MAX_VIEWPORT_DIMS, vpdims)
    print("Max vpdims: ", vpdims[0], vpdims[1])
end

function stringedit_scene.exitGL()
    glfont:exitGL()
    stringedit_scene.exitGL_cursor()
    stringedit_scene.exitGL_quad()
    fbf.deallocate_fbo(fbo)
end

function render_to_fbo()
    -- Set the bound FBO back when done
    local boundfbo = ffi.new("int[1]")
    gl.glGetIntegerv(GL.GL_FRAMEBUFFER_BINDING, boundfbo)

    fbf.bind_fbo(fbo)

    -- Set the viewport back when we're done
    local vpdims = ffi.new("int[4]")
    gl.glGetIntegerv(GL.GL_VIEWPORT, vpdims)

    gl.glViewport(0,0, fbw, fbh)

    local l = .2
    gl.glClearColor(l, l, l, 0)
    gl.glClear(GL.GL_COLOR_BUFFER_BIT + GL.GL_DEPTH_BUFFER_BIT)

    local aspect = fbw/fbh
    local orth = {}
    mm.glh_ortho(orth, -aspect,aspect,-1,1,-1,1)
    local id = {}
    mm.make_identity_matrix(id)
    render_text(id, orth)
    local cm = {}
    mm.make_identity_matrix(cm)
    stringedit_scene.render_cursor(cm, orth)

    -- Set the viewport back when we're done
    gl.glViewport(vpdims[0], vpdims[1], vpdims[2], vpdims[3])

    -- Set the FBO back when done
    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, boundfbo[0])
end

function render_text(view, proj)
    local m = {}
    mm.make_identity_matrix(m)
    local aspect = fbw/fbh
    mm.glh_translate(m, -aspect, 1, 0) -- align to upper left corner
    mm.glh_translate(m, .25, 0, 0) -- move right to show line numbers
    local s = textscale
    mm.glh_scale(m, s, -s, s)
    mm.pre_multiply(m, view)

    for i=1,visibleLines do
        local k = i + scroll
        local v = editbuf.lines[k]
        local col = {1, 1, 1}
        glfont:render_string(m, proj, col, v)

        -- Line numbers
        local ln = tostring(k)
        local lc = {.8, .8, .8}
        local mn = {}
        for i=1,16 do mn[i] = m[i] end
        mm.glh_translate(mn, -100-59*string.len(ln), 0, 0)
        glfont:render_string(mn, proj, lc, ln)

        mm.glh_translate(m, 0, lineh, 0)
    end
end

function stringedit_scene.render_for_one_eye(view, proj)
    if draw_fbo then
        render_to_fbo()

        local m = {}
        mm.make_identity_matrix(m)
        local s = 2
        mm.glh_scale(m, s, s, s)

        local aspect = fbo.w / fbo.h
        mm.glh_scale(m, aspect, 1, 1)

        mm.glh_translate(m, -.5, -.5, 0)
        mm.pre_multiply(m, view)
        stringedit_scene.render_quad(m, proj)
    else
        -- Floating text in space
        render_text(view, proj)
        stringedit_scene.render_cursor(view, proj)
    end
    
    -- Do this every once in a while to save memory
    glfont:deleteoldstrings()
end

function stringedit_scene.timestep(absTime, dt)
end

function stringedit_scene.keypressed(key, scancode, action, mods)
    if mods == 2 then -- ctrl held
        if action == 1 then -- press
            if key == string.byte('S') then
                print("Saving: "..editFilename)
                editbuf:savetofile(editFilename)
                return true
            elseif key == string.byte('F') then
                draw_fbo = not draw_fbo
            end
        end
    end

    local scrollAmt = 10
    local ch = key
    local func_table = {
        [259] = function (x) -- Backspace
            editbuf:backspace()
        end,
        [257] = function (x) -- Enter
            editbuf:enter()
        end,
        [262] = function (x) -- Right
            editbuf:cursormotion(1,0)
        end,
        [263] = function (x) -- Left
            editbuf:cursormotion(-1,0)
        end,
        [264] = function (x) -- Down
            editbuf:cursormotion(0,1)
            if scroll + visibleLines < editbuf.curline then
                scroll = editbuf.curline - visibleLines
                scroll = math.max(0, scroll)
            end
        end,
        [265] = function (x) -- Up
            editbuf:cursormotion(0,-1)
            if scroll >= editbuf.curline then
                scroll = editbuf.curline - 1
            end
        end,
        [266] = function (x) -- Page Up
            scroll = scroll - scrollAmt
            scroll = math.max(scroll, 0)
            editbuf:cursormotion(0,-scrollAmt)
        end,
        [267] = function (x) -- Page Down
            scroll = scroll + scrollAmt
            scroll = math.min(scroll, #editbuf.lines - visibleLines)
            editbuf:cursormotion(0,scrollAmt)
        end,
    }
    local f = func_table[ch]
    if f then
        f()
        return true
    end

    return false
end

function stringedit_scene.charkeypressed(ch)
    editbuf:addchar(ch)
    return true
end

return stringedit_scene
