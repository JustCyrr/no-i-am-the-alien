extends Area3D
class_name Projectile3D

enum ProjectileKind {
	PISTOL,
	RIFLE,
	BAZOOKA,
}

const PISTOL_SHEET: String = "res://assets/projectiles/pistol_bullet/spritesheet.png"
const RIFLE_SHEET: String = "res://assets/projectiles/rifle_bullet/spritesheet.png"
const ROCKET_SHEET: String = "res://assets/projectiles/bazooka_rocket/spritesheet.png"

const EXPLOSION_SHEET: String = "res://assets/particles/explosion/spritesheet.png"
const HIT_SPARKS_SHEET: String = "res://assets/particles/hit_sparks/spritesheet.png"
const SMOKE_PUFF_SHEET: String = "res://assets/particles/smoke_puff/spritesheet.png"

const SFX_BULLET_WHIZ: String = "res://assets/audio/bullet_whiz.wav"
const SFX_BULLET_IMPACT: String = "res://assets/audio/bullet_impact.wav"
const SFX_ROCKET_FLY: String = "res://assets/audio/rocket_fly.wav"
const SFX_EXPLOSION: String = "res://assets/audio/explosion.wav"

var kind: ProjectileKind = ProjectileKind.PISTOL
var travel_dir: Vector3 = Vector3.FORWARD
var speed: float = 16.0
var damage: int = 1
var parried_enemy_damage: float = 25.0
var explosion_radius: float = 4.5
var lifetime: float = 4.0
var shooter: Node = null
var is_parried: bool = false

var _sprite: Sprite3D
var _flight_audio: AudioStreamPlayer3D
var _whiz_audio: AudioStreamPlayer3D
var _whiz_played: bool = false
var _anim_timer: float = 0.0
var _smoke_timer: float = 0.0
var _age: float = 0.0
var _parry_wall_grace: float = 0.0
var _has_detonated: bool = false


static func spawn(
	parent_node: Node,
	world_pos: Vector3,
	direction: Vector3,
	proj_kind: ProjectileKind,
	proj_shooter: Node = null,
	speed_multiplier: float = 1.0
) -> Projectile3D:
	var proj: Projectile3D = Projectile3D.new()
	proj.kind = proj_kind
	proj.travel_dir = direction.normalized()
	proj.shooter = proj_shooter
	proj.collision_layer = 4
	proj.collision_mask = 17 # Player (1) + World Obstacles (16)
	proj.monitoring = true
	proj.monitorable = false

	match proj_kind:
		ProjectileKind.PISTOL:
			proj.speed = 15.0 * speed_multiplier
			proj.damage = 1
			proj.parried_enemy_damage = 25.0
			proj.lifetime = 3.5
		ProjectileKind.RIFLE:
			proj.speed = 21.0 * speed_multiplier
			proj.damage = 1
			proj.parried_enemy_damage = 25.0
			proj.lifetime = 3.5
		ProjectileKind.BAZOOKA:
			proj.speed = 12.5 * speed_multiplier
			proj.damage = 2
			proj.parried_enemy_damage = 85.0
			proj.explosion_radius = 4.5
			proj.lifetime = 5.0

	parent_node.add_child(proj)
	proj.global_position = world_pos
	return proj


func _ready() -> void:
	add_to_group("projectiles")

	var col: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.28 if kind == ProjectileKind.BAZOOKA else 0.16
	col.shape = sphere
	add_child(col)

	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.hframes = 8

	match kind:
		ProjectileKind.PISTOL:
			_sprite.vframes = 1
			_sprite.pixel_size = 0.018
			if ResourceLoader.exists(PISTOL_SHEET):
				_sprite.texture = load(PISTOL_SHEET) as Texture2D
		ProjectileKind.RIFLE:
			_sprite.vframes = 1
			_sprite.pixel_size = 0.018
			if ResourceLoader.exists(RIFLE_SHEET):
				_sprite.texture = load(RIFLE_SHEET) as Texture2D
		ProjectileKind.BAZOOKA:
			_sprite.vframes = 2
			_sprite.pixel_size = 0.024
			if ResourceLoader.exists(ROCKET_SHEET):
				_sprite.texture = load(ROCKET_SHEET) as Texture2D
	add_child(_sprite)

	if kind == ProjectileKind.BAZOOKA and ResourceLoader.exists(SFX_ROCKET_FLY):
		_flight_audio = AudioStreamPlayer3D.new()
		_flight_audio.stream = load(SFX_ROCKET_FLY) as AudioStream
		_flight_audio.volume_db = -4.0
		_flight_audio.unit_size = 6.0
		_flight_audio.max_distance = 32.0
		_flight_audio.bus = &"EnemySFX"
		add_child(_flight_audio)
		_flight_audio.play()
	elif ResourceLoader.exists(SFX_BULLET_WHIZ):
		_whiz_audio = AudioStreamPlayer3D.new()
		_whiz_audio.stream = load(SFX_BULLET_WHIZ) as AudioStream
		_whiz_audio.volume_db = -8.0
		_whiz_audio.unit_size = 4.0
		_whiz_audio.max_distance = 14.0
		_whiz_audio.bus = &"EnemySFX"
		add_child(_whiz_audio)

	body_entered.connect(_on_body_entered)
	_update_doom_angle()


