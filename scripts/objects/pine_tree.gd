extends StaticBody2D

@export var max_chop_hp: int = 12
@export var drop_count: int = 3
@export var respawn_time: float = 45.0

var current_chop_hp: int = 12
var is_chopped: bool = false
var respawn_remaining: float = 0.0

@onready var tree_sprite: Sprite2D = $TreeSprite if has_node("TreeSprite") else null
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

var hp_bar_bg: ColorRect = null
var hp_bar_fill: ColorRect = null
var hide_bar_timer: float = 0.0

# Sát thương chặt cây theo từng loại Rìu:
# - Rìu gỗ (wood_axe): 2 sát thương -> 6 nhát chặt (lâu nhất)
# - Rìu đá (stone_axe): 3 sát thương -> 4 nhát chặt (vừa)
# - Rìu sắt (iron_axe): 6 sát thương -> 2 nhát chặt (nhanh nhất)
const AXE_CHOP_POWER: Dictionary = {
	"wood_axe": 2,
	"stone_axe": 3,
	"iron_axe": 6
}

func _ready() -> void:
	add_to_group("choppable_tree")
	y_sort_enabled = true
	current_chop_hp = max_chop_hp
	_setup_chop_progress_bar()
	_restore_respawn_state_if_chopped()

func _process(delta: float) -> void:
	if hide_bar_timer > 0.0:
		hide_bar_timer -= delta
		if hide_bar_timer <= 0.0 and hp_bar_bg:
			hp_bar_bg.visible = false

	if is_chopped and respawn_remaining > 0.0:
		respawn_remaining -= delta
		if respawn_remaining <= 0.0:
			_regrow_tree()

func _get_tree_key() -> String:
	var scene_path := ""
	if get_tree() and get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	return "%s::%s::%d_%d" % [scene_path, name, int(round(global_position.x)), int(round(global_position.y))]

func _restore_respawn_state_if_chopped() -> void:
	if not SceneManager:
		return
	var key := _get_tree_key()
	if not SceneManager.chopped_trees_respawn_time.has(key):
		return

	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var target_sec: float = float(SceneManager.chopped_trees_respawn_time[key])
	var remaining := target_sec - now_sec

	if remaining > 0.0:
		is_chopped = true
		current_chop_hp = 0
		respawn_remaining = remaining
		if col_shape:
			col_shape.set_deferred("disabled", true)
		if tree_sprite:
			tree_sprite.visible = false
	else:
		SceneManager.chopped_trees_respawn_time.erase(key)

func _setup_chop_progress_bar() -> void:
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = Color(0.12, 0.1, 0.08, 0.85)
	hp_bar_bg.position = Vector2(-16, -68)
	hp_bar_bg.size = Vector2(32, 5)
	hp_bar_bg.z_index = 12
	hp_bar_bg.visible = false
	add_child(hp_bar_bg)

	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = Color(0.45, 0.88, 0.32, 1.0)
	hp_bar_fill.position = Vector2(1, 1)
	hp_bar_fill.size = Vector2(30, 3)
	hp_bar_bg.add_child(hp_bar_fill)

