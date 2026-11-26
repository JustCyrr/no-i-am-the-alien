extends Node3D
class_name CombatFX3D

# Lightweight single-draw-call 3D combat juice FX:
# - Ballistic bullet / shotgun tracers
# - Dynamic muzzle & impact OmniLight3D flashes
# - Directional MultiMesh blood sprays, sparks, and chunky pixel gibs on kill

static var _unit_box: BoxMesh
static var _tracer_box: BoxMesh


static func _get_unit_box() -> BoxMesh:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	return _unit_box


static func _get_tracer_box() -> BoxMesh:
	if _tracer_box == null:
		_tracer_box = BoxMesh.new()
		_tracer_box.size = Vector3(1.0, 1.0, 1.0)
	return _tracer_box


static func spawn_tracer(
	parent: Node,
	start_pos: Vector3,
	end_pos: Vector3,
	col: Color = Color(1.0, 0.88, 0.45, 0.92),
	thickness: float = 0.024,
	duration: float = 0.075
) -> void:
	if parent == null:
		return
	var delta_v: Vector3 = end_pos - start_pos
	var dist: float = delta_v.length()
	if dist < 0.35:
		return

	var host: CombatFX3D = CombatFX3D.new()
	host._mode = 0
	host._lifetime = maxf(duration, 0.02)
	host._max_lifetime = host._lifetime

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _get_tracer_box()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = Color(col.r, col.g, col.b, 1.0)
	mat.emission_energy_multiplier = 2.6
	mat.no_depth_test = false
	mi.material_override = mat
	host._tracer_mesh = mi
	host._tracer_mat = mat
	host._tracer_base_alpha = col.a
	host._tracer_thickness = thickness
	host._tracer_length = minf(dist, 45.0)
	host.add_child(mi)

	parent.add_child(host)
	var mid: Vector3 = start_pos.lerp(end_pos, 0.5)
	host.global_position = mid
	var up_ref: Vector3 = Vector3.UP if absf(delta_v.normalized().y) < 0.96 else Vector3.RIGHT
	host.look_at(end_pos, up_ref)
	mi.scale = Vector3(thickness, thickness, dist)


static func spawn_flash_light(
	parent: Node,
	world_pos: Vector3,
	col: Color = Color(1.0, 0.72, 0.32, 1.0),
	energy: float = 4.0,
	light_range: float = 10.0,
	duration: float = 0.065
) -> void:
	if parent == null:
		return
	var host: CombatFX3D = CombatFX3D.new()
	host._mode = 1
	host._lifetime = maxf(duration, 0.02)
	host._max_lifetime = host._lifetime
	host._light_base_energy = energy

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = col
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	host._flash_light = light
	host.add_child(light)

	parent.add_child(host)
	host.global_position = world_pos


static func spawn_blood_burst(
	parent: Node,
	origin: Vector3,
	push_dir: Vector3,
	count: int = 8,
	speed: float = 7.5,
	is_kill_gibs: bool = false
) -> void:
	if parent == null or count <= 0:
		return
	var host: CombatFX3D = CombatFX3D.new()
	host._mode = 2
	host._lifetime = 0.62 if is_kill_gibs else 0.36
	host._max_lifetime = host._lifetime
	host._gravity = 16.5 if is_kill_gibs else 14.0
	host._floor_y = maxf(0.05, origin.y - 1.15)

	var dir: Vector3 = push_dir
	if dir.length_squared() < 0.001:
		dir = Vector3.UP
	else:
		dir = dir.normalized()

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _get_unit_box()
	mm.instance_count = count

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.65, 0.24, 1.0)
	mat.emission_energy_multiplier = 0.55
	mmi.material_override = mat
	mmi.multimesh = mm

	host._mmi = mmi
	host._mm = mm
	host._positions.resize(count)
	host._velocities.resize(count)
	host._rotations.resize(count)
	host._ang_vels.resize(count)
	host._scales.resize(count)

	for i: int in range(count):
		var spread: Vector3 = Vector3(
			randf_range(-0.65, 0.65),
			randf_range(-0.20, 0.78),
			randf_range(-0.65, 0.65)
		)
		var v_dir: Vector3 = (dir * (0.95 if not is_kill_gibs else 0.75) + spread).normalized()
		var spd: float = speed * randf_range(0.55, 1.35)
		host._positions[i] = Vector3(
			randf_range(-0.18, 0.18),
			randf_range(-0.15, 0.25),
			randf_range(-0.18, 0.18)
		)
		host._velocities[i] = v_dir * spd + Vector3(0.0, randf_range(1.2, 3.6 if is_kill_gibs else 2.2), 0.0)
		host._rotations[i] = Vector3(randf_range(0.0, TAU), randf_range(0.0, TAU), randf_range(0.0, TAU))
		host._ang_vels[i] = Vector3(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))

		var sz: float = randf_range(0.09, 0.18) if is_kill_gibs else randf_range(0.045, 0.095)
		var chunk_scale: Vector3 = Vector3(sz, sz * randf_range(0.75, 1.35), sz * randf_range(0.75, 1.35))
		host._scales[i] = chunk_scale

		# Alien gore palette: toxic neon emerald blood + dark viscera + bone/crimson chunks on kill
		var pick: float = randf()
		var c: Color
		if is_kill_gibs and pick < 0.28:
			c = Color(0.86, 0.16, 0.16, 1.0) # Dark arterial crimson chunk
		elif is_kill_gibs and pick < 0.45:
			c = Color(0.16, 0.26, 0.18, 1.0) # Dark alien flesh gib
		elif pick < 0.78:
			c = Color(0.24, 0.92, 0.36, 1.0) # Acid alien blood droplet
		else:
			c = Color(0.58, 1.0, 0.32, 1.0) # Bright plasma-ichor highlight
		mm.set_instance_color(i, c)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(chunk_scale), host._positions[i]))

	host.add_child(mmi)
	parent.add_child(host)
	host.global_position = origin


