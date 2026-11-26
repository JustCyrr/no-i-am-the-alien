extends CanvasLayer
class_name PauseMenu

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"

var _root_control: Control
var _left_strip: PanelContainer
var _stage_tag_label: Label
var _settings_holder: CenterContainer
var _settings_panel: SettingsPanel
var _sfx_player: AudioStreamPlayer
var _is_open: bool = false
var _slide_tween: Tween


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_player = MenuUIKit.make_sfx_player(self, "PauseMenuSfx", -6.0)
	_build_ui()
	_root_control.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			# Do not open pause menu while DeathScreen is active
			var parent_n: Node = get_parent()
			if parent_n != null:
				var ds: Node = parent_n.get_node_or_null("DeathScreen")
				if ds != null and ds.has_method("is_open") and bool(ds.call("is_open")):
					return
			if _is_open:
				if _settings_panel != null and _settings_panel.visible:
					if _settings_panel.is_listening_for_rebind():
						_settings_panel.cancel_rebind()
					else:
						_hide_settings()
				else:
					resume_game()
			else:
				pause_game()
			get_viewport().set_input_as_handled()


func pause_game() -> void:
	_is_open = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root_control.visible = true
	_hide_settings()
	if _stage_tag_label != null:
		var sm: Node = get_node_or_null("/root/StageManager")
		if sm != null and sm.has_method("get_current_stage_header"):
			_stage_tag_label.text = "// SYSTEM HALTED // %s" % str(sm.call("get_current_stage_header"))
	MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_CLICK_PATH, 0.92)

	# Crisp snap-in slide from left
	if _left_strip != null:
		_left_strip.offset_left = -56.0
		_left_strip.offset_right = 334.0
		if _slide_tween != null and _slide_tween.is_valid():
			_slide_tween.kill()
		_slide_tween = create_tween()
		_slide_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_slide_tween.set_parallel(true)
		_slide_tween.tween_property(_left_strip, "offset_left", 0.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_slide_tween.tween_property(_left_strip, "offset_right", 390.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func resume_game() -> void:
	if _settings_panel != null:
		_settings_panel.cancel_rebind()
	_is_open = false
	_root_control.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_TICK_PATH, 1.15)


func _show_settings() -> void:
	if _settings_panel != null:
		_settings_panel.refresh_from_settings()
		_settings_panel.visible = true
	if _settings_holder != null:
		_settings_holder.visible = true


func _hide_settings() -> void:
	if _settings_panel != null:
		_settings_panel.cancel_rebind()
		_settings_panel.visible = false
	if _settings_holder != null:
		_settings_holder.visible = false


func _go_to_main_menu() -> void:
	_is_open = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "PauseRoot"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)

	# Translucent CRT scanline overlay so the frozen 3D combat scene stays visible behind
	var backdrop: ColorRect = MenuUIKit.make_backdrop_rect(0.74, 0.15, 0.28, 0.45)
	_root_control.add_child(backdrop)

	# Full-height Left Brutalist Strip
	_left_strip = PanelContainer.new()
	_left_strip.anchor_left = 0.0
	_left_strip.anchor_top = 0.0
	_left_strip.anchor_right = 0.0
	_left_strip.anchor_bottom = 1.0
	_left_strip.offset_left = 0.0
	_left_strip.offset_right = 390.0
	_left_strip.offset_top = 0.0
	_left_strip.offset_bottom = 0.0

	var strip_sb: StyleBoxFlat = MenuUIKit.make_flat_box(Color(0.048, 0.052, 0.050, 0.96))
	strip_sb.border_width_right = 4
	strip_sb.border_color = MenuUIKit.COL_CRIMSON
	_left_strip.add_theme_stylebox_override("panel", strip_sb)
	_root_control.add_child(_left_strip)

	var strip_vbox: VBoxContainer = VBoxContainer.new()
	strip_vbox.add_theme_constant_override("separation", 0)
	_left_strip.add_child(strip_vbox)

	# Top Hazard Bar
	strip_vbox.add_child(MenuUIKit.make_hazard_bar(10.0, MenuUIKit.COL_CRIMSON))

	# Inner padded content
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 26)
	strip_vbox.add_child(margin)

	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 18)
	margin.add_child(content_vbox)

	# Header tag
	_stage_tag_label = Label.new()
	_stage_tag_label.text = "// SYSTEM HALTED // SECTOR 09"
	var mono_f: Font = MenuUIKit.get_mono_font()
	if mono_f != null:
		_stage_tag_label.add_theme_font_override("font", mono_f)
	_stage_tag_label.add_theme_font_size_override("font_size", 12)
	_stage_tag_label.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
	content_vbox.add_child(_stage_tag_label)

	# Heavy Brutalist Title
	var title_lbl: Label = Label.new()
	title_lbl.text = "PAUSED"
	var disp_i: Font = MenuUIKit.get_display_italic_font()
	if disp_i != null:
		title_lbl.add_theme_font_override("font", disp_i)
	title_lbl.add_theme_font_size_override("font_size", 74)
	title_lbl.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	title_lbl.add_theme_color_override("font_shadow_color", MenuUIKit.COL_CRIMSON)
	title_lbl.add_theme_constant_override("shadow_offset_x", 5)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	content_vbox.add_child(title_lbl)

	# Split accent rule
	var rule_hbox: HBoxContainer = HBoxContainer.new()
	rule_hbox.add_theme_constant_override("separation", 4)
	content_vbox.add_child(rule_hbox)

	var red_bar: ColorRect = ColorRect.new()
	red_bar.custom_minimum_size = Vector2(0.0, 4.0)
	red_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	red_bar.color = MenuUIKit.COL_CRIMSON
	rule_hbox.add_child(red_bar)

	var green_bar: ColorRect = ColorRect.new()
	green_bar.custom_minimum_size = Vector2(56.0, 4.0)
	green_bar.color = MenuUIKit.COL_ACID
	rule_hbox.add_child(green_bar)

	var top_gap: Control = Control.new()
	top_gap.custom_minimum_size = Vector2(0.0, 12.0)
	content_vbox.add_child(top_gap)

	# Shooter Action Buttons
	var resume_btn: Button = MenuUIKit.make_shooter_button("RESUME", "01", _sfx_player, MenuUIKit.COL_ACID, 310.0) as Button
	resume_btn.pressed.connect(resume_game)
	content_vbox.add_child(resume_btn)

	var settings_btn: Button = MenuUIKit.make_shooter_button("SETTINGS", "02", _sfx_player, MenuUIKit.COL_CRIMSON, 310.0) as Button
	settings_btn.pressed.connect(_show_settings)
	content_vbox.add_child(settings_btn)

	var main_menu_btn: Button = MenuUIKit.make_shooter_button("MAIN MENU", "03", _sfx_player, MenuUIKit.COL_CRIMSON, 310.0) as Button
	main_menu_btn.pressed.connect(_go_to_main_menu)
	content_vbox.add_child(main_menu_btn)

	# Push footer down
	var flex_spacer: Control = Control.new()
	flex_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(flex_spacer)

	# Bottom Footer Info
	var foot_hbox: HBoxContainer = HBoxContainer.new()
	foot_hbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(foot_hbox)

	var esc_hint: Label = Label.new()
	esc_hint.text = "[ESC] RESUME COMBAT"
	esc_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esc_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if mono_f != null:
		esc_hint.add_theme_font_override("font", mono_f)
	esc_hint.add_theme_font_size_override("font_size", 12)
	esc_hint.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	foot_hbox.add_child(esc_hint)

	var skull_tex: Texture2D = MenuUIKit.get_skull_texture()
	if skull_tex != null:
		for i: int in range(3):
			var sk: TextureRect = TextureRect.new()
			sk.texture = skull_tex
			sk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sk.custom_minimum_size = Vector2(22.0, 22.0)
			sk.modulate = Color(0.85, 0.85, 0.82, 0.72)
			foot_hbox.add_child(sk)

	# Bottom Hazard Bar
	strip_vbox.add_child(MenuUIKit.make_hazard_bar(8.0, MenuUIKit.COL_CRIMSON_DARK))

	# Right-Side Settings Container (opens beside the left pause strip!)
	_settings_holder = CenterContainer.new()
	_settings_holder.anchor_left = 0.0
	_settings_holder.anchor_top = 0.0
	_settings_holder.anchor_right = 1.0
	_settings_holder.anchor_bottom = 1.0
	_settings_holder.offset_left = 410.0
	_settings_holder.offset_right = -20.0
	_settings_holder.offset_top = 20.0
	_settings_holder.offset_bottom = -20.0
	_settings_holder.visible = false
	_root_control.add_child(_settings_holder)

	_settings_panel = SettingsPanel.new()
	_settings_panel.visible = false
	_settings_panel.back_pressed.connect(_hide_settings)
	_settings_holder.add_child(_settings_panel)
