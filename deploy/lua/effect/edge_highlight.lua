--[[ edge_highlight.lua

]]

effect_chain = {}

local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local vao = 0
local vbos = {}
local time = 0



local src_vert = [[
#version 300 es

in vec4 vPosition;
in vec4 vColor;
out vec2 uv;

void main()
{
    uv = .5 * (vPosition.xy + vec2(1.)); // map [-1,1] to [0,1]
    gl_Position = vec4(vPosition.xy, 0., 1.);
}
]]


local mix_frag = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec2 uv;
out vec4 fragColor;
uniform sampler2D tex1;
uniform sampler2D tex2;
float u_coeff = .5;

void main()
{
    vec4 col1 = texture(tex1, uv);
    vec4 col2 = texture(tex2, uv);
    fragColor = col2 + .5 * col1;//col2, u_coeff);
}
]]





local filter_passthrough = [[
void main()
{
    fragColor = texture(tex, uv);
}
]]

local filter_bw = [[
void main()
{
    fragColor = vec4(.3*length(texture(tex, uv))); // Black and white
}
]]

-- Standard image convolution by kernel
local filter_convolve = [[
uniform int ResolutionX;
uniform int ResolutionY;

#define KERNEL_SIZE 9
float kernel[KERNEL_SIZE] = float[](
#if 0
    1./16., 2./16., 1./16.,
    2./16., 4./16., 2./16.,
    1./16., 2./16., 1./16.

    0., 1., 0.,
    1., -4., 1.,
    0., 1., 0.
#else
    1., 2., 1.,
    0., 0., 0.,
    -1., -2., -1.
#endif
);

void main()
{
    float step_x = 1./float(ResolutionX);
    float step_y = 1./float(ResolutionY);

    vec2 offset[KERNEL_SIZE] = vec2[](
        vec2(-step_x, -step_y), vec2(0.0, -step_y), vec2(step_x, -step_y),
        vec2(-step_x,     0.0), vec2(0.0,     0.0), vec2(step_x,     0.0),
        vec2(-step_x,  step_y), vec2(0.0,  step_y), vec2(step_x,  step_y)
    );

    vec4 sum = vec4(0.);
    int i;
    for( i=0; i<KERNEL_SIZE; i++ )
    {
        vec4 tc = texture(tex, uv + offset[i]);
        sum += tc * kernel[i];
    }
    if (sum.x + sum.y + sum.z > .1)
        sum = vec4(vec3(1.)-sum.xyz,1.);
    fragColor = sum;
}
]]

local filter_hueshift = [[
uniform float time;

// http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl
vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = c.g < c.b ? vec4(c.bg, K.wz) : vec4(c.gb, K.xy);
    vec4 q = c.r < p.x ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main()
{
    vec3 col = texture(tex, uv).xyz;
    vec3 hsv = rgb2hsv(col);
    hsv.x += .5 * time;
    fragColor = vec4(hsv2rgb(hsv), 1.);
}
]]

require("util.filter")
local filters = {}
table.insert(filters, Filter.new({name="Passthrough",source=filter_passthrough}))
table.insert(filters, Filter.new({name="Downsample",source=filter_passthrough,sample_factor=1/2}))
table.insert(filters, Filter.new({name="Edge Detect",source=filter_convolve}))
--table.insert(filters, Filter.new({name="Edge Detect",source=filter_convolve}))
table.insert(filters, Filter.new({name="Hue Shift",source=filter_hueshift}))
-- This last one is only here to get the previous stage's outoput nto a buffer for mixing.
table.insert(filters, Filter.new({name="Passthrough",source=filter_passthrough}))

-- For accessing filter list outside of module
function effect_chain.get_filters()
    return filters
end

local function make_quad_vbos()
    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    table.insert(vbos, vvbo)

    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    local verts = glFloatv(4*2, {
        -1,-1,
        1,-1,
        1,1,
        -1,1,
        })
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
end

function effect_chain.initGL(w,h)
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    make_quad_vbos()

    for _,f in pairs(filters) do
        f:initGL()
        f:resize(w,h)

        -- Re-use the VBO for each program
        local vpos_loc = gl.glGetAttribLocation(f.prog, "vPosition")
        gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
        gl.glEnableVertexAttribArray(vpos_loc)
    end

    prog_mix = sf.make_shader_from_source({
        vsrc = src_vert,
        fsrc = mix_frag,
        })

    local vpos_loc = gl.glGetAttribLocation(prog_mix, "vPosition")
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    gl.glEnableVertexAttribArray(vpos_loc)

    gl.glBindVertexArray(0)
end

function effect_chain.exitGL()
    for k,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}

    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)

    gl.glDeleteProgram(prog_mix)
    for _,f in pairs(filters) do
        f:exitGL()
    end
end

function effect_chain.insert_effect(shader, index)
end

function effect_chain.remove_effect(index)
end

function effect_chain.resize_fbo(w,h)
    for _,f in pairs(filters) do
        f:resize(w,h)
    end
end

function effect_chain.bind_fbo()
    local filter = filters[1]
    if not filter then return end
    if filter.fbo then
        fbf.bind_fbo(filter.fbo)
        gl.glViewport(0,0, filter.fbo.w, filter.fbo.h)
    end
end

local function draw(prog, w, h, srctex)
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
    gl.glUniform1f(t_loc, time)

    gl.glBindVertexArray(vao)
    gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

local function flush()
    gl.glDisable(GL.GL_DEPTH_TEST)
    for i=1,#filters-1 do
        local source = filters[i]
        local dest = filters[i+1]
        if not source or not dest then return end

        local f = dest.fbo
        if f then
            fbf.bind_fbo(f)
            gl.glViewport(0,0, f.w, f.h)
        end

        draw(source.prog, f.w, f.h, source.fbo.tex)
    end
end

function effect_chain.unbind_fbo()
    -- We could flush here, or at the start of present.
    -- Let's do it here.
    flush()
    fbf.unbind_fbo()
end

function effect_chain.present()
    -- if list empty, do nothing
    local filter = filters[#filters]
    if not filter then return end

    -- Mix last stage's output with first stage's(unfiltered) and present
    gl.glUseProgram(prog_mix)

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, filter.fbo.tex)
    local tx_loc = gl.glGetUniformLocation(prog_mix, "tex")
    gl.glUniform1i(tx_loc, 0)

    gl.glActiveTexture(GL.GL_TEXTURE1)
    gl.glBindTexture(GL.GL_TEXTURE_2D, filters[1].fbo.tex)
    local tx2_loc = gl.glGetUniformLocation(prog_mix, "tex2")
    gl.glUniform1i(tx2_loc, 1)

    gl.glBindVertexArray(vao)
    gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function effect_chain.timestep(absTime, dt)
    time = absTime
end

return effect_chain
