extends Node3D
class_name InfiniteWorldManager

signal chunk_loaded(chunk_coord: Vector2i, walkable_points: Array[Vector3])
signal chunk_unloaded(chunk_coord: Vector2i)

enum StageKind {
	HOSPITAL,
	MILITARY,
	CITY,
}

const TILE_SIZE: float = 4.0
const CHUNK_TILES: int = 4
const CHUNK_SIZE: float = TILE_SIZE * float(CHUNK_TILES) # 16.0m

const STAGE_MODEL_DEFS: Dictionary = {
	StageKind.HOSPITAL: {
		"base": "res://assets/environments/1_hospital_interior",
		"floor_y": 0.22,
		"ceiling_mat": "res://assets/environments/1_hospital_interior/materials/hosp_ceiling_panel.tres",
		"models": [
			"floor_tile",
			"wall_segment",
			"wall_bio_segment",
			"door_frame",
			"stasis_tank",
			"alien_operating_table",
			"medical_console",
			"bio_cabinet",
		],
		"extra_models": {},
	},
	StageKind.MILITARY: {
		"base": "res://assets/environments/2_military_base_exterior",
		"floor_y": 0.27,
		"ceiling_mat": "",
		"models": [
			"ground_slab",
			"bunker_wall",
			"bunker_building",
			"watchtower",
			"radar_dish",
			"ammo_crate",
			"barricade",
			"plasma_barrel",
		],
		# Extra cross-world v2 props for richer military outposts (captured alien cargo, field consoles, floodlights, beacons!)
		"extra_models": {
			"stasis_tank": "res://assets/environments/1_hospital_interior/models/stasis_tank_mesh.tres",
			"bio_cabinet": "res://assets/environments/1_hospital_interior/models/bio_cabinet_mesh.tres",
			"medical_console": "res://assets/environments/1_hospital_interior/models/medical_console_mesh.tres",
			"street_lamp": "res://assets/environments/3_city/models/street_lamp_mesh.tres",
			"holo_pillar": "res://assets/environments/3_city/models/holo_pillar_mesh.tres",
		},
	},
	StageKind.CITY: {
		"base": "res://assets/environments/3_city",
		"floor_y": 0.21,
		"ceiling_mat": "",
		"models": [
			"road_segment",
			"sidewalk_slab",
			"city_wall",
			"alien_house",
			"alien_tower_building",
			"alien_shop_kiosk",
			"street_lamp",
			"holo_pillar",
		],
		"extra_models": {},
	},
}

@export var stage_kind: StageKind = StageKind.HOSPITAL
@export var world_seed: int = 1337
@export var render_radius: int = 3
@export var unload_radius: int = 4
@export var max_chunks_per_frame: int = 2

var _player: Node3D = null
var _chunks_root: Node3D
var _loaded_chunks: Dictionary = {} # Vector2i -> Dictionary {node, walkable_points}
var _pending_queue: Array[Vector2i] = []
var _last_player_chunk: Vector2i = Vector2i(999999, 999999)

var _meshes: Dictionary = {} # model_name -> Mesh
var _base_faces: Dictionary = {} # model_name -> PackedVector3Array (exact 3D mesh triangles)
var _trimesh_cache: Dictionary = {} # "model|sx|sy|sz" -> ConcavePolygonShape3D
var _floor_y: float = 0.22
var _ceiling_mesh: BoxMesh = null


func _ready() -> void:
	add_to_group("infinite_world")
	_chunks_root = Node3D.new()
	_chunks_root.name = "LoadedChunks"
	add_child(_chunks_root)

	_load_stage_assets()

	_player = get_tree().get_first_node_in_group("player") as Node3D
	var start_chunk: Vector2i = Vector2i.ZERO
	if _player != null:
		start_chunk = world_to_chunk(_player.global_position)
	_last_player_chunk = start_chunk

	# Immediately stream the 3x3 area around spawn so player always starts on solid ground
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			_create_chunk(Vector2i(start_chunk.x + dx, start_chunk.y + dz))

	_refresh_chunk_queue(start_chunk)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	if _player != null:
		var p_chunk: Vector2i = world_to_chunk(_player.global_position)
		if p_chunk != _last_player_chunk:
			_last_player_chunk = p_chunk
			_refresh_chunk_queue(p_chunk)
			_unload_distant_chunks(p_chunk)

	var built_this_frame: int = 0
	while built_this_frame < max_chunks_per_frame and not _pending_queue.is_empty():
		var coord: Vector2i = _pending_queue.pop_front() as Vector2i
		if not _loaded_chunks.has(coord):
			_create_chunk(coord)
			built_this_frame += 1


func world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor((world_pos.x + CHUNK_SIZE * 0.5) / CHUNK_SIZE)),
		int(floor((world_pos.z + CHUNK_SIZE * 0.5) / CHUNK_SIZE))
	)


func chunk_to_world_center(coord: Vector2i) -> Vector3:
	return Vector3(float(coord.x) * CHUNK_SIZE, 0.0, float(coord.y) * CHUNK_SIZE)


