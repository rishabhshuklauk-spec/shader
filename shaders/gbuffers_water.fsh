#version 330 compatibility

/* RENDERTARGETS: 0,1,2 */

uniform sampler2D gtexture;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in float matID;
in vec3 wPos;

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmap;
layout(location = 2) out vec4 normalData;

vec2 hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
	const float K1 = 0.366025404;
	const float K2 = 0.211324865;
	vec2 i = floor(p + (p.x + p.y) * K1);
	vec2 a = p - i + (i.x + i.y) * K2;
	vec2 o = (a.x > a.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec2 b = a - o + K2;
	vec2 c = a - 1.0 + 2.0 * K2;
	vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
	vec3 n = h * h * h * h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
	return dot(n, vec3(70.0));
}

float waterHeight(vec2 pos) {
	float h = 0.0;
	float amplitude = 0.15;
	float frequency = 0.2;
	float t = frameTimeCounter * 0.4;
	for (int i = 0; i < 3; i++) {
		h += noise(pos * frequency + t) * amplitude;
		amplitude *= 0.4;
		frequency *= 2.0;
		t *= 1.1;
	}
	return h;
}

vec3 getWaterNormal(vec2 pos) {
	float eps = 0.1;
	float h0 = waterHeight(pos);
	float hx = waterHeight(pos + vec2(eps, 0.0));
	float hz = waterHeight(pos + vec2(0.0, eps));
	return normalize(vec3(h0 - hx, eps * 1.5, h0 - hz));
}

void main() {
	vec4 texColor = texture(gtexture, texcoord) * glcolor;

	if (matID == 102.0) {
		vec3 waterNormal = getWaterNormal(wPos.xz);
		vec3 worldViewDir = normalize(cameraPosition - wPos);
		vec3 worldLightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
		vec3 halfVector = normalize(worldLightDir + worldViewDir);

		float NdotV = max(dot(waterNormal, worldViewDir), 0.0);
		float fresnel = pow(1.0 - NdotV, 5.0);

		float NdotH = max(dot(waterNormal, halfVector), 0.0);
		float specular = pow(NdotH, 400.0) * 1.5;

		vec3 waterColor = vec3(0.08, 0.50, 0.70);
		vec3 skyReflect = vec3(0.40, 0.65, 0.95);
		float NdotL = max(dot(waterNormal, worldLightDir), 0.0);

		vec3 finalColor = mix(waterColor, skyReflect, fresnel * 0.9);
		finalColor += vec3(1.0, 0.98, 0.95) * specular * NdotL;

		float depthAlpha = mix(0.45, 0.90, fresnel);

		texColor.rgb = finalColor;
		texColor.a = depthAlpha;
	}

	color = texColor;
	lightmap = vec4(lmcoord, 0.0, 1.0);
	normalData = vec4(normal * 0.5 + 0.5, 1.0);
}