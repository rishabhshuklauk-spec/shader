#version 330 compatibility

uniform sampler2D texture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;

void main() {
	vec4 albedo = texture(texture, texcoord) * glcolor;

	if (albedo.a < 0.1) {
		discard;
	}

	colortex0 = albedo;
	colortex1 = vec4(lmcoord, 0.0, 1.0);
}