func get_walkable_points_in_range(origin: Vector3, min_dist: float, max_dist: float) -> Array[Vector3]:
	var results: Array[Vector3] = []
	var min_sq: float = min_dist * min_dist
	var max_sq: float = max_dist * max_dist

	for coord_var: Variant in _loaded_chunks.keys():
		var c_data: Dictionary = _loaded_chunks[coord_var] as Dictionary
		var pts: Array = c_data["walkable_points"] as Array
		for p_var: Variant in pts:
			var p: Vector3 = p_var as Vector3
			var dx: float = p.x - origin.x
			var dz: float = p.z - origin.z
			var d_sq: float = dx * dx + dz * dz
			if d_sq >= min_sq and d_sq <= max_sq:
				results.append(p)
	return results


func get_nearest_walkable_point(target_pos: Vector3) -> Vector3:
	var best: Vector3 = Vector3(target_pos.x, _floor_y + 0.05, target_pos.z)
	var best_sq: float = INF
	var center_c: Vector2i = world_to_chunk(target_pos)

	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var c_key: Vector2i = Vector2i(center_c.x + dx, center_c.y + dz)
			if not _loaded_chunks.has(c_key):
				continue
			var c_data: Dictionary = _loaded_chunks[c_key] as Dictionary
			var pts: Array = c_data["walkable_points"] as Array
			for p_var: Variant in pts:
				var p: Vector3 = p_var as Vector3
				var d_sq: float = Vector2(p.x - target_pos.x, p.z - target_pos.z).length_squared()
				if d_sq < best_sq:
					best_sq = d_sq
					best = p
	return best


func _load_stage_assets() -> void:
	var def: Dictionary = STAGE_MODEL_DEFS[stage_kind] as Dictionary
	var base_dir: String = str(def["base"])
	_floor_y = float(def["floor_y"])
	_meshes.clear()
	_base_faces.clear()
	_trimesh_cache.clear()

	for m_var: Variant in (def["models"] as Array):
		var m_name: String = str(m_var)
		var mesh_path: String = "%s/models/%s_mesh.tres" % [base_dir, m_name]
		_register_mesh_asset(m_name, mesh_path)

	var extras: Dictionary = def["extra_models"] as Dictionary
	for extra_key: Variant in extras.keys():
		_register_mesh_asset(str(extra_key), str(extras[extra_key]))

	var ceil_mat_path: String = str(def["ceiling_mat"])
	if not ceil_mat_path.is_empty() and ResourceLoader.exists(ceil_mat_path):
		var base_mat: Material = load(ceil_mat_path) as Material
		if base_mat != null:
			var ceil_mat: Material = base_mat.duplicate() as Material
			if ceil_mat is ShaderMaterial:
				(ceil_mat as ShaderMaterial).set_shader_parameter("uv_scale", Vector2(4.0, 4.0))
				(ceil_mat as ShaderMaterial).set_shader_parameter("emission_energy", 1.75)
			_ceiling_mesh = BoxMesh.new()
			_ceiling_mesh.size = Vector3(CHUNK_SIZE, 0.22, CHUNK_SIZE)
			_ceiling_mesh.material = ceil_mat


func _register_mesh_asset(m_name: String, mesh_path: String) -> void:
	if not ResourceLoader.exists(mesh_path):
		return
	var m_res: Mesh = load(mesh_path) as Mesh
	if m_res == null:
		return
	_meshes[m_name] = m_res
	_base_faces[m_name] = m_res.get_faces()


func _get_trimesh_shape(model_name: String, scale_vec: Vector3) -> ConcavePolygonShape3D:
	var sx: float = snappedf(scale_vec.x, 0.05)
	var sy: float = snappedf(scale_vec.y, 0.05)
	var sz: float = snappedf(scale_vec.z, 0.05)
	var key: String = "%s|%.2f|%.2f|%.2f" % [model_name, sx, sy, sz]
	if _trimesh_cache.has(key):
		return _trimesh_cache[key] as ConcavePolygonShape3D

	if not _base_faces.has(model_name):
		return null
	var src_faces: PackedVector3Array = _base_faces[model_name] as PackedVector3Array
	if src_faces.is_empty():
		return null

	var scaled_faces: PackedVector3Array = PackedVector3Array()
	if is_equal_approx(sx, 1.0) and is_equal_approx(sy, 1.0) and is_equal_approx(sz, 1.0):
		scaled_faces = src_faces
	else:
		scaled_faces.resize(src_faces.size())
		for i: int in range(src_faces.size()):
			var v: Vector3 = src_faces[i]
			scaled_faces[i] = Vector3(v.x * sx, v.y * sy, v.z * sz)

	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(scaled_faces)
	_trimesh_cache[key] = shape
	return shape


func _refresh_chunk_queue(center: Vector2i) -> void:
	var desired: Array[Vector2i] = []
	for dx: int in range(-render_radius, render_radius + 1):
		for dz: int in range(-render_radius, render_radius + 1):
			var c: Vector2i = Vector2i(center.x + dx, center.y + dz)
			if not _loaded_chunks.has(c):
				desired.append(c)

	desired.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (a.x - center.x) * (a.x - center.x) + (a.y - center.y) * (a.y - center.y)
		var db: int = (b.x - center.x) * (b.x - center.x) + (b.y - center.y) * (b.y - center.y)
		return da < db
	)
	_pending_queue = desired


