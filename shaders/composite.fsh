#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float frameTimeCounter;
uniform float rainStrength;

in vec2 texcoord;
layout(location = 0) out vec4 color;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	v += 0.5000 * noise(p); p *= 2.02;
	v += 0.2500 * noise(p); p *= 2.03;
	v += 0.1250 * noise(p); p *= 2.01;
	v += 0.0625 * noise(p);
	return v;
}

vec3 ACESFilm(vec3 x) {
	x = max(x, vec3(0.0));
	vec3 a = vec3(2.51);
	vec3 b = vec3(0.03);
	vec3 c = vec3(2.43);
	vec3 d = vec3(0.59);
	vec3 e = vec3(0.14);
	vec3 num = x * (x * a + b);
	vec3 den = x * (x * c + d) + e;
	return clamp(num / max(den, vec3(0.00001)), vec3(0.0), vec3(1.0));
}

void main() {
	float rawDepth = texture(depthtex0, texcoord).r;
	vec4 albedo = texture(colortex0, texcoord);

	vec3 worldLightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
	vec3 trueSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	float sunHeight = trueSunDir.y;
	float dayBlend = clamp(sunHeight * 4.0, 0.0, 1.0);
	float nightBlend = clamp(-sunHeight * 4.0, 0.0, 1.0);
	float sunsetBlend = clamp(1.0 - abs(sunHeight) * 5.0, 0.0, 1.0);

	vec3 finalColor = max(albedo.rgb, vec3(0.0));

	if (rawDepth > 0.9999) {
		vec3 ndcPos = vec3(texcoord.xy, rawDepth) * 2.0 - vec3(1.0);
		vec4 vph = gbufferProjectionInverse * vec4(ndcPos, 1.0);
		vec3 viewDir = normalize(vph.xyz / vph.w);
		vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewDir);

		vec3 skyDay = mix(vec3(0.38, 0.62, 0.93), vec3(0.12, 0.38, 0.78), clamp(worldDir.y, 0.0, 1.0));
		vec3 skyNight = mix(vec3(0.01, 0.015, 0.03), vec3(0.02, 0.025, 0.05), clamp(worldDir.y, 0.0, 1.0));
		vec3 skySunset = mix(vec3(0.82, 0.38, 0.12), vec3(0.22, 0.16, 0.38), clamp(worldDir.y, 0.0, 1.0));

		vec3 sky = mix(skyDay, skyNight, nightBlend);
		sky = mix(sky, skySunset, sunsetBlend * 0.85);
		sky = mix(sky, vec3(0.22, 0.25, 0.30), rainStrength);

		if (worldDir.y > 0.04) {
			vec2 cc = (worldDir.xz / worldDir.y) * 1.2;
			cc.x += frameTimeCounter * 0.011;
			cc.y += frameTimeCounter * 0.004;
			float n = fbm(cc);
			float ca = smoothstep(0.42, 0.68, n);

			vec3 cloudDay = vec3(1.0, 0.98, 0.95);
			vec3 cloudNight = vec3(0.05, 0.08, 0.13);
			vec3 cloudSunset = vec3(1.15, 0.58, 0.28);

			vec3 cloudColor = mix(cloudDay, cloudNight, nightBlend);
			cloudColor = mix(cloudColor, cloudSunset, sunsetBlend * 0.9);
			cloudColor = mix(cloudColor, vec3(0.22, 0.25, 0.3), rainStrength);

			float hf = smoothstep(0.04, 0.22, worldDir.y);
			sky = mix(sky, cloudColor, ca * hf * 0.82);
		}

		// Blend vanilla sun, moon, and stars over the custom sky
		sky = mix(sky, albedo.rgb, albedo.a);

		finalColor = sky;
	} else {
		vec3 ndcPos = vec3(texcoord.xy, rawDepth) * 2.0 - vec3(1.0);
		vec4 vph = gbufferProjectionInverse * vec4(ndcPos, 1.0);
		vec3 viewPos = vph.xyz / vph.w;
		float dist = length(viewPos);

		vec3 fogColorDay = mix(vec3(0.38, 0.62, 0.93), vec3(0.82, 0.38, 0.12), sunsetBlend);
		vec3 fogColorNight = vec3(0.01, 0.015, 0.03);
		vec3 fogColor = mix(fogColorDay, fogColorNight, nightBlend);

		float fogFactor = exp(-pow(dist * mix(0.004, 0.015, rainStrength), 2.0));
		finalColor = mix(fogColor, finalColor, clamp(fogFactor, 0.0, 1.0));
	}

	finalColor *= 1.2;
	finalColor = ACESFilm(finalColor);
	finalColor = pow(max(finalColor, vec3(0.0)), vec3(1.0 / 2.2));

	color = vec4(finalColor, albedo.a);
}