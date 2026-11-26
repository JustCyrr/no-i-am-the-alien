shader_type canvas_item;

uniform float bg_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.22;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.24;
uniform float glow_strength : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = FRAGCOORD.xy;

	// Deep asphalt / gunmetal base
	vec3 base_col = vec3(0.032, 0.036, 0.034);

	// Subtle drifting tactical grid
	vec2 grid_uv = px / 44.0 + vec2(TIME * 0.08, TIME * 0.04);
	vec2 gv = abs(fract(grid_uv - 0.5) - 0.5);
	float major_line = step(0.475, max(gv.x, gv.y));
	vec2 sub_uv = px / 11.0 + vec2(TIME * 0.08, TIME * 0.04);
	vec2 sv = abs(fract(sub_uv - 0.5) - 0.5);
	float minor_line = step(0.47, max(sv.x, sv.y));

	vec3 grid_col = vec3(0.11, 0.14, 0.11) * major_line + vec3(0.045, 0.055, 0.048) * minor_line;
	base_col += grid_col * grid_strength;

	// Atmospheric crimson breach glow (bottom-left) + alien bio-acid glow (right)
	float red_dist = length((uv - vec2(0.14, 0.88)) * vec2(1.15, 1.35));
	float red_glow = exp(-red_dist * 2.6) * (0.28 + 0.04 * sin(TIME * 2.1));

	float green_dist = length((uv - vec2(0.78, 0.56)) * vec2(1.05, 1.25));
	float green_glow = exp(-green_dist * 2.4) * (0.22 + 0.035 * cos(TIME * 1.7));

	base_col += vec3(0.90, 0.11, 0.09) * red_glow * glow_strength;
	base_col += vec3(0.26, 0.88, 0.18) * green_glow * glow_strength;

	// Crisp CRT horizontal scanlines
	float scan = sin(px.y * 1.5707963);
	float scan_mask = 1.0 - scanline_strength * (0.5 + 0.5 * scan);
	base_col *= scan_mask;

	// Subtle sweeping radar bar
	float sweep_y = fract(TIME * 0.09);
	float sweep = exp(-abs(uv.y - sweep_y) * 55.0) * 0.06 * glow_strength;
	base_col += vec3(0.45, 1.0, 0.30) * sweep;

	// Film grain
	float grain = (hash21(floor(px * 0.5) + floor(TIME * 24.0)) - 0.5) * 0.045;
	base_col += vec3(grain);

	// Hard edge vignette
	vec2 vig_uv = (uv - 0.5) * 2.0;
	float vig = clamp(1.0 - dot(vig_uv, vig_uv) * 0.38, 0.18, 1.0);
	base_col *= vig;

	COLOR = vec4(clamp(base_col, 0.0, 1.0), bg_opacity);
}
