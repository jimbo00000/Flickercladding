--[[ touch_shader2.lua

    Draws touch points *indirectly* with a fragment shader.

    There is an intermediate render-to-texture step, where touch points
    are drawn with blending onto an intermediate buffer. Color trails
    can accumulate over multiple frames, leaving trails.
]]
touch_shader2 = {}

--local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glUintv  = ffi.typeof('GLuint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local vbos = {}
local vao = 0
local prog = 0
local prog_present = 0

local winw, winh = 0,0 -- Window size in pixels
local pointers = {} -- List of pointer states

local fbo = nil

local basic_vert = [[
#version 310 es

in vec2 vPosition;
in vec2 vColor;

out vec3 vfColor;

void main()
{
    vfColor = vec3(vColor, 0.);
    gl_Position = vec4(vPosition, 0., 1.);
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

#define MAX_TOUCH_POINTS 16
uniform vec2 uTouchPts[MAX_TOUCH_POINTS];
uniform int numPts;

void main()
{
    vec3 col = .5*vfColor + vec3(.5);
    float c = 0.;
    for (int i=0; i<numPts; ++i)
    {
        vec2 tp = uTouchPts[i];
        tp.y = 1. - tp.y;
        float d = length(col.xy - tp);
        c = max(c, smoothstep(.1, 0., d));
    }
    col *= c;

    fragColor = vec4(col, length(col));
}
]]


local present_texture_frag = [[
#version 310 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

layout(location = 0) uniform sampler2D sTex;

in vec3 vfColor;
out vec4 fragColor;

void main()
{
    vec2 tc = .5*vfColor.xy + vec2(.5);
    vec4 col = texture(sTex, tc);
    fragColor = vec4(col.xyz, 1.);
}
]]


local function init_cube_attributes()
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

function touch_shader2.initGL()
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })

    prog_present = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = present_texture_frag,
        })

    init_cube_attributes()
    gl.glBindVertexArray(0)
end

function touch_shader2.exitGL()
    gl.glBindVertexArray(vao)
    for _,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}

    gl.glDeleteProgram(prog)
    gl.glDeleteProgram(prog_present)

    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)
    fbf.deallocate_fbo(fbo)
end



local function render_points()
    local utp_loc = gl.glGetUniformLocation(prog, "uTouchPts")
    local unp_loc = gl.glGetUniformLocation(prog, "numPts")
    gl.glUseProgram(prog)
    
    -- The array may be sparse, so we can't just use #v
    local i = 0
    for k,v in pairs(pointers) do
        i = i+1
    end
    -- Assemble array of touch points to pass in as uniform
    pts = {}
    for k,v in pairs(pointers) do
        if v and v.x and v.y then
            local x,y = v.x, v.y
            table.insert(pts, x)
            table.insert(pts, y)
        end
    end
    
    local num = i
    gl.glUniform2fv(utp_loc, num, glFloatv(2*num, pts))
    gl.glUniform1i(unp_loc, num)

    gl.glEnable(GL.GL_BLEND)
    gl.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA)
    gl.glBindVertexArray(vao)
    gl.glDrawElements(GL.GL_TRIANGLES, 6, GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
    gl.glDisable(GL.GL_BLEND)
end

local function render_to_buffer()
    -- Set the bound FBO back when done
    local boundfbo = ffi.new("int[1]")
    gl.glGetIntegerv(GL.GL_FRAMEBUFFER_BINDING, boundfbo)
    fbf.bind_fbo(fbo)

    -- Set the viewport back when we're done
    local vpdims = ffi.new("int[4]")
    gl.glGetIntegerv(GL.GL_VIEWPORT, vpdims)
    gl.glViewport(0,0, winw, winh)

    render_points()

    -- Set the viewport back when we're done
    gl.glViewport(vpdims[0], vpdims[1], vpdims[2], vpdims[3])

    -- Set the FBO back when done
    gl.glBindFramebuffer(GL.GL_FRAMEBUFFER, boundfbo[0])
end



local bright = 0
function touch_shader2.render_for_one_eye(view, proj)

    -- Do this here or in touch?
    -- Both should be on the right thread.
    render_to_buffer()

    gl.glUseProgram(prog_present)

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, fbo.tex)
    gl.glUniform1i(0, 0)
    
    gl.glBindVertexArray(vao)
    gl.glDrawElements(GL.GL_TRIANGLES, 6, GL.GL_UNSIGNED_INT, nil)
    gl.glBindVertexArray(0)
    gl.glUseProgram(0)
end

function touch_shader2.timestep(absTime, dt)
end

function touch_shader2.onSingleTouch(pointerid, action, x, y)
    pointers[pointerid] = {x=x/winw, y=y/winh}

    if action == 1 or action == 6 then
        pointers[pointerid] = nil
    end
end

function touch_shader2.setBrightness(b)
    bright = b
end

-- Called on init before initGL and every time the screen rotates
function touch_shader2.setWindowSize(w,h)
    fbf.deallocate_fbo(fbo)

    winw, winh = w,h
    fbo = fbf.allocate_fbo(winw, winh)
end

return touch_shader2
