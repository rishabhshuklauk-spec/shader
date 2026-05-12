#version 330 compatibility

uniform sampler2D colortex0;
in vec2 texcoord;
layout(location = 0) out vec4 color;

void main() {
    vec3 baseColor = texture(colortex0, texcoord).rgb;

    vec3 bloom = vec3(0.0);
    vec2 blurDir = vec2(0.5) - texcoord;
    blurDir = normalize(blurDir);

    float weightSum = 0.0;
    for (int i = -6; i <= 6; i++) {
        float weight = exp(-float(i * i) / 12.0);
        vec2 sampleCoord = texcoord + blurDir * (float(i) * 0.008);

        if (sampleCoord.x < 0.0 || sampleCoord.x > 1.0 || sampleCoord.y < 0.0 || sampleCoord.y > 1.0) continue;

        vec3 sampleColor = texture(colortex0, sampleCoord).rgb;
        float luma = dot(sampleColor, vec3(0.2126, 0.7152, 0.0722));

        float brightPass = smoothstep(0.95, 1.0, luma);

        bloom += sampleColor * brightPass * weight;
        weightSum += weight;
    }

    if (weightSum > 0.0) bloom /= weightSum;

    color = vec4(baseColor + bloom * 0.45, 1.0);
}