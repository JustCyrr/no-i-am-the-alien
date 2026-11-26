extends CanvasLayer
class_name DeathScreen

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"

var _root_control: Control
var _panel: PanelContainer
var _stats_label: Label
var _sfx_player: AudioStreamPlayer
var _is_open: bool = false


func _ready() -> void:
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_player = MenuUIKit.make_sfx_player(self, "DeathScreenSfx", -5.0)
	_build_ui()
	_root_control.visible = false


func is_open() -> bool:
	return _is_open


func show_death_screen() -> void:
	if _is_open:
		return
	_is_open = true
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root_control.visible = true

	if _stats_label != null:
		var sm: Node = get_node_or_null("/root/StageManager")
		if sm != null and sm.has_method("get_current_stage_header"):
			_stats_label.text = "// %s //" % str(sm.call("get_current_stage_header"))
		else:
			_stats_label.text = "// SIGNAL TERMINATED //"

	_root_control.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_root_control, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_R:
			_on_retry_pressed()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "DeathRoot"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)

	# Crimson-tinted brutalist CRT overlay
	var backdrop: ColorRect = MenuUIKit.make_backdrop_rect(0.84, 0.22, 0.30, 0.95)
	_root_control.add_child(backdrop)

	var red_wash: ColorRect = ColorRect.new()
	red_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	red_wash.color = Color(0.55, 0.02, 0.02, 0.22)
	red_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(red_wash)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(540.0, 0.0)
	_panel.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(MenuUIKit.COL_BG_PANEL, MenuUIKit.COL_CRIMSON, 2, 0.0, 0.0, -1, Vector2(8.0, 8.0))
	)
	center.add_child(_panel)

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(outer_vbox)

	outer_vbox.add_child(MenuUIKit.make_hazard_bar(10.0, MenuUIKit.COL_CRIMSON))

	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 38)
	pad.add_theme_constant_override("margin_right", 38)
	pad.add_theme_constant_override("margin_top", 28)
	pad.add_theme_constant_override("margin_bottom", 26)
	outer_vbox.add_child(pad)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	pad.add_child(vbox)

	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	var mono_f: Font = MenuUIKit.get_mono_font()
	var disp_i: Font = MenuUIKit.get_display_italic_font()

	var tag_lbl: Label = Label.new()
	tag_lbl.text = "// VITALS FLATLINED // TERMINATED"
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mono_h != null:
		tag_lbl.add_theme_font_override("font", mono_h)
	tag_lbl.add_theme_font_size_override("font_size", 12)
	tag_lbl.add_theme_color_override("font_color", MenuUIKit.COL_CRIMSON)
	vbox.add_child(tag_lbl)

	var title_lbl: Label = Label.new()
	title_lbl.text = "YOU DIED"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if disp_i != null:
		title_lbl.add_theme_font_override("font", disp_i)
	title_lbl.add_theme_font_size_override("font_size", 78)
	title_lbl.add_theme_color_override("font_color", MenuUIKit.COL_CRIMSON)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	title_lbl.add_theme_constant_override("shadow_offset_x", 5)
	title_lbl.add_theme_constant_override("shadow_offset_y", 4)
	vbox.add_child(title_lbl)

	# 3 Dead Skulls Row
	var skull_row: HBoxContainer = HBoxContainer.new()
	skull_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skull_row.add_theme_constant_override("separation", 14)
	vbox.add_child(skull_row)
	if ResourceLoader.exists(MenuUIKit.SKULL_DEAD_PATH):
		var dead_tex: Texture2D = load(MenuUIKit.SKULL_DEAD_PATH) as Texture2D
		for i: int in range(3):
			var sk: TextureRect = TextureRect.new()
			sk.texture = dead_tex
			sk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sk.custom_minimum_size = Vector2(36.0, 36.0)
			skull_row.add_child(sk)

	_stats_label = Label.new()
	_stats_label.text = "// SIGNAL TERMINATED //"
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mono_f != null:
		_stats_label.add_theme_font_override("font", mono_f)
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	vbox.add_child(_stats_label)

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	vbox.add_child(gap)

	var retry_btn: Button = MenuUIKit.make_shooter_button("RETRY STAGE", "01", _sfx_player, MenuUIKit.COL_ACID, 380.0) as Button
	retry_btn.pressed.connect(_on_retry_pressed)
	vbox.add_child(retry_btn)

	var menu_btn: Button = MenuUIKit.make_shooter_button("MAIN MENU", "02", _sfx_player, MenuUIKit.COL_CRIMSON, 380.0) as Button
	menu_btn.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(menu_btn)

	var hint_lbl: Label = Label.new()
	hint_lbl.text = "[R] QUICK RETRY"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mono_f != null:
		hint_lbl.add_theme_font_override("font", mono_f)
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	vbox.add_child(hint_lbl)

	outer_vbox.add_child(MenuUIKit.make_hazard_bar(8.0, MenuUIKit.COL_CRIMSON_DARK))


func _on_retry_pressed() -> void:
	_is_open = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm != null and sm.has_method("reset_current_stage_progress"):
		sm.call("reset_current_stage_progress")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	_is_open = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
