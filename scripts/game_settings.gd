extends Node

signal settings_changed()

const CONFIG_PATH: String = "user://settings.cfg"

const BUS_MASTER: StringName = &"Master"
const BUS_PLAYER_SFX: StringName = &"PlayerSFX"
const BUS_ENEMY_SFX: StringName = &"EnemySFX"

const BASE_MOUSE_SENS: float = 0.0025
const RETRO_SHADER_PATH: String = "res://shaders/v2/ps2_retro_postprocess.gdshader"

const SHADER_PRESETS: Array[Dictionary] = [
	{
		"name": "OFF",
		"enabled": false,
		"pixel_scale": 1.0,
		"color_steps": 32.0,
		"dither_strength": 0.0,
		"contrast": 1.0,
		"saturation": 1.0,
		"vignette": 0.0,
		"scanlines": 0.0,
	},
	{
		"name": "PS2 CLASSIC",
		"enabled": true,
		"pixel_scale": 1.65,
		"color_steps": 26.0,
		"dither_strength": 0.85,
		"contrast": 1.07,
		"saturation": 1.10,
		"vignette": 0.24,
		"scanlines": 0.0,
	},
	{
		"name": "ULTRAKILL",
		"enabled": true,
		"pixel_scale": 1.0,
		"color_steps": 30.0,
		"dither_strength": 0.65,
		"contrast": 1.09,
		"saturation": 1.14,
		"vignette": 0.18,
		"scanlines": 0.0,
	},
	{
		"name": "PS1 CRUNCH",
		"enabled": true,
		"pixel_scale": 2.6,
		"color_steps": 16.0,
		"dither_strength": 1.15,
		"contrast": 1.10,
		"saturation": 1.06,
		"vignette": 0.30,
		"scanlines": 0.14,
	},
]

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": "move_forward", "label": "Move Forward"},
	{"action": "move_back", "label": "Move Back"},
	{"action": "move_left", "label": "Move Left"},
	{"action": "move_right", "label": "Move Right"},
	{"action": "jump", "label": "Jump"},
	{"action": "sprint", "label": "Sprint"},
	{"action": "slide", "label": "Slide"},
	{"action": "attack", "label": "Attack / Shoot"},
	{"action": "parry", "label": "Parry"},
	{"action": "toggle_grapple", "label": "Toggle Grapple"},
	{"action": "grapple_fire", "label": "Fire Grapple"},
	{"action": "dash", "label": "Dash (Stage 3)"},
]

var master_volume: float = 1.0
var player_sfx_volume: float = 1.0
var enemy_sfx_volume: float = 1.0
var mouse_sensitivity_scale: float = 1.0
var fov: float = 75.0

var retro_shader_preset: int = 1 # Default ON: PS2 CLASSIC
var retro_pixel_scale: float = 1.65
var retro_color_steps: float = 26.0
var retro_dither_strength: float = 0.85
var retro_contrast: float = 1.07
var retro_saturation: float = 1.10
var retro_vignette: float = 0.24
var retro_scanlines: float = 0.0

var _default_events: Dictionary = {}
var _retro_layer: CanvasLayer
var _retro_rect: ColorRect
var _retro_mat: ShaderMaterial
var _last_checked_scene: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_snapshot_default_keybinds()
	_setup_retro_postprocess_layer()
	load_settings()
	apply_all()


func _process(_delta: float) -> void:
	var cur: Node = get_tree().current_scene
	var path: String = cur.scene_file_path if cur != null else ""
	if path != _last_checked_scene:
		_last_checked_scene = path
		_sync_retro_shader_for_scene(path)


func _setup_retro_postprocess_layer() -> void:
	_retro_layer = CanvasLayer.new()
	_retro_layer.name = "RetroPostProcessLayer"
	_retro_layer.layer = 5 # Above 3D world (0), below HandsLayer (10), HUD (18), PauseMenu (30)
	_retro_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_retro_layer)

	_retro_rect = ColorRect.new()
	_retro_rect.name = "PS2RetroPostProcess"
	_retro_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_retro_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retro_rect.color = Color.WHITE

	if ResourceLoader.exists(RETRO_SHADER_PATH):
		_retro_mat = ShaderMaterial.new()
		_retro_mat.shader = load(RETRO_SHADER_PATH) as Shader
		_retro_rect.material = _retro_mat

	_retro_layer.add_child(_retro_rect)
	_retro_layer.visible = false