func _unload_distant_chunks(center: Vector2i) -> void:
	var to_remove: Array[Vector2i] = []
	for coord_var: Variant in _loaded_chunks.keys():
		var c: Vector2i = coord_var as Vector2i
		if maxi(absi(c.x - center.x), absi(c.y - center.y)) > unload_radius:
			to_remove.append(c)

	for c: Vector2i in to_remove:
		var data: Dictionary = _loaded_chunks[c] as Dictionary
		var node: Node3D = data["node"] as Node3D
		if is_instance_valid(node):
			node.queue_free()
		_loaded_chunks.erase(c)
		chunk_unloaded.emit(c)


func _create_chunk(coord: Vector2i) -> void:
	var chunk_node: Node3D = Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [coord.x, coord.y]
	var origin: Vector3 = chunk_to_world_center(coord)
	chunk_node.position = origin
	_chunks_root.add_child(chunk_node)

	var batches: Dictionary = {} # model_name -> Array[Transform3D]
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ChunkCollision"
	body.collision_layer = 16 # World Obstacles
	body.collision_mask = 0
	chunk_node.add_child(body)

	# Unified 16x16 floor slab collider
	var floor_col: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(CHUNK_SIZE, _floor_y, CHUNK_SIZE)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, _floor_y * 0.5, 0.0)
	body.add_child(floor_col)

	var walkable_local: Array[Vector3] = []

	match stage_kind:
		StageKind.HOSPITAL:
			_populate_hospital_chunk(coord, batches, body, chunk_node, walkable_local)
		StageKind.MILITARY:
			_populate_military_chunk(coord, batches, body, walkable_local)
		StageKind.CITY:
			_populate_city_chunk(coord, batches, body, walkable_local)

	for model_key: Variant in batches.keys():
		var m_name: String = str(model_key)
		var xforms: Array = batches[m_name] as Array
		if xforms.is_empty() or not _meshes.has(m_name):
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[m_name] as Mesh
		mm.instance_count = xforms.size()
		for i: int in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i] as Transform3D)

		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "MM_%s" % m_name
		mmi.multimesh = mm
		var casts_shadow: bool = (m_name == "alien_tower_building" or m_name == "watchtower" or m_name == "bunker_building")
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk_node.add_child(mmi)

	var walkable_world: Array[Vector3] = []
	for lp: Vector3 in walkable_local:
		walkable_world.append(origin + lp)

	_loaded_chunks[coord] = {
		"node": chunk_node,
		"walkable_points": walkable_world,
	}
	chunk_loaded.emit(coord, walkable_world)


func _add_batch_item(
	batches: Dictionary,
	body: StaticBody3D,
	model_name: String,
	local_pos: Vector3,
	rot_y_deg: float = 0.0,
	add_collision: bool = true,
	scale_vec: Vector3 = Vector3.ONE
) -> void:
	if not _meshes.has(model_name):
		return
	var sx: float = snappedf(scale_vec.x, 0.05)
	var sy: float = snappedf(scale_vec.y, 0.05)
	var sz: float = snappedf(scale_vec.z, 0.05)
	var snapped_scale: Vector3 = Vector3(sx, sy, sz)

	var basis: Basis = Basis(Vector3.UP, deg_to_rad(rot_y_deg)).scaled(snapped_scale)
	var xf: Transform3D = Transform3D(basis, local_pos)
	if not batches.has(model_name):
		batches[model_name] = []
	(batches[model_name] as Array).append(xf)

	if add_collision:
		# Exact per-triangle 3D mesh collision (ConcavePolygonShape3D, cached per model+scale!)
		# Players land accurately on stepped building roofs, walk between watchtower legs, and never float on invisible boxes!
		var trimesh: ConcavePolygonShape3D = _get_trimesh_shape(model_name, snapped_scale)
		if trimesh != null:
			var col: CollisionShape3D = CollisionShape3D.new()
			col.shape = trimesh
			col.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y_deg)), local_pos)
			body.add_child(col)


# ==============================================================================
# STAGE 1: BIO-HOSPITAL (v2) — LARGE STARTING ROOM + INFINITE CONNECTED LABYRINTH
# ==============================================================================
func _hospital_edge_open_north(cx: int, cz: int) -> bool:
	if (cx == 0 and cz == 0) or (cx == 0 and cz == 1):
		return true
	var h: int = _hash2d(cx, cz, world_seed + 101)
	return (h & 1) == 0 or (posmod(h, 9) == 0)


func _hospital_edge_open_west(cx: int, cz: int) -> bool:
	if (cx == 0 and cz == 0) or (cx == 1 and cz == 0):
		return true
	var h: int = _hash2d(cx - 1, cz, world_seed + 101)
	return (h & 1) == 1 or (posmod(h, 11) == 0)


