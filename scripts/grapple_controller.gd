extends Node3D
class_name GrappleController

signal grapple_latched(is_enemy: bool)
signal grapple_released()

enum GrappleState {
	IDLE,
	EXTENDING,
	PULLING_SELF,
	PULLING_ENEMY,
	RETRACTING,
}

const TEX_HOOK_8DIR: String = "res://assets/hands/grapple/hook/hook_head_8dir.png"
const TEX_ROPE_TILE: String = "res://assets/hands/grapple/rope/rope_tile_h.png"
const FX_HIT_SPARKS: String = "res://assets/particles/hit_sparks/spritesheet.png"
const FX_ALIEN_BLOOD: String = "res://assets/particles/hit_sparks/alien_blood_sheet.png"

const SFX_FIRE: String = "res://assets/audio/grapple/grapple_fire.wav"
const SFX_CABLE_WHIP: String = "res://assets/audio/grapple/grapple_cable_whip.wav"
const SFX_HOOK_CLICK: String = "res://assets/audio/grapple/grapple_hook_click.wav"
const SFX_LATCH_HIT: String = "res://assets/audio/grapple/grapple_latch_hit.wav"
const SFX_LOCK_METALLIC: String = "res://assets/audio/grapple/grapple_lock_metallic.wav"
const SFX_PULL_WHOOSH: String = "res://assets/audio/grapple/grapple_pull_whoosh.wav"
const SFX_REEL_ZIP: String = "res://assets/audio/grapple/grapple_reel_zip.wav"
const SFX_RELEASE_SNAP: String = "res://assets/audio/grapple/grapple_release_snap.wav"
const SFX_RETRACT: String = "res://assets/audio/grapple/grapple_retract.wav"

@export_group("Grapple Range & Launch")
@export var max_range: float = 48.0
@export var hook_extend_speed: float = 82.0
@export var hook_retract_speed: float = 88.0
@export var enemy_aim_assist_radius: float = 0.85

@export_group("Spider-Man Pull & Swing Physics")
@export var min_pull_accel: float = 22.0
@export var max_pull_accel: float = 54.0
@export var accel_ramp_time: float = 1.25
@export var max_swing_speed: float = 30.0
@export var air_steer_accel: float = 24.0
@export var ground_lift_boost: float = 4.6
@export var reach_detach_distance: float = 2.1
@export var vault_pop_up: float = 6.2
@export var rope_slack_damping: float = 0.92
@export var bank_roll_max_deg: float = 8.5

@export_group("Enemy Yank")
@export var enemy_pull_start_speed: float = 16.0
@export var enemy_pull_max_speed: float = 30.0
@export var enemy_stop_distance: float = 2.3

@export_group("Visuals")
@export var rope_half_width: float = 0.036
@export var rope_segments: int = 12
@export var wrist_camera_offset: Vector3 = Vector3(-0.34, -0.25, -0.58)

var state: GrappleState = GrappleState.IDLE

var _player: CharacterBody3D
var _camera: Camera3D

var _hook_pos: Vector3 = Vector3.ZERO
var _target_pos: Vector3 = Vector3.ZERO
var _target_enemy: Node3D = null
var _target_is_enemy: bool = false
var _missed_shot: bool = false

var _hold_time: float = 0.0
var _whip_phase: float = 0.0
var _rope_uv_scroll: float = 0.0
var _bank_roll_deg: float = 0.0
var _current_speed_ratio: float = 0.0

var _hook_sprite: Sprite3D
var _rope_mesh_node: MeshInstance3D
var _rope_imm: ImmediateMesh
var _rope_mat: StandardMaterial3D

var _sfx_one_shot: AudioStreamPlayer
var _sfx_secondary: AudioStreamPlayer
var _sfx_reel_loop: AudioStreamPlayer
var _sfx_whoosh_loop: AudioStreamPlayer


func setup(player_ref: CharacterBody3D, camera_ref: Camera3D) -> void:
	_player = player_ref
	_camera = camera_ref


