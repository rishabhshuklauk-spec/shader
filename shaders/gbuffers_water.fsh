#version 330 compatibility

/* RENDERTARGETS: 0,1,2 */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float frameTimeCounter;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;
in vec3 worldPos;
in float blockId;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;

vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }

float noise(vec2 v) {
  const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);

  vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;

  i = mod289(i);
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 )) + i.x + vec3(0.0, i1.x, 1.0 ));

  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
  m = m*m;
  m = m*m;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

void main() {
    vec4 albedo = texture(texture, texcoord) * glcolor;

    float t = frameTimeCounter;

    vec2 waveCoord1 = worldPos.xz * 0.8 + vec2(t * 0.3, t * 0.2);
    vec2 waveCoord2 = worldPos.xz * 1.6 + vec2(-t * 0.2, t * 0.35);
    vec2 waveCoord3 = worldPos.xz * 0.4 + vec2(t * 0.15, -t * 0.1);

    float dx = noise(waveCoord1 + vec2(0.1, 0.0)) - noise(waveCoord1 - vec2(0.1, 0.0));
    float dz = noise(waveCoord1 + vec2(0.0, 0.1)) - noise(waveCoord1 - vec2(0.0, 0.1));
    vec3 waveNormal = normalize(vec3(-dx * 0.3, 1.0, -dz * 0.3));
    waveNormal = normalize(gl_NormalMatrix * waveNormal);

    // Write almost transparent to colortex0 to preserve background terrain
    colortex0 = vec4(0.0, 0.0, 0.0, 0.01);
    
    // Write empty to colortex1 (bloom buffer)
    colortex1 = vec4(0.0);

    // Write normal to RGB, and surface distance to Alpha
    colortex2 = vec4(waveNormal * 0.5 + 0.5, length(viewPos));
}