#version 330 compatibility

attribute vec4 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out vec4 shadowClipPos;
out float blockId;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor  = gl_Color;
    normal   = normalize(gl_NormalMatrix * gl_Normal);
    blockId  = mc_Entity.x;

    vec4 position = gl_Vertex;
    vec4 viewPosPlayer = gl_ModelViewMatrix * position;
    vec4 playerPos = gbufferModelViewInverse * viewPosPlayer;
    vec3 worldPos = playerPos.xyz + cameraPosition;
    float phase   = floor(worldPos.x + 0.001) * 1.7 + floor(worldPos.z + 0.001) * 4.3;
    float t       = frameTimeCounter;

    if (abs(mc_Entity.x - 10001.0) < 0.5) {
        position.x += sin(t * 0.6 + phase) * 0.025 + sin(t * 1.2 + phase * 0.8) * 0.01;
        position.z += cos(t * 0.5 + phase + 1.2) * 0.025 + cos(t * 1.0 + phase) * 0.01;
    }

    if (abs(mc_Entity.x - 10002.0) < 0.5) {
        float upper = step(0.5, fract(worldPos.y + 0.001));
        position.x += (sin(t * 0.8 + phase) * 0.035 + sin(t * 1.4 + phase * 0.6) * 0.015) * upper;
        position.z += (cos(t * 0.7 + phase + 0.8) * 0.035 + cos(t * 1.2 + phase) * 0.015) * upper;
    }

    vec4 viewPos   = gl_ModelViewMatrix * position;
    gl_Position    = gl_ProjectionMatrix * viewPos;
    playerPos = gbufferModelViewInverse * viewPos;
    shadowClipPos  = shadowProjection * (shadowModelView * playerPos);
}