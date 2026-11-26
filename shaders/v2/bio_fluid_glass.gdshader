shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// ============================================================================
// Alien Bio-Fluid & Stasis Glass Shader (Godot 4.x)
// Ideal for stasis_tank__hosp_bio_glass and wall_bio_segment__hosp_bio_glass
// Reveals floating inner specimen silhouette with animated pixelated bubbles!
// ============================================================================

uniform sampler2D bio_albedo_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D bio_normal_tex : hint_normal, filter_nearest, repeat_enable;

uniform vec3 fluid_core_color : source_color = vec3(0.10, 0.92, 0.58);
uniform vec3 fluid_rim_color : source_color = vec3(0.45, 1.0, 0.92);
uniform float glass_opacity : hint_range(0.2, 1.0) = 0.72;
uniform float fresnel_power : hint_range(1.0, 6.0) = 2.4;
uniform float fresnel_strength : hint_range(0.0, 2.5) = 1.25;
uniform float bubble_rise_speed : hint_range(0.0, 2.0) = 0.22;
uniform float wave_wobble : hint_range(0.0, 0.06) = 0.014;
uniform float pixel_grid : hint_range(32.0, 256.0) = 128.0;
uniform float emission_energy : hint_range(0.2, 6.0) = 1.85;
uniform float pulse_speed : hint_range(0.0, 6.0) = 1.8;

void fragment() {
	// Crisp pixel-snapped rising bubble UVs + subtle horizontal fluid sway
	vec2 base_uv = UV;
	float sway = sin(base_uv.y * 12.0 + TIME * 2.2) * wave_wobble;
	vec2 anim_uv = vec2(base_uv.x + sway, base_uv.y - TIME * bubble_rise_speed);
	vec2 px_uv = floor(anim_uv * pixel_grid) / pixel_grid;

	// Second counter-drifting parallax bubble layer for volumetric depth
	vec2 px_uv2 = floor(vec2(base_uv.x * 1.5 - sway * 0.7, base_uv.y * 1.5 - TIME * bubble_rise_speed * 1.55) * pixel_grid) / pixel_grid;

	vec3 tex1 = texture(bio_albedo_tex, px_uv).rgb;
	vec3 tex2 = texture(bio_albedo_tex, px_uv2).rgb;
	float bubble_spark = smoothstep(0.68, 0.92, max(tex1.g, tex2.g * 0.9));

	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), fresnel_power);
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed + base_uv.y * 4.0);

	vec3 fluid = mix(tex1 * fluid_core_color * 1.15, fluid_rim_color, clamp(fresnel * 0.75 + bubble_spark * 0.55, 0.0, 1.0));

	ALBEDO = fluid;
	NORMAL_MAP = texture(bio_normal_tex, px_uv).rgb;
	NORMAL_MAP_DEPTH = 0.85;
	ROUGHNESS = mix(0.24, 0.08, fresnel);
	METALLIC = 0.10;
	ALPHA = clamp(glass_opacity + fresnel * 0.25 + bubble_spark * 0.20, 0.0, 1.0);
	EMISSION = (fluid * 0.85 + fluid_rim_color * fresnel * fresnel_strength) * emission_energy * pulse;
}
