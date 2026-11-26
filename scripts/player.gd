extends CharacterBody3D

signal punch_started(arm_side: String)
signal punch_hit(arm_side: String, target: Object, hit_position: Vector3)
signal parry_succeeded(projectile: Projectile3D)
signal stamina_changed(current_stamina: float, max_value: float)
signal health_changed(current_hp: int, max_value: int)
signal player_died()

const STAMINA_UNDER_PATH: String = "res://assets/ui/stamina_bar/stamina_bar_under.png"
const STAMINA_UNDER_RED_PATH: String = "res://assets/ui/stamina_bar/stamina_bar_under_red.png"
const STAMINA_FILL_ORANGE_PATH: String = "res://assets/ui/stamina_bar/stamina_bar_fill_orange.png"
const STAMINA_FILL_RED_PATH: String = "res://assets/ui/stamina_bar/stamina_bar_fill_red.png"

const SKULLS_PATHS: Array[String] = [
	"res://assets/ui/health_skulls/skulls_0hp.png",
	"res://assets/ui/health_skulls/skulls_1hp.png",
	"res://assets/ui/health_skulls/skulls_2hp.png",
	"res://assets/ui/health_skulls/skulls_3hp.png",
]

const PARRY_FRAMES_DIR: String = "res://assets/hands/parry/frames"
const PARRY_FRAME_COUNT: int = 12
const SHIELD_ACTIVE_PATH: String = "res://assets/ui/shield_icon/shield_active.png"
const SHIELD_FLASH_PATH: String = "res://assets/ui/shield_icon/shield_flash.png"
const GRAPPLE_HAND_READY_PATH: String = "res://assets/hands/grapple/grapple_hand.png"
const GRAPPLE_HAND_FIRED_PATH: String = "res://assets/hands/grapple/grapple_hand_fired.png"

const SFX_HIT_FIST: String = "res://assets/audio/weapons/hit_thump_fist.wav"
const SFX_HIT_PISTOL: String = "res://assets/audio/weapons/hit_snap_pistol.wav"
const SFX_HIT_SHOTGUN: String = "res://assets/audio/weapons/hit_boom_shotgun.wav"
const SFX_HIT_SLIDE: String = "res://assets/audio/weapons/hit_crunch_slide.wav"
const SFX_KILL_CONFIRM: String = "res://assets/audio/weapons/hit_kill_confirm.wav"

const HIT_FEEL_PROFILES: Dictionary = {
	"fist_left": {
		"hitstop_ms": 24.0,
		"kill_hitstop_ms": 44.0,
		"hitstop_min_scale": 0.0,
		"trauma": 0.28,
		"z_kick": 0.085,
		"pitch_kick": 2.1,
		"roll_kick": -3.4,
		"fov_punch": -2.4,
		"marker_spread": 7.5,
		"marker_color": Color(1.0, 0.90, 0.42, 1.0),
		"sfx": SFX_HIT_FIST,
		"vol_db": 1.6,
		"pitch_min": 0.93,
		"pitch_max": 1.05,
	},
	"fist_right": {
		"hitstop_ms": 24.0,
		"kill_hitstop_ms": 44.0,
		"hitstop_min_scale": 0.0,
		"trauma": 0.28,
		"z_kick": 0.085,
		"pitch_kick": 2.1,
		"roll_kick": 3.4,
		"fov_punch": -2.4,
		"marker_spread": 7.5,
		"marker_color": Color(1.0, 0.90, 0.42, 1.0),
		"sfx": SFX_HIT_FIST,
		"vol_db": 1.6,
		"pitch_min": 0.93,
		"pitch_max": 1.05,
	},
	"pistol": {
		"hitstop_ms": 0.0,
		"kill_hitstop_ms": 24.0,
		"hitstop_min_scale": 0.0,
		"trauma": 0.16,
		"z_kick": 0.045,
		"pitch_kick": 1.2,
		"roll_kick": 1.0,
		"fov_punch": 1.3,
		"marker_spread": 6.0,
		"marker_color": Color(1.0, 0.96, 0.78, 1.0),
		"sfx": SFX_HIT_PISTOL,
		"vol_db": 0.8,
		"pitch_min": 0.96,
		"pitch_max": 1.07,
	},
	"shotgun": {
		"hitstop_ms": 34.0,
		"kill_hitstop_ms": 54.0,
		"hitstop_min_scale": 0.88,
		"trauma": 0.54,
		"z_kick": 0.145,
		"pitch_kick": 4.2,
		"roll_kick": 3.6,
		"fov_punch": -4.2,
		"marker_spread": 11.5,
		"marker_color": Color(1.0, 0.62, 0.18, 1.0),
		"sfx": SFX_HIT_SHOTGUN,
		"vol_db": 2.4,
		"pitch_min": 0.92,
		"pitch_max": 1.03,
	},
	"slide_ram": {
		"hitstop_ms": 38.0,
		"kill_hitstop_ms": 56.0,
		"hitstop_min_scale": 0.0,
		"trauma": 0.56,
		"z_kick": 0.125,
		"pitch_kick": 3.2,
		"roll_kick": 4.8,
		"fov_punch": -3.4,
		"marker_spread": 10.5,
		"marker_color": Color(1.0, 0.48, 0.18, 1.0),
		"sfx": SFX_HIT_SLIDE,
		"vol_db": 2.0,
		"pitch_min": 0.92,
		"pitch_max": 1.04,
	},
}

@export_group("Health")
@export var max_hp: int = 3
@export var damage_invuln_time: float = 0.75

@export_group("Movement")
@export var walk_speed: float = 5.5
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 5.2
@export var mouse_sensitivity: float = 0.0025

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var sprint_stamina_drain: float = 28.0
@export var slide_stamina_cost: float = 16.0
@export var stamina_regen_rate: float = 22.0
@export var stamina_regen_delay: float = 0.6
@export var low_stamina_threshold: float = 25.0
@export var exhausted_recover_threshold: float = 22.0

@export_group("Slide")
@export var max_slide_duration: float = 1.5
@export var slide_start_speed: float = 11.2
@export var slide_end_speed: float = 3.5
@export var slide_cooldown: float = 0.85
@export var slide_ram_damage: float = 28.0
@export var slide_ram_knockback: float = 18.0
@export var slide_ram_upward: float = 4.8
@export var slide_ram_radius: float = 1.55
@export var stand_head_height: float = 1.6
@export var slide_head_height: float = 0.85
@export var stand_capsule_height: float = 1.8
@export var slide_capsule_height: float = 1.0
@export var height_lerp_speed: float = 12.0

@export_group("Camera Feel")
@export var base_fov: float = 75.0
@export var sprint_fov: float = 83.0
@export var slide_fov: float = 87.0
@export var fov_lerp_speed: float = 8.0
@export var walk_bob_freq: float = 9.5
@export var walk_bob_amp_y: float = 0.042
@export var walk_bob_amp_x: float = 0.024
@export var sprint_bob_freq: float = 13.5
@export var sprint_bob_amp_y: float = 0.078
@export var sprint_bob_amp_x: float = 0.048
@export var slide_roll_deg: float = -4.0

@export_group("Combat")
@export var punch_cooldown: float = 0.28
@export var punch_damage: float = 15.0
@export var camera_kick_deg: float = 1.8

@export_group("Parry")
@export var parry_fps: float = 22.0
@export var parry_range: float = 5.2
@export var parry_cooldown: float = 0.0
@export var parry_success_cooldown: float = 0.0
@export var parry_freeze_invert_ms: float = 45.0
@export var parry_freeze_ink_ms: float = 55.0

@export_group("Dash (Stage 3)")
@export var dash_speed: float = 26.5
@export var dash_duration: float = 0.17
@export var dash_cooldown: float = 0.85
@export var dash_invuln_time: float = 0.24

@onready var body_collision: CollisionShape3D = $CollisionShape3D as CollisionShape3D
@onready var ceiling_check: RayCast3D = $CeilingCheck as RayCast3D
@onready var head: Node3D = $Head as Node3D
@onready var fps_camera: Camera3D = $Head/Camera3D as Camera3D
@onready var punch_ray: RayCast3D = $Head/Camera3D/PunchRay as RayCast3D
@onready var grapple_controller: GrappleController = $GrappleController as GrappleController
@onready var right_weapon_controller: RightWeaponController = $RightWeaponController as RightWeaponController

