#version 330 compatibility

/*
const int colortex0Format = RGB16;
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

const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor = vec3(1.0);
const vec3 ambientColor = vec3(0.1);

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

void main() {
	vec2 lightmap = texture(colortex1, texcoord).xy;
	lightmap = clamp((lightmap - (1.0 / 32.0)) * (32.0 / 30.0), 0.0, 1.0);

	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 normal = normalize((encodedNormal - 0.5) * 2.0);
	vec3 lightVector = normalize(shadowLightPosition);
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;

	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2));

	float depth = texture(depthtex0, texcoord).r;
	if (depth == 1.0) return;

	vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

	shadowClipPos.z -= 0.001;
	shadowClipPos.xyz = distort(shadowClipPos.xyz);

	vec3 shadowNdcPos = shadowClipPos.xyz / shadowClipPos.w;
	vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;

	float shadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);

	vec3 blocklight = lightmap.x * blocklightColor;
	vec3 skylight = lightmap.y * skylightColor;
	vec3 ambient = ambientColor;
	vec3 sunlight = sunlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow * lightmap.y;

	color.rgb *= blocklight + skylight + ambient + sunlight;
}