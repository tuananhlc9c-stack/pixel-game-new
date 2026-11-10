extends StaticBody2D

# 4 loại quặng khoáng sản từ file Content T1/New/farm233.png (64x64):
# Lần lượt theo thứ tự: Đồng (copper), Sắt (iron), Vàng (gold), Đá tím (amethyst)
# Máu đập (HP) lần lượt cao hơn và đều cao hơn đá thường (đá thường max_mine_hp = 12):
# - Đồng (copper_ore): HP = 18, 30s hồi
# - Sắt (iron_ore): HP = 24, 35s hồi
# - Vàng (gold_ore): HP = 32, 40s hồi
# - Đá tím (amethyst_ore): HP = 40, 45s hồi

@export_enum("copper", "iron", "gold", "amethyst") var ore_type: String = "copper"

const ORE_CONFIG: Dictionary = {
	"copper": {
		"name": "Copper Ore",
		"display_name": "Copper Ore",
		"max_hp": 18,
		"drop_item_id": "copper_ore",
		"drop_item_name": "Copper Ore",
		"drop_scene": "res://scenes/objects/copper_ore_item.tscn",
		"drop_count": 3,
		"respawn_time": 30.0,
		"sprite_region": Rect2(0, 16, 16, 16),
		"spark_color": Color(0.9, 0.52, 0.28, 1.0),
		"bar_color": Color(0.95, 0.55, 0.25, 1.0)
	},
	"iron": {
		"name": "Iron Ore",
		"display_name": "Iron Ore",
		"max_hp": 24,
		"drop_item_id": "iron_ore",
		"drop_item_name": "Iron Ore",
		"drop_scene": "res://scenes/objects/iron_ore_item.tscn",
		"drop_count": 3,
		"respawn_time": 35.0,
		"sprite_region": Rect2(16, 16, 16, 16),
		"spark_color": Color(0.78, 0.76, 0.72, 1.0),
		"bar_color": Color(0.75, 0.82, 0.9, 1.0)
	},
	"gold": {
		"name": "Gold Ore",
		"display_name": "Gold Ore",
		"max_hp": 32,
		"drop_item_id": "gold_ore",
		"drop_item_name": "Gold Ore",
		"drop_scene": "res://scenes/objects/gold_ore_item.tscn",
		"drop_count": 3,
		"respawn_time": 40.0,
		"sprite_region": Rect2(32, 16, 16, 16),
		"spark_color": Color(1.0, 0.85, 0.2, 1.0),
		"bar_color": Color(1.0, 0.85, 0.2, 1.0)
	},
	"amethyst": {
		"name": "Amethyst",
		"display_name": "Amethyst Cluster",
		"max_hp": 40,
		"drop_item_id": "amethyst_gem",
		"drop_item_name": "Amethyst",
		"drop_scene": "res://scenes/objects/amethyst_gem_item.tscn",
		"drop_count": 3,
		"respawn_time": 45.0,
		"sprite_region": Rect2(48, 16, 16, 16),
		"spark_color": Color(0.85, 0.35, 1.0, 1.0),
		"bar_color": Color(0.82, 0.35, 0.95, 1.0)
	}
}

const PICKAXE_MINE_POWER: Dictionary = {
	"wood_pickaxe": 2,
	"stone_pickaxe": 3,
	"iron_pickaxe": 6
}

var current_mine_hp: int = 18
var max_mine_hp: int = 18
var is_mined: bool = false
var respawn_remaining: float = 0.0

@onready var rock_sprite: Sprite2D = $RockSprite if has_node("RockSprite") else null
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

var hp_bar_bg: ColorRect = null
var hp_bar_fill: ColorRect = null
var hide_bar_timer: float = 0.0

func _ready() -> void:
	add_to_group("mineable_rock")
	y_sort_enabled = true
	_apply_ore_type_config()
	_setup_mine_progress_bar()
	_restore_respawn_state_if_mined()

func _apply_ore_type_config() -> void:
	if not ORE_CONFIG.has(ore_type):
		ore_type = "copper"
	var cfg: Dictionary = ORE_CONFIG[ore_type]
	max_mine_hp = int(cfg.get("max_hp", 18))
	current_mine_hp = max_mine_hp
	if rock_sprite:
		rock_sprite.region_rect = cfg.get("sprite_region", Rect2(0, 0, 32, 32))