@onready var left_arm_anchor: Control = $HandsLayer/HUDRoot/LeftArmAnchor as Control
@onready var grapple_arm_anchor: Control = $HandsLayer/HUDRoot/GrappleArmAnchor as Control
@onready var grapple_arm: TextureRect = $HandsLayer/HUDRoot/GrappleArmAnchor/GrappleArm as TextureRect
@onready var right_arm_anchor: Control = $HandsLayer/HUDRoot/RightArmAnchor as Control
@onready var pistol_arm_anchor: Control = $HandsLayer/HUDRoot/PistolArmAnchor as Control
@onready var pistol_arm: TextureRect = $HandsLayer/HUDRoot/PistolArmAnchor/PistolArm as TextureRect
@onready var shotgun_arm_anchor: Control = $HandsLayer/HUDRoot/ShotgunArmAnchor as Control
@onready var shotgun_arm: TextureRect = $HandsLayer/HUDRoot/ShotgunArmAnchor/ShotgunArm as TextureRect
@onready var weapon_slots_hud: Control = $HandsLayer/HUDRoot/WeaponSlotsHUD as Control
@onready var hud_pistol_slot: TextureRect = $HandsLayer/HUDRoot/WeaponSlotsHUD/PistolSlot as TextureRect
@onready var hud_pistol_ammo: Label = $HandsLayer/HUDRoot/WeaponSlotsHUD/PistolAmmo as Label
@onready var hud_shotgun_slot: TextureRect = $HandsLayer/HUDRoot/WeaponSlotsHUD/ShotgunSlot as TextureRect
@onready var hud_shotgun_ammo: Label = $HandsLayer/HUDRoot/WeaponSlotsHUD/ShotgunAmmo as Label
@onready var slide_arm_anchor: Control = $HandsLayer/HUDRoot/SlideArmAnchor as Control
@onready var slide_arm: TextureRect = $HandsLayer/HUDRoot/SlideArmAnchor/SlideArm as TextureRect
@onready var parry_arm: TextureRect = $HandsLayer/HUDRoot/ParryArm as TextureRect
@onready var left_arm: FPSArm = $HandsLayer/HUDRoot/LeftArmAnchor/LeftArm as FPSArm
@onready var right_arm: FPSArm = $HandsLayer/HUDRoot/RightArmAnchor/RightArm as FPSArm
@onready var crosshair: ColorRect = $HandsLayer/HUDRoot/Crosshair as ColorRect
@onready var stamina_bar: TextureProgressBar = $HandsLayer/HUDRoot/StaminaBar as TextureProgressBar
@onready var health_skulls: TextureRect = $HandsLayer/HUDRoot/HealthSkulls as TextureRect
@onready var damage_flash: ColorRect = $HandsLayer/HUDRoot/DamageFlash as ColorRect
@onready var buff_vignette: ColorRect = $HandsLayer/HUDRoot/BuffVignette as ColorRect
@onready var shield_hud: Control = $HandsLayer/HUDRoot/ShieldHUD as Control
@onready var shield_icon: TextureRect = $HandsLayer/HUDRoot/ShieldHUD/ShieldIcon as TextureRect
@onready var shield_bar_fill: ColorRect = $HandsLayer/HUDRoot/ShieldHUD/ShieldBarFill as ColorRect
@onready var death_label: Label = $HandsLayer/HUDRoot/DeathLabel as Label
@onready var debug_label: Label = $HandsLayer/HUDRoot/DebugLabel as Label
@onready var impact_frame_rect: ColorRect = $ImpactLayer/ImpactFrameRect as ColorRect

@onready var walk_step_player: AudioStreamPlayer = $Audio/WalkStepPlayer as AudioStreamPlayer
@onready var run_step_player: AudioStreamPlayer = $Audio/RunStepPlayer as AudioStreamPlayer
@onready var slide_player: AudioStreamPlayer = $Audio/SlidePlayer as AudioStreamPlayer
@onready var punch_whoosh_player: AudioStreamPlayer = $Audio/PunchWhooshPlayer as AudioStreamPlayer
@onready var punch_hit_player: AudioStreamPlayer = $Audio/PunchHitPlayer as AudioStreamPlayer
@onready var hurt_player: AudioStreamPlayer = $Audio/PlayerHurtPlayer as AudioStreamPlayer
@onready var death_player: AudioStreamPlayer = $Audio/PlayerDeathPlayer as AudioStreamPlayer
@onready var shield_block_player: AudioStreamPlayer = $Audio/ShieldBlockPlayer as AudioStreamPlayer
@onready var parry_swing_player: AudioStreamPlayer = $Audio/ParrySwingPlayer as AudioStreamPlayer
@onready var parry_clang_player: AudioStreamPlayer = $Audio/ParryClangPlayer as AudioStreamPlayer
@onready var parry_chime_player: AudioStreamPlayer = $Audio/ParryChimePlayer as AudioStreamPlayer
@onready var parry_energy_player: AudioStreamPlayer = $Audio/ParryEnergyPlayer as AudioStreamPlayer

var _gravity: float = 9.8
var _hp: int = 3
var _invuln_timer: float = 0.0
var _is_dead: bool = false
var _damage_flash_alpha: float = 0.0
var _debug_toast: String = ""
var _debug_toast_timer: float = 0.0

var _next_hand_is_left: bool = true
var _punch_cooldown_timer: float = 0.0
var _camera_roll_kick: float = 0.0
var _camera_pitch_kick: float = 0.0
var _camera_z_kick: float = 0.0
var _crosshair_flash_timer: float = 0.0
var _hit_trauma: float = 0.0
var _hit_trauma_time: float = 0.0
var _hit_fov_offset: float = 0.0
var _weapon_hitstop_token: int = 0
var _pixel_reticle: PixelReticle
var _weapon_hit_player: AudioStreamPlayer
var _kill_confirm_player: AudioStreamPlayer
var _hit_sfx_cache: Dictionary = {}

var _is_parrying: bool = false
var _parry_pulling_in: bool = false
var _parry_active_window: bool = false
var _parry_succeeded_this_swing: bool = false
var _parry_cooldown_timer: float = 0.0
var _is_in_hitstop: bool = false
var _parry_tween: Tween
var _left_retract_tween: Tween
var _impact_fade_tween: Tween
var _parry_frames: Array[Texture2D] = []

var _stamina: float = 100.0
var _stamina_regen_timer: float = 0.0
var _is_exhausted: bool = false
var _is_sprinting: bool = false

var _is_sliding: bool = false
var _slide_timer: float = 0.0
var _slide_cooldown_timer: float = 0.0
var _slide_dir: Vector3 = Vector3.ZERO
var _current_slide_roll: float = 0.0
var _slide_arm_tween: Tween

var _head_bob_time: float = 0.0
var _prev_bob_sin: float = 0.0

var _capsule_shape: CapsuleShape3D
var _stamina_under_tex: Texture2D
var _stamina_under_red_tex: Texture2D
var _stamina_fill_orange_tex: Texture2D
var _stamina_fill_red_tex: Texture2D
var _skull_textures: Array[Texture2D] = []
var _shield_active_tex: Texture2D
var _shield_flash_tex: Texture2D

var _heal_fx_intensity: float = 0.0
var _speed_boost_timer: float = 0.0
var _speed_boost_mult: float = 1.5
var _speed_fx_intensity: float = 0.0
var _shield_timer: float = 0.0
var _shield_max_duration: float = 5.0
var _shield_fx_intensity: float = 0.0
var _shield_flash_pulse: float = 0.0

var _grapple_equipped: bool = false
var _is_swapping_left_arm: bool = false
var _left_swap_tween: Tween
var _grapple_hand_ready_tex: Texture2D
var _grapple_hand_fired_tex: Texture2D
var _grapple_arm_bob_time: float = 0.0
var _grapple_recoil: Vector2 = Vector2.ZERO
var _slide_hit_enemies: Dictionary = {}

var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _dash_sfx_player: AudioStreamPlayer
var _death_screen: DeathScreen


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_hp = max_hp
	_stamina = max_stamina
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if body_collision != null and body_collision.shape is CapsuleShape3D:
		_capsule_shape = body_collision.shape.duplicate() as CapsuleShape3D
		body_collision.shape = _capsule_shape

	if fps_camera != null:
		fps_camera.current = true
		fps_camera.fov = base_fov
		fps_camera.far = 175.0

	if grapple_controller != null:
		grapple_controller.setup(self, fps_camera)
		grapple_controller.grapple_latched.connect(_on_grapple_latched)

	if right_weapon_controller != null:
		right_weapon_controller.setup(
			self,
			fps_camera,
			right_arm_anchor,
			right_arm,
			pistol_arm_anchor,
			pistol_arm,
			shotgun_arm_anchor,
			shotgun_arm,
			weapon_slots_hud,
			hud_pistol_slot,
			hud_pistol_ammo,
			hud_shotgun_slot,
			hud_shotgun_ammo
		)
		right_weapon_controller.weapon_changed.connect(_on_right_weapon_changed)
		right_weapon_controller.fired_recoil.connect(_on_weapon_fired_recoil)
		right_weapon_controller.weapon_toast.connect(_show_debug_toast)

	if left_arm != null:
		left_arm.punch_impact.connect(_on_arm_punch_impact)
	if right_arm != null:
		right_arm.punch_impact.connect(_on_arm_punch_impact)

	if death_label != null:
		death_label.visible = false
	if damage_flash != null:
		damage_flash.color = Color(0.85, 0.05, 0.05, 0.0)
	if parry_arm != null:
		parry_arm.visible = false
	if impact_frame_rect != null:
		impact_frame_rect.visible = false
		_set_impact_shader_param("intensity", 0.0)

	_load_hud_textures()
	_setup_death_screen_and_dash()
	_setup_weapon_hit_feel()
	_route_player_audio_bus()
	_connect_game_settings()
	_apply_stage_ability_defaults()
	_update_health_ui()
	_update_stamina_ui()
	_update_arm_visibility()


