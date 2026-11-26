extends Node

signal stage_changed(stage_index: int, stage_title: String)
signal kills_updated(current_kills: int, required_kills: int)
signal rebirth_unlocked(stage_index: int)

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const CHARLOTTE_ROOM_SCENE: String = "res://scenes/charlotte_room.tscn"
const REBIRTH_PORTAL_SCENE: String = "res://scenes/props/shared/rebirth_portal.tscn"
const SFX_REBIRTH_PATH: String = "res://assets/audio/rebirth_portal.wav"
const SFX_UNLOCK_PATH: String = "res://assets/audio/parry_ring_chime.wav"

const CHEAT_SKIP_STAGE: String = "NOIAMTHEALIEN"
const CHEAT_CHARLOTTE: String = "CHARLOTTE"

const STAGES: Array[Dictionary] = [
	{
		"scene": "res://scenes/stages/stage_1_hospital.tscn",
		"code": "STAGE 01",
		"title": "BIO-HOSPITAL",
		"subtitle": "INFINITE LABYRINTH // ELIMINATE 50 ALIENS TO REBIRTH",
		"kills_required": 50,
		"accent": Color(0.30, 1.0, 0.65, 1.0),
	},
	{
		"scene": "res://scenes/stages/stage_2_military.tscn",
		"code": "STAGE 02",
		"title": "MILITARY OUTPOST",
		"subtitle": "GRAPPLE HOOK UNLOCKED // ELIMINATE 100 ALIENS TO REBIRTH",
		"kills_required": 100,
		"accent": Color(1.0, 0.58, 0.16, 1.0),
	},
	{
		"scene": "res://scenes/stages/stage_3_city.tscn",
		"code": "STAGE 03",
		"title": "XENO METROPOLIS",
		"subtitle": "GRAPPLE + [Q] DASH UNLOCKED // ELIMINATE 500 ALIENS TO ASCEND",
		"kills_required": 500,
		"accent": Color(0.95, 0.25, 0.85, 1.0),
	},
]

var current_stage_index: int = 0
var rebirth_count: int = 0
var stage_kills: int = 0
var total_kills: int = 0
var rebirth_ready: bool = false
var is_transitioning: bool = false

var _last_scene_path: String = ""
var _portal_spawned_for_stage: bool = false
var _cheat_buffer: String = ""

# Charlotte Secret Room return state
var _in_charlotte_room: bool = false
var _has_charlotte_return: bool = false
var _charlotte_return_scene: String = ""
var _charlotte_return_pos: Vector3 = Vector3(0.0, 0.35, 0.0)
var _charlotte_return_rot: Vector3 = Vector3.ZERO
var _charlotte_return_head_x: float = 0.0
var _charlotte_return_kills: int = 0
var _charlotte_return_stage_idx: int = 0
var _charlotte_return_rebirth_ready: bool = false
var _restoring_from_charlotte: bool = false

var _overlay_layer: CanvasLayer
var _hud_panel: PanelContainer
var _hud_stage_lbl: Label
var _hud_kills_lbl: Label
var _hud_bar_fill: ColorRect
var _hud_rebirth_hint: Label
var _hud_ability_hint: Label

var _flash_rect: ColorRect
var _banner_box: PanelContainer
var _banner_tag: Label
var _banner_title: Label
var _banner_sub: Label

var _complete_root: Control
var _complete_stats_lbl: Label
var _sfx_player: AudioStreamPlayer
var _pulse_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_player = MenuUIKit.make_sfx_player(self, "StageManagerSfx", -3.0)
	_build_overlay_ui()


func _process(delta: float) -> void:
	var cur_scene: Node = get_tree().current_scene
	var cur_path: String = cur_scene.scene_file_path if cur_scene != null else ""

	if cur_path != _last_scene_path:
		_last_scene_path = cur_path
		_on_scene_switched(cur_path)

	if rebirth_ready and _hud_rebirth_hint != null and _hud_rebirth_hint.visible:
		_pulse_time += delta * 6.0
		var alpha: float = 0.55 + 0.45 * sin(_pulse_time)
		_hud_rebirth_hint.modulate = Color(1.0, 1.0, 1.0, alpha)


