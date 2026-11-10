extends StaticBody2D

@export var max_mine_hp: int = 12
@export var drop_count: int = 3
@export var respawn_time: float = 45.0

var current_mine_hp: int = 12
var is_mined: bool = false
var respawn_remaining: float = 0.0

@onready var rock_sprite: Sprite2D = $RockSprite if has_node("RockSprite") else null
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

var hp_bar_bg: ColorRect = null
var hp_bar_fill: ColorRect = null
var hide_bar_timer: float = 0.0

# Sát thương đập đá theo từng cấp độ Cuốc:
# - Cuốc gỗ (wood_pickaxe): 2 sát thương -> 6 nhát đập (lâu nhất)
# - Cuốc đá (stone_pickaxe): 3 sát thương -> 4 nhát đập (trung bình)
# - Cuốc sắt (iron_pickaxe): 6 sát thương -> 2 nhát đập (nhanh nhất)
const PICKAXE_MINE_POWER: Dictionary = {
	"wood_pickaxe": 2,
	"stone_pickaxe": 3,
	"iron_pickaxe": 6
}

func _ready() -> void:
	add_to_group("mineable_rock")
	y_sort_enabled = true
	current_mine_hp = max_mine_hp
	_setup_mine_progress_bar()
	_restore_respawn_state_if_mined()

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
	return "rock::%s::%s::%d_%d" % [scene_path, name, int(round(global_position.x)), int(round(global_position.y))]

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
	hp_bar_bg.position = Vector2(-15, -32)
	hp_bar_bg.size = Vector2(30, 5)
	hp_bar_bg.z_index = 12
	hp_bar_bg.visible = false
	add_child(hp_bar_bg)

	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = Color(0.45, 0.85, 0.95, 1.0)
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
	_spawn_stone_sparks(6)
	_spawn_floating_text("-%d" % mine_dmg, Color(0.85, 0.95, 1.0, 1.0))

	if current_mine_hp <= 0:
		_break_rock(attacker_pos)

func _update_mine_bar() -> void:
	if not hp_bar_bg or not hp_bar_fill:
		return
	hp_bar_bg.visible = true
	hide_bar_timer = 2.0
	var ratio := clampf(float(current_mine_hp) / float(max(max_mine_hp, 1)), 0.0, 1.0)
	hp_bar_fill.size.x = 28.0 * ratio
	if ratio > 0.5:
		hp_bar_fill.color = Color(0.45, 0.85, 0.95, 1.0)
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

func _spawn_stone_sparks(count: int = 5) -> void:
	for i in range(count):
		var pebble := ColorRect.new()
		pebble.size = Vector2(3, 3)
		pebble.color = Color(0.78, 0.72, 0.68, 1.0) if i % 2 == 0 else Color(0.56, 0.5, 0.48, 1.0)
		pebble.position = Vector2(randf_range(-8.0, 8.0), randf_range(-14.0, -4.0))
		pebble.z_index = 9
		add_child(pebble)

		var target_pos := pebble.position + Vector2(randf_range(-20.0, 20.0), randf_range(-16.0, 12.0))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(pebble, "position", target_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pebble, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(pebble.queue_free)

func _spawn_floating_text(msg: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-50, -42)
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
	respawn_remaining = respawn_time
	if SceneManager:
		var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
		SceneManager.chopped_trees_respawn_time[_get_rock_key()] = now_sec + respawn_time

	if hp_bar_bg:
		hp_bar_bg.visible = false
	if col_shape:
		col_shape.set_deferred("disabled", true)

	_spawn_stone_sparks(10)
	_spawn_stone_drops()

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

func _spawn_stone_drops() -> void:
	var stone_scene := load("res://scenes/objects/stone_item.tscn") as PackedScene
	if not stone_scene or not get_parent():
		return

	for i in range(drop_count):
		var drop := stone_scene.instantiate() as Node2D
		if not drop:
			continue
		var angle := (TAU / float(max(drop_count, 1))) * float(i) + randf_range(-0.35, 0.35)
		var offset := Vector2(cos(angle), sin(angle)) * randf_range(12.0, 24.0)
		drop.global_position = global_position + Vector2(0, -4)
		drop.scale = Vector2(0.5, 0.5)
		get_parent().add_child(drop)

		var tw := drop.create_tween().set_parallel(true)
		tw.tween_property(drop, "global_position", global_position + offset, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(drop, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
