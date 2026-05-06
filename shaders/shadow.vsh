#version 330 compatibility

out vec2 texcoord;
out vec4 glcolor;

vec3 distort(vec3 pos) {
    float d = length(pos.xy);
    d = d * 0.85 + 0.15;
    pos.xy /= d;
    pos.z *= 0.2;
    return pos;
}

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    gl_Position = ftransform();
    gl_Position.xyz = distort(gl_Position.xyz);
}