vec3 distortShadowClipPos(vec3 shadowClipPos) {
    float distortionFactor = length(shadowClipPos.xy);
    distortionFactor = distortionFactor * 0.75 + 0.25;
    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.2;
    return shadowClipPos;
}