#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;

in vec2 texcoord;
layout(location = 0) out vec4 color;

vec3 acesTonemap(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec3 clr = texture(colortex0, texcoord).rgb;
    vec3 bloom = texture(colortex1, texcoord).rgb;

    clr += bloom * 0.8;

    float lum = dot(clr, vec3(0.2126, 0.7152, 0.0722));
    clr = mix(vec3(lum), clr, 1.1);

    clr = acesTonemap(clr);

    clr = pow(clr, vec3(1.0 / 2.2));

    color = vec4(clr, 1.0);
}