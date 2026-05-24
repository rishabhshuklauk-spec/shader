#version 330 compatibility

uniform sampler2D texture;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

layout(location = 0) out vec4 colortex0;

void main() {
	vec4 albedo = texture(texture, texcoord) * glcolor;
	if (albedo.a < 0.1) discard;

	vec3 linearAlbedo = pow(max(albedo.rgb, vec3(0.0)), vec3(2.2));

	vec3 lightDir = normalize(shadowLightPosition);
	float NdotL = max(dot(normal, lightDir), 0.0);
	float skyLight = clamp(lmcoord.y, 0.0, 1.0);
	float blockLight = clamp(lmcoord.x, 0.0, 1.0);

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
	vec3 sunColor = mix(sunColorDay, sunColorNight, nightBlend) * NdotL * skyLight;

	vec3 finalColor = linearAlbedo * (ambient + sunColor);

	colortex0 = vec4(max(finalColor, vec3(0.0)), albedo.a);
}