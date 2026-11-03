shader_type canvas_item;

uniform float center_opacity : hint_range(0.0, 1.0) = 0.75;
uniform float fade_start : hint_range(0.0, 1.0) = 0.20;
uniform float fade_end : hint_range(0.0, 1.5) = 1.0;

void fragment() {
    float original_alpha = COLOR.a;

    vec2 centered = (UV - vec2(0.5)) * 2.0;

    float distance_from_center = length(centered);

    float fade = 1.0 - smoothstep(
        fade_start,
        fade_end,
        distance_from_center
    );

    COLOR = vec4(
        0.015,
        0.020,
        0.025,
        fade * center_opacity * original_alpha
    );
}