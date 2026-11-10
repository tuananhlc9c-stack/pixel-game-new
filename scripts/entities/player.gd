extends CharacterBody2D

@export var speed: float = 120.0
@export var roll_speed: float = 260.0
@export var roll_duration: float = 0.25
@export var max_health: int = 100
@export var max_mana: float = 100.0
@export var mana_regen_rate: float = 12.0 # Tự hồi 12 mana / giây
@export var roll_mana_cost: float = 20.0 # Mỗi lần lăn tốn 20 mana
@export var attack_damage: int = 25
@export var attack_knockback: float = 140.0
@export_group("Special Attack (Right Click)")
@export var special_attack_damage: int = 60
@export var special_attack_knockback: float = 240.0
@export var special_attack_cooldown: float = 3.0
@export var special_attack_scale: float = 1.45
@export var special_lunge_speed: float = 180.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var cam: Camera2D = $Camera2D if has_node("Camera2D") else null
@onready var weapon_pivot: Marker2D = $WeaponPivot if has_node("WeaponPivot") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var hitbox: Area2D = $WeaponPivot/hitbox if has_node("WeaponPivot/hitbox") else null
@onready var slash_effect: AnimatedSprite2D = $WeaponPivot/SlashEffect if has_node("WeaponPivot/SlashEffect") else null

var health_component: HealthComponent
var hp_bar_fill: ColorRect
var hp_label: Label
var mana_bar_fill: ColorRect
var mana_label: Label
var exp_bar_fill: ColorRect
var exp_label: Label
var level_badge_label: Label
var special_cd_bar_fill: ColorRect
var special_cd_label: Label
var level_up_hud_label: Label = null
var current_mana: float = 100.0
var level: int = 1
var current_exp: int = 0
var max_exp: int = 100

var last_direction: String = "down"
var is_rolling: bool = false
var is_attacking: bool = false
var is_special_attacking: bool = false
var special_cooldown_timer: float = 0.0
var current_attack_damage: int = 25
var current_attack_knockback: float = 140.0
var special_wave_progress: float = -1.0
var special_wave_angle: float = 0.0
var swing_combo_dir: int = 1
var combo_reset_timer: float = 0.0
var is_recording_trail: bool = false
var trail_is_special: bool = false
var slash_trail: Array[Dictionary] = []
var swing_tween: Tween = null
var knockback_velocity: Vector2 = Vector2.ZERO
var hit_targets: Array[Node] = []
var initial_spawn_position: Vector2 = Vector2.ZERO

# Hệ thống Câu Cá (Fishing System)
enum FishingState { NONE, CASTING, WAITING, BITE, CAUGHT }
var fishing_state: FishingState = FishingState.NONE
var fishing_timer: float = 0.0
var fishing_time_elapsed: float = 0.0
var bobber_target_local: Vector2 = Vector2.ZERO
var bobber_current_local: Vector2 = Vector2.ZERO
var rod_tip_local: Vector2 = Vector2.ZERO
var held_rod_sprite: Sprite2D = null
var fishing_status_label: Label = null
var caught_fish_sprite: Sprite2D = null
var default_weapon_texture: Texture2D = null
var active_swing_tool_id: String = ""

const TOOL_CONFIG: Dictionary = {
	"wood_pickaxe": {
		"name": "Wooden Pickaxe",
		"icon_region": Rect2(80, 16, 16, 16),
		"damage": 22,
		"special_damage": 50,
		"swing_speed_mult": 1.0,
		"glow_col": Color(0.95, 0.62, 0.22, 1.0),
		"core_col": Color(1.0, 0.92, 0.65, 1.0)
	},
	"wood_axe": {
		"name": "Wooden Axe",
		"icon_region": Rect2(80, 80, 16, 16),
		"damage": 26,
		"special_damage": 56,
		"swing_speed_mult": 1.0,
		"glow_col": Color(0.92, 0.52, 0.18, 1.0),
		"core_col": Color(1.0, 0.88, 0.55, 1.0)
	},
	"stone_pickaxe": {
		"name": "Stone Pickaxe",
		"icon_region": Rect2(80, 48, 16, 16),
		"damage": 32,
		"special_damage": 68,
		"swing_speed_mult": 1.22,
		"glow_col": Color(0.75, 0.72, 0.62, 1.0),
		"core_col": Color(0.96, 0.94, 0.88, 1.0)
	},
	"stone_axe": {
		"name": "Stone Axe",
		"icon_region": Rect2(80, 112, 16, 16),
		"damage": 36,
		"special_damage": 75,
		"swing_speed_mult": 1.22,
		"glow_col": Color(0.72, 0.68, 0.58, 1.0),
		"core_col": Color(0.95, 0.92, 0.84, 1.0)
	},
	"iron_pickaxe": {
		"name": "Iron Pickaxe",
		"icon_region": Rect2(192, 16, 16, 16),
		"damage": 45,
		"special_damage": 92,
		"swing_speed_mult": 1.48,
		"glow_col": Color(0.45, 0.84, 1.0, 1.0),
		"core_col": Color(0.92, 0.98, 1.0, 1.0)
	},
	"iron_axe": {
		"name": "Iron Axe",
		"icon_region": Rect2(192, 80, 16, 16),
		"damage": 48,
		"special_damage": 96,
		"swing_speed_mult": 1.48,
		"glow_col": Color(0.45, 0.84, 1.0, 1.0),
		"core_col": Color(0.92, 0.98, 1.0, 1.0)
	},
	# Kiếm Thường / Đại Kiếm (Sword) - Chém mạnh & nhanh: Gỗ < Sắt < Đồng < Vàng < Tím
	"wood_sword": {
		"name": "Wooden Sword", "type": "sword", "icon_region": Rect2(48, 112, 16, 16),
		"damage": 20, "special_damage": 45, "swing_speed_mult": 1.05,
		"glow_col": Color(0.68, 0.48, 0.25, 1.0), "core_col": Color(0.95, 0.85, 0.65, 1.0)
	},
	"iron_sword": {
		"name": "Iron Sword", "type": "sword", "icon_region": Rect2(64, 112, 16, 16),
		"damage": 30, "special_damage": 65, "swing_speed_mult": 1.2,
		"glow_col": Color(0.55, 0.75, 0.88, 1.0), "core_col": Color(0.92, 0.96, 1.0, 1.0)
	},
	"copper_sword": {
		"name": "Copper Sword", "type": "sword", "icon_region": Rect2(80, 112, 16, 16),
		"damage": 42, "special_damage": 88, "swing_speed_mult": 1.3,
		"glow_col": Color(0.92, 0.52, 0.18, 1.0), "core_col": Color(1.0, 0.85, 0.52, 1.0)
	},
	"gold_sword": {
		"name": "Gold Sword", "type": "sword", "icon_region": Rect2(96, 112, 16, 16),
		"damage": 60, "special_damage": 125, "swing_speed_mult": 1.4,
		"glow_col": Color(1.0, 0.82, 0.15, 1.0), "core_col": Color(1.0, 0.98, 0.75, 1.0)
	},
	"amethyst_sword": {
		"name": "Amethyst Sword", "type": "sword", "icon_region": Rect2(112, 112, 16, 16),
		"damage": 88, "special_damage": 175, "swing_speed_mult": 1.55,
		"glow_col": Color(0.85, 0.25, 1.0, 1.0), "core_col": Color(0.98, 0.82, 1.0, 1.0)
	},
	# Kiếm Quắm (Scythe) - chém quét rộng, sát thương tăng dần: Gỗ < Sắt < Đồng < Vàng < Tím
	"wood_scythe": {
		"name": "Wooden Scythe", "type": "scythe", "icon_region": Rect2(48, 80, 16, 16),
		"damage": 18, "special_damage": 40, "swing_speed_mult": 1.0,
		"glow_col": Color(0.68, 0.48, 0.25, 1.0), "core_col": Color(0.95, 0.85, 0.65, 1.0)
	},
	"iron_scythe": {
		"name": "Iron Scythe", "type": "scythe", "icon_region": Rect2(64, 80, 16, 16),
		"damage": 28, "special_damage": 60, "swing_speed_mult": 1.15,
		"glow_col": Color(0.55, 0.75, 0.88, 1.0), "core_col": Color(0.92, 0.96, 1.0, 1.0)
	},
	"copper_scythe": {
		"name": "Copper Scythe", "type": "scythe", "icon_region": Rect2(80, 80, 16, 16),
		"damage": 38, "special_damage": 82, "swing_speed_mult": 1.25,
		"glow_col": Color(0.92, 0.52, 0.18, 1.0), "core_col": Color(1.0, 0.85, 0.52, 1.0)
	},
	"gold_scythe": {
		"name": "Gold Scythe", "type": "scythe", "icon_region": Rect2(96, 80, 16, 16),
		"damage": 55, "special_damage": 115, "swing_speed_mult": 1.35,
		"glow_col": Color(1.0, 0.82, 0.15, 1.0), "core_col": Color(1.0, 0.98, 0.75, 1.0)
	},
	"amethyst_scythe": {
		"name": "Amethyst Scythe", "type": "scythe", "icon_region": Rect2(112, 80, 16, 16),
		"damage": 80, "special_damage": 165, "swing_speed_mult": 1.5,
		"glow_col": Color(0.85, 0.25, 1.0, 1.0), "core_col": Color(0.98, 0.82, 1.0, 1.0)
	},
	# Giáo (Spear) - đâm thẳng xuyên mục tiêu: Gỗ < Sắt < Đồng < Vàng < Tím
	"wood_spear": {
		"name": "Wooden Spear", "type": "spear", "icon_region": Rect2(48, 32, 16, 16),
		"damage": 20, "special_damage": 44, "swing_speed_mult": 1.0,
		"glow_col": Color(0.68, 0.48, 0.25, 1.0), "core_col": Color(0.95, 0.85, 0.65, 1.0)
	},
	"iron_spear": {
		"name": "Iron Spear", "type": "spear", "icon_region": Rect2(64, 32, 16, 16),
		"damage": 30, "special_damage": 66, "swing_speed_mult": 1.15,
		"glow_col": Color(0.55, 0.75, 0.88, 1.0), "core_col": Color(0.92, 0.96, 1.0, 1.0)
	},
	"copper_spear": {
		"name": "Copper Spear", "type": "spear", "icon_region": Rect2(80, 32, 16, 16),
		"damage": 42, "special_damage": 90, "swing_speed_mult": 1.25,
		"glow_col": Color(0.92, 0.52, 0.18, 1.0), "core_col": Color(1.0, 0.85, 0.52, 1.0)
	},
	"gold_spear": {
		"name": "Gold Spear", "type": "spear", "icon_region": Rect2(96, 32, 16, 16),
		"damage": 60, "special_damage": 128, "swing_speed_mult": 1.35,
		"glow_col": Color(1.0, 0.82, 0.15, 1.0), "core_col": Color(1.0, 0.98, 0.75, 1.0)
	},
	"amethyst_spear": {
		"name": "Amethyst Spear", "type": "spear", "icon_region": Rect2(112, 32, 16, 16),
		"damage": 88, "special_damage": 180, "swing_speed_mult": 1.5,
		"glow_col": Color(0.85, 0.25, 1.0, 1.0), "core_col": Color(0.98, 0.82, 1.0, 1.0)
	},
	# Cung tên (Bow) - bắn tên tầm xa: Gỗ < Sắt < Đồng < Vàng < Tím
	"wood_bow": {
		"name": "Wooden Bow", "type": "bow", "icon_region": Rect2(48, 64, 16, 16),
		"damage": 18, "special_damage": 38, "swing_speed_mult": 1.0,
		"glow_col": Color(0.68, 0.48, 0.25, 1.0), "core_col": Color(0.95, 0.85, 0.65, 1.0)
	},
	"iron_bow": {
		"name": "Iron Bow", "type": "bow", "icon_region": Rect2(64, 64, 16, 16),
		"damage": 26, "special_damage": 58, "swing_speed_mult": 1.15,
		"glow_col": Color(0.55, 0.75, 0.88, 1.0), "core_col": Color(0.92, 0.96, 1.0, 1.0)
	},
	"copper_bow": {
		"name": "Copper Bow", "type": "bow", "icon_region": Rect2(80, 64, 16, 16),
		"damage": 36, "special_damage": 78, "swing_speed_mult": 1.25,
		"glow_col": Color(0.92, 0.52, 0.18, 1.0), "core_col": Color(1.0, 0.85, 0.52, 1.0)
	},
	"gold_bow": {
		"name": "Gold Bow", "type": "bow", "icon_region": Rect2(96, 64, 16, 16),
		"damage": 52, "special_damage": 110, "swing_speed_mult": 1.35,
		"glow_col": Color(1.0, 0.82, 0.15, 1.0), "core_col": Color(1.0, 0.98, 0.75, 1.0)
	},
	"amethyst_bow": {
		"name": "Amethyst Bow", "type": "bow", "icon_region": Rect2(112, 64, 16, 16),
		"damage": 78, "special_damage": 160, "swing_speed_mult": 1.5,
		"glow_col": Color(0.85, 0.25, 1.0, 1.0), "core_col": Color(0.98, 0.82, 1.0, 1.0)
	},
	# Kiếm Cong / Trượng Kiếm: Đều chuyển thành dạng Kiếm Chém (type: "sword")
	"wood_staff": {
		"name": "Wooden Staff", "type": "sword", "icon_region": Rect2(48, 96, 16, 16),
		"damage": 22, "special_damage": 48, "swing_speed_mult": 1.0,
		"glow_col": Color(0.68, 0.48, 0.25, 1.0), "core_col": Color(0.95, 0.85, 0.65, 1.0)
	},
	"iron_staff": {
		"name": "Iron Staff", "type": "sword", "icon_region": Rect2(64, 96, 16, 16),
		"damage": 32, "special_damage": 70, "swing_speed_mult": 1.15,
		"glow_col": Color(0.55, 0.75, 0.88, 1.0), "core_col": Color(0.92, 0.96, 1.0, 1.0)
	},
	"copper_staff": {
		"name": "Copper Staff", "type": "sword", "icon_region": Rect2(80, 96, 16, 16),
		"damage": 45, "special_damage": 96, "swing_speed_mult": 1.25,
		"glow_col": Color(0.92, 0.52, 0.18, 1.0), "core_col": Color(1.0, 0.85, 0.52, 1.0)
	},
	"gold_staff": {
		"name": "Gold Staff", "type": "sword", "icon_region": Rect2(96, 96, 16, 16),
		"damage": 65, "special_damage": 138, "swing_speed_mult": 1.35,
		"glow_col": Color(1.0, 0.82, 0.15, 1.0), "core_col": Color(1.0, 0.98, 0.75, 1.0)
	},
	"amethyst_staff": {
		"name": "Amethyst Staff", "type": "sword", "icon_region": Rect2(112, 96, 16, 16),
		"damage": 95, "special_damage": 195, "swing_speed_mult": 1.5,
		"glow_col": Color(0.85, 0.25, 1.0, 1.0), "core_col": Color(0.98, 0.82, 1.0, 1.0)
	}
}

