#version 330 compatibility

uniform sampler2D texture;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 color;

void main() {
	vec4 albedo = texture(texture, texcoord) * glcolor;

	if (albedo.a < 0.05) {
		discard;
	}

	color = albedo;
}