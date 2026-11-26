extends PanelContainer
class_name SettingsPanel

signal back_pressed()

enum SettingsTab {
	AUDIO,
	CONTROLS,
	KEYBINDS,
	VIDEO,
}

var _current_tab: SettingsTab = SettingsTab.AUDIO
var _tab_buttons: Dictionary = {}
var _tab_pages: Dictionary = {}

var _master_slider: HSlider
var _master_val_label: Label
var _player_slider: HSlider
var _player_val_label: Label
var _enemy_slider: HSlider
var _enemy_val_label: Label
var _sens_slider: HSlider
var _sens_val_label: Label
var _fov_slider: HSlider
var _fov_val_label: Label
var _shader_preset_buttons: Array[Button] = []
var _pixel_scale_slider: HSlider
var _pixel_scale_val_label: Label
var _dither_slider: HSlider
var _dither_val_label: Label
var _color_steps_slider: HSlider
var _color_steps_val_label: Label

var _rebind_buttons: Dictionary = {}
var _listening_action: String = ""
var _updating_ui: bool = false
var _blink_timer: float = 0.0
var _sfx_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(650.0, 540.0)
	_sfx_player = MenuUIKit.make_sfx_player(self, "SettingsSfx", -6.0)
	_apply_panel_style()
	_build_ui()
	_select_tab(SettingsTab.AUDIO, false)
	refresh_from_settings()


func _process(delta: float) -> void:
	if not visible or _listening_action.is_empty():
		return
	_blink_timer += delta * 6.0
	var btn_var: Variant = _rebind_buttons.get(_listening_action)
	if btn_var is Button:
		var btn: Button = btn_var as Button
		var pulse: float = 0.5 + 0.5 * sin(_blink_timer)
		btn.text = ">> PRESS KEY <<" if pulse > 0.35 else "   PRESS KEY   "


func is_listening_for_rebind() -> bool:
	return not _listening_action.is_empty()


func cancel_rebind() -> void:
	if _listening_action.is_empty():
		return
	_listening_action = ""
	_refresh_keybind_labels()


func _input(event: InputEvent) -> void:
	if not visible or _listening_action.is_empty():
		return

	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		get_viewport().set_input_as_handled()
		if ke.keycode == KEY_ESCAPE:
			MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_TICK_PATH, 0.85)
			cancel_rebind()
			return
		var bound_key: InputEventKey = InputEventKey.new()
		bound_key.physical_keycode = ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode
		var gs: Node = _get_settings()
		if gs != null:
			gs.call("rebind_action", _listening_action, bound_key)
		MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_CLICK_PATH, 1.08)
		_listening_action = ""
		_refresh_keybind_labels()
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return
		get_viewport().set_input_as_handled()
		var bound_mb: InputEventMouseButton = InputEventMouseButton.new()
		bound_mb.button_index = mb.button_index
		var gs2: Node = _get_settings()
		if gs2 != null:
			gs2.call("rebind_action", _listening_action, bound_mb)
		MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_CLICK_PATH, 1.08)
		_listening_action = ""
		_refresh_keybind_labels()


func _apply_panel_style() -> void:
	var sb: StyleBoxFlat = MenuUIKit.make_flat_box(
		MenuUIKit.COL_BG_PANEL,
		MenuUIKit.COL_BORDER_LIGHT,
		2,
		0.0,
		0.0,
		-1,
		Vector2(8.0, 8.0)
	)
	add_theme_stylebox_override("panel", sb)


