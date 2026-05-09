#version 330 compatibility

#define REMOVE_GRASS //

uniform sampler2D gtexture;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in float matID;
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmap;
layout(location = 2) out vec4 normalData;

void main() {
	#ifdef REMOVE_GRASS
	if (matID == 100.0) {
		discard;
	}
	#endif
	vec4 texColor = texture(gtexture, texcoord) * glcolor;
	if (texColor.a < 0.1) {
		discard;
	}
	color = texColor;
	lightmap = vec4(lmcoord, 0.0, 1.0);
	normalData = vec4(normal * 0.5 + 0.5, 1.0);
}