const FISH_POOL: Array[Dictionary] = [
	{"id": "fish_carp", "name": "Carp", "region": Rect2(0, 48, 16, 16)},
	{"id": "fish_perch", "name": "Perch", "region": Rect2(16, 48, 16, 16)},
	{"id": "fish_salmon", "name": "Red Salmon", "region": Rect2(32, 48, 16, 16)},
	{"id": "fish_gold", "name": "Goldfish", "region": Rect2(48, 48, 16, 16)},
	{"id": "fish_tuna", "name": "Tuna", "region": Rect2(80, 48, 16, 16)},
	{"id": "fish_crab", "name": "Red Crab", "region": Rect2(144, 48, 16, 16)},
	{"id": "fish_shrimp", "name": "Silver Shrimp", "region": Rect2(160, 48, 16, 16)},
	{"id": "fish_octopus", "name": "Octopus", "region": Rect2(176, 48, 16, 16)}
]

func _ready() -> void:
	add_to_group("player")

	# 1. Chuẩn hóa tâm nhân vật nếu bị lệch trong scene
	if anim and anim.position != Vector2.ZERO:
		var visual_offset := anim.position
		global_position += visual_offset
		anim.position = Vector2.ZERO
		if col_shape:
			col_shape.position -= visual_offset
		if cam:
			cam.position = Vector2.ZERO

	# 2. Thiết lập trạng thái ban đầu cho vũ khí & kết nối hitbox
	if weapon_pivot:
		weapon_pivot.position = Vector2.ZERO
		weapon_pivot.z_index = 10
		weapon_pivot.hide()

	if hitbox:
		hitbox.position = Vector2(18, 0)
		if not hitbox.body_entered.is_connected(_on_weapon_hitbox_body_entered):
			hitbox.body_entered.connect(_on_weapon_hitbox_body_entered)
		if not hitbox.area_entered.is_connected(_on_weapon_hitbox_area_entered):
			hitbox.area_entered.connect(_on_weapon_hitbox_area_entered)
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.position = Vector2.ZERO
				child.disabled = true

	if slash_effect:
		slash_effect.hide()

	# 3. Khởi tạo Hệ thống Máu (HealthComponent) và HUD
	_setup_health_system()
	_setup_fishing_visuals()

	# 4. Đặt vị trí spawn khi chuyển cảnh
	if SceneManager and SceneManager.use_spawn_position:
		global_position = SceneManager.spawn_position
		SceneManager.use_spawn_position = false

	initial_spawn_position = global_position

