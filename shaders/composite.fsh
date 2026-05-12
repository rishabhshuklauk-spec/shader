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

uniform float isJungle;
uniform float isSavanna;
uniform float isDesert;

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

	bool isHand = distanceToPlayer < 0.45;

	if (isHand) {
		color = texture(colortex0, texcoord);
		color.rgb = pow(color.rgb, vec3(2.2));
		color.rgb = ACESFilm(color.rgb * 1.4);
		return;
	}

	vec2 lightmap = texture(colortex1, texcoord).xy;
	lightmap.x = pow(lightmap.x, 2.6);
	lightmap.y = pow(lightmap.y, 2.6);

	vec4 encodedNormalData = texture(colortex2, texcoord);
	vec3 normal = normalize((encodedNormalData.rgb - 0.5) * 2.0);

	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2));

	float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	color.rgb = mix(vec3(luma), color.rgb, 0.85);

	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

	if (isEyeInWater == 1) {
		vec3 waterFogColor = vec3(0.02, 0.25, 0.45);
		float wFogFactor = exp(-pow(distanceToPlayer * 0.03, 1.5));

		vec3 underwaterAmbient = vec3(0.1, 0.35, 0.6) * lightmap.y;
		vec3 underwaterBlock = vec3(1.0, 0.7, 0.3) * lightmap.x;
		color.rgb *= (underwaterAmbient + underwaterBlock + 0.05);

		color.rgb = mix(waterFogColor, color.rgb, clamp(wFogFactor, 0.0, 1.0));
		color.rgb = ACESFilm(color.rgb * 0.85);
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

	float totalBlend = dayBlend + nightBlend + twilightF;
	dayBlend /= totalBlend;
	nightBlend /= totalBlend;
	float twilightBlend = twilightF / totalBlend;

	float hotBiome = max(isSavanna, isDesert);

	vec3 viewLightVector = normalize(shadowLightPosition);
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * viewLightVector;

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
	shadow = mix(mix(0.2, 0.05, nightBlend), 1.0, shadow);

	vec3 lightColor = vec3(1.15, 1.05, 0.95) * dayBlend
	+ vec3(1.6, 0.65, 0.15) * twilightBlend
	+ vec3(0.02, 0.05, 0.1) * nightBlend;

	vec3 ambientColor = vec3(0.06, 0.08, 0.12) * dayBlend
	+ vec3(0.12, 0.08, 0.06) * twilightBlend
	+ vec3(0.02, 0.03, 0.05) * nightBlend;

	ambientColor = mix(ambientColor, vec3(0.10, 0.08, 0.05), hotBiome * dayBlend);

	vec3 blocklight = lightmap.x * vec3(1.2, 0.8, 0.4);

	vec3 skylightColor = vec3(0.25, 0.4, 0.6) * dayBlend + vec3(0.1, 0.05, 0.08) * twilightBlend + vec3(0.01, 0.015, 0.02) * nightBlend;
	vec3 skylight = lightmap.y * skylightColor;

	float wrappedLight = dot(viewLightVector, normal) * 0.5 + 0.5;
	vec3 directLight = lightColor * clamp(wrappedLight, 0.0, 1.0) * shadow * lightmap.y;
	vec3 baseLight = vec3(0.015);

	float handLight = max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;
	if (handLight > 0.0) {
		float handAtten = exp(-pow(distanceToPlayer * 0.18, 2.0));
		vec3 torchColor = vec3(1.4, 0.85, 0.35) * handLight;
		directLight += torchColor * handAtten;
	}

	color.rgb *= (blocklight + skylight + ambientColor + directLight + baseLight);

	vec3 viewDir = normalize(viewPos);
	vec3 worldViewDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
	float upDot = clamp(worldViewDir.y, 0.0, 1.0);

	vec3 zenithDay = mix(vec3(0.1, 0.25, 0.55), vec3(0.08, 0.20, 0.40), hotBiome);
	vec3 skyZenith = zenithDay * dayBlend
	+ vec3(0.15, 0.20, 0.35) * twilightBlend
	+ vec3(0.02, 0.04, 0.08) * nightBlend;

	vec3 horizonDay = mix(vec3(0.35, 0.55, 0.85), vec3(0.7, 0.6, 0.45), isSavanna);
	horizonDay = mix(horizonDay, vec3(0.8, 0.7, 0.5), isDesert);
	vec3 skyHorizon = horizonDay * dayBlend
	+ vec3(1.0, 0.45, 0.15) * twilightBlend
	+ vec3(0.04, 0.06, 0.10) * nightBlend;

	vec3 customSky = mix(skyHorizon, skyZenith, pow(upDot, 0.6));

	vec3 rightV = normalize(cross(worldLightVector, vec3(0.0, 1.0, 0.0)));
	if (abs(worldLightVector.y) > 0.99) rightV = vec3(1.0, 0.0, 0.0);
	vec3 upV = cross(rightV, worldLightVector);

	float dx = dot(worldViewDir, rightV);
	float dy = dot(worldViewDir, upV);
	float dz = dot(worldViewDir, worldLightVector);

	float sSize = 0.035;
	float sEdge = 0.0015;
	float squareBody = (1.0 - smoothstep(sSize - sEdge, sSize, abs(dx))) * (1.0 - smoothstep(sSize - sEdge, sSize, abs(dy))) * step(0.0, dz);

	vec3 celestialColor = mix(vec3(1.2, 1.1, 1.0), vec3(0.4, 0.6, 1.0), nightBlend);
	float sunGlow = pow(max(dz, 0.0), mix(60.0, 40.0, hotBiome * dayBlend)) * mix(0.8, 0.25, nightBlend);

	customSky += (squareBody + sunGlow) * celestialColor;

	if (rawDepth == 1.0) {
		color.rgb = ACESFilm(customSky * 0.85);
		return;
	}

	float fogBase = 0.0025;
	fogBase = mix(fogBase, 0.012, isJungle);
	fogBase = mix(fogBase, 0.005, isSavanna);
	fogBase = mix(fogBase, 0.0035, isDesert);
	fogBase = mix(fogBase, 0.001, nightBlend);

	float atmoFogFactor = exp(-pow(distanceToPlayer * fogBase, 2.0));
	color.rgb = mix(customSky, color.rgb, clamp(atmoFogFactor, 0.0, 1.0));

	color.rgb = ACESFilm(color.rgb * 0.85);
}