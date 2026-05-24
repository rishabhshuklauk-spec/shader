#version 330 compatibility

#include "/lib/shadowDistort.glsl"

attribute vec4 mc_Entity;

out vec2 texcoord;
out vec4 glcolor;
out float blockId;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor  = gl_Color;
    blockId  = mc_Entity.x;

    vec4 pos = gl_ModelViewProjectionMatrix * gl_Vertex;
    pos.xyz  = distortShadowClipPos(pos.xyz);

    gl_Position = pos;
}