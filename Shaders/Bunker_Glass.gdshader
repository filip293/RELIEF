shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

uniform vec4 glass_tint : source_color = vec4(0.9, 0.95, 0.9, 0.15); // Very transparent
uniform float roughness_clean : hint_range(0.0, 1.0) = 0.02;       // Ultra-smooth like real glass
uniform float grime_intensity : hint_range(0.0, 1.0) = 0.25;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(rand(i + vec2(0.0, 0.0)), rand(i + vec2(1.0, 0.0)), f.x),
               mix(rand(i + vec2(0.0, 1.0)), rand(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    
    // Subtle dust and smudge spots that will catch the flashlight beam
    float smudges = noise(uv * 12.0) * grime_intensity;
    
    // True glass has no base albedo color blocking the view behind it
    ALBEDO = vec3(0.01);
    METALLIC = 0.0;
    SPECULAR = 1.0; // Maximum light bounce for flashlight glare
    
    // Smooth glass with smudges that react to light hits
    ROUGHNESS = clamp(roughness_clean + smudges, 0.01, 0.7);
    
    // High transparency so the room behind stays fully visible
    ALPHA = glass_tint.a + (smudges * 0.1);
}