shader_type canvas_item;

// ============================================================================
// Full-Screen AA Retro PS2 / Ultrakill Dither & Palette Post-Process (Godot 4.x)
// Attach to a full-screen ColorRect inside a CanvasLayer above your 3D viewport!
// ============================================================================

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform float pixel_scale : hint_range(1.0, 4.0) = 1.0; // 1.0 = native res, 2.0 = crisp 2x retro pixels
uniform float color_steps : hint_range(8.0, 64.0) = 28.0; // Levels per RGB channel (24-32 = AA PS2 sweet spot)
uniform float dither_strength : hint_range(0.0, 1.5) = 0.75;
uniform float contrast : hint_range(0.85, 1.35) = 1.06;
uniform float saturation : hint_range(0.7, 1.4) = 1.08;
uniform float vignette_strength : hint_range(0.0, 0.65) = 0.22;
uniform float scanline_strength : hint_range(0.0, 0.45) = 0.0;
uniform vec3 shadow_tint : source_color = vec3(0.02, 0.03, 0.05);

float bayer4x4(vec2 px) {
	int x = int(mod(floor(px.x), 4.0));
	int y = int(mod(floor(px.y), 4.0));
	int idx = y * 4 + x;
	const float m[16] = float[16](
		 0.0,  8.0,  2.0, 10.0,
		12.0,  4.0, 14.0,  6.0,
		 3.0, 11.0,  1.0,  9.0,
		15.0,  7.0, 13.0,  5.0
	);
	return (m[idx] / 16.0) - 0.5;
}

void fragment() {
	vec2 res = vec2(textureSize(screen_texture, 0));
	vec2 virtual_res = max(floor(res / pixel_scale), vec2(64.0));
	vec2 px = floor(SCREEN_UV * virtual_res);
	vec2 sample_uv = (px + 0.5) / virtual_res;

	vec3 col = texture(screen_texture, sample_uv).rgb;

	// Subtle contrast + saturation punch
	col = (col - 0.5) * contrast + 0.5;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = max(col, vec3(0.0)) + shadow_tint * (1.0 - clamp(lum * 3.0, 0.0, 1.0));

	// Subtle retro edge vignette
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float vig = 1.0 - dot(centered, centered) * vignette_strength * 0.45;
	col *= clamp(vig, 0.0, 1.0);

	// Optional subtle retro horizontal scanlines (PS1 mode)
	if (scanline_strength > 0.001) {
		float scan = 0.5 + 0.5 * sin(px.y * 3.14159265);
		col *= mix(1.0, 1.0 - scanline_strength, scan);
	}

	// 4x4 Ordered Bayer dithering + color-depth banding
	float b = bayer4x4(px) * (dither_strength / color_steps);
	col = floor(clamp(col + b, 0.0, 1.0) * color_steps + 0.5) / color_steps;

	COLOR = vec4(col, 1.0);
}