func _build_ui() -> void:
	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	add_child(outer_vbox)

	# Top Hazard Accent
	outer_vbox.add_child(MenuUIKit.make_hazard_bar(6.0, MenuUIKit.COL_CRIMSON))

	# Header Band
	var header_panel: PanelContainer = PanelContainer.new()
	header_panel.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.04, 0.045, 0.042, 1.0), MenuUIKit.COL_BORDER_DIM, 0, 20.0, 10.0)
	)
	outer_vbox.add_child(header_panel)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_panel.add_child(header_hbox)

	var title: Label = Label.new()
	title.text = "SETTINGS"
	var disp_f: Font = MenuUIKit.get_display_italic_font()
	if disp_f != null:
		title.add_theme_font_override("font", disp_f)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	title.add_theme_color_override("font_shadow_color", MenuUIKit.COL_CRIMSON)
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	var sys_tag: Label = Label.new()
	sys_tag.text = "// CONFIG.SYS"
	sys_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mono_f: Font = MenuUIKit.get_mono_font()
	if mono_f != null:
		sys_tag.add_theme_font_override("font", mono_f)
	sys_tag.add_theme_font_size_override("font_size", 12)
	sys_tag.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
	header_hbox.add_child(sys_tag)

	# Tab Bar
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 2)
	outer_vbox.add_child(tab_bar)

	_add_tab_button(tab_bar, SettingsTab.AUDIO, "01 // AUDIO")
	_add_tab_button(tab_bar, SettingsTab.CONTROLS, "02 // CONTROLS")
	_add_tab_button(tab_bar, SettingsTab.KEYBINDS, "03 // KEYBINDS")
	_add_tab_button(tab_bar, SettingsTab.VIDEO, "04 // VIDEO")

	# Thin crimson underline under tabs
	var tab_rule: ColorRect = ColorRect.new()
	tab_rule.custom_minimum_size = Vector2(0.0, 2.0)
	tab_rule.color = MenuUIKit.COL_CRIMSON
	outer_vbox.add_child(tab_rule)

	# Main Content Area
	var body_margin: MarginContainer = MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 20)
	body_margin.add_theme_constant_override("margin_right", 20)
	body_margin.add_theme_constant_override("margin_top", 12)
	body_margin.add_theme_constant_override("margin_bottom", 12)
	outer_vbox.add_child(body_margin)

	var page_stack: Control = Control.new()
	page_stack.clip_contents = true
	page_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_child(page_stack)

	# PAGE 1: AUDIO
	var audio_page: VBoxContainer = VBoxContainer.new()
	audio_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	audio_page.add_theme_constant_override("separation", 10)
	page_stack.add_child(audio_page)
	_tab_pages[SettingsTab.AUDIO] = audio_page

	_add_sub_banner(audio_page, "SOUND MIXER // OUTPUT CHANNELS")
	var m_row: Dictionary = _add_slider_card(audio_page, "MASTER VOLUME", "GLOBAL OUTPUT LEVEL", 0.0, 1.0, 0.01, MenuUIKit.COL_ACID, _on_master_changed)
	_master_slider = m_row["slider"] as HSlider
	_master_val_label = m_row["value"] as Label

	var p_row: Dictionary = _add_slider_card(audio_page, "PLAYER SFX", "WEAPONS, PARRY, GRAPPLE, STEPS", 0.0, 1.0, 0.01, MenuUIKit.COL_ACID, _on_player_sfx_changed)
	_player_slider = p_row["slider"] as HSlider
	_player_val_label = p_row["value"] as Label

	var e_row: Dictionary = _add_slider_card(audio_page, "ENEMY SFX", "ALIEN VOICES, SHOTS, EXPLOSIONS", 0.0, 1.0, 0.01, MenuUIKit.COL_CRIMSON, _on_enemy_sfx_changed)
	_enemy_slider = e_row["slider"] as HSlider
	_enemy_val_label = e_row["value"] as Label

	# PAGE 2: CONTROLS
	var ctrl_page: VBoxContainer = VBoxContainer.new()
	ctrl_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl_page.add_theme_constant_override("separation", 14)
	page_stack.add_child(ctrl_page)
	_tab_pages[SettingsTab.CONTROLS] = ctrl_page

	_add_sub_banner(ctrl_page, "AIM & OPTICS // CAMERA PARAMETERS")
	var s_row: Dictionary = _add_slider_card(ctrl_page, "MOUSE SENSITIVITY", "LOOK TURN RATE MULTIPLIER", 0.15, 3.0, 0.05, MenuUIKit.COL_CRIMSON, _on_sens_changed)
	_sens_slider = s_row["slider"] as HSlider
	_sens_val_label = s_row["value"] as Label

	var f_row: Dictionary = _add_slider_card(ctrl_page, "FIELD OF VIEW", "BASE CAMERA FOV (SPRINT/SLIDE SCALES)", 65.0, 105.0, 1.0, MenuUIKit.COL_ACID, _on_fov_changed)
	_fov_slider = f_row["slider"] as HSlider
	_fov_val_label = f_row["value"] as Label

	var note_box: PanelContainer = PanelContainer.new()
	note_box.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.05, 0.055, 0.052, 0.9), MenuUIKit.COL_ACID_DIM, 1, 14.0, 10.0, 4)
	)
	ctrl_page.add_child(note_box)
	var note_lbl: Label = Label.new()
	note_lbl.text = "TIP: MOUSE WHEEL CYCLES RIGHT-HAND WEAPONS (FIST / PISTOL / SHOTGUN)."
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mono_f != null:
		note_lbl.add_theme_font_override("font", mono_f)
	note_lbl.add_theme_font_size_override("font_size", 12)
	note_lbl.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	note_box.add_child(note_lbl)

	# PAGE 3: KEYBINDS
	var keys_page: VBoxContainer = VBoxContainer.new()
	keys_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	keys_page.add_theme_constant_override("separation", 10)
	page_stack.add_child(keys_page)
	_tab_pages[SettingsTab.KEYBINDS] = keys_page

	_add_sub_banner(keys_page, "CLICK A KEYCAP TO REBIND  //  ESC TO CANCEL")

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	MenuUIKit.style_brutalist_scrollbar(scroll)
	keys_page.add_child(scroll)

	var keys_vbox: VBoxContainer = VBoxContainer.new()
	keys_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(keys_vbox)

	var gs: Node = _get_settings()
	if gs != null:
		var actions_var: Variant = gs.get("REBINDABLE_ACTIONS")
		if actions_var is Array:
			for entry_var: Variant in (actions_var as Array):
				if entry_var is Dictionary:
					var entry: Dictionary = entry_var as Dictionary
					_add_keybind_row(keys_vbox, str(entry["action"]), str(entry["label"]))

	# PAGE 4: VIDEO / RETRO SHADER
	var video_page: VBoxContainer = VBoxContainer.new()
	video_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_page.add_theme_constant_override("separation", 8)
	page_stack.add_child(video_page)
	_tab_pages[SettingsTab.VIDEO] = video_page

	_add_sub_banner(video_page, "PS2 RETRO POST-PROCESS // LIVE SHADER PRESET")

	var preset_card: PanelContainer = PanelContainer.new()
	preset_card.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(MenuUIKit.COL_BG_ROW, MenuUIKit.COL_BORDER_DIM, 1, 12.0, 8.0, 4)
	)
	video_page.add_child(preset_card)

	var preset_hbox: HBoxContainer = HBoxContainer.new()
	preset_hbox.add_theme_constant_override("separation", 6)
	preset_card.add_child(preset_hbox)

	var preset_names: Array[String] = ["OFF", "PS2 CLASSIC", "ULTRAKILL", "PS1 CRUNCH"]
	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	for p_idx: int in range(preset_names.size()):
		var p_btn: Button = Button.new()
		p_btn.text = preset_names[p_idx]
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.custom_minimum_size = Vector2(0.0, 36.0)
		p_btn.focus_mode = Control.FOCUS_NONE
		p_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if mono_h != null:
			p_btn.add_theme_font_override("font", mono_h)
		p_btn.add_theme_font_size_override("font_size", 12)
		p_btn.pressed.connect(_on_shader_preset_pressed.bind(p_idx))
		preset_hbox.add_child(p_btn)
		_shader_preset_buttons.append(p_btn)

	var ps_row: Dictionary = _add_slider_card(video_page, "PIXEL SCALE", "VIRTUAL RETRO RESOLUTION (1.0x = NATIVE)", 1.0, 3.5, 0.05, MenuUIKit.COL_ACID, _on_pixel_scale_changed)
	_pixel_scale_slider = ps_row["slider"] as HSlider
	_pixel_scale_val_label = ps_row["value"] as Label

	var dt_row: Dictionary = _add_slider_card(video_page, "BAYER DITHER", "4x4 ORDERED PS2 DITHERING INTENSITY", 0.0, 1.5, 0.05, MenuUIKit.COL_ACID, _on_dither_changed)
	_dither_slider = dt_row["slider"] as HSlider
	_dither_val_label = dt_row["value"] as Label

	var cs_row: Dictionary = _add_slider_card(video_page, "COLOR DEPTH", "RGB QUANTIZATION LEVELS (LOWER = MORE RETRO)", 10.0, 48.0, 1.0, MenuUIKit.COL_CRIMSON, _on_color_steps_changed)
	_color_steps_slider = cs_row["slider"] as HSlider
	_color_steps_val_label = cs_row["value"] as Label

	# Footer Action Bar
	var footer_panel: PanelContainer = PanelContainer.new()
	footer_panel.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(Color(0.04, 0.045, 0.042, 1.0), MenuUIKit.COL_BORDER_DIM, 0, 22.0, 12.0)
	)
	outer_vbox.add_child(footer_panel)

	var footer_hbox: HBoxContainer = HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 14)
	footer_panel.add_child(footer_hbox)

	var reset_btn: Button = _make_footer_button("RESET DEFAULTS", MenuUIKit.COL_CRIMSON)
	reset_btn.pressed.connect(_on_reset_pressed)
	footer_hbox.add_child(reset_btn)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(spacer)

	var back_btn: Button = _make_footer_button("BACK [ESC]", MenuUIKit.COL_ACID)
	back_btn.pressed.connect(_on_back_pressed)
	footer_hbox.add_child(back_btn)


