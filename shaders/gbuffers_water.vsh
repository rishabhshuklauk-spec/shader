#version 330 compatibility

uniform float frameTimeCounter;
uniform vec3 cameraPosition;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	normal = normalize(gl_NormalMatrix * gl_Normal);

	vec4 position = gl_Vertex;
	vec3 worldPos = position.xyz + cameraPosition;

	bool isTop = normal.y > 0.8;

	if (isTop) {
		float waveSpeed = frameTimeCounter * 2.0;
		float wave1 = sin(worldPos.x * 1.5 + waveSpeed) * 0.05;
		float wave2 = cos(worldPos.z * 1.5 + waveSpeed * 0.8) * 0.05;

		position.y += wave1 + wave2;
	}

	gl_Position = gl_ModelViewProjectionMatrix * position;
}