func _ready() -> void:
	# 3D World-space Grapple Hook Head (8-dir Doom sprite)
	_hook_sprite = Sprite3D.new()
	_hook_sprite.name = "GrappleHookHead"
	_hook_sprite.top_level = true
	_hook_sprite.visible = false
	_hook_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hook_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_hook_sprite.shaded = false
	_hook_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_hook_sprite.hframes = 8
	_hook_sprite.vframes = 1
	_hook_sprite.pixel_size = 0.016
	if ResourceLoader.exists(TEX_HOOK_8DIR):
		_hook_sprite.texture = load(TEX_HOOK_8DIR) as Texture2D
	add_child(_hook_sprite)

	# 3D Dynamic Tensioned Cable Ribbon (ImmediateMesh with tiled pixel rope)
	_rope_imm = ImmediateMesh.new()
	_rope_mat = StandardMaterial3D.new()
	_rope_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rope_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rope_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_rope_mat.albedo_color = Color(0.95, 0.95, 0.98, 1.0)
	if ResourceLoader.exists(TEX_ROPE_TILE):
		_rope_mat.albedo_texture = load(TEX_ROPE_TILE) as Texture2D

	_rope_mesh_node = MeshInstance3D.new()
	_rope_mesh_node.name = "GrappleCableMesh"
	_rope_mesh_node.top_level = true
	_rope_mesh_node.visible = false
	_rope_mesh_node.mesh = _rope_imm
	_rope_mesh_node.material_override = _rope_mat
	_rope_mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope_mesh_node)

	# Audio players
	_sfx_one_shot = _make_player("GrappleOneShot", -1.0)
	_sfx_secondary = _make_player("GrappleSecondary", -2.0)
	_sfx_reel_loop = _make_player("GrappleReelLoop", -5.0)
	_sfx_whoosh_loop = _make_player("GrappleWhooshLoop", -6.0)
	if ResourceLoader.exists(SFX_REEL_ZIP):
		_sfx_reel_loop.stream = load(SFX_REEL_ZIP) as AudioStream
	if ResourceLoader.exists(SFX_PULL_WHOOSH):
		_sfx_whoosh_loop.stream = load(SFX_PULL_WHOOSH) as AudioStream


