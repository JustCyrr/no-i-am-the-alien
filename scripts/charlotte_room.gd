extends Node3D

const CHARLOTTE_TEX_PATH: String = "res://assets/easter_egg/charlotte.jpg"
const PLAYER_SCENE_PATH: String = "res://scenes/player.tscn"

const ROOM_W: float = 11.0
const ROOM_H: float = 7.5
const ROOM_D: float = 11.0


func _ready() -> void:
	_build_charlotte_box()
	_build_banner_hud()
	_spawn_player()


func _build_charlotte_box() -> void:
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.94, 0.90)
	env.ambient_light_energy = 1.15
	env_node.environment = env
	add_child(env_node)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(CHARLOTTE_TEX_PATH):
		mat.albedo_texture = load(CHARLOTTE_TEX_PATH) as Texture2D

	var box_body: StaticBody3D = StaticBody3D.new()
	box_body.name = "CharlotteBox"
	box_body.collision_layer = 16
	box_body.collision_mask = 0
	add_child(box_body)

	# 6 crisp full-UV QuadMesh faces so Charlotte's adorable face fills every wall, floor & ceiling cleanly!
	# North Wall (-Z, facing +Z toward player)
	_add_wall_quad(box_body, mat, Vector3(0.0, ROOM_H * 0.5, -ROOM_D * 0.5), Vector3(0.0, 0.0, 0.0), Vector2(ROOM_W, ROOM_H))
	# South Wall (+Z, facing -Z)
	_add_wall_quad(box_body, mat, Vector3(0.0, ROOM_H * 0.5, ROOM_D * 0.5), Vector3(0.0, 180.0, 0.0), Vector2(ROOM_W, ROOM_H))
	# West Wall (-X, facing +X)
	_add_wall_quad(box_body, mat, Vector3(-ROOM_W * 0.5, ROOM_H * 0.5, 0.0), Vector3(0.0, 90.0, 0.0), Vector2(ROOM_D, ROOM_H))
	# East Wall (+X, facing -X)
	_add_wall_quad(box_body, mat, Vector3(ROOM_W * 0.5, ROOM_H * 0.5, 0.0), Vector3(0.0, -90.0, 0.0), Vector2(ROOM_D, ROOM_H))
	# Floor (Y=0, facing +Y)
	_add_wall_quad(box_body, mat, Vector3(0.0, 0.0, 0.0), Vector3(-90.0, 0.0, 0.0), Vector2(ROOM_W, ROOM_D))
	# Ceiling (Y=ROOM_H, facing -Y)
	_add_wall_quad(box_body, mat, Vector3(0.0, ROOM_H, 0.0), Vector3(90.0, 0.0, 0.0), Vector2(ROOM_W, ROOM_D))

	# Solid invisible box collision boundaries
	_add_collider(box_body, Vector3(0.0, -0.25, 0.0), Vector3(ROOM_W, 0.5, ROOM_D))
	_add_collider(box_body, Vector3(0.0, ROOM_H + 0.25, 0.0), Vector3(ROOM_W, 0.5, ROOM_D))
	_add_collider(box_body, Vector3(0.0, ROOM_H * 0.5, -ROOM_D * 0.5 - 0.25), Vector3(ROOM_W, ROOM_H, 0.5))
	_add_collider(box_body, Vector3(0.0, ROOM_H * 0.5, ROOM_D * 0.5 + 0.25), Vector3(ROOM_W, ROOM_H, 0.5))
	_add_collider(box_body, Vector3(-ROOM_W * 0.5 - 0.25, ROOM_H * 0.5, 0.0), Vector3(0.5, ROOM_H, ROOM_D))
	_add_collider(box_body, Vector3(ROOM_W * 0.5 + 0.25, ROOM_H * 0.5, 0.0), Vector3(0.5, ROOM_H, ROOM_D))


func _add_wall_quad(parent: Node3D, mat: Material, pos: Vector3, rot_deg: Vector3, sz: Vector2) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = sz
	qm.material = mat
	mi.mesh = qm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)


func _add_collider(parent: StaticBody3D, pos: Vector3, sz: Vector3) -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = sz
	col.shape = shape
	col.position = pos
	parent.add_child(col)


func _build_banner_hud() -> void:
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 19
	add_child(cl)

	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.offset_left = -280.0
	panel.offset_right = 280.0
	panel.offset_top = 18.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.14, 0.02, 0.03, 0.90), Color(1.0, 0.35, 0.40, 1.0), 2, 18.0, 10.0)
	)
	cl.add_child(panel)

	var lbl: Label = Label.new()
	lbl.text = "CHARLOTTE'S SECRET BOX  //  TYPE 'CHARLOTTE' AGAIN TO RETURN"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	if mono_h != null:
		lbl.add_theme_font_override("font", mono_h)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	panel.add_child(lbl)


func _spawn_player() -> void:
	if not ResourceLoader.exists(PLAYER_SCENE_PATH):
		return
	var ps: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	if ps == null:
		return
	var p: Node3D = ps.instantiate() as Node3D
	p.name = "Player"
	p.position = Vector3(0.0, 0.2, 2.5)
	add_child(p)
