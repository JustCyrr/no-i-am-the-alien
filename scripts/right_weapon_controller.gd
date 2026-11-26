extends Node
class_name RightWeaponController

signal weapon_changed(weapon_id: int)
signal fired_recoil(pitch_kick_deg: float, roll_kick_deg: float)
signal weapon_toast(msg: String)

enum RightWeapon {
	FIST = 0,
	PISTOL = 1,
	SHOTGUN = 2,
}

const PISTOL_IDLE_PATH: String = "res://assets/hands/pistol/idle.png"
const PISTOL_FRAMES_DIR: String = "res://assets/hands/pistol/fire_frames"
const SHOTGUN_IDLE_PATH: String = "res://assets/hands/shotgun/idle.png"
const SHOTGUN_FRAMES_DIR: String = "res://assets/hands/shotgun/fire_frames"

const HUD_PISTOL_ACTIVE: String = "res://assets/ui/hud_weapons/pistol/pistol_slot_sheet.png"
const HUD_PISTOL_INACTIVE: String = "res://assets/ui/hud_weapons/pistol/pistol_slot_inactive.png"
const HUD_SHOTGUN_ACTIVE: String = "res://assets/ui/hud_weapons/shotgun/shotgun_slot_sheet.png"
const HUD_SHOTGUN_INACTIVE: String = "res://assets/ui/hud_weapons/shotgun/shotgun_slot_inactive.png"

const FX_HIT_SPARKS: String = "res://assets/particles/hit_sparks/spritesheet.png"
const FX_SMOKE_PUFF: String = "res://assets/particles/smoke_puff/spritesheet.png"

const SFX_PISTOL_SHOT: String = "res://assets/audio/weapons/player_pistol_shot.wav"
const SFX_SHOTGUN_BOOM: String = "res://assets/audio/weapons/player_shotgun_boom.wav"
const SFX_DRY_FIRE: String = "res://assets/audio/weapons/dry_fire_click.wav"
const SFX_EQUIP_RACK: String = "res://assets/audio/weapons/weapon_equip_rack.wav"
const SFX_BULLET_IMPACT: String = "res://assets/audio/bullet_impact.wav"

const PISTOL_MAX_AMMO: int = 7
const SHOTGUN_MAX_AMMO: int = 2

@export_group("Weapon Balance")
@export var pistol_damage: float = 22.0
@export var pistol_fire_cooldown: float = 0.28
@export var pistol_range: float = 48.0

@export var shotgun_pellets: int = 7
@export var shotgun_spread_deg: float = 3.2
@export var shotgun_close_dist: float = 5.5
@export var shotgun_far_dist: float = 13.5
@export var shotgun_pellet_close_damage: float = 11.0
@export var shotgun_pellet_far_damage: float = 3.4
@export var shotgun_fire_cooldown: float = 0.52
@export var shotgun_range: float = 36.0

var current_weapon: RightWeapon = RightWeapon.FIST
var has_pistol: bool = false
var has_shotgun: bool = false
var pistol_ammo: int = 0
var shotgun_ammo: int = 0

var _player: CharacterBody3D
var _camera: Camera3D
var _right_fist_anchor: Control
var _right_fist_arm: Control
var _pistol_anchor: Control
var _pistol_arm: TextureRect
var _shotgun_anchor: Control
var _shotgun_arm: TextureRect

var _hud_container: Control
var _hud_pistol_slot: TextureRect
var _hud_pistol_ammo: Label
var _hud_shotgun_slot: TextureRect
var _hud_shotgun_ammo: Label

var _pistol_idle_tex: Texture2D
var _pistol_fire_frames: Array[Texture2D] = []
var _shotgun_idle_tex: Texture2D
var _shotgun_fire_frames: Array[Texture2D] = []

var _hud_pistol_active_frames: Array[AtlasTexture] = []
var _hud_pistol_inactive_tex: Texture2D
var _hud_shotgun_active_frames: Array[AtlasTexture] = []
var _hud_shotgun_inactive_tex: Texture2D

var _sfx_primary: AudioStreamPlayer
var _sfx_layer: AudioStreamPlayer

