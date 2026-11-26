extends CharacterBody3D
class_name AlienEnemy

signal died(enemy: AlienEnemy)

enum AlienVariant {
	DOCTOR_SCALPEL,
	DOCTOR_HAMMER,
	DOCTOR_SAW,
	POLICE_BATON,
	POLICE_SHIELD,
	POLICE_PISTOL,
	SOLDIER_RIFLE,
	SOLDIER_BAZOOKA,
	SOLDIER_BOOSTER,
}

enum AnimState {
	IDLE,
	WALK,
	ATTACK,
}

const ENEMY_SHEETS: Dictionary = {
	AlienVariant.DOCTOR_SCALPEL: "res://assets/enemies/doctor_scalpel/spritesheet.png",
	AlienVariant.DOCTOR_HAMMER: "res://assets/enemies/doctor_hammer/spritesheet.png",
	AlienVariant.DOCTOR_SAW: "res://assets/enemies/doctor_saw/spritesheet.png",
	AlienVariant.POLICE_BATON: "res://assets/enemies/police_baton/spritesheet.png",
	AlienVariant.POLICE_SHIELD: "res://assets/enemies/police_shield/spritesheet.png",
	AlienVariant.POLICE_PISTOL: "res://assets/enemies/police_pistol/spritesheet.png",
	AlienVariant.SOLDIER_RIFLE: "res://assets/enemies/soldier_rifle/spritesheet.png",
	AlienVariant.SOLDIER_BAZOOKA: "res://assets/enemies/soldier_bazooka/spritesheet.png",
	AlienVariant.SOLDIER_BOOSTER: "res://assets/enemies/soldier_booster/spritesheet.png",
}

const FX_ALIEN_BLOOD: String = "res://assets/particles/hit_sparks/alien_blood_sheet.png"
const FX_HIT_SPARKS: String = "res://assets/particles/hit_sparks/spritesheet.png"
const FX_MUZZLE_FLASH: String = "res://assets/particles/muzzle_flash/spritesheet.png"
const FX_BOOST_AURA: String = "res://assets/particles/boost_aura/spritesheet.png"
const TEX_BOOST_CIRCLE: String = "res://assets/particles/boost_aura/ground_circle_topdown.png"

const SFX_FOOTSTEP: String = "res://assets/audio/alien_footstep.wav"
const SFX_SPOT: String = "res://assets/audio/alien_spot.wav"
const SFX_HURT: String = "res://assets/audio/alien_hurt.wav"
const SFX_DEATH: String = "res://assets/audio/alien_death.wav"
const SFX_BLOOD: String = "res://assets/audio/alien_blood.wav"
const SFX_SCALPEL: String = "res://assets/audio/melee_scalpel.wav"
const SFX_HAMMER: String = "res://assets/audio/melee_hammer.wav"
const SFX_SAW_START: String = "res://assets/audio/melee_saw_start.wav"
const SFX_SAW_LOOP: String = "res://assets/audio/melee_saw_loop.wav"
const SFX_BATON: String = "res://assets/audio/melee_baton.wav"
const SFX_SHIELD_BASH: String = "res://assets/audio/melee_shield_bash.wav"
const SFX_SHIELD_BLOCK: String = "res://assets/audio/shield_block.wav"
const SFX_PISTOL: String = "res://assets/audio/pistol_shot.wav"
const SFX_RIFLE: String = "res://assets/audio/rifle_shot.wav"
const SFX_BAZOOKA: String = "res://assets/audio/bazooka_fire.wav"
const SFX_BOOST_AURA: String = "res://assets/audio/boost_aura.wav"
const SFX_BOOST_APPLY: String = "res://assets/audio/boost_apply.wav"

@export var variant: AlienVariant = AlienVariant.DOCTOR_SCALPEL
@export var detection_range: float = 13.0
@export var boost_radius: float = 7.5
@export var sprite_pixel_size: float = 0.028

var max_hp: float = 40.0
var hp: float = 40.0
var move_speed: float = 3.5
var attack_range: float = 2.0
var preferred_range: float = 1.6
var attack_cooldown: float = 1.0
var attack_damage: int = 1
var is_ranged: bool = false
var is_booster: bool = false
var has_front_shield: bool = false

var _gravity: float = 9.8
var _alerted: bool = false
var _is_dead: bool = false
var _is_grappled: bool = false
var _anim_state: AnimState = AnimState.IDLE
var _anim_timer: float = 0.0
var _attack_timer: float = 0.0
var _is_attacking: bool = false
var _attack_action_done: bool = false
var _hurt_flash_timer: float = 0.0
var _boost_timer: float = 0.0
var _footstep_timer: float = 0.0
var _burst_remaining: int = 0
var _burst_delay_timer: float = 0.0
var _facing_dir: Vector3 = Vector3.FORWARD
var _knockback_stun_timer: float = 0.0
var _los_cache_timer: float = 0.0
var _cached_los: bool = false
var _hit_squash: Vector3 = Vector3.ONE
var _hit_jolt_offset: Vector2 = Vector2.ZERO
var _last_hit_dir: Vector3 = Vector3.FORWARD
var _last_hit_weapon: String = "fist"

