extends Control

const GAME_SCENE: String = "res://scenes/stages/stage_1_hospital.tscn"

const ENEMY_SHOWCASE: Array[Dictionary] = [
	{
		"name": "DOC-SAW",
		"role": "MELEE RIPPER",
		"sheet": "res://assets/enemies/doctor_saw/spritesheet.png",
		"row_start": 0,
		"row_count": 4,
		"fps": 6.5,
		"scale_w": 176.0,
		"scale_h": 248.0,
	},
	{
		"name": "HVY-BAZOOKA",
		"role": "ROCKET TROOPER",
		"sheet": "res://assets/enemies/soldier_bazooka/spritesheet.png",
		"row_start": 4,
		"row_count": 3,
		"fps": 4.8,
		"scale_w": 208.0,
		"scale_h": 286.0,
	},
	{
		"name": "COP-PISTOL",
		"role": "ENFORCER",
		"sheet": "res://assets/enemies/police_pistol/spritesheet.png",
		"row_start": 0,
		"row_count": 4,
		"fps": 5.5,
		"scale_w": 176.0,
		"scale_h": 248.0,
	},
]

var _right_dossier: Control
var _settings_holder: CenterContainer
var _settings_panel: SettingsPanel
var _sfx_player: AudioStreamPlayer

var _animated_sprites: Array[Dictionary] = []
var _anim_time: float = 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sfx_player = MenuUIKit.make_sfx_player(self, "MainMenuSfx", -6.0)
	_build_ui()


func _process(delta: float) -> void:
	_anim_time += delta
	for item: Dictionary in _animated_sprites:
		var atlas: AtlasTexture = item["atlas"] as AtlasTexture
		var frame_w: float = float(item["fw"])
		var frame_h: float = float(item["fh"])
		var row_start: int = int(item["row_start"])
		var row_count: int = int(item["row_count"])
		var fps: float = float(item["fps"])
		var row_idx: int = row_start + (int(_anim_time * fps) % maxi(1, row_count))
		# Column 0 = front-facing Doom angle
		atlas.region = Rect2(0.0, float(row_idx) * frame_h, frame_w, frame_h)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			if _settings_panel != null and _settings_panel.visible:
				if _settings_panel.is_listening_for_rebind():
					_settings_panel.cancel_rebind()
				else:
					_hide_settings()
				get_viewport().set_input_as_handled()


