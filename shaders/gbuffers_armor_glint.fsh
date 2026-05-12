#version 330 compatibility

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 color;

void main() {
	vec4 texColor = texture(gtexture, texcoord) * glcolor;
	color = texColor;
}