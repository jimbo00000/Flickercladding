uniform float time;
void main()
{
    vec2 col = uv.yx;
    col.x = sin(30.*(uv.x+uv.y-time*.15));
    fragColor = vec4(col, .5*(sin(7.*time) + 1.), 1.);
}

