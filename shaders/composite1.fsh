#version 330 compatibility

/* RENDERTARGETS: 0,1 */

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float viewWidth;
uniform float viewHeight;
in vec2 texcoord;
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 bloomColor;

void main() {
    color = texture(colortex0, texcoord);
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    vec3 bloom = vec3(0.0);
    float weightSum = 0.0;
    int samples = 3;
    float spread = 4.0;
    for(int x = -samples; x <= samples; x++) {
        for(int y = -samples; y <= samples; y++) {
            vec2 offset = vec2(x, y) * texel * spread;
            vec2 currentCoord = texcoord + offset;
            if (currentCoord.x < 0.0 || currentCoord.x > 1.0 || currentCoord.y < 0.0 || currentCoord.y > 1.0) {
                continue;
            }
            float dist = length(vec2(x, y));
            float weight = exp(-(dist * dist) / 8.0);
            vec3 sampleColor = texture(colortex0, currentCoord).rgb;
            float sampleDepth = texture(depthtex0, currentCoord).r;
            float brightness = dot(sampleColor, vec3(0.2126, 0.7152, 0.0722));
            float contribution = max(0.0, brightness - 0.4);
            if (sampleDepth == 1.0) {
                contribution = 0.0;
            }
            bloom += sampleColor * contribution * weight;
            weightSum += weight;
        }
    }
    if (weightSum > 0.0) {
        bloomColor = vec4(bloom / weightSum, 1.0);
    } else {
        bloomColor = vec4(0.0);
    }
}