var _sprite: Sprite3D
var _ground_aura: Sprite3D
var _voice_audio: AudioStreamPlayer3D
var _action_audio: AudioStreamPlayer3D
var _loop_audio: AudioStreamPlayer3D
var _step_audio: AudioStreamPlayer3D


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 19 # Player (1) + Enemies (2) + World Obstacles (16)

	_facing_dir = -global_transform.basis.z
	_facing_dir.y = 0.0
	if _facing_dir.length_squared() < 0.001:
		_facing_dir = Vector3.FORWARD
	else:
		_facing_dir = _facing_dir.normalized()

	_configure_variant_stats()
	_setup_nodes()
	_update_sprite_frame(0.0)


func _configure_variant_stats() -> void:
	is_ranged = false
	is_booster = false
	has_front_shield = false
	attack_damage = 1

	match variant:
		AlienVariant.DOCTOR_SCALPEL:
			max_hp = 50.0
			move_speed = 4.5
			attack_range = 2.0
			preferred_range = 1.5
			attack_cooldown = 0.85
		AlienVariant.DOCTOR_HAMMER:
			max_hp = 80.0
			move_speed = 3.2
			attack_range = 2.2
			preferred_range = 1.7
			attack_cooldown = 1.35
		AlienVariant.DOCTOR_SAW:
			max_hp = 70.0
			move_speed = 3.7
			attack_range = 2.1
			preferred_range = 1.5
			attack_cooldown = 0.75
		AlienVariant.POLICE_BATON:
			max_hp = 65.0
			move_speed = 3.8
			attack_range = 2.1
			preferred_range = 1.6
			attack_cooldown = 1.0
		AlienVariant.POLICE_SHIELD:
			max_hp = 100.0
			move_speed = 2.8
			attack_range = 2.2
			preferred_range = 1.7
			attack_cooldown = 1.15
			has_front_shield = true
		AlienVariant.POLICE_PISTOL:
			max_hp = 60.0
			move_speed = 3.0
			attack_range = 13.0
			preferred_range = 7.5
			attack_cooldown = 1.5
			is_ranged = true
		AlienVariant.SOLDIER_RIFLE:
			max_hp = 75.0
			move_speed = 3.0
			attack_range = 15.0
			preferred_range = 9.0
			attack_cooldown = 1.9
			is_ranged = true
		AlienVariant.SOLDIER_BAZOOKA:
			max_hp = 90.0
			move_speed = 2.3
			attack_range = 17.0
			preferred_range = 11.0
			attack_cooldown = 2.9
			is_ranged = true
		AlienVariant.SOLDIER_BOOSTER:
			max_hp = 70.0
			move_speed = 2.9
			attack_range = boost_radius
			preferred_range = 6.5
			attack_cooldown = 2.6
			is_booster = true

	hp = max_hp


func _setup_nodes() -> void:
	# Ensure a CapsuleShape3D exists if scene didn't already provide one
	if get_node_or_null("CollisionShape3D") == null:
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.45
		cap.height = 1.9
		col.shape = cap
		col.position = Vector3(0.0, 0.95, 0.0)
		add_child(col)

	_sprite = get_node_or_null("Sprite3D") as Sprite3D
	if _sprite == null:
		_sprite = Sprite3D.new()
		_sprite.name = "Sprite3D"
		add_child(_sprite)

	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.hframes = 8
	_sprite.vframes = 10
	_sprite.pixel_size = sprite_pixel_size
	_sprite.position = Vector3(0.0, 40.0 * sprite_pixel_size, 0.0)

	var sheet_path: String = str(ENEMY_SHEETS.get(variant, ""))
	if not sheet_path.is_empty() and ResourceLoader.exists(sheet_path):
		_sprite.texture = load(sheet_path) as Texture2D

	# Audio players
	_voice_audio = _make_audio_player("VoiceAudio", 0.0, 26.0)
	_action_audio = _make_audio_player("ActionAudio", -1.0, 30.0)
	_loop_audio = _make_audio_player("LoopAudio", -6.0, 18.0)
	_step_audio = _make_audio_player("StepAudio", -10.0, 18.0)
	if ResourceLoader.exists(SFX_FOOTSTEP):
		_step_audio.stream = load(SFX_FOOTSTEP) as AudioStream

	# Circular ground boost aura for Soldier Booster
	if is_booster:
		_ground_aura = Sprite3D.new()
		_ground_aura.name = "BoostGroundCircle"
		_ground_aura.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_ground_aura.shaded = false
		_ground_aura.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_ground_aura.position = Vector3(0.0, 0.06, 0.0)
		_ground_aura.modulate = Color(0.55, 1.0, 0.65, 0.72)
		if ResourceLoader.exists(TEX_BOOST_CIRCLE):
			var circle_tex: Texture2D = load(TEX_BOOST_CIRCLE) as Texture2D
			_ground_aura.texture = circle_tex
			if circle_tex != null and circle_tex.get_width() > 0:
				_ground_aura.pixel_size = (boost_radius * 2.0) / float(circle_tex.get_width())
		add_child(_ground_aura)


