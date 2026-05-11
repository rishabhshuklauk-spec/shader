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
	vec2 lightmap = texture(colortex1, texcoord).xy;
	lightmap.x = pow(lightmap.x, 2.6);
	lightmap.y = pow(lightmap.y, 2.6);

	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 normal = normalize((encodedNormal - 0.5) * 2.0);
	vec3 viewLightVector = normalize(shadowLightPosition);
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * viewLightVector;

	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2));

	float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	color.rgb = mix(vec3(luma), color.rgb, 0.75);

	float depth = texture(depthtex0, texcoord).r;
	vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	float distanceToPlayer = length(viewPos);

	bool isHand = distanceToPlayer < 1.5;

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

	float time = float(worldTime);
	float dayBlend = 1.0 - clamp((time - 12000.0) / 1000.0, 0.0, 1.0) + clamp((time - 23000.0) / 1000.0, 0.0, 1.0);
	float sunsetBlend = clamp(1.0 - abs(time - 12500.0) / 1000.0, 0.0, 1.0) + clamp(1.0 - abs(time - 23500.0) / 1000.0, 0.0, 1.0);

	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	shadowClipPos.xyz = distort(shadowClipPos.xyz);
	vec3 shadowNdcPos = shadowClipPos.xyz / shadowClipPos.w;
	vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;

	float NdotL = clamp(dot(normal, viewLightVector), 0.0, 1.0);
	float bias = mix(0.002, 0.0005, NdotL);

	float shadow = 1.0;
	if (!isHand && shadowScreenPos.x > 0.0 && shadowScreenPos.x < 1.0 && shadowScreenPos.y > 0.0 && shadowScreenPos.y < 1.0) {
		shadow = getPCFShadow(shadowScreenPos, bias);
	}
	shadow = mix(0.35, 1.0, shadow);

	vec3 sunlightColor = mix(vec3(0.01, 0.02, 0.03), vec3(1.15, 1.05, 0.95), dayBlend);
	sunlightColor = mix(sunlightColor, vec3(1.8, 0.7, 0.2), sunsetBlend);

	vec3 skylightColor = mix(vec3(0.01, 0.02, 0.04), vec3(0.2, 0.4, 0.6), dayBlend);
	skylightColor = mix(skylightColor, vec3(0.3, 0.15, 0.25), sunsetBlend);

	vec3 ambient = mix(vec3(0.02), vec3(0.05, 0.06, 0.08), dayBlend);
	ambient = mix(ambient, vec3(0.09, 0.05, 0.05), sunsetBlend);

	vec3 blocklight = lightmap.x * vec3(1.0, 0.65, 0.25);
	vec3 skylight = lightmap.y * skylightColor;

	float wrappedLight = dot(worldLightVector, normal) * 0.5 + 0.5;
	if (isHand) wrappedLight = 1.0;

	vec3 sunlight = sunlightColor * clamp(wrappedLight, 0.0, 1.0) * shadow * lightmap.y;

	color.rgb *= (blocklight + skylight + ambient + sunlight);

	vec3 viewDir = normalize(viewPos);
	float sunDot = clamp(dot(viewDir, viewLightVector), 0.0, 1.0);
	float upDot = clamp(viewDir.y, 0.0, 1.0);

	vec3 nativeFog = pow(fogColor, vec3(2.2));

	vec3 skyZenith = mix(vec3(0.01, 0.015, 0.02), vec3(0.08, 0.25, 0.55), dayBlend);
	skyZenith = mix(skyZenith, vec3(0.12, 0.05, 0.18), sunsetBlend);

	vec3 skyHorizon = mix(vec3(0.02, 0.025, 0.03), nativeFog * 1.5, dayBlend);
	skyHorizon = mix(skyHorizon, vec3(1.2, 0.45, 0.15), sunsetBlend);

	float glowSpread = mix(8.0, 4.0, sunsetBlend);
	float glowIntensity = mix(0.8, 1.8, sunsetBlend);
	vec3 sunGlow = sunlightColor * pow(sunDot, glowSpread) * glowIntensity;

	vec3 customSky = mix(skyHorizon, skyZenith, pow(upDot, 0.5)) + sunGlow;

	if (depth == 1.0) {
		color.rgb = ACESFilm(customSky * 0.9);
		return;
	}

	float atmoFogFactor = exp(-pow(distanceToPlayer * 0.0025, 2.0));
	color.rgb = mix(customSky, color.rgb, clamp(atmoFogFactor, 0.0, 1.0));

	color.rgb = ACESFilm(color.rgb * 0.9);
}