--[[ touchtris.lua

    Draws a triangle over each tracked touch pointer.

    Touch events are delivered via the function onSingleTouch.
    When a touch event arrives, its state is saved in a local array
    so triangles can be drawn over each touch point.

    Touch points are delivered in pixel coordinates from the window,
    so we have to keep track of how big the window is in pixels.
    This information is delivered via the setWindowSize function.
    Touch pointer state is stored in normalized [0,1] coordinates
    which are obtained by simply dividing coords by window size.
    When drawing is done, the [0,1] interval is stratched over
    the entire viewport(screen).
]]
touchtris = {}

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local mm = require("util.matrixmath")

local glIntv     = ffi.typeof('GLint[?]')
local glUintv    = ffi.typeof('GLuint[?]')
local glFloatv   = ffi.typeof('GLfloat[?]')

local vbos = {}
local vao = 0
local prog = 0

local winw,winh = 0,0 -- Window dimension in pixels
local pointers = {} -- Holds state of pointers for drawing

local basic_vert = [[
#version 300 es

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
#version 300 es

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


local function init_cube_attributes()
    local verts = glFloatv(3*3, {
        0,0,0,
        1,0,0,
        0,1,0,
        })

    local vpos_loc = gl.glGetAttribLocation(prog, "vPosition")
    local vcol_loc = gl.glGetAttribLocation(prog, "vColor")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, vvbo)

    local cols = glFloatv(3*3, {
        1,1,1,
        1,0,0,
        1,1,0,
        })

    local cvbo = glIntv(0)
    gl.glGenBuffers(1, cvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, cvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(cols), cols, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vcol_loc, 3, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, cvbo)

    gl.glEnableVertexAttribArray(vpos_loc)
    gl.glEnableVertexAttribArray(vcol_loc)

    local quads = glUintv(6*6, {
        0,1,2,
    })
    local qvbo = glIntv(0)
    gl.glGenBuffers(1, qvbo)
    gl.glBindBuffer(GL.GL_ELEMENT_ARRAY_BUFFER, qvbo[0])
    gl.glBufferData(GL.GL_ELEMENT_ARRAY_BUFFER, ffi.sizeof(quads), quads, GL.GL_STATIC_DRAW)
    table.insert(vbos, qvbo)
end

function touchtris.initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    init_cube_attributes()
    gl.glBindVertexArray(0)
end

function touchtris.exitGL()
    gl.glBindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog)
    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)
end

-- The passed in view and proj matrices are ignored, drawing everything
-- in flat, local screen space.
function touchtris.render_for_one_eye(view, proj)
    local umv_loc = gl.glGetUniformLocation(prog, "mvmtx")
    local upr_loc = gl.glGetUniformLocation(prog, "prmtx")
    gl.glUseProgram(prog)
    local id = {}
    mm.make_identity_matrix(id)
    gl.glUniformMatrix4fv(upr_loc, 1, GL.GL_FALSE, glFloatv(16, id))

    gl.glBindVertexArray(vao)
    for k,p in pairs(pointers) do
        local tx = {}
        if p then
            local x,y = p.x, -p.y
            x = 2*x - 1
            y = 2*y + 1
            mm.make_translation_matrix(tx, x, y, 0)
            local sm = {}
            local s = .25
            mm.make_scale_matrix(sm, s,s,s)
            mm.post_multiply(tx, sm)
            gl.glUniformMatrix4fv(umv_loc, 1, GL.GL_FALSE, glFloatv(16, tx))
        end

        gl.glDrawElements(GL.GL_TRIANGLES, 3, GL.GL_UNSIGNED_INT, nil)
    end
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function touchtris.timestep(absTime, dt)
end

function touchtris.onSingleTouch(pointerid, action, x, y)
    pointers[pointerid] = {x=x/winw, y=y/winh}

    -- Actions 1 and 6 are "up" actions, indicating a pointer
    -- has been lifted from the touchscreen.
    if action == 1 or action == 6 then
        pointers[pointerid] = nil
    end
end

function touchtris.setWindowSize(w,h)
    winw,winh = w,h
end

return touchtris