func _make_audio_player(node_name: String, vol_db: float, max_dist: float) -> AudioStreamPlayer3D:
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.name = node_name
	p.volume_db = vol_db
	p.unit_size = 7.0
	p.max_distance = max_dist
	p.bus = &"EnemySFX"
	add_child(p)
	return p


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _is_grappled:
		move_and_slide()
		_update_sprite_modulate()
		_update_sprite_frame(delta)
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)

	if _boost_timer > 0.0:
		_boost_timer = maxf(0.0, _boost_timer - delta)

	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer = maxf(0.0, _hurt_flash_timer - delta)

	_update_hit_squash(delta)

	if _knockback_stun_timer > 0.0:
		_knockback_stun_timer = maxf(0.0, _knockback_stun_timer - delta)
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		move_and_slide()
		_update_sprite_modulate()
		_update_sprite_frame(delta)
		return

	if _los_cache_timer > 0.0:
		_los_cache_timer = maxf(0.0, _los_cache_timer - delta)

	# Handle Soldier Rifle multi-shot burst
	if _burst_remaining > 0:
		_burst_delay_timer -= delta
		if _burst_delay_timer <= 0.0:
			_burst_remaining -= 1
			_burst_delay_timer = 0.11
			var player_for_burst: Node3D = _get_player()
			if player_for_burst != null:
				_fire_projectile(player_for_burst, Projectile3D.ProjectileKind.RIFLE, SFX_RIFLE)

	# Animate Booster's circular ground aura
	if _ground_aura != null:
		_ground_aura.rotate_y(delta * 0.9)
		var pulse: float = 0.58 + 0.22 * sin(Time.get_ticks_msec() * 0.005)
		_ground_aura.modulate = Color(0.55, 1.0, 0.65, pulse)

	var player: Node3D = _get_player()
	var speed_mult: float = 1.35 if _boost_timer > 0.0 else 1.0
	var cd_mult: float = 0.72 if _boost_timer > 0.0 else 1.0

	if player != null:
		var to_player: Vector3 = player.global_position - global_position
		var flat_to_player: Vector3 = Vector3(to_player.x, 0.0, to_player.z)
		var dist: float = flat_to_player.length()

		if not _alerted and dist <= detection_range:
			_become_alerted()

		if _alerted:
			if dist > 0.05:
				_facing_dir = flat_to_player.normalized()

			if _is_attacking:
				velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
			elif is_booster:
				_process_booster_ai(delta, flat_to_player, dist, speed_mult, cd_mult)
			elif is_ranged:
				_process_ranged_ai(delta, player, flat_to_player, dist, speed_mult, cd_mult)
			else:
				_process_melee_ai(delta, flat_to_player, dist, speed_mult, cd_mult)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			_set_anim_state(AnimState.IDLE)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		_set_anim_state(AnimState.IDLE)

	# Rotary saw continuous buzz while alerted and close
	if variant == AlienVariant.DOCTOR_SAW:
		_update_saw_loop(player)

	move_and_slide()
	_update_footsteps(delta)
	_update_sprite_modulate()
	_update_sprite_frame(delta)


func _become_alerted() -> void:
	_alerted = true
	_play_3d(_voice_audio, SFX_SPOT, randf_range(0.92, 1.08))
	if variant == AlienVariant.DOCTOR_SAW:
		_play_3d(_action_audio, SFX_SAW_START, 1.0)


func _process_melee_ai(delta: float, flat_to_player: Vector3, dist: float, speed_mult: float, cd_mult: float) -> void:
	if dist <= attack_range and _attack_timer <= 0.0:
		_start_attack(cd_mult)
		velocity.x = 0.0
		velocity.z = 0.0
	elif dist > preferred_range:
		var dir: Vector3 = flat_to_player.normalized()
		velocity.x = dir.x * move_speed * speed_mult
		velocity.z = dir.z * move_speed * speed_mult
		_set_anim_state(AnimState.WALK)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		_set_anim_state(AnimState.IDLE)


