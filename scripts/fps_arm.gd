extends TextureRect
class_name FPSArm

signal punch_impact(arm_side: String)
signal punch_finished(arm_side: String)

@export var arm_side: String = "left"
@export var idle_texture: Texture2D
@export var punch_textures: Array[Texture2D] = []

@export_group("Frame Animation")
@export var punch_fps: float = 20.0
@export var impact_frame: int = 5

@export_group("Motion Accent")
@export var rest_offset: Vector2 = Vector2.ZERO
@export var punch_offset: Vector2 = Vector2(26.0, -12.0)
@export var punch_scale: Vector2 = Vector2(1.06, 1.06)
@export var punch_rotation_deg: float = 3.5

@export_group("Idle & Walk Bob")
@export var idle_sway_speed: float = 2.0
@export var idle_sway_amount: Vector2 = Vector2(2.5, 4.0)
@export var walk_bob_speed: float = 9.5
@export var walk_bob_amount: Vector2 = Vector2(7.0, 9.0)
@export var bob_phase_offset: float = 0.0

var _is_punching: bool = false
var _bob_time: float = 0.0
var _bob_offset: Vector2 = Vector2.ZERO
var _anim_offset: Vector2 = Vector2.ZERO
var _anim_scale: Vector2 = Vector2.ONE
var _anim_rotation_deg: float = 0.0
var _impact_jolt: Vector2 = Vector2.ZERO
var _impact_stick_token: int = 0
var _motion_tween: Tween
var _frame_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pivot_offset = _get_arm_pivot()
	_load_default_textures()
	_apply_idle_texture()
	_apply_transform()


func _get_arm_pivot() -> Vector2:
	if arm_side == "right":
		return Vector2(size.x, size.y)
	return Vector2(0.0, size.y)


func _load_default_textures() -> void:
	pass


func set_arm_textures(new_idle: Texture2D, new_punch_frames: Array[Texture2D] = []) -> void:
	idle_texture = new_idle
	punch_textures = new_punch_frames
	if not _is_punching:
		_apply_idle_texture()


func is_punching() -> bool:
	return _is_punching


func update_bob(delta: float, move_ratio: float, on_floor: bool) -> void:
	var target_bob: Vector2 = Vector2.ZERO
	if not _is_punching:
		if on_floor and move_ratio > 0.05:
			_bob_time += delta * walk_bob_speed
			target_bob = Vector2(
				cos(_bob_time + bob_phase_offset) * walk_bob_amount.x * move_ratio,
				absf(sin(_bob_time + bob_phase_offset)) * walk_bob_amount.y * move_ratio
			)
		else:
			_bob_time += delta * idle_sway_speed
			target_bob = Vector2(
				sin(_bob_time + bob_phase_offset) * idle_sway_amount.x,
				cos(_bob_time * 1.3 + bob_phase_offset) * idle_sway_amount.y
			)
	_bob_offset = _bob_offset.lerp(target_bob, minf(1.0, delta * 12.0))
	if _impact_jolt.length_squared() > 0.05:
		_impact_jolt = _impact_jolt.lerp(Vector2.ZERO, minf(1.0, delta * 28.0))
	else:
		_impact_jolt = Vector2.ZERO
	_apply_transform()


func trigger_contact_impact(heavy: bool = false) -> void:
	# Stick the fist briefly on the contact pose with solid bone-crunch shudder!
	var side_dir: float = -1.0 if arm_side == "left" else 1.0
	var mag: float = 11.0 if heavy else 7.5
	_impact_jolt = Vector2(side_dir * mag, mag * 0.45)
	_apply_transform()

	_impact_stick_token += 1
	var my_token: int = _impact_stick_token
	var stick_dur: float = 0.050 if heavy else 0.032

	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.pause()
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.pause()

	await get_tree().create_timer(stick_dur, true, false, true).timeout
	if not is_inside_tree() or my_token != _impact_stick_token:
		return

	_impact_jolt = Vector2(-side_dir * (mag * 0.45), mag * 0.25)
	_apply_transform()
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.play()
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.play()


func play_punch() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()

	_is_punching = true
	pivot_offset = _get_arm_pivot()

	var frame_count: int = punch_textures.size()
	if frame_count > 1:
		var frame_dt: float = 1.0 / maxf(punch_fps, 1.0)
		var peak_idx: int = clampi(impact_frame, 1, frame_count - 1)
		var strike_dur: float = float(peak_idx) * frame_dt
		var recover_dur: float = float(frame_count - peak_idx) * frame_dt

		# Motion tween: grounded lunge to peak, then smooth return during retraction
		_motion_tween = create_tween()
		_motion_tween.tween_method(_set_anim_offset, _anim_offset, punch_offset, strike_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_motion_tween.parallel().tween_method(_set_anim_scale, _anim_scale, punch_scale, strike_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_motion_tween.parallel().tween_method(_set_anim_rotation_deg, _anim_rotation_deg, punch_rotation_deg, strike_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		_motion_tween.chain().tween_method(_set_anim_offset, punch_offset, Vector2.ZERO, recover_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_motion_tween.parallel().tween_method(_set_anim_scale, punch_scale, Vector2.ONE, recover_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_motion_tween.parallel().tween_method(_set_anim_rotation_deg, punch_rotation_deg, 0.0, recover_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Frame tween: exact sequential PNG frame stepping + impact trigger
		_frame_tween = create_tween()
		for i: int in range(frame_count):
			_frame_tween.tween_callback(_set_punch_frame.bind(i))
			if i == peak_idx:
				_frame_tween.tween_callback(_emit_punch_impact)
			_frame_tween.tween_interval(frame_dt)
		_frame_tween.tween_callback(_on_punch_complete)
	else:
		# Fallback procedural punch if only a single texture is assigned
		_motion_tween = create_tween()
		_motion_tween.tween_callback(_set_punch_frame.bind(0))
		_motion_tween.parallel().tween_method(_set_anim_offset, _anim_offset, punch_offset * 3.0, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_motion_tween.parallel().tween_method(_set_anim_scale, _anim_scale, Vector2(1.18, 1.18), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_motion_tween.chain().tween_callback(_emit_punch_impact)
		_motion_tween.chain().tween_interval(0.05)
		_motion_tween.chain().tween_callback(_apply_idle_texture)
		_motion_tween.parallel().tween_method(_set_anim_offset, punch_offset * 3.0, Vector2.ZERO, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_motion_tween.parallel().tween_method(_set_anim_scale, Vector2(1.18, 1.18), Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_motion_tween.chain().tween_callback(_on_punch_complete)


func _emit_punch_impact() -> void:
	punch_impact.emit(arm_side)


func _on_punch_complete() -> void:
	_is_punching = false
	_apply_idle_texture()
	punch_finished.emit(arm_side)


func _apply_idle_texture() -> void:
	if idle_texture != null:
		texture = idle_texture


func _set_punch_frame(frame_index: int) -> void:
	if punch_textures.is_empty():
		_apply_idle_texture()
		return
	var clamped: int = clampi(frame_index, 0, punch_textures.size() - 1)
	if punch_textures[clamped] != null:
		texture = punch_textures[clamped]


func _set_anim_offset(val: Vector2) -> void:
	_anim_offset = val
	_apply_transform()


func _set_anim_scale(val: Vector2) -> void:
	_anim_scale = val
	_apply_transform()


func _set_anim_rotation_deg(val: float) -> void:
	_anim_rotation_deg = val
	_apply_transform()


func _apply_transform() -> void:
	position = rest_offset + _bob_offset + _anim_offset + _impact_jolt
	scale = _anim_scale
	rotation_degrees = _anim_rotation_deg
