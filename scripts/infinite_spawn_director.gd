extends Node3D
class_name InfiniteSpawnDirector

const STAGE_ENEMY_POOLS: Dictionary = {
	InfiniteWorldManager.StageKind.HOSPITAL: [
		{"path": "res://scenes/enemies/doctor_scalpel.tscn", "weight": 35},
		{"path": "res://scenes/enemies/doctor_hammer.tscn", "weight": 30},
		{"path": "res://scenes/enemies/doctor_saw.tscn", "weight": 25},
		{"path": "res://scenes/enemies/police_baton.tscn", "weight": 6},
		{"path": "res://scenes/enemies/police_pistol.tscn", "weight": 4},
	],
	InfiniteWorldManager.StageKind.MILITARY: [
		{"path": "res://scenes/enemies/soldier_rifle.tscn", "weight": 38},
		{"path": "res://scenes/enemies/soldier_bazooka.tscn", "weight": 24},
		{"path": "res://scenes/enemies/soldier_booster.tscn", "weight": 18},
		{"path": "res://scenes/enemies/police_shield.tscn", "weight": 10},
		{"path": "res://scenes/enemies/police_pistol.tscn", "weight": 10},
	],
	InfiniteWorldManager.StageKind.CITY: [
		{"path": "res://scenes/enemies/police_baton.tscn", "weight": 18},
		{"path": "res://scenes/enemies/police_shield.tscn", "weight": 16},
		{"path": "res://scenes/enemies/police_pistol.tscn", "weight": 22},
		{"path": "res://scenes/enemies/soldier_rifle.tscn", "weight": 18},
		{"path": "res://scenes/enemies/soldier_bazooka.tscn", "weight": 11},
		{"path": "res://scenes/enemies/soldier_booster.tscn", "weight": 8},
		{"path": "res://scenes/enemies/doctor_saw.tscn", "weight": 7},
	],
}

const RANDOM_PICKUP_POOL: Array[Dictionary] = [
	{"path": "res://scenes/pickups/speed_boost.tscn", "weight": 26},
	{"path": "res://scenes/pickups/shield_boost.tscn", "weight": 22},
	{"path": "res://scenes/pickups/medkit.tscn", "weight": 22},
	{"path": "res://scenes/pickups/pistol.tscn", "weight": 16},
	{"path": "res://scenes/pickups/shotgun.tscn", "weight": 14},
]

@export var world_manager_path: NodePath = NodePath("../InfiniteWorld")
@export var max_active_enemies: int = 20
@export var spawn_check_interval: float = 0.55
@export var spawn_batch_size: int = 3
@export var initial_wave_count: int = 6
@export var min_spawn_dist: float = 12.0
@export var max_spawn_dist: float = 36.0
@export var despawn_dist: float = 62.0
@export var chunk_pickup_chance: float = 0.42

var _world: InfiniteWorldManager = null
var _player: Node3D = null
var _enemies_container: Node3D
var _pickups_container: Node3D
var _active_enemies: Array[Node3D] = []
var _chunk_pickups: Dictionary = {} # Vector2i -> Array[Node3D]
var _scene_cache: Dictionary = {} # path -> PackedScene
var _spawn_timer: float = 0.2
var _starter_spawned: bool = false
var _initial_wave_done: bool = false


func _ready() -> void:
	_enemies_container = Node3D.new()
	_enemies_container.name = "DynamicEnemies"
	add_child(_enemies_container)

	_pickups_container = Node3D.new()
	_pickups_container.name = "DynamicPickups"
	add_child(_pickups_container)

	_world = get_node_or_null(world_manager_path) as InfiniteWorldManager
	if _world == null:
		_world = get_tree().get_first_node_in_group("infinite_world") as InfiniteWorldManager

	if _world != null:
		_world.chunk_loaded.connect(_on_chunk_loaded)
		_world.chunk_unloaded.connect(_on_chunk_unloaded)
		call_deferred("_spawn_starter_room_pickups")


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null or _world == null:
		return

	if not _initial_wave_done:
		var init_candidates: Array[Vector3] = _world.get_walkable_points_in_range(_player.global_position, min_spawn_dist, max_spawn_dist)
		if init_candidates.size() >= 6:
			_initial_wave_done = true
			for i: int in range(mini(initial_wave_count, max_active_enemies)):
				var pt: Vector3 = _pick_spaced_spawn_point(init_candidates)
				if pt == Vector3.INF:
					break
				_spawn_random_enemy_at(pt)

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = spawn_check_interval

	_prune_and_despawn_enemies()

	var needed: int = max_active_enemies - _active_enemies.size()
	if needed <= 0:
		return

	# Spawn scaled batch per stage intensity (Hospital < Military < City!)
	var batch: int = mini(needed, maxi(1, spawn_batch_size))
	var candidates: Array[Vector3] = _world.get_walkable_points_in_range(_player.global_position, min_spawn_dist, max_spawn_dist)
	if candidates.is_empty():
		return

	for i: int in range(batch):
		var chosen: Vector3 = _pick_spaced_spawn_point(candidates)
		if chosen == Vector3.INF:
			break
		_spawn_random_enemy_at(chosen)