var _is_swapping: bool = false
var _is_firing_anim: bool = false
var _is_discarding: bool = false
var _fire_cooldown_timer: float = 0.0
var _hud_anim_timer: float = 0.0
var _weapon_bob_time: float = 0.0
var _weapon_recoil: Vector2 = Vector2.ZERO
var _weapon_rot_recoil: float = 0.0
var _weapon_scale_recoil: float = 0.0
var _swap_tween: Tween
var _fire_tween: Tween
var _pump_tween: Tween


func setup(
	player_ref: CharacterBody3D,
	camera_ref: Camera3D,
	right_fist_anchor_ref: Control,
	right_fist_arm_ref: Control,
	pistol_anchor_ref: Control,
	pistol_arm_ref: TextureRect,
	shotgun_anchor_ref: Control,
	shotgun_arm_ref: TextureRect,
	hud_container_ref: Control,
	hud_pistol_slot_ref: TextureRect,
	hud_pistol_ammo_ref: Label,
	hud_shotgun_slot_ref: TextureRect,
	hud_shotgun_ammo_ref: Label
) -> void:
	_player = player_ref
	_camera = camera_ref
	_right_fist_anchor = right_fist_anchor_ref
	_right_fist_arm = right_fist_arm_ref
	_pistol_anchor = pistol_anchor_ref
	_pistol_arm = pistol_arm_ref
	_shotgun_anchor = shotgun_anchor_ref
	_shotgun_arm = shotgun_arm_ref
	_hud_container = hud_container_ref
	_hud_pistol_slot = hud_pistol_slot_ref
	_hud_pistol_ammo = hud_pistol_ammo_ref
	_hud_shotgun_slot = hud_shotgun_slot_ref
	_hud_shotgun_ammo = hud_shotgun_ammo_ref

	_load_assets()
	_update_hud_slots(0.0)


func _ready() -> void:
	_sfx_primary = AudioStreamPlayer.new()
	_sfx_primary.name = "WeaponPrimarySfx"
	_sfx_primary.volume_db = 0.0
	_sfx_primary.bus = &"PlayerSFX"
	add_child(_sfx_primary)

	_sfx_layer = AudioStreamPlayer.new()
	_sfx_layer.name = "WeaponLayerSfx"
	_sfx_layer.volume_db = -1.5
	_sfx_layer.bus = &"PlayerSFX"
	add_child(_sfx_layer)


func _load_assets() -> void:
	if ResourceLoader.exists(PISTOL_IDLE_PATH):
		_pistol_idle_tex = load(PISTOL_IDLE_PATH) as Texture2D
	_pistol_fire_frames.clear()
	for i: int in range(6):
		var p: String = "%s/frame_%02d.png" % [PISTOL_FRAMES_DIR, i]
		if ResourceLoader.exists(p):
			var t: Texture2D = load(p) as Texture2D
			if t != null:
				_pistol_fire_frames.append(t)

	if ResourceLoader.exists(SHOTGUN_IDLE_PATH):
		_shotgun_idle_tex = load(SHOTGUN_IDLE_PATH) as Texture2D
	_shotgun_fire_frames.clear()
	for i: int in range(6):
		var s: String = "%s/frame_%02d.png" % [SHOTGUN_FRAMES_DIR, i]
		if ResourceLoader.exists(s):
			var t2: Texture2D = load(s) as Texture2D
			if t2 != null:
				_shotgun_fire_frames.append(t2)

	if ResourceLoader.exists(HUD_PISTOL_INACTIVE):
		_hud_pistol_inactive_tex = load(HUD_PISTOL_INACTIVE) as Texture2D
	if ResourceLoader.exists(HUD_SHOTGUN_INACTIVE):
		_hud_shotgun_inactive_tex = load(HUD_SHOTGUN_INACTIVE) as Texture2D

	_hud_pistol_active_frames = _slice_horizontal_sheet(HUD_PISTOL_ACTIVE, 4)
	_hud_shotgun_active_frames = _slice_horizontal_sheet(HUD_SHOTGUN_ACTIVE, 4)


func _slice_horizontal_sheet(path: String, count: int) -> Array[AtlasTexture]:
	var result: Array[AtlasTexture] = []
	if not ResourceLoader.exists(path):
		return result
	var sheet: Texture2D = load(path) as Texture2D
	if sheet == null or count <= 0:
		return result
	var cell_w: float = float(sheet.get_width()) / float(count)
	var cell_h: float = float(sheet.get_height())
	for i: int in range(count):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(float(i) * cell_w, 0.0, cell_w, cell_h)
		result.append(atlas)
	return result


