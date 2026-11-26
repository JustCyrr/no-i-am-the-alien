extends FPSArm

const DEFAULT_IDLE_PATH: String = "res://assets/hands/right_arm_idle.png"
const DEFAULT_FRAMES_DIR: String = "res://assets/hands/right_arm_punch_frames"
const DEFAULT_FRAME_COUNT: int = 10


func _init() -> void:
	arm_side = "right"
	punch_fps = 20.0
	impact_frame = 5
	punch_offset = Vector2(-18.0, 6.0)
	punch_scale = Vector2(1.16, 1.16)
	punch_rotation_deg = -1.5
	bob_phase_offset = PI


func _load_default_textures() -> void:
	if idle_texture == null and ResourceLoader.exists(DEFAULT_IDLE_PATH):
		idle_texture = load(DEFAULT_IDLE_PATH) as Texture2D
	if punch_textures.is_empty():
		var loaded: Array[Texture2D] = []
		for i: int in range(DEFAULT_FRAME_COUNT):
			var frame_path: String = "%s/frame_%02d.png" % [DEFAULT_FRAMES_DIR, i]
			if ResourceLoader.exists(frame_path):
				var tex: Texture2D = load(frame_path) as Texture2D
				if tex != null:
					loaded.append(tex)
		punch_textures = loaded
