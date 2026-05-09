#version 330 compatibility

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
in vec4 mc_Entity;

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

    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    float matID = mc_Entity.x;

    if (matID == 101.0) {
        vec3 worldPos = (gl_ModelViewMatrix * gl_Vertex).xyz + cameraPosition;
        float waveSpeed = 0.5;
        float waveStrength = 0.03;
        float wave = sin(frameTimeCounter * waveSpeed + worldPos.x * 0.8 + worldPos.z * 0.8) * waveStrength;
        position.x += wave;
        position.z += wave * 0.5;
    }

    gl_Position = gl_ProjectionMatrix * position;
    gl_Position.xyz = distort(gl_Position.xyz);
}