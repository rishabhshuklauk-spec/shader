#version 330 compatibility

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;
in float materialID;

layout(location = 0) out vec4 color;

void main() {
    if (materialID == 100.0) {
        discard;
    }

    color = texture(gtexture, texcoord) * glcolor;
    if (color.a < 0.1) {
        discard;
    }
}