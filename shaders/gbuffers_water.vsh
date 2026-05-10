#version 330 compatibility

uniform float frameTimeCounter;
uniform vec3 cameraPosition;

in vec4 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out float matID;
out vec3 wPos;

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor  = gl_Color;
	normal   = normalize(gl_NormalMatrix * gl_Normal);
	matID    = mc_Entity.x;

	vec4 position = gl_Vertex;
	vec3 worldPos = position.xyz + cameraPosition;

	if (matID == 102.0) {
		float t = frameTimeCounter * 0.5;
		position.y += sin(worldPos.x * 0.5 + t) * cos(worldPos.z * 0.5 + t) * 0.02;
	}

	wPos = worldPos;
	gl_Position = gl_ModelViewProjectionMatrix * position;
}