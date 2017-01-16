--[[ single_pass_filters.lua

	Sources for filter shaders that can be drawn entirely in a single pass.
]]

single_pass_filters = {

    ["passthrough"] = [[
    void main()
    {
        fragColor = texture(tex, uv);
    }
    ]],

    ["invert"] = [[
    void main()
    {
        fragColor = vec4(1.) - texture(tex, uv); // Invert color
    }
    ]],

    ["black&white"] = [[
    void main()
    {
        fragColor = vec4(.3*length(texture(tex, uv))); // Black and white
    }
    ]],

    -- Standard image convolution by kernel
    ["convolve"] = [[
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
    ]],

    -- http://haxepunk.com/documentation/tutorials/post-process/
    ["scanline"] = [[
    uniform int ResolutionX;
    uniform int ResolutionY;
    //uniform
    float scale = 3.0;

    void main()
    {
        if (mod(floor(uv.y * float(ResolutionY) / scale), 2.0) == 0.0)
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        else
            fragColor = texture(tex, uv);
    }
    ]],

    ["wiggle"] = [[
    uniform float time;

    void main()
    {
        vec2 tc = uv + .1*vec2(sin(time), cos(.7*time));
        fragColor = texture(tex, tc);
    }
    ]],

    ["wobble"] = [[
    uniform float time;

    void main()
    {
        vec2 fromCenter = uv - vec2(.5);
        float len = length(fromCenter);
        float f = 1.05 + .05 * sin(5.*time);
        len = pow(len, f);

        vec2 adjFromCenter = len * normalize(fromCenter);
        vec2 uv01 = vec2(.5) + adjFromCenter;
        fragColor = texture(tex, uv01);
    }
    ]],

    ["hueshift"] = [[
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
    ]],

    -- Give a graphical indication  of what scanout looks like.
    ["beamrace"] = [[
    #line 150
    uniform int ResolutionX;
    uniform int ResolutionY;
    uniform float time;

    float fps = 1.;
    float persistence = .20; // duty cycle

    float sawTooth(float a, float b, float x)
    {
        return clamp(((fract(a*(x-time))-(1.-b))/b),0.,1.);

        float attack = step(.2,fract(x-a));//1.-step(a, x);
        float decay = b*((x-a))+1.;
        return clamp(attack*decay, 0., 1.);
    }

    float getBrightnessAtPixel(vec2 uv, float spf, float pers)
    {
        uv = uv.yx;
        float t = mod(time, spf) / spf; //[0,1]

        float secondsPerLine = spf / float(ResolutionY);
        float u = mod(time, secondsPerLine) / secondsPerLine;

        ///@todo X
        float colScaleX = 1.0;//clamp(  1.0 - .1*float(ResolutionX)*abs(uv.x-u)  ,0.,1.);
        float colScaleY = clamp(  1.0 - .1*float(ResolutionY)*abs(uv.y-t)  ,0.,1.);

        colScaleY = sawTooth(fps, pers, uv.y);

        return colScaleX * colScaleY;
    }

    void main()
    {
        fragColor = getBrightnessAtPixel(uv, 1./fps, persistence) *
            texture(tex, uv);
    }
    ]],


    -- From the early Oculus VR SDK
    ["lenswarp"] = [[
    vec2 LensCenter;
    vec2 ScreenCenter;
    vec2 Scale;
    vec2 ScaleIn;
    vec4 HmdWarpParam;

    vec2 HmdWarp(vec2 in01)
    {
        vec2  theta = (in01 - LensCenter) * ScaleIn; // Scales to [-1, 1]
        float rSq = theta.x * theta.x + theta.y * theta.y;
        vec2  theta1 = theta * (HmdWarpParam.x + HmdWarpParam.y * rSq +
                                HmdWarpParam.z * rSq * rSq + HmdWarpParam.w * rSq * rSq * rSq);
        return LensCenter + Scale * theta1;
    }
     
    void main()
    {
        float lensOff = 0.287994 - 0.25;

        // Left eye
        LensCenter = vec2(0.25 + lensOff, 0.5);
        ScreenCenter = vec2(.25, .5);
        if (uv.x > .5)
        {
            LensCenter = vec2(0.75 + lensOff, 0.5);
            ScreenCenter = vec2(.75, .5);
        }

        Scale = vec2(0.145806,  0.233290);
        ScaleIn = vec2(4.0, 2.5);
        HmdWarpParam = vec4(1.0, 0.5, 0.25, 0.0);

        vec2 tc = HmdWarp(uv);
        if (!all(equal(clamp(tc, ScreenCenter-vec2(0.25,0.5), ScreenCenter+vec2(0.25,0.5)), tc)))
            fragColor = vec4(0);
        else
            fragColor = texture(tex, tc);
    }
    ]],

    ["sidebyside_double"] = [[
    void main()
    {
        vec2 tc = uv;
        tc.x = fract(2.*tc.x);
        fragColor = texture(tex, tc);
    }
    ]],

    -- http://www.geeks3d.com/20091027/shader-library-posterization-post-processing-effect-glsl/
    ["posterize"] = [[
    void main()
    {
        float gamma = 0.6;
        float numColors = 8.0;

        vec3 c = texture(tex, uv).rgb;
        c = pow(c, vec3(gamma, gamma, gamma));
        c = c * numColors;
        c = floor(c);
        c = c / numColors;
        c = pow(c, vec3(1.0/gamma));
        fragColor = vec4(c, 1.0);
    }
    ]],

}

return single_pass_filters
