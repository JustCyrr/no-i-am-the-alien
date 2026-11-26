shader_type canvas_item;

uniform float heal_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float speed_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float shield_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float shield_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5, 0.5);
	float dist = length(centered * vec2(1.15, 1.0));
	float edge = smoothstep(0.36, 0.72, dist);
	float t = TIME;

	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// 1. Medkit heal: soft emerald-green border pulse
	if (heal_intensity > 0.001) {
		float h_mask = edge * heal_intensity * 0.42;
		col += vec3(0.18, 0.95, 0.42) * h_mask;
		alpha = max(alpha, h_mask);
	}

	// 2. Speed boost: subtle cyan/yellow speed rim + faint corner wind streaks
	if (speed_intensity > 0.001) {
		float ang = atan(centered.y, centered.x);
		float streak = 0.5 + 0.5 * sin(ang * 24.0 + t * 14.0);
		float s_mask = edge * (0.20 + 0.14 * streak) * speed_intensity;
		vec3 speed_col = mix(vec3(0.15, 0.85, 1.0), vec3(1.0, 0.95, 0.35), streak * 0.45);
		col += speed_col * s_mask;
		alpha = max(alpha, s_mask);
	}

	// 3. Shield invincibility: soft blue energy barrier vignette
	if (shield_intensity > 0.001) {
		float pulse = 0.82 + 0.18 * sin(t * 7.0);
		float sh_mask = edge * (0.26 * pulse + 0.22 * shield_flash) * shield_intensity;
		vec3 shield_col = mix(vec3(0.15, 0.62, 1.0), vec3(0.75, 0.95, 1.0), shield_flash);
		col += shield_col * sh_mask;
		alpha = max(alpha, sh_mask);
	}

	COLOR = vec4(col, clamp(alpha, 0.0, 0.55));
}
