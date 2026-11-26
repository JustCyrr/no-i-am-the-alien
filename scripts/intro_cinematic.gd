extends Control

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"

const SLIDES: Array[Dictionary] = [
	{
		"img": "res://assets/cinematic/slide_01_capture.jpg",
		"tag": "01 // CRASH SITE — SECTOR 09",
		"caption": "THEY PULLED ME FROM THE WRECKAGE. THEY THOUGHT I WAS JUST ANOTHER SPECIMEN.",
		"sfx": "res://assets/audio/slide_dirt.wav",
		"duration": 4.8,
		"zoom_from": 1.02,
		"zoom_to": 1.12,
		"pan_from": Vector2(-12.0, 0.0),
		"pan_to": Vector2(14.0, -8.0),
	},
	{
		"img": "res://assets/cinematic/slide_02_experiment.jpg",
		"tag": "02 // BIO-CONTAINMENT LAB",
		"caption": "THEY STRAPPED ME DOWN AND PUMPED THEIR ALIEN SERUM INTO MY VEINS... BIG MISTAKE.",
		"sfx": "res://assets/audio/rebirth_portal.wav",
		"duration": 5.0,
		"zoom_from": 1.04,
		"zoom_to": 1.14,
		"pan_from": Vector2(12.0, 4.0),
		"pan_to": Vector2(-10.0, -10.0),
	},
	{
		"img": "res://assets/cinematic/slide_03_breakout.jpg",
		"tag": "03 // CONTAINMENT BREACH",
		"caption": "THEY SCREAMED 'THE HUMAN ESCAPED!'  —  NO! I AM THE ALIEN.",
		"sfx": "res://assets/audio/weapons/player_shotgun_boom.wav",
		"duration": 5.2,
		"zoom_from": 1.03,
		"zoom_to": 1.15,
		"pan_from": Vector2(-10.0, 6.0),
		"pan_to": Vector2(12.0, -6.0),
	},
]

var _slide_rect: TextureRect
var _fade_rect: ColorRect
var _tag_lbl: Label
var _caption_lbl: Label
var _progress_fill: ColorRect
var _sfx_player: AudioStreamPlayer

var _slide_index: int = 0
var _slide_timer: float = 0.0
var _slide_duration: float = 4.8
var _is_advancing: bool = false
var _ken_burns_tween: Tween


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sfx_player = MenuUIKit.make_sfx_player(self, "IntroSfx", -4.0)
	_build_ui()
	_show_slide(0)


func _process(delta: float) -> void:
	if _is_advancing:
		return
	_slide_timer += delta
	if _progress_fill != null:
		var ratio: float = clampf(_slide_timer / maxf(_slide_duration, 0.1), 0.0, 1.0)
		_progress_fill.anchor_right = ratio
	if _slide_timer >= _slide_duration:
		_advance_next()