func _build_ui() -> void:
	# Full-screen CRT / tactical grid / crimson+acid atmosphere
	var bg: ColorRect = MenuUIKit.make_backdrop_rect(1.0, 0.28, 0.24, 1.0)
	add_child(bg)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# Top Hazard Strip + Status Header
	root_vbox.add_child(MenuUIKit.make_hazard_bar(10.0, MenuUIKit.COL_CRIMSON))

	var top_bar_panel: PanelContainer = PanelContainer.new()
	top_bar_panel.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.04, 0.045, 0.042, 0.94), MenuUIKit.COL_BORDER_DIM, 0, 32.0, 8.0)
	)
	root_vbox.add_child(top_bar_panel)

	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar_panel.add_child(top_bar)

	var mono_f: Font = MenuUIKit.get_mono_font()
	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	var disp_i: Font = MenuUIKit.get_display_italic_font()

	var left_status: Label = Label.new()
	left_status.text = "SECTOR 09 // BIO-CONTAINMENT BREACH"
	if mono_h != null:
		left_status.add_theme_font_override("font", mono_h)
	left_status.add_theme_font_size_override("font_size", 12)
	left_status.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
	left_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(left_status)

	var right_status: Label = Label.new()
	right_status.text = "HOSTILES DETECTED: 09 VARIANTS // STATUS: CRITICAL"
	if mono_f != null:
		right_status.add_theme_font_override("font", mono_f)
	right_status.add_theme_font_size_override("font_size", 12)
	right_status.add_theme_color_override("font_color", MenuUIKit.COL_CRIMSON)
	top_bar.add_child(right_status)

	# Middle Asymmetric Split (Left Brand+Buttons | Right Alien Dossier / Settings)
	var mid_margin: MarginContainer = MarginContainer.new()
	mid_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_margin.add_theme_constant_override("margin_left", 40)
	mid_margin.add_theme_constant_override("margin_right", 36)
	mid_margin.add_theme_constant_override("margin_top", 18)
	mid_margin.add_theme_constant_override("margin_bottom", 16)
	root_vbox.add_child(mid_margin)

	var split_hbox: HBoxContainer = HBoxContainer.new()
	split_hbox.add_theme_constant_override("separation", 34)
	mid_margin.add_child(split_hbox)

	# --- LEFT COLUMN: TITLE + ACTION BUTTONS ---
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(360.0, 0.0)
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 12)
	split_hbox.add_child(left_col)

	# Brutalist Stacked Title: NO! I AM THE ALIEN
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", -12)
	left_col.add_child(title_box)

	var title_top: Label = Label.new()
	title_top.text = "NO! I AM"
	if disp_i != null:
		title_top.add_theme_font_override("font", disp_i)
	title_top.add_theme_font_size_override("font_size", 74)
	title_top.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	title_top.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	title_top.add_theme_constant_override("shadow_offset_x", 6)
	title_top.add_theme_constant_override("shadow_offset_y", 5)
	title_box.add_child(title_top)

	var title_bot: Label = Label.new()
	title_bot.text = "THE ALIEN"
	if disp_i != null:
		title_bot.add_theme_font_override("font", disp_i)
	title_bot.add_theme_font_size_override("font_size", 76)
	title_bot.add_theme_color_override("font_color", MenuUIKit.COL_CRIMSON)
	title_bot.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	title_bot.add_theme_constant_override("shadow_offset_x", 6)
	title_bot.add_theme_constant_override("shadow_offset_y", 5)
	title_box.add_child(title_bot)

	# Sharp Split Rule
	var rule_hbox: HBoxContainer = HBoxContainer.new()
	rule_hbox.add_theme_constant_override("separation", 6)
	left_col.add_child(rule_hbox)

	var bar_a: ColorRect = ColorRect.new()
	bar_a.custom_minimum_size = Vector2(210.0, 4.0)
	bar_a.color = MenuUIKit.COL_CRIMSON
	rule_hbox.add_child(bar_a)

	var bar_b: ColorRect = ColorRect.new()
	bar_b.custom_minimum_size = Vector2(74.0, 4.0)
	bar_b.color = MenuUIKit.COL_ACID
	rule_hbox.add_child(bar_b)

	var tagline: Label = Label.new()
	tagline.text = "PARRY ROCKETS // GRAPPLE THE SWARM // SURVIVE"
	if mono_f != null:
		tagline.add_theme_font_override("font", mono_f)
	tagline.add_theme_font_size_override("font_size", 11)
	tagline.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	left_col.add_child(tagline)

	var spacer_btn: Control = Control.new()
	spacer_btn.custom_minimum_size = Vector2(0.0, 14.0)
	left_col.add_child(spacer_btn)

	# 3 Core Action Buttons
	var play_btn: Button = MenuUIKit.make_shooter_button("PLAY", "01", _sfx_player, MenuUIKit.COL_ACID, 340.0) as Button
	play_btn.pressed.connect(_on_play_pressed)
	left_col.add_child(play_btn)

	var settings_btn: Button = MenuUIKit.make_shooter_button("SETTINGS", "02", _sfx_player, MenuUIKit.COL_CRIMSON, 340.0) as Button
	settings_btn.pressed.connect(_toggle_settings)
	left_col.add_child(settings_btn)

	var quit_btn: Button = MenuUIKit.make_shooter_button("QUIT", "03", _sfx_player, MenuUIKit.COL_CRIMSON, 340.0) as Button
	quit_btn.pressed.connect(_on_quit_pressed)
	left_col.add_child(quit_btn)

	# --- RIGHT COLUMN: LIVE PIXEL-ART ALIEN DOSSIER OR SETTINGS ---
	var right_stack: Control = Control.new()
	right_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_child(right_stack)

	_right_dossier = _build_alien_dossier()
	_right_dossier.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_stack.add_child(_right_dossier)

	_settings_holder = CenterContainer.new()
	_settings_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_holder.visible = false
	right_stack.add_child(_settings_holder)

	_settings_panel = SettingsPanel.new()
	_settings_panel.visible = false
	_settings_panel.back_pressed.connect(_hide_settings)
	_settings_holder.add_child(_settings_panel)

	# Bottom Controls Bar
	var footer_panel: PanelContainer = PanelContainer.new()
	footer_panel.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.04, 0.045, 0.042, 0.96), MenuUIKit.COL_BORDER_DIM, 0, 32.0, 9.0)
	)
	root_vbox.add_child(footer_panel)

	var footer_hbox: HBoxContainer = HBoxContainer.new()
	footer_panel.add_child(footer_hbox)

	var controls_lbl: Label = Label.new()
	controls_lbl.text = "[WASD] MOVE  [SHIFT] SPRINT  [C] SLIDE  [RMB] PARRY  [E/R] GRAPPLE (S2+)  [Q] DASH (S3)  [SCROLL] GUNS"
	if mono_f != null:
		controls_lbl.add_theme_font_override("font", mono_f)
	controls_lbl.add_theme_font_size_override("font_size", 11)
	controls_lbl.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	controls_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(controls_lbl)

	var skull_tex: Texture2D = MenuUIKit.get_skull_texture()
	if skull_tex != null:
		for i: int in range(3):
			var sk: TextureRect = TextureRect.new()
			sk.texture = skull_tex
			sk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sk.custom_minimum_size = Vector2(20.0, 20.0)
			footer_hbox.add_child(sk)

	root_vbox.add_child(MenuUIKit.make_hazard_bar(8.0, MenuUIKit.COL_CRIMSON_DARK))