func _process_ranged_ai(delta: float, player: Node3D, flat_to_player: Vector3, dist: float, speed_mult: float, cd_mult: float) -> void:
	if _los_cache_timer <= 0.0:
		_cached_los = _has_line_of_sight(player)
		_los_cache_timer = randf_range(0.14, 0.22)
	var has_los: bool = _cached_los
	if dist <= attack_range and has_los and _attack_timer <= 0.0:
		_start_attack(cd_mult)
		velocity.x = 0.0
		velocity.z = 0.0
	elif dist > preferred_range or not has_los:
		var dir: Vector3 = flat_to_player.normalized()
		velocity.x = dir.x * move_speed * speed_mult
		velocity.z = dir.z * move_speed * speed_mult
		_set_anim_state(AnimState.WALK)
	elif dist < preferred_range * 0.55:
		# Back away slightly to keep shooting distance
		var away: Vector3 = -flat_to_player.normalized()
		velocity.x = away.x * move_speed * 0.65 * speed_mult
		velocity.z = away.z * move_speed * 0.65 * speed_mult
		_set_anim_state(AnimState.WALK)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		_set_anim_state(AnimState.IDLE)


func _process_booster_ai(delta: float, flat_to_player: Vector3, dist: float, speed_mult: float, cd_mult: float) -> void:
	# Stay near allied aliens or at mid-range from player, pulsing boost aura
	if _attack_timer <= 0.0:
		_start_attack(cd_mult)
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var ally_center: Vector3 = _find_nearest_ally_pos()
	if ally_center != Vector3.INF:
		var to_ally: Vector3 = ally_center - global_position
		to_ally.y = 0.0
		if to_ally.length() > boost_radius * 0.55:
			var dir: Vector3 = to_ally.normalized()
			velocity.x = dir.x * move_speed * speed_mult
			velocity.z = dir.z * move_speed * speed_mult
			_facing_dir = dir
			_set_anim_state(AnimState.WALK)
			return

	if dist > preferred_range + 2.5:
		var dir_p: Vector3 = flat_to_player.normalized()
		velocity.x = dir_p.x * move_speed * 0.8 * speed_mult
		velocity.z = dir_p.z * move_speed * 0.8 * speed_mult
		_set_anim_state(AnimState.WALK)
	elif dist < 4.0:
		var away_p: Vector3 = -flat_to_player.normalized()
		velocity.x = away_p.x * move_speed * 0.8 * speed_mult
		velocity.z = away_p.z * move_speed * 0.8 * speed_mult
		_set_anim_state(AnimState.WALK)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		_set_anim_state(AnimState.IDLE)


func _find_nearest_ally_pos() -> Vector3:
	var best_pos: Vector3 = Vector3.INF
	var best_dist: float = 999.0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is AlienEnemy):
			continue
		var ally: AlienEnemy = node as AlienEnemy
		if ally._is_dead or ally.is_booster:
			continue
		var d: float = global_position.distance_to(ally.global_position)
		if d < best_dist:
			best_dist = d
			best_pos = ally.global_position
	return best_pos


func _start_attack(cd_mult: float) -> void:
	_is_attacking = true
	_attack_action_done = false
	_attack_timer = attack_cooldown * cd_mult
	_set_anim_state(AnimState.ATTACK, true)


func _execute_attack_action() -> void:
	_attack_action_done = true
	var player: Node3D = _get_player()

	match variant:
		AlienVariant.DOCTOR_SCALPEL:
			_play_3d(_action_audio, SFX_SCALPEL, randf_range(0.95, 1.1))
			_try_melee_hit(player)
		AlienVariant.DOCTOR_HAMMER:
			_play_3d(_action_audio, SFX_HAMMER, randf_range(0.9, 1.02))
			_try_melee_hit(player)
		AlienVariant.DOCTOR_SAW:
			_play_3d(_action_audio, SFX_SAW_LOOP, randf_range(0.96, 1.06))
			_try_melee_hit(player)
		AlienVariant.POLICE_BATON:
			_play_3d(_action_audio, SFX_BATON, randf_range(0.94, 1.08))
			_try_melee_hit(player)
		AlienVariant.POLICE_SHIELD:
			_play_3d(_action_audio, SFX_SHIELD_BASH, randf_range(0.92, 1.04))
			_try_melee_hit(player)
		AlienVariant.POLICE_PISTOL:
			if player != null:
				_fire_projectile(player, Projectile3D.ProjectileKind.PISTOL, SFX_PISTOL)
		AlienVariant.SOLDIER_RIFLE:
			if player != null:
				_fire_projectile(player, Projectile3D.ProjectileKind.RIFLE, SFX_RIFLE)
				_burst_remaining = 2
				_burst_delay_timer = 0.11
		AlienVariant.SOLDIER_BAZOOKA:
			if player != null:
				_fire_projectile(player, Projectile3D.ProjectileKind.BAZOOKA, SFX_BAZOOKA)
		AlienVariant.SOLDIER_BOOSTER:
			_trigger_boost_pulse()


func _try_melee_hit(player: Node3D) -> void:
	if player == null:
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= attack_range + 0.55 and player.has_method("take_damage"):
		player.call("take_damage", attack_damage, global_position)