func _add_tab_button(parent: HBoxContainer, tab_id: SettingsTab, text_val: String) -> void:
	var btn: Button = Button.new()
	btn.text = text_val
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0.0, 42.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	if mono_h != null:
		btn.add_theme_font_override("font", mono_h)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_select_tab.bind(tab_id, true))
	parent.add_child(btn)
	_tab_buttons[tab_id] = btn


func _select_tab(tab_id: SettingsTab, play_sfx: bool) -> void:
	cancel_rebind()
	_current_tab = tab_id
	if play_sfx:
		MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_TICK_PATH, 1.12)

	for tid_var: Variant in _tab_pages.keys():
		var tid: SettingsTab = tid_var as SettingsTab
		var page: Control = _tab_pages[tid] as Control
		page.visible = (tid == tab_id)

	for tid_var2: Variant in _tab_buttons.keys():
		var tid2: SettingsTab = tid_var2 as SettingsTab
		var btn: Button = _tab_buttons[tid2] as Button
		if tid2 == tab_id:
			btn.add_theme_stylebox_override("normal", MenuUIKit.make_flat_box(MenuUIKit.COL_CRIMSON))
			btn.add_theme_stylebox_override("hover", MenuUIKit.make_flat_box(MenuUIKit.COL_CRIMSON))
			btn.add_theme_stylebox_override("pressed", MenuUIKit.make_flat_box(MenuUIKit.COL_CRIMSON))
			btn.add_theme_color_override("font_color", MenuUIKit.COL_BLACK)
			btn.add_theme_color_override("font_hover_color", MenuUIKit.COL_BLACK)
		else:
			btn.add_theme_stylebox_override("normal", MenuUIKit.make_flat_box(Color(0.09, 0.098, 0.094, 1.0), MenuUIKit.COL_BORDER_DIM, 1))
			btn.add_theme_stylebox_override("hover", MenuUIKit.make_flat_box(Color(0.15, 0.16, 0.15, 1.0), MenuUIKit.COL_BONE, 1))
			btn.add_theme_stylebox_override("pressed", MenuUIKit.make_flat_box(MenuUIKit.COL_CRIMSON_DARK))
			btn.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
			btn.add_theme_color_override("font_hover_color", MenuUIKit.COL_BONE)


