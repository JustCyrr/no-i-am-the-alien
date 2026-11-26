shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float invert_phase : hint_range(0.0, 1.0) = 0.0;
uniform float seed : hint_range(0.0, 100.0) = 1.0;

void fragment() {
	if (intensity <= 0.001) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		vec4 src = texture(screen_texture, SCREEN_UV);
		float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));
		float bw = step(0.36, luma);

		// Center-radiating anime speed lines & starburst
		vec2 centered = SCREEN_UV - vec2(0.5, 0.5);
		float dist = length(centered);
		float ang = atan(centered.y, centered.x);

		float ray_a = sin(ang * 34.0 + seed * 3.1);
		float ray_b = sin(ang * 58.0 - seed * 5.7);
		float ray_c = cos(ang * 19.0 + seed * 1.9);
		float rays = step(0.58, (ray_a * 0.5 + ray_b * 0.35 + ray_c * 0.35));

		float outer_mask = smoothstep(0.18, 0.42, dist);
		float center_star = step(dist, 0.11 + 0.06 * abs(sin(ang * 8.0 + seed)));

		float ink = bw;
		// Carve stark white/black manga speed-lines along the edges
		ink = mix(ink, 1.0 - ink, rays * outer_mask * 0.85);
		// Bright starburst flash right at the parry point
		ink = max(ink, center_star);

		// Negative inversion on the first impact flash frame
		float final_bw = mix(ink, 1.0 - ink, invert_phase);
		COLOR = vec4(vec3(final_bw), intensity);
	}
}
