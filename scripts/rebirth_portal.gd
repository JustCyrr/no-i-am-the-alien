extends Area3D
class_name RebirthPortal

const TEX_GROUND_RING: String = "res://assets/particles/boost_aura/ground_circle_topdown.png"
const TEX_AURA_SHEET: String = "res://assets/particles/boost_aura/spritesheet.png"

@export_file("*.tscn") var next_stage_scene: String = ""
@export var portal_title: String = "REBIRTH PORTAL"
@export var portal_subtitle: String = "ENTER TO ASCEND TO NEXT STAGE"
@export var require_all_enemies_dead: bool = false
@export var accent_color: Color = Color(0.49, 1.0, 0.27, 1.0)

var _ring_sprite: Sprite3D
var _core_sprite: Sprite3D
var _beam_mesh: MeshInstance3D
var _light: OmniLight3D
var _label_3d: Label3D
var _time: float = 0.0
var _triggered: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Player
	monitoring = true
	monitorable = false

	_ensure_visuals()
	body_entered.connect(_on_body_entered)


func _ensure_visuals() -> void:
	if get_node_or_null("CollisionShape3D") == null:
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.radius = 1.45
		cyl.height = 3.2
		col.shape = cyl
		col.position = Vector3(0.0, 1.6, 0.0)
		add_child(col)

	# Ground pixel-art portal ring
	_ring_sprite = Sprite3D.new()
	_ring_sprite.name = "GroundRing"
	_ring_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_ring_sprite.shaded = false
	_ring_sprite.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_ring_sprite.position = Vector3(0.0, 0.08, 0.0)
	_ring_sprite.pixel_size = 0.042
	if ResourceLoader.exists(TEX_GROUND_RING):
		_ring_sprite.texture = load(TEX_GROUND_RING) as Texture2D
	add_child(_ring_sprite)

	# Energy Pillar Beam
	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.name = "PortalBeam"
	var beam_cyl: CylinderMesh = CylinderMesh.new()
	beam_cyl.top_radius = 1.15
	beam_cyl.bottom_radius = 1.35
	beam_cyl.height = 4.2
	beam_cyl.radial_segments = 12
	_beam_mesh.mesh = beam_cyl
	_beam_mesh.position = Vector3(0.0, 2.1, 0.0)
	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.22)
	_beam_mesh.material_override = beam_mat
	add_child(_beam_mesh)

	# Floating Pixel Core Aura
	_core_sprite = Sprite3D.new()
	_core_sprite.name = "PortalCore"
	_core_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_core_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_core_sprite.shaded = false
	_core_sprite.hframes = 6
	_core_sprite.vframes = 1
	_core_sprite.pixel_size = 0.032
	_core_sprite.position = Vector3(0.0, 1.55, 0.0)
	if ResourceLoader.exists(TEX_AURA_SHEET):
		_core_sprite.texture = load(TEX_AURA_SHEET) as Texture2D
	add_child(_core_sprite)

	# Beacon Light
	_light = OmniLight3D.new()
	_light.name = "PortalLight"
	_light.position = Vector3(0.0, 2.0, 0.0)
	_light.omni_range = 9.0
	_light.light_energy = 2.4
	_light.light_color = accent_color
	add_child(_light)

	# Floating World Label
	_label_3d = Label3D.new()
	_label_3d.name = "PortalLabel"
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_label_3d.position = Vector3(0.0, 3.45, 0.0)
	_label_3d.pixel_size = 0.0085
	_label_3d.font_size = 44
	_label_3d.outline_size = 10
	_label_3d.modulate = accent_color
	_label_3d.text = "%s\n%s" % [portal_title, portal_subtitle]
	add_child(_label_3d)


func _process(delta: float) -> void:
	_time += delta
	var unlocked: bool = _is_portal_unlocked()
	var active_col: Color = accent_color if unlocked else Color(0.90, 0.16, 0.16, 1.0)

	if _ring_sprite != null:
		_ring_sprite.rotation.y += delta * (1.8 if unlocked else 0.5)
		_ring_sprite.modulate = Color(active_col.r, active_col.g, active_col.b, 0.85)

	if _core_sprite != null:
		_core_sprite.frame = int(_time * 10.0) % 6
		_core_sprite.position.y = 1.55 + sin(_time * 2.6) * 0.18
		_core_sprite.modulate = active_col

	if _beam_mesh != null:
		_beam_mesh.rotation.y -= delta * 0.9
		var mat: StandardMaterial3D = _beam_mesh.material_override as StandardMaterial3D
		if mat != null:
			var pulse: float = 0.18 + 0.08 * sin(_time * 3.5)
			mat.albedo_color = Color(active_col.r, active_col.g, active_col.b, pulse if unlocked else 0.1)

	if _light != null:
		_light.light_color = active_col
		_light.light_energy = (2.2 + 0.5 * sin(_time * 4.0)) if unlocked else 1.0

	if _label_3d != null:
		_label_3d.modulate = active_col
		if unlocked:
			_label_3d.text = "%s\n[ %s ]" % [portal_title, portal_subtitle]
		else:
			var rem: int = _count_alive_enemies()
			_label_3d.text = "PORTAL LOCKED\n[ HOSTILES REMAINING: %d ]" % rem


func _is_portal_unlocked() -> bool:
	if not require_all_enemies_dead:
		return true
	return _count_alive_enemies() <= 0


func _count_alive_enemies() -> int:
	var count: int = 0
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			var dead_val: Variant = n.get("_is_dead")
			if dead_val == null or not bool(dead_val):
				count += 1
	return count


func _on_body_entered(body: Node3D) -> void:
	if _triggered or body == null or not body.is_in_group("player"):
		return
	if not _is_portal_unlocked():
		return
	_triggered = true
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm != null and sm.has_method("trigger_rebirth"):
		sm.call("trigger_rebirth", next_stage_scene)