func is_using_gun() -> bool:
	return current_weapon != RightWeapon.FIST


func is_busy() -> bool:
	return _is_swapping or _is_discarding


func pickup_weapon(weapon_name: String) -> bool:
	if weapon_name == "pistol":
		if has_pistol and pistol_ammo >= PISTOL_MAX_AMMO:
			return false
		var was_new: bool = not has_pistol
		has_pistol = true
		pistol_ammo = PISTOL_MAX_AMMO
		weapon_toast.emit("PISTOL EQUIPPED (7 ROUNDS)")
		if was_new or current_weapon == RightWeapon.FIST:
			switch_to(RightWeapon.PISTOL)
		_update_hud_slots(0.0)
		return true

	if weapon_name == "shotgun":
		if has_shotgun and shotgun_ammo >= SHOTGUN_MAX_AMMO:
			return false
		var was_new_s: bool = not has_shotgun
		has_shotgun = true
		shotgun_ammo = SHOTGUN_MAX_AMMO
		weapon_toast.emit("SHOTGUN EQUIPPED (2 ROUNDS)")
		if was_new_s or current_weapon == RightWeapon.FIST:
			switch_to(RightWeapon.SHOTGUN)
		_update_hud_slots(0.0)
		return true

	return false


func cycle_scroll(step: int) -> void:
	if _is_swapping or _is_discarding:
		return
	var owned: Array[RightWeapon] = [RightWeapon.FIST]
	if has_pistol:
		owned.append(RightWeapon.PISTOL)
	if has_shotgun:
		owned.append(RightWeapon.SHOTGUN)
	if owned.size() <= 1:
		return

	var cur_idx: int = owned.find(current_weapon)
	if cur_idx < 0:
		cur_idx = 0
	var next_idx: int = posmod(cur_idx + step, owned.size())
	switch_to(owned[next_idx])