func _input(event: InputEvent) -> void:
	if is_transitioning or get_tree().paused:
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			var code: Key = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
			if code >= KEY_A and code <= KEY_Z:
				var ch: String = char(int(code))
				_cheat_buffer += ch
				if _cheat_buffer.length() > 24:
					_cheat_buffer = _cheat_buffer.right(24)
				_check_secret_codes()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or is_transitioning or not rebirth_ready:
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_T:
			trigger_rebirth()
			get_viewport().set_input_as_handled()


func _check_secret_codes() -> void:
	var cur_scene: Node = get_tree().current_scene
	if cur_scene == null:
		return
	var cur_path: String = cur_scene.scene_file_path
	# Ignore secret codes on Main Menu / Intro Cinematic
	if cur_path.ends_with("main_menu.tscn") or cur_path.ends_with("intro_cinematic.tscn"):
		return

	if _cheat_buffer.ends_with(CHEAT_SKIP_STAGE):
		_cheat_buffer = ""
		if _in_charlotte_room:
			return
		var strict_idx: int = _get_active_stage_index_strict()
		if strict_idx >= 0:
			trigger_rebirth()
		return

	if _cheat_buffer.ends_with(CHEAT_CHARLOTTE):
		_cheat_buffer = ""
		_toggle_charlotte_room()
		return


func _toggle_charlotte_room() -> void:
	if _in_charlotte_room:
		# Return to exact previous stage, position, rotation, and kill count!
		if _has_charlotte_return and ResourceLoader.exists(_charlotte_return_scene):
			_in_charlotte_room = false
			_restoring_from_charlotte = true
			MenuUIKit.play_ui_sfx(_sfx_player, SFX_UNLOCK_PATH, 1.1)
			get_tree().change_scene_to_file(_charlotte_return_scene)
			call_deferred("_restore_player_after_charlotte")
		return

	# Save current exact location & stage progress, then enter Charlotte's Box!
	var cur_scene: Node = get_tree().current_scene
	if cur_scene == null or cur_scene.scene_file_path.is_empty():
		return
	if not ResourceLoader.exists(CHARLOTTE_ROOM_SCENE):
		return

	_charlotte_return_scene = cur_scene.scene_file_path
	_charlotte_return_kills = stage_kills
	_charlotte_return_stage_idx = current_stage_index
	_charlotte_return_rebirth_ready = rebirth_ready
	_charlotte_return_pos = Vector3(0.0, 0.35, 0.0)
	_charlotte_return_rot = Vector3.ZERO
	_charlotte_return_head_x = 0.0

	var p: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		_charlotte_return_pos = p.global_position
		_charlotte_return_rot = p.rotation
		var head_node: Node3D = p.get_node_or_null("Head") as Node3D
		if head_node != null:
			_charlotte_return_head_x = head_node.rotation.x

	_has_charlotte_return = true
	_in_charlotte_room = true
	MenuUIKit.play_ui_sfx(_sfx_player, SFX_UNLOCK_PATH, 1.35)
	get_tree().change_scene_to_file(CHARLOTTE_ROOM_SCENE)


func _restore_player_after_charlotte() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	current_stage_index = _charlotte_return_stage_idx
	stage_kills = _charlotte_return_kills
	rebirth_ready = _charlotte_return_rebirth_ready
	_restoring_from_charlotte = false
	_refresh_kill_hud()

	var p: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		p.global_position = _charlotte_return_pos
		p.rotation = _charlotte_return_rot
		var head_node: Node3D = p.get_node_or_null("Head") as Node3D
		if head_node != null:
			head_node.rotation.x = _charlotte_return_head_x


func is_grapple_unlocked() -> bool:
	var cur_scene: Node = get_tree().current_scene
	if cur_scene == null:
		return true
	var p: String = cur_scene.scene_file_path
	# Stage 1 (Hospital): Grapple LOCKED! Only Stage 2 & Stage 3 (plus sandbox/charlotte) have Grapple!
	if p.ends_with("stage_1_hospital.tscn"):
		return false
	return true