func _unhandled_input(event: InputEvent) -> void:
	if _is_advancing:
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_ESCAPE:
				_go_to_main_menu()
				get_viewport().set_input_as_handled()
			elif ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER:
				_advance_next()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_advance_next()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.025, 1.0)
	add_child(bg)

	# Fullscreen comic art viewport with clipping for smooth Ken Burns zoom
	var art_clip: Control = Control.new()
	art_clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_clip.clip_contents = true
	add_child(art_clip)

	_slide_rect = TextureRect.new()
	_slide_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slide_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_slide_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_slide_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art_clip.add_child(_slide_rect)

	# Subtle CRT scanline & vignette overlay over the comic frame
	var crt_overlay: ColorRect = MenuUIKit.make_backdrop_rect(0.24, 0.0, 0.25, 0.35)
	crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crt_overlay)

	# Top Cinema Letterbox Bar
	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_bottom = 66.0
	top_bar.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.03, 0.032, 0.035, 0.94), MenuUIKit.COL_CRIMSON, 0, 28.0, 12.0)
	)
	add_child(top_bar)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_bar.add_child(top_hbox)

	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	var mono_f: Font = MenuUIKit.get_mono_font()
	var disp_i: Font = MenuUIKit.get_display_italic_font()

	_tag_lbl = Label.new()
	_tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mono_h != null:
		_tag_lbl.add_theme_font_override("font", mono_h)
	_tag_lbl.add_theme_font_size_override("font_size", 14)
	_tag_lbl.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
	top_hbox.add_child(_tag_lbl)

	var title_stamp: Label = Label.new()
	title_stamp.text = "NO! I AM THE ALIEN"
	title_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if disp_i != null:
		title_stamp.add_theme_font_override("font", disp_i)
	title_stamp.add_theme_font_size_override("font_size", 24)
	title_stamp.add_theme_color_override("font_color", MenuUIKit.COL_CRIMSON)
	top_hbox.add_child(title_stamp)

	# Bottom Cinema Letterbox Bar with Narrative Caption + Progress
	var bot_bar: PanelContainer = PanelContainer.new()
	bot_bar.anchor_left = 0.0
	bot_bar.anchor_right = 1.0
	bot_bar.anchor_top = 1.0
	bot_bar.anchor_bottom = 1.0
	bot_bar.offset_top = -112.0
	bot_bar.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.03, 0.032, 0.035, 0.95), MenuUIKit.COL_BORDER_DIM, 0, 36.0, 14.0)
	)
	add_child(bot_bar)

	var bot_vbox: VBoxContainer = VBoxContainer.new()
	bot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_vbox.add_theme_constant_override("separation", 10)
	bot_bar.add_child(bot_vbox)

	_caption_lbl = Label.new()
	_caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mono_h != null:
		_caption_lbl.add_theme_font_override("font", mono_h)
	_caption_lbl.add_theme_font_size_override("font_size", 16)
	_caption_lbl.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	bot_vbox.add_child(_caption_lbl)

	var bot_meta: HBoxContainer = HBoxContainer.new()
	bot_meta.add_theme_constant_override("separation", 16)
	bot_vbox.add_child(bot_meta)

	var prog_bg: ColorRect = ColorRect.new()
	prog_bg.custom_minimum_size = Vector2(0.0, 5.0)
	prog_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog_bg.color = Color(0.14, 0.15, 0.16, 1.0)
	bot_meta.add_child(prog_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.anchor_left = 0.0
	_progress_fill.anchor_top = 0.0
	_progress_fill.anchor_right = 0.0
	_progress_fill.anchor_bottom = 1.0
	_progress_fill.color = MenuUIKit.COL_CRIMSON
	prog_bg.add_child(_progress_fill)

	var skip_hint: Label = Label.new()
	skip_hint.text = "[SPACE / CLICK] NEXT   |   [ESC] SKIP"
	if mono_f != null:
		skip_hint.add_theme_font_override("font", mono_f)
	skip_hint.add_theme_font_size_override("font_size", 11)
	skip_hint.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	bot_meta.add_child(skip_hint)

	# Fullscreen Black Crossfade Curtain
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)


func _show_slide(idx: int) -> void:
	if idx < 0 or idx >= SLIDES.size():
		_go_to_main_menu()
		return

	_slide_index = idx
	_slide_timer = 0.0
	var s: Dictionary = SLIDES[idx]
	_slide_duration = float(s["duration"])

	var img_path: String = str(s["img"])
	if ResourceLoader.exists(img_path):
		_slide_rect.texture = load(img_path) as Texture2D

	_tag_lbl.text = str(s["tag"])
	_caption_lbl.text = str(s["caption"])
	_progress_fill.anchor_right = 0.0

	var sfx_path: String = str(s["sfx"])
	if not sfx_path.is_empty():
		MenuUIKit.play_ui_sfx(_sfx_player, sfx_path, 0.92)

	# Smooth Ken Burns cinematic motion
	_slide_rect.pivot_offset = get_viewport_rect().size * 0.5
	var z_from: float = float(s["zoom_from"])
	var z_to: float = float(s["zoom_to"])
	var p_from: Vector2 = s["pan_from"] as Vector2
	var p_to: Vector2 = s["pan_to"] as Vector2

	_slide_rect.scale = Vector2(z_from, z_from)
	_slide_rect.position = p_from

	if _ken_burns_tween != null and _ken_burns_tween.is_valid():
		_ken_burns_tween.kill()
	_ken_burns_tween = create_tween()
	_ken_burns_tween.set_parallel(true)
	_ken_burns_tween.tween_property(_slide_rect, "scale", Vector2(z_to, z_to), _slide_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ken_burns_tween.tween_property(_slide_rect, "position", p_to, _slide_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ken_burns_tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _advance_next() -> void:
	if _is_advancing:
		return
	_is_advancing = true

	var tw: Tween = create_tween()
	tw.tween_property(_fade_rect, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	var next_idx: int = _slide_index + 1
	if next_idx >= SLIDES.size():
		_go_to_main_menu()
	else:
		_is_advancing = false
		_show_slide(next_idx)


func _go_to_main_menu() -> void:
	_is_advancing = true
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