static func spawn_sparks_burst(
	parent: Node,
	origin: Vector3,
	out_dir: Vector3,
	col: Color = Color(1.0, 0.85, 0.35, 1.0),
	count: int = 8
) -> void:
	if parent == null or count <= 0:
		return
	var host: CombatFX3D = CombatFX3D.new()
	host._mode = 2
	host._lifetime = 0.24
	host._max_lifetime = host._lifetime
	host._gravity = 11.0
	host._floor_y = origin.y - 2.0

	var dir: Vector3 = out_dir.normalized() if out_dir.length_squared() > 0.001 else Vector3.UP

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _get_unit_box()
	mm.instance_count = count

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(col.r, col.g, col.b, 1.0)
	mat.emission_energy_multiplier = 2.4
	mmi.material_override = mat
	mmi.multimesh = mm

	host._mmi = mmi
	host._mm = mm
	host._positions.resize(count)
	host._velocities.resize(count)
	host._rotations.resize(count)
	host._ang_vels.resize(count)
	host._scales.resize(count)

	for i: int in range(count):
		var spread: Vector3 = Vector3(randf_range(-0.9, 0.9), randf_range(-0.4, 0.9), randf_range(-0.9, 0.9))
		var v_dir: Vector3 = (dir * 0.65 + spread).normalized()
		host._positions[i] = Vector3.ZERO
		host._velocities[i] = v_dir * randf_range(5.5, 12.5)
		host._rotations[i] = Vector3(randf_range(0.0, TAU), randf_range(0.0, TAU), randf_range(0.0, TAU))
		host._ang_vels[i] = Vector3(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		var sc: Vector3 = Vector3(0.032, 0.032, randf_range(0.11, 0.22))
		host._scales[i] = sc
		mm.set_instance_color(i, col)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(sc), Vector3.ZERO))

	host.add_child(mmi)
	parent.add_child(host)
	host.global_position = origin


var _mode: int = 0
var _lifetime: float = 0.1
var _max_lifetime: float = 0.1

var _tracer_mesh: MeshInstance3D
var _tracer_mat: StandardMaterial3D
var _tracer_base_alpha: float = 1.0
var _tracer_thickness: float = 0.02
var _tracer_length: float = 1.0

var _flash_light: OmniLight3D
var _light_base_energy: float = 3.0

var _mmi: MultiMeshInstance3D
var _mm: MultiMesh
var _gravity: float = 14.0
var _floor_y: float = 0.05
var _positions: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _rotations: PackedVector3Array = PackedVector3Array()
var _ang_vels: PackedVector3Array = PackedVector3Array()
var _scales: PackedVector3Array = PackedVector3Array()


func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return

	var ratio: float = clampf(_lifetime / maxf(_max_lifetime, 0.001), 0.0, 1.0)

	if _mode == 0:
		if _tracer_mat != null:
			var c: Color = _tracer_mat.albedo_color
			c.a = _tracer_base_alpha * ratio * ratio
			_tracer_mat.albedo_color = c
		if _tracer_mesh != null:
			var w: float = _tracer_thickness * maxf(0.25, ratio)
			_tracer_mesh.scale = Vector3(w, w, _tracer_mesh.scale.z)
	elif _mode == 1:
		if _flash_light != null:
			_flash_light.light_energy = _light_base_energy * ratio * ratio
	elif _mode == 2 and _mm != null:
		var count: int = _positions.size()
		var base_y: float = global_position.y
		var shrink: float = 1.0 if ratio > 0.35 else clampf(ratio / 0.35, 0.05, 1.0)
		for i: int in range(count):
			var vel: Vector3 = _velocities[i]
			vel.y -= _gravity * delta
			var pos: Vector3 = _positions[i] + vel * delta
			if base_y + pos.y < _floor_y:
				pos.y = _floor_y - base_y
				vel.y = absf(vel.y) * 0.28
				vel.x *= 0.62
				vel.z *= 0.62
			_positions[i] = pos
			_velocities[i] = vel
			var rot: Vector3 = _rotations[i] + _ang_vels[i] * delta
			_rotations[i] = rot
			var b: Basis = Basis.from_euler(rot).scaled(_scales[i] * shrink)
			_mm.set_instance_transform(i, Transform3D(b, pos))
