#version 330 compatibility

in vec4 mc_Entity;

out vec2 texcoord;
out vec4 glcolor;
out float materialID;

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
    materialID = mc_Entity.x;

    gl_Position = ftransform();
    gl_Position.xyz = distort(gl_Position.xyz);
}