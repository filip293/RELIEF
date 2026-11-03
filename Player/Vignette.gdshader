shader_type canvas_item;

uniform float edge_opacity : hint_range(0.0, 1.0) = 1;
uniform float clear_radius : hint_range(0.0, 0.6) = 0.01;
uniform float fade_radius : hint_range(0.2, 1.0) = 0.22;

void fragment() {
    float original_alpha = COLOR.a;

    vec2 centered = (UV - vec2(0.5)) * vec2(1.0, 0.75);

    float distance_from_center = length(centered);

    float darkness = smoothstep(
        clear_radius,
        fade_radius,
        distance_from_center
    );

    COLOR = vec4(
        0.0,
        0.0,
        0.0,
        darkness * edge_opacity * original_alpha
    );
}