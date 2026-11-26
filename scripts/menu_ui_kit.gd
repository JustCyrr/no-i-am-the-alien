extends RefCounted
class_name MenuUIKit

const FONT_DISPLAY_PATH: String = "res://assets/fonts/display_heavy.ttf"
const FONT_DISPLAY_ITALIC_PATH: String = "res://assets/fonts/display_heavy_italic.ttf"
const FONT_MONO_BOLD_PATH: String = "res://assets/fonts/mono_bold.ttf"
const FONT_MONO_EXTRABOLD_PATH: String = "res://assets/fonts/mono_extrabold.ttf"

const SKULL_ALIVE_PATH: String = "res://assets/ui/health_skulls/skull_alive.png"
const SKULL_DEAD_PATH: String = "res://assets/ui/health_skulls/skull_dead.png"
const SFX_HOVER_PATH: String = "res://assets/audio/grapple/grapple_hook_click.wav"
const SFX_CLICK_PATH: String = "res://assets/audio/weapons/weapon_equip_rack.wav"
const SFX_TICK_PATH: String = "res://assets/audio/weapons/dry_fire_click.wav"

# Brutalist Retro Boomer-Shooter Palette
const COL_BG_DARK: Color = Color(0.055, 0.060, 0.058, 0.96)
const COL_BG_PANEL: Color = Color(0.075, 0.082, 0.078, 0.97)
const COL_BG_ROW: Color = Color(0.105, 0.114, 0.108, 0.92)
const COL_BORDER_DIM: Color = Color(0.24, 0.26, 0.24, 1.0)
const COL_BORDER_LIGHT: Color = Color(0.42, 0.44, 0.40, 1.0)
const COL_CRIMSON: Color = Color(0.90, 0.15, 0.14, 1.0)
const COL_CRIMSON_DARK: Color = Color(0.48, 0.07, 0.07, 1.0)
const COL_ACID: Color = Color(0.49, 1.0, 0.27, 1.0)
const COL_ACID_DIM: Color = Color(0.20, 0.45, 0.12, 1.0)
const COL_BONE: Color = Color(0.95, 0.93, 0.88, 1.0)
const COL_MUTED: Color = Color(0.56, 0.59, 0.55, 1.0)
const COL_BLACK: Color = Color(0.03, 0.03, 0.03, 1.0)

static func get_display_font() -> Font:
	if ResourceLoader.exists(FONT_DISPLAY_PATH):
		return load(FONT_DISPLAY_PATH) as Font
	return null


static func get_display_italic_font() -> Font:
	if ResourceLoader.exists(FONT_DISPLAY_ITALIC_PATH):
		return load(FONT_DISPLAY_ITALIC_PATH) as Font
	return null


static func get_mono_font() -> Font:
	if ResourceLoader.exists(FONT_MONO_BOLD_PATH):
		return load(FONT_MONO_BOLD_PATH) as Font
	return null


static func get_mono_heavy_font() -> Font:
	if ResourceLoader.exists(FONT_MONO_EXTRABOLD_PATH):
		return load(FONT_MONO_EXTRABOLD_PATH) as Font
	return null


static func get_skull_texture() -> Texture2D:
	if ResourceLoader.exists(SKULL_ALIVE_PATH):
		return load(SKULL_ALIVE_PATH) as Texture2D
	return null


static func make_flat_box(
	bg: Color,
	border: Color = Color(0.0, 0.0, 0.0, 0.0),
	border_w: int = 0,
	pad_x: float = 0.0,
	pad_y: float = 0.0,
	left_accent_w: int = -1,
	shadow_offset: Vector2 = Vector2.ZERO
) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	if left_accent_w >= 0:
		sb.border_width_left = left_accent_w
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	if shadow_offset != Vector2.ZERO:
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
		sb.shadow_size = 1
		sb.shadow_offset = shadow_offset
	return sb


static func make_backdrop_rect(opacity: float, grid_str: float, scan_str: float, glow_str: float) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.color = Color(0.04, 0.04, 0.04, opacity)
	if ResourceLoader.exists("res://shaders/menu_backdrop.gdshader"):
		var sh: Shader = load("res://shaders/menu_backdrop.gdshader") as Shader
		if sh != null:
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("bg_opacity", opacity)
			mat.set_shader_parameter("grid_strength", grid_str)
			mat.set_shader_parameter("scanline_strength", scan_str)
			mat.set_shader_parameter("glow_strength", glow_str)
			rect.material = mat
	return rect