func _fire_projectile(player: Node3D, proj_kind: Projectile3D.ProjectileKind, shot_sfx: String) -> void:
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		return

	var muzzle_pos: Vector3 = global_position + Vector3(0.0, 1.25, 0.0) + _facing_dir * 0.55
	var target_pos: Vector3 = player.global_position + Vector3(0.0, 1.05, 0.0)
	var aim_dir: Vector3 = (target_pos - muzzle_pos).normalized()
	if proj_kind == Projectile3D.ProjectileKind.RIFLE:
		aim_dir = (aim_dir + Vector3(randf_range(-0.035, 0.035), randf_range(-0.02, 0.02), randf_range(-0.035, 0.035))).normalized()

	var proj_speed_mult: float = 1.2 if _boost_timer > 0.0 else 1.0
	Projectile3D.spawn(root_scene, muzzle_pos, aim_dir, proj_kind, self, proj_speed_mult)

	SpriteFX3D.spawn(root_scene, muzzle_pos, FX_MUZZLE_FLASH, 4, 1, 18.0, 0.022)
	_play_3d(_action_audio, shot_sfx, randf_range(0.94, 1.06))


func _trigger_boost_pulse() -> void:
	var root_scene: Node = get_tree().current_scene
	if root_scene != null:
		SpriteFX3D.spawn(
			root_scene,
			global_position + Vector3(0.0, 0.9, 0.0),
			FX_BOOST_AURA,
			6,
			1,
			10.0,
			0.04,
			SFX_BOOST_AURA,
			-3.0
		)

	var boosted_any: bool = false
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is AlienEnemy):
			continue
		var ally: AlienEnemy = node as AlienEnemy
		if ally._is_dead:
			continue
		if global_position.distance_to(ally.global_position) <= boost_radius:
			ally.apply_boost(3.5)
			boosted_any = true

	if boosted_any:
		_play_3d(_action_audio, SFX_BOOST_APPLY, randf_range(0.96, 1.05))


func apply_boost(duration: float) -> void:
	_boost_timer = maxf(_boost_timer, duration)
	var root_scene: Node = get_tree().current_scene
	if root_scene != null:
		SpriteFX3D.spawn(
			root_scene,
			global_position + Vector3(0.0, 0.85, 0.0),
			FX_BOOST_AURA,
			6,
			1,
			12.0,
			0.025
		)


func _compute_push_dir(hit_pos: Vector3) -> Vector3:
	var player: Node3D = _get_player()
	if player != null:
		var from_player: Vector3 = global_position - player.global_position
		from_player.y = 0.0
		if from_player.length_squared() > 0.001:
			return from_player.normalized()
	var from_hit: Vector3 = global_position - hit_pos
	from_hit.y = 0.0
	if from_hit.length_squared() > 0.001:
		return from_hit.normalized()
	return -_facing_dir


func _apply_sprite_hit_reaction(squash: Vector3, jolt_px: Vector2) -> void:
	_hit_squash = squash
	_hit_jolt_offset = jolt_px
	if _sprite != null:
		_sprite.scale = _hit_squash
		_sprite.offset = _hit_jolt_offset


func _update_hit_squash(delta: float) -> void:
	if _sprite == null:
		return
	if _hit_squash.distance_squared_to(Vector3.ONE) > 0.0001:
		_hit_squash = _hit_squash.lerp(Vector3.ONE, minf(1.0, delta * 18.0))
		_sprite.scale = _hit_squash
	elif _sprite.scale != Vector3.ONE:
		_sprite.scale = Vector3.ONE
	if _hit_jolt_offset.length_squared() > 0.01:
		_hit_jolt_offset = _hit_jolt_offset.lerp(Vector2.ZERO, minf(1.0, delta * 22.0))
		_sprite.offset = _hit_jolt_offset
	elif _sprite.offset != Vector2.ZERO:
		_sprite.offset = Vector2.ZERO


