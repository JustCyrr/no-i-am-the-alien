extends Sprite3D
class_name SpriteFX3D

@export var fps: float = 14.0
@export var loop: bool = false

var _timer: float = 0.0
var _frame_count: int = 1
var _audio: AudioStreamPlayer3D


static func spawn(
	parent_node: Node,
	world_pos: Vector3,
	sheet_path: String,
	cols: int,
	rows: int,
	anim_fps: float,
	pixel_scale: float = 0.025,
	sfx_path: String = "",
	sfx_volume_db: float = -2.0,
	sfx_bus: StringName = &"EnemySFX"
) -> SpriteFX3D:
	var fx: SpriteFX3D = SpriteFX3D.new()
	fx.fps = anim_fps
	fx.hframes = cols
	fx.vframes = rows
	fx.frame = 0
	fx.pixel_size = pixel_scale
	fx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fx.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fx.shaded = false
	fx.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	if ResourceLoader.exists(sheet_path):
		fx.texture = load(sheet_path) as Texture2D

	parent_node.add_child(fx)
	fx.global_position = world_pos

	if not sfx_path.is_empty() and ResourceLoader.exists(sfx_path):
		var player_3d: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player_3d.stream = load(sfx_path) as AudioStream
		player_3d.volume_db = sfx_volume_db
		player_3d.unit_size = 8.0
		player_3d.max_distance = 35.0
		player_3d.pitch_scale = randf_range(0.93, 1.07)
		player_3d.bus = sfx_bus
		fx.add_child(player_3d)
		fx._audio = player_3d
		player_3d.play()

	return fx


func _ready() -> void:
	_frame_count = maxi(1, hframes * vframes)


func _process(delta: float) -> void:
	_timer += delta * maxf(fps, 1.0)
	var idx: int = int(_timer)
	if idx >= _frame_count:
		if loop:
			_timer = fmod(_timer, float(_frame_count))
			frame = int(_timer)
		else:
			visible = false
			if _audio != null and _audio.playing:
				set_process(false)
				_audio.finished.connect(queue_free)
			else:
				queue_free()
	else:
		frame = idx