func is_dash_unlocked() -> bool:
	var cur_scene: Node = get_tree().current_scene
	if cur_scene == null:
		return false
	var p: String = cur_scene.scene_file_path
	# Dash [Q] is unlocked ONLY in Stage 3 (City) (plus sandbox/charlotte)!
	if p.ends_with("stage_3_city.tscn") or p.ends_with("main.tscn") or p.ends_with("charlotte_room.tscn"):
		return true
	return false


func _on_scene_switched(scene_path: String) -> void:
	_in_charlotte_room = scene_path.ends_with("charlotte_room.tscn")

	var matched_idx: int = -1
	for i: int in range(STAGES.size()):
		if str(STAGES[i]["scene"]) == scene_path:
			matched_idx = i
			break

	if matched_idx >= 0:
		current_stage_index = matched_idx
		if not _restoring_from_charlotte:
			stage_kills = 0
			rebirth_ready = false
			_portal_spawned_for_stage = false
		if _hud_panel != null:
			_hud_panel.visible = true
		_refresh_kill_hud()
	else:
		if _hud_panel != null:
			_hud_panel.visible = false
		if not _in_charlotte_room:
			rebirth_ready = false


func start_demo() -> void:
	rebirth_count = 0
	total_kills = 0
	stage_kills = 0
	current_stage_index = 0
	rebirth_ready = false
	_portal_spawned_for_stage = false
	_in_charlotte_room = false
	_has_charlotte_return = false
	_restoring_from_charlotte = false
	is_transitioning = false
	_hide_demo_complete()
	Engine.time_scale = 1.0
	get_tree().paused = false
	var first_scene: String = str(STAGES[0]["scene"])
	if ResourceLoader.exists(first_scene):
		get_tree().change_scene_to_file(first_scene)
		call_deferred("_show_stage_intro_banner", 0)


func reset_current_stage_progress() -> void:
	stage_kills = 0
	rebirth_ready = false
	_portal_spawned_for_stage = false
	_refresh_kill_hud()


func register_enemy_kill() -> void:
	var cur_idx: int = _get_active_stage_index_strict()
	if cur_idx < 0:
		return

	stage_kills += 1
	total_kills += 1
	var req: int = int(STAGES[cur_idx]["kills_required"])
	kills_updated.emit(stage_kills, req)

	if not rebirth_ready and stage_kills >= req:
		rebirth_ready = true
		rebirth_unlocked.emit(cur_idx)
		MenuUIKit.play_ui_sfx(_sfx_player, SFX_UNLOCK_PATH, 1.0)
		_spawn_rebirth_portal_near_player(cur_idx)

	_refresh_kill_hud()


func get_required_kills() -> int:
	var idx: int = clampi(current_stage_index, 0, STAGES.size() - 1)
	return int(STAGES[idx]["kills_required"])


func get_current_stage_index() -> int:
	var strict_idx: int = _get_active_stage_index_strict()
	if strict_idx >= 0:
		current_stage_index = strict_idx
	return current_stage_index


func _get_active_stage_index_strict() -> int:
	var cur_scene: Node = get_tree().current_scene
	if cur_scene != null and not cur_scene.scene_file_path.is_empty():
		for i: int in range(STAGES.size()):
			if str(STAGES[i]["scene"]) == cur_scene.scene_file_path:
				return i
	return -1


func get_current_stage_header() -> String:
	var idx: int = _get_active_stage_index_strict()
	if idx >= 0:
		return "%s // %s (%d/%d)" % [
			str(STAGES[idx]["code"]),
			str(STAGES[idx]["title"]),
			stage_kills,
			int(STAGES[idx]["kills_required"]),
		]
	var cur_scene: Node = get_tree().current_scene
	if cur_scene != null:
		if cur_scene.scene_file_path.ends_with("charlotte_room.tscn"):
			return "CHARLOTTE'S SECRET BOX"
		if cur_scene.scene_file_path.ends_with("main.tscn"):
			return "TEST ARENA // SANDBOX"
	return "NO! I AM THE ALIEN"