static func make_hazard_bar(height: float = 8.0, primary: Color = COL_CRIMSON) -> Control:
	var bar: Control = _HazardStripeBar.new()
	bar.clip_contents = true
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set("stripe_color", primary)
	return bar


static func make_sfx_player(parent: Node, node_name: String, vol_db: float = -7.0) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.volume_db = vol_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.bus = &"PlayerSFX"
	parent.add_child(p)
	return p


static func play_ui_sfx(player: AudioStreamPlayer, path: String, pitch: float = 1.0) -> void:
	if player == null or not ResourceLoader.exists(path):
		return
	player.stream = load(path) as AudioStream
	player.pitch_scale = pitch
	player.play()


static func style_brutalist_slider(slider: HSlider, fill_color: Color = COL_ACID) -> void:
	var bg_box: StyleBoxFlat = make_flat_box(Color(0.04, 0.045, 0.042, 1.0), COL_BORDER_DIM, 2)
	bg_box.content_margin_top = 8.0
	bg_box.content_margin_bottom = 8.0

	var fill_box: StyleBoxFlat = make_flat_box(fill_color, Color(0.0, 0.0, 0.0, 0.0), 0)
	fill_box.content_margin_top = 8.0
	fill_box.content_margin_bottom = 8.0

	var fill_hl: StyleBoxFlat = make_flat_box(fill_color.lightened(0.18), Color(0.0, 0.0, 0.0, 0.0), 0)
	fill_hl.content_margin_top = 8.0
	fill_hl.content_margin_bottom = 8.0

	slider.add_theme_stylebox_override("slider", bg_box)
	slider.add_theme_stylebox_override("grabber_area", fill_box)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hl)
	slider.add_theme_icon_override("grabber", _get_grabber_texture(false))
	slider.add_theme_icon_override("grabber_highlight", _get_grabber_texture(true))
	slider.add_theme_icon_override("grabber_disabled", _get_grabber_texture(false))


static func style_brutalist_scrollbar(scroll: ScrollContainer) -> void:
	var vbar: VScrollBar = scroll.get_v_scroll_bar()
	if vbar == null:
		return
	vbar.custom_minimum_size = Vector2(10.0, 0.0)
	vbar.add_theme_stylebox_override("scroll", make_flat_box(Color(0.04, 0.045, 0.042, 1.0), COL_BORDER_DIM, 1))
	vbar.add_theme_stylebox_override("grabber", make_flat_box(COL_BORDER_LIGHT))
	vbar.add_theme_stylebox_override("grabber_highlight", make_flat_box(COL_CRIMSON))
	vbar.add_theme_stylebox_override("grabber_pressed", make_flat_box(COL_ACID))


static func _get_grabber_texture(highlighted: bool) -> Texture2D:
	var w: int = 12
	var h: int = 22
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var border_col: Color = COL_BLACK
	var fill_col: Color = COL_CRIMSON if highlighted else COL_BONE
	var notch_col: Color = COL_BONE if highlighted else COL_CRIMSON

	for y: int in range(h):
		for x: int in range(w):
			if x == 0 or x == w - 1 or y == 0 or y == h - 1:
				img.set_pixel(x, y, border_col)
			elif x >= 4 and x <= 7 and y >= 7 and y <= 14:
				img.set_pixel(x, y, notch_col)
			else:
				img.set_pixel(x, y, fill_col)

	return ImageTexture.create_from_image(img)


static func make_shooter_button(
	label_text: String,
	tag_text: String,
	sfx_player: AudioStreamPlayer,
	accent_color: Color = COL_CRIMSON,
	min_width: float = 340.0
) -> Control:
	var btn: Control = _ShooterActionButton.new()
	btn.call("configure", label_text, tag_text, sfx_player, accent_color, min_width)
	return btn


class _HazardStripeBar extends Control:
	var stripe_color: Color = Color(0.90, 0.15, 0.14, 1.0)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(0.0, 0.0, w, h), Color(0.07, 0.075, 0.072, 1.0), true)
		var step: float = 18.0
		var stripe_w: float = 8.0
		var x: float = -h
		while x < w + h:
			var pts: PackedVector2Array = PackedVector2Array([
				Vector2(x, h),
				Vector2(x + h, 0.0),
				Vector2(x + h + stripe_w, 0.0),
				Vector2(x + stripe_w, h),
			])
			draw_colored_polygon(pts, stripe_color)
			x += step