func _setup_death_screen_and_dash() -> void:
	_death_screen = get_node_or_null("DeathScreen") as DeathScreen
	if _death_screen == null:
		_death_screen = DeathScreen.new()
		_death_screen.name = "DeathScreen"
		add_child(_death_screen)

	_dash_sfx_player = AudioStreamPlayer.new()
	_dash_sfx_player.name = "DashSfxPlayer"
	_dash_sfx_player.volume_db = -2.0
	_dash_sfx_player.bus = &"PlayerSFX"
	if ResourceLoader.exists("res://assets/audio/grapple/grapple_pull_whoosh.wav"):
		_dash_sfx_player.stream = load("res://assets/audio/grapple/grapple_pull_whoosh.wav") as AudioStream
	add_child(_dash_sfx_player)


func _setup_weapon_hit_feel() -> void:
	_weapon_hit_player = AudioStreamPlayer.new()
	_weapon_hit_player.name = "WeaponHitImpactPlayer"
	_weapon_hit_player.bus = &"PlayerSFX"
	add_child(_weapon_hit_player)

	_kill_confirm_player = AudioStreamPlayer.new()
	_kill_confirm_player.name = "KillConfirmPlayer"
	_kill_confirm_player.bus = &"PlayerSFX"
	_kill_confirm_player.volume_db = 0.5
	if ResourceLoader.exists(SFX_KILL_CONFIRM):
		_kill_confirm_player.stream = load(SFX_KILL_CONFIRM) as AudioStream
	add_child(_kill_confirm_player)

	for prof_key: Variant in HIT_FEEL_PROFILES.keys():
		var prof: Dictionary = HIT_FEEL_PROFILES[prof_key] as Dictionary
		var sfx_path: String = str(prof.get("sfx", ""))
		if not sfx_path.is_empty() and not _hit_sfx_cache.has(sfx_path) and ResourceLoader.exists(sfx_path):
			_hit_sfx_cache[sfx_path] = load(sfx_path) as AudioStream

	var hud_root: Control = get_node_or_null("HandsLayer/HUDRoot") as Control
	if hud_root != null:
		_pixel_reticle = PixelReticle.new()
		_pixel_reticle.name = "PixelReticle"
		hud_root.add_child(_pixel_reticle)
		if crosshair != null:
			crosshair.visible = false


func trigger_weapon_hit_feel(weapon_id: String, killed: bool = false, blocked: bool = false, intensity_scale: float = 1.0) -> void:
	var profile: Dictionary = HIT_FEEL_PROFILES.get(weapon_id, HIT_FEEL_PROFILES["fist_right"]) as Dictionary
	var scale_f: float = clampf(intensity_scale, 0.5, 1.6)

	# 1) Directional spring camera recoil + damped trauma + FOV punch
	var pitch_k: float = float(profile.get("pitch_kick", 2.0)) * scale_f
	var roll_k: float = float(profile.get("roll_kick", 2.5)) * scale_f
	var z_k: float = float(profile.get("z_kick", 0.06)) * scale_f
	if weapon_id == "pistol" or weapon_id == "shotgun" or weapon_id == "slide_ram":
		roll_k *= -1.0 if randf() < 0.5 else 1.0
	if blocked:
		pitch_k *= 0.50
		roll_k *= 0.55
		z_k *= 0.45
	elif killed:
		pitch_k *= 1.25
		roll_k *= 1.20
		z_k *= 1.30

	_camera_pitch_kick = clampf(_camera_pitch_kick + pitch_k, 0.0, 11.0)
	_camera_roll_kick = clampf(_camera_roll_kick + roll_k, -12.0, 12.0)
	_camera_z_kick = clampf(_camera_z_kick + z_k, 0.0, 0.22)

	var trauma_add: float = float(profile.get("trauma", 0.24)) * scale_f * (0.45 if blocked else (1.30 if killed else 1.0))
	_hit_trauma = clampf(maxf(_hit_trauma, trauma_add), 0.0, 1.0)

	var fov_p: float = float(profile.get("fov_punch", -2.0)) * scale_f * (0.45 if blocked else (1.28 if killed else 1.0))
	_hit_fov_offset = clampf(_hit_fov_offset + fov_p, -6.5, 4.5)

	# 2) Mastered 48kHz real foley impact audio + organic bone/gore kill finisher
	if _weapon_hit_player != null and not blocked:
		var sfx_path: String = str(profile.get("sfx", ""))
		var stream: AudioStream = _hit_sfx_cache.get(sfx_path, null) as AudioStream
		if stream != null:
			_weapon_hit_player.stream = stream
			_weapon_hit_player.volume_db = float(profile.get("vol_db", 0.0)) + (1.0 if killed else 0.0)
			_weapon_hit_player.pitch_scale = randf_range(float(profile.get("pitch_min", 0.94)), float(profile.get("pitch_max", 1.06)))
			_weapon_hit_player.play()

	if killed and _kill_confirm_player != null and _kill_confirm_player.stream != null:
		_kill_confirm_player.pitch_scale = randf_range(0.92, 1.04)
		_kill_confirm_player.play()

	# 3) Crisp 1px-outlined PixelReticle feedback
	var marker_col: Color = profile.get("marker_color", Color.WHITE) as Color
	if blocked:
		marker_col = Color(0.55, 0.88, 1.0, 1.0)
	elif killed:
		marker_col = Color(1.0, 0.16, 0.16, 1.0)

	if _pixel_reticle != null:
		_pixel_reticle.trigger_hit(float(profile.get("marker_spread", 8.0)) * clampf(scale_f, 0.85, 1.3), marker_col, killed, blocked)
	_crosshair_flash_timer = 0.16 if killed else 0.10

	# 4) Surgical non-stuttering hitstop (0ms on pistol body shots & grazing pellets!)
	if not blocked and not _is_in_hitstop and not get_tree().paused:
		var min_scale: float = float(profile.get("hitstop_min_scale", 0.0))
		var stop_ms: float = 0.0
		if killed:
			stop_ms = float(profile.get("kill_hitstop_ms", 24.0))
		elif scale_f >= min_scale:
			stop_ms = float(profile.get("hitstop_ms", 0.0))
		if stop_ms >= 8.0:
			_run_weapon_hitstop(stop_ms / 1000.0)


func _run_weapon_hitstop(duration_sec: float) -> void:
	if duration_sec <= 0.006:
		return
	_weapon_hitstop_token += 1
	var my_token: int = _weapon_hitstop_token
	Engine.time_scale = 0.03
	await get_tree().create_timer(duration_sec, true, false, true).timeout
	if not is_inside_tree():
		return
	if my_token == _weapon_hitstop_token and not _is_in_hitstop and not get_tree().paused:
		Engine.time_scale = 1.0


func _apply_stage_ability_defaults() -> void:
	# Grapple Hook is unlocked ONLY in Stage 2 & Stage 3 (auto-equipped on entry!), locked in Stage 1
	var cur_scene: Node = get_tree().current_scene
	if cur_scene != null:
		var sp: String = cur_scene.scene_file_path
		if sp.ends_with("stage_2_military.tscn") or sp.ends_with("stage_3_city.tscn"):
			_grapple_equipped = true
		elif sp.ends_with("stage_1_hospital.tscn"):
			_grapple_equipped = false


func _is_grapple_unlocked() -> bool:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm != null and sm.has_method("is_grapple_unlocked"):
		return bool(sm.call("is_grapple_unlocked"))
	return true


func _is_dash_unlocked() -> bool:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm != null and sm.has_method("is_dash_unlocked"):
		return bool(sm.call("is_dash_unlocked"))
	return true


func _route_player_audio_bus() -> void:
	var audio_root: Node = get_node_or_null("Audio")
	if audio_root == null:
		return
	for child: Node in audio_root.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).bus = &"PlayerSFX"


func _connect_game_settings() -> void:
	var gs: Node = get_node_or_null("/root/GameSettings")
	if gs == null:
		return
	if gs.has_signal("settings_changed") and not gs.is_connected("settings_changed", _apply_game_settings):
		gs.connect("settings_changed", _apply_game_settings)
	_apply_game_settings()


