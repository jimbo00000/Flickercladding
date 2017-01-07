--[[
    edge_effect.lua

    Basic 3x3 convolution filter. Good for blurring, edge detection, etc.
    TODO: pass kernel in via a parameter.
]]
edge_effect = {}

local openGL = require("opengl")
local ffi = require("ffi")
local sf = require("util.shaderfunctions")
local fbf = require("util.fbofunctions")

local glIntv   = ffi.typeof('GLint[?]')
local glFloatv = ffi.typeof('GLfloat[?]')

local vao = 0
local prog = 0
local vbos = {}
local fbo

local basic_vert = [[
#version 300 es

in vec4 vPosition;
out vec3 vfTexCoord;

void main()
{
    vfTexCoord = vec3(.5*(vPosition.xy+1.),0.);
    gl_Position = vec4(vPosition.xy, 0., 1.);
}
]]

local basic_frag = [[
#version 300 es

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

in vec3 vfTexCoord;
out vec4 fragColor;
uniform sampler2D tex;

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
        vec4 tc = texture(tex, vfTexCoord.xy + offset[i]);
        sum += tc * kernel[i];
    }
    if (sum.x + sum.y + sum.z > .1)
        sum = vec4(vec3(1.)-sum.xyz,1.);
    fragColor = sum;
}
]]
function make_quad_vbos(prog)
    local verts = glFloatv(4*2, {
        -1,-1,
        1,-1,
        1,1,
        -1,1,
        })

    local vpos_loc = gl.glGetAttribLocation(prog, "vPosition")

    local vvbo = glIntv(0)
    gl.glGenBuffers(1, vvbo)
    gl.glBindBuffer(GL.GL_ARRAY_BUFFER, vvbo[0])
    gl.glBufferData(GL.GL_ARRAY_BUFFER, ffi.sizeof(verts), verts, GL.GL_STATIC_DRAW)
    gl.glVertexAttribPointer(vpos_loc, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, nil)
    table.insert(vbos, vvbo)

    gl.glEnableVertexAttribArray(vpos_loc)

    return vbos
end

function edge_effect.initGL(w, h)
    vbos = {}
    texs = {}
    local vaoId = ffi.new("int[1]")
    gl.glGenVertexArrays(1, vaoId)
    vao = vaoId[0]
    gl.glBindVertexArray(vao)

    prog = sf.make_shader_from_source({
        vsrc = basic_vert,
        fsrc = basic_frag,
        })
    vbos = make_quad_vbos(prog)

    fbo = fbf.allocate_fbo(w, h, true)

    gl.glBindVertexArray(0)
end

function edge_effect.exitGL()
    for k,v in pairs(vbos) do
        gl.glDeleteBuffers(1,v)
    end
    vbos = {}
    gl.glDeleteProgram(prog)

    local vaoId = ffi.new("GLuint[1]", vao)
    gl.glDeleteVertexArrays(1, vaoId)

    fbf.deallocate_fbo(fbo)
end

function edge_effect.present_texture(texId, resx, resy)
    gl.glUseProgram(prog)

    gl.glActiveTexture(GL.GL_TEXTURE0)
    gl.glBindTexture(GL.GL_TEXTURE_2D, texId)
    local tx_loc = gl.glGetUniformLocation(prog, "tex")
    gl.glUniform1i(tx_loc, 0)

    local rx_loc = gl.glGetUniformLocation(prog, "ResolutionX")
    gl.glUniform1i(rx_loc, resx)
    local ry_loc = gl.glGetUniformLocation(prog, "ResolutionY")
    gl.glUniform1i(ry_loc, resy)

    gl.glPolygonMode(GL.GL_FRONT_AND_BACK, GL.GL_FILL)
    gl.glBindVertexArray(vao)
    gl.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
    gl.glBindVertexArray(0)

    gl.glUseProgram(0)
end

function edge_effect.bind_fbo()
    if fbo then fbf.bind_fbo(fbo) end
end

function edge_effect.unbind_fbo()
    fbf.unbind_fbo()
end

function edge_effect.resize_fbo(w,h)
    if fbo then fbf.deallocate_fbo(fbo) end
    fbo = fbf.allocate_fbo(w,h,true)
end

function edge_effect.present()
    edge_effect.present_texture(fbo.tex, fbo.w, fbo.h)
end

return edge_effect
