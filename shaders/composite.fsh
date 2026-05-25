#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int isEyeInWater;
uniform vec3 cameraPosition;

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
	float rawDepth1 = texture(depthtex1, texcoord).r;
	vec4 albedo = texture(colortex0, texcoord);
	vec4 waterData = texture(colortex2, texcoord);

	vec3 worldLightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
	vec3 trueSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	float sunHeight = trueSunDir.y;
	float dayBlend = clamp(sunHeight * 4.0, 0.0, 1.0);
	float nightBlend = clamp(-sunHeight * 4.0, 0.0, 1.0);
	float sunsetBlend = clamp(1.0 - abs(sunHeight) * 5.0, 0.0, 1.0);

	vec3 finalColor = max(albedo.rgb, vec3(0.0));
	
	// Reconstruct view position for terrain (depthtex1) and surface (depthtex0)
	vec3 ndcPos0 = vec3(texcoord.xy, rawDepth) * 2.0 - vec3(1.0);
	vec4 vph0 = gbufferProjectionInverse * vec4(ndcPos0, 1.0);
	vec3 viewPos0 = vph0.xyz / vph0.w;
	
	vec3 ndcPos1 = vec3(texcoord.xy, rawDepth1) * 2.0 - vec3(1.0);
	vec4 vph1 = gbufferProjectionInverse * vec4(ndcPos1, 1.0);
	vec3 viewPos1 = vph1.xyz / vph1.w;

	bool isWater = waterData.a > 0.01;

	if (rawDepth > 0.9999 && !isWater) {
		vec3 ndcPos = vec3(texcoord.xy, rawDepth) * 2.0 - vec3(1.0);
		vec4 vph = gbufferProjectionInverse * vec4(ndcPos, 1.0);
		vec3 viewDir = normalize(vph.xyz / vph.w);
		vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewDir);

		vec3 skyDay = mix(vec3(0.38, 0.62, 0.93), vec3(0.12, 0.38, 0.78), clamp(worldDir.y, 0.0, 1.0));
		vec3 skyNight = mix(vec3(0.01, 0.015, 0.03), vec3(0.02, 0.025, 0.05), clamp(worldDir.y, 0.0, 1.0));
		vec3 skySunset = mix(vec3(0.82, 0.38, 0.12), vec3(0.22, 0.16, 0.38), clamp(worldDir.y, 0.0, 1.0));

		vec3 sky = mix(skyDay, skyNight, nightBlend);
		sky = mix(sky, skySunset, sunsetBlend);

		if (worldDir.y > 0.04) {
			vec2 cc = (worldDir.xz / worldDir.y) * 1.2;
			float cloudNoise = noise(cc + frameTimeCounter * 0.02);
			float cloudNoise2 = noise(cc * 2.5 - frameTimeCounter * 0.015);
			float cloudMask = smoothstep(0.4, 0.7, cloudNoise * 0.7 + cloudNoise2 * 0.3);
			
			vec3 cloudDay = vec3(1.0, 0.98, 0.95);
			vec3 cloudNight = vec3(0.05, 0.08, 0.13);
			vec3 cloudSunset = vec3(1.15, 0.58, 0.28);
			vec3 cloudColor = mix(cloudDay, cloudNight, nightBlend);
			cloudColor = mix(cloudColor, cloudSunset, sunsetBlend);
			
			float ca = cloudMask * 0.9;
			float hf = smoothstep(0.04, 0.15, worldDir.y);
			sky = mix(sky, cloudColor, ca * hf * 0.82);
		}

		// Mask out the square edges of the vanilla sun/moon
		float sunDot = dot(worldDir, trueSunDir);
		float moonDot = dot(worldDir, -trueSunDir);
		float celestialMask = smoothstep(0.998, 0.999, max(sunDot, moonDot));
		float isVanillaSunMoon = step(0.9, albedo.a);
		sky = mix(sky, albedo.rgb, albedo.a * mix(1.0, celestialMask, isVanillaSunMoon));

		finalColor = sky;
	} else if (isWater) {
		float waterDist = waterData.a;
		vec3 viewPosWater = normalize(viewPos1) * waterDist;
		vec3 viewDirWater = normalize(viewPosWater);
		vec3 worldDirWater = normalize(mat3(gbufferModelViewInverse) * viewDirWater);

		float waterDepth = max(length(viewPos1) - length(viewPosWater), 0.0);
		if (rawDepth1 > 0.9999) waterDepth = 100.0;
		if (isEyeInWater == 1) waterDepth = length(viewPosWater);

		vec3 background = albedo.rgb;
		if (rawDepth1 > 0.9999) {
			vec3 skyDay = mix(vec3(0.38, 0.62, 0.93), vec3(0.12, 0.38, 0.78), clamp(worldDirWater.y, 0.0, 1.0));
			vec3 skyNight = mix(vec3(0.01, 0.015, 0.03), vec3(0.02, 0.025, 0.05), clamp(worldDirWater.y, 0.0, 1.0));
			background = mix(skyDay, skyNight, nightBlend);
		}

		float edgeFade = clamp(waterDepth * 10.0, 0.0, 1.0);
		
		vec3 waterNormalView = waterData.rgb * 2.0 - vec3(1.0);
		if (isEyeInWater == 1) {
			waterNormalView = -waterNormalView; // Invert normal for Snell's window and TIR
		}
		vec3 waterNormalWorld = normalize(mat3(gbufferModelViewInverse) * waterNormalView);
		
		vec3 viewLightDir = normalize(shadowLightPosition);
		float NdotL = max(dot(waterNormalView, viewLightDir), 0.0);
		
		vec3 halfDir = normalize(-viewDirWater + viewLightDir);
		float spec = pow(max(dot(waterNormalView, halfDir), 0.0), 96.0) * edgeFade;
		
		vec3 specColorDay = vec3(1.4, 1.3, 1.0);
		vec3 specColorNight = vec3(0.2, 0.3, 0.5);
		vec3 specular = mix(specColorDay, specColorNight, nightBlend) * spec * 0.15;

		float transmittance = exp(-waterDepth * 0.15); // Uniform absorption stops the terrain from turning green!

		vec3 waterColorDay = mix(vec3(0.01, 0.06, 0.15), vec3(0.03, 0.18, 0.35), transmittance);
		vec3 waterColorNight = vec3(0.0, 0.01, 0.03);
		vec3 waterColor = mix(waterColorDay, waterColorNight, nightBlend);
		
		float fresnel = pow(1.0 - max(dot(-worldDirWater, waterNormalWorld), 0.0), 5.0);
		fresnel = (0.02 + 0.3 * fresnel) * edgeFade;
		
		vec3 skyReflect = mix(vec3(0.35, 0.55, 0.85), vec3(0.02, 0.03, 0.06), nightBlend);
		vec3 reflectionColor = skyReflect;
		
		if (isEyeInWater == 1) {
			reflectionColor = waterColor; // Total Internal Reflection shows deep water
		}

		vec3 litWater = background * transmittance + waterColor * (1.0 - transmittance);
		finalColor = mix(litWater, reflectionColor, fresnel * 0.3) + specular;
	} else {
		float dist = length(viewPos0);

		vec3 fogColorDay = mix(vec3(0.38, 0.62, 0.93), vec3(0.82, 0.38, 0.12), sunsetBlend);
		vec3 fogColorNight = vec3(0.01, 0.015, 0.03);
		vec3 fogColor = mix(fogColorDay, fogColorNight, nightBlend);
		float fogDensity = mix(0.004, 0.015, rainStrength);

		if (isEyeInWater == 1) {
			fogColor = vec3(0.01, 0.08, 0.18);
			fogDensity = 0.02;
		}

		float fogFactor = exp(-pow(dist * fogDensity, 2.0));
		finalColor = mix(fogColor, finalColor, clamp(fogFactor, 0.0, 1.0));
	}

	finalColor *= 1.2;
	finalColor = ACESFilm(finalColor);
	finalColor = pow(max(finalColor, vec3(0.0)), vec3(1.0 / 2.2));

	color = vec4(finalColor, albedo.a);
}