func _is_3d_gameplay_scene(scene_path: String) -> bool:
	if scene_path.is_empty():
		return false
	if scene_path.ends_with("intro_cinematic.tscn") or scene_path.ends_with("main_menu.tscn"):
		return false
	return true


func _sync_retro_shader_for_scene(scene_path: String) -> void:
	var enabled_by_preset: bool = retro_shader_preset > 0
	var show_shader: bool = enabled_by_preset and _is_3d_gameplay_scene(scene_path)
	if _retro_layer != null:
		_retro_layer.visible = show_shader

	if _retro_mat == null:
		return

	var tint: Vector3 = Vector3(0.018, 0.028, 0.042)
	if scene_path.ends_with("stage_1_hospital.tscn"):
		tint = Vector3(0.012, 0.036, 0.038) # Clinical bio-teal shadows
	elif scene_path.ends_with("stage_2_military.tscn"):
		tint = Vector3(0.038, 0.020, 0.012) # Dusty rust-amber shadows
	elif scene_path.ends_with("stage_3_city.tscn"):
		tint = Vector3(0.024, 0.016, 0.048) # Deep indigo neon shadows
	elif scene_path.ends_with("charlotte_room.tscn"):
		tint = Vector3(0.028, 0.020, 0.024)

	_retro_mat.set_shader_parameter("pixel_scale", retro_pixel_scale)
	_retro_mat.set_shader_parameter("color_steps", retro_color_steps)
	_retro_mat.set_shader_parameter("dither_strength", retro_dither_strength)
	_retro_mat.set_shader_parameter("contrast", retro_contrast)
	_retro_mat.set_shader_parameter("saturation", retro_saturation)
	_retro_mat.set_shader_parameter("vignette_strength", retro_vignette)
	_retro_mat.set_shader_parameter("scanline_strength", retro_scanlines)
	_retro_mat.set_shader_parameter("shadow_tint", tint)


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index(BUS_PLAYER_SFX) == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_PLAYER_SFX)
		AudioServer.set_bus_send(idx, BUS_MASTER)
	if AudioServer.get_bus_index(BUS_ENEMY_SFX) == -1:
		var idx2: int = AudioServer.bus_count
		AudioServer.add_bus(idx2)
		AudioServer.set_bus_name(idx2, BUS_ENEMY_SFX)
		AudioServer.set_bus_send(idx2, BUS_MASTER)


func _snapshot_default_keybinds() -> void:
	_default_events.clear()
	for entry: Dictionary in REBINDABLE_ACTIONS:
		var act: String = str(entry["action"])
		if InputMap.has_action(act):
			var copies: Array[InputEvent] = []
			for ev: InputEvent in InputMap.action_get_events(act):
				copies.append(ev.duplicate() as InputEvent)
			_default_events[act] = copies


func get_mouse_sensitivity() -> float:
	return BASE_MOUSE_SENS * mouse_sensitivity_scale


func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	_apply_bus_volume(BUS_MASTER, master_volume)
	save_settings()
	settings_changed.emit()


func set_player_sfx_volume(val: float) -> void:
	player_sfx_volume = clampf(val, 0.0, 1.0)
	_apply_bus_volume(BUS_PLAYER_SFX, player_sfx_volume)
	save_settings()
	settings_changed.emit()


func set_enemy_sfx_volume(val: float) -> void:
	enemy_sfx_volume = clampf(val, 0.0, 1.0)
	_apply_bus_volume(BUS_ENEMY_SFX, enemy_sfx_volume)
	save_settings()
	settings_changed.emit()


func set_mouse_sensitivity_scale(val: float) -> void:
	mouse_sensitivity_scale = clampf(val, 0.15, 3.0)
	save_settings()
	settings_changed.emit()


func set_fov(val: float) -> void:
	fov = clampf(val, 65.0, 105.0)
	save_settings()
	settings_changed.emit()


