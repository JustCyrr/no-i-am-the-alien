extends Control
class_name PixelReticle

# Crisp 1px black-outlined PS2/ULTRAKILL pixel reticle with reactive per-weapon hit feedback.

var center_color: Color = Color(1.0, 1.0, 1.0, 0.92)
var weapon_mode: int = 0 # 0=fist, 1=pistol, 2=shotgun

var _hit_alpha: float = 0.0
var _hit_color: Color = Color(1.0, 0.94, 0.72, 1.0)
var _hit_radius: float = 6.0
var _hit_target_radius: float = 6.0
var _hit_is_kill: bool = false
var _hit_is_blocked: bool = false
var _recoil_bloom: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -48.0
	offset_top = -48.0
	offset_right = 48.0
	offset_bottom = 48.0
	custom_minimum_size = Vector2(96.0, 96.0)


func set_weapon_mode(mode: int) -> void:
	if weapon_mode != mode:
		weapon_mode = mode
		queue_redraw()


func set_center_color(col: Color) -> void:
	if center_color != col:
		center_color = col
		queue_redraw()


func add_fire_bloom(amount: float) -> void:
	_recoil_bloom = minf(18.0, _recoil_bloom + amount)
	queue_redraw()


func trigger_hit(spread_px: float, col: Color, is_kill: bool, is_blocked: bool) -> void:
	_hit_alpha = 1.0
	_hit_color = col
	_hit_is_kill = is_kill
	_hit_is_blocked = is_blocked
	_hit_radius = spread_px * (1.35 if is_kill else 1.15)
	_hit_target_radius = spread_px * 0.52
	_recoil_bloom = maxf(_recoil_bloom, 4.5 if is_kill else 2.5)
	queue_redraw()


func _process(delta: float) -> void:
	var dirty: bool = false
	if _hit_alpha > 0.0:
		var fade_rate: float = 4.8 if _hit_is_kill else 8.2
		_hit_alpha = maxf(0.0, _hit_alpha - delta * fade_rate)
		_hit_radius = lerpf(_hit_radius, _hit_target_radius, minf(1.0, delta * 22.0))
		dirty = true
	if _recoil_bloom > 0.05:
		_recoil_bloom = lerpf(_recoil_bloom, 0.0, minf(1.0, delta * 14.0))
		dirty = true
	elif _recoil_bloom != 0.0:
		_recoil_bloom = 0.0
		dirty = true
	if dirty:
		queue_redraw()


func _draw_outlined_rect(r: Rect2, fill_col: Color, alpha: float = 1.0) -> void:
	var rx: float = floor(r.position.x)
	var ry: float = floor(r.position.y)
	var rw: float = floor(r.size.x)
	var rh: float = floor(r.size.y)
	var outline_c: Color = Color(0.0, 0.0, 0.0, clampf(alpha * 0.92, 0.0, 1.0))
	var fill_c: Color = Color(fill_col.r, fill_col.g, fill_col.b, clampf(fill_col.a * alpha, 0.0, 1.0))
	draw_rect(Rect2(rx - 1.0, ry - 1.0, rw + 2.0, rh + 2.0), outline_c, true)
	draw_rect(Rect2(rx, ry, rw, rh), fill_c, true)


