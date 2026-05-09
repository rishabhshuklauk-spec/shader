#version 330 compatibility

#define REMOVE_GRASS //

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
in vec4 mc_Entity;
out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out float matID;

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor  = gl_Color;
	normal   = normalize(gl_NormalMatrix * gl_Normal);
	matID    = mc_Entity.x;
	vec4 position = gl_Vertex;
	#ifdef REMOVE_GRASS
	if (matID == 100.0) {
		position.xyz = vec3(0.0);
	}
	#endif
	if (matID == 101.0) {
		vec3 worldPos = position.xyz + cameraPosition;
		float waveSpeed = 0.5;
		float waveStrength = 0.03;
		float wave = sin(frameTimeCounter * waveSpeed + worldPos.x * 0.8 + worldPos.z * 0.8) * waveStrength;
		position.x += wave;
		position.z += wave * 0.5;
	}
	gl_Position = gl_ModelViewProjectionMatrix * position;
}