func set_shader_preset(preset_idx: int) -> void:
	var idx: int = clampi(preset_idx, 0, SHADER_PRESETS.size() - 1)
	retro_shader_preset = idx
	var p: Dictionary = SHADER_PRESETS[idx]
	retro_pixel_scale = float(p["pixel_scale"])
	retro_color_steps = float(p["color_steps"])
	retro_dither_strength = float(p["dither_strength"])
	retro_contrast = float(p["contrast"])
	retro_saturation = float(p["saturation"])
	retro_vignette = float(p["vignette"])
	retro_scanlines = float(p["scanlines"])
	_sync_retro_shader_for_scene(_last_checked_scene)
	save_settings()
	settings_changed.emit()


func set_retro_pixel_scale(val: float) -> void:
	retro_pixel_scale = clampf(val, 1.0, 3.5)
	if retro_shader_preset == 0:
		retro_shader_preset = 1
	_sync_retro_shader_for_scene(_last_checked_scene)
	save_settings()
	settings_changed.emit()


func set_retro_dither_strength(val: float) -> void:
	retro_dither_strength = clampf(val, 0.0, 1.5)
	if retro_shader_preset == 0 and retro_dither_strength > 0.01:
		retro_shader_preset = 1
	_sync_retro_shader_for_scene(_last_checked_scene)
	save_settings()
	settings_changed.emit()


func set_retro_color_steps(val: float) -> void:
	retro_color_steps = clampf(val, 10.0, 48.0)
	if retro_shader_preset == 0:
		retro_shader_preset = 1
	_sync_retro_shader_for_scene(_last_checked_scene)
	save_settings()
	settings_changed.emit()


func rebind_action(action_name: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action_name) or new_event == null:
		return
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, new_event)
	save_settings()
	settings_changed.emit()


func reset_to_defaults() -> void:
	master_volume = 1.0
	player_sfx_volume = 1.0
	enemy_sfx_volume = 1.0
	mouse_sensitivity_scale = 1.0
	fov = 75.0
	retro_shader_preset = 1
	var p: Dictionary = SHADER_PRESETS[1]
	retro_pixel_scale = float(p["pixel_scale"])
	retro_color_steps = float(p["color_steps"])
	retro_dither_strength = float(p["dither_strength"])
	retro_contrast = float(p["contrast"])
	retro_saturation = float(p["saturation"])
	retro_vignette = float(p["vignette"])
	retro_scanlines = float(p["scanlines"])

	for act_key: Variant in _default_events.keys():
		var act: String = str(act_key)
		if not InputMap.has_action(act):
			continue
		InputMap.action_erase_events(act)
		var ev_list: Array = _default_events[act] as Array
		for ev_item: Variant in ev_list:
			if ev_item is InputEvent:
				InputMap.action_add_event(act, (ev_item as InputEvent).duplicate() as InputEvent)

	apply_all()
	save_settings()


func apply_all() -> void:
	_ensure_audio_buses()
	_apply_bus_volume(BUS_MASTER, master_volume)
	_apply_bus_volume(BUS_PLAYER_SFX, player_sfx_volume)
	_apply_bus_volume(BUS_ENEMY_SFX, enemy_sfx_volume)
	var cur: Node = get_tree().current_scene
	_last_checked_scene = cur.scene_file_path if cur != null else ""
	_sync_retro_shader_for_scene(_last_checked_scene)
	settings_changed.emit()


func _apply_bus_volume(bus_name: StringName, linear_val: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear_val <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_val))


