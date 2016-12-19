--[[ julia_set.lua

    Draws a Julia set fractal on a fulllscreen quad.
    Parameters adjustable via mouse.
]]
julia_set = {}

julia_set.__index = julia_set

function julia_set.new(...)
    local self = setmetatable({}, julia_set)
    if self.init ~= nil and type(self.init) == "function" then
        self:init(...)
    end 
    return self
end

function julia_set:init()
    self.joff = {.05,.62}
    self.shader = nil
end

require("util.fullscreen_shader")

local fragsrc = [[
uniform vec2 an;

void main()
{
    vec2 uv11 = 2.*uv - vec2(1.);

    float r = 1.65;
    mat3 rotation = mat3(
        vec3( cos(r),  sin(r),  0.),
        vec3(-sin(r),  cos(r),  0.),
        vec3(     0.,      0.,  1.)
    );

    // https://www.shadertoy.com/view/4d23WG
    vec2 z = 1.15*(rotation*vec3(uv11,1.)).xy;
    //vec2 an = 0.51*cos( vec2(0.0,1.5708) ) - 0.25*cos( vec2(0.0,1.5708) );

    float f = 1e20;
    for( int i=0; i<128; i++ ) 
    {
        z = vec2( z.x*z.x-z.y*z.y, 2.0*z.x*z.y ) + an;
        f = min( f, dot(z,z) );
    }
    
    f = 1.0+log(f)/16.0;

    fragColor = vec4(f,f*f,f*f*f,1.0);

    vec2 v01 = .5*(vec2(1.)+uv11);
    if ((fract(4.*v01.x) >= .995)
     || (fract(3.*v01.y) >= .995))
        fragColor = vec4(0.,0.,1.,1.);
}
]]

function julia_set:initGL()
    self.shader = FullscreenShader.new(fragsrc)
    self.shader:initGL()
end

function julia_set:exitGL()
    self.shader:exitGL()
end

function julia_set:render_for_one_eye(view, proj)
    local function set_variables(prog)
        local uan_loc = gl.glGetUniformLocation(prog, "an")
        gl.glUniform2f(uan_loc, self.joff[1], self.joff[2])
    end

    self.shader:render(view, proj, set_variables)
end

function julia_set:onmouse(xf, yf)
    self.joff[1], self.joff[2] = xf, yf
    --print(xf,yf)
end

return julia_set