func _process(delta: float) -> void:
	if hide_bar_timer > 0.0:
		hide_bar_timer -= delta
		if hide_bar_timer <= 0.0 and hp_bar_bg:
			hp_bar_bg.visible = false

	if is_mined and respawn_remaining > 0.0:
		respawn_remaining -= delta
		if respawn_remaining <= 0.0:
			_respawn_rock()

func _get_rock_key() -> String:
	var scene_path := ""
	if get_tree() and get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	return "ore_node::%s::%s::%d_%d" % [scene_path, name, int(round(global_position.x)), int(round(global_position.y))]

func _restore_respawn_state_if_mined() -> void:
	if not SceneManager:
		return
	var key := _get_rock_key()
	if not SceneManager.chopped_trees_respawn_time.has(key):
		return

	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var target_sec: float = float(SceneManager.chopped_trees_respawn_time[key])
	var remaining := target_sec - now_sec

	if remaining > 0.0:
		is_mined = true
		current_mine_hp = 0
		respawn_remaining = remaining
		if col_shape:
			col_shape.set_deferred("disabled", true)
		if rock_sprite:
			rock_sprite.visible = false
	else:
		SceneManager.chopped_trees_respawn_time.erase(key)

func _setup_mine_progress_bar() -> void:
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = Color(0.12, 0.12, 0.14, 0.85)
	hp_bar_bg.position = Vector2(-15, -34)
	hp_bar_bg.size = Vector2(30, 5)
	hp_bar_bg.z_index = 12
	hp_bar_bg.visible = false
	add_child(hp_bar_bg)

	hp_bar_fill = ColorRect.new()
	var cfg: Dictionary = ORE_CONFIG.get(ore_type, {})
	hp_bar_fill.color = cfg.get("bar_color", Color(0.45, 0.85, 0.95, 1.0))
	hp_bar_fill.position = Vector2(1, 1)
	hp_bar_fill.size = Vector2(28, 3)
	hp_bar_bg.add_child(hp_bar_fill)

func hit_by_tool(tool_id: String, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if is_mined:
		return

	if not PICKAXE_MINE_POWER.has(tool_id):
		_play_hit_shake(0.4, attacker_pos)
		_spawn_floating_text("Use a Pickaxe!", Color(1.0, 0.65, 0.4, 1.0))
		return

	var mine_dmg: int = int(PICKAXE_MINE_POWER[tool_id])
	current_mine_hp = max(0, current_mine_hp - mine_dmg)

	_update_mine_bar()
	_play_hit_shake(1.0, attacker_pos)
	_spawn_sparks(6)
	_spawn_floating_text("-%d" % mine_dmg, Color(1.0, 0.95, 0.7, 1.0))

	if current_mine_hp <= 0:
		_break_rock(attacker_pos)

func _update_mine_bar() -> void:
	if not hp_bar_bg or not hp_bar_fill:
		return
	hp_bar_bg.visible = true
	hide_bar_timer = 2.0
	var ratio := clampf(float(current_mine_hp) / float(max(max_mine_hp, 1)), 0.0, 1.0)
	hp_bar_fill.size.x = 28.0 * ratio
	var cfg: Dictionary = ORE_CONFIG.get(ore_type, {})
	var base_col: Color = cfg.get("bar_color", Color(0.45, 0.85, 0.95, 1.0))
	if ratio > 0.5:
		hp_bar_fill.color = base_col
	elif ratio > 0.25:
		hp_bar_fill.color = Color(0.95, 0.78, 0.22, 1.0)
	else:
		hp_bar_fill.color = Color(0.95, 0.35, 0.25, 1.0)

func _play_hit_shake(intensity: float = 1.0, _attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if not rock_sprite:
		return
	rock_sprite.modulate = Color(1.45, 1.4, 1.35, 1.0)
	var tween := create_tween()
	tween.tween_property(rock_sprite, "position", Vector2(2.5 * intensity, 0.0), 0.035)
	tween.tween_property(rock_sprite, "position", Vector2(-2.5 * intensity, 0.0), 0.04)
	tween.tween_property(rock_sprite, "position", Vector2.ZERO, 0.045)
	tween.parallel().tween_property(rock_sprite, "scale", Vector2(1.1, 0.9), 0.045)
	tween.chain().tween_property(rock_sprite, "scale", Vector2.ONE, 0.06)
	tween.parallel().tween_property(rock_sprite, "modulate", Color.WHITE, 0.1)

func _spawn_sparks(count: int = 6) -> void:
	var cfg: Dictionary = ORE_CONFIG.get(ore_type, {})
	var spark_col: Color = cfg.get("spark_color", Color(0.9, 0.7, 0.4, 1.0))
	for i in range(count):
		var spark := ColorRect.new()
		spark.size = Vector2(3, 3)
		spark.color = spark_col if i % 2 == 0 else Color(1.0, 1.0, 0.9, 1.0)
		spark.position = Vector2(randf_range(-10.0, 10.0), randf_range(-16.0, -4.0))
		spark.z_index = 9
		add_child(spark)

		var target_pos := spark.position + Vector2(randf_range(-22.0, 22.0), randf_range(-18.0, 14.0))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(spark, "position", target_pos, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, 0.26)
		tw.chain().tween_callback(spark.queue_free)

func _spawn_floating_text(msg: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-50, -44)
	lbl.size = Vector2(100, 18)
	lbl.z_index = 20
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1.0))
	lbl.add_theme_constant_override("outline_size", 3)
	add_child(lbl)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 12.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.chain().tween_callback(lbl.queue_free)

