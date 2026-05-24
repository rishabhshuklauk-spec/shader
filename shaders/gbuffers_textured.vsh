#version 330 compatibility

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor  = gl_Color;
	normal   = normalize(gl_NormalMatrix * gl_Normal);
	gl_Position = ftransform();
}