func on_punched(damage: float, hit_pos: Vector3, arm_side: String) -> Dictionary:
	if _is_dead:
		return {"hit": false, "killed": false, "blocked": false}

	if not _alerted:
		_become_alerted()

	var root_scene: Node = get_tree().current_scene
	var final_damage: float = damage
	var blocked: bool = false
	var push_dir: Vector3 = _compute_push_dir(hit_pos)
	_last_hit_dir = push_dir
	_last_hit_weapon = "fist"

	# Riot shield police blocks frontal hits for reduced damage + metallic sparks
	if has_front_shield:
		var player: Node3D = _get_player()
		if player != null:
			var to_attacker: Vector3 = player.global_position - global_position
			to_attacker.y = 0.0
			if to_attacker.length_squared() > 0.001 and _facing_dir.dot(to_attacker.normalized()) > 0.3:
				final_damage = damage * 0.4
				blocked = true
				_play_3d(_action_audio, SFX_SHIELD_BLOCK, randf_range(0.95, 1.08))
				if root_scene != null:
					SpriteFX3D.spawn(root_scene, hit_pos, FX_HIT_SPARKS, 4, 1, 16.0, 0.028)
					CombatFX3D.spawn_sparks_burst(root_scene, hit_pos, -push_dir, Color(0.65, 0.9, 1.0, 1.0), 10)

	hp -= final_damage
	_hurt_flash_timer = 0.16
	_knockback_stun_timer = maxf(_knockback_stun_timer, 0.16)

	var side_sign: float = 1.0 if arm_side == "left" else -1.0
	if blocked:
		_apply_sprite_hit_reaction(Vector3(1.10, 0.94, 1.0), Vector2(side_sign * 4.0, 0.0))
		velocity += push_dir * 2.4
	else:
		_apply_sprite_hit_reaction(Vector3(1.26, 0.80, 1.0), Vector2(side_sign * 9.0, -3.5))
		velocity.x = push_dir.x * 5.6
		velocity.z = push_dir.z * 5.6
		velocity.y = maxf(velocity.y, 1.4)

	if root_scene != null and not blocked:
		SpriteFX3D.spawn(root_scene, hit_pos, FX_ALIEN_BLOOD, 4, 1, 15.0, 0.032)
		CombatFX3D.spawn_blood_burst(root_scene, hit_pos, push_dir + Vector3(0.0, 0.25, 0.0), 9, 7.2, false)
		CombatFX3D.spawn_flash_light(root_scene, hit_pos, Color(0.45, 1.0, 0.45, 1.0), 2.4, 5.5, 0.055)

	var killed: bool = hp <= 0.0
	if killed:
		_die()
	else:
		_play_3d(_voice_audio, SFX_HURT, randf_range(0.9, 1.1))
	return {"hit": true, "killed": killed, "blocked": blocked}


func on_parried_hit(damage: float, hit_pos: Vector3) -> Dictionary:
	if _is_dead:
		return {"hit": false, "killed": false, "blocked": false}

	if not _alerted:
		_become_alerted()

	var push_dir: Vector3 = _compute_push_dir(hit_pos)
	_last_hit_dir = push_dir
	_last_hit_weapon = "parry"

	hp -= damage
	_hurt_flash_timer = 0.22
	_knockback_stun_timer = maxf(_knockback_stun_timer, 0.24)
	_apply_sprite_hit_reaction(Vector3(1.34, 0.74, 1.0), Vector2(0.0, -7.0))

	velocity.x = push_dir.x * 8.5
	velocity.z = push_dir.z * 8.5
	velocity.y = maxf(velocity.y, 3.0)

	var root_scene: Node = get_tree().current_scene
	if root_scene != null:
		SpriteFX3D.spawn(root_scene, hit_pos, FX_ALIEN_BLOOD, 4, 1, 14.0, 0.040)
		CombatFX3D.spawn_blood_burst(root_scene, hit_pos, push_dir, 12, 9.5, false)

	var killed: bool = hp <= 0.0
	if killed:
		_die()
	else:
		_play_3d(_voice_audio, SFX_HURT, randf_range(0.9, 1.1))
	return {"hit": true, "killed": killed, "blocked": false}


func set_grappled(active: bool) -> void:
	_is_grappled = active
	if active:
		if not _alerted:
			_become_alerted()
		_is_attacking = false
		_burst_remaining = 0
		_hurt_flash_timer = 0.12
		_set_anim_state(AnimState.IDLE)


func apply_grapple_pull(pull_velocity: Vector3) -> void:
	if _is_dead:
		return
	velocity = pull_velocity


func on_bullet_hit(damage: float, hit_pos: Vector3, knockback: float = 3.2, play_sfx: bool = true, weapon_tag: String = "pistol") -> Dictionary:
	if _is_dead:
		return {"hit": false, "killed": false, "blocked": false}

	if not _alerted:
		_become_alerted()

	var root_scene: Node = get_tree().current_scene
	var final_damage: float = damage
	var blocked: bool = false
	var push_dir: Vector3 = _compute_push_dir(hit_pos)
	_last_hit_dir = push_dir
	_last_hit_weapon = weapon_tag

	if has_front_shield:
		var player: Node3D = _get_player()
		if player != null:
			var to_attacker: Vector3 = player.global_position - global_position
			to_attacker.y = 0.0
			if to_attacker.length_squared() > 0.001 and _facing_dir.dot(to_attacker.normalized()) > 0.35:
				final_damage = damage * 0.45
				blocked = true
				if play_sfx:
					_play_3d(_action_audio, SFX_SHIELD_BLOCK, randf_range(0.95, 1.08))
				if root_scene != null:
					SpriteFX3D.spawn(root_scene, hit_pos, FX_HIT_SPARKS, 4, 1, 16.0, 0.024)
					if play_sfx:
						CombatFX3D.spawn_sparks_burst(root_scene, hit_pos, -push_dir, Color(0.65, 0.9, 1.0, 1.0), 8)

	hp -= final_damage
	_hurt_flash_timer = 0.14 if weapon_tag == "pistol" else 0.19
	var stun_dur: float = 0.19 if weapon_tag == "shotgun" else 0.10
	_knockback_stun_timer = maxf(_knockback_stun_timer, stun_dur)

	if not blocked:
		if weapon_tag == "shotgun":
			_apply_sprite_hit_reaction(Vector3(1.36, 0.72, 1.0), Vector2(randf_range(-6.0, 6.0), -6.0))
			velocity += push_dir * knockback
			velocity.y = maxf(velocity.y, 1.8 if play_sfx else 0.6)
		else:
			_apply_sprite_hit_reaction(Vector3(0.84, 1.16, 1.0), Vector2(randf_range(-5.0, 5.0), -3.0))
			velocity.x = push_dir.x * knockback
			velocity.z = push_dir.z * knockback
	else:
		velocity += push_dir * (knockback * 0.45)

	if root_scene != null and not blocked:
		if play_sfx:
			SpriteFX3D.spawn(root_scene, hit_pos, FX_ALIEN_BLOOD, 4, 1, 15.0, 0.034 if weapon_tag == "shotgun" else 0.026)
			var droplet_count: int = 12 if weapon_tag == "shotgun" else 6
			var droplet_spd: float = 9.5 if weapon_tag == "shotgun" else 7.8
			CombatFX3D.spawn_blood_burst(root_scene, hit_pos, push_dir, droplet_count, droplet_spd, false)

	var killed: bool = hp <= 0.0
	if killed:
		_die()
	elif play_sfx:
		_play_3d(_voice_audio, SFX_HURT, randf_range(0.9, 1.1))
	return {"hit": true, "killed": killed, "blocked": blocked}