func _spawn_starter_room_pickups() -> void:
	if _starter_spawned or _world == null:
		return
	_starter_spawned = true

	var floor_y: float = 0.3
	match _world.stage_kind:
		InfiniteWorldManager.StageKind.HOSPITAL:
			_spawn_pickup_exact(Vector2i.ZERO, "res://scenes/pickups/pistol.tscn", Vector3(-3.0, floor_y, -3.0))
			_spawn_pickup_exact(Vector2i.ZERO, "res://scenes/pickups/medkit.tscn", Vector3(3.0, floor_y, -3.0))
			_spawn_pickup_exact(Vector2i.ZERO, "res://scenes/pickups/speed_boost.tscn", Vector3(0.0, floor_y, -5.5))
		InfiniteWorldManager.StageKind.MILITARY:
			_spawn_pickup_exact(Vector2i.ZERO, "res://scenes/pickups/shotgun.tscn", Vector3(-3.0, floor_y, -3.5))
			_spawn_pickup_exact(Vector2i.ZERO, "res://scenes/pickups/speed_boost.tscn", Vector3(3.0, floor_y, -3.5))
			_spawn_pickup_exact(Vector2i.ZERO, "res://scenes/pickups/shield_boost.tscn", Vector3(0.0, floor_y, 4.0))
		InfiniteWorldManager.StageKind.CITY:
			_spawn_pickup_exact(Vector2i.ZERO, "res://scenes/pickups/pistol.tscn", Vector3(-3.0, floor_y, -3.5))
			_spawn_pickup_exact(Vector2i.ZERO, "res://scenes/pickups/shotgun.tscn", Vector3(3.0, floor_y, -3.5))
			_spawn_pickup_exact(Vector2i.ZERO, "res://scenes/pickups/shield_boost.tscn", Vector3(0.0, floor_y, -6.0))


func _on_chunk_loaded(coord: Vector2i, walkable_points: Array[Vector3]) -> void:
	if coord == Vector2i.ZERO or walkable_points.is_empty():
		return

	# Deterministic random pickup chance per newly streamed chunk
	var h: int = absi((coord.x * 73856093) ^ (coord.y * 19349663) ^ (_world.world_seed * 83492791))
	var roll: float = float(h % 1000) / 1000.0
	if roll > chunk_pickup_chance:
		return

	var pt_idx: int = (h >> 4) % walkable_points.size()
	var spawn_pos: Vector3 = walkable_points[pt_idx]
	var pickup_path: String = _pick_weighted_from_pool(RANDOM_PICKUP_POOL, h >> 8)
	_spawn_pickup_exact(coord, pickup_path, spawn_pos)


func _on_chunk_unloaded(coord: Vector2i) -> void:
	if not _chunk_pickups.has(coord):
		return
	var arr: Array = _chunk_pickups[coord] as Array
	for item_var: Variant in arr:
		if is_instance_valid(item_var):
			(item_var as Node).queue_free()
	_chunk_pickups.erase(coord)


func _spawn_pickup_exact(coord: Vector2i, scene_path: String, world_pos: Vector3) -> void:
	var ps: PackedScene = _get_cached_scene(scene_path)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate() as Node3D
	if inst == null:
		return
	_pickups_container.add_child(inst)
	inst.global_position = world_pos
	if not _chunk_pickups.has(coord):
		_chunk_pickups[coord] = []
	(_chunk_pickups[coord] as Array).append(inst)


func _prune_and_despawn_enemies() -> void:
	var p_pos: Vector3 = _player.global_position
	var despawn_sq: float = despawn_dist * despawn_dist

	for i: int in range(_active_enemies.size() - 1, -1, -1):
		var e: Node3D = _active_enemies[i]
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			_active_enemies.remove_at(i)
			continue
		var dead_val: Variant = e.get("_is_dead")
		if dead_val != null and bool(dead_val):
			_active_enemies.remove_at(i)
			continue
		var d_sq: float = Vector2(e.global_position.x - p_pos.x, e.global_position.z - p_pos.z).length_squared()
		if d_sq > despawn_sq:
			e.queue_free()
			_active_enemies.remove_at(i)


func _pick_spaced_spawn_point(candidates: Array[Vector3]) -> Vector3:
	for attempt: int in range(8):
		var idx: int = randi() % candidates.size()
		var p: Vector3 = candidates[idx]
		var too_close: bool = false
		for e: Node3D in _active_enemies:
			if is_instance_valid(e) and p.distance_squared_to(e.global_position) < 9.0:
				too_close = true
				break
		if not too_close:
			return p
	return Vector3.INF


func _spawn_random_enemy_at(world_pos: Vector3) -> void:
	var pool: Array = STAGE_ENEMY_POOLS.get(_world.stage_kind, STAGE_ENEMY_POOLS[InfiniteWorldManager.StageKind.HOSPITAL]) as Array
	var scene_path: String = _pick_weighted_from_pool(pool, randi())
	var ps: PackedScene = _get_cached_scene(scene_path)
	if ps == null:
		return
	var enemy: Node3D = ps.instantiate() as Node3D
	if enemy == null:
		return
	_enemies_container.add_child(enemy)
	enemy.global_position = world_pos
	_active_enemies.append(enemy)


func _pick_weighted_from_pool(pool: Array, rng_int: int) -> String:
	var total_w: int = 0
	for item_var: Variant in pool:
		total_w += int((item_var as Dictionary)["weight"])
	if total_w <= 0:
		return str((pool[0] as Dictionary)["path"])
	var roll: int = absi(rng_int) % total_w
	var acc: int = 0
	for item_var2: Variant in pool:
		var d: Dictionary = item_var2 as Dictionary
		acc += int(d["weight"])
		if roll < acc:
			return str(d["path"])
	return str((pool[0] as Dictionary)["path"])


func _get_cached_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path] as PackedScene
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path) as PackedScene
	if ps != null:
		_scene_cache[path] = ps
	return ps