func _build_alien_dossier() -> Control:
	var center: CenterContainer = CenterContainer.new()

	var frame: PanelContainer = PanelContainer.new()
	frame.custom_minimum_size = Vector2(580.0, 410.0)
	frame.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(
			Color(0.055, 0.064, 0.056, 0.86),
			MenuUIKit.COL_BORDER_LIGHT,
			2,
			0.0,
			0.0,
			-1,
			Vector2(8.0, 8.0)
		)
	)
	center.add_child(frame)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	frame.add_child(vbox)

	# Dossier Top Strip
	var hdr: PanelContainer = PanelContainer.new()
	hdr.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.035, 0.042, 0.038, 0.98), MenuUIKit.COL_BORDER_DIM, 0, 18.0, 10.0, 5)
	)
	vbox.add_child(hdr)

	var hdr_hbox: HBoxContainer = HBoxContainer.new()
	hdr.add_child(hdr_hbox)

	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	var mono_f: Font = MenuUIKit.get_mono_font()

	var hdr_l: Label = Label.new()
	hdr_l.text = "TARGET DOSSIER // ACTIVE XENO LINEUP"
	if mono_h != null:
		hdr_l.add_theme_font_override("font", mono_h)
	hdr_l.add_theme_font_size_override("font_size", 13)
	hdr_l.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	hdr_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hbox.add_child(hdr_l)

	var hdr_r: Label = Label.new()
	hdr_r.text = "[ LIVE FEED ]"
	if mono_h != null:
		hdr_r.add_theme_font_override("font", mono_h)
	hdr_r.add_theme_font_size_override("font_size", 12)
	hdr_r.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
	hdr_hbox.add_child(hdr_r)

	# Sprite Stage
	var stage_margin: MarginContainer = MarginContainer.new()
	stage_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_margin.add_theme_constant_override("margin_left", 14)
	stage_margin.add_theme_constant_override("margin_right", 14)
	stage_margin.add_theme_constant_override("margin_top", 8)
	stage_margin.add_theme_constant_override("margin_bottom", 12)
	vbox.add_child(stage_margin)

	var lineup: HBoxContainer = HBoxContainer.new()
	lineup.alignment = BoxContainer.ALIGNMENT_CENTER
	lineup.add_theme_constant_override("separation", 4)
	stage_margin.add_child(lineup)

	_animated_sprites.clear()
	for spec: Dictionary in ENEMY_SHOWCASE:
		var unit_col: VBoxContainer = VBoxContainer.new()
		unit_col.alignment = BoxContainer.ALIGNMENT_END
		unit_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unit_col.add_theme_constant_override("separation", 6)
		lineup.add_child(unit_col)

		var sheet_path: String = str(spec["sheet"])
		if ResourceLoader.exists(sheet_path):
			var sheet_tex: Texture2D = load(sheet_path) as Texture2D
			if sheet_tex != null:
				var fw: float = float(sheet_tex.get_width()) / 8.0
				var fh: float = float(sheet_tex.get_height()) / 10.0
				var atlas: AtlasTexture = AtlasTexture.new()
				atlas.atlas = sheet_tex
				atlas.region = Rect2(0.0, float(int(spec["row_start"])) * fh, fw, fh)

				var sprite_rect: TextureRect = TextureRect.new()
				sprite_rect.texture = atlas
				sprite_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				sprite_rect.custom_minimum_size = Vector2(float(spec["scale_w"]), float(spec["scale_h"]))
				unit_col.add_child(sprite_rect)

				_animated_sprites.append({
					"atlas": atlas,
					"fw": fw,
					"fh": fh,
					"row_start": int(spec["row_start"]),
					"row_count": int(spec["row_count"]),
					"fps": float(spec["fps"]),
				})

		var name_lbl: Label = Label.new()
		name_lbl.text = str(spec["name"])
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if mono_h != null:
			name_lbl.add_theme_font_override("font", mono_h)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
		unit_col.add_child(name_lbl)

		var role_lbl: Label = Label.new()
		role_lbl.text = str(spec["role"])
		role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if mono_f != null:
			role_lbl.add_theme_font_override("font", mono_f)
		role_lbl.add_theme_font_size_override("font_size", 10)
		role_lbl.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
		unit_col.add_child(role_lbl)

	# Bottom Hazard Accent inside Dossier
	vbox.add_child(MenuUIKit.make_hazard_bar(6.0, MenuUIKit.COL_ACID_DIM))
	return center


func _toggle_settings() -> void:
	if _settings_panel != null and _settings_panel.visible:
		_hide_settings()
	else:
		_show_settings()


func _show_settings() -> void:
	if _right_dossier != null:
		_right_dossier.visible = false
	if _settings_holder != null:
		_settings_holder.visible = true
	if _settings_panel != null:
		_settings_panel.refresh_from_settings()
		_settings_panel.visible = true


func _hide_settings() -> void:
	if _settings_panel != null:
		_settings_panel.cancel_rebind()
		_settings_panel.visible = false
	if _settings_holder != null:
		_settings_holder.visible = false
	if _right_dossier != null:
		_right_dossier.visible = true


func _on_play_pressed() -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm != null and sm.has_method("start_demo"):
		sm.call("start_demo")
	elif ResourceLoader.exists(GAME_SCENE):
		get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