func _setup_health_system() -> void:
	# Cập nhật Level và Máu/Mana tối đa theo cấp độ (Mỗi cấp tăng 50 HP và 50 Mana)
	if SceneManager:
		level = clampi(SceneManager.saved_player_level, 1, 18)
		current_exp = SceneManager.saved_player_exp
	else:
		level = 1
		current_exp = 0
	max_exp = SceneManager.get_exp_required_for_level(level) if SceneManager else 100

	# Base: Level 1 = 100 HP, 100 Mana. Mỗi cấp tăng thêm +50
	max_health = 100 + (level - 1) * 50
	max_mana = 100.0 + float((level - 1) * 50)

	if has_node("HealthComponent"):
		health_component = $HealthComponent
	else:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		health_component.max_health = max_health
		health_component.invincibility_duration = 0.6
		add_child(health_component)

	health_component.max_health = max_health
	if SceneManager and SceneManager.saved_player_health > 0:
		health_component.current_health = min(SceneManager.saved_player_health, max_health)
	else:
		health_component.current_health = max_health

	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_player_died)

	# Kết nối sự kiện lên cấp & nhận kinh nghiệm từ SceneManager
	if SceneManager:
		if not SceneManager.exp_changed.is_connected(_on_scene_manager_exp_changed):
			SceneManager.exp_changed.connect(_on_scene_manager_exp_changed)
		if not SceneManager.level_up.is_connected(_on_scene_manager_level_up):
			SceneManager.level_up.connect(_on_scene_manager_level_up)

	# Tạo HUD ở góc trên bên trái màn hình
	var hud := CanvasLayer.new()
	hud.name = "PlayerHUD"
	add_child(hud)

	# 1. Thanh Máu (HP)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.15, 0.85)
	bg.position = Vector2(16, 16)
	bg.size = Vector2(144, 18)
	hud.add_child(bg)

	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = Color(0.85, 0.22, 0.25, 1.0)
	hp_bar_fill.position = Vector2(18, 18)
	hp_bar_fill.size = Vector2(140, 14)
	hud.add_child(hp_bar_fill)

	hp_label = Label.new()
	hp_label.position = Vector2(22, 14)
	hp_label.add_theme_font_size_override("font_size", 12)
	hud.add_child(hp_label)

	# 2. Thanh Năng Lượng (Mana) màu xanh lam dưới thanh máu
	var mana_bg := ColorRect.new()
	mana_bg.color = Color(0.12, 0.12, 0.15, 0.85)
	mana_bg.position = Vector2(16, 38)
	mana_bg.size = Vector2(144, 16)
	hud.add_child(mana_bg)

	mana_bar_fill = ColorRect.new()
	mana_bar_fill.color = Color(0.2, 0.55, 0.95, 1.0)
	mana_bar_fill.position = Vector2(18, 40)
	mana_bar_fill.size = Vector2(140, 12)
	hud.add_child(mana_bar_fill)

	mana_label = Label.new()
	mana_label.position = Vector2(22, 38)
	mana_label.add_theme_font_size_override("font_size", 11)
	hud.add_child(mana_label)

	# Khởi tạo giá trị Mana
	if SceneManager and SceneManager.saved_player_mana >= 0.0:
		current_mana = minf(SceneManager.saved_player_mana, max_mana)
	else:
		current_mana = max_mana
	_update_mana_ui()

	# 3. Thanh Kinh Nghiệm (EXP) màu tím / xanh lá dưới thanh mana (Tối đa 18 cấp)
	var exp_bg := ColorRect.new()
	exp_bg.color = Color(0.12, 0.12, 0.15, 0.85)
	exp_bg.position = Vector2(16, 58)
	exp_bg.size = Vector2(144, 16)
	hud.add_child(exp_bg)

	exp_bar_fill = ColorRect.new()
	exp_bar_fill.color = Color(0.55, 0.28, 0.95, 1.0) # Màu tím sáng
	exp_bar_fill.position = Vector2(18, 60)
	exp_bar_fill.size = Vector2(140, 12)
	hud.add_child(exp_bar_fill)

	exp_label = Label.new()
	exp_label.position = Vector2(22, 58)
	exp_label.add_theme_font_size_override("font_size", 10)
	hud.add_child(exp_label)

	# 4. Thanh hồi chiêu Chém Đặc Biệt (Chuột Phải) dưới thanh EXP
	var cd_bg := ColorRect.new()
	cd_bg.color = Color(0.12, 0.12, 0.15, 0.85)
	cd_bg.position = Vector2(16, 78)
	cd_bg.size = Vector2(144, 14)
	hud.add_child(cd_bg)

	special_cd_bar_fill = ColorRect.new()
	special_cd_bar_fill.color = Color(0.95, 0.72, 0.18, 1.0)
	special_cd_bar_fill.position = Vector2(18, 80)
	special_cd_bar_fill.size = Vector2(140, 10)
	hud.add_child(special_cd_bar_fill)

	special_cd_label = Label.new()
	special_cd_label.position = Vector2(22, 76)
	special_cd_label.add_theme_font_size_override("font_size", 10)
	hud.add_child(special_cd_label)

	# 5. Nhãn thông báo Level Up trên HUD
	level_up_hud_label = Label.new()
	level_up_hud_label.name = "LevelUpHUDLabel"
	level_up_hud_label.position = Vector2(16, 96)
	level_up_hud_label.size = Vector2(240, 24)
	level_up_hud_label.add_theme_font_size_override("font_size", 13)
	level_up_hud_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.2, 1.0))
	level_up_hud_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.0, 1.0))
	level_up_hud_label.add_theme_constant_override("outline_size", 4)
	level_up_hud_label.visible = false
	hud.add_child(level_up_hud_label)

	_on_health_changed(health_component.current_health, health_component.max_health)
	_update_exp_ui()
	_update_special_cooldown_ui()

func _is_mouse_over_placed_furniture() -> bool:
	var world_mouse := get_global_mouse_position()
	for node in get_tree().get_nodes_in_group("world_pickup_item"):
		if is_instance_valid(node):
			if node.get("is_dragging") == true:
				return true
			if node.has_method("is_point_over_item") and node.is_point_over_item(world_mouse):
				return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	for shop_ui in get_tree().get_nodes_in_group("merchant_shop_ui"):
		if shop_ui is Control and shop_ui.is_visible_in_tree():
			return

	# Nếu chuột đang trỏ vào đồ nội thất trên sàn (để kéo di chuyển hoặc chuột phải cất vào túi), không vung kiếm
	if _is_mouse_over_placed_furniture():
		return

	if event.is_action_pressed("attack"):
		var inv = get_tree().get_first_node_in_group("inventory")
		if inv and inv.has_method("is_holding_furniture") and inv.is_holding_furniture():
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if inv.place_selected_furniture_at_mouse():
					get_viewport().set_input_as_handled()
					return
		if _is_holding_fishing_rod():
			_handle_fishing_action()
			return
		elif fishing_state != FishingState.NONE:
			_cancel_fishing()
			return
		if not is_attacking and not is_rolling:
			start_weapon_swing(false)
	elif event.is_action_pressed("special_attack") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		if fishing_state != FishingState.NONE:
			_cancel_fishing("Canceled")
			return
		if not is_attacking and not is_rolling:
			if special_cooldown_timer <= 0.0:
				start_weapon_swing(true)
			else:
				_flash_cooldown_warning()

func _physics_process(delta: float) -> void:
	# Tự động hồi phục Mana theo thời gian
	if current_mana < max_mana:
		current_mana = minf(max_mana, current_mana + mana_regen_rate * delta)
		if SceneManager:
			SceneManager.saved_player_mana = current_mana
		_update_mana_ui()

	if special_cooldown_timer > 0.0:
		special_cooldown_timer = maxf(0.0, special_cooldown_timer - delta)
		_update_special_cooldown_ui()

	if combo_reset_timer > 0.0:
		combo_reset_timer = maxf(0.0, combo_reset_timer - delta)
		if combo_reset_timer <= 0.0:
			swing_combo_dir = 1

	# Cập nhật vệt kiếm động mượt mà theo từng khung hình
	_update_slash_trail(delta)
	_update_fishing(delta)

	if special_wave_progress >= 0.0:
		special_wave_progress += delta * 4.2
		if special_wave_progress > 1.0:
			special_wave_progress = -1.0
		queue_redraw()

	# Quét va chạm liên tục trong lúc vung kiếm để đòn chém nhanh không bỏ sót mục tiêu
	if is_attacking and hitbox:
		for body in hitbox.get_overlapping_bodies():
			_apply_weapon_hit(body)
		for area in hitbox.get_overlapping_areas():
			_on_weapon_hitbox_area_entered(area)

	if knockback_velocity.length() > 5.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return

	if is_rolling:
		move_and_slide()
		return

	var input_x := Input.get_axis("move_left", "move_right")
	if input_x == 0:
		input_x = Input.get_axis("ui_left", "ui_right")

	var input_y := Input.get_axis("move_up", "move_down")
	if input_y == 0:
		input_y = Input.get_axis("ui_up", "ui_down")

	var direction := Vector2(input_x, input_y).normalized()

	# Nếu đang thả câu mà di chuyển hoặc lộn nhào thì tự động thu dây câu
	if fishing_state != FishingState.NONE:
		if direction != Vector2.ZERO or Input.is_action_just_pressed("roll") or Input.is_action_just_pressed("ui_accept"):
			if fishing_state != FishingState.CAUGHT:
				_cancel_fishing()
		else:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	# Khi đang chém: cho phép di chuyển mượt hoặc trượt theo quán tính thay vì khựng cứng
	if is_attacking:
		if is_special_attacking:
			velocity = velocity.move_toward(direction * (speed * 0.45), 520.0 * delta)
		else:
			var target_move := direction * (speed * 0.65)
			velocity = velocity.move_toward(target_move, 650.0 * delta)
		move_and_slide()
		return

	if Input.is_action_just_pressed("roll") or Input.is_action_just_pressed("ui_accept"):
		if current_mana >= roll_mana_cost:
			start_roll(direction)
			return
		else:
			_flash_mana_warning()

	if direction != Vector2.ZERO:
		velocity = direction * speed

		if direction.x < 0:
			anim.flip_h = true
			last_direction = "left"
		elif direction.x > 0:
			anim.flip_h = false
			last_direction = "right"

		if abs(direction.x) > abs(direction.y):
			if anim.flip_h and anim.sprite_frames.has_animation("walk_left"):
				anim.play("walk_left")
			else:
				anim.play("walk_right")
		else:
			if direction.y > 0:
				anim.play("walk_down")
				if direction.x == 0:
					last_direction = "down"
			else:
				anim.play("walk_up")
				if direction.x == 0:
					last_direction = "up"
	else:
		velocity = Vector2.ZERO
		if last_direction == "up":
			anim.flip_h = false
			anim.play("stand1")
		elif last_direction == "left":
			anim.flip_h = true
			anim.play("stand")
		else:
			anim.flip_h = false
			anim.play("stand")

	move_and_slide()