func switch_to(target: RightWeapon) -> void:
	if target == current_weapon:
		return
	if target == RightWeapon.PISTOL and not has_pistol:
		return
	if target == RightWeapon.SHOTGUN and not has_shotgun:
		return

	if _swap_tween != null and _swap_tween.is_valid():
		_swap_tween.kill()
	if _fire_tween != null and _fire_tween.is_valid():
		_fire_tween.kill()
	_is_firing_anim = false
	_is_swapping = true
	_weapon_recoil = Vector2.ZERO

	_play_sfx(_sfx_primary, SFX_EQUIP_RACK, randf_range(0.95, 1.08))

	var outgoing: Control = _get_visual_for(current_weapon)
	_swap_tween = create_tween()
	if outgoing != null:
		outgoing.pivot_offset = Vector2(outgoing.size.x, outgoing.size.y)
		_swap_tween.tween_property(outgoing, "position", Vector2(55.0, 240.0), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_swap_tween.parallel().tween_property(outgoing, "rotation_degrees", 16.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		_swap_tween.tween_interval(0.11)

	_swap_tween.tween_callback(_apply_swap_midpoint.bind(target))

	var incoming: Control = _get_visual_for(target)
	if incoming != null:
		_swap_tween.tween_property(incoming, "position", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_swap_tween.parallel().tween_property(incoming, "rotation_degrees", 0.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swap_tween.tween_callback(_on_swap_finished)


func _apply_swap_midpoint(target: RightWeapon) -> void:
	current_weapon = target
	_reset_all_visual_transforms()
	var incoming: Control = _get_visual_for(current_weapon)
	if incoming != null:
		incoming.pivot_offset = Vector2(incoming.size.x, incoming.size.y)
		incoming.position = Vector2(55.0, 240.0)
		incoming.rotation_degrees = 16.0
	if _pistol_arm != null and _pistol_idle_tex != null:
		_pistol_arm.texture = _pistol_idle_tex
	if _shotgun_arm != null and _shotgun_idle_tex != null:
		_shotgun_arm.texture = _shotgun_idle_tex
	weapon_changed.emit(int(current_weapon))
	_update_hud_slots(0.0)


func _on_swap_finished() -> void:
	_is_swapping = false
	_is_discarding = false
	_reset_all_visual_transforms()
	weapon_changed.emit(int(current_weapon))


func _reset_all_visual_transforms() -> void:
	for ctrl: Control in [_right_fist_arm, _pistol_arm, _shotgun_arm]:
		if ctrl != null:
			ctrl.position = Vector2.ZERO
			ctrl.rotation_degrees = 0.0


func _get_visual_for(w: RightWeapon) -> Control:
	match w:
		RightWeapon.PISTOL:
			return _pistol_arm
		RightWeapon.SHOTGUN:
			return _shotgun_arm
		_:
			return _right_fist_arm


func try_fire() -> bool:
	if current_weapon == RightWeapon.FIST or _is_swapping or _is_discarding or _fire_cooldown_timer > 0.0:
		return false

	if current_weapon == RightWeapon.PISTOL:
		if pistol_ammo <= 0:
			_trigger_empty_click_and_discard(RightWeapon.PISTOL)
			return true
		pistol_ammo -= 1
		_fire_cooldown_timer = pistol_fire_cooldown
		_fire_pistol_hitscan()
		_play_weapon_fire_anim(_pistol_arm, _pistol_fire_frames, _pistol_idle_tex, 20.0)
		_weapon_recoil = Vector2(24.0, 32.0)
		_weapon_rot_recoil = -8.5
		_weapon_scale_recoil = 0.045
		fired_recoil.emit(2.4, 1.4)
		_play_sfx(_sfx_primary, SFX_PISTOL_SHOT, randf_range(0.96, 1.06))
		_update_hud_slots(0.0)
		return true

	if current_weapon == RightWeapon.SHOTGUN:
		if shotgun_ammo <= 0:
			_trigger_empty_click_and_discard(RightWeapon.SHOTGUN)
			return true
		shotgun_ammo -= 1
		_fire_cooldown_timer = shotgun_fire_cooldown
		_fire_shotgun_hitscan()
		_play_weapon_fire_anim(_shotgun_arm, _shotgun_fire_frames, _shotgun_idle_tex, 15.0)
		_weapon_recoil = Vector2(46.0, 58.0)
		_weapon_rot_recoil = -15.5
		_weapon_scale_recoil = 0.085
		fired_recoil.emit(5.8, 3.6)
		_play_sfx(_sfx_primary, SFX_SHOTGUN_BOOM, randf_range(1.22, 1.34))
		_sfx_layer.volume_db = -1.5
		_play_sfx(_sfx_layer, SFX_PISTOL_SHOT, randf_range(0.60, 0.70))
		_schedule_shotgun_pump_sfx()
		_update_hud_slots(0.0)
		return true

	return false


func _trigger_empty_click_and_discard(empty_weapon: RightWeapon) -> void:
	_is_discarding = true
	_play_sfx(_sfx_primary, SFX_DRY_FIRE, randf_range(0.96, 1.05))
	_weapon_recoil = Vector2(8.0, 12.0)

	if empty_weapon == RightWeapon.PISTOL:
		has_pistol = false
		pistol_ammo = 0
		weapon_toast.emit("PISTOL EMPTY!")
	elif empty_weapon == RightWeapon.SHOTGUN:
		has_shotgun = false
		shotgun_ammo = 0
		weapon_toast.emit("SHOTGUN EMPTY!")
	_update_hud_slots(0.0)

	# Short beat after dry-fire click, then smoothly holster weapon & return to normal fist!
	var delay_tween: Tween = create_tween()
	delay_tween.tween_interval(0.18)
	delay_tween.tween_callback(_discard_to_fist)


func _discard_to_fist() -> void:
	_is_discarding = false
	switch_to(RightWeapon.FIST)


func _schedule_shotgun_pump_sfx() -> void:
	if _pump_tween != null and _pump_tween.is_valid():
		_pump_tween.kill()
	_pump_tween = create_tween()
	_pump_tween.tween_interval(0.20)
	_pump_tween.tween_callback(_play_shotgun_pump)


func _play_shotgun_pump() -> void:
	if current_weapon == RightWeapon.SHOTGUN and not _is_swapping:
		_sfx_layer.volume_db = -5.5
		_play_sfx(_sfx_layer, SFX_EQUIP_RACK, randf_range(1.06, 1.15))


func _get_muzzle_world_pos() -> Vector3:
	if _camera == null:
		return Vector3.ZERO
	var xf: Transform3D = _camera.global_transform
	return xf.origin + xf.basis.x * 0.24 - xf.basis.y * 0.11 - xf.basis.z * 0.62


func _fire_pistol_hitscan() -> void:
	if _camera == null or _player == null:
		return
	var origin: Vector3 = _camera.global_position
	var fwd: Vector3 = -_camera.global_transform.basis.z
	var muzzle_pos: Vector3 = _get_muzzle_world_pos()
	var root_scene: Node = get_tree().current_scene
	if root_scene != null:
		CombatFX3D.spawn_flash_light(root_scene, muzzle_pos, Color(1.0, 0.78, 0.38, 1.0), 3.4, 8.5, 0.055)

	var space_state: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + fwd * pistol_range, 18)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = space_state.intersect_ray(query)
	var end_pos: Vector3 = origin + fwd * pistol_range
	if not hit.is_empty():
		end_pos = hit["position"] as Vector3

	if root_scene != null:
		CombatFX3D.spawn_tracer(root_scene, muzzle_pos, end_pos, Color(1.0, 0.90, 0.52, 0.90), 0.020, 0.068)

	if hit.is_empty():
		return

	var hit_pos: Vector3 = end_pos
	var col: Object = hit["collider"] as Object
	if col != null and col.has_method("on_bullet_hit"):
		var res: Variant = col.call("on_bullet_hit", pistol_damage, hit_pos, 4.2, true, "pistol")
		_dispatch_hit_feel("pistol", res, 1.0)
	elif col != null and col.has_method("on_punched"):
		var res_p: Variant = col.call("on_punched", pistol_damage, hit_pos, "pistol")
		_dispatch_hit_feel("pistol", res_p, 1.0)
	elif root_scene != null:
		var hit_norm: Vector3 = hit.get("normal", -fwd) as Vector3
		SpriteFX3D.spawn(root_scene, hit_pos, FX_HIT_SPARKS, 4, 1, 16.0, 0.022, SFX_BULLET_IMPACT, -4.0)
		CombatFX3D.spawn_sparks_burst(root_scene, hit_pos, hit_norm, Color(1.0, 0.84, 0.36, 1.0), 7)


func _dispatch_hit_feel(weapon_id: String, hit_result: Variant, intensity_scale: float) -> void:
	if _player == null or not _player.has_method("trigger_weapon_hit_feel"):
		return
	var killed: bool = false
	var blocked: bool = false
	if hit_result is Dictionary:
		var d: Dictionary = hit_result as Dictionary
		if not bool(d.get("hit", true)):
			return
		killed = bool(d.get("killed", false))
		blocked = bool(d.get("blocked", false))
	_player.call("trigger_weapon_hit_feel", weapon_id, killed, blocked, intensity_scale)


func _fire_shotgun_hitscan() -> void:
	if _camera == null or _player == null:
		return
	var origin: Vector3 = _camera.global_position
	var cam_basis: Basis = _camera.global_transform.basis
	var fwd: Vector3 = -cam_basis.z
	var right_v: Vector3 = cam_basis.x
	var up_v: Vector3 = cam_basis.y
	var muzzle_pos: Vector3 = _get_muzzle_world_pos()
	var space_state: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var root_scene: Node = get_tree().current_scene
	if root_scene != null:
		CombatFX3D.spawn_flash_light(root_scene, muzzle_pos, Color(1.0, 0.62, 0.22, 1.0), 6.2, 14.0, 0.085)

	var spread_rad: float = deg_to_rad(shotgun_spread_deg)

	var sfx_played_for_enemy: Dictionary = {}
	var wall_sfx_played: bool = false
	var pellets_hit_enemy: int = 0
	var any_killed: bool = false
	var any_unblocked: bool = false

	for i: int in range(shotgun_pellets):
		var pellet_dir: Vector3 = fwd
		if i > 0:
			var angle: float = (TAU / float(shotgun_pellets - 1)) * float(i - 1) + randf_range(-0.22, 0.22)
			var mag: float = randf_range(0.35, 1.0) * spread_rad
			pellet_dir = (fwd + right_v * (cos(angle) * mag) + up_v * (sin(angle) * mag)).normalized()

		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + pellet_dir * shotgun_range, 18)
		query.exclude = [_player.get_rid()]
		var hit: Dictionary = space_state.intersect_ray(query)
		var end_pos: Vector3 = origin + pellet_dir * shotgun_range
		if not hit.is_empty():
			end_pos = hit["position"] as Vector3

		if root_scene != null:
			var pellet_start: Vector3 = muzzle_pos + right_v * randf_range(-0.04, 0.04) + up_v * randf_range(-0.03, 0.03)
			CombatFX3D.spawn_tracer(root_scene, pellet_start, end_pos, Color(1.0, 0.78, 0.34, 0.76), 0.012, 0.075)

		if hit.is_empty():
			continue

		var hit_pos: Vector3 = end_pos
		var dist: float = origin.distance_to(hit_pos)
		var falloff_t: float = clampf((dist - shotgun_close_dist) / maxf(shotgun_far_dist - shotgun_close_dist, 0.1), 0.0, 1.0)
		var pellet_dmg: float = lerpf(shotgun_pellet_close_damage, shotgun_pellet_far_damage, falloff_t)
		var pellet_kb: float = lerpf(2.5, 1.1, falloff_t)

		var col: Object = hit["collider"] as Object
		if col != null and col.has_method("on_bullet_hit"):
			var id: int = col.get_instance_id()
			var play_audio: bool = not sfx_played_for_enemy.has(id)
			sfx_played_for_enemy[id] = true
			var res: Variant = col.call("on_bullet_hit", pellet_dmg, hit_pos, pellet_kb, play_audio, "shotgun")
			if res is Dictionary:
				var d: Dictionary = res as Dictionary
				if bool(d.get("hit", true)):
					pellets_hit_enemy += 1
					if bool(d.get("killed", false)):
						any_killed = true
					if not bool(d.get("blocked", false)):
						any_unblocked = true
			else:
				pellets_hit_enemy += 1
				any_unblocked = true
		elif col != null and col.has_method("on_punched"):
			var res_p: Variant = col.call("on_punched", pellet_dmg, hit_pos, "shotgun")
			pellets_hit_enemy += 1
			any_unblocked = true
			if res_p is Dictionary and bool((res_p as Dictionary).get("killed", false)):
				any_killed = true
		elif root_scene != null:
			var wall_sfx: String = SFX_BULLET_IMPACT if not wall_sfx_played else ""
			wall_sfx_played = true
			var hit_norm: Vector3 = hit.get("normal", -pellet_dir) as Vector3
			SpriteFX3D.spawn(root_scene, hit_pos, FX_HIT_SPARKS, 4, 1, 16.0, 0.022, wall_sfx, -5.0)
			if i % 2 == 0:
				SpriteFX3D.spawn(root_scene, hit_pos, FX_SMOKE_PUFF, 4, 1, 12.0, 0.020)
				CombatFX3D.spawn_sparks_burst(root_scene, hit_pos, hit_norm, Color(1.0, 0.70, 0.25, 1.0), 5)

	if pellets_hit_enemy > 0 and _player.has_method("trigger_weapon_hit_feel"):
		var shotgun_scale: float = clampf(0.55 + float(pellets_hit_enemy) * 0.14, 0.65, 1.45)
		_player.call("trigger_weapon_hit_feel", "shotgun", any_killed, not any_unblocked, shotgun_scale)


func _play_weapon_fire_anim(target_rect: TextureRect, frames: Array[Texture2D], idle_tex: Texture2D, fps: float) -> void:
	if target_rect == null or frames.is_empty():
		return
	if _fire_tween != null and _fire_tween.is_valid():
		_fire_tween.kill()
	_is_firing_anim = true
	var dt: float = 1.0 / maxf(fps, 1.0)
	_fire_tween = create_tween()
	for i: int in range(frames.size()):
		_fire_tween.tween_callback(_set_rect_tex.bind(target_rect, frames[i]))
		_fire_tween.tween_interval(dt)
	_fire_tween.tween_callback(_finish_fire_anim.bind(target_rect, idle_tex))


func _set_rect_tex(rect: TextureRect, tex: Texture2D) -> void:
	if rect != null and tex != null:
		rect.texture = tex


func _finish_fire_anim(rect: TextureRect, idle_tex: Texture2D) -> void:
	_is_firing_anim = false
	if rect != null and idle_tex != null:
		rect.texture = idle_tex


func step_visuals(delta: float, move_ratio: float, on_floor: bool, freeze_for_parry: bool) -> void:
	if _fire_cooldown_timer > 0.0:
		_fire_cooldown_timer = maxf(0.0, _fire_cooldown_timer - delta)

	_update_hud_slots(delta)

	if freeze_for_parry or _is_swapping or current_weapon == RightWeapon.FIST:
		return

	var active_rect: TextureRect = _pistol_arm if current_weapon == RightWeapon.PISTOL else _shotgun_arm
	if active_rect == null:
		return

	_weapon_recoil = _weapon_recoil.lerp(Vector2.ZERO, minf(1.0, delta * 13.0))
	_weapon_rot_recoil = lerpf(_weapon_rot_recoil, 0.0, minf(1.0, delta * 14.0))
	_weapon_scale_recoil = lerpf(_weapon_scale_recoil, 0.0, minf(1.0, delta * 16.0))
	var target_pos: Vector2 = _weapon_recoil

	if on_floor and move_ratio > 0.05:
		_weapon_bob_time += delta * 9.5
		target_pos += Vector2(
			cos(_weapon_bob_time + PI) * 7.0 * move_ratio,
			absf(sin(_weapon_bob_time + PI)) * 9.0 * move_ratio
		)
	else:
		_weapon_bob_time += delta * 2.0
		target_pos += Vector2(
			sin(_weapon_bob_time + PI) * 2.5,
			cos(_weapon_bob_time * 1.3 + PI) * 4.0
		)

	active_rect.pivot_offset = Vector2(active_rect.size.x * 0.75, active_rect.size.y * 0.85)
	active_rect.position = active_rect.position.lerp(target_pos, minf(1.0, delta * 18.0))
	active_rect.rotation_degrees = lerpf(active_rect.rotation_degrees, _weapon_rot_recoil, minf(1.0, delta * 18.0))
	var sc: float = 1.0 + _weapon_scale_recoil
	active_rect.scale = Vector2(sc, sc)


func apply_right_visibility(show_right_side: bool) -> void:
	if _right_fist_anchor != null:
		_right_fist_anchor.visible = show_right_side and (current_weapon == RightWeapon.FIST)
	if _pistol_anchor != null:
		_pistol_anchor.visible = show_right_side and (current_weapon == RightWeapon.PISTOL)
	if _shotgun_anchor != null:
		_shotgun_anchor.visible = show_right_side and (current_weapon == RightWeapon.SHOTGUN)


func _update_hud_slots(delta: float) -> void:
	_hud_anim_timer += delta * 8.0
	var anim_idx: int = int(_hud_anim_timer) % 4

	if _hud_container != null:
		_hud_container.visible = has_pistol or has_shotgun

	if _hud_pistol_slot != null:
		_hud_pistol_slot.visible = has_pistol
		if has_pistol:
			if current_weapon == RightWeapon.PISTOL and not _hud_pistol_active_frames.is_empty():
				_hud_pistol_slot.texture = _hud_pistol_active_frames[anim_idx % _hud_pistol_active_frames.size()]
			elif _hud_pistol_inactive_tex != null:
				_hud_pistol_slot.texture = _hud_pistol_inactive_tex
	if _hud_pistol_ammo != null:
		_hud_pistol_ammo.visible = has_pistol
		_hud_pistol_ammo.text = "%d / %d" % [pistol_ammo, PISTOL_MAX_AMMO]

	if _hud_shotgun_slot != null:
		_hud_shotgun_slot.visible = has_shotgun
		if has_shotgun:
			if current_weapon == RightWeapon.SHOTGUN and not _hud_shotgun_active_frames.is_empty():
				_hud_shotgun_slot.texture = _hud_shotgun_active_frames[anim_idx % _hud_shotgun_active_frames.size()]
			elif _hud_shotgun_inactive_tex != null:
				_hud_shotgun_slot.texture = _hud_shotgun_inactive_tex
	if _hud_shotgun_ammo != null:
		_hud_shotgun_ammo.visible = has_shotgun
		_hud_shotgun_ammo.text = "%d / %d" % [shotgun_ammo, SHOTGUN_MAX_AMMO]


func _play_sfx(player_node: AudioStreamPlayer, path: String, pitch: float = 1.0) -> void:
	if player_node == null or path.is_empty() or not ResourceLoader.exists(path):
		return
	player_node.stream = load(path) as AudioStream
	player_node.pitch_scale = pitch
	player_node.play()
