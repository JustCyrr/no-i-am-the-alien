shader_type spatial;
render_mode cull_back;

// ============================================================================
// Alien Neon Signboard, Hologram & CRT Monitor Shader (Godot 4.x)
// Ideal for city_neon_sign, hosp_monitor_screen, and glowing neon trims
// Crisp pixel-art scanlines, chromatic edge fringe, subtle flicker & glitch!
// ============================================================================

uniform sampler2D screen_albedo_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D screen_emissive_tex : source_color, filter_nearest, repeat_enable;

uniform float emission_energy : hint_range(0.5, 8.0) = 2.6;
uniform float scanline_density : hint_range(24.0, 256.0) = 96.0;
uniform float scanline_strength : hint_range(0.0, 0.6) = 0.24;
uniform float scanline_scroll_speed : hint_range(-4.0, 4.0) = 0.35;
uniform float chromatic_offset : hint_range(0.0, 0.015) = 0.004;
uniform float flicker_strength : hint_range(0.0, 0.35) = 0.08;
uniform float glitch_intensity : hint_range(0.0, 0.08) = 0.012;
uniform float glitch_rate : hint_range(0.5, 12.0) = 3.2;
uniform float fresnel_boost : hint_range(0.0, 1.5) = 0.45;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	vec2 uv = UV;

	// Occasional crisp horizontal band glitch (brief retro signal hiccup)
	float t_slot = floor(TIME * glitch_rate);
	float glitch_trigger = step(0.84, hash11(t_slot));
	float row_band = floor(uv.y * 16.0);
	float row_rand = hash11(row_band + t_slot * 7.13) - 0.5;
	float row_mask = step(0.72, hash11(row_band * 3.7 + t_slot));
	uv.x += row_rand * glitch_intensity * glitch_trigger * row_mask;

	// Subtle RGB chromatic channel separation on emissive neon glyphs
	vec3 alb = texture(screen_albedo_tex, uv).rgb;
	float em_r = texture(screen_emissive_tex, uv + vec2(chromatic_offset, 0.0)).r;
	float em_g = texture(screen_emissive_tex, uv).g;
	float em_b = texture(screen_emissive_tex, uv - vec2(chromatic_offset, 0.0)).b;
	vec3 emi = vec3(em_r, em_g, em_b);

	// Crisp animated CRT scanlines
	float scan = 0.5 + 0.5 * sin((uv.y * scanline_density + TIME * scanline_scroll_speed) * 6.2831853);
	float scan_mult = mix(1.0 - scanline_strength, 1.0, step(0.35, scan));

	// Organic power-hum flicker (multi-frequency sine, never harsh strobe)
	float hum = 1.0 - flicker_strength * (
		0.5 + 0.35 * sin(TIME * 23.0) * sin(TIME * 7.3) + 0.15 * sin(TIME * 47.0)
	);

	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.5);

	ALBEDO = alb * scan_mult;
	ROUGHNESS = 0.20;
	METALLIC = 0.30;
	EMISSION = emi * emission_energy * scan_mult * hum * (1.0 + fresnel * fresnel_boost);
}
