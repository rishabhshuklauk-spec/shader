#version 330 compatibility

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;
in vec3 worldPos;

layout(location = 0) out vec4 colortex0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main() {
    float t = frameTimeCounter;

    vec2 waveCoord1 = worldPos.xz * 0.8 + vec2(t * 0.3, t * 0.2);
    vec2 waveCoord2 = worldPos.xz * 1.6 + vec2(-t * 0.2, t * 0.35);
    vec2 waveCoord3 = worldPos.xz * 0.4 + vec2(t * 0.15, -t * 0.1);

    float wave1 = noise(waveCoord1) * 0.5;
    float wave2 = noise(waveCoord2) * 0.25;
    float wave3 = noise(waveCoord3) * 0.25;
    float waveMix = wave1 + wave2 + wave3;

    float dx = noise(waveCoord1 + vec2(0.1, 0.0)) - noise(waveCoord1 - vec2(0.1, 0.0));
    float dz = noise(waveCoord1 + vec2(0.0, 0.1)) - noise(waveCoord1 - vec2(0.0, 0.1));
    vec3 waveNormal = normalize(vec3(-dx * 0.3, 1.0, -dz * 0.3));
    waveNormal = normalize(gl_NormalMatrix * waveNormal);

    vec3 waterColorShallow = vec3(0.05, 0.20, 0.35);
    vec3 waterColorDeep    = vec3(0.02, 0.08, 0.18);
    vec3 waterColor = mix(waterColorDeep, waterColorShallow, 0.6 + waveMix * 0.4);

    vec3 lightDir  = normalize(shadowLightPosition);
    float NdotL    = max(dot(waveNormal, lightDir), 0.0);
    float skyLight = clamp(lmcoord.y, 0.0, 1.0);

    vec3 trueSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunHeight = trueSunDir.y;
    float dayBlend = clamp(sunHeight * 4.0, 0.0, 1.0);
    float nightBlend = clamp(-sunHeight * 4.0, 0.0, 1.0);

    vec3 ambientSkyDay = vec3(0.06, 0.10, 0.16);
    vec3 ambientSkyNight = vec3(0.01, 0.02, 0.04);
    vec3 ambientSky = mix(ambientSkyDay, ambientSkyNight, nightBlend) * skyLight;

    vec3 sunColorDay = vec3(1.4, 1.3, 1.1);
    vec3 sunColorNight = vec3(0.15, 0.25, 0.45);
    vec3 sunLight = mix(sunColorDay, sunColorNight, nightBlend) * NdotL * skyLight * 0.6;

    vec3 viewDir = normalize(-viewPos);
    vec3 halfDir = normalize(viewDir + lightDir);
    float spec   = pow(max(dot(waveNormal, halfDir), 0.0), 96.0);
    vec3 specColorDay = vec3(1.4, 1.3, 1.0);
    vec3 specColorNight = vec3(0.2, 0.3, 0.5);
    vec3 specular = mix(specColorDay, specColorNight, nightBlend) * spec * skyLight * 0.15;

    float fresnel = pow(1.0 - max(dot(viewDir, waveNormal), 0.0), 5.0);
    fresnel = 0.02 + 0.3 * fresnel;

    vec3 skyReflect = mix(vec3(0.35, 0.55, 0.85), vec3(0.02, 0.03, 0.06), nightBlend);

    vec3 litWater = waterColor * (ambientSky + sunLight + vec3(0.003));
    vec3 finalColor = mix(litWater, skyReflect, fresnel * 0.3) + specular;

    colortex0 = vec4(max(finalColor, vec3(0.0)), 0.55);
}