func _break_rock(_attacker_pos: Vector2) -> void:
	is_mined = true
	var cfg: Dictionary = ORE_CONFIG.get(ore_type, {})
	var r_time: float = float(cfg.get("respawn_time", 35.0))
	respawn_remaining = r_time
	if SceneManager:
		var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
		SceneManager.chopped_trees_respawn_time[_get_rock_key()] = now_sec + r_time

	if hp_bar_bg:
		hp_bar_bg.visible = false
	if col_shape:
		col_shape.set_deferred("disabled", true)

	_spawn_sparks(12)
	_spawn_ore_drops()

	if rock_sprite:
		var break_tw := create_tween().set_parallel(true)
		break_tw.tween_property(rock_sprite, "scale", Vector2(1.25, 0.65), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		break_tw.tween_property(rock_sprite, "modulate:a", 0.0, 0.16)
		await break_tw.finished
		if is_instance_valid(rock_sprite) and is_mined:
			rock_sprite.visible = false
			rock_sprite.scale = Vector2.ONE

func _respawn_rock() -> void:
	is_mined = false
	respawn_remaining = 0.0
	current_mine_hp = max_mine_hp
	if SceneManager:
		SceneManager.chopped_trees_respawn_time.erase(_get_rock_key())

	if col_shape:
		col_shape.set_deferred("disabled", false)

	if rock_sprite:
		rock_sprite.position = Vector2.ZERO
		rock_sprite.modulate = Color.WHITE
		rock_sprite.scale = Vector2(0.2, 0.2)
		rock_sprite.visible = true
		var regrow_tw := create_tween()
		regrow_tw.tween_property(rock_sprite, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_ore_drops() -> void:
	var cfg: Dictionary = ORE_CONFIG.get(ore_type, {})
	var drop_path: String = str(cfg.get("drop_scene", ""))
	var drop_count: int = int(cfg.get("drop_count", 3))
	var drop_scene := load(drop_path) as PackedScene
	if not drop_scene or not get_parent():
		return

	for i in range(drop_count):
		var drop := drop_scene.instantiate() as Node2D
		if not drop:
			continue
		var angle := (TAU / float(max(drop_count, 1))) * float(i) + randf_range(-0.35, 0.35)
		var offset := Vector2(cos(angle), sin(angle)) * randf_range(14.0, 26.0)
		drop.global_position = global_position + Vector2(0, -6)
		drop.scale = Vector2(0.5, 0.5)
		get_parent().add_child(drop)

		var tw := drop.create_tween().set_parallel(true)
		tw.tween_property(drop, "global_position", global_position + offset, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(drop, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
