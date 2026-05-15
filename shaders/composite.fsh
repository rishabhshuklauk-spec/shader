#version 330 compatibility

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
uniform int isEyeInWater;

uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform vec3 skyColor;
uniform vec3 fogColor;

in vec2 texcoord;
layout(location = 0) out vec4 color;

vec3 ACESFilm(vec3 x) {
	float a = 2.51;
	float b = 0.03;
	float c = 2.43;
	float d = 0.59;
	float e = 0.14;
	return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

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
	for(int x = -2; x <= 2; x++) {
		for(int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * texelSize * 1.5;
			shadow += step(shadowScreenPos.z - bias, texture(shadowtex0, shadowScreenPos.xy + offset).r);
		}
	}
	return shadow / 25.0;
}

void main() {
	float rawDepth = texture(depthtex0, texcoord).r;

	vec3 ndcPos = vec3(texcoord.xy, rawDepth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);
	float distanceToPlayer = length(viewPos);

	vec2 lightmap = texture(colortex1, texcoord).xy;
	lightmap.x = pow(lightmap.x, 2.6);
	lightmap.y = pow(lightmap.y, 2.6);

	vec4 encodedNormalData = texture(colortex2, texcoord);
	bool noNormal = length(encodedNormalData.rgb) < 0.01;
	vec3 normal = noNormal ? vec3(0.0, 1.0, 0.0) : normalize((encodedNormalData.rgb - 0.5) * 2.0);

	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2));

	float handLight = max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;

	if (isEyeInWater == 1) {
		vec3 waterColor = vec3(0.05, 0.35, 0.65);
		float ambientSky = max(lightmap.y, 0.15);
		vec3 inWaterAmbient = waterColor * ambientSky;
		vec3 rawTorchColor = vec3(1.2, 0.7, 0.2);
		vec3 inWaterBlock = rawTorchColor * lightmap.x;

		color.rgb *= (inWaterAmbient + inWaterBlock + 0.15);

		if (handLight > 0.0) {
			float hAtten = clamp(1.0 - (distanceToPlayer / 15.0), 0.0, 1.0);
			hAtten = hAtten * hAtten;
			color.rgb += rawTorchColor * handLight * hAtten * 0.8;
		}

		float fogFactor = clamp(distanceToPlayer / 32.0, 0.0, 1.0);
		color.rgb = mix(color.rgb, waterColor * ambientSky * 1.5, fogFactor);

		color.rgb = ACESFilm(color.rgb * 1.2);
		color.a = 1.0;
		return;
	}

	float timeMod = mod(float(worldTime), 24000.0);
	float dayDist = min(abs(timeMod - 6000.0), 24000.0 - abs(timeMod - 6000.0));
	float dayF = clamp(1.0 - dayDist / 6000.0, 0.0, 1.0);
	float nightDist = min(abs(timeMod - 18000.0), 24000.0 - abs(timeMod - 18000.0));
	float nightF = clamp(1.0 - nightDist / 6000.0, 0.0, 1.0);

	float sunsetDist = min(abs(timeMod - 13000.0), 24000.0 - abs(timeMod - 13000.0));
	float sunsetF = clamp(1.0 - sunsetDist / 1500.0, 0.0, 1.0);
	float sunriseDist = min(abs(timeMod - 23000.0), 24000.0 - abs(timeMod - 23000.0));
	float sunriseF = clamp(1.0 - sunriseDist / 1500.0, 0.0, 1.0);

	float twilightF = clamp(sunsetF + sunriseF, 0.0, 1.0);
	float dayBlend = clamp(dayF - twilightF, 0.0, 1.0);
	float nightBlend = clamp(nightF - twilightF, 0.0, 1.0);
	float twilightBlend = twilightF / (dayBlend + nightBlend + twilightF + 0.00001);

	vec3 viewLightVector = normalize(shadowLightPosition);

	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	shadowClipPos.xyz = distort(shadowClipPos.xyz);
	vec3 shadowNdcPos = shadowClipPos.xyz / shadowClipPos.w;
	vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;

	float NdotL = clamp(dot(normal, viewLightVector), 0.0, 1.0);
	float bias = mix(0.002, 0.0005, NdotL);

	float shadow = 1.0;
	if (shadowScreenPos.x > 0.0 && shadowScreenPos.x < 1.0 && shadowScreenPos.y > 0.0 && shadowScreenPos.y < 1.0) {
		shadow = getPCFShadow(shadowScreenPos, bias);
	}
	shadow = mix(mix(0.60, 0.35, nightBlend), 1.0, shadow);

	vec3 lightColor = vec3(1.15, 1.05, 0.95) * dayBlend
	+ vec3(1.6, 0.65, 0.15) * twilightBlend
	+ vec3(0.08, 0.12, 0.20) * nightBlend;

	vec3 ambientColor = vec3(0.18, 0.22, 0.28) * dayBlend
	+ vec3(0.20, 0.15, 0.12) * twilightBlend
	+ vec3(0.08, 0.10, 0.14) * nightBlend;

	vec3 blocklight = lightmap.x * vec3(1.2, 0.8, 0.4);
	vec3 skylight = lightmap.y * mix(vec3(0.45, 0.60, 0.85), vec3(0.08, 0.12, 0.18), nightBlend);

	float wrappedLight = dot(viewLightVector, normal) * 0.5 + 0.5;
	vec3 directLight = lightColor * clamp(wrappedLight, 0.0, 1.0) * shadow * lightmap.y;
	vec3 baseLight = mix(vec3(0.04), vec3(0.06), nightBlend);

	if (handLight > 0.0) {
		float handAtten = clamp(1.0 - (distanceToPlayer / 15.0), 0.0, 1.0);
		handAtten = handAtten * handAtten;
		vec3 torchColor = vec3(1.3, 0.8, 0.35) * handLight;
		directLight += torchColor * handAtten;
	}

	color.rgb *= (blocklight + skylight + ambientColor + directLight + baseLight);

	if (rawDepth == 1.0) {
		color.rgb = ACESFilm(mix(fogColor, skyColor, clamp(viewPos.y * 0.05, 0.0, 1.0)) * 0.85);
		color.a = 1.0;
		return;
	}

	float fogBase = mix(0.0025, 0.001, nightBlend);
	float atmoFogFactor = exp(-pow(distanceToPlayer * fogBase, 2.0));
	color.rgb = mix(mix(fogColor, skyColor, 0.5), color.rgb, clamp(atmoFogFactor, 0.0, 1.0));

	color.rgb = ACESFilm(color.rgb * 0.85);
	color.a = 1.0;
}