func _draw() -> void:
	var c: Vector2 = size * 0.5

	# 1) Crisp 1px-outlined center pip (expands subtly on kill flash)
	var dot_sz: float = 4.0 if (_hit_alpha > 0.35 and _hit_is_kill) else 2.0
	var dot_col: Color = _hit_color if _hit_alpha > 0.25 else center_color
	_draw_outlined_rect(Rect2(c.x - dot_sz * 0.5, c.y - dot_sz * 0.5, dot_sz, dot_sz), dot_col, 1.0)

	# 2) Subtle weapon-specific tactical frame (clean PS2 pixel brackets)
	var frame_col: Color = Color(center_color.r, center_color.g, center_color.b, 0.72)
	if weapon_mode == 1:
		# Pistol: tight horizontal side ticks
		var gap: float = 7.0 + _recoil_bloom * 0.65
		_draw_outlined_rect(Rect2(c.x - gap - 5.0, c.y - 1.0, 5.0, 2.0), frame_col, 0.85)
		_draw_outlined_rect(Rect2(c.x + gap, c.y - 1.0, 5.0, 2.0), frame_col, 0.85)
	elif weapon_mode == 2:
		# Shotgun: crisp 4-corner pellet-spread L-brackets
		var r: float = 15.0 + _recoil_bloom * 0.85
		var arm: float = 5.0
		# Top-left
		_draw_outlined_rect(Rect2(c.x - r, c.y - r, arm, 2.0), frame_col, 0.80)
		_draw_outlined_rect(Rect2(c.x - r, c.y - r, 2.0, arm), frame_col, 0.80)
		# Top-right
		_draw_outlined_rect(Rect2(c.x + r - arm, c.y - r, arm, 2.0), frame_col, 0.80)
		_draw_outlined_rect(Rect2(c.x + r - 2.0, c.y - r, 2.0, arm), frame_col, 0.80)
		# Bottom-left
		_draw_outlined_rect(Rect2(c.x - r, c.y + r - 2.0, arm, 2.0), frame_col, 0.80)
		_draw_outlined_rect(Rect2(c.x - r, c.y + r - arm, 2.0, arm), frame_col, 0.80)
		# Bottom-right
		_draw_outlined_rect(Rect2(c.x + r - arm, c.y + r - 2.0, arm, 2.0), frame_col, 0.80)
		_draw_outlined_rect(Rect2(c.x + r - 2.0, c.y + r - arm, 2.0, arm), frame_col, 0.80)

	# 3) Reactive pixel-stepped impact brackets (1px black outline, zero blurry rotated quads!)
	if _hit_alpha > 0.02:
		var a: float = clampf(_hit_alpha * 1.15, 0.0, 1.0)
		var r: float = floor(_hit_radius)
		var steps: int = 4 if _hit_is_kill else 3
		var px: float = 2.0
		var dirs: Array[Vector2] = [
			Vector2(-1.0, -1.0),
			Vector2(1.0, -1.0),
			Vector2(-1.0, 1.0),
			Vector2(1.0, 1.0),
		]
		# Draw black outline pass first so diagonal pixel stairs fuse cleanly
		var outline_c: Color = Color(0.0, 0.0, 0.0, a * 0.92)
		var fill_c: Color = Color(_hit_color.r, _hit_color.g, _hit_color.b, a)
		for d: Vector2 in dirs:
			for s: int in range(steps):
				var p: Vector2 = c + d * (r + float(s) * px)
				draw_rect(Rect2(floor(p.x - 2.0), floor(p.y - 2.0), px + 2.0, px + 2.0), outline_c, true)
		for d: Vector2 in dirs:
			for s: int in range(steps):
				var p: Vector2 = c + d * (r + float(s) * px)
				draw_rect(Rect2(floor(p.x - 1.0), floor(p.y - 1.0), px, px), fill_c, true)

		# On kill: crisp inner diamond corners framing the reticle!
		if _hit_is_kill and not _hit_is_blocked:
			var kr: float = r + float(steps) * px + 2.0
			_draw_outlined_rect(Rect2(c.x - 2.0, c.y - kr - 2.0, 4.0, 2.0), fill_c, a)
			_draw_outlined_rect(Rect2(c.x - 2.0, c.y + kr, 4.0, 2.0), fill_c, a)
			_draw_outlined_rect(Rect2(c.x - kr - 2.0, c.y - 2.0, 2.0, 4.0), fill_c, a)
			_draw_outlined_rect(Rect2(c.x + kr, c.y - 2.0, 2.0, 4.0), fill_c, a)
