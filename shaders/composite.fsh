#version 330 compatibility

/*
const int colortex0Format = RGB16;
const int colortex1Format = RGB16;
const int colortex2Format = RGB16;
const int shadowMapResolution = 2048;
const float shadowDistance = 128.0;
*/

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform int worldTime;

const vec3 blocklightColor = vec3(1.0, 0.45, 0.05);
const vec3 skylightColor = vec3(0.04, 0.08, 0.15);
const vec3 sunlightColor = vec3(1.0);
const vec3 ambientColor = vec3(0.08);
const vec3 fogDayColor = vec3(0.5, 0.7, 1.0);
const vec3 fogSunsetColor = vec3(0.9, 0.4, 0.2);
const vec3 fogNightColor = vec3(0.001, 0.002, 0.005);

in vec2 texcoord;
layout(location = 0) out vec4 color;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
	vec4 homPos = projectionMatrix * vec4(position, 1.0);
	return homPos.xyz / homPos.w;
}

vec3 distort(vec3 pos) {
	float d = length(pos.xy);
	d = d * 0.85 + 0.15;
	pos.xy /= d;
	pos.z *= 0.2;
	return pos;
}

float getPCFShadow(vec3 shadowScreenPos, float bias) {
	float shadow = 0.0;
	float texelSize = 1.0 / 2048.0;
	for(int x = -1; x <= 1; x++) {
		for(int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * texelSize;
			shadow += step(shadowScreenPos.z - bias, texture(shadowtex0, shadowScreenPos.xy + offset).r);
		}
	}
	return shadow / 9.0;
}

void main() {
	vec2 lightmap = texture(colortex1, texcoord).xy;
	lightmap = clamp((lightmap - (1.0 / 32.0)) * (32.0 / 30.0), 0.0, 1.0);
	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 normal = normalize((encodedNormal - 0.5) * 2.0);
	vec3 lightVector = normalize(shadowLightPosition);
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;
	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2));
	float time = float(worldTime);
	float dayBlend = 1.0 - clamp((time - 12000.0) / 1000.0, 0.0, 1.0) + clamp((time - 23000.0) / 1000.0, 0.0, 1.0);
	float sunsetBlend = clamp(1.0 - abs(time - 12500.0) / 1000.0, 0.0, 1.0) + clamp(1.0 - abs(time - 23500.0) / 1000.0, 0.0, 1.0);
	vec3 currentFog = mix(fogNightColor, fogDayColor, dayBlend);
	currentFog = mix(currentFog, fogSunsetColor, sunsetBlend);
	vec3 linearFogColor = pow(currentFog, vec3(2.2));
	float depth = texture(depthtex0, texcoord).r;
	if (depth == 1.0) {
		color.rgb = max(color.rgb, linearFogColor);
		return;
	}
	vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	shadowClipPos.xyz = distort(shadowClipPos.xyz);
	vec3 shadowNdcPos = shadowClipPos.xyz / shadowClipPos.w;
	vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;
	float NdotL = clamp(dot(normal, lightVector), 0.0, 1.0);
	float bias = mix(0.002, 0.0005, NdotL);
	float shadow = 1.0;
	if (shadowScreenPos.x > 0.0 && shadowScreenPos.x < 1.0 && shadowScreenPos.y > 0.0 && shadowScreenPos.y < 1.0) {
		shadow = getPCFShadow(shadowScreenPos, bias);
	}
	shadow = mix(0.02, 1.0, shadow);
	vec3 currentSunlight = mix(vec3(0.002, 0.005, 0.015), sunlightColor, dayBlend);
	vec3 currentSkylight = mix(vec3(0.001, 0.002, 0.005), skylightColor, dayBlend);
	vec3 currentAmbient = mix(vec3(0.001), ambientColor, dayBlend);
	vec3 blocklight = lightmap.x * blocklightColor;
	vec3 skylight = lightmap.y * currentSkylight;
	vec3 ambient = currentAmbient;
	float wrappedLight = dot(worldLightVector, normal) * 0.5 + 0.5;
	vec3 sunlight = currentSunlight * clamp(wrappedLight, 0.0, 1.0) * shadow * lightmap.y;
	color.rgb *= (blocklight + skylight + ambient + sunlight);
	float distanceToPlayer = length(viewPos);
	float fogDensity = clamp((distanceToPlayer - 48.0) / 128.0, 0.0, 1.0);
	color.rgb = mix(color.rgb, linearFogColor, fogDensity);
}