# Cơ chế chém 3 giai đoạn mượt mà (Lấy đà -> Vung chém tốc độ cao -> Thu kiếm) + Đảo chiều Combo
func start_weapon_swing(is_special: bool = false) -> void:
	if not weapon_pivot:
		return

	if swing_tween and swing_tween.is_valid():
		swing_tween.kill()

	is_attacking = true
	is_special_attacking = is_special
	hit_targets.clear()
	active_swing_tool_id = _get_equipped_tool_id()

	var swing_dir: float = float(swing_combo_dir)
	if not is_special:
		swing_combo_dir *= -1
		combo_reset_timer = 0.75
	else:
		swing_dir = 1.0

	# Thiết lập sát thương, lực đẩy lùi và hồi chiêu (tùy theo Kiếm hoặc Cuốc/Rìu đang cầm)
	if active_swing_tool_id != "" and TOOL_CONFIG.has(active_swing_tool_id):
		var t_cfg: Dictionary = TOOL_CONFIG[active_swing_tool_id]
		if is_special:
			current_attack_damage = int(t_cfg["special_damage"])
			current_attack_knockback = special_attack_knockback
			special_cooldown_timer = special_attack_cooldown
			_update_special_cooldown_ui()
		else:
			current_attack_damage = int(t_cfg["damage"])
			current_attack_knockback = attack_knockback
	elif is_special:
		current_attack_damage = special_attack_damage
		current_attack_knockback = special_attack_knockback
		special_cooldown_timer = special_attack_cooldown
		_update_special_cooldown_ui()
	else:
		current_attack_damage = attack_damage
		current_attack_knockback = attack_knockback

	# 1. Hiển thị vũ khí / công cụ
	weapon_pivot.show()
	weapon_pivot.modulate.a = 1.0
	if slash_effect:
		slash_effect.hide()

	var weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite if has_node("WeaponPivot/WeaponSprite") else null
	if weapon_sprite:
		if default_weapon_texture == null:
			default_weapon_texture = weapon_sprite.texture
		if active_swing_tool_id != "" and TOOL_CONFIG.has(active_swing_tool_id):
			var t_cfg: Dictionary = TOOL_CONFIG[active_swing_tool_id]
			var is_weapon_sheet := ("type" in t_cfg)
			var sheet_path := "res://Content T1/Tilesheet/Weapon1_tilet.png" if is_weapon_sheet else "res://Content T1/Tilesheet/Tools1_tilet.png"
			var loaded_tex := load(sheet_path) as Texture2D
			if loaded_tex:
				var tool_atlas := AtlasTexture.new()
				tool_atlas.atlas = loaded_tex
				tool_atlas.region = t_cfg["icon_region"]
				weapon_sprite.texture = tool_atlas
		elif default_weapon_texture != null:
			weapon_sprite.texture = default_weapon_texture
		weapon_sprite.show()
		weapon_sprite.scale = Vector2(1.014, 0.97)

	# 2. Lấy góc hướng về phía chuột
	var local_mouse := get_local_mouse_position()
	if local_mouse.length() < 2.0:
		local_mouse = Vector2.RIGHT

	var mouse_dir := local_mouse.normalized()
	var mouse_angle := local_mouse.angle()
	weapon_pivot.position = Vector2.ZERO

	# Xoay mặt nhân vật theo hướng chuột
	if abs(local_mouse.x) > abs(local_mouse.y):
		if local_mouse.x < 0:
			anim.flip_h = true
			last_direction = "left"
		else:
			anim.flip_h = false
			last_direction = "right"
	else:
		if local_mouse.y > 0:
			anim.flip_h = false
			last_direction = "down"
		else:
			anim.flip_h = false
			last_direction = "up"

	var weapon_type: String = "sword"
	if active_swing_tool_id != "" and TOOL_CONFIG.has(active_swing_tool_id):
		weapon_type = str(TOOL_CONFIG[active_swing_tool_id].get("type", "tool"))

	# Tách luồng hoạt ảnh riêng cho từng loại vũ khí:
	if weapon_type == "bow":
		_execute_bow_attack(is_special, mouse_dir, mouse_angle, weapon_sprite)
		return
	elif weapon_type == "staff":
		_execute_staff_attack(is_special, mouse_dir, mouse_angle, weapon_sprite)
		return
	elif weapon_type == "spear":
		_execute_spear_attack(is_special, mouse_dir, mouse_angle, weapon_sprite)
		return

	# Hoạt ảnh chém hình vòng cung cho Kiếm Quắm (Scythe) và Công Cụ / Kiếm Mặc Định
	# Tính toán góc lấy đà, góc bắt đầu và góc kết thúc đối xứng quanh con trỏ chuột
	var half_arc := deg_to_rad(125.0 if is_special else 68.0)
	var windup_start := mouse_angle - (half_arc - deg_to_rad(22.0)) * swing_dir
	var slash_start := mouse_angle - half_arc * swing_dir
	var slash_end := mouse_angle + half_arc * swing_dir
	var follow_end := slash_end + deg_to_rad(16.0) * swing_dir
	var base_scale := special_attack_scale if is_special else 1.0

	weapon_pivot.rotation = windup_start
	weapon_pivot.scale = Vector2.ONE * (base_scale * 0.88)

	if is_special:
		velocity = mouse_dir * special_lunge_speed
		special_wave_angle = mouse_angle
		special_wave_progress = 0.0
		if weapon_sprite:
			weapon_sprite.modulate = Color(2.3, 1.4, 0.35, 1.0)
		if anim:
			anim.modulate = Color(1.6, 1.35, 0.65, 1.0)
	else:
		# Nhích nhẹ về phía trước theo hướng chém để tạo cảm giác có lực
		velocity = velocity * 0.55 + mouse_dir * 48.0
		if weapon_sprite:
			weapon_sprite.modulate = Color(1.25, 1.25, 1.35, 1.0)

	# 3. Giai đoạn 1: Lấy đà nhanh (Wind-up) + Nén nhẹ người
	var speed_mult := 1.0
	if active_swing_tool_id != "" and TOOL_CONFIG.has(active_swing_tool_id):
		speed_mult = float(TOOL_CONFIG[active_swing_tool_id].get("swing_speed_mult", 1.0))
	var windup_time := (0.055 if is_special else 0.04) / speed_mult
	var slash_time := (0.19 if is_special else 0.135) / speed_mult
	var follow_time := (0.075 if is_special else 0.055) / speed_mult

	swing_tween = create_tween()
	swing_tween.set_parallel(true)
	swing_tween.tween_property(weapon_pivot, "rotation", slash_start, windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(weapon_pivot, "scale", Vector2.ONE * base_scale, windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if anim:
		swing_tween.tween_property(anim, "scale", Vector2(1.12, 0.9), windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		swing_tween.tween_property(anim, "rotation", deg_to_rad(-5.0 * swing_dir), windup_time)

	await swing_tween.finished
	if not is_instance_valid(self):
		return

	# 4. Giai đoạn 2: Vung kiếm/công cụ tốc độ cao (Main Slash) + Bật Hitbox + Bật Vệt Chém Động
	if active_swing_tool_id != "":
		_try_harvest_resources_with_tool(active_swing_tool_id, mouse_dir)

	slash_trail.clear()
	is_recording_trail = true
	trail_is_special = is_special

	if hitbox:
		hitbox.show()
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = false

	swing_tween = create_tween()
	swing_tween.tween_property(weapon_pivot, "rotation", slash_end, slash_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Phóng nhẹ kích thước kiếm ở đỉnh vòng vung tạo độ vươn mượt mà
	var scale_tween := create_tween()
	scale_tween.tween_property(weapon_pivot, "scale", Vector2.ONE * (base_scale * 1.16), slash_time * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(weapon_pivot, "scale", Vector2.ONE * base_scale, slash_time * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if anim:
		var body_tween := create_tween().set_parallel(true)
		body_tween.tween_property(anim, "scale", Vector2(0.94, 1.07), slash_time * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		body_tween.tween_property(anim, "rotation", deg_to_rad(6.0 * swing_dir), slash_time * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await swing_tween.finished
	if not is_instance_valid(self):
		return

	# 5. Giai đoạn 3: Thu kiếm theo quán tính & mờ dần (Follow-through)
	is_recording_trail = false
	if hitbox:
		hitbox.hide()
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true

	# Mở khóa di chuyển và cho phép nối đòn sớm ngay khi bước vào giai đoạn thu kiếm
	is_special_attacking = false
	is_attacking = false

	swing_tween = create_tween()
	swing_tween.set_parallel(true)
	swing_tween.tween_property(weapon_pivot, "rotation", follow_end, follow_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(weapon_pivot, "scale", Vector2.ONE * (base_scale * 0.85), follow_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing_tween.tween_property(weapon_pivot, "modulate:a", 0.0, follow_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if anim:
		swing_tween.tween_property(anim, "scale", Vector2.ONE, follow_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		swing_tween.tween_property(anim, "rotation", 0.0, follow_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if is_special:
			swing_tween.tween_property(anim, "modulate", Color.WHITE, follow_time)

	await swing_tween.finished
	if not is_instance_valid(self):
		return

	if not is_attacking:
		if weapon_sprite:
			weapon_sprite.modulate = Color.WHITE
			weapon_sprite.scale = Vector2(1.014, 0.97)
		weapon_pivot.modulate.a = 1.0
		weapon_pivot.scale = Vector2.ONE
		weapon_pivot.hide()

func _execute_spear_attack(is_special: bool, mouse_dir: Vector2, mouse_angle: float, weapon_sprite: Sprite2D) -> void:
	var speed_mult: float = 1.0
	var t_cfg: Dictionary = {}
	if active_swing_tool_id != "" and TOOL_CONFIG.has(active_swing_tool_id):
		t_cfg = TOOL_CONFIG[active_swing_tool_id]
		speed_mult = float(t_cfg.get("swing_speed_mult", 1.0))

	var thrust_reach: float = 20.0 if not is_special else 30.0
	var thrust_time: float = (0.10 if not is_special else 0.14) / speed_mult
	var recover_time: float = (0.09 if not is_special else 0.11) / speed_mult

	# Đặt tâm vũ khí sát tay nhân vật
	weapon_pivot.rotation = mouse_angle
	weapon_pivot.position = mouse_dir * 4.0
	weapon_pivot.scale = Vector2.ONE * (special_attack_scale if is_special else 1.0)
	if weapon_sprite:
		weapon_sprite.position = Vector2(4, 0)
		weapon_sprite.rotation = PI * 0.25 # Hướng mũi giáo dọc theo góc đâm
		weapon_sprite.modulate = Color(2.0, 1.5, 0.4, 1.0) if is_special else t_cfg.get("core_col", Color.WHITE)

	if is_special:
		velocity = mouse_dir * special_lunge_speed * 1.1
	else:
		velocity = velocity * 0.4 + mouse_dir * 45.0

	# 1. Rút giáo nhẹ về sau chuẩn bị đâm
	swing_tween = create_tween()
	swing_tween.tween_property(weapon_pivot, "position", -mouse_dir * 3.0, 0.035 / speed_mult).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await swing_tween.finished
	if not is_instance_valid(self):
		return

	# 2. Đâm thẳng ra phía trước + bật hitbox
	if hitbox:
		hitbox.show()
		hitbox.position = Vector2(thrust_reach * 0.8, 0)
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = false

	swing_tween = create_tween()
	swing_tween.tween_property(weapon_pivot, "position", mouse_dir * thrust_reach, thrust_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if anim:
		var body_tween := create_tween()
		body_tween.tween_property(anim, "scale", Vector2(1.12, 0.92), thrust_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		body_tween.tween_property(anim, "scale", Vector2.ONE, thrust_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await swing_tween.finished
	if not is_instance_valid(self):
		return

	# 3. Thu giáo về & kết thúc đòn
	if hitbox:
		hitbox.hide()
		hitbox.position = Vector2(18, 0)
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true

	is_special_attacking = false
	is_attacking = false

	swing_tween = create_tween().set_parallel(true)
	swing_tween.tween_property(weapon_pivot, "position", Vector2.ZERO, recover_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing_tween.tween_property(weapon_pivot, "modulate:a", 0.0, recover_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await swing_tween.finished
	if not is_instance_valid(self):
		return

	if not is_attacking:
		if weapon_sprite:
			weapon_sprite.position = Vector2(17, 3)
			weapon_sprite.modulate = Color.WHITE
			weapon_sprite.rotation = deg_to_rad(45.0)
		weapon_pivot.modulate.a = 1.0
		weapon_pivot.scale = Vector2.ONE
		weapon_pivot.position = Vector2.ZERO
		weapon_pivot.hide()

func _execute_bow_attack(is_special: bool, mouse_dir: Vector2, mouse_angle: float, weapon_sprite: Sprite2D) -> void:
	var speed_mult: float = 1.0
	var t_cfg: Dictionary = {}
	if active_swing_tool_id != "" and TOOL_CONFIG.has(active_swing_tool_id):
		t_cfg = TOOL_CONFIG[active_swing_tool_id]
		speed_mult = float(t_cfg.get("swing_speed_mult", 1.0))

	var draw_time: float = (0.13 if not is_special else 0.18) / speed_mult
	var release_time: float = 0.07 / speed_mult

	# Giữ cung ở cự ly gần cơ thể (chỉ cách 4-6px)
	weapon_pivot.rotation = mouse_angle
	weapon_pivot.position = mouse_dir * 4.0
	weapon_pivot.scale = Vector2.ONE * (special_attack_scale if is_special else 1.0)
	if weapon_sprite:
		weapon_sprite.position = Vector2(2, 0)
		weapon_sprite.rotation = 0.0
		weapon_sprite.modulate = t_cfg.get("core_col", Color.WHITE)

	# Giật lùi nhẹ người tạo cảm giác kéo cung
	velocity = -mouse_dir * 18.0

	# 1. Kéo căng dây cung (Scale hơi dẹt lại)
	swing_tween = create_tween().set_parallel(true)
	swing_tween.tween_property(weapon_pivot, "scale", Vector2(0.88, 1.2) * (special_attack_scale if is_special else 1.0), draw_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(weapon_pivot, "position", mouse_dir * 2.0, draw_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await swing_tween.finished
	if not is_instance_valid(self):
		return

	# 2. Bắn mũi tên ra từ ngay đầu cung
	_spawn_arrow_projectile(mouse_dir, is_special, t_cfg)

	# Bật nảy dây cung khi bắn
	swing_tween = create_tween().set_parallel(true)
	swing_tween.tween_property(weapon_pivot, "scale", Vector2(1.15, 0.85) * (special_attack_scale if is_special else 1.0), release_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(weapon_pivot, "position", mouse_dir * 6.0, release_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await swing_tween.finished
	if not is_instance_valid(self):
		return

	is_special_attacking = false
	is_attacking = false

	# 3. Thu cung mờ dần
	swing_tween = create_tween()
	swing_tween.tween_property(weapon_pivot, "modulate:a", 0.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await swing_tween.finished
	if not is_instance_valid(self):
		return

	if not is_attacking:
		if weapon_sprite:
			weapon_sprite.position = Vector2(17, 3)
			weapon_sprite.modulate = Color.WHITE
			weapon_sprite.rotation = deg_to_rad(45.0)
		weapon_pivot.modulate.a = 1.0
		weapon_pivot.scale = Vector2.ONE
		weapon_pivot.position = Vector2.ZERO
		weapon_pivot.hide()

func _spawn_arrow_projectile(dir: Vector2, is_special: bool, t_cfg: Dictionary) -> void:
	var arrow_scene := load("res://scenes/objects/arrow_projectile.tscn") as PackedScene
	if not arrow_scene:
		return
	var count := 1 if not is_special else 3
	var dmg: int = current_attack_damage
	var tint: Color = t_cfg.get("core_col", Color.WHITE)

	for i in range(count):
		var arrow = arrow_scene.instantiate()
		var fire_dir := dir
		if count > 1:
			var spread_angle := deg_to_rad((i - 1) * 16.0)
			fire_dir = dir.rotated(spread_angle)
		arrow.global_position = global_position + dir * 6.0
		get_parent().add_child(arrow)
		if arrow.has_method("setup"):
			arrow.setup(fire_dir, 550.0 if not is_special else 650.0, dmg, tint, self)

func _execute_staff_attack(is_special: bool, mouse_dir: Vector2, mouse_angle: float, weapon_sprite: Sprite2D) -> void:
	var speed_mult: float = 1.0
	var t_cfg: Dictionary = {}
	if active_swing_tool_id != "" and TOOL_CONFIG.has(active_swing_tool_id):
		t_cfg = TOOL_CONFIG[active_swing_tool_id]
		speed_mult = float(t_cfg.get("swing_speed_mult", 1.0))

	var cast_time: float = (0.14 if not is_special else 0.20) / speed_mult
	var recover_time: float = 0.09 / speed_mult

	# Cầm trượng gọn gần cơ thể
	weapon_pivot.rotation = mouse_angle - deg_to_rad(25.0)
	weapon_pivot.position = mouse_dir * 4.0
	weapon_pivot.scale = Vector2.ONE * (special_attack_scale if is_special else 1.0)
	if weapon_sprite:
		weapon_sprite.position = Vector2(4, 0)
		weapon_sprite.rotation = deg_to_rad(35.0)
		weapon_sprite.modulate = t_cfg.get("glow_col", Color.CYAN)

	# 1. Giơ trượng lên tích năng lượng
	swing_tween = create_tween().set_parallel(true)
	swing_tween.tween_property(weapon_pivot, "rotation", mouse_angle, cast_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(weapon_pivot, "scale", Vector2.ONE * (special_attack_scale * 1.18 if is_special else 1.1), cast_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if anim:
		var body_tw := create_tween()
		body_tw.tween_property(anim, "scale", Vector2(0.94, 1.08), cast_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		body_tw.tween_property(anim, "scale", Vector2.ONE, recover_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await swing_tween.finished
	if not is_instance_valid(self):
		return

	# 2. Bắn quả cầu ma pháp (Magic Orb) từ đầu trượng
	_spawn_magic_orb_projectile(mouse_dir, is_special, t_cfg)

	# 3. Thu trượng
	is_special_attacking = false
	is_attacking = false

	swing_tween = create_tween().set_parallel(true)
	swing_tween.tween_property(weapon_pivot, "scale", Vector2.ONE, recover_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing_tween.tween_property(weapon_pivot, "modulate:a", 0.0, recover_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await swing_tween.finished
	if not is_instance_valid(self):
		return

	if not is_attacking:
		if weapon_sprite:
			weapon_sprite.position = Vector2(17, 3)
			weapon_sprite.modulate = Color.WHITE
			weapon_sprite.rotation = deg_to_rad(45.0)
		weapon_pivot.modulate.a = 1.0
		weapon_pivot.scale = Vector2.ONE
		weapon_pivot.position = Vector2.ZERO
		weapon_pivot.hide()

func _spawn_magic_orb_projectile(dir: Vector2, is_special: bool, t_cfg: Dictionary) -> void:
	var orb_scene := load("res://scenes/objects/magic_orb_projectile.tscn") as PackedScene
	if not orb_scene:
		return
	var count := 1 if not is_special else 3
	var dmg: int = current_attack_damage
	var tint: Color = t_cfg.get("glow_col", Color(0.85, 0.4, 1.0, 1.0))

	for i in range(count):
		var orb = orb_scene.instantiate()
		var fire_dir := dir
		if count > 1:
			var spread_angle := deg_to_rad((i - 1) * 20.0)
			fire_dir = dir.rotated(spread_angle)
		orb.global_position = global_position + dir * 8.0
		get_parent().add_child(orb)
		if orb.has_method("setup"):
			orb.setup(fire_dir, 230.0 if not is_special else 290.0, dmg, tint, self)

func _on_weapon_hitbox_body_entered(body: Node) -> void:
	_apply_weapon_hit(body)

func _on_weapon_hitbox_area_entered(area: Area2D) -> void:
	if area.get_parent() and area.get_parent() != self:
		_apply_weapon_hit(area.get_parent())

func _apply_weapon_hit(target: Node) -> void:
	if not is_attacking or not is_instance_valid(target) or target == self:
		return
	if target in hit_targets:
		return
	if target.has_method("hit_by_tool"):
		hit_targets.append(target)
		target.hit_by_tool(active_swing_tool_id, global_position)
		return
	if target.has_method("take_damage"):
		hit_targets.append(target)
		var damage_dealt: int = current_attack_damage
		if active_swing_tool_id != "" and TOOL_CONFIG.has(active_swing_tool_id):
			var is_harvest_tool: bool = ("axe" in active_swing_tool_id or "pickaxe" in active_swing_tool_id)
			if is_harvest_tool:
				damage_dealt = 1
		target.take_damage(damage_dealt, global_position, current_attack_knockback)

func start_roll(dir: Vector2) -> void:
	is_rolling = true
	current_mana = maxf(0.0, current_mana - roll_mana_cost)
	if SceneManager:
		SceneManager.saved_player_mana = current_mana
	_update_mana_ui()

	var roll_dir := dir

	if roll_dir == Vector2.ZERO:
		match last_direction:
			"up": roll_dir = Vector2.UP
			"down": roll_dir = Vector2.DOWN
			"left": roll_dir = Vector2.LEFT
			"right": roll_dir = Vector2.RIGHT

	if roll_dir.x < 0 or (roll_dir.x == 0 and last_direction == "left"):
		anim.flip_h = true
	else:
		anim.flip_h = false

	if anim.sprite_frames.has_animation("rolling"):
		anim.play("rolling")

	velocity = roll_dir * roll_speed

	await get_tree().create_timer(roll_duration).timeout
	if is_instance_valid(self):
		is_rolling = false
		velocity = Vector2.ZERO

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback_force: float = 140.0) -> void:
	if is_rolling or not health_component or health_component.is_invincible:
		return
	if fishing_state != FishingState.NONE:
		_cancel_fishing()

	var final_damage: int = amount
	if SceneManager and SceneManager.get("saved_equipment_data"):
		var total_def: int = 0
		for slot_k in SceneManager.saved_equipment_data.keys():
			var eq = SceneManager.saved_equipment_data[slot_k]
			if typeof(eq) == TYPE_DICTIONARY and eq != null:
				total_def += int(eq.get("defense", 0))
		final_damage = maxi(1, amount - total_def)

	if source_pos != Vector2.ZERO:
		var dir := (global_position - source_pos).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.DOWN
		knockback_velocity = dir * knockback_force

	if anim:
		anim.modulate = Color(2.5, 0.35, 0.35, 1.0)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", Color.WHITE, 0.25)

	health_component.take_damage(final_damage)

func _on_health_changed(current: int, maximum: int) -> void:
	if SceneManager:
		SceneManager.saved_player_health = current
	if hp_bar_fill and maximum > 0:
		var ratio := clampf(float(current) / float(maximum), 0.0, 1.0)
		hp_bar_fill.size.x = 140.0 * ratio
	if hp_label:
		hp_label.text = "HP: %d / %d" % [current, maximum]

func _on_player_died() -> void:
	# Khi hết máu, hồi phục lại đầy máu và đưa về điểm xuất phát của map hiện tại
	health_component.reset_health()
	current_mana = max_mana
	if SceneManager:
		SceneManager.saved_player_mana = current_mana
	_update_mana_ui()
	global_position = initial_spawn_position
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	special_cooldown_timer = 0.0
	_update_special_cooldown_ui()

func _update_mana_ui() -> void:
	if mana_bar_fill and max_mana > 0.0:
		var ratio := clampf(current_mana / max_mana, 0.0, 1.0)
		mana_bar_fill.size.x = 140.0 * ratio
	if mana_label:
		mana_label.text = "Mana: %d / %d" % [int(current_mana), int(max_mana)]

func _update_exp_ui() -> void:
	if exp_bar_fill:
		if level >= 18:
			exp_bar_fill.size.x = 140.0
		elif max_exp > 0:
			var ratio := clampf(float(current_exp) / float(max_exp), 0.0, 1.0)
			exp_bar_fill.size.x = 140.0 * ratio
		else:
			exp_bar_fill.size.x = 0.0

	if exp_label:
		if level >= 18:
			exp_label.text = "Lv.18 (MAX LEVEL)"
		else:
			exp_label.text = "Lv.%d: %d / %d EXP" % [level, current_exp, max_exp]

func _on_scene_manager_exp_changed(new_exp: int, req_exp: int, new_level: int) -> void:
	current_exp = new_exp
	max_exp = req_exp
	level = new_level
	_update_exp_ui()
	var inv = get_tree().get_first_node_in_group("inventory")
	if inv and inv.has_method("update_stats_display"):
		inv.update_stats_display()

func _on_scene_manager_level_up(new_level: int) -> void:
	level = new_level
	# Mỗi lần lên cấp tăng 50 HP tối đa và 50 Mana tối đa
	max_health = 100 + (level - 1) * 50
	max_mana = 100.0 + float((level - 1) * 50)
	if health_component:
		health_component.max_health = max_health
		health_component.current_health = max_health # Hồi đầy máu khi lên cấp
		_on_health_changed(health_component.current_health, health_component.max_health)
	current_mana = max_mana
	if SceneManager:
		SceneManager.saved_player_mana = current_mana
		SceneManager.saved_player_health = max_health
	_update_mana_ui()
	_update_exp_ui()

	# Hiển thị thông báo bay lên đầu chúc mừng lên cấp
	_show_floating_level_up_text("LEVEL UP! Lv.%d (+50 HP & Mana)" % level)

	var inv = get_tree().get_first_node_in_group("inventory")
	if inv and inv.has_method("update_stats_display"):
		inv.update_stats_display()

func _show_floating_level_up_text(text_msg: String) -> void:
	if not level_up_hud_label:
		return
	level_up_hud_label.text = text_msg
	level_up_hud_label.visible = true
	level_up_hud_label.modulate.a = 1.0
	level_up_hud_label.position = Vector2(16, 96)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(level_up_hud_label, "position:y", 90.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(level_up_hud_label, "modulate:a", 0.0, 1.8).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(level_up_hud_label):
		level_up_hud_label.visible = false

func _flash_mana_warning() -> void:
	if not mana_label:
		return
	mana_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	var tween := create_tween()
	tween.tween_property(mana_label, "modulate", Color.WHITE, 0.25)

func _update_special_cooldown_ui() -> void:
	if not special_cd_bar_fill or not special_cd_label:
		return

	if special_cooldown_timer <= 0.0:
		special_cd_bar_fill.size.x = 140.0
		special_cd_bar_fill.color = Color(0.95, 0.72, 0.18, 1.0)
		special_cd_label.text = "Chuột Phải: SẴN SÀNG"
	else:
		var ratio := 1.0 - clampf(special_cooldown_timer / maxf(special_attack_cooldown, 0.01), 0.0, 1.0)
		special_cd_bar_fill.size.x = 140.0 * ratio
		special_cd_bar_fill.color = Color(0.45, 0.45, 0.55, 0.9)
		special_cd_label.text = "Hồi chiêu: %.1fs" % special_cooldown_timer

func _flash_cooldown_warning() -> void:
	if not special_cd_label:
		return
	special_cd_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
	var tween := create_tween()
	tween.tween_property(special_cd_label, "modulate", Color.WHITE, 0.25)

func _update_slash_trail(delta: float) -> void:
	var max_life := 0.14 if trail_is_special else 0.095
	var changed := false

	# Giảm thời gian sống của các điểm trên vệt kiếm cũ
	for i in range(slash_trail.size() - 1, -1, -1):
		slash_trail[i]["age"] += delta
		if slash_trail[i]["age"] >= max_life:
			slash_trail.remove_at(i)
		changed = true

	# Ghi nhận góc kiếm hiện tại và nội suy thêm các điểm trung gian để đường cong mượt tuyệt đối
	if is_recording_trail and weapon_pivot:
		var cur_angle := weapon_pivot.rotation
		var cur_scale := weapon_pivot.scale.x
		if slash_trail.size() > 0:
			var prev_angle: float = slash_trail[slash_trail.size() - 1]["angle"]
			var prev_scale: float = slash_trail[slash_trail.size() - 1]["scale"]
			var diff := cur_angle - prev_angle
			var steps := clampi(int(abs(diff) / deg_to_rad(6.0)), 1, 8)
			for s in range(1, steps + 1):
				var t := float(s) / float(steps)
				slash_trail.append({
					"angle": lerpf(prev_angle, cur_angle, t),
					"scale": lerpf(prev_scale, cur_scale, t),
					"age": delta * (1.0 - t)
				})
		else:
			slash_trail.append({
				"angle": cur_angle,
				"scale": cur_scale,
				"age": 0.0
			})
		changed = true

	if changed:
		queue_redraw()

func _draw() -> void:
	# 1. Vẽ vệt kiếm bán nguyệt động (Dynamic Crescent Slash Ribbon) mượt theo lưỡi kiếm
	if slash_trail.size() >= 2:
		var max_life := 0.14 if trail_is_special else 0.095
		var count := slash_trail.size()
		for i in range(count - 1):
			var p0: Dictionary = slash_trail[i]
			var p1: Dictionary = slash_trail[i + 1]
			var t0 := float(i) / float(count - 1)
			var t1 := float(i + 1) / float(count - 1)

			var life0 := clampf(1.0 - (float(p0["age"]) / max_life), 0.0, 1.0)
			var life1 := clampf(1.0 - (float(p1["age"]) / max_life), 0.0, 1.0)

			# Độ dày vệt kiếm thon nhọn ở đuôi và phình to ở đầu lưỡi kiếm
			var profile0 := sin(t0 * PI * 0.82) * life0
			var profile1 := sin(t1 * PI * 0.82) * life1

			var outer_r0 := 25.0 * float(p0["scale"])
			var outer_r1 := 25.0 * float(p1["scale"])
			var thickness0 := (13.5 if trail_is_special else 9.0) * profile0 * float(p0["scale"])
			var thickness1 := (13.5 if trail_is_special else 9.0) * profile1 * float(p1["scale"])

			var dir0 := Vector2.RIGHT.rotated(float(p0["angle"]))
			var dir1 := Vector2.RIGHT.rotated(float(p1["angle"]))

			var out0 := dir0 * outer_r0
			var out1 := dir1 * outer_r1
			var in0 := dir0 * maxf(4.0, outer_r0 - thickness0)
			var in1 := dir1 * maxf(4.0, outer_r1 - thickness1)

			var alpha := (life0 + life1) * 0.5 * t1
			var glow_col := Color(1.0, 0.42, 0.12, alpha * 0.65) if trail_is_special else Color(0.55, 0.88, 1.0, alpha * 0.48)
			var core_col := Color(1.0, 0.94, 0.45, alpha * 0.95) if trail_is_special else Color(1.0, 1.0, 1.0, alpha * 0.9)
			if not trail_is_special and active_swing_tool_id != "" and TOOL_CONFIG.has(active_swing_tool_id):
				var t_cfg: Dictionary = TOOL_CONFIG[active_swing_tool_id]
				var base_glow: Color = t_cfg["glow_col"]
				var base_core: Color = t_cfg["core_col"]
				glow_col = Color(base_glow.r, base_glow.g, base_glow.b, alpha * 0.62)
				core_col = Color(base_core.r, base_core.g, base_core.b, alpha * 0.92)

			# Lớp hào quang bên ngoài
			draw_colored_polygon(PackedVector2Array([out0, out1, in1, in0]), glow_col)

			# Lõi sáng sắc nét ở rìa lưỡi kiếm
			var core_in0 := dir0 * maxf(4.0, outer_r0 - thickness0 * 0.48)
			var core_in1 := dir1 * maxf(4.0, outer_r1 - thickness1 * 0.48)
			draw_colored_polygon(PackedVector2Array([out0, out1, core_in1, core_in0]), core_col)

	# 2. Vẽ vòng cung sóng kiếm lan tỏa khi tung đòn Chém Đặc Biệt (Chuột Phải)
	if special_wave_progress >= 0.0:
		var radius := lerpf(18.0, 48.0, special_wave_progress)
		var alpha := 1.0 - special_wave_progress
		var start_ang := special_wave_angle - deg_to_rad(80)
		var end_ang := special_wave_angle + deg_to_rad(80)
		draw_arc(Vector2.ZERO, radius, start_ang, end_ang, 32, Color(1.0, 0.82, 0.25, alpha * 0.9), 4.0)
		draw_arc(Vector2.ZERO, radius - 4.5, start_ang, end_ang, 32, Color(1.0, 0.35, 0.15, alpha * 0.65), 2.5)

	# 3. Vẽ dây câu và phao câu cá
	if fishing_state in [FishingState.CASTING, FishingState.WAITING, FishingState.BITE]:
		_draw_fishing_line_and_bobber()

# ----------------- HỆ THỐNG CÂU CÁ ĐƠN GIẢN -----------------
func _setup_fishing_visuals() -> void:
	var tools_tex := load("res://Content T1/Tilesheet/Tools1_tilet.png") as Texture2D
	held_rod_sprite = Sprite2D.new()
	held_rod_sprite.name = "HeldRodSprite"
	held_rod_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tools_tex:
		var atlas := AtlasTexture.new()
		atlas.atlas = tools_tex
		atlas.region = Rect2(0, 144, 16, 16)
		held_rod_sprite.texture = atlas
	held_rod_sprite.z_index = 6
	held_rod_sprite.visible = false
	add_child(held_rod_sprite)

	caught_fish_sprite = Sprite2D.new()
	caught_fish_sprite.name = "CaughtFishSprite"
	caught_fish_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	caught_fish_sprite.position = Vector2(0, -24)
	caught_fish_sprite.z_index = 15
	caught_fish_sprite.visible = false
	add_child(caught_fish_sprite)

	fishing_status_label = Label.new()
	fishing_status_label.name = "FishingStatusLabel"
	fishing_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fishing_status_label.position = Vector2(-90, -38)
	fishing_status_label.size = Vector2(180, 24)
	fishing_status_label.z_index = 20
	fishing_status_label.add_theme_font_size_override("font_size", 10)
	fishing_status_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.75, 1.0))
	fishing_status_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 1.0))
	fishing_status_label.add_theme_constant_override("outline_size", 3)
	fishing_status_label.visible = false
	add_child(fishing_status_label)

func _get_equipped_tool_id() -> String:
	var inv = get_tree().get_first_node_in_group("inventory")
	if inv and inv.has_method("get_selected_tool_id"):
		return inv.get_selected_tool_id()
	return ""

func _try_harvest_resources_with_tool(tool_id: String, swing_dir_vec: Vector2) -> void:
	var strike_pos := global_position + swing_dir_vec * 20.0
	var is_axe := "axe" in tool_id and not ("pickaxe" in tool_id)
	var is_pickaxe := "pickaxe" in tool_id

	# Kiểm tra chặt cây thông (choppable_tree) trong tầm vung rìu/công cụ
	for tree in get_tree().get_nodes_in_group("choppable_tree"):
		if not is_instance_valid(tree) or tree in hit_targets:
			continue
		if tree.get("is_chopped") == true:
			continue
		var tree_pos := (tree as Node2D).global_position
		if tree_pos.distance_to(strike_pos) <= 34.0 or tree_pos.distance_to(global_position) <= 38.0:
			var to_tree := (tree_pos - global_position).normalized()
			if swing_dir_vec.dot(to_tree) >= -0.25 or tree_pos.distance_to(global_position) <= 24.0:
				if tree.has_method("hit_by_tool"):
					hit_targets.append(tree)
					tree.hit_by_tool(tool_id, global_position)
					break

	# Kiểm tra đập đá tảng (mineable_rock) trong tầm vung cuốc/công cụ
	for rock in get_tree().get_nodes_in_group("mineable_rock"):
		if not is_instance_valid(rock) or rock in hit_targets:
			continue
		if rock.get("is_mined") == true:
			continue
		var rock_pos := (rock as Node2D).global_position
		if rock_pos.distance_to(strike_pos) <= 34.0 or rock_pos.distance_to(global_position) <= 38.0:
			var to_rock := (rock_pos - global_position).normalized()
			if swing_dir_vec.dot(to_rock) >= -0.25 or rock_pos.distance_to(global_position) <= 24.0:
				if rock.has_method("hit_by_tool"):
					hit_targets.append(rock)
					rock.hit_by_tool(tool_id, global_position)
					break

	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv or not inv.has_method("add_item"):
		return

	for node in get_tree().get_nodes_in_group("world_pickup_item"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var n_id: String = str(node.get("item_id")) if "item_id" in node else ""
		if not (n_id in ["branch", "stone", "copper_ore", "iron_ore", "gold_ore", "amethyst_gem"]):
			continue
		var dist := (node as Node2D).global_position.distance_to(strike_pos)
		if dist > 32.0 and (node as Node2D).global_position.distance_to(global_position) > 36.0:
			continue

		var can_harvest := false
		if n_id == "branch" and (is_axe or is_pickaxe):
			can_harvest = true
		elif n_id in ["stone", "copper_ore", "iron_ore", "gold_ore", "amethyst_gem"] and (is_pickaxe or is_axe):
			can_harvest = true

		if can_harvest:
			var icon_tex: Texture2D = node.get("item_icon")
			if not icon_tex and node.has_node("Sprite2D"):
				var spr: Sprite2D = node.get_node("Sprite2D")
				if spr and spr.region_enabled:
					var atl := AtlasTexture.new()
					atl.atlas = spr.texture
					atl.region = spr.region_rect
					icon_tex = atl
				elif spr:
					icon_tex = spr.texture
			var scene_ref: PackedScene = load(node.scene_file_path) as PackedScene if node.scene_file_path != "" else null
			var disp_name: String = str(node.get("item_name")) if "item_name" in node else n_id
			if inv.add_item(icon_tex, scene_ref, n_id, disp_name):
				_show_fishing_message("+1 %s!" % disp_name, Color(0.65, 1.0, 0.55, 1.0), 0.9)
				node.queue_free()
				break

func _is_holding_fishing_rod() -> bool:
	var inv = get_tree().get_first_node_in_group("inventory")
	if inv and inv.has_method("is_holding_fishing_rod"):
		return inv.is_holding_fishing_rod()
	return false

func _handle_fishing_action() -> void:
	if is_attacking or is_rolling:
		return

	if fishing_state == FishingState.NONE:
		_try_cast_fishing_rod()
	elif fishing_state == FishingState.BITE:
		_catch_fish_success()
	elif fishing_state in [FishingState.CASTING, FishingState.WAITING]:
		_cancel_fishing("Too early!")

func _try_cast_fishing_rod() -> void:
	var local_mouse := get_local_mouse_position()
	if local_mouse.length() < 4.0:
		local_mouse = Vector2.DOWN * 48.0

	# Xoay hướng nhân vật về phía quăng câu
	if abs(local_mouse.x) > abs(local_mouse.y):
		if local_mouse.x < 0:
			anim.flip_h = true
			last_direction = "left"
		else:
			anim.flip_h = false
			last_direction = "right"
		anim.play("stand")
	else:
		anim.flip_h = false
		if local_mouse.y > 0:
			last_direction = "down"
			anim.play("stand")
		else:
			last_direction = "up"
			anim.play("stand1")

	var water_world_pos := _find_water_target(local_mouse)
	if water_world_pos == Vector2.INF:
		_show_fishing_message("Stand near water to fish!", Color(1.0, 0.55, 0.45, 1.0), 1.4)
		return

	velocity = Vector2.ZERO
	fishing_state = FishingState.CASTING
	fishing_timer = 0.22
	fishing_time_elapsed = 0.0

	bobber_target_local = to_local(water_world_pos)
	_update_rod_pose(bobber_target_local)
	bobber_current_local = rod_tip_local

	_show_fishing_message("Casting...", Color(0.75, 0.92, 1.0, 1.0))
	queue_redraw()

func _update_rod_pose(target_local: Vector2) -> void:
	if not held_rod_sprite:
		return
	held_rod_sprite.visible = true
	var dir := target_local.normalized()
	held_rod_sprite.position = dir * 9.0 + Vector2(0, -2)
	held_rod_sprite.flip_h = (dir.x < 0)
	held_rod_sprite.rotation = dir.angle() * 0.35 if dir.x >= 0 else (PI - dir.angle()) * -0.35
	rod_tip_local = held_rod_sprite.position + dir * 8.0 + Vector2(0, -4)

func _find_water_target(local_mouse: Vector2) -> Vector2:
	var dir := local_mouse.normalized()
	var click_dist := clampf(local_mouse.length(), 28.0, 110.0)
	var preferred_world := global_position + dir * click_dist
	if _is_water_at_world_pos(preferred_world):
		return preferred_world

	# Tìm các điểm dọc theo hướng chuột trỏ tới (từ gần ra xa)
	var distances: Array[float] = [32.0, 48.0, 64.0, 80.0, 96.0, 112.0]
	for d: float in distances:
		var test_pos: Vector2 = global_position + dir * d
		if _is_water_at_world_pos(test_pos):
			return test_pos

	# Quét góc lân cận nếu người chơi bấm hơi lệch mép nước
	var angles: Array[float] = [-25.0, 25.0, -50.0, 50.0]
	var near_distances: Array[float] = [40.0, 64.0, 88.0]
	for angle_deg: float in angles:
		var rot_dir: Vector2 = dir.rotated(deg_to_rad(angle_deg))
		for d: float in near_distances:
			var test_pos: Vector2 = global_position + rot_dir * d
			if _is_water_at_world_pos(test_pos):
				return test_pos

	return Vector2.INF

func _is_water_at_world_pos(world_pos: Vector2) -> bool:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return false

	# 1. Kiểm tra lớp nước có shader water_caustics (ví dụ: TileMapLayer/TileMapLayer trong farm house.tscn)
	var water_overlay := scene_root.get_node_or_null("TileMapLayer/TileMapLayer") as TileMapLayer
	if water_overlay:
		var cell := water_overlay.local_to_map(water_overlay.to_local(world_pos))
		if water_overlay.get_cell_source_id(cell) != -1:
			return true

	# 2. Kiểm tra TileMapLayer gốc có dùng source_id == 2 (Water green_tilet.png) không
	var base_layer := scene_root.get_node_or_null("TileMapLayer") as TileMapLayer
	if base_layer:
		var cell := base_layer.local_to_map(base_layer.to_local(world_pos))
		if base_layer.get_cell_source_id(cell) == 2:
			return true

	return false

func _update_fishing(delta: float) -> void:
	if fishing_state == FishingState.NONE:
		if held_rod_sprite:
			held_rod_sprite.visible = _is_holding_fishing_rod() and not is_attacking and not is_rolling
			if held_rod_sprite.visible:
				var side := -1.0 if anim.flip_h else 1.0
				held_rod_sprite.position = Vector2(7.0 * side, 0.0)
				held_rod_sprite.flip_h = anim.flip_h
				held_rod_sprite.rotation = 0.0
		return

	if not _is_holding_fishing_rod() and fishing_state != FishingState.CAUGHT:
		_cancel_fishing()
		return

	fishing_time_elapsed += delta
	fishing_timer -= delta

	match fishing_state:
		FishingState.CASTING:
			var t := 1.0 - clampf(fishing_timer / 0.22, 0.0, 1.0)
			bobber_current_local = rod_tip_local.lerp(bobber_target_local, t) + Vector2(0, -sin(t * PI) * 14.0)
			if fishing_timer <= 0.0:
				bobber_current_local = bobber_target_local
				fishing_state = FishingState.WAITING
				fishing_timer = randf_range(1.5, 3.0)
				_show_fishing_message("Fishing...", Color(0.85, 0.95, 1.0, 1.0))
			queue_redraw()

		FishingState.WAITING:
			bobber_current_local = bobber_target_local + Vector2(0, sin(fishing_time_elapsed * 4.5) * 1.5)
			if fishing_timer <= 0.0:
				fishing_state = FishingState.BITE
				fishing_timer = 1.35
				_show_fishing_message("! BITE ! (Left Click)", Color(1.0, 0.9, 0.2, 1.0))
			queue_redraw()

		FishingState.BITE:
			bobber_current_local = bobber_target_local + Vector2(randf_range(-1.5, 1.5), sin(fishing_time_elapsed * 26.0) * 3.5 + 2.0)
			if fishing_timer <= 0.0:
				_cancel_fishing("Fish got away...")
			queue_redraw()

		FishingState.CAUGHT:
			if fishing_timer <= 0.0:
				fishing_state = FishingState.NONE
				if caught_fish_sprite:
					caught_fish_sprite.visible = false
				if fishing_status_label:
					fishing_status_label.visible = false
				queue_redraw()

func _catch_fish_success() -> void:
	var fish_info: Dictionary = FISH_POOL[randi() % FISH_POOL.size()]
	var fish_tex_sheet := load("res://Content T1/Loose/Fish-food.png") as Texture2D
	var fish_scene := load("res://scenes/objects/fish_item.tscn") as PackedScene

	var fish_icon := AtlasTexture.new()
	fish_icon.atlas = fish_tex_sheet
	fish_icon.region = fish_info["region"]

	var inv = get_tree().get_first_node_in_group("inventory")
	var added := false
	if inv and inv.has_method("add_item"):
		added = inv.add_item(fish_icon, fish_scene, fish_info["id"], fish_info["name"])

	if added:
		_show_fishing_message("Caught: %s!" % fish_info["name"], Color(0.45, 1.0, 0.55, 1.0), 1.6)
	else:
		_show_fishing_message("Inventory Full!", Color(1.0, 0.45, 0.4, 1.0), 1.6)

	if caught_fish_sprite:
		caught_fish_sprite.texture = fish_icon
		caught_fish_sprite.visible = true
		caught_fish_sprite.position = bobber_target_local
		caught_fish_sprite.scale = Vector2(0.5, 0.5)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(caught_fish_sprite, "position", Vector2(0, -24), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(caught_fish_sprite, "scale", Vector2(1.15, 1.15), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	fishing_state = FishingState.CAUGHT
	fishing_timer = 1.2
	queue_redraw()

func _cancel_fishing(msg: String = "") -> void:
	fishing_state = FishingState.NONE
	if caught_fish_sprite:
		caught_fish_sprite.visible = false
	if msg != "":
		_show_fishing_message(msg, Color(1.0, 0.65, 0.45, 1.0), 1.1)
	else:
		if fishing_status_label:
			fishing_status_label.visible = false
	queue_redraw()

func _show_fishing_message(text: String, color: Color = Color.WHITE, auto_hide_delay: float = 0.0) -> void:
	if not fishing_status_label:
		return
	fishing_status_label.text = text
	fishing_status_label.add_theme_color_override("font_color", color)
	fishing_status_label.visible = true
	if auto_hide_delay > 0.0:
		var current_text := text
		get_tree().create_timer(auto_hide_delay).timeout.connect(func():
			if is_instance_valid(fishing_status_label) and fishing_status_label.text == current_text and fishing_state == FishingState.NONE:
				fishing_status_label.visible = false
		)

func _draw_fishing_line_and_bobber() -> void:
	# Vẽ đường dây câu hơi võng tự nhiên
	var segments := 12
	var prev_pt := rod_tip_local
	var sag_amount := 6.0 if fishing_state != FishingState.BITE else 1.5
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var pt := rod_tip_local.lerp(bobber_current_local, t)
		pt.y += sin(t * PI) * sag_amount
		draw_line(prev_pt, pt, Color(0.92, 0.95, 1.0, 0.85), 1.2)
		prev_pt = pt

	# Vẽ vòng gợn nước quanh phao
	var ripple_r := 4.5 + sin(fishing_time_elapsed * 6.0) * 1.5
	if fishing_state == FishingState.BITE:
		ripple_r = 6.5 + fmod(fishing_time_elapsed * 18.0, 5.0)
	draw_arc(bobber_current_local + Vector2(0, 2), ripple_r, 0.0, TAU, 16, Color(0.85, 0.96, 1.0, 0.55), 1.0)

	# Vẽ phao câu đỏ - trắng
	draw_circle(bobber_current_local + Vector2(0, 1), 3.2, Color(0.9, 0.2, 0.2, 1.0))
	draw_circle(bobber_current_local + Vector2(0, -1), 2.4, Color(0.98, 0.98, 0.98, 1.0))