func _add_sub_banner(parent: VBoxContainer, text_val: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text_val
	var mono_f: Font = MenuUIKit.get_mono_font()
	if mono_f != null:
		lbl.add_theme_font_override("font", mono_f)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	parent.add_child(lbl)


func _add_slider_card(
	parent: VBoxContainer,
	label_text: String,
	subtitle_text: String,
	min_v: float,
	max_v: float,
	step_v: float,
	fill_col: Color,
	callback: Callable
) -> Dictionary:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(MenuUIKit.COL_BG_ROW, MenuUIKit.COL_BORDER_DIM, 1, 14.0, 9.0, 4)
	)
	parent.add_child(card)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var top_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(top_row)

	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 1)
	top_row.add_child(left_col)

	var name_lbl: Label = Label.new()
	name_lbl.text = label_text
	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	if mono_h != null:
		name_lbl.add_theme_font_override("font", mono_h)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	left_col.add_child(name_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = subtitle_text
	var mono_f: Font = MenuUIKit.get_mono_font()
	if mono_f != null:
		sub_lbl.add_theme_font_override("font", mono_f)
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
	left_col.add_child(sub_lbl)

	var val_lbl: Label = Label.new()
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var disp_f: Font = MenuUIKit.get_display_font()
	if disp_f != null:
		val_lbl.add_theme_font_override("font", disp_f)
	val_lbl.add_theme_font_size_override("font_size", 24)
	val_lbl.add_theme_color_override("font_color", fill_col)
	top_row.add_child(val_lbl)

	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0.0, 22.0)
	slider.focus_mode = Control.FOCUS_NONE
	MenuUIKit.style_brutalist_slider(slider, fill_col)
	slider.value_changed.connect(callback)
	vbox.add_child(slider)

	return {"slider": slider, "value": val_lbl}