func hit_by_tool(tool_id: String, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if is_chopped:
		return

	if not AXE_CHOP_POWER.has(tool_id):
		_play_shake_effect(0.45, attacker_pos)
		_spawn_floating_text("Use an Axe!", Color(1.0, 0.65, 0.4, 1.0))
		return

	var chop_dmg: int = int(AXE_CHOP_POWER[tool_id])
	current_chop_hp = max(0, current_chop_hp - chop_dmg)

	_update_chop_bar()
	_play_shake_effect(1.0, attacker_pos)
	_spawn_wood_chips()

	if current_chop_hp <= 0:
		_chop_down_tree(attacker_pos)

func _update_chop_bar() -> void:
	if not hp_bar_bg or not hp_bar_fill:
		return
	hp_bar_bg.visible = true
	hide_bar_timer = 2.0
	var ratio := clampf(float(current_chop_hp) / float(max(max_chop_hp, 1)), 0.0, 1.0)
	hp_bar_fill.size.x = 30.0 * ratio
	if ratio > 0.5:
		hp_bar_fill.color = Color(0.45, 0.88, 0.32, 1.0)
	elif ratio > 0.25:
		hp_bar_fill.color = Color(0.95, 0.78, 0.22, 1.0)
	else:
		hp_bar_fill.color = Color(0.95, 0.35, 0.25, 1.0)

func _play_shake_effect(intensity: float = 1.0, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if not tree_sprite:
		return
	var dir_sign := 1.0
	if attacker_pos != Vector2.ZERO and attacker_pos.x > global_position.x:
		dir_sign = -1.0

	tree_sprite.modulate = Color(1.35, 1.3, 1.15, 1.0)
	var tween := create_tween()
	tween.tween_property(tree_sprite, "rotation", deg_to_rad(6.5 * intensity * dir_sign), 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(tree_sprite, "rotation", deg_to_rad(-4.5 * intensity * dir_sign), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tree_sprite, "rotation", 0.0, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(tree_sprite, "modulate", Color.WHITE, 0.12)

func _spawn_wood_chips() -> void:
	for i in range(4):
		var chip := ColorRect.new()
		chip.size = Vector2(3, 3)
		chip.color = Color(0.76, 0.52, 0.28, 1.0) if i % 2 == 0 else Color(0.58, 0.38, 0.18, 1.0)
		chip.position = Vector2(randf_range(-6.0, 6.0), randf_range(-14.0, -4.0))
		chip.z_index = 8
		add_child(chip)

		var target_pos := chip.position + Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, 10.0))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(chip, "position", target_pos, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(chip, "modulate:a", 0.0, 0.26)
		tw.chain().tween_callback(chip.queue_free)

func _spawn_floating_text(msg: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-60, -56)
	lbl.size = Vector2(120, 20)
	lbl.z_index = 20
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03, 1.0))
	lbl.add_theme_constant_override("outline_size", 3)
	add_child(lbl)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 14.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.65)
	tw.chain().tween_callback(lbl.queue_free)

func _chop_down_tree(attacker_pos: Vector2) -> void:
	is_chopped = true
	respawn_remaining = respawn_time
	if SceneManager:
		var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
		SceneManager.chopped_trees_respawn_time[_get_tree_key()] = now_sec + respawn_time

	if hp_bar_bg:
		hp_bar_bg.visible = false
	if col_shape:
		col_shape.set_deferred("disabled", true)

	var fall_dir := 1.0
	if attacker_pos != Vector2.ZERO and attacker_pos.x > global_position.x:
		fall_dir = -1.0

	_spawn_branch_drops(fall_dir)

	if tree_sprite:
		var fall_tween := create_tween()
		fall_tween.tween_property(tree_sprite, "rotation", deg_to_rad(86.0 * fall_dir), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall_tween.parallel().tween_property(tree_sprite, "modulate:a", 0.0, 0.45).set_delay(0.12)
		await fall_tween.finished
		if is_instance_valid(tree_sprite) and is_chopped:
			tree_sprite.visible = false

func _regrow_tree() -> void:
	is_chopped = false
	respawn_remaining = 0.0
	current_chop_hp = max_chop_hp
	if SceneManager:
		SceneManager.chopped_trees_respawn_time.erase(_get_tree_key())

	if col_shape:
		col_shape.set_deferred("disabled", false)

	if tree_sprite:
		tree_sprite.rotation = 0.0
		tree_sprite.modulate = Color.WHITE
		tree_sprite.scale = Vector2(0.2, 0.2)
		tree_sprite.visible = true
		var regrow_tw := create_tween()
		regrow_tw.tween_property(tree_sprite, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_branch_drops(fall_dir: float) -> void:
	var branch_scene := load("res://scenes/objects/branch_item.tscn") as PackedScene
	if not branch_scene or not get_parent():
		return

	for i in range(drop_count):
		var drop := branch_scene.instantiate() as Node2D
		if not drop:
			continue
		var start_pos := global_position + Vector2(fall_dir * float(8 + i * 6), -6.0)
		var offset := Vector2(
			fall_dir * randf_range(10.0, 30.0) + randf_range(-8.0, 8.0),
			randf_range(-10.0, 14.0)
		)
		drop.global_position = start_pos
		drop.scale = Vector2(0.5, 0.5)
		get_parent().add_child(drop)

		var tw := drop.create_tween().set_parallel(true)
		tw.tween_property(drop, "global_position", global_position + offset, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(drop, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