func _spawn_rebirth_portal_near_player(stage_idx: int) -> void:
	if _portal_spawned_for_stage or not ResourceLoader.exists(REBIRTH_PORTAL_SCENE):
		return
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	_portal_spawned_for_stage = true
	var ps: PackedScene = load(REBIRTH_PORTAL_SCENE) as PackedScene
	if ps == null:
		return
	var portal: Node3D = ps.instantiate() as Node3D
	portal.name = "ActiveRebirthPortal"

	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()

	var spawn_pos: Vector3 = player.global_position + fwd * 7.5
	spawn_pos.y = 0.25

	var world_mgr: Node = root_scene.get_node_or_null("InfiniteWorld")
	if world_mgr != null and world_mgr.has_method("get_nearest_walkable_point"):
		spawn_pos = world_mgr.call("get_nearest_walkable_point", spawn_pos) as Vector3

	var next_idx: int = stage_idx + 1
	if next_idx < STAGES.size():
		portal.set("next_stage_scene", str(STAGES[next_idx]["scene"]))
		portal.set("portal_title", "REBIRTH %s READY" % _to_roman(stage_idx + 1))
		portal.set("portal_subtitle", "ENTER FOR %s" % str(STAGES[next_idx]["title"]))
	else:
		portal.set("next_stage_scene", "")
		portal.set("portal_title", "FINAL REBIRTH")
		portal.set("portal_subtitle", "ENTER TO FINISH DEMO")
	portal.set("accent_color", STAGES[stage_idx]["accent"] as Color)
	portal.set("require_all_enemies_dead", false)

	root_scene.add_child(portal)
	portal.global_position = spawn_pos


func trigger_rebirth(override_next_scene: String = "") -> void:
	if is_transitioning:
		return
	is_transitioning = true

	var cur_idx: int = get_current_stage_index()
	var next_idx: int = cur_idx + 1
	var target_scene: String = override_next_scene
	var is_final_clear: bool = false

	if target_scene.is_empty():
		if next_idx < STAGES.size():
			target_scene = str(STAGES[next_idx]["scene"])
		else:
			is_final_clear = true
	else:
		for i: int in range(STAGES.size()):
			if str(STAGES[i]["scene"]) == target_scene:
				next_idx = i
				break

	rebirth_count += 1
	rebirth_ready = false
	Engine.time_scale = 1.0
	MenuUIKit.play_ui_sfx(_sfx_player, SFX_REBIRTH_PATH, 1.0)

	if is_final_clear:
		await _play_rebirth_flash("FINAL REBIRTH COMPLETE", "DEMO COMPLETE!", "NO! I AM THE ALIEN — ALL 3 SECTORS CLEARED")
		_show_demo_complete()
		is_transitioning = false
		return

	var next_code: String = str(STAGES[clampi(next_idx, 0, STAGES.size() - 1)]["code"])
	var next_title: String = str(STAGES[clampi(next_idx, 0, STAGES.size() - 1)]["title"])
	var next_sub: String = str(STAGES[clampi(next_idx, 0, STAGES.size() - 1)]["subtitle"])
	var roman: String = _to_roman(rebirth_count)
	await _play_rebirth_flash(
		"REBIRTH %s // ASCENSION" % roman,
		"%s: %s" % [next_code, next_title],
		next_sub
	)

	current_stage_index = clampi(next_idx, 0, STAGES.size() - 1)
	stage_kills = 0
	_portal_spawned_for_stage = false
	if ResourceLoader.exists(target_scene):
		get_tree().paused = false
		get_tree().change_scene_to_file(target_scene)
		stage_changed.emit(current_stage_index, next_title)

	await get_tree().create_timer(0.2).timeout
	var fade_out: Tween = create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.set_parallel(true)
	fade_out.tween_property(_flash_rect, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_out.tween_property(_banner_box, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await fade_out.finished
	_flash_rect.visible = false
	_banner_box.visible = false
	is_transitioning = false


func _refresh_kill_hud() -> void:
	if _hud_panel == null:
		return
	var idx: int = clampi(current_stage_index, 0, STAGES.size() - 1)
	var entry: Dictionary = STAGES[idx]
	var req: int = int(entry["kills_required"])
	var accent: Color = entry["accent"] as Color

	_hud_stage_lbl.text = "%s // %s" % [str(entry["code"]), str(entry["title"])]
	_hud_kills_lbl.text = "ALIENS PURGED: %d / %d" % [stage_kills, req]
	var ratio: float = clampf(float(stage_kills) / float(maxi(1, req)), 0.0, 1.0)
	_hud_bar_fill.anchor_right = ratio
	_hud_bar_fill.color = MenuUIKit.COL_ACID if rebirth_ready else accent
	_hud_rebirth_hint.visible = rebirth_ready

	if _hud_ability_hint != null:
		match idx:
			0:
				_hud_ability_hint.text = "[C] SLIDE   [RMB] PARRY   [ESC] PAUSE"
			1:
				_hud_ability_hint.text = "[E/R] GRAPPLE   [RMB] PARRY   [ESC] PAUSE"
			_:
				_hud_ability_hint.text = "[E/R] GRAPPLE   [Q] DASH   [ESC] PAUSE"


func _show_stage_intro_banner(stage_idx: int) -> void:
	if stage_idx < 0 or stage_idx >= STAGES.size():
		return
	var entry: Dictionary = STAGES[stage_idx]
	_banner_tag.text = "// %s //" % str(entry["code"])
	_banner_title.text = str(entry["title"])
	_banner_sub.text = str(entry["subtitle"])
	_banner_box.visible = true
	_banner_box.modulate.a = 0.0

	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_banner_box, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.8)
	tw.tween_property(_banner_box, "modulate:a", 0.0, 0.45)
	await tw.finished
	if not is_transitioning:
		_banner_box.visible = false


func _play_rebirth_flash(tag_txt: String, title_txt: String, sub_txt: String) -> void:
	_banner_tag.text = "// %s //" % tag_txt
	_banner_title.text = title_txt
	_banner_sub.text = sub_txt

	_flash_rect.color = Color(0.55, 1.0, 0.35, 1.0)
	_flash_rect.visible = true
	_flash_rect.modulate.a = 0.0
	_banner_box.visible = true
	_banner_box.modulate.a = 0.0

	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_flash_rect, "modulate:a", 0.92, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_flash_rect, "color", Color(0.03, 0.04, 0.035, 0.98), 0.28)
	tw.parallel().tween_property(_banner_box, "modulate:a", 1.0, 0.24)
	tw.tween_interval(1.0)
	await tw.finished


