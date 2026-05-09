#version 330 compatibility

/* RENDERTARGETS: 0,1,2 */

uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmap;
layout(location = 2) out vec4 normalData;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < 0.1) {
		discard;
	}

	lightmap = vec4(lmcoord, 0.0, 1.0);
	normalData = vec4(normal * 0.5 + 0.5, 1.0);
}