#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;

uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform int worldTime;
uniform int isEyeInWater;

uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform float rainStrength;
uniform float frameTimeCounter;

uniform vec3 skyColor;
uniform vec3 fogColor;

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

void main() {
	float rawDepth = texture(depthtex0, texcoord).r;
	float opaqueDepth = texture(depthtex1, texcoord).r;

	vec3 ndcPos = vec3(texcoord.xy, rawDepth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);
	float distanceToPlayer = length(viewPos);

	vec2 lightmap = texture(colortex1, texcoord).xy;
	lightmap.x = pow(lightmap.x, 2.6);
	lightmap.y = pow(lightmap.y, 2.6);

	vec4 encodedNormalData = texture(colortex2, texcoord);
	vec3 normal = vec3(0.0, 1.0, 0.0);
	if (length(encodedNormalData.rgb) > 0.01) {
		normal = normalize((encodedNormalData.rgb - 0.5) * 2.0);
	}

	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2));

	float handLight = max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;

	if (isEyeInWater == 1) {
		vec3 waterColor = vec3(0.05, 0.35, 0.65);
		vec3 absorbColor = vec3(0.8, 0.25, 0.05);

		float opticalDepth = distanceToPlayer * 0.15;
		vec3 transmittance = exp(-absorbColor * opticalDepth);

		float ambientSky = max(lightmap.y, 0.1);
		vec3 inWaterAmbient = waterColor * ambientSky;

		vec3 rawTorchColor = vec3(1.2, 0.7, 0.2);
		vec3 inWaterBlock = rawTorchColor * lightmap.x * transmittance;

		color.rgb *= (inWaterAmbient + inWaterBlock + 0.02);

		if (handLight > 0.0) {
			float hAtten = clamp(1.0 - (distanceToPlayer / 15.0), 0.0, 1.0);
			hAtten = hAtten * hAtten;
			color.rgb += rawTorchColor * handLight * hAtten * transmittance * 1.5;
		}

		vec3 scatterLight = waterColor * ambientSky * 0.4;
		color.rgb = color.rgb * transmittance + scatterLight * (1.0 - transmittance);

		color.rgb = ACESFilm(color.rgb * 1.1);
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
	shadow = mix(mix(0.65, 0.25, nightBlend), 1.0, shadow);

	vec3 lightColor = vec3(1.15, 1.05, 0.95) * dayBlend
	+ vec3(1.6, 0.65, 0.15) * twilightBlend
	+ vec3(0.12, 0.18, 0.28) * nightBlend;

	vec3 ambientColor = vec3(0.08, 0.10, 0.14) * dayBlend
	+ vec3(0.14, 0.10, 0.08) * twilightBlend
	+ vec3(0.06, 0.08, 0.12) * nightBlend;

	ambientColor = mix(ambientColor, vec3(0.12, 0.10, 0.08), hotBiome * dayBlend);

	vec3 blocklight = lightmap.x * vec3(1.2, 0.8, 0.4);
	vec3 skylight = lightmap.y * mix(vec3(0.35, 0.50, 0.70), vec3(0.08, 0.12, 0.20), nightBlend);

	float wrappedLight = dot(viewLightVector, normal) * 0.5 + 0.5;
	vec3 directLight = lightColor * clamp(wrappedLight, 0.0, 1.0) * shadow * lightmap.y;
	vec3 baseLight = mix(vec3(0.02), vec3(0.05), nightBlend);

	if (handLight > 0.0) {
		float handAtten = clamp(1.0 - (distanceToPlayer / 15.0), 0.0, 1.0);
		handAtten = handAtten * handAtten;
		vec3 torchColor = vec3(1.3, 0.8, 0.35) * handLight;
		directLight += torchColor * handAtten;
	}

	color.rgb *= (blocklight + skylight + ambientColor + directLight + baseLight);

	vec3 viewDir = normalize(viewPos);

	float marchDist = min(distanceToPlayer, 64.0);
	int steps = 12;
	float stepSize = marchDist / float(steps);
	float dither = fract(sin(dot(texcoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 marchPos = viewDir * (dither * stepSize);
	float volumetrics = 0.0;

	for(int i = 0; i < steps; i++) {
		marchPos += viewDir * stepSize;
		vec3 worldM = (gbufferModelViewInverse * vec4(marchPos, 1.0)).xyz;
		vec3 sView = (shadowModelView * vec4(worldM, 1.0)).xyz;
		vec4 sClip = shadowProjection * vec4(sView, 1.0);
		sClip.xyz = distort(sClip.xyz);
		vec3 sScreen = sClip.xyz / sClip.w * 0.5 + 0.5;

		if(sScreen.x > 0.0 && sScreen.x < 1.0 && sScreen.y > 0.0 && sScreen.y < 1.0) {
			float sDepth = texture(shadowtex0, sScreen.xy).r;
			volumetrics += step(sScreen.z - 0.002, sDepth);
		}
	}
	volumetrics /= float(steps);
	vec3 godRays = lightColor * volumetrics * mix(0.08, 0.03, nightBlend) * dayBlend * lightmap.y;
	color.rgb += godRays;

	float skyExposure = smoothstep(0.8, 1.0, lightmap.y);

	bool isWater = (opaqueDepth - rawDepth > 0.00005) && (opaqueDepth != 1.0);

	if (isWater) {
		vec3 opaqueNdc = vec3(texcoord.xy, opaqueDepth) * 2.0 - 1.0;
		vec3 opaqueView = projectAndDivide(gbufferProjectionInverse, opaqueNdc);
		float physicalWaterDepth = length(opaqueView) - distanceToPlayer;

		vec3 surfaceNormal = normal;
		bool isWaterfall = normal.y < 0.8;
		vec2 waveCoord;

		if (isWaterfall) {
			waveCoord = vec2(feetPlayerPos.x + feetPlayerPos.z, feetPlayerPos.y * 2.5 + frameTimeCounter * 0.6);
		} else {
			waveCoord = feetPlayerPos.xz * 1.5 - frameTimeCounter * 0.05;
		}

		float wave = noise(waveCoord) * 0.5 + noise(waveCoord * 2.5 + frameTimeCounter * 0.05) * 0.25;
		surfaceNormal.x += wave * 0.06;
		if (!isWaterfall) surfaceNormal.y += wave * 0.03;
		surfaceNormal.z += wave * 0.06;
		surfaceNormal = normalize(surfaceNormal);

		vec3 deepOcean = vec3(0.02, 0.18, 0.35);
		vec3 tropicalCyan = vec3(0.0, 0.45, 0.60);
		vec3 jungleMurk = vec3(0.1, 0.25, 0.15);

		vec3 waterPigment = deepOcean;
		if (hotBiome > 0.0) waterPigment = mix(waterPigment, tropicalCyan, hotBiome);
		if (isJungle > 0.0) waterPigment = mix(waterPigment, jungleMurk, isJungle);

		vec3 absorbColor = vec3(0.85, 0.35, 0.05);
		vec3 transmittance = exp(-absorbColor * physicalWaterDepth * 0.12);

		float skyLightImpact = max(lightmap.y, 0.15);
		vec3 scatterLight = waterPigment * skyLightImpact * 2.0;

		color.rgb = color.rgb * transmittance + scatterLight * (1.0 - transmittance);

		vec3 wHalfVector = normalize(worldLightVector + -mat3(gbufferModelViewInverse)*viewDir);
		float NdotH = clamp(dot(surfaceNormal, wHalfVector), 0.0, 1.0);
		float specular = pow(NdotH, 400.0) * shadow * skyExposure;

		vec3 specColor = mix(vec3(1.5, 1.4, 1.2), vec3(0.4, 0.6, 1.2), nightBlend);
		color.rgb += specular * specColor * 2.0;

		vec3 rDir = normalize(reflect(viewDir, surfaceNormal));
		vec3 rayPos = viewPos;
		vec3 ssrColor = vec3(0.0);
		float ssrHit = 0.0;

		int rSteps = 24;
		float rStepSize = 0.5;
		vec3 marchRDir = rDir * rStepSize;
		float ditherS = fract(sin(dot(texcoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
		rayPos += marchRDir * ditherS;

		for(int i = 0; i < rSteps; i++) {
			rayPos += marchRDir;
			vec4 p = gbufferProjection * vec4(rayPos, 1.0);
			p.xyz /= p.w;
			vec2 sPos = p.xy * 0.5 + 0.5;

			if(sPos.x < 0.0 || sPos.x > 1.0 || sPos.y < 0.0 || sPos.y > 1.0) break;

			float d = texture(depthtex0, sPos).r;
			vec3 ndcHit = vec3(sPos, d) * 2.0 - 1.0;
			vec3 hitView = projectAndDivide(gbufferProjectionInverse, ndcHit);

			float depthDiff = rayPos.z - hitView.z;
			if (depthDiff > 0.0 && depthDiff < 1.5) {
				ssrColor = texture(colortex0, sPos).rgb;
				ssrColor = pow(ssrColor, vec3(2.2));
				ssrHit = 1.0;
				break;
			}
		}

		if (ssrHit == 0.0) {
			vec3 worldRDir = mat3(gbufferModelViewInverse) * rDir;
			float rUpDot = clamp(worldRDir.y, 0.0, 1.0);
			vec3 skyReflect = mix(fogColor, skyColor, clamp(rUpDot * 2.5, 0.0, 1.0));

			vec3 rightV = normalize(cross(worldLightVector, vec3(0.0, 1.0, 0.0)));
			if (abs(worldLightVector.y) > 0.99) rightV = vec3(1.0, 0.0, 0.0);
			vec3 upV = cross(rightV, worldLightVector);
			float dx = dot(worldRDir, rightV);
			float dy = dot(worldRDir, upV);
			float dz = dot(worldRDir, worldLightVector);

			float sSize = 0.035;
			float sEdge = 0.0015;
			float squareBody = (1.0 - smoothstep(sSize - sEdge, sSize, abs(dx))) * (1.0 - smoothstep(sSize - sEdge, sSize, abs(dy))) * step(0.0, dz);

			vec3 celestialColor = mix(vec3(1.2, 1.1, 1.0), vec3(0.4, 0.6, 1.0), nightBlend);
			float sunGlow = pow(max(dz, 0.0), mix(60.0, 40.0, dayBlend)) * mix(0.8, 0.25, nightBlend);

			skyReflect += (squareBody + sunGlow) * celestialColor;
			ssrColor = skyReflect * skyExposure;
		}

		float fresnel = clamp(1.0 - dot(-viewDir, surfaceNormal), 0.0, 1.0);
		fresnel = pow(fresnel, mix(5.0, 3.0, float(isWater)));

		float finalReflect = mix(0.1, 0.9, fresnel);
		if (isWaterfall) finalReflect *= 0.5;

		color.rgb = mix(color.rgb, ssrColor, finalReflect);
	}

	vec3 worldViewDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
	float upDot = clamp(worldViewDir.y, 0.0, 1.0);
	vec3 vanillaSky = mix(fogColor, skyColor, clamp(upDot * 2.5, 0.0, 1.0));

	vec3 rightV = normalize(cross(worldLightVector, vec3(0.0, 1.0, 0.0)));
	if (abs(worldLightVector.y) > 0.99) rightV = vec3(1.0, 0.0, 0.0);
	vec3 upV = cross(rightV, worldLightVector);

	float dx = dot(worldViewDir, rightV);
	float dy = dot(worldViewDir, upV);
	float dz = dot(worldViewDir, worldLightVector);

	float sSize = 0.035;
	float sEdge = 0.0015;
	float squareBody = (1.0 - smoothstep(sSize - sEdge, sSize, abs(dx))) * (1.0 - smoothstep(sSize - sEdge, sSize, abs(dy))) * step(0.0, dz);

	vec3 celestialColor = mix(vec3(1.2, 1.1, 1.0), vec3(0.35, 0.6, 1.2), nightBlend);
	float sunGlow = pow(max(dz, 0.0), mix(60.0, 25.0, nightBlend)) * mix(0.8, 0.6, nightBlend);

	vanillaSky += (squareBody + sunGlow) * celestialColor;

	if (rawDepth == 1.0) {
		color.rgb = ACESFilm(vanillaSky * 0.85);
		return;
	}

	float fogBase = mix(0.0025, 0.001, nightBlend);
	float atmoFogFactor = exp(-pow(distanceToPlayer * fogBase, 2.0));
	color.rgb = mix(vanillaSky, color.rgb, clamp(atmoFogFactor, 0.0, 1.0));

	color.rgb = ACESFilm(color.rgb * 0.85);
}