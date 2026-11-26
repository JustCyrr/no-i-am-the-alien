shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// ============================================================================
// AA Retro PS2 / Ultrakill-Style PBR Surface Shader (Godot 4.x)
// Designed for environments_v2 GLB assets (Albedo + OpenGL Normal + ORM + Emissive)
// ============================================================================

group_uniforms PBR_Textures;
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_nearest, repeat_enable;
uniform sampler2D orm_tex : filter_nearest, repeat_enable; // R=AO, G=Roughness, B=Metallic
uniform sampler2D emissive_tex : source_color, filter_nearest, repeat_enable;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

group_uniforms Material_Tuning;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float normal_depth : hint_range(0.0, 2.5) = 1.15;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_mult : hint_range(0.1, 2.0) = 1.0;
uniform float metallic_mult : hint_range(0.0, 2.0) = 1.0;
uniform float emission_energy : hint_range(0.0, 8.0) = 2.0;
uniform float emission_pulse_amp : hint_range(0.0, 0.5) = 0.06;
uniform float emission_pulse_speed : hint_range(0.0, 8.0) = 2.0;

group_uniforms Ground_Contact_Weathering;
uniform float ground_y = 0.0;
uniform float ground_ao_height : hint_range(0.0, 2.0) = 0.45;
uniform float ground_ao_strength : hint_range(0.0, 0.85) = 0.35;
uniform vec3 ground_grime_tint : source_color = vec3(0.08, 0.10, 0.12);

group_uniforms Retro_Lighting_And_Dither;
uniform float light_steps : hint_range(3.0, 24.0) = 9.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.45;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform vec3 rim_color : source_color = vec3(0.55, 0.72, 0.82);

group_uniforms Optional_PS2_Vertex_Snap;
uniform bool vertex_snap_enable = false;
uniform vec2 snap_resolution = vec2(640.0, 360.0);

varying vec3 v_world_pos;

float bayer4x4(vec2 frag_xy) {
	int x = int(mod(floor(frag_xy.x), 4.0));
	int y = int(mod(floor(frag_xy.y), 4.0));
	int idx = y * 4 + x;
	const float m[16] = float[16](
		 0.0,  8.0,  2.0, 10.0,
		12.0,  4.0, 14.0,  6.0,
		 3.0, 11.0,  1.0,  9.0,
		15.0,  7.0, 13.0,  5.0
	);
	return (m[idx] / 16.0) - 0.5;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (vertex_snap_enable) {
		vec2 snapped = floor((clip.xy / clip.w) * snap_resolution * 0.5 + 0.5) / (snap_resolution * 0.5);
		clip.xy = snapped * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec2 uv = UV * uv_scale + uv_offset;
	vec3 alb = texture(albedo_tex, uv).rgb * albedo_tint.rgb;
	vec3 orm = texture(orm_tex, uv).rgb;
	vec3 emi = texture(emissive_tex, uv).rgb;

	// Subtle world-height floor contact grounding (eliminates floating-box feel)
	float h_factor = clamp((v_world_pos.y - ground_y) / max(ground_ao_height, 0.001), 0.0, 1.0);
	float grime_mix = (1.0 - h_factor) * (1.0 - h_factor) * ground_ao_strength;
	alb = mix(alb, alb * ground_grime_tint * 2.2, grime_mix);

	ALBEDO = alb;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;

	AO = mix(1.0, orm.r * (1.0 - grime_mix * 0.5), ao_strength);
	ROUGHNESS = clamp(orm.g * roughness_mult, 0.08, 1.0);
	METALLIC = clamp(orm.b * metallic_mult, 0.0, 1.0);

	float pulse = 1.0 + sin(TIME * emission_pulse_speed) * emission_pulse_amp;
	EMISSION = emi * emission_energy * pulse;
}

void light() {
	float b = bayer4x4(FRAGCOORD.xy) * dither_strength;
	float ndotl = max(dot(NORMAL, LIGHT), 0.0);
	float atten_light = ndotl * ATTENUATION;

	// Retro 4x4 Bayer-stepped diffuse shading (keeps AA PBR richness with crisp pixel-art banding)
	float stepped = clamp(floor(atten_light * light_steps + b + 0.5) / light_steps, 0.0, 1.0);
	DIFFUSE_LIGHT += stepped * ALBEDO * LIGHT_COLOR / PI;

	// Crisp metallic-aware retro Blinn-Phong specular glint
	vec3 half_vec = normalize(LIGHT + VIEW);
	float ndoth = max(dot(NORMAL, half_vec), 0.0);
	float shininess = mix(96.0, 6.0, ROUGHNESS);
	float spec_raw = pow(ndoth, shininess) * (1.0 - ROUGHNESS * 0.75) * mix(0.25, 1.15, METALLIC);
	float spec_stepped = floor(spec_raw * 6.0 + b * 0.6 + 0.5) / 6.0;
	vec3 spec_tint = mix(vec3(1.0), ALBEDO, METALLIC);
	SPECULAR_LIGHT += spec_stepped * spec_tint * LIGHT_COLOR * ATTENUATION * 0.65;

	// Subtle silhouette rim light for dark corridors/night exteriors
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	DIFFUSE_LIGHT += fresnel * rim_strength * rim_color * LIGHT_COLOR * ATTENUATION * 0.25;
}