func deflect(aim_origin: Vector3, aim_dir: Vector3, parrier: Node) -> bool:
	if is_parried or _has_detonated:
		return false

	is_parried = true
	_age = 0.0
	_whiz_played = true
	_parry_wall_grace = 0.07

	var launch_dir: Vector3 = aim_dir.normalized()
	var old_pos: Vector3 = global_position

	# Prevent Area3D overlap triggers while switching mask and repositioning
	set_deferred("monitoring", false)
	collision_mask = 18 # Enemies (2) + World Obstacles (16)
	shooter = parrier

	# Safe launch point in front of camera, never underground/inside floor
	var launch_pos: Vector3 = aim_origin + launch_dir * 1.15
	if parrier is Node3D:
		var parrier_3d: Node3D = parrier as Node3D
		launch_pos.y = maxf(launch_pos.y, parrier_3d.global_position.y + 0.65)

	global_position = launch_pos
	travel_dir = launch_dir
	speed *= 1.85
	if kind == ProjectileKind.BAZOOKA:
		explosion_radius = 5.5

	if _sprite != null:
		_sprite.modulate = Color(2.0, 1.75, 0.55, 1.0)
		_sprite.pixel_size *= 1.25

	var root_scene: Node = get_tree().current_scene
	if root_scene != null:
		SpriteFX3D.spawn(root_scene, old_pos, HIT_SPARKS_SHEET, 4, 1, 16.0, 0.032)

	_update_doom_angle()
	return true


func _physics_process(delta: float) -> void:
	if _has_detonated:
		return

	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	if _parry_wall_grace > 0.0:
		_parry_wall_grace = maxf(0.0, _parry_wall_grace - delta)

	# Race-condition guard: if player is actively parrying and this unparried projectile is right in front of them, parry it BEFORE any explosion!
	if not is_parried and _try_intercept_by_player_parry():
		return

	var step_vec: Vector3 = travel_dir * speed * delta
	var active_mask: int = collision_mask
	if is_parried and _parry_wall_grace > 0.0:
		active_mask = 2 # Only hit enemies during the first 70ms after parry so nearby walls/floor never blow up in your face

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + step_vec,
		active_mask
	)
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_obj: Object = hit["collider"] as Object
		# Double guard: if about to hit player who is actively parrying, deflect instead of exploding!
		if not is_parried and hit_obj != null and hit_obj.has_method("can_parry_projectile") and bool(hit_obj.call("can_parry_projectile")):
			if hit_obj.has_method("parry_projectile") and bool(hit_obj.call("parry_projectile", self)):
				return
		global_position = hit["position"] as Vector3
		_detonate(hit_obj)
		return

	global_position += step_vec
	_update_doom_angle()

	if kind == ProjectileKind.BAZOOKA:
		_anim_timer += delta * 14.0
		if _flight_audio != null and not _flight_audio.playing:
			_flight_audio.play()
		_smoke_timer += delta
		if _smoke_timer >= 0.055:
			_smoke_timer = 0.0
			var root_scene: Node = get_tree().current_scene
			if root_scene != null:
				SpriteFX3D.spawn(
					root_scene,
					global_position - travel_dir * 0.25,
					SMOKE_PUFF_SHEET,
					4,
					1,
					10.0,
					0.02
				)
	elif not is_parried:
		_check_bullet_whiz()


func _try_intercept_by_player_parry() -> bool:
	var player_node: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player_node == null:
		return false
	if not player_node.has_method("can_parry_projectile") or not bool(player_node.call("can_parry_projectile")):
		return false
	var dist: float = global_position.distance_to(player_node.global_position + Vector3(0.0, 1.35, 0.0))
	if dist <= 5.0 and player_node.has_method("parry_projectile"):
		return bool(player_node.call("parry_projectile", self))
	return false