func _add_keybind_row(parent: VBoxContainer, action_name: String, display_label: String) -> void:
	var row_panel: PanelContainer = PanelContainer.new()
	row_panel.add_theme_stylebox_override(
		"panel",
		MenuUIKit.make_flat_box(MenuUIKit.COL_BG_ROW, MenuUIKit.COL_BORDER_DIM, 1, 14.0, 6.0)
	)
	parent.add_child(row_panel)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row_panel.add_child(row)

	var lbl: Label = Label.new()
	lbl.text = display_label.to_upper()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mono_f: Font = MenuUIKit.get_mono_font()
	if mono_f != null:
		lbl.add_theme_font_override("font", mono_f)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	row.add_child(lbl)

	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(180.0, 34.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	if mono_h != null:
		btn.add_theme_font_override("font", mono_h)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_start_listening.bind(action_name))
	row.add_child(btn)
	_rebind_buttons[action_name] = btn


func _make_footer_button(text_val: String, accent: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text_val
	btn.custom_minimum_size = Vector2(168.0, 42.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var mono_h: Font = MenuUIKit.get_mono_heavy_font()
	if mono_h != null:
		btn.add_theme_font_override("font", mono_h)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_stylebox_override("normal", MenuUIKit.make_flat_box(Color(0.08, 0.085, 0.082, 1.0), accent, 2))
	btn.add_theme_stylebox_override("hover", MenuUIKit.make_flat_box(accent, MenuUIKit.COL_BONE, 2))
	btn.add_theme_stylebox_override("pressed", MenuUIKit.make_flat_box(MenuUIKit.COL_BONE, accent, 2))
	btn.add_theme_color_override("font_color", MenuUIKit.COL_BONE)
	btn.add_theme_color_override("font_hover_color", MenuUIKit.COL_BLACK)
	btn.add_theme_color_override("font_pressed_color", MenuUIKit.COL_BLACK)
	btn.mouse_entered.connect(func() -> void: MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_HOVER_PATH, 1.1))
	return btn


func _start_listening(action_name: String) -> void:
	_listening_action = action_name
	_blink_timer = 0.0
	MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_TICK_PATH, 1.25)
	_refresh_keybind_labels()


func refresh_from_settings() -> void:
	var gs: Node = _get_settings()
	if gs == null:
		return
	_updating_ui = true
	var mv: float = float(gs.get("master_volume"))
	var pv: float = float(gs.get("player_sfx_volume"))
	var ev: float = float(gs.get("enemy_sfx_volume"))
	var sens: float = float(gs.get("mouse_sensitivity_scale"))
	var fov_v: float = float(gs.get("fov"))
	var preset_idx: int = int(gs.get("retro_shader_preset"))
	var px_scale: float = float(gs.get("retro_pixel_scale"))
	var dither_v: float = float(gs.get("retro_dither_strength"))
	var c_steps: float = float(gs.get("retro_color_steps"))

	if _master_slider != null:
		_master_slider.value = mv
	if _player_slider != null:
		_player_slider.value = pv
	if _enemy_slider != null:
		_enemy_slider.value = ev
	if _sens_slider != null:
		_sens_slider.value = sens
	if _fov_slider != null:
		_fov_slider.value = fov_v
	if _pixel_scale_slider != null:
		_pixel_scale_slider.value = px_scale
	if _dither_slider != null:
		_dither_slider.value = dither_v
	if _color_steps_slider != null:
		_color_steps_slider.value = c_steps

	_update_value_labels(mv, pv, ev, sens, fov_v)
	_update_video_labels(preset_idx, px_scale, dither_v, c_steps)
	_refresh_keybind_labels()
	_updating_ui = false