class _ShooterActionButton extends Button:
	var _tag_text: String = ""
	var _main_text: String = ""
	var _sfx_player: AudioStreamPlayer = null
	var _accent_color: Color = Color(0.90, 0.15, 0.14, 1.0)

	var _skull_icon: TextureRect
	var _tag_label: Label
	var _title_label: Label
	var _accent_bar: ColorRect
	var _content_hbox: HBoxContainer
	var _is_hovered: bool = false
	var _hover_tween: Tween

	func configure(
		main_text: String,
		tag_text: String,
		sfx_player: AudioStreamPlayer,
		accent_color: Color,
		min_width: float
	) -> void:
		_main_text = main_text
		_tag_text = tag_text
		_sfx_player = sfx_player
		_accent_color = accent_color
		custom_minimum_size = Vector2(min_width, 60.0)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		text = ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var normal_sb: StyleBoxFlat = MenuUIKit.make_flat_box(
			Color(0.075, 0.082, 0.078, 0.85),
			MenuUIKit.COL_BORDER_DIM,
			1
		)
		var hover_sb: StyleBoxFlat = MenuUIKit.make_flat_box(
			_accent_color,
			MenuUIKit.COL_BONE,
			2,
			0.0,
			0.0,
			-1,
			Vector2(5.0, 5.0)
		)
		var pressed_sb: StyleBoxFlat = MenuUIKit.make_flat_box(
			MenuUIKit.COL_BONE,
			_accent_color,
			2
		)
		add_theme_stylebox_override("normal", normal_sb)
		add_theme_stylebox_override("hover", hover_sb)
		add_theme_stylebox_override("pressed", pressed_sb)

		_accent_bar = ColorRect.new()
		_accent_bar.color = _accent_color
		_accent_bar.anchor_top = 0.0
		_accent_bar.anchor_bottom = 1.0
		_accent_bar.offset_left = 0.0
		_accent_bar.offset_right = 6.0
		_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_accent_bar)

		_content_hbox = HBoxContainer.new()
		_content_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		_content_hbox.offset_left = 18.0
		_content_hbox.offset_right = -16.0
		_content_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		_content_hbox.add_theme_constant_override("separation", 12)
		_content_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_content_hbox)

		_skull_icon = TextureRect.new()
		_skull_icon.texture = MenuUIKit.get_skull_texture()
		_skull_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_skull_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_skull_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_skull_icon.custom_minimum_size = Vector2(28.0, 28.0)
		_skull_icon.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_skull_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_hbox.add_child(_skull_icon)

		_tag_label = Label.new()
		_tag_label.text = _tag_text
		_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var mono_f: Font = MenuUIKit.get_mono_font()
		if mono_f != null:
			_tag_label.add_theme_font_override("font", mono_f)
		_tag_label.add_theme_font_size_override("font_size", 13)
		_tag_label.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
		_tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_hbox.add_child(_tag_label)

		_title_label = Label.new()
		_title_label.text = _main_text
		_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var disp_f: Font = MenuUIKit.get_display_italic_font()
		if disp_f != null:
			_title_label.add_theme_font_override("font", disp_f)
		_title_label.add_theme_font_size_override("font_size", 32)
		_title_label.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
		_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
		_title_label.add_theme_constant_override("shadow_offset_x", 2)
		_title_label.add_theme_constant_override("shadow_offset_y", 2)
		_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_hbox.add_child(_title_label)

		mouse_entered.connect(_on_hover_enter)
		mouse_exited.connect(_on_hover_exit)
		button_down.connect(_on_press_sfx)

	func _on_hover_enter() -> void:
		_is_hovered = true
		MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_HOVER_PATH, randf_range(1.05, 1.16))
		_accent_bar.color = MenuUIKit.COL_BLACK
		_tag_label.add_theme_color_override("font_color", MenuUIKit.COL_BLACK)
		_title_label.add_theme_color_override("font_color", MenuUIKit.COL_BLACK)
		_title_label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.18))
		if _hover_tween != null and _hover_tween.is_valid():
			_hover_tween.kill()
		_hover_tween = create_tween()
		_hover_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_hover_tween.set_parallel(true)
		_hover_tween.tween_property(_content_hbox, "offset_left", 28.0, 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(_skull_icon, "modulate:a", 1.0, 0.08)

	func _on_hover_exit() -> void:
		_is_hovered = false
		_accent_bar.color = _accent_color
		_tag_label.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
		_title_label.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
		_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
		if _hover_tween != null and _hover_tween.is_valid():
			_hover_tween.kill()
		_hover_tween = create_tween()
		_hover_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_hover_tween.set_parallel(true)
		_hover_tween.tween_property(_content_hbox, "offset_left", 18.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(_skull_icon, "modulate:a", 0.0, 0.09)

	func _on_press_sfx() -> void:
		MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_CLICK_PATH, randf_range(0.95, 1.05))