func _show_demo_complete() -> void:
	_flash_rect.visible = false
	_banner_box.visible = false
	if _hud_panel != null:
		_hud_panel.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _complete_stats_lbl != null:
		_complete_stats_lbl.text = "NO! I AM THE ALIEN — DEMO COMPLETE  //  TOTAL KILLS: %d" % total_kills
	if _complete_root != null:
		_complete_root.visible = true


func _hide_demo_complete() -> void:
	if _complete_root != null:
		_complete_root.visible = false


func _to_roman(n: int) -> String:
	match n:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		_:
			return str(n)


func _build_overlay_ui() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "StageTransitionLayer"
	_overlay_layer.layer = 18
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)

	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	var mono_f: Font = MenuUIKit.get_mono_font()
	var disp_i: Font = MenuUIKit.get_display_italic_font()

	# Top-Left Brutalist Kill & Rebirth Progress HUD
	_hud_panel = PanelContainer.new()
	_hud_panel.name = "StageRebirthHUD"
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_panel.anchor_left = 0.0
	_hud_panel.anchor_top = 0.0
	_hud_panel.offset_left = 16.0
	_hud_panel.offset_top = 14.0
	_hud_panel.custom_minimum_size = Vector2(294.0, 0.0)
	_hud_panel.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.045, 0.052, 0.048, 0.84), MenuUIKit.COL_BORDER_DIM, 1, 12.0, 8.0, 4)
	)
	_hud_panel.visible = false
	_overlay_layer.add_child(_hud_panel)

	var hud_vbox: VBoxContainer = VBoxContainer.new()
	hud_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_vbox.add_theme_constant_override("separation", 4)
	_hud_panel.add_child(hud_vbox)

	_hud_stage_lbl = Label.new()
	_hud_stage_lbl.text = "STAGE 01 // BIO-HOSPITAL"
	if mono_h != null:
		_hud_stage_lbl.add_theme_font_override("font", mono_h)
	_hud_stage_lbl.add_theme_font_size_override("font_size", 11)
	_hud_stage_lbl.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
	hud_vbox.add_child(_hud_stage_lbl)

	_hud_kills_lbl = Label.new()
	_hud_kills_lbl.text = "ALIENS PURGED: 0 / 50"
	if mono_h != null:
		_hud_kills_lbl.add_theme_font_override("font", mono_h)
	_hud_kills_lbl.add_theme_font_size_override("font_size", 14)
	_hud_kills_lbl.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	hud_vbox.add_child(_hud_kills_lbl)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0.0, 7.0)
	bar_bg.color = Color(0.12, 0.14, 0.13, 1.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_vbox.add_child(bar_bg)

	_hud_bar_fill = ColorRect.new()
	_hud_bar_fill.anchor_left = 0.0
	_hud_bar_fill.anchor_top = 0.0
	_hud_bar_fill.anchor_right = 0.0
	_hud_bar_fill.anchor_bottom = 1.0
	_hud_bar_fill.color = MenuUIKit.COL_ACID
	_hud_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(_hud_bar_fill)

	_hud_rebirth_hint = Label.new()
	_hud_rebirth_hint.text = ">> REBIRTH READY! PRESS [T] OR ENTER PORTAL <<"
	if mono_h != null:
		_hud_rebirth_hint.add_theme_font_override("font", mono_h)
	_hud_rebirth_hint.add_theme_font_size_override("font_size", 11)
	_hud_rebirth_hint.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
	_hud_rebirth_hint.visible = false
	hud_vbox.add_child(_hud_rebirth_hint)

	_hud_ability_hint = Label.new()
	_hud_ability_hint.text = "[C] SLIDE   [RMB] PARRY   [ESC] PAUSE"
	if mono_f != null:
		_hud_ability_hint.add_theme_font_override("font", mono_f)
	_hud_ability_hint.add_theme_font_size_override("font_size", 10)
	_hud_ability_hint.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	hud_vbox.add_child(_hud_ability_hint)

	# Full-screen Flash & Banner
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.03, 0.04, 0.035, 1.0)
	_flash_rect.visible = false
	_overlay_layer.add_child(_flash_rect)

	var banner_center: CenterContainer = CenterContainer.new()
	banner_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(banner_center)

	_banner_box = PanelContainer.new()
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.custom_minimum_size = Vector2(580.0, 0.0)
	_banner_box.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.045, 0.052, 0.048, 0.94), MenuUIKit.COL_ACID, 2, 28.0, 20.0, 6, Vector2(6.0, 6.0))
	)
	_banner_box.visible = false
	banner_center.add_child(_banner_box)

	var b_vbox: VBoxContainer = VBoxContainer.new()
	b_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	b_vbox.add_theme_constant_override("separation", 6)
	b_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.add_child(b_vbox)

	_banner_tag = Label.new()
	_banner_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mono_h != null:
		_banner_tag.add_theme_font_override("font", mono_h)
	_banner_tag.add_theme_font_size_override("font_size", 14)
	_banner_tag.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
	b_vbox.add_child(_banner_tag)

	_banner_title = Label.new()
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if disp_i != null:
		_banner_title.add_theme_font_override("font", disp_i)
	_banner_title.add_theme_font_size_override("font_size", 46)
	_banner_title.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	_banner_title.add_theme_color_override("font_shadow_color", MenuUIKit.COL_CRIMSON)
	_banner_title.add_theme_constant_override("shadow_offset_x", 3)
	_banner_title.add_theme_constant_override("shadow_offset_y", 2)
	b_vbox.add_child(_banner_title)

	_banner_sub = Label.new()
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mono_f != null:
		_banner_sub.add_theme_font_override("font", mono_f)
	_banner_sub.add_theme_font_size_override("font_size", 12)
	_banner_sub.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	b_vbox.add_child(_banner_sub)

	# Demo Finished / Demo Bitti Screen
	_complete_root = Control.new()
	_complete_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_complete_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_complete_root.visible = false
	_overlay_layer.add_child(_complete_root)

	var complete_bg: ColorRect = MenuUIKit.make_backdrop_rect(0.92, 0.24, 0.26, 0.95)
	_complete_root.add_child(complete_bg)

	var c_center: CenterContainer = CenterContainer.new()
	c_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_complete_root.add_child(c_center)

	var c_panel: PanelContainer = PanelContainer.new()
	c_panel.custom_minimum_size = Vector2(600.0, 0.0)
	c_panel.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(MenuUIKit.COL_BG_PANEL, MenuUIKit.COL_ACID, 2, 0.0, 0.0, -1, Vector2(8.0, 8.0))
	)
	c_center.add_child(c_panel)

	var c_outer: VBoxContainer = VBoxContainer.new()
	c_outer.add_theme_constant_override("separation", 0)
	c_panel.add_child(c_outer)
	c_outer.add_child(MenuUIKit.make_hazard_bar(10.0, MenuUIKit.COL_ACID))

	var c_pad: MarginContainer = MarginContainer.new()
	c_pad.add_theme_constant_override("margin_left", 36)
	c_pad.add_theme_constant_override("margin_right", 36)
	c_pad.add_theme_constant_override("margin_top", 28)
	c_pad.add_theme_constant_override("margin_bottom", 28)
	c_outer.add_child(c_pad)

	var c_vbox: VBoxContainer = VBoxContainer.new()
	c_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	c_vbox.add_theme_constant_override("separation", 12)
	c_pad.add_child(c_vbox)

	var c_tag: Label = Label.new()
	c_tag.text = "// NO! I AM THE ALIEN // ALL 3 SECTORS CONQUERED"
	c_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mono_h != null:
		c_tag.add_theme_font_override("font", mono_h)
	c_tag.add_theme_font_size_override("font_size", 12)
	c_tag.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
	c_vbox.add_child(c_tag)

	var c_title: Label = Label.new()
	c_title.text = "DEMO COMPLETE"
	c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if disp_i != null:
		c_title.add_theme_font_override("font", disp_i)
	c_title.add_theme_font_size_override("font_size", 68)
	c_title.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	c_title.add_theme_color_override("font_shadow_color", MenuUIKit.COL_CRIMSON)
	c_title.add_theme_constant_override("shadow_offset_x", 4)
	c_title.add_theme_constant_override("shadow_offset_y", 3)
	c_vbox.add_child(c_title)

	var c_en: Label = Label.new()
	c_en.text = "THANKS FOR PLAYING NO! I AM THE ALIEN!"
	c_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mono_h != null:
		c_en.add_theme_font_override("font", mono_h)
	c_en.add_theme_font_size_override("font_size", 14)
	c_en.add_theme_color_override("font_color", MenuUIKit.COL_CRIMSON)
	c_vbox.add_child(c_en)

	_complete_stats_lbl = Label.new()
	_complete_stats_lbl.text = "HOSPITAL (50)  ->  MILITARY (100)  ->  CITY (500)"
	_complete_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mono_f != null:
		_complete_stats_lbl.add_theme_font_override("font", mono_f)
	_complete_stats_lbl.add_theme_font_size_override("font_size", 12)
	_complete_stats_lbl.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	c_vbox.add_child(_complete_stats_lbl)

	var replay_btn: Button = MenuUIKit.make_shooter_button("PLAY AGAIN", "01", _sfx_player, MenuUIKit.COL_ACID, 380.0) as Button
	replay_btn.pressed.connect(start_demo)
	c_vbox.add_child(replay_btn)

	var menu_btn: Button = MenuUIKit.make_shooter_button("MAIN MENU", "02", _sfx_player, MenuUIKit.COL_CRIMSON, 380.0) as Button
	menu_btn.pressed.connect(_go_main_menu)
	c_vbox.add_child(menu_btn)

	c_outer.add_child(MenuUIKit.make_hazard_bar(8.0, MenuUIKit.COL_CRIMSON))


func _go_main_menu() -> void:
	_hide_demo_complete()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
