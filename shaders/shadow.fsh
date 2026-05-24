#version 330 compatibility

uniform sampler2D texture;

in vec2 texcoord;
in vec4 glcolor;
in float blockId;

void main() {
    vec4 albedo = texture(texture, texcoord);

    if (abs(blockId - 10001.0) < 0.5) {
        albedo.a = 1.0;
    }

    albedo *= glcolor;
    if (albedo.a < 0.1) discard;

    gl_FragData[0] = vec4(1.0);
}