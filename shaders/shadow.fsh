#version 330 compatibility

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

void main() {
    vec4 texColor = texture(gtexture, texcoord) * glcolor;
    if (texColor.a < 0.1) {
        discard;
    }
    gl_FragData[0] = vec4(0.0);
}