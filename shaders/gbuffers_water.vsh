#version 330 compatibility

uniform float frameTimeCounter;
uniform vec3 cameraPosition;

attribute vec4 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 viewPos;
out vec3 worldPos;
out float blockId;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor  = gl_Color;
    normal   = normalize(gl_NormalMatrix * gl_Normal);
    blockId  = mc_Entity.x;

    vec4 position = gl_Vertex;
    worldPos = position.xyz + cameraPosition;

    if (gl_Normal.y > 0.8) {
        float wave = sin(worldPos.x * 1.8 + frameTimeCounter * 1.0) * 0.015 +
                     cos(worldPos.z * 1.4 + frameTimeCounter * 0.8) * 0.015 +
                     sin(worldPos.x * 0.6 + worldPos.z * 0.8 + frameTimeCounter * 0.5) * 0.01;
        position.y += wave;
    }

    vec4 viewPosition = gl_ModelViewMatrix * position;
    viewPos = viewPosition.xyz;
    gl_Position = gl_ProjectionMatrix * viewPosition;
}