func _populate_hospital_chunk(
	coord: Vector2i,
	batches: Dictionary,
	body: StaticBody3D,
	chunk_node: Node3D,
	walkable_local: Array[Vector3]
) -> void:
	for tx: int in range(CHUNK_TILES):
		for tz: int in range(CHUNK_TILES):
			_add_batch_item(batches, body, "floor_tile", _tile_center_local(tx, tz, 0.0), 0.0, false)

	if _ceiling_mesh != null:
		var ceil_mi: MeshInstance3D = MeshInstance3D.new()
		ceil_mi.name = "Ceiling"
		ceil_mi.mesh = _ceiling_mesh
		ceil_mi.position = Vector3(0.0, 3.33, 0.0)
		ceil_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk_node.add_child(ceil_mi)

		var ceil_col: CollisionShape3D = CollisionShape3D.new()
		var ceil_box: BoxShape3D = BoxShape3D.new()
		ceil_box.size = Vector3(CHUNK_SIZE, 0.22, CHUNK_SIZE)
		ceil_col.shape = ceil_box
		ceil_col.position = Vector3(0.0, 3.33, 0.0)
		body.add_child(ceil_col)

	var h: int = _hash2d(coord.x, coord.y, world_seed + 307)
	var north_open: bool = _hospital_edge_open_north(coord.x, coord.y)
	var west_open: bool = _hospital_edge_open_west(coord.x, coord.y)

	for i: int in range(CHUNK_TILES):
		var offset: float = (float(i) - 1.5) * TILE_SIZE
		var is_mid: bool = (i == 1 or i == 2)

		if not (north_open and is_mid):
			var w_model: String = "wall_bio_segment" if ((i + h) % 2 == 0) else "wall_segment"
			_add_batch_item(batches, body, w_model, Vector3(offset, _floor_y, -CHUNK_SIZE * 0.5), 0.0, true)

		if not (west_open and is_mid):
			var w_model2: String = "wall_bio_segment" if ((i + h + 1) % 2 == 0) else "wall_segment"
			_add_batch_item(batches, body, w_model2, Vector3(-CHUNK_SIZE * 0.5, _floor_y, offset), 90.0, true)

	var occupied: Dictionary = {}

	if coord == Vector2i.ZERO:
		_add_batch_item(batches, body, "stasis_tank", Vector3(-5.6, _floor_y, -5.6), 45.0, true)
		_add_batch_item(batches, body, "stasis_tank", Vector3(5.6, _floor_y, -5.6), -45.0, true)
		_add_batch_item(batches, body, "stasis_tank", Vector3(-5.6, _floor_y, 5.6), 135.0, true)
		_add_batch_item(batches, body, "stasis_tank", Vector3(5.6, _floor_y, 5.6), -135.0, true)
		_add_batch_item(batches, body, "medical_console", Vector3(-6.2, _floor_y, -2.8), 90.0, true)
		_add_batch_item(batches, body, "bio_cabinet", Vector3(6.2, _floor_y, 2.8), -90.0, true)
		occupied[Vector2i(0, 0)] = true
		occupied[Vector2i(3, 0)] = true
		occupied[Vector2i(0, 3)] = true
		occupied[Vector2i(3, 3)] = true

		var start_light: OmniLight3D = OmniLight3D.new()
		start_light.position = Vector3(0.0, 2.85, 0.0)
		start_light.light_color = Color(0.60, 1.0, 0.88)
		start_light.light_energy = 2.0
		start_light.omni_range = 20.0
		start_light.shadow_enabled = false
		chunk_node.add_child(start_light)
	else:
		var room_style: int = posmod(h, 5)
		match room_style:
			0:
				_add_batch_item(batches, body, "alien_operating_table", Vector3(-5.2, _floor_y, -5.0), 0.0, true)
				_add_batch_item(batches, body, "alien_operating_table", Vector3(5.2, _floor_y, 5.0), 180.0, true)
				_add_batch_item(batches, body, "medical_console", Vector3(5.6, _floor_y, -5.4), -90.0, true)
				occupied[Vector2i(0, 0)] = true
				occupied[Vector2i(3, 3)] = true
				occupied[Vector2i(3, 0)] = true
			1:
				_add_batch_item(batches, body, "stasis_tank", Vector3(-5.4, _floor_y, -5.4), 0.0, true)
				_add_batch_item(batches, body, "stasis_tank", Vector3(5.4, _floor_y, 5.4), 180.0, true)
				_add_batch_item(batches, body, "bio_cabinet", Vector3(-5.8, _floor_y, 5.2), 90.0, true)
				occupied[Vector2i(0, 0)] = true
				occupied[Vector2i(3, 3)] = true
				occupied[Vector2i(0, 3)] = true
			2:
				_add_batch_item(batches, body, "stasis_tank", Vector3(0.0, _floor_y, 0.0), float(posmod(h, 4)) * 90.0, true)
				_add_batch_item(batches, body, "bio_cabinet", Vector3(5.8, _floor_y, -5.8), 180.0, true)
				occupied[Vector2i(1, 1)] = true
				occupied[Vector2i(2, 2)] = true
				occupied[Vector2i(3, 0)] = true
			3:
				_add_batch_item(batches, body, "medical_console", Vector3(-5.8, _floor_y, 5.4), 90.0, true)
				_add_batch_item(batches, body, "bio_cabinet", Vector3(5.8, _floor_y, -5.4), -90.0, true)
				occupied[Vector2i(0, 3)] = true
				occupied[Vector2i(3, 0)] = true
			_:
				# Open clean hospital intersection (varied breathing room)
				pass

		if posmod(h, 2) == 0:
			var lamp: OmniLight3D = OmniLight3D.new()
			lamp.position = Vector3(0.0, 2.85, 0.0)
			lamp.light_color = Color(0.55, 0.98, 0.85)
			lamp.light_energy = 1.45
			lamp.omni_range = 17.0
			lamp.shadow_enabled = false
			chunk_node.add_child(lamp)

	for tx: int in range(CHUNK_TILES):
		for tz: int in range(CHUNK_TILES):
			if not occupied.has(Vector2i(tx, tz)):
				walkable_local.append(_tile_center_local(tx, tz, _floor_y + 0.05))


