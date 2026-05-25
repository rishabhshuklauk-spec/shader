#version 330 compatibility

#include "/lib/shadowDistort.glsl"

uniform sampler2D texture;
uniform sampler2D shadowtex0;
uniform sampler2D lightmap;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec4 shadowClipPos;
in float blockId;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;

void main() {
    vec4 albedo = texture(texture, texcoord);

    if (abs(blockId - 10001.0) < 0.5) {
        albedo.a = 1.0;
    }

    albedo *= glcolor;
    if (albedo.a < 0.1) discard;

    vec3 linearAlbedo = pow(max(albedo.rgb, vec3(0.0)), vec3(2.2));

    vec3 lightDir = normalize(shadowLightPosition);
    float NdotL   = max(dot(normal, lightDir), 0.0);
    float skyLight   = clamp(lmcoord.y, 0.0, 1.0);
    float blockLight = clamp(lmcoord.x, 0.0, 1.0);

    float shadow = 1.0;
    if (skyLight > 0.01) {
        vec3 sp = shadowClipPos.xyz / shadowClipPos.w;
        sp      = distortShadowClipPos(sp);
        sp      = sp * 0.5 + 0.5;

        if (sp.x > 0.0 && sp.x < 1.0 && sp.y > 0.0 && sp.y < 1.0 && sp.z > 0.0 && sp.z < 1.0) {
            float bias = 0.0004 + (1.0 - NdotL) * 0.0012;
            float s    = 0.0;
            vec2  ts   = vec2(1.0 / 2048.0);

            s += step(sp.z - bias, texture(shadowtex0, sp.xy + vec2(-1.0, -1.0) * ts).r);
            s += step(sp.z - bias, texture(shadowtex0, sp.xy + vec2( 0.0, -1.0) * ts).r);
            s += step(sp.z - bias, texture(shadowtex0, sp.xy + vec2( 1.0, -1.0) * ts).r);
            s += step(sp.z - bias, texture(shadowtex0, sp.xy + vec2(-1.0,  0.0) * ts).r);
            s += step(sp.z - bias, texture(shadowtex0, sp.xy + vec2( 0.0,  0.0) * ts).r);
            s += step(sp.z - bias, texture(shadowtex0, sp.xy + vec2( 1.0,  0.0) * ts).r);
            s += step(sp.z - bias, texture(shadowtex0, sp.xy + vec2(-1.0,  1.0) * ts).r);
            s += step(sp.z - bias, texture(shadowtex0, sp.xy + vec2( 0.0,  1.0) * ts).r);
            s += step(sp.z - bias, texture(shadowtex0, sp.xy + vec2( 1.0,  1.0) * ts).r);

            shadow = s / 9.0;
        }
    }

    vec3 trueSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunHeight = trueSunDir.y;
    float nightBlend = clamp(-sunHeight * 4.0, 0.0, 1.0);

    vec3 ambientSkyDay = vec3(0.08, 0.12, 0.18);
    vec3 ambientSkyNight = vec3(0.015, 0.025, 0.04);
    vec3 ambientSky  = mix(ambientSkyDay, ambientSkyNight, nightBlend) * skyLight;

    vec3 torchColor  = vec3(1.5, 0.6, 0.1) * (blockLight * blockLight) * 2.0;
    vec3 ambient     = ambientSky + torchColor + mix(vec3(0.005), vec3(0.001), nightBlend);

    vec3 sunColorDay = vec3(1.6, 1.4, 1.2);
    vec3 sunColorNight = vec3(0.15, 0.25, 0.45);
    vec3 sunColor = mix(sunColorDay, sunColorNight, nightBlend) * NdotL * shadow * skyLight;

    vec3 finalColor = linearAlbedo * (ambient + sunColor);

    if (abs(blockId - 10001.0) < 0.5) {
        float backLight = max(dot(-normal, lightDir), 0.0) * skyLight * (1.0 - shadow) * 0.4;
        finalColor += linearAlbedo * vec3(0.6, 0.9, 0.2) * backLight;
    }

    colortex0 = vec4(max(finalColor, vec3(0.0)), albedo.a);
    colortex1 = vec4(0.0);
}