func on_slide_ram_hit(
	damage: float,
	push_dir: Vector3,
	knockback_speed: float = 18.0,
	upward_boost: float = 4.8,
	hit_pos: Vector3 = Vector3.ZERO
) -> Dictionary:
	if _is_dead:
		return {"hit": false, "killed": false, "blocked": false}

	if not _alerted:
		_become_alerted()

	# Interrupt active attack and stagger the enemy backward!
	_is_attacking = false
	_burst_remaining = 0
	_set_anim_state(AnimState.IDLE)

	hp -= damage
	_hurt_flash_timer = 0.24
	_knockback_stun_timer = 0.36
	_apply_sprite_hit_reaction(Vector3(0.80, 1.28, 1.0), Vector2(randf_range(-8.0, 8.0), -10.0))

	var flat_push: Vector3 = Vector3(push_dir.x, 0.0, push_dir.z)
	if flat_push.length_squared() < 0.001:
		flat_push = _compute_push_dir(hit_pos)
	if flat_push.length_squared() > 0.001:
		flat_push = flat_push.normalized()
		_last_hit_dir = flat_push
		_last_hit_weapon = "slide_ram"
		velocity.x = flat_push.x * knockback_speed
		velocity.z = flat_push.z * knockback_speed
	velocity.y = maxf(velocity.y, upward_boost)

	var fx_pos: Vector3 = hit_pos if hit_pos != Vector3.ZERO else (global_position + Vector3(0.0, 0.95, 0.0))
	var root_scene: Node = get_tree().current_scene
	if root_scene != null:
		SpriteFX3D.spawn(root_scene, fx_pos, FX_ALIEN_BLOOD, 4, 1, 14.0, 0.040)
		SpriteFX3D.spawn(root_scene, fx_pos, FX_HIT_SPARKS, 4, 1, 16.0, 0.028)
		CombatFX3D.spawn_blood_burst(root_scene, fx_pos, _last_hit_dir + Vector3(0.0, 0.45, 0.0), 12, 10.5, false)
		CombatFX3D.spawn_sparks_burst(root_scene, fx_pos, _last_hit_dir, Color(1.0, 0.65, 0.22, 1.0), 10)

	var killed: bool = hp <= 0.0
	if killed:
		_die()
	else:
		_play_3d(_voice_audio, SFX_HURT, randf_range(0.86, 1.06))
	return {"hit": true, "killed": killed, "blocked": false}


