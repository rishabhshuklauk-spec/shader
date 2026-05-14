#version 330 compatibility

uniform sampler2D texture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;

void main() {
	vec4 albedo = texture(texture, texcoord) * glcolor;

	if (albedo.a < 0.05) {
		discard;
	}

	color = vec4(albedo.rgb, 0.15);
	colortex1 = vec4(lmcoord, 0.0, 1.0);
	colortex2 = vec4(normal * 0.5 + 0.5, 1.0);
}