func _check_bullet_whiz() -> void:
	if _whiz_played or _whiz_audio == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	if global_position.distance_to(cam.global_position) <= 4.2:
		_whiz_played = true
		_whiz_audio.pitch_scale = randf_range(0.92, 1.12)
		_whiz_audio.play()


func _update_doom_angle() -> void:
	if _sprite == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return

	var fwd: Vector3 = Vector3(travel_dir.x, 0.0, travel_dir.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()

	var to_cam: Vector3 = cam.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.0001:
		return
	to_cam = to_cam.normalized()

	var ang_rad: float = atan2(fwd.cross(to_cam).y, fwd.dot(to_cam))
	var col: int = int(round(fposmod(rad_to_deg(ang_rad), 360.0) / 45.0)) % 8
	var row: int = int(_anim_timer) % _sprite.vframes
	_sprite.frame_coords = Vector2i(col, row)


func _on_body_entered(body: Node3D) -> void:
	if _has_detonated or body == shooter:
		return
	if not is_parried and body != null and body.has_method("can_parry_projectile") and bool(body.call("can_parry_projectile")):
		if body.has_method("parry_projectile") and bool(body.call("parry_projectile", self)):
			return
	if is_parried and _parry_wall_grace > 0.0 and not body.is_in_group("enemies"):
		return
	_detonate(body)


func _detonate(direct_hit: Object) -> void:
	if _has_detonated:
		return
	_has_detonated = true

	var root_scene: Node = get_tree().current_scene

	if kind == ProjectileKind.BAZOOKA:
		if root_scene != null:
			SpriteFX3D.spawn(
				root_scene,
				global_position,
				EXPLOSION_SHEET,
				6,
				1,
				14.0,
				0.06 if is_parried else 0.05,
				SFX_EXPLOSION,
				1.5 if is_parried else 1.0
			)
			SpriteFX3D.spawn(
				root_scene,
				global_position + Vector3(0.0, 0.45, 0.0),
				SMOKE_PUFF_SHEET,
				4,
				1,
				9.0,
				0.045
			)
		# Bazooka always deals area splash damage!
		if is_parried:
			for node: Node in get_tree().get_nodes_in_group("enemies"):
				if not (node is Node3D):
					continue
				var enemy_3d: Node3D = node as Node3D
				var dist_e: float = global_position.distance_to(enemy_3d.global_position + Vector3(0.0, 1.0, 0.0))
				if dist_e <= explosion_radius:
					if enemy_3d.has_method("on_parried_hit"):
						enemy_3d.call("on_parried_hit", parried_enemy_damage, global_position)
					elif enemy_3d.has_method("on_punched"):
						enemy_3d.call("on_punched", parried_enemy_damage, global_position, "parry")
		else:
			# Area damage to Player
			var player_node: Node3D = get_tree().get_first_node_in_group("player") as Node3D
			if player_node != null:
				var dist_p: float = global_position.distance_to(player_node.global_position + Vector3(0.0, 0.9, 0.0))
				if dist_p <= explosion_radius and player_node.has_method("take_damage"):
					player_node.call("take_damage", damage, global_position)
			# Area splash also hits enemies standing in the explosion
			for node: Node in get_tree().get_nodes_in_group("enemies"):
				if node == shooter or not (node is Node3D):
					continue
				var ally_3d: Node3D = node as Node3D
				var dist_a: float = global_position.distance_to(ally_3d.global_position + Vector3(0.0, 1.0, 0.0))
				if dist_a <= explosion_radius and ally_3d.has_method("on_parried_hit"):
					ally_3d.call("on_parried_hit", 30.0, global_position)
	else:
		if is_parried:
			if direct_hit != null:
				if direct_hit.has_method("on_parried_hit"):
					direct_hit.call("on_parried_hit", parried_enemy_damage, global_position)
				elif direct_hit.has_method("on_punched"):
					direct_hit.call("on_punched", parried_enemy_damage, global_position, "parry")
		else:
			if direct_hit != null and direct_hit.has_method("take_damage"):
				direct_hit.call("take_damage", damage, global_position)
		if root_scene != null:
			SpriteFX3D.spawn(
				root_scene,
				global_position,
				HIT_SPARKS_SHEET,
				4,
				1,
				14.0,
				0.025 if is_parried else 0.022,
				SFX_BULLET_IMPACT,
				-3.0
			)

	queue_free()
