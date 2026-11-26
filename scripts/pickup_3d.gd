extends Area3D
class_name Pickup3D

enum PickupType {
	MEDKIT,
	SPEED_BOOST,
	SHIELD_BOOST,
	PISTOL,
	SHOTGUN,
}

const PICKUP_SHEETS: Dictionary = {
	PickupType.MEDKIT: "res://assets/pickups/medkit/medkit_spin_sheet.png",
	PickupType.SPEED_BOOST: "res://assets/pickups/speed_boost/speed_boost_spin_sheet.png",
	PickupType.SHIELD_BOOST: "res://assets/pickups/shield_boost/shield_boost_spin_sheet.png",
	PickupType.PISTOL: "res://assets/pickups/pistol/pistol_spin_sheet.png",
	PickupType.SHOTGUN: "res://assets/pickups/shotgun/shotgun_spin_sheet.png",
}

const PICKUP_SFX: Dictionary = {
	PickupType.MEDKIT: "res://assets/audio/medkit_pickup.wav",
	PickupType.SPEED_BOOST: "res://assets/audio/speed_boost_pickup.wav",
	PickupType.SHIELD_BOOST: "res://assets/audio/shield_boost_pickup.wav",
	PickupType.PISTOL: "res://assets/audio/weapons/weapon_equip_rack.wav",
	PickupType.SHOTGUN: "res://assets/audio/weapons/weapon_equip_rack.wav",
}

@export var pickup_type: PickupType = PickupType.MEDKIT
@export var spin_fps: float = 8.0
@export var bob_amplitude: float = 0.1
@export var bob_speed: float = 3.0
@export var sprite_pixel_size: float = 0.02

var _sprite: Sprite3D
var _spin_timer: float = 0.0
var _bob_timer: float = 0.0
var _base_sprite_y: float = 0.52
var _collected: bool = false


static func spawn(parent_node: Node, world_pos: Vector3, p_type: PickupType) -> Pickup3D:
	var item: Pickup3D = Pickup3D.new()
	item.pickup_type = p_type
	parent_node.add_child(item)
	item.global_position = world_pos
	return item


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 # Player only
	monitoring = true
	monitorable = false

	if get_node_or_null("CollisionShape3D") == null:
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.75
		col.shape = sphere
		col.position = Vector3(0.0, 0.55, 0.0)
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
	_sprite.vframes = 1
	_sprite.pixel_size = sprite_pixel_size
	_sprite.position = Vector3(0.0, _base_sprite_y, 0.0)

	var sheet_path: String = str(PICKUP_SHEETS.get(pickup_type, ""))
	if not sheet_path.is_empty() and ResourceLoader.exists(sheet_path):
		_sprite.texture = load(sheet_path) as Texture2D

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _collected or _sprite == null:
		return

	_spin_timer += delta * maxf(spin_fps, 1.0)
	_sprite.frame = int(_spin_timer) % 8

	_bob_timer += delta * bob_speed
	_sprite.position.y = _base_sprite_y + sin(_bob_timer) * bob_amplitude


func _physics_process(_delta: float) -> void:
	if _collected:
		return
	for body: Node3D in get_overlapping_bodies():
		if _try_give_to(body):
			return


func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	_try_give_to(body)


func _try_give_to(body: Node3D) -> bool:
	if body == null or not body.is_in_group("player"):
		return false

	var consumed: bool = false
	match pickup_type:
		PickupType.MEDKIT:
			if body.has_method("apply_medkit"):
				consumed = bool(body.call("apply_medkit", 1))
		PickupType.SPEED_BOOST:
			if body.has_method("apply_speed_boost"):
				body.call("apply_speed_boost", 6.0, 1.5)
				consumed = true
		PickupType.SHIELD_BOOST:
			if body.has_method("apply_shield_boost"):
				body.call("apply_shield_boost", 5.0)
				consumed = true
		PickupType.PISTOL:
			if body.has_method("pickup_weapon"):
				consumed = bool(body.call("pickup_weapon", "pistol"))
		PickupType.SHOTGUN:
			if body.has_method("pickup_weapon"):
				consumed = bool(body.call("pickup_weapon", "shotgun"))

	if not consumed:
		return false

	_collected = true
	var root_scene: Node = get_tree().current_scene
	var sfx_path: String = str(PICKUP_SFX.get(pickup_type, "res://assets/audio/boost_apply.wav"))
	if root_scene != null:
		SpriteFX3D.spawn(
			root_scene,
			global_position + Vector3(0.0, 0.6, 0.0),
			"res://assets/particles/boost_aura/spritesheet.png",
			6,
			1,
			14.0,
			0.022,
			sfx_path,
			-1.0,
			&"PlayerSFX"
		)
	queue_free()
	return true