func _update_video_labels(preset_idx: int, px_scale: float, dither_v: float, c_steps: float) -> void:
	if _pixel_scale_val_label != null:
		_pixel_scale_val_label.text = "%.2fx" % px_scale
	if _dither_val_label != null:
		_dither_val_label.text = "%d%%" % int(round(dither_v * 100.0))
	if _color_steps_val_label != null:
		_color_steps_val_label.text = "%d LVL" % int(round(c_steps))
	for i: int in range(_shader_preset_buttons.size()):
		var btn: Button = _shader_preset_buttons[i]
		if i == preset_idx:
			var active_col: Color = MenuUIKit.COL_CRIMSON if i == 0 else MenuUIKit.COL_ACID
			btn.add_theme_stylebox_override("normal", MenuUIKit.make_flat_box(active_col, MenuUIKit.COL_BONE, 2))
			btn.add_theme_stylebox_override("hover", MenuUIKit.make_flat_box(active_col, MenuUIKit.COL_BONE, 2))
			btn.add_theme_stylebox_override("pressed", MenuUIKit.make_flat_box(active_col, MenuUIKit.COL_BONE, 2))
			btn.add_theme_color_override("font_color", MenuUIKit.COL_BLACK)
			btn.add_theme_color_override("font_hover_color", MenuUIKit.COL_BLACK)
		else:
			btn.add_theme_stylebox_override("normal", MenuUIKit.make_flat_box(Color(0.06, 0.066, 0.064, 1.0), MenuUIKit.COL_BORDER_DIM, 1))
			btn.add_theme_stylebox_override("hover", MenuUIKit.make_flat_box(Color(0.14, 0.15, 0.14, 1.0), MenuUIKit.COL_BONE, 1))
			btn.add_theme_stylebox_override("pressed", MenuUIKit.make_flat_box(MenuUIKit.COL_ACID_DIM))
			btn.add_theme_color_override("font_color", MenuUIKit.COL_MUTED)
			btn.add_theme_color_override("font_hover_color", MenuUIKit.COL_BONE)


func _update_value_labels(mv: float, pv: float, ev: float, sens: float, fov_v: float) -> void:
	if _master_val_label != null:
		_master_val_label.text = "%d%%" % int(round(mv * 100.0))
	if _player_val_label != null:
		_player_val_label.text = "%d%%" % int(round(pv * 100.0))
	if _enemy_val_label != null:
		_enemy_val_label.text = "%d%%" % int(round(ev * 100.0))
	if _sens_val_label != null:
		_sens_val_label.text = "%.2fx" % sens
	if _fov_val_label != null:
		_fov_val_label.text = "%d°" % int(round(fov_v))


func _refresh_keybind_labels() -> void:
	var gs: Node = _get_settings()
	for act_key: Variant in _rebind_buttons.keys():
		var act: String = str(act_key)
		var btn: Button = _rebind_buttons[act] as Button
		if act == _listening_action:
			btn.text = ">> PRESS KEY <<"
			btn.add_theme_stylebox_override("normal", MenuUIKit.make_flat_box(MenuUIKit.COL_CRIMSON, MenuUIKit.COL_BONE, 2))
			btn.add_theme_stylebox_override("hover", MenuUIKit.make_flat_box(MenuUIKit.COL_CRIMSON, MenuUIKit.COL_BONE, 2))
			btn.add_theme_color_override("font_color", MenuUIKit.COL_BLACK)
			btn.add_theme_color_override("font_hover_color", MenuUIKit.COL_BLACK)
		else:
			var label_str: String = "UNBOUND"
			if gs != null and gs.has_method("format_action_binding"):
				label_str = str(gs.call("format_action_binding", act))
			btn.text = "[ %s ]" % label_str
			btn.add_theme_stylebox_override("normal", MenuUIKit.make_flat_box(Color(0.05, 0.055, 0.052, 1.0), MenuUIKit.COL_BORDER_LIGHT, 2))
			btn.add_theme_stylebox_override("hover", MenuUIKit.make_flat_box(MenuUIKit.COL_ACID, MenuUIKit.COL_BLACK, 2))
			btn.add_theme_stylebox_override("pressed", MenuUIKit.make_flat_box(MenuUIKit.COL_CRIMSON, MenuUIKit.COL_BONE, 2))
			btn.add_theme_color_override("font_color", MenuUIKit.COL_ACID)
			btn.add_theme_color_override("font_hover_color", MenuUIKit.COL_BLACK)