# ==============================================================================
# STAGE 2: MILITARY OUTPOST (v2) — DIVERSE OPEN WORLD WITH NATURAL EMPTY PLAINS
# ==============================================================================
func _populate_military_chunk(
	coord: Vector2i,
	batches: Dictionary,
	body: StaticBody3D,
	walkable_local: Array[Vector3]
) -> void:
	# Rotate individual ground slabs deterministically to break grid repetition!
	for tx: int in range(CHUNK_TILES):
		for tz: int in range(CHUNK_TILES):
			var th: int = _hash2d(coord.x * 4 + tx, coord.y * 4 + tz, world_seed + 19)
			var tile_rot: float = float(posmod(th, 4)) * 90.0
			_add_batch_item(batches, body, "ground_slab", _tile_center_local(tx, tz, 0.0), tile_rot, false)

	var occupied: Dictionary = {}
	var h: int = _hash2d(coord.x, coord.y, world_seed + 509)
	var macro_x: int = int(floor(float(coord.x) / 2.0))
	var macro_z: int = int(floor(float(coord.y) / 2.0))
	var macro_h: int = _hash2d(macro_x, macro_z, world_seed + 911)

	if coord == Vector2i.ZERO:
		# Open landing compound with 1 tall watchtower + light barricades & floodlight
		_add_batch_item(batches, body, "watchtower", Vector3(-5.8, _floor_y, -5.8), 0.0, true, Vector3(1.15, 1.35, 1.15))
		_add_batch_item(batches, body, "barricade", Vector3(5.0, _floor_y, -4.4), -25.0, true)
		_add_batch_item(batches, body, "ammo_crate", Vector3(5.8, _floor_y, 5.2), 15.0, true)
		_add_batch_item(batches, body, "street_lamp", Vector3(-6.2, _floor_y, 5.8), 45.0, true, Vector3(1.1, 1.25, 1.1))
		occupied[Vector2i(0, 0)] = true
		occupied[Vector2i(3, 0)] = true
		occupied[Vector2i(3, 3)] = true
		occupied[Vector2i(0, 3)] = true
	else:
		# ~38% wide open barren wasteland plains (so outposts feel distinct & varied!)
		var is_open_wasteland: bool = (posmod(macro_h, 10) < 3) or (posmod(h, 12) >= 8)
		var rot_base: float = float(posmod(h >> 3, 4)) * 90.0

		if is_open_wasteland:
			# Mostly empty open desert/battlefield — occasionally a single scattered prop
			var scatter: int = posmod(h >> 5, 5)
			if scatter == 0:
				_add_batch_item(batches, body, "barricade", Vector3(2.0, _floor_y, -1.5), rot_base + 22.0, true)
				occupied[Vector2i(2, 1)] = true
			elif scatter == 1:
				_add_batch_item(batches, body, "plasma_barrel", Vector3(-3.0, _floor_y, 2.5), 0.0, true)
				_add_batch_item(batches, body, "plasma_barrel", Vector3(-1.9, _floor_y, 3.1), 0.0, true)
				occupied[Vector2i(1, 2)] = true
			elif scatter == 2:
				_add_batch_item(batches, body, "ammo_crate", Vector3(0.0, _floor_y, 0.0), rot_base + 18.0, true)
				occupied[Vector2i(1, 1)] = true
			# scatter 3 & 4 = 100% completely empty open battleground!
		else:
			# 8 Unique Military Base / Alien Research Compound Layouts (no two areas feel identical!)
			var layout: int = posmod(h, 8)
			match layout:
				0:
					# Command HQ: Giant 1.45x Bunker with Roof-Mounted Radar Dish + Floodlight!
					_add_batch_item(batches, body, "bunker_building", Vector3(-1.0, _floor_y, -1.0), rot_base, true, Vector3(1.45, 1.35, 1.45))
					_add_batch_item(batches, body, "radar_dish", Vector3(-1.0, _floor_y + 6.9, -1.0), rot_base + 30.0, true, Vector3(1.1, 1.1, 1.1))
					_add_batch_item(batches, body, "barricade", Vector3(5.6, _floor_y, 4.8), rot_base + 90.0, true)
					_add_batch_item(batches, body, "street_lamp", Vector3(5.8, _floor_y, -5.8), -135.0, true, Vector3(1.1, 1.3, 1.1))
					for ox: int in range(0, 3):
						for oz: int in range(0, 3):
							occupied[Vector2i(ox, oz)] = true
					occupied[Vector2i(3, 3)] = true
				1:
					# Captured Alien Cargo & Field Bio-Lab (cross-world stasis tanks + field console + cabinets!)
					_add_batch_item(batches, body, "stasis_tank", Vector3(-3.8, _floor_y, -3.5), 0.0, true, Vector3(1.15, 1.15, 1.15))
					_add_batch_item(batches, body, "stasis_tank", Vector3(3.8, _floor_y, -3.5), 180.0, true, Vector3(1.15, 1.15, 1.15))
					_add_batch_item(batches, body, "medical_console", Vector3(0.0, _floor_y, -4.5), 0.0, true)
					_add_batch_item(batches, body, "bio_cabinet", Vector3(-5.8, _floor_y, 2.0), 90.0, true)
					_add_batch_item(batches, body, "bunker_wall", Vector3(0.0, _floor_y, -6.6), 0.0, true)
					_add_batch_item(batches, body, "barricade", Vector3(0.0, _floor_y, 5.2), 0.0, true)
					occupied[Vector2i(0, 0)] = true
					occupied[Vector2i(1, 0)] = true
					occupied[Vector2i(2, 0)] = true
					occupied[Vector2i(3, 0)] = true
					occupied[Vector2i(0, 2)] = true
					occupied[Vector2i(2, 3)] = true
				2:
					# High Comms Relay & Sniper Watchtower (giant 1.6x watchtower + 1.55x radar + holo beacon)
					_add_batch_item(batches, body, "watchtower", Vector3(-4.2, _floor_y, 4.0), rot_base, true, Vector3(1.25, 1.60, 1.25))
					_add_batch_item(batches, body, "radar_dish", Vector3(4.5, _floor_y, -4.2), rot_base + 50.0, true, Vector3(1.55, 1.55, 1.55))
					_add_batch_item(batches, body, "holo_pillar", Vector3(4.8, _floor_y, 4.8), 0.0, true, Vector3(1.1, 1.25, 1.1))
					occupied[Vector2i(0, 2)] = true
					occupied[Vector2i(0, 3)] = true
					occupied[Vector2i(1, 3)] = true
					occupied[Vector2i(3, 0)] = true
					occupied[Vector2i(3, 3)] = true
				3:
					# Explosive Plasma Fuel Farm (6 glowing barrels + L-shaped bunker wall protection)
					_add_batch_item(batches, body, "bunker_wall", Vector3(-4.0, _floor_y, -5.8), 0.0, true)
					_add_batch_item(batches, body, "bunker_wall", Vector3(-6.2, _floor_y, -3.5), 90.0, true)
					_add_batch_item(batches, body, "plasma_barrel", Vector3(-2.5, _floor_y, -2.5), 0.0, true)
					_add_batch_item(batches, body, "plasma_barrel", Vector3(-1.3, _floor_y, -2.5), 0.0, true)
					_add_batch_item(batches, body, "plasma_barrel", Vector3(-2.0, _floor_y, -1.4), 0.0, true)
					_add_batch_item(batches, body, "plasma_barrel", Vector3(3.4, _floor_y, 2.8), 0.0, true)
					_add_batch_item(batches, body, "plasma_barrel", Vector3(4.5, _floor_y, 2.2), 0.0, true)
					_add_batch_item(batches, body, "barricade", Vector3(3.5, _floor_y, -3.8), -45.0, true)
					occupied[Vector2i(0, 0)] = true
					occupied[Vector2i(1, 0)] = true
					occupied[Vector2i(1, 1)] = true
					occupied[Vector2i(3, 2)] = true
					occupied[Vector2i(3, 1)] = true
				4:
					# Twin-Wall Military Checkpoint Gate + Floodlights
					_add_batch_item(batches, body, "bunker_wall", Vector3(-5.0, _floor_y, 0.0), 0.0, true)
					_add_batch_item(batches, body, "bunker_wall", Vector3(5.0, _floor_y, 0.0), 0.0, true)
					_add_batch_item(batches, body, "barricade", Vector3(-1.5, _floor_y, 2.5), 15.0, true)
					_add_batch_item(batches, body, "barricade", Vector3(1.5, _floor_y, -2.5), -15.0, true)
					_add_batch_item(batches, body, "street_lamp", Vector3(-3.2, _floor_y, -1.2), 0.0, true, Vector3(1.1, 1.3, 1.1))
					_add_batch_item(batches, body, "street_lamp", Vector3(3.2, _floor_y, 1.2), 180.0, true, Vector3(1.1, 1.3, 1.1))
					occupied[Vector2i(0, 1)] = true
					occupied[Vector2i(0, 2)] = true
					occupied[Vector2i(3, 1)] = true
					occupied[Vector2i(3, 2)] = true
				5:
					# Stacked 2-Tier Munitions & Supply Depot
					_add_batch_item(batches, body, "ammo_crate", Vector3(-3.0, _floor_y, -2.5), 0.0, true, Vector3(1.25, 1.25, 1.25))
					_add_batch_item(batches, body, "ammo_crate", Vector3(-1.1, _floor_y, -2.5), 6.0, true, Vector3(1.25, 1.25, 1.25))
					_add_batch_item(batches, body, "ammo_crate", Vector3(-2.1, _floor_y + 1.08, -2.5), -8.0, true, Vector3(1.15, 1.15, 1.15))
					_add_batch_item(batches, body, "bio_cabinet", Vector3(4.5, _floor_y, -3.5), -90.0, true)
					_add_batch_item(batches, body, "plasma_barrel", Vector3(4.5, _floor_y, 3.2), 0.0, true)
					_add_batch_item(batches, body, "barricade", Vector3(-3.2, _floor_y, 4.8), 20.0, true)
					occupied[Vector2i(1, 1)] = true
					occupied[Vector2i(3, 1)] = true
					occupied[Vector2i(1, 3)] = true
				6:
					# Heavy Fortress Outpost (angled bunker + corner watchtower + holo marker)
					_add_batch_item(batches, body, "bunker_building", Vector3(-3.2, _floor_y, -3.0), rot_base + 15.0, true, Vector3(1.15, 1.2, 1.15))
					_add_batch_item(batches, body, "watchtower", Vector3(5.2, _floor_y, 4.6), rot_base, true, Vector3(1.15, 1.35, 1.15))
					_add_batch_item(batches, body, "holo_pillar", Vector3(4.8, _floor_y, -4.8), 0.0, true)
					occupied[Vector2i(0, 0)] = true
					occupied[Vector2i(1, 0)] = true
					occupied[Vector2i(0, 1)] = true
					occupied[Vector2i(1, 1)] = true
					occupied[Vector2i(3, 3)] = true
					occupied[Vector2i(3, 0)] = true
				_:
					# Lone Titan Watchtower Landmark in Wide Open Area (epic grapple swing anchor!)
					_add_batch_item(batches, body, "watchtower", Vector3(0.0, _floor_y, 0.0), rot_base, true, Vector3(1.35, 1.75, 1.35))
					occupied[Vector2i(1, 1)] = true
					occupied[Vector2i(2, 1)] = true
					occupied[Vector2i(1, 2)] = true
					occupied[Vector2i(2, 2)] = true

	for tx: int in range(CHUNK_TILES):
		for tz: int in range(CHUNK_TILES):
			if not occupied.has(Vector2i(tx, tz)):
				walkable_local.append(_tile_center_local(tx, tz, _floor_y + 0.05))


