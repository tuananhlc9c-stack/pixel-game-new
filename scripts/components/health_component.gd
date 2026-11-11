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