func _apply_game_settings() -> void:
	var gs: Node = get_node_or_null("/root/GameSettings")
	if gs == null:
		return
	if gs.has_method("get_mouse_sensitivity"):
		mouse_sensitivity = float(gs.call("get_mouse_sensitivity"))
	var fov_val: Variant = gs.get("fov")
	if fov_val != null:
		base_fov = float(fov_val)
		sprint_fov = base_fov + 8.0
		slide_fov = base_fov + 12.0
		if fps_camera != null and not _is_sprinting and not _is_sliding:
			fps_camera.fov = base_fov


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _load_hud_textures() -> void:
	if ResourceLoader.exists(STAMINA_UNDER_PATH):
		_stamina_under_tex = load(STAMINA_UNDER_PATH) as Texture2D
	if ResourceLoader.exists(STAMINA_UNDER_RED_PATH):
		_stamina_under_red_tex = load(STAMINA_UNDER_RED_PATH) as Texture2D
	if ResourceLoader.exists(STAMINA_FILL_ORANGE_PATH):
		_stamina_fill_orange_tex = load(STAMINA_FILL_ORANGE_PATH) as Texture2D
	if ResourceLoader.exists(STAMINA_FILL_RED_PATH):
		_stamina_fill_red_tex = load(STAMINA_FILL_RED_PATH) as Texture2D

	_skull_textures.clear()
	for p: String in SKULLS_PATHS:
		if ResourceLoader.exists(p):
			_skull_textures.append(load(p) as Texture2D)
		else:
			_skull_textures.append(null)

	_parry_frames.clear()
	for i: int in range(PARRY_FRAME_COUNT):
		var frame_path: String = "%s/frame_%02d.png" % [PARRY_FRAMES_DIR, i]
		if ResourceLoader.exists(frame_path):
			var tex: Texture2D = load(frame_path) as Texture2D
			if tex != null:
				_parry_frames.append(tex)

	if ResourceLoader.exists(SHIELD_ACTIVE_PATH):
		_shield_active_tex = load(SHIELD_ACTIVE_PATH) as Texture2D
	if ResourceLoader.exists(SHIELD_FLASH_PATH):
		_shield_flash_tex = load(SHIELD_FLASH_PATH) as Texture2D
	if ResourceLoader.exists(GRAPPLE_HAND_READY_PATH):
		_grapple_hand_ready_tex = load(GRAPPLE_HAND_READY_PATH) as Texture2D
	if ResourceLoader.exists(GRAPPLE_HAND_FIRED_PATH):
		_grapple_hand_fired_tex = load(GRAPPLE_HAND_FIRED_PATH) as Texture2D


func apply_medkit(amount: int = 1) -> bool:
	if _is_dead or _hp >= max_hp:
		return false
	_hp = mini(max_hp, _hp + amount)
	_heal_fx_intensity = 1.0
	_update_health_ui()
	health_changed.emit(_hp, max_hp)
	_show_debug_toast("+1 HP (MEDKIT)")
	return true


func apply_speed_boost(duration: float = 6.0, mult: float = 1.5) -> void:
	_speed_boost_timer = maxf(_speed_boost_timer, duration)
	_speed_boost_mult = mult
	_show_debug_toast("SPEED BOOST (1.5x)")


func apply_shield_boost(duration: float = 5.0) -> void:
	_shield_max_duration = maxf(duration, 0.1)
	_shield_timer = maxf(_shield_timer, duration)
	_shield_flash_pulse = 1.0
	_show_debug_toast("SHIELD ACTIVE (5s)")


func pickup_weapon(weapon_name: String) -> bool:
	if right_weapon_controller == null:
		return false
	return right_weapon_controller.pickup_weapon(weapon_name)


func _on_right_weapon_changed(weapon_id: int) -> void:
	_update_arm_visibility()
	if _pixel_reticle != null:
		_pixel_reticle.set_weapon_mode(weapon_id)


func _on_weapon_fired_recoil(pitch_kick_deg: float, roll_kick_deg: float) -> void:
	_camera_pitch_kick = clampf(_camera_pitch_kick + pitch_kick_deg, 0.0, 9.5)
	_camera_roll_kick = roll_kick_deg
	_camera_z_kick = clampf(_camera_z_kick + (0.09 if pitch_kick_deg > 4.0 else 0.035), 0.0, 0.22)
	if _pixel_reticle != null:
		_pixel_reticle.add_fire_bloom(8.5 if pitch_kick_deg > 4.0 else 4.0)


func take_damage(amount: int = 1, _source_pos: Vector3 = Vector3.ZERO) -> void:
	if _is_dead or _invuln_timer > 0.0 or amount <= 0:
		return

	if _shield_timer > 0.0:
		_invuln_timer = 0.25
		_shield_flash_pulse = 1.0
		if shield_block_player != null:
			shield_block_player.pitch_scale = randf_range(0.95, 1.08)
			shield_block_player.play()
		return

	_hp = maxi(0, _hp - amount)
	_invuln_timer = damage_invuln_time
	_damage_flash_alpha = 0.45
	_camera_roll_kick = randf_range(-5.5, 5.5)

	_update_health_ui()
	health_changed.emit(_hp, max_hp)

	if _hp <= 0:
		_die()
	else:
		if hurt_player != null:
			hurt_player.pitch_scale = randf_range(0.92, 1.08)
			hurt_player.play()


func _die() -> void:
	_is_dead = true
	_stop_slide()
	if grapple_controller != null:
		grapple_controller.cancel_immediately()
	if run_step_player != null and run_step_player.playing:
		run_step_player.stop()
	if death_player != null:
		death_player.play()
	_damage_flash_alpha = 0.6
	if death_label != null:
		death_label.visible = false
	if _death_screen != null:
		_death_screen.show_death_screen()
	player_died.emit()


