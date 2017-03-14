uniform float time;
void main()
{
    fragColor = vec4(.5+.3*sin(10.*time),.4,1.,1.);
}

