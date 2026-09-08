precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uOffset;
uniform float uTime;
uniform vec3 uBaseColor;
uniform float uOpacity;
uniform vec2 uLightPos;

out vec4 fragColor;

vec4 tanh_polyline(vec4 x) {
    vec4 val = clamp(x, -20.0, 20.0);
    vec4 ex = exp(val);
    vec4 emx = exp(-val);
    return (ex - emx) / (ex + emx);
}

void main() {
    // 1. Coordinates (Logical mapping)
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 localCoord = fragCoord - uOffset;
    vec2 uv = localCoord / uSize;

    // 2. Base Aluminum Shading
    float edgeShadow = max(0.4, 1.0 - pow(abs(uv.y - 0.5) * 2.0, 3.0));
    vec3 color = uBaseColor * edgeShadow;

    // 3. DYNAMIC SYMMETRIC LIGHTING
    // Calculate the absolute distance to the light source
    // We use a weighted distance to make the light feel "wider" (Cinematic)
    float dx = abs(fragCoord.x - uLightPos.x);
    float dy = abs(fragCoord.y - uLightPos.y);

    // Weighted distance: dy*0.3 makes the light "tall" (shines from below/above easily)
    float dist = sqrt(dx*dx + (dy*dy * 0.3));

    // Large radius ensures the text catches the light even from the bottom of the screen
    float lightRadius = 800.0;
    float glow = smoothstep(lightRadius, 0.0, dist);

    // SHINE LOGIC:
    // High-intensity specular 'hit'
    float glint = pow(glow, 60.0) * 25.0;

    // Base ambient glow from the sun/cursor
    float ambientGlow = 1 - glow;

    // Combine with a Pure White Light for Silver effect
    vec3 lightColor = vec3(1.0, 1.0, 1.0);
    
    // FIX: Apply the light color to the glow/glint!
    // Previously it was adding scalar (white) to vector.
    // Also boost glint slightly (30.0) to ensure "pop".
    color += lightColor * (ambientGlow + glint);

    // 4. Final Tone Mapping & Fade
    // Tone Mapping handles high values gracefully, so we can push glint high.
    vec4 finalResult = tanh_polyline(vec4(color, 1.0));
    fragColor = vec4(finalResult.rgb * uOpacity, uOpacity);
}