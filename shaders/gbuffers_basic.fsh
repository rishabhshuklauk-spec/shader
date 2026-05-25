#version 330 compatibility

uniform sampler2D lightmap;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 colortex1;

void main() {
	color = glcolor * texture(lightmap, lmcoord);
	if (color.a < alphaTestRef) {
		discard;
	}
    colortex1 = vec4(0.0);
}