func _update_health_ui() -> void:
	if health_skulls == null or _skull_textures.is_empty():
		return
	var idx: int = clampi(_hp, 0, _skull_textures.size() - 1)
	if _skull_textures[idx] != null:
		health_skulls.texture = _skull_textures[idx]


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return

	if event is InputEventMouseButton:
		var mouse_btn: InputEventMouseButton = event as InputEventMouseButton
		if mouse_btn.pressed:
			if mouse_btn.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _is_parrying and right_weapon_controller != null:
				if mouse_btn.button_index == MOUSE_BUTTON_WHEEL_UP:
					right_weapon_controller.cycle_scroll(1)
					return
				if mouse_btn.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					right_weapon_controller.cycle_scroll(-1)
					return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		if head != null:
			head.rotate_x(-motion.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _physics_process(delta: float) -> void:
	if _debug_toast_timer > 0.0:
		_debug_toast_timer = maxf(0.0, _debug_toast_timer - delta)
		if _debug_toast_timer <= 0.0:
			_debug_toast = ""
			_update_debug_ui()

	if _invuln_timer > 0.0:
		_invuln_timer = maxf(0.0, _invuln_timer - delta)

	if _parry_cooldown_timer > 0.0:
		_parry_cooldown_timer = maxf(0.0, _parry_cooldown_timer - delta)

	if damage_flash != null:
		var target_alpha: float = 0.45 if _is_dead else 0.0
		_damage_flash_alpha = lerpf(_damage_flash_alpha, target_alpha, minf(1.0, delta * 5.0))
		damage_flash.color = Color(0.85, 0.05, 0.05, _damage_flash_alpha)

	if _is_dead:
		if head != null:
			head.position.y = lerpf(head.position.y, 0.45, minf(1.0, delta * 5.0))
		if fps_camera != null:
			fps_camera.rotation_degrees.z = lerpf(fps_camera.rotation_degrees.z, 18.0, minf(1.0, delta * 5.0))
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _slide_cooldown_timer > 0.0:
		_slide_cooldown_timer = maxf(0.0, _slide_cooldown_timer - delta)
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	# Stage 3 Dash trigger (Q key)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("dash"):
		_try_start_dash(move_dir)

	# Toggle Grapple Hook on left arm (E key) — Stage 2 & 3 only!
	if Input.is_action_just_pressed("toggle_grapple"):
		if _is_grapple_unlocked():
			_toggle_grapple_equip()
		else:
			_show_debug_toast("GRAPPLE HOOK UNLOCKS IN STAGE 02")

	# Fire Grapple Hook (hold R while equipped)
	if _is_grapple_unlocked() and _grapple_equipped and grapple_controller != null and not _is_swapping_left_arm and not _is_parrying:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("grapple_fire"):
			if _is_sliding:
				_stop_slide()
			if grapple_controller.fire():
				_grapple_recoil = Vector2(-26.0, 22.0)

	# Step active grapple physics (Spider-Man pull/swing or enemy yank)
	var holding_grapple: bool = _is_grapple_unlocked() and _grapple_equipped and Input.is_action_pressed("grapple_fire") and not _is_parrying
	if grapple_controller != null:
		grapple_controller.step_grapple(delta, input_dir, holding_grapple)

	var grappling_self: bool = grapple_controller != null and grapple_controller.is_pulling_self()

	# Slide trigger (C key)
	if Input.is_action_just_pressed("slide") and is_on_floor() and not _is_sliding and not _is_dashing and not grappling_self:
		_try_start_slide(move_dir)

	# Jump (cancels slide into slide-jump, or cancels grapple into Spider-Man web-zip vault jump!)
	if Input.is_action_just_pressed("jump"):
		if grappling_self and grapple_controller != null:
			grapple_controller.release(true)
			grappling_self = false
		elif is_on_floor():
			if _is_sliding:
				_stop_slide()
			velocity.y = jump_velocity

	# Horizontal movement: Dash vs Grapple Swing vs Slide vs Ground/Air Momentum
	if _is_dashing:
		_is_sprinting = false
		_process_dash(delta)
	elif grappling_self:
		_is_sprinting = false
	elif _is_sliding:
		_is_sprinting = false
		_process_slide(delta, move_dir)
	else:
		_process_ground_movement(delta, input_dir, move_dir)

	move_and_slide()

	_update_stamina(delta)
	_update_buffs(delta)
	_update_body_height(delta)
	_update_camera_effects(delta)
	_update_footstep_audio(delta)

	# Parry trigger (Right Click / F)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("parry"):
		_try_start_parry()

	# Active projectile parry scan during parry frames
	if _is_parrying and _parry_active_window:
		_check_parry_projectiles()

	# Attack: shoot equipped Right Weapon (Pistol / Shotgun), or punch with fists!
	if _punch_cooldown_timer > 0.0:
		_punch_cooldown_timer = maxf(0.0, _punch_cooldown_timer - delta)

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("attack"):
		if not _is_parrying and right_weapon_controller != null and right_weapon_controller.is_using_gun():
			right_weapon_controller.try_fire()
		else:
			_try_punch()

	# Update arm visibility and arm bobbing
	# During parry: right arm / right weapon stays completely still on screen!
	_update_arm_visibility()
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	var ref_speed: float = sprint_speed if _is_sprinting else walk_speed
	var move_ratio: float = 0.0 if (_is_sliding or grappling_self) else clampf(horiz_speed / maxf(ref_speed, 0.01), 0.0, 1.0)
	if _is_sprinting:
		move_ratio = minf(1.35, move_ratio * 1.25)

	if right_weapon_controller != null:
		right_weapon_controller.step_visuals(delta, move_ratio, is_on_floor() and not _is_sliding, _is_parrying)

	if not _is_parrying:
		if left_arm != null and not _grapple_equipped and not _is_swapping_left_arm:
			left_arm.update_bob(delta, move_ratio, is_on_floor() and not _is_sliding)
		var using_gun: bool = right_weapon_controller != null and (right_weapon_controller.is_using_gun() or right_weapon_controller.is_busy())
		if right_arm != null and not using_gun:
			right_arm.update_bob(delta, move_ratio, is_on_floor() and not _is_sliding)
		if _grapple_equipped and not _is_swapping_left_arm:
			_update_grapple_arm_visual(delta, move_ratio)

	# PixelReticle aim color indicator (grapple lock / neutral)
	if _crosshair_flash_timer > 0.0:
		_crosshair_flash_timer -= delta
	elif _pixel_reticle != null:
		if _grapple_equipped and grapple_controller != null:
			var aim_kind: int = grapple_controller.get_aim_target_kind()
			if aim_kind == 2:
				_pixel_reticle.set_center_color(Color(1.0, 0.52, 0.14, 1.0)) # Enemy in grapple range
			elif aim_kind == 1:
				_pixel_reticle.set_center_color(Color(0.22, 0.92, 1.0, 1.0)) # Surface in grapple range
			else:
				_pixel_reticle.set_center_color(Color(1.0, 1.0, 1.0, 0.78))
		else:
			_pixel_reticle.set_center_color(Color(1.0, 1.0, 1.0, 0.92))


func _try_start_parry() -> void:
	if _is_parrying or _parry_cooldown_timer > 0.0 or _parry_frames.is_empty():
		return

	_is_parrying = true
	_parry_pulling_in = true
	_parry_active_window = true
	_parry_succeeded_this_swing = false

	if parry_swing_player != null:
		parry_swing_player.pitch_scale = randf_range(0.96, 1.06)
		parry_swing_player.play()

	# Immediate point-blank check on button press
	_check_parry_projectiles()

	if _parry_tween != null and _parry_tween.is_valid():
		_parry_tween.kill()
	if _left_retract_tween != null and _left_retract_tween.is_valid():
		_left_retract_tween.kill()

	_update_arm_visibility()

	# 1. Briefly pull the active left arm inward/downward, then play full-screen parry animation
	var active_left: Control = grapple_arm if _grapple_equipped else left_arm
	_parry_tween = create_tween()
	if active_left != null:
		_parry_tween.tween_property(active_left, "position", Vector2(-45.0, 110.0), 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		_parry_tween.tween_interval(0.045)

	_parry_tween.tween_callback(_begin_parry_frames)

	var frame_dt: float = 1.0 / maxf(parry_fps, 1.0)
	for i: int in range(_parry_frames.size()):
		_parry_tween.tween_callback(_set_parry_frame.bind(i))
		_parry_tween.tween_interval(frame_dt)

	_parry_tween.tween_callback(_finish_parry)


func _begin_parry_frames() -> void:
	_parry_pulling_in = false
	_update_arm_visibility()


func _set_parry_frame(idx: int) -> void:
	if parry_arm != null and idx >= 0 and idx < _parry_frames.size():
		parry_arm.texture = _parry_frames[idx]
	# Generous active deflect window centered on active frames [5, 6, 7]
	_parry_active_window = (idx >= 0 and idx <= 8)


func _finish_parry() -> void:
	_is_parrying = false
	_parry_pulling_in = false
	_parry_active_window = false
	_parry_cooldown_timer = parry_success_cooldown if _parry_succeeded_this_swing else parry_cooldown

	if parry_arm != null:
		parry_arm.visible = false

	_update_arm_visibility()

	# Smoothly bring the active left arm back up from retracted position
	var active_left_back: Control = grapple_arm if _grapple_equipped else left_arm
	if active_left_back != null:
		if _left_retract_tween != null and _left_retract_tween.is_valid():
			_left_retract_tween.kill()
		active_left_back.position = Vector2(-30.0, 85.0)
		_left_retract_tween = create_tween()
		_left_retract_tween.tween_property(active_left_back, "position", Vector2.ZERO, 0.085).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func can_parry_projectile() -> bool:
	return _is_parrying and _parry_active_window and not _is_dead


func parry_projectile(proj: Projectile3D) -> bool:
	if proj == null or proj.is_parried or not can_parry_projectile() or fps_camera == null:
		return false

	var cam_pos: Vector3 = fps_camera.global_position
	var cam_fwd: Vector3 = -fps_camera.global_transform.basis.z
	if not proj.deflect(cam_pos, cam_fwd, self):
		return false

	_invuln_timer = maxf(_invuln_timer, 0.35)
	if not _parry_succeeded_this_swing:
		_parry_succeeded_this_swing = true
		parry_succeeded.emit(proj)
		_trigger_parry_impact_fx()
	return true


func _check_parry_projectiles() -> void:
	if fps_camera == null:
		return

	var cam_pos: Vector3 = fps_camera.global_position
	var cam_fwd: Vector3 = -fps_camera.global_transform.basis.z

	for node: Node in get_tree().get_nodes_in_group("projectiles"):
		if not (node is Projectile3D):
			continue
		var proj: Projectile3D = node as Projectile3D
		if proj.is_parried:
			continue

		var to_proj: Vector3 = proj.global_position - cam_pos
		var dist: float = to_proj.length()
		if dist > parry_range:
			continue

		var in_front: bool = dist <= 2.4 or (dist > 0.001 and cam_fwd.dot(to_proj / dist) >= 0.15)
		if not in_front:
			continue

		parry_projectile(proj)


func _trigger_parry_impact_fx() -> void:
	if _is_in_hitstop:
		return
	_is_in_hitstop = true

	if parry_clang_player != null:
		parry_clang_player.pitch_scale = randf_range(0.96, 1.06)
		parry_clang_player.play()
	if parry_chime_player != null:
		parry_chime_player.pitch_scale = randf_range(0.98, 1.04)
		parry_chime_player.play()

	if _impact_fade_tween != null and _impact_fade_tween.is_valid():
		_impact_fade_tween.kill()

	# Phase 1: Stark inverted B&W anime impact freeze
	if impact_frame_rect != null:
		impact_frame_rect.visible = true
		_set_impact_shader_param("intensity", 1.0)
		_set_impact_shader_param("invert_phase", 1.0)
		_set_impact_shader_param("seed", randf_range(1.0, 99.0))

	Engine.time_scale = 0.0
	await get_tree().create_timer(parry_freeze_invert_ms / 1000.0, true, false, true).timeout
	if not is_inside_tree():
		Engine.time_scale = 1.0
		return

	# Phase 2: Positive high-contrast B&W anime ink + manga speedlines
	if impact_frame_rect != null:
		_set_impact_shader_param("invert_phase", 0.0)
		_set_impact_shader_param("seed", randf_range(1.0, 99.0))

	await get_tree().create_timer(parry_freeze_ink_ms / 1000.0, true, false, true).timeout
	if not is_inside_tree():
		Engine.time_scale = 1.0
		return

	# Release hitstop and blast the deflected projectile back
	Engine.time_scale = 1.0
	_is_in_hitstop = false

	if parry_energy_player != null:
		parry_energy_player.pitch_scale = randf_range(0.96, 1.06)
		parry_energy_player.play()

	if fps_camera != null:
		fps_camera.fov = minf(fps_camera.fov + 7.5, 98.0)
	_camera_roll_kick = -4.0

	if impact_frame_rect != null:
		_impact_fade_tween = create_tween()
		_impact_fade_tween.tween_method(_set_impact_intensity, 1.0, 0.0, 0.075).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_impact_fade_tween.tween_callback(_hide_impact_frame)


func _set_impact_intensity(val: float) -> void:
	_set_impact_shader_param("intensity", val)


func _hide_impact_frame() -> void:
	if impact_frame_rect != null:
		impact_frame_rect.visible = false
		_set_impact_shader_param("intensity", 0.0)


func _set_impact_shader_param(param_name: String, val: Variant) -> void:
	if impact_frame_rect == null:
		return
	var mat: ShaderMaterial = impact_frame_rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(param_name, val)


func _try_start_slide(move_dir: Vector3) -> void:
	if _slide_cooldown_timer > 0.0 or _is_exhausted or _stamina < 10.0:
		return

	_is_sliding = true
	_is_sprinting = false
	_slide_timer = 0.0
	_slide_hit_enemies.clear()

	if move_dir != Vector3.ZERO:
		_slide_dir = move_dir
	else:
		_slide_dir = (-transform.basis.z).normalized()

	_stamina = maxf(0.0, _stamina - slide_stamina_cost)
	_stamina_regen_timer = stamina_regen_delay
	if _stamina <= 0.0:
		_is_exhausted = true
	_update_stamina_ui()

	if run_step_player != null and run_step_player.playing:
		run_step_player.stop()
	if slide_player != null:
		slide_player.pitch_scale = randf_range(0.96, 1.04)
		slide_player.play()

	if slide_arm != null:
		if _slide_arm_tween != null and _slide_arm_tween.is_valid():
			_slide_arm_tween.kill()
		slide_arm.position = Vector2(-60.0, 90.0)
		_slide_arm_tween = create_tween()
		_slide_arm_tween.tween_property(slide_arm, "position", Vector2.ZERO, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process_slide(delta: float, move_dir: Vector3) -> void:
	_slide_timer += delta

	if _slide_timer >= max_slide_duration or not Input.is_action_pressed("slide") or not is_on_floor():
		_stop_slide()
		return

	var progress: float = clampf(_slide_timer / maxf(max_slide_duration, 0.01), 0.0, 1.0)
	var spd_mult: float = _speed_boost_mult if _speed_boost_timer > 0.0 else 1.0
	var current_slide_speed: float = lerpf(slide_start_speed, slide_end_speed, progress * progress) * spd_mult

	if move_dir != Vector3.ZERO:
		_slide_dir = _slide_dir.lerp(move_dir, minf(1.0, delta * 2.5)).normalized()

	velocity.x = _slide_dir.x * current_slide_speed
	velocity.z = _slide_dir.z * current_slide_speed
	_check_slide_ram_enemies()


func _check_slide_ram_enemies() -> void:
	var ram_radius_sq: float = slide_ram_radius * slide_ram_radius
	var p_pos: Vector3 = global_position
	var ram_hits: int = 0
	var any_killed: bool = false

	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var enemy_id: int = node.get_instance_id()
		if _slide_hit_enemies.has(enemy_id):
			continue
		var dead_val: Variant = node.get("_is_dead")
		if dead_val != null and bool(dead_val):
			continue

		var e_pos: Vector3 = (node as Node3D).global_position
		if absf(e_pos.y - p_pos.y) > 1.7:
			continue
		var to_e: Vector3 = Vector3(e_pos.x - p_pos.x, 0.0, e_pos.z - p_pos.z)
		if to_e.length_squared() > ram_radius_sq:
			continue

		_slide_hit_enemies[enemy_id] = true
		ram_hits += 1
		var push_dir: Vector3 = _slide_dir
		if to_e.length_squared() > 0.001:
			push_dir = (_slide_dir * 0.7 + to_e.normalized() * 0.3).normalized()

		var hit_point: Vector3 = e_pos + Vector3(0.0, 0.9, 0.0)
		if node.has_method("on_slide_ram_hit"):
			var res: Variant = node.call("on_slide_ram_hit", slide_ram_damage, push_dir, slide_ram_knockback, slide_ram_upward, hit_point)
			if res is Dictionary and bool((res as Dictionary).get("killed", false)):
				any_killed = true
		elif node.has_method("on_punched"):
			var res_p: Variant = node.call("on_punched", slide_ram_damage, hit_point, "slide_ram")
			if res_p is Dictionary and bool((res_p as Dictionary).get("killed", false)):
				any_killed = true

	if ram_hits > 0:
		trigger_weapon_hit_feel("slide_ram", any_killed, false, clampf(0.92 + float(ram_hits) * 0.12, 1.0, 1.35))


func _try_start_dash(move_dir: Vector3) -> void:
	if not _is_dash_unlocked():
		_show_debug_toast("DASH [Q] UNLOCKS IN STAGE 03")
		return
	if _is_dashing or _dash_cooldown_timer > 0.0:
		return

	if _is_sliding:
		_stop_slide()
	if grapple_controller != null and grapple_controller.is_active():
		grapple_controller.release(false)

	var dir: Vector3 = move_dir
	if dir.length_squared() < 0.01:
		dir = -transform.basis.z
		dir.y = 0.0
	_dash_dir = dir.normalized()

	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_invuln_timer = maxf(_invuln_timer, dash_invuln_time)
	_speed_fx_intensity = 1.0
	_camera_roll_kick = randf_range(-3.2, 3.2)

	velocity.x = _dash_dir.x * dash_speed
	velocity.z = _dash_dir.z * dash_speed
	velocity.y = maxf(velocity.y, 1.2)

	if _dash_sfx_player != null:
		_dash_sfx_player.pitch_scale = randf_range(1.45, 1.65)
		_dash_sfx_player.play()


func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity.x = _dash_dir.x * dash_speed
	velocity.z = _dash_dir.z * dash_speed
	velocity.y = maxf(velocity.y, 0.0)
	if _dash_timer <= 0.0:
		_is_dashing = false
		velocity.x *= 0.52
		velocity.z *= 0.52


func _stop_slide() -> void:
	if not _is_sliding:
		return
	_is_sliding = false
	_slide_cooldown_timer = slide_cooldown
	if slide_player != null and slide_player.playing:
		slide_player.stop()


func _process_ground_movement(delta: float, input_dir: Vector2, move_dir: Vector3) -> void:
	var wants_sprint: bool = Input.is_action_pressed("sprint") and input_dir.length() > 0.1
	_is_sprinting = wants_sprint and not _is_exhausted and _stamina > 0.0

	var spd_mult: float = _speed_boost_mult if _speed_boost_timer > 0.0 else 1.0
	var target_speed: float = (sprint_speed if _is_sprinting else walk_speed) * spd_mult

	if is_on_floor():
		if move_dir != Vector3.ZERO:
			velocity.x = move_dir.x * target_speed
			velocity.z = move_dir.z * target_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, target_speed * 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, target_speed * 10.0 * delta)
	else:
		# Midair momentum preservation & Spider-Man air steering!
		var horiz_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		if move_dir != Vector3.ZERO:
			var current_horiz_spd: float = horiz_vel.length()
			var desired_spd: float = maxf(current_horiz_spd, target_speed)
			var steered: Vector3 = horiz_vel + move_dir * 16.0 * delta
			if steered.length() > desired_spd:
				steered = steered.normalized() * desired_spd
			velocity.x = steered.x
			velocity.z = steered.z
		else:
			velocity.x = move_toward(velocity.x, 0.0, 1.5 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 1.5 * delta)


func _update_stamina(delta: float) -> void:
	var prev_stamina: float = _stamina

	if _is_sprinting:
		_stamina = maxf(0.0, _stamina - sprint_stamina_drain * delta)
		_stamina_regen_timer = stamina_regen_delay
		if _stamina <= 0.0:
			_is_exhausted = true
			_is_sprinting = false
	elif not _is_sliding:
		if _stamina_regen_timer > 0.0:
			_stamina_regen_timer = maxf(0.0, _stamina_regen_timer - delta)
		elif _stamina < max_stamina:
			_stamina = minf(max_stamina, _stamina + stamina_regen_rate * delta)
			if _is_exhausted and _stamina >= exhausted_recover_threshold:
				_is_exhausted = false

	if not is_equal_approx(_stamina, prev_stamina):
		stamina_changed.emit(_stamina, max_stamina)
	_update_stamina_ui()


func _update_buffs(delta: float) -> void:
	if _heal_fx_intensity > 0.0:
		_heal_fx_intensity = maxf(0.0, _heal_fx_intensity - delta * 1.65)

	if _speed_boost_timer > 0.0:
		_speed_boost_timer = maxf(0.0, _speed_boost_timer - delta)
	var target_speed_fx: float = 1.0 if _speed_boost_timer > 0.0 else 0.0
	_speed_fx_intensity = lerpf(_speed_fx_intensity, target_speed_fx, minf(1.0, delta * 8.0))

	if _shield_timer > 0.0:
		_shield_timer = maxf(0.0, _shield_timer - delta)
	if _shield_flash_pulse > 0.0:
		_shield_flash_pulse = maxf(0.0, _shield_flash_pulse - delta * 3.5)

	var shield_active: bool = _shield_timer > 0.0
	var target_shield_fx: float = 1.0 if shield_active else 0.0
	if shield_active and _shield_timer <= 1.2:
		# Subtle warning blink in final 1.2s of shield
		var blink: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.025)
		target_shield_fx = blink
	_shield_fx_intensity = lerpf(_shield_fx_intensity, target_shield_fx, minf(1.0, delta * 10.0))

	# Update Shield HUD icon + timer bar right above the 3 skulls
	if shield_hud != null:
		shield_hud.visible = shield_active
		if shield_active:
			var ratio: float = clampf(_shield_timer / maxf(_shield_max_duration, 0.01), 0.0, 1.0)
			if shield_bar_fill != null:
				shield_bar_fill.offset_right = 52.0 + 104.0 * ratio
			if shield_icon != null:
				var use_flash_icon: bool = _shield_flash_pulse > 0.35 or (_shield_timer <= 1.2 and int(Time.get_ticks_msec() / 120) % 2 == 0)
				if use_flash_icon and _shield_flash_tex != null:
					shield_icon.texture = _shield_flash_tex
				elif _shield_active_tex != null:
					shield_icon.texture = _shield_active_tex

	# Push subtle screen-edge buff effects to shader
	if buff_vignette != null:
		var mat: ShaderMaterial = buff_vignette.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("heal_intensity", _heal_fx_intensity)
			mat.set_shader_parameter("speed_intensity", _speed_fx_intensity)
			mat.set_shader_parameter("shield_intensity", _shield_fx_intensity)
			mat.set_shader_parameter("shield_flash", _shield_flash_pulse)


func _update_stamina_ui() -> void:
	if stamina_bar == null:
		return
	stamina_bar.max_value = max_stamina
	stamina_bar.value = _stamina

	var is_low: bool = _stamina <= low_stamina_threshold or _is_exhausted
	if _is_exhausted and _stamina_under_red_tex != null:
		stamina_bar.texture_under = _stamina_under_red_tex
	elif _stamina_under_tex != null:
		stamina_bar.texture_under = _stamina_under_tex

	if is_low and _stamina_fill_red_tex != null:
		stamina_bar.texture_progress = _stamina_fill_red_tex
	elif _stamina_fill_orange_tex != null:
		stamina_bar.texture_progress = _stamina_fill_orange_tex


func _update_body_height(delta: float) -> void:
	var keep_low: bool = _is_sliding
	if not keep_low and ceiling_check != null:
		ceiling_check.force_raycast_update()
		if ceiling_check.is_colliding():
			keep_low = true

	var target_head_y: float = slide_head_height if keep_low else stand_head_height
	var target_capsule_h: float = slide_capsule_height if keep_low else stand_capsule_height
	var t: float = minf(1.0, delta * height_lerp_speed)

	if head != null:
		head.position.y = lerpf(head.position.y, target_head_y, t)

	if _capsule_shape != null and body_collision != null:
		_capsule_shape.height = lerpf(_capsule_shape.height, target_capsule_h, t)
		body_collision.position.y = _capsule_shape.height * 0.5


func _update_camera_effects(delta: float) -> void:
	if fps_camera == null:
		return

	var grapple_spd: float = grapple_controller.get_speed_ratio() if grapple_controller != null else 0.0
	var grapple_bank: float = grapple_controller.get_bank_roll_deg() if grapple_controller != null else 0.0

	var target_fov: float = base_fov
	if _is_dashing:
		target_fov = base_fov + 15.0
	elif grapple_controller != null and grapple_controller.is_pulling_self():
		target_fov = lerpf(base_fov + 4.0, 96.0, grapple_spd)
	elif _is_sliding:
		target_fov = slide_fov
	elif _is_sprinting:
		target_fov = sprint_fov
	if _speed_boost_timer > 0.0:
		target_fov += 6.0
	_hit_fov_offset = lerpf(_hit_fov_offset, 0.0, minf(1.0, delta * 18.0))
	fps_camera.fov = lerpf(fps_camera.fov, target_fov + _hit_fov_offset, minf(1.0, delta * fov_lerp_speed))

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	var target_cam_pos: Vector3 = Vector3.ZERO

	if not _is_sliding and is_on_floor() and horiz_speed > 0.35 and (grapple_controller == null or not grapple_controller.is_pulling_self()):
		var freq: float = sprint_bob_freq if _is_sprinting else walk_bob_freq
		var amp_y: float = sprint_bob_amp_y if _is_sprinting else walk_bob_amp_y
		var amp_x: float = sprint_bob_amp_x if _is_sprinting else walk_bob_amp_x
		var speed_scale: float = clampf(horiz_speed / maxf(sprint_speed if _is_sprinting else walk_speed, 0.01), 0.0, 1.0)

		_head_bob_time += delta * freq
		var bob_sin: float = sin(_head_bob_time)
		var bob_cos: float = cos(_head_bob_time * 0.5)
		target_cam_pos = Vector3(
			bob_cos * amp_x * speed_scale,
			bob_sin * amp_y * speed_scale,
			0.0
		)

		if not _is_sprinting and _prev_bob_sin >= -0.85 and bob_sin < -0.85:
			_play_walk_footstep()
		_prev_bob_sin = bob_sin
	else:
		_prev_bob_sin = 0.0

	# Smooth damped directional kick + sinusoidal trauma (never random pixel jitter!)
	_camera_z_kick = lerpf(_camera_z_kick, 0.0, minf(1.0, delta * 15.0))
	var trauma_offset: Vector3 = Vector3.ZERO
	var trauma_roll: float = 0.0
	if _hit_trauma > 0.001:
		_hit_trauma_time += delta
		_hit_trauma = maxf(0.0, _hit_trauma - delta * 3.8)
		var t2: float = _hit_trauma * _hit_trauma
		trauma_offset = Vector3(
			sin(_hit_trauma_time * 74.0) * 0.032 * t2,
			cos(_hit_trauma_time * 91.0) * 0.026 * t2,
			0.0
		)
		trauma_roll = sin(_hit_trauma_time * 66.0) * 2.2 * t2

	var desired_cam_pos: Vector3 = target_cam_pos + Vector3(0.0, 0.0, _camera_z_kick)
	fps_camera.position = fps_camera.position.lerp(desired_cam_pos, minf(1.0, delta * 18.0)) + trauma_offset

	_camera_roll_kick = lerpf(_camera_roll_kick, 0.0, minf(1.0, delta * 14.0))
	_camera_pitch_kick = lerpf(_camera_pitch_kick, 0.0, minf(1.0, delta * 12.0))
	var target_slide_roll: float = slide_roll_deg if _is_sliding else 0.0
	_current_slide_roll = lerpf(_current_slide_roll, target_slide_roll, minf(1.0, delta * 10.0))
	fps_camera.rotation_degrees.x = _camera_pitch_kick
	fps_camera.rotation_degrees.z = _camera_roll_kick + _current_slide_roll + grapple_bank + trauma_roll


func _play_walk_footstep() -> void:
	if walk_step_player == null:
		return
	walk_step_player.pitch_scale = randf_range(0.93, 1.07)
	walk_step_player.play(0.34)


func _update_footstep_audio(_delta: float) -> void:
	if run_step_player == null:
		return
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	var should_play_run: bool = _is_sprinting and is_on_floor() and not _is_sliding and horiz_speed > 1.0
	if should_play_run:
		if not run_step_player.playing:
			run_step_player.pitch_scale = randf_range(0.97, 1.04)
			run_step_player.play()
	else:
		if run_step_player.playing:
			run_step_player.stop()


func _update_arm_visibility() -> void:
	if _is_parrying:
		if slide_arm_anchor != null:
			slide_arm_anchor.visible = false
		if left_arm_anchor != null:
			left_arm_anchor.visible = _parry_pulling_in and not _grapple_equipped
		if grapple_arm_anchor != null:
			grapple_arm_anchor.visible = _parry_pulling_in and _grapple_equipped
		if right_weapon_controller != null:
			right_weapon_controller.apply_right_visibility(true)
		elif right_arm_anchor != null:
			right_arm_anchor.visible = true
		if parry_arm != null:
			parry_arm.visible = not _parry_pulling_in
		return

	if parry_arm != null:
		parry_arm.visible = false

	var any_punching: bool = (left_arm != null and left_arm.is_punching()) or (right_arm != null and right_arm.is_punching())
	var grapple_out: bool = grapple_controller != null and grapple_controller.is_hook_out()
	var using_gun: bool = right_weapon_controller != null and right_weapon_controller.is_using_gun()
	var show_slide_idle: bool = _is_sliding and not any_punching and not grapple_out and not using_gun

	if slide_arm_anchor != null:
		slide_arm_anchor.visible = show_slide_idle
	if left_arm_anchor != null:
		left_arm_anchor.visible = (not show_slide_idle) and (not _grapple_equipped)
	if grapple_arm_anchor != null:
		grapple_arm_anchor.visible = (not show_slide_idle) and _grapple_equipped
	if right_weapon_controller != null:
		right_weapon_controller.apply_right_visibility(not show_slide_idle)
	elif right_arm_anchor != null:
		right_arm_anchor.visible = not show_slide_idle


func _toggle_grapple_equip() -> void:
	if _is_swapping_left_arm or _is_parrying:
		return

	if grapple_controller != null and grapple_controller.is_active():
		grapple_controller.release(false)

	_is_swapping_left_arm = true
	if grapple_controller != null:
		grapple_controller.play_equip_click()

	if _left_swap_tween != null and _left_swap_tween.is_valid():
		_left_swap_tween.kill()

	var outgoing: Control = grapple_arm if _grapple_equipped else left_arm
	var next_equipped: bool = not _grapple_equipped

	_left_swap_tween = create_tween()
	if outgoing != null:
		outgoing.pivot_offset = Vector2(0.0, outgoing.size.y)
		_left_swap_tween.tween_property(outgoing, "position", Vector2(-50.0, 230.0), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_left_swap_tween.parallel().tween_property(outgoing, "rotation_degrees", -16.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		_left_swap_tween.tween_interval(0.11)

	_left_swap_tween.tween_callback(_finish_left_arm_swap_midpoint.bind(next_equipped))

	var incoming: Control = grapple_arm if next_equipped else left_arm
	if incoming != null:
		_left_swap_tween.tween_property(incoming, "position", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_left_swap_tween.parallel().tween_property(incoming, "rotation_degrees", 0.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_left_swap_tween.tween_callback(_on_left_arm_swap_done)


func _finish_left_arm_swap_midpoint(next_equipped: bool) -> void:
	_grapple_equipped = next_equipped
	var incoming: Control = grapple_arm if _grapple_equipped else left_arm
	if incoming != null:
		incoming.pivot_offset = Vector2(0.0, incoming.size.y)
		incoming.position = Vector2(-50.0, 230.0)
		incoming.rotation_degrees = -16.0
	if left_arm != null and _grapple_equipped:
		left_arm.rotation_degrees = 0.0
	if grapple_arm != null and not _grapple_equipped:
		grapple_arm.rotation_degrees = 0.0
	_update_arm_visibility()
	_show_debug_toast("GRAPPLE HOOK [HOLD R]" if _grapple_equipped else "LEFT FIST")


func _on_left_arm_swap_done() -> void:
	_is_swapping_left_arm = false
	_update_arm_visibility()


func _on_grapple_latched(_is_enemy: bool) -> void:
	_grapple_recoil = Vector2(-18.0, 14.0)
	_camera_roll_kick = -2.2


func _update_grapple_arm_visual(delta: float, move_ratio: float) -> void:
	if grapple_arm == null:
		return

	var hook_out: bool = grapple_controller != null and grapple_controller.is_hook_out()
	if hook_out and _grapple_hand_fired_tex != null:
		grapple_arm.texture = _grapple_hand_fired_tex
	elif not hook_out and _grapple_hand_ready_tex != null:
		grapple_arm.texture = _grapple_hand_ready_tex

	_grapple_recoil = _grapple_recoil.lerp(Vector2.ZERO, minf(1.0, delta * 11.0))

	var target_pos: Vector2 = _grapple_recoil
	var target_rot: float = 0.0

	if grapple_controller != null and (grapple_controller.is_pulling_self() or grapple_controller.is_pulling_enemy()):
		# Tensioned cable vibration + forward aim brace while pulling
		var spd_r: float = grapple_controller.get_speed_ratio()
		var vib: float = 2.0 + 4.5 * spd_r
		target_pos += Vector2(randf_range(-vib, vib), randf_range(-vib, vib)) + Vector2(18.0, -14.0)
		target_rot = 4.5
	else:
		if is_on_floor() and move_ratio > 0.05:
			_grapple_arm_bob_time += delta * 9.5
			target_pos += Vector2(cos(_grapple_arm_bob_time) * 7.0 * move_ratio, absf(sin(_grapple_arm_bob_time)) * 9.0 * move_ratio)
		else:
			_grapple_arm_bob_time += delta * 2.0
			target_pos += Vector2(sin(_grapple_arm_bob_time) * 2.5, cos(_grapple_arm_bob_time * 1.3) * 4.0)

	grapple_arm.position = grapple_arm.position.lerp(target_pos, minf(1.0, delta * 16.0))
	grapple_arm.rotation_degrees = lerpf(grapple_arm.rotation_degrees, target_rot, minf(1.0, delta * 14.0))


func _try_punch() -> void:
	if _is_parrying or _punch_cooldown_timer > 0.0:
		return

	var use_left: bool = _next_hand_is_left and not _grapple_equipped
	var chosen_arm: FPSArm = left_arm if use_left else right_arm
	var side_name: String = "left" if use_left else "right"
	if not _grapple_equipped:
		_next_hand_is_left = not _next_hand_is_left
	_punch_cooldown_timer = punch_cooldown

	if punch_whoosh_player != null:
		punch_whoosh_player.pitch_scale = randf_range(0.94, 1.08)
		punch_whoosh_player.play()

	if chosen_arm != null:
		chosen_arm.play_punch()
	_update_arm_visibility()
	punch_started.emit(side_name)


func _on_arm_punch_impact(arm_side: String) -> void:
	_camera_roll_kick = -camera_kick_deg if arm_side == "left" else camera_kick_deg
	if punch_ray == null:
		return
	punch_ray.force_raycast_update()
	if punch_ray.is_colliding():
		var collider: Object = punch_ray.get_collider()
		var hit_pos: Vector3 = punch_ray.get_collision_point()
		punch_hit.emit(arm_side, collider, hit_pos)
		if collider != null and collider.has_method("on_punched"):
			var res: Variant = collider.call("on_punched", punch_damage, hit_pos, arm_side)
			var killed: bool = false
			var blocked: bool = false
			if res is Dictionary:
				var d: Dictionary = res as Dictionary
				killed = bool(d.get("killed", false))
				blocked = bool(d.get("blocked", false))
			var active_arm: FPSArm = left_arm if arm_side == "left" else right_arm
			if active_arm != null:
				active_arm.trigger_contact_impact(killed)
			var w_id: String = "fist_left" if arm_side == "left" else "fist_right"
			trigger_weapon_hit_feel(w_id, killed, blocked, 1.0)
		else:
			if punch_hit_player != null:
				punch_hit_player.pitch_scale = randf_range(0.92, 1.08)
				punch_hit_player.play()
			var root_scene: Node = get_tree().current_scene
			if root_scene != null:
				CombatFX3D.spawn_sparks_burst(root_scene, hit_pos, punch_ray.get_collision_normal(), Color(0.92, 0.92, 0.92, 1.0), 5)


func _show_debug_toast(msg: String) -> void:
	_debug_toast = msg
	_debug_toast_timer = 2.0
	_update_debug_ui()


func _update_debug_ui() -> void:
	if debug_label == null:
		return
	debug_label.text = _debug_toast
