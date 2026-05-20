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
uniform float frameTimeCounter;
uniform float rainStrength;

in vec2 texcoord;
layout(location = 0) out vec4 color;

vec3 distort(vec3 pos) {
	float d = length(pos.xy);
	d = d * 0.85 + 0.15;
	pos.xy /= d;
	pos.z *= 0.2;
	return pos;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float f = 0.0;
	f += 0.5000 * noise(p); p = p * 2.02;
	f += 0.2500 * noise(p); p = p * 2.03;
	f += 0.1250 * noise(p); p = p * 2.01;
	f += 0.0625 * noise(p);
	return f;
}

void main() {
	float rawDepth = texture(depthtex0, texcoord).r;
	vec4 albedo = texture(colortex0, texcoord);
	vec3 rgb = pow(albedo.rgb, vec3(2.2));

	float timeMod = mod(float(worldTime), 24000.0);
	float nightBlend = smoothstep(12000.0, 13800.0, timeMod) * (1.0 - smoothstep(22200.0, 24000.0, timeMod));
	float sunsetBlend = smoothstep(11500.0, 12500.0, timeMod) * (1.0 - smoothstep(13000.0, 14000.0, timeMod)) + smoothstep(22000.0, 23000.0, timeMod) * (1.0 - smoothstep(23500.0, 24000.0, timeMod));

	vec3 ndcPos = vec3(texcoord.xy, rawDepth) * 2.0 - 1.0;
	vec4 viewPos = gbufferProjectionInverse * vec4(ndcPos, 1.0);
	viewPos /= viewPos.w;

	if (rawDepth == 1.0) {
		vec3 viewDir = normalize(viewPos.xyz);
		vec3 worldDir = mat3(gbufferModelViewInverse) * viewDir;

		vec3 skyDay = mix(vec3(0.4, 0.65, 0.9), vec3(0.15, 0.4, 0.8), clamp(worldDir.y, 0.0, 1.0));
		vec3 skyNight = mix(vec3(0.01, 0.015, 0.03), vec3(0.02, 0.025, 0.05), clamp(worldDir.y, 0.0, 1.0));
		vec3 skySunset = mix(vec3(0.85, 0.35, 0.15), vec3(0.2, 0.15, 0.35), clamp(worldDir.y, 0.0, 1.0));

		vec3 finalSky = mix(skyDay, skyNight, nightBlend);
		finalSky = mix(finalSky, skySunset, clamp(sunsetBlend, 0.0, 1.0));
		finalSky = mix(finalSky, vec3(0.2, 0.22, 0.25), rainStrength);

		if (worldDir.y > 0.05) {
			vec2 cloudCoord = (worldDir.xz / worldDir.y) * 1.2;
			cloudCoord.x += frameTimeCounter * 0.012;
			cloudCoord.y += frameTimeCounter * 0.005;

			float n = fbm(cloudCoord);
			float cloudAlpha = smoothstep(0.4, 0.7, n);

			vec3 cloudColorDay = vec3(1.0, 0.98, 0.95);
			vec3 cloudColorNight = vec3(0.05, 0.08, 0.12);
			vec3 cloudColorSunset = vec3(1.2, 0.6, 0.3);

			vec3 finalCloudColor = mix(cloudColorDay, cloudColorNight, nightBlend);
			finalCloudColor = mix(finalCloudColor, cloudColorSunset, clamp(sunsetBlend, 0.0, 1.0));
			finalCloudColor = mix(finalCloudColor, vec3(0.2, 0.22, 0.25), rainStrength);

			float horizonFade = smoothstep(0.05, 0.25, worldDir.y);
			finalSky = mix(finalSky, finalCloudColor, cloudAlpha * horizonFade * 0.8);
		}

		rgb = finalSky / (finalSky + vec3(0.18));
		rgb = pow(rgb, vec3(1.0 / 2.2));
		color = vec4(rgb, albedo.a);
		return;
	}

	vec4 normalData = texture(colortex2, texcoord);
	vec3 normal = length(normalData.rgb) > 0.1 ? normalize(normalData.rgb * 2.0 - 1.0) : vec3(0.0, 1.0, 0.0);

	vec3 lightDir = normalize(shadowLightPosition);
	float NdotL = clamp(dot(normal, lightDir), 0.0, 1.0);

	vec4 playerPos = gbufferModelViewInverse * viewPos;
	vec4 shadowViewPos = shadowModelView * playerPos;
	vec4 shadowClipPos = shadowProjection * shadowViewPos;
	shadowClipPos.xyz = distort(shadowClipPos.xyz);
	vec3 shadowScreenPos = (shadowClipPos.xyz / shadowClipPos.w) * 0.5 + 0.5;

	float bias = 0.001 + (1.0 - NdotL) * 0.002;
	float shadow = 1.0;
	if (shadowScreenPos.x > 0.0 && shadowScreenPos.x < 1.0 && shadowScreenPos.y > 0.0 && shadowScreenPos.y < 1.0) {
		shadow = step(shadowScreenPos.z - bias, texture(shadowtex0, shadowScreenPos.xy).r);
	}

	shadow = mix(shadow, 1.0, nightBlend * 0.8);
	shadow = mix(shadow, 1.0, rainStrength);

	vec4 lmap = texture(colortex1, texcoord);
	float blockLight = pow(lmap.x, 2.6);
	float skyLight = pow(lmap.y, 2.6);

	vec3 sunColor = mix(vec3(1.4, 1.25, 1.0), vec3(0.03, 0.05, 0.1), nightBlend);
	sunColor = mix(sunColor, vec3(1.8, 0.6, 0.15), clamp(sunsetBlend, 0.0, 1.0));

	vec3 ambientColor = mix(vec3(0.4, 0.5, 0.65), vec3(0.005, 0.01, 0.02), nightBlend);
	ambientColor = mix(ambientColor, vec3(0.5, 0.3, 0.3), clamp(sunsetBlend, 0.0, 1.0));

	vec3 directLighting = sunColor * NdotL * shadow * skyLight * 1.5;
	vec3 ambientLighting = ambientColor * skyLight;
	vec3 torchLighting = vec3(1.6, 0.8, 0.25) * blockLight;

	directLighting *= mix(1.0, 0.01, nightBlend);
	ambientLighting *= mix(1.0, 0.01, nightBlend);

	rgb *= (directLighting + ambientLighting + torchLighting);

	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float maxC = max(rgb.r, max(rgb.g, rgb.b));
	float minC = min(rgb.r, min(rgb.g, rgb.b));
	rgb = mix(vec3(luma), rgb, 1.15 + (1.0 - (maxC - minC)) * 0.15);

	float dist = length(viewPos.xyz);
	vec3 fogColor = mix(vec3(0.55, 0.7, 0.9), vec3(0.02, 0.03, 0.06), nightBlend);
	fogColor = mix(fogColor, vec3(0.8, 0.45, 0.2), clamp(sunsetBlend, 0.0, 1.0));
	fogColor = mix(fogColor, vec3(0.3, 0.35, 0.4), rainStrength);

	float fogFactor = exp(-pow(dist * mix(0.0012, 0.007, rainStrength), 2.0));
	rgb = mix(fogColor, rgb, clamp(fogFactor, 0.0, 1.0));

	rgb = rgb / (rgb + vec3(0.18));
	rgb = pow(rgb, vec3(1.0 / 2.2));

	color = vec4(rgb, albedo.a);
}