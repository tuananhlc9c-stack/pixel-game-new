class_name HealthComponent
extends Node

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int)
signal died

@export var max_health: int = 100
@export var invincibility_duration: float = 0.4

var current_health: int
var is_invincible: bool = false

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> void:
	if is_invincible or current_health <= 0 or amount <= 0:
		return

	current_health = max(current_health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)

	var p_node = get_parent()
	var is_player = (p_node != null and (p_node.is_in_group("player") or p_node.name == "Player"))

	if p_node is Node2D:
		_spawn_damage_popup(p_node as Node2D, amount, is_player)

	if current_health == 0:
		if not is_player and AudioManager:
			AudioManager.play_sfx_random_pitch("enemy_die", 0.0, 0.9, 1.1)
		died.emit()
	else:
		if not is_player and AudioManager:
			AudioManager.play_sfx_random_pitch("enemy_hurt", 0.0, 0.95, 1.15)
		if invincibility_duration > 0.0:
			start_invincibility(invincibility_duration)

func heal(amount: int) -> void:
	if current_health <= 0 or amount <= 0:
		return
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func reset_health() -> void:
	current_health = max_health
	is_invincible = false
	health_changed.emit(current_health, max_health)

func start_invincibility(duration: float) -> void:
	is_invincible = true
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		is_invincible = false

func _spawn_damage_popup(target_node: Node2D, amount: int, is_player_hit: bool) -> void:
	if not is_instance_valid(target_node) or not get_tree():
		return
	var scene_root := get_tree().current_scene
	if not scene_root:
		return

	var holder := Node2D.new()
	holder.top_level = true
	holder.z_index = 95
	var jitter_x := randf_range(-8.0, 8.0)
	var jitter_y := randf_range(-4.0, 2.0)
	var start_pos := target_node.global_position + Vector2(jitter_x, -20.0 + jitter_y)
	holder.global_position = start_pos

	var lbl := Label.new()
	lbl.text = "-%d" % amount if is_player_hit else str(amount)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-40.0, -10.0)
	lbl.size = Vector2(80.0, 20.0)

	var font_sz: int = 12 if (is_player_hit or amount >= 50) else 11
	lbl.add_theme_font_size_override("font_size", font_sz)

	if is_player_hit:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.898, 0.886, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.02, 1.0))
	elif amount >= 50:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.01, 1.0))
	else:
		lbl.add_theme_color_override("font_color", Color(0.881, 0.154, 0.0, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 1.0))

	lbl.add_theme_constant_override("outline_size", 3)
	holder.add_child(lbl)
	scene_root.add_child(holder)

	holder.scale = Vector2(0.5, 0.5)
	var pop_tw := holder.create_tween()
	pop_tw.tween_property(holder, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(holder, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var move_tw := holder.create_tween().set_parallel(true)
	var drift_x := randf_range(-10.0, 10.0)
	move_tw.tween_property(holder, "global_position", start_pos + Vector2(drift_x, -22.0), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move_tw.tween_property(holder, "modulate:a", 0.0, 0.4).set_delay(0.25)
	move_tw.chain().tween_callback(holder.queue_free)
