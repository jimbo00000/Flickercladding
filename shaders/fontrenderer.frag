#version 310 es
// fontrenderer.frag
// Shader for FontRenderer class
// Shader runs with blending enabled:  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

#ifdef GL_ES
precision mediump float;
#endif

in vec2 v_texCoord;
out vec4 fragColor;

uniform vec3 u_fontColor;
uniform sampler2D s_texture;

void main()
{
    /// Texture is luminance only
    float lum = texture(s_texture, v_texCoord).r;
    
    /// Some options here to beef up the font weight a bit:
    lum = clamp(2.0 * lum, 0.0, 1.0);
    //lum = pow(lum, 0.25);
    //lum = sin(lum*1.57079632679);

    ///
    /// These functions appear to cause an error on the Tegra 3 device:
    /// Cyan text with black background showing through. No sqrt?
    ///
    //lum = sqrt(lum);
    //lum = sqrt(sin(lum*1.57079632679));


    fragColor = vec4(u_fontColor, lum);
}