func _die() -> void:
	_is_dead = true
	_burst_remaining = 0
	if _loop_audio != null and _loop_audio.playing:
		_loop_audio.stop()
	if _ground_aura != null:
		_ground_aura.visible = false

	collision_layer = 0
	collision_mask = 0
	died.emit(self)

	var stage_mgr: Node = get_node_or_null("/root/StageManager")
	if stage_mgr != null and stage_mgr.has_method("register_enemy_kill"):
		stage_mgr.call("register_enemy_kill")

	var root_scene: Node = get_tree().current_scene
	if root_scene != null:
		var death_center: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)
		SpriteFX3D.spawn(
			root_scene,
			death_center,
			FX_ALIEN_BLOOD,
			4,
			1,
			12.0,
			0.052 if _last_hit_weapon == "shotgun" else 0.045,
			SFX_DEATH,
			-1.5
		)
		var gib_count: int = 18 if (_last_hit_weapon == "shotgun" or _last_hit_weapon == "slide_ram") else (14 if _last_hit_weapon == "fist" else 10)
		var gib_speed: float = 11.5 if (_last_hit_weapon == "shotgun" or _last_hit_weapon == "slide_ram") else 8.5
		CombatFX3D.spawn_blood_burst(root_scene, death_center, _last_hit_dir + Vector3(0.0, 0.3, 0.0), gib_count, gib_speed, true)
		CombatFX3D.spawn_flash_light(root_scene, death_center, Color(0.35, 1.0, 0.42, 1.0), 3.0, 7.0, 0.08)
		# 75% chance to drop a Medkit (+1 HP) on death
		if randf() <= 0.75:
			Pickup3D.spawn(root_scene, global_position + Vector3(0.0, 0.05, 0.0), Pickup3D.PickupType.MEDKIT)
		# 25% chance to drop a Pistol (7 ammo) or Shotgun (2 ammo)
		if randf() <= 0.25:
			var weapon_drop: Pickup3D.PickupType = Pickup3D.PickupType.PISTOL if randf() < 0.5 else Pickup3D.PickupType.SHOTGUN
			Pickup3D.spawn(root_scene, global_position + Vector3(0.55, 0.05, 0.0), weapon_drop)
	queue_free()


func _has_line_of_sight(player: Node3D) -> bool:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from_pos: Vector3 = global_position + Vector3(0.0, 1.3, 0.0)
	var to_pos: Vector3 = player.global_position + Vector3(0.0, 1.1, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos, 16)
	var hit: Dictionary = space_state.intersect_ray(query)
	return hit.is_empty()


func _set_anim_state(new_state: AnimState, force_reset: bool = false) -> void:
	if _anim_state == new_state and not force_reset:
		return
	_anim_state = new_state
	_anim_timer = 0.0


func _update_sprite_frame(delta: float) -> void:
	if _sprite == null:
		return

	var col: int = _compute_doom_angle_col()
	var row: int = 0

	match _anim_state:
		AnimState.IDLE:
			_anim_timer += delta * 6.0
			row = int(_anim_timer) % 2
		AnimState.WALK:
			var walk_fps: float = 13.0 if _boost_timer > 0.0 else 10.0
			_anim_timer += delta * walk_fps
			row = 2 + (int(_anim_timer) % 4)
		AnimState.ATTACK:
			var atk_fps: float = 15.0 if _boost_timer > 0.0 else 12.0
			_anim_timer += delta * atk_fps
			var step: int = int(_anim_timer)
			if step >= 2 and not _attack_action_done:
				_execute_attack_action()
			if step >= 4:
				_is_attacking = false
				_set_anim_state(AnimState.IDLE)
				row = 0
			else:
				row = 6 + step

	_sprite.frame_coords = Vector2i(col, row)


func _compute_doom_angle_col() -> int:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return 0
	var to_cam: Vector3 = cam.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.0001:
		return 0
	to_cam = to_cam.normalized()

	var fwd: Vector3 = _facing_dir
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()

	var ang_rad: float = atan2(fwd.cross(to_cam).y, fwd.dot(to_cam))
	return int(round(fposmod(rad_to_deg(ang_rad), 360.0) / 45.0)) % 8


func _update_sprite_modulate() -> void:
	if _sprite == null:
		return
	if _hurt_flash_timer > 0.085:
		_sprite.modulate = Color(2.45, 2.3, 2.3, 1.0)
	elif _hurt_flash_timer > 0.0:
		_sprite.modulate = Color(1.75, 0.45, 0.45, 1.0)
	elif _boost_timer > 0.0:
		var glow: float = 1.05 + 0.18 * sin(Time.get_ticks_msec() * 0.012)
		_sprite.modulate = Color(0.75, 1.25 * glow, 0.8, 1.0)
	else:
		_sprite.modulate = Color.WHITE


func _update_footsteps(delta: float) -> void:
	if _step_audio == null:
		return
	var horiz: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz > 0.8:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = 0.34 if _boost_timer > 0.0 else 0.44
			_step_audio.pitch_scale = randf_range(0.88, 1.12)
			_step_audio.play()
	else:
		_footstep_timer = 0.1


func _update_saw_loop(player: Node3D) -> void:
	if _loop_audio == null:
		return
	var should_buzz: bool = _alerted and player != null and global_position.distance_to(player.global_position) <= 8.0
	if should_buzz:
		if _loop_audio.stream == null and ResourceLoader.exists(SFX_SAW_LOOP):
			_loop_audio.stream = load(SFX_SAW_LOOP) as AudioStream
		if not _loop_audio.playing:
			_loop_audio.play()
	elif _loop_audio.playing:
		_loop_audio.stop()


func _play_3d(player_3d: AudioStreamPlayer3D, path: String, pitch: float = 1.0) -> void:
	if player_3d == null or path.is_empty() or not ResourceLoader.exists(path):
		return
	player_3d.stream = load(path) as AudioStream
	player_3d.pitch_scale = pitch
	player_3d.play()


func _get_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D