# ==============================================================================
# STAGE 3: XENO METROPOLIS (v2) — GIGANTIC SPIDER-MAN SKYSCRAPER OPEN WORLD!
# ==============================================================================
func _populate_city_chunk(
	coord: Vector2i,
	batches: Dictionary,
	body: StaticBody3D,
	walkable_local: Array[Vector3]
) -> void:
	var is_road_ns: bool = (posmod(coord.x, 3) == 0)
	var is_road_ew: bool = (posmod(coord.y, 3) == 0)
	var occupied: Dictionary = {}
	var h: int = _hash2d(coord.x, coord.y, world_seed + 821)

	if is_road_ns and is_road_ew:
		for tx: int in range(CHUNK_TILES):
			for tz: int in range(CHUNK_TILES):
				var on_ns: bool = (tx == 1 or tx == 2)
				var on_ew: bool = (tz == 1 or tz == 2)
				var lp: Vector3 = _tile_center_local(tx, tz, 0.0)
				if on_ns or on_ew:
					var r_deg: float = 90.0 if (on_ew and not on_ns) else 0.0
					_add_batch_item(batches, body, "road_segment", lp, r_deg, false)
				else:
					_add_batch_item(batches, body, "sidewalk_slab", lp, 0.0, false)

		_add_batch_item(batches, body, "street_lamp", Vector3(-5.2, _floor_y, -5.2), 45.0, true, Vector3(1.2, 1.3, 1.2))
		_add_batch_item(batches, body, "street_lamp", Vector3(5.2, _floor_y, 5.2), -135.0, true, Vector3(1.2, 1.3, 1.2))
		_add_batch_item(batches, body, "holo_pillar", Vector3(5.6, _floor_y, -5.6), 0.0, true, Vector3(1.25, 1.35, 1.25))
		_add_batch_item(batches, body, "holo_pillar", Vector3(-5.6, _floor_y, 5.6), 0.0, true, Vector3(1.25, 1.35, 1.25))
		occupied[Vector2i(0, 0)] = true
		occupied[Vector2i(3, 3)] = true
		occupied[Vector2i(3, 0)] = true
		occupied[Vector2i(0, 3)] = true

	elif is_road_ns:
		for tx: int in range(CHUNK_TILES):
			for tz: int in range(CHUNK_TILES):
				var lp: Vector3 = _tile_center_local(tx, tz, 0.0)
				if tx == 1 or tx == 2:
					_add_batch_item(batches, body, "road_segment", lp, 0.0, false)
				else:
					_add_batch_item(batches, body, "sidewalk_slab", lp, 0.0, false)

		_add_batch_item(batches, body, "street_lamp", Vector3(-4.8, _floor_y, -4.0), 90.0, true, Vector3(1.2, 1.3, 1.2))
		_add_batch_item(batches, body, "street_lamp", Vector3(4.8, _floor_y, 4.0), -90.0, true, Vector3(1.2, 1.3, 1.2))
		if posmod(h, 2) == 0:
			_add_batch_item(batches, body, "alien_shop_kiosk", Vector3(-6.0, _floor_y, 3.2), 90.0, true, Vector3(1.15, 1.2, 1.15))
			occupied[Vector2i(0, 2)] = true
			occupied[Vector2i(0, 3)] = true
		else:
			_add_batch_item(batches, body, "holo_pillar", Vector3(5.8, _floor_y, -3.5), 0.0, true, Vector3(1.25, 1.35, 1.25))
			occupied[Vector2i(3, 1)] = true

	elif is_road_ew:
		for tx: int in range(CHUNK_TILES):
			for tz: int in range(CHUNK_TILES):
				var lp: Vector3 = _tile_center_local(tx, tz, 0.0)
				if tz == 1 or tz == 2:
					_add_batch_item(batches, body, "road_segment", lp, 90.0, false)
				else:
					_add_batch_item(batches, body, "sidewalk_slab", lp, 0.0, false)

		_add_batch_item(batches, body, "street_lamp", Vector3(-4.0, _floor_y, -4.8), 0.0, true, Vector3(1.2, 1.3, 1.2))
		_add_batch_item(batches, body, "street_lamp", Vector3(4.0, _floor_y, 4.8), 180.0, true, Vector3(1.2, 1.3, 1.2))
		if posmod(h, 2) == 0:
			_add_batch_item(batches, body, "alien_shop_kiosk", Vector3(3.2, _floor_y, -6.0), 0.0, true, Vector3(1.15, 1.2, 1.15))
			occupied[Vector2i(2, 0)] = true
			occupied[Vector2i(3, 0)] = true
		else:
			_add_batch_item(batches, body, "holo_pillar", Vector3(-3.5, _floor_y, 5.8), 0.0, true, Vector3(1.25, 1.35, 1.25))
			occupied[Vector2i(1, 3)] = true

	else:
		# GIGANTIC SPIDER-MAN SKYSCRAPER CITY BLOCKS with EXACT stepped trimesh rooftop collisions!
		for tx: int in range(CHUNK_TILES):
			for tz: int in range(CHUNK_TILES):
				_add_batch_item(batches, body, "sidewalk_slab", _tile_center_local(tx, tz, 0.0), 0.0, false)

		var block_style: int = posmod(h, 5)
		var rot_b: float = float(posmod(h >> 2, 4)) * 90.0
		match block_style:
			0:
				var h_scale: float = 3.1 + float(posmod(h >> 4, 4)) * 0.25 # 43m - 54m tall!
				_add_batch_item(batches, body, "alien_tower_building", Vector3(0.0, _floor_y, 0.0), rot_b, true, Vector3(2.15, h_scale, 2.0))
				occupied[Vector2i(1, 1)] = true
				occupied[Vector2i(2, 1)] = true
				occupied[Vector2i(1, 2)] = true
				occupied[Vector2i(2, 2)] = true
				occupied[Vector2i(0, 1)] = true
				occupied[Vector2i(3, 2)] = true
			1:
				_add_batch_item(batches, body, "alien_tower_building", Vector3(-1.5, _floor_y, -1.5), rot_b, true, Vector3(1.85, 2.75, 1.75))
				_add_batch_item(batches, body, "alien_shop_kiosk", Vector3(5.2, _floor_y, 5.2), rot_b + 90.0, true, Vector3(1.2, 1.3, 1.2))
				occupied[Vector2i(0, 0)] = true
				occupied[Vector2i(1, 0)] = true
				occupied[Vector2i(2, 0)] = true
				occupied[Vector2i(0, 1)] = true
				occupied[Vector2i(1, 1)] = true
				occupied[Vector2i(2, 1)] = true
				occupied[Vector2i(3, 3)] = true
			2:
				_add_batch_item(batches, body, "alien_tower_building", Vector3(-2.2, _floor_y, -2.0), rot_b, true, Vector3(1.75, 3.25, 1.65))
				_add_batch_item(batches, body, "alien_house", Vector3(4.2, _floor_y, 4.2), rot_b + 180.0, true, Vector3(1.45, 2.35, 1.45))
				occupied[Vector2i(0, 0)] = true
				occupied[Vector2i(1, 0)] = true
				occupied[Vector2i(0, 1)] = true
				occupied[Vector2i(1, 1)] = true
				occupied[Vector2i(2, 2)] = true
				occupied[Vector2i(3, 2)] = true
				occupied[Vector2i(2, 3)] = true
				occupied[Vector2i(3, 3)] = true
			3:
				_add_batch_item(batches, body, "alien_tower_building", Vector3(0.0, _floor_y, 0.0), rot_b, true, Vector3(2.3, 4.0, 2.1))
				_add_batch_item(batches, body, "city_wall", Vector3(0.0, _floor_y, 7.2), 0.0, true)
				occupied[Vector2i(0, 0)] = true
				occupied[Vector2i(1, 0)] = true
				occupied[Vector2i(2, 0)] = true
				occupied[Vector2i(1, 1)] = true
				occupied[Vector2i(2, 1)] = true
				occupied[Vector2i(1, 2)] = true
				occupied[Vector2i(2, 2)] = true
				occupied[Vector2i(1, 3)] = true
				occupied[Vector2i(2, 3)] = true
			_:
				# Open Neon City Courtyard Plaza (varied breathing space between skyscrapers!)
				_add_batch_item(batches, body, "holo_pillar", Vector3(0.0, _floor_y, 0.0), 0.0, true, Vector3(1.5, 1.7, 1.5))
				_add_batch_item(batches, body, "alien_shop_kiosk", Vector3(-5.2, _floor_y, -5.2), 45.0, true, Vector3(1.2, 1.25, 1.2))
				occupied[Vector2i(1, 1)] = true
				occupied[Vector2i(2, 2)] = true
				occupied[Vector2i(0, 0)] = true

	for tx: int in range(CHUNK_TILES):
		for tz: int in range(CHUNK_TILES):
			if not occupied.has(Vector2i(tx, tz)):
				walkable_local.append(_tile_center_local(tx, tz, _floor_y + 0.05))


func _tile_center_local(tx: int, tz: int, y_val: float) -> Vector3:
	return Vector3(
		(float(tx) - 1.5) * TILE_SIZE,
		y_val,
		(float(tz) - 1.5) * TILE_SIZE
	)


func _hash2d(x: int, z: int, seed_val: int) -> int:
	var n: int = x * 374761393 + z * 668265263 + seed_val * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return absi(n)