func format_action_binding(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "UNBOUND"
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "UNBOUND"
	var ev: InputEvent = events[0]
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				return "LEFT CLICK"
			MOUSE_BUTTON_RIGHT:
				return "RIGHT CLICK"
			MOUSE_BUTTON_MIDDLE:
				return "MIDDLE CLICK"
			MOUSE_BUTTON_XBUTTON1:
				return "MOUSE 4"
			MOUSE_BUTTON_XBUTTON2:
				return "MOUSE 5"
			_:
				return "MOUSE %d" % int(mb.button_index)
	if ev is InputEventKey:
		var ke: InputEventKey = ev as InputEventKey
		var code: Key = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
		return OS.get_keycode_string(code).to_upper()
	return ev.as_text().to_upper()


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "player_sfx_volume", player_sfx_volume)
	cfg.set_value("audio", "enemy_sfx_volume", enemy_sfx_volume)
	cfg.set_value("controls", "mouse_sensitivity_scale", mouse_sensitivity_scale)
	cfg.set_value("controls", "fov", fov)
	cfg.set_value("video", "retro_shader_preset", retro_shader_preset)
	cfg.set_value("video", "retro_pixel_scale", retro_pixel_scale)
	cfg.set_value("video", "retro_color_steps", retro_color_steps)
	cfg.set_value("video", "retro_dither_strength", retro_dither_strength)
	cfg.set_value("video", "retro_contrast", retro_contrast)
	cfg.set_value("video", "retro_saturation", retro_saturation)
	cfg.set_value("video", "retro_vignette", retro_vignette)
	cfg.set_value("video", "retro_scanlines", retro_scanlines)

	for entry: Dictionary in REBINDABLE_ACTIONS:
		var act: String = str(entry["action"])
		if not InputMap.has_action(act):
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(act)
		if events.is_empty():
			continue
		var ev: InputEvent = events[0]
		if ev is InputEventMouseButton:
			var mb: InputEventMouseButton = ev as InputEventMouseButton
			cfg.set_value("keybinds", act, {"type": "mouse", "button": int(mb.button_index)})
		elif ev is InputEventKey:
			var ke: InputEventKey = ev as InputEventKey
			var code: Key = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
			cfg.set_value("keybinds", act, {"type": "key", "keycode": int(code)})

	cfg.save(CONFIG_PATH)


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return

	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	player_sfx_volume = clampf(float(cfg.get_value("audio", "player_sfx_volume", 1.0)), 0.0, 1.0)
	enemy_sfx_volume = clampf(float(cfg.get_value("audio", "enemy_sfx_volume", 1.0)), 0.0, 1.0)
	mouse_sensitivity_scale = clampf(float(cfg.get_value("controls", "mouse_sensitivity_scale", 1.0)), 0.15, 3.0)
	fov = clampf(float(cfg.get_value("controls", "fov", 75.0)), 65.0, 105.0)
	retro_shader_preset = clampi(int(cfg.get_value("video", "retro_shader_preset", 1)), 0, SHADER_PRESETS.size() - 1)
	var def_p: Dictionary = SHADER_PRESETS[retro_shader_preset]
	retro_pixel_scale = clampf(float(cfg.get_value("video", "retro_pixel_scale", def_p["pixel_scale"])), 1.0, 3.5)
	retro_color_steps = clampf(float(cfg.get_value("video", "retro_color_steps", def_p["color_steps"])), 10.0, 48.0)
	retro_dither_strength = clampf(float(cfg.get_value("video", "retro_dither_strength", def_p["dither_strength"])), 0.0, 1.5)
	retro_contrast = clampf(float(cfg.get_value("video", "retro_contrast", def_p["contrast"])), 0.85, 1.35)
	retro_saturation = clampf(float(cfg.get_value("video", "retro_saturation", def_p["saturation"])), 0.7, 1.4)
	retro_vignette = clampf(float(cfg.get_value("video", "retro_vignette", def_p["vignette"])), 0.0, 0.65)
	retro_scanlines = clampf(float(cfg.get_value("video", "retro_scanlines", def_p["scanlines"])), 0.0, 0.45)

	if cfg.has_section("keybinds"):
		for entry: Dictionary in REBINDABLE_ACTIONS:
			var act: String = str(entry["action"])
			if not InputMap.has_action(act) or not cfg.has_section_key("keybinds", act):
				continue
			var data_val: Variant = cfg.get_value("keybinds", act)
			if not (data_val is Dictionary):
				continue
			var data: Dictionary = data_val as Dictionary
			var ev_type: String = str(data.get("type", ""))
			if ev_type == "mouse":
				var mb: InputEventMouseButton = InputEventMouseButton.new()
				mb.button_index = int(data.get("button", MOUSE_BUTTON_LEFT)) as MouseButton
				InputMap.action_erase_events(act)
				InputMap.action_add_event(act, mb)
			elif ev_type == "key":
				var ke: InputEventKey = InputEventKey.new()
				var code: Key = int(data.get("keycode", KEY_NONE)) as Key
				ke.physical_keycode = code
				InputMap.action_erase_events(act)
				InputMap.action_add_event(act, ke)
