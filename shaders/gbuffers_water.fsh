#version 330 compatibility

/* RENDERTARGETS: 0,1,2 */

uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in float materialID;

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmap;
layout(location = 2) out vec4 normalData;

void main() {
	vec4 texColor = texture(gtexture, texcoord) * glcolor;

	if (materialID == 102.0) {
		vec3 waterColor = vec3(0.05, 0.4, 0.6);
		texColor.rgb = mix(texColor.rgb, waterColor, 0.75);
		texColor.a = 0.55;
	}

	color = texColor;

	lightmap = vec4(lmcoord, 0.0, 1.0);
	normalData = vec4(normal * 0.5 + 0.5, 1.0);
}