#version 330 compatibility

uniform float frameTimeCounter;
uniform vec3 cameraPosition;

in vec4 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out float materialID;

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor  = gl_Color;
	normal   = normalize(gl_NormalMatrix * gl_Normal);
	materialID = mc_Entity.x;

	vec4 position = gl_Vertex;
	vec3 worldPos = position.xyz + cameraPosition;

	if (materialID == 102.0) {
		float wave = sin(frameTimeCounter * 0.6 + worldPos.x * 0.5 + worldPos.z * 0.5) * 0.03;
		position.y += wave;
	}

	gl_Position = gl_ModelViewProjectionMatrix * position;
}