func _make_player(node_name: String, vol_db: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.volume_db = vol_db
	p.bus = &"PlayerSFX"
	add_child(p)
	return p


func play_equip_click() -> void:
	_play_sound(_sfx_one_shot, SFX_HOOK_CLICK, randf_range(0.96, 1.06))
	_play_sound(_sfx_secondary, SFX_LOCK_METALLIC, randf_range(0.95, 1.05))


func is_active() -> bool:
	return state != GrappleState.IDLE


func is_hook_out() -> bool:
	return state != GrappleState.IDLE


func is_pulling_self() -> bool:
	return state == GrappleState.PULLING_SELF


func is_pulling_enemy() -> bool:
	return state == GrappleState.PULLING_ENEMY


func get_speed_ratio() -> float:
	return _current_speed_ratio


func get_bank_roll_deg() -> float:
	return _bank_roll_deg


func get_aim_target_kind() -> int:
	# 0 = out of range, 1 = world surface, 2 = enemy
	var res: Dictionary = _scan_aim_target()
	if res.is_empty():
		return 0
	return 2 if bool(res.get("is_enemy", false)) else 1


func fire() -> bool:
	if _player == null or _camera == null or state != GrappleState.IDLE:
		return false

	var scan: Dictionary = _scan_aim_target()
	_hook_pos = _get_wrist_world_pos()
	_hold_time = 0.0
	_whip_phase = 0.0

	if scan.is_empty():
		# Miss shot: extends briefly out into empty air, then snaps back
		_missed_shot = true
		_target_is_enemy = false
		_target_enemy = null
		_target_pos = _camera.global_position + (-_camera.global_transform.basis.z) * minf(max_range * 0.65, 18.0)
	else:
		_missed_shot = false
		_target_is_enemy = bool(scan.get("is_enemy", false))
		_target_enemy = scan.get("enemy", null) as Node3D
		_target_pos = scan.get("position", _hook_pos) as Vector3

	state = GrappleState.EXTENDING
	_hook_sprite.visible = true
	_rope_mesh_node.visible = true
	_play_sound(_sfx_one_shot, SFX_FIRE, randf_range(0.96, 1.06))
	_play_sound(_sfx_secondary, SFX_CABLE_WHIP, randf_range(0.95, 1.08))
	return true


func release(do_vault_jump: bool = false) -> void:
	if state == GrappleState.IDLE or state == GrappleState.RETRACTING:
		return

	if _target_enemy != null and is_instance_valid(_target_enemy):
		if _target_enemy.has_method("set_grappled"):
			_target_enemy.call("set_grappled", false)
	_target_enemy = null

	if do_vault_jump and state == GrappleState.PULLING_SELF and _player != null:
		_player.velocity.y = maxf(_player.velocity.y, vault_pop_up + 1.5)

	_stop_loops()
	_play_sound(_sfx_one_shot, SFX_RELEASE_SNAP, randf_range(0.95, 1.06))
	_play_sound(_sfx_secondary, SFX_RETRACT, randf_range(0.96, 1.05))
	state = GrappleState.RETRACTING
	grapple_released.emit()


func cancel_immediately() -> void:
	if _target_enemy != null and is_instance_valid(_target_enemy):
		if _target_enemy.has_method("set_grappled"):
			_target_enemy.call("set_grappled", false)
	_target_enemy = null
	state = GrappleState.IDLE
	_stop_loops()
	_bank_roll_deg = 0.0
	_current_speed_ratio = 0.0
	if _hook_sprite != null:
		_hook_sprite.visible = false
	if _rope_imm != null:
		_rope_imm.clear_surfaces()
	if _rope_mesh_node != null:
		_rope_mesh_node.visible = false


func step_grapple(delta: float, input_dir: Vector2, holding_fire: bool) -> void:
	if _player == null or _camera == null:
		return

	if state == GrappleState.IDLE:
		_bank_roll_deg = lerpf(_bank_roll_deg, 0.0, minf(1.0, delta * 9.0))
		_current_speed_ratio = lerpf(_current_speed_ratio, 0.0, minf(1.0, delta * 8.0))
		if _hook_sprite != null and _hook_sprite.visible:
			_hook_sprite.visible = false
		if _rope_mesh_node != null and _rope_mesh_node.visible:
			_rope_imm.clear_surfaces()
			_rope_mesh_node.visible = false
		return

	# Release if player lets go of R while extending or pulling
	if not holding_fire and state != GrappleState.RETRACTING:
		release(false)

	match state:
		GrappleState.EXTENDING:
			_step_extending(delta)
		GrappleState.PULLING_SELF:
			_step_pulling_self(delta, input_dir)
		GrappleState.PULLING_ENEMY:
			_step_pulling_enemy(delta)
		GrappleState.RETRACTING:
			_step_retracting(delta)

	_update_visuals(delta)


func _step_extending(delta: float) -> void:
	_whip_phase += delta * 28.0
	if _target_is_enemy and _target_enemy != null and is_instance_valid(_target_enemy):
		_target_pos = _target_enemy.global_position + Vector3(0.0, 1.05, 0.0)

	var to_target: Vector3 = _target_pos - _hook_pos
	var dist: float = to_target.length()
	var step_dist: float = hook_extend_speed * delta

	if dist <= step_dist + 0.15:
		_hook_pos = _target_pos
		if _missed_shot:
			state = GrappleState.RETRACTING
			_play_sound(_sfx_one_shot, SFX_RETRACT, 1.05)
			return

		if _target_is_enemy:
			if _target_enemy != null and is_instance_valid(_target_enemy):
				state = GrappleState.PULLING_ENEMY
				_hold_time = 0.0
				if _target_enemy.has_method("set_grappled"):
					_target_enemy.call("set_grappled", true)
				_on_latch_fx(true)
			else:
				release(false)
		else:
			state = GrappleState.PULLING_SELF
			_hold_time = 0.0
			# Crisp initial lift off the ground so Spider-Man swing begins immediately
			if _player.is_on_floor():
				_player.velocity.y = maxf(_player.velocity.y, ground_lift_boost)
			_on_latch_fx(false)
	else:
		_hook_pos += to_target.normalized() * step_dist


func _on_latch_fx(hit_enemy: bool) -> void:
	_play_sound(_sfx_one_shot, SFX_LATCH_HIT, randf_range(0.95, 1.06))
	_play_sound(_sfx_secondary, SFX_LOCK_METALLIC, randf_range(0.96, 1.05))
	var root_scene: Node = get_tree().current_scene
	if root_scene != null:
		var fx_sheet: String = FX_ALIEN_BLOOD if hit_enemy else FX_HIT_SPARKS
		SpriteFX3D.spawn(root_scene, _hook_pos, fx_sheet, 4, 1, 16.0, 0.03)
	grapple_latched.emit(hit_enemy)


func _step_pulling_self(delta: float, input_dir: Vector2) -> void:
	_hold_time += delta
	var player_center: Vector3 = _player.global_position + Vector3(0.0, 1.0, 0.0)
	var to_anchor: Vector3 = _hook_pos - player_center
	var dist: float = to_anchor.length()

	if dist <= reach_detach_distance:
		# Smooth upward vault pop upon reaching the grapple point
		_player.velocity.y = maxf(_player.velocity.y, vault_pop_up)
		release(false)
		return

	var pull_dir: Vector3 = to_anchor / maxf(dist, 0.001)

	# 1. Accelerating reel force as player keeps holding R
	var ramp: float = clampf(_hold_time / maxf(accel_ramp_time, 0.05), 0.0, 1.0)
	var current_accel: float = lerpf(min_pull_accel, max_pull_accel, ramp * ramp)
	_player.velocity += pull_dir * current_accel * delta

	# Gentle anti-gravity assist when anchor is above or level so you arc gracefully
	if pull_dir.y > -0.25:
		_player.velocity.y += 4.2 * delta

	# 2. Spider-Man pendulum tension constraint (converts falling into forward/curved swing!)
	var radial_vel: float = _player.velocity.dot(pull_dir)
	if radial_vel < 0.0:
		_player.velocity -= pull_dir * radial_vel * rope_slack_damping

	# 3. Responsive midair directional steering (A/D lateral swing carve + W/S pitch lean)
	var cam_basis: Basis = _camera.global_transform.basis
	var cam_right: Vector3 = cam_basis.x
	cam_right.y = 0.0
	if cam_right.length_squared() > 0.001:
		cam_right = cam_right.normalized()

	var cam_fwd_flat: Vector3 = -cam_basis.z
	cam_fwd_flat.y = 0.0
	if cam_fwd_flat.length_squared() > 0.001:
		cam_fwd_flat = cam_fwd_flat.normalized()

	var steer_vec: Vector3 = cam_right * input_dir.x + cam_fwd_flat * (-input_dir.y * 0.55)
	if steer_vec.length_squared() > 0.001:
		_player.velocity += steer_vec.normalized() * air_steer_accel * delta

	# Soft cap max speed so flight stays exhilarating and controllable
	var spd: float = _player.velocity.length()
	if spd > max_swing_speed:
		_player.velocity = _player.velocity.normalized() * max_swing_speed
		spd = max_swing_speed

	_current_speed_ratio = clampf(spd / maxf(max_swing_speed, 1.0), 0.0, 1.0)

	# Dynamic Spider-Man camera banking into the lateral carve
	var lateral_speed: float = _player.velocity.dot(cam_right)
	var target_bank: float = clampf((-lateral_speed / 12.0) * bank_roll_max_deg - input_dir.x * 2.5, -bank_roll_max_deg, bank_roll_max_deg)
	_bank_roll_deg = lerpf(_bank_roll_deg, target_bank, minf(1.0, delta * 8.0))

	# Dynamic speed-pitched reel & wind whoosh loops
	_update_reel_loops(_current_speed_ratio)


func _step_pulling_enemy(delta: float) -> void:
	if _target_enemy == null or not is_instance_valid(_target_enemy):
		release(false)
		return

	_hold_time += delta
	var target_in_front: Vector3 = _player.global_position + (-_player.global_transform.basis.z) * 1.7 + Vector3(0.0, 0.15, 0.0)
	var to_player: Vector3 = target_in_front - _target_enemy.global_position
	var flat_dist: float = Vector2(to_player.x, to_player.z).length()

	_hook_pos = _target_enemy.global_position + Vector3(0.0, 1.05, 0.0)

	if flat_dist <= enemy_stop_distance:
		if _target_enemy.has_method("apply_grapple_pull"):
			_target_enemy.call("apply_grapple_pull", Vector3.ZERO)
		release(false)
		return

	var ramp: float = clampf(_hold_time / 0.65, 0.0, 1.0)
	var yank_speed: float = lerpf(enemy_pull_start_speed, enemy_pull_max_speed, ramp)
	var yank_dir: Vector3 = to_player.normalized()
	var pull_vel: Vector3 = yank_dir * yank_speed
	pull_vel.y = maxf(pull_vel.y, 2.2) # Slight hop so enemy clears low lips/ramps

	if _target_enemy.has_method("apply_grapple_pull"):
		_target_enemy.call("apply_grapple_pull", pull_vel)

	_current_speed_ratio = clampf(0.4 + ramp * 0.5, 0.0, 1.0)
	_update_reel_loops(_current_speed_ratio)


func _step_retracting(delta: float) -> void:
	var wrist_pos: Vector3 = _get_wrist_world_pos()
	var to_wrist: Vector3 = wrist_pos - _hook_pos
	var dist: float = to_wrist.length()
	var step_dist: float = hook_retract_speed * delta

	_bank_roll_deg = lerpf(_bank_roll_deg, 0.0, minf(1.0, delta * 10.0))
	_current_speed_ratio = lerpf(_current_speed_ratio, 0.0, minf(1.0, delta * 10.0))

	if dist <= step_dist + 0.2:
		state = GrappleState.IDLE
		_hook_sprite.visible = false
		_rope_imm.clear_surfaces()
		_rope_mesh_node.visible = false
		_play_sound(_sfx_one_shot, SFX_HOOK_CLICK, 1.08)
	else:
		_hook_pos += to_wrist.normalized() * step_dist


func _update_reel_loops(speed_ratio: float) -> void:
	if _sfx_reel_loop != null and _sfx_reel_loop.stream != null:
		_sfx_reel_loop.pitch_scale = lerpf(0.92, 1.38, speed_ratio)
		if not _sfx_reel_loop.playing:
			_sfx_reel_loop.play()
	if _sfx_whoosh_loop != null and _sfx_whoosh_loop.stream != null:
		_sfx_whoosh_loop.pitch_scale = lerpf(0.88, 1.28, speed_ratio)
		_sfx_whoosh_loop.volume_db = lerpf(-12.0, -3.0, speed_ratio)
		if not _sfx_whoosh_loop.playing:
			_sfx_whoosh_loop.play()


func _stop_loops() -> void:
	if _sfx_reel_loop != null and _sfx_reel_loop.playing:
		_sfx_reel_loop.stop()
	if _sfx_whoosh_loop != null and _sfx_whoosh_loop.playing:
		_sfx_whoosh_loop.stop()


func _scan_aim_target() -> Dictionary:
	if _camera == null or _player == null:
		return {}

	var origin: Vector3 = _camera.global_position
	var fwd: Vector3 = -_camera.global_transform.basis.z
	var end_pos: Vector3 = origin + fwd * max_range

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end_pos, 18) # Enemies (2) + World (16)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = space_state.intersect_ray(query)

	var best_enemy: Node3D = null
	var best_enemy_pos: Vector3 = Vector3.ZERO
	var max_enemy_dist: float = max_range

	if not hit.is_empty():
		var col_obj: Object = hit["collider"] as Object
		var hit_pos: Vector3 = hit["position"] as Vector3
		if col_obj != null and col_obj is Node3D and (col_obj as Node3D).is_in_group("enemies"):
			return {"is_enemy": true, "enemy": col_obj, "position": hit_pos}
		max_enemy_dist = origin.distance_to(hit_pos)

	# Slight aim-assist cone for moving enemies so hooking aliens feels snappy
	var best_perp: float = enemy_aim_assist_radius
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node3D):
			continue
		var enemy_3d: Node3D = node as Node3D
		var center: Vector3 = enemy_3d.global_position + Vector3(0.0, 1.05, 0.0)
		var rel: Vector3 = center - origin
		var along: float = rel.dot(fwd)
		if along <= 1.2 or along >= max_enemy_dist:
			continue
		var perp: float = (rel - fwd * along).length()
		if perp < best_perp:
			best_perp = perp
			best_enemy = enemy_3d
			best_enemy_pos = center

	if best_enemy != null:
		return {"is_enemy": true, "enemy": best_enemy, "position": best_enemy_pos}

	if not hit.is_empty():
		return {"is_enemy": false, "enemy": null, "position": hit["position"] as Vector3}

	return {}


func _get_wrist_world_pos() -> Vector3:
	if _camera == null:
		return global_position
	return _camera.global_transform * wrist_camera_offset


func _update_visuals(delta: float) -> void:
	if _hook_sprite == null or _rope_mesh_node == null or _camera == null:
		return

	if state == GrappleState.IDLE:
		_hook_sprite.visible = false
		_rope_imm.clear_surfaces()
		_rope_mesh_node.visible = false
		return

	var start_pos: Vector3 = _get_wrist_world_pos()
	var end_pos: Vector3 = _hook_pos

	_hook_sprite.global_position = end_pos
	var hook_dir: Vector3 = (end_pos - start_pos)
	if hook_dir.length_squared() > 0.001:
		var fwd_flat: Vector3 = Vector3(hook_dir.x, 0.0, hook_dir.z)
		if fwd_flat.length_squared() > 0.0001:
			fwd_flat = fwd_flat.normalized()
			var to_cam: Vector3 = _camera.global_position - end_pos
			to_cam.y = 0.0
			if to_cam.length_squared() > 0.0001:
				var ang: float = atan2(fwd_flat.cross(to_cam.normalized()).y, fwd_flat.dot(to_cam.normalized()))
				_hook_sprite.frame = int(round(fposmod(rad_to_deg(ang), 360.0) / 45.0)) % 8

	# Scroll braided steel rope texture toward wrist while reeling
	if state == GrappleState.PULLING_SELF or state == GrappleState.PULLING_ENEMY:
		_rope_uv_scroll -= delta * (4.0 + _current_speed_ratio * 9.0)
	elif state == GrappleState.EXTENDING:
		_rope_uv_scroll += delta * 12.0

	# Rebuild dynamic camera-facing 3D ribbon mesh
	var rope_vec: Vector3 = end_pos - start_pos
	var rope_len: float = rope_vec.length()
	if rope_len < 0.05:
		_rope_mesh_node.visible = false
		return

	_rope_mesh_node.visible = true
	var rope_dir: Vector3 = rope_vec / rope_len
	var cam_pos: Vector3 = _camera.global_position
	var cam_up: Vector3 = _camera.global_transform.basis.y
	var cam_right: Vector3 = _camera.global_transform.basis.x

	_rope_imm.clear_surfaces()
	_rope_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var segs: int = maxi(2, rope_segments)
	for i: int in range(segs + 1):
		var t: float = float(i) / float(segs)
		var pt: Vector3 = start_pos.lerp(end_pos, t)

		# Dynamic whip wave while shooting out; razor taut while pulling
		if state == GrappleState.EXTENDING:
			var env: float = sin(t * PI)
			var wave: float = sin(t * 14.0 - _whip_phase) * 0.12 * env
			pt += cam_up * wave + cam_right * (cos(t * 10.0 - _whip_phase) * 0.06 * env)
		elif state == GrappleState.RETRACTING:
			var sag: float = sin(t * PI) * 0.09
			pt -= Vector3.UP * sag

		var to_eye: Vector3 = (cam_pos - pt).normalized()
		var side: Vector3 = rope_dir.cross(to_eye)
		if side.length_squared() < 0.0001:
			side = cam_right
		else:
			side = side.normalized()

		var u_coord: float = t * rope_len * 2.5 + _rope_uv_scroll
		_rope_imm.surface_set_uv(Vector2(u_coord, 0.0))
		_rope_imm.surface_add_vertex(pt - side * rope_half_width)
		_rope_imm.surface_set_uv(Vector2(u_coord, 1.0))
		_rope_imm.surface_add_vertex(pt + side * rope_half_width)

	_rope_imm.surface_end()


func _play_sound(player_node: AudioStreamPlayer, path: String, pitch: float = 1.0) -> void:
	if player_node == null or path.is_empty() or not ResourceLoader.exists(path):
		return
	player_node.stream = load(path) as AudioStream
	player_node.pitch_scale = pitch
	player_node.play()