func _on_master_changed(val: float) -> void:
	if _master_val_label != null:
		_master_val_label.text = "%d%%" % int(round(val * 100.0))
	if _updating_ui:
		return
	var gs: Node = _get_settings()
	if gs != null:
		gs.call("set_master_volume", val)


func _on_player_sfx_changed(val: float) -> void:
	if _player_val_label != null:
		_player_val_label.text = "%d%%" % int(round(val * 100.0))
	if _updating_ui:
		return
	var gs: Node = _get_settings()
	if gs != null:
		gs.call("set_player_sfx_volume", val)


func _on_enemy_sfx_changed(val: float) -> void:
	if _enemy_val_label != null:
		_enemy_val_label.text = "%d%%" % int(round(val * 100.0))
	if _updating_ui:
		return
	var gs: Node = _get_settings()
	if gs != null:
		gs.call("set_enemy_sfx_volume", val)


func _on_sens_changed(val: float) -> void:
	if _sens_val_label != null:
		_sens_val_label.text = "%.2fx" % val
	if _updating_ui:
		return
	var gs: Node = _get_settings()
	if gs != null:
		gs.call("set_mouse_sensitivity_scale", val)


func _on_fov_changed(val: float) -> void:
	if _fov_val_label != null:
		_fov_val_label.text = "%d°" % int(round(val))
	if _updating_ui:
		return
	var gs: Node = _get_settings()
	if gs != null:
		gs.call("set_fov", val)


func _on_shader_preset_pressed(preset_idx: int) -> void:
	MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_CLICK_PATH, 1.08)
	var gs: Node = _get_settings()
	if gs != null:
		gs.call("set_shader_preset", preset_idx)
	refresh_from_settings()


func _on_pixel_scale_changed(val: float) -> void:
	if _pixel_scale_val_label != null:
		_pixel_scale_val_label.text = "%.2fx" % val
	if _updating_ui:
		return
	var gs: Node = _get_settings()
	if gs != null:
		gs.call("set_retro_pixel_scale", val)
		_update_video_labels(int(gs.get("retro_shader_preset")), val, float(gs.get("retro_dither_strength")), float(gs.get("retro_color_steps")))


func _on_dither_changed(val: float) -> void:
	if _dither_val_label != null:
		_dither_val_label.text = "%d%%" % int(round(val * 100.0))
	if _updating_ui:
		return
	var gs: Node = _get_settings()
	if gs != null:
		gs.call("set_retro_dither_strength", val)
		_update_video_labels(int(gs.get("retro_shader_preset")), float(gs.get("retro_pixel_scale")), val, float(gs.get("retro_color_steps")))


func _on_color_steps_changed(val: float) -> void:
	if _color_steps_val_label != null:
		_color_steps_val_label.text = "%d LVL" % int(round(val))
	if _updating_ui:
		return
	var gs: Node = _get_settings()
	if gs != null:
		gs.call("set_retro_color_steps", val)
		_update_video_labels(int(gs.get("retro_shader_preset")), float(gs.get("retro_pixel_scale")), float(gs.get("retro_dither_strength")), val)


func _on_reset_pressed() -> void:
	cancel_rebind()
	MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_CLICK_PATH, 0.9)
	var gs: Node = _get_settings()
	if gs != null:
		gs.call("reset_to_defaults")
	refresh_from_settings()


func _on_back_pressed() -> void:
	cancel_rebind()
	MenuUIKit.play_ui_sfx(_sfx_player, MenuUIKit.SFX_CLICK_PATH, 1.0)
	back_pressed.emit()


func _get_settings() -> Node:
	return get_node_or_null("/root/GameSettings")
