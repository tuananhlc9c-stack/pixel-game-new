class_name HitboxComponent
extends Area2D

@export var damage: int = 25
@export var knockback_force: float = 140.0

var hit_targets: Array[Node] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func clear_hit_targets() -> void:
	hit_targets.clear()

func _on_body_entered(body: Node) -> void:
	_try_apply_damage(body)

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		_try_apply_damage(area)
	elif area.get_parent() and area.get_parent() != get_owner():
		_try_apply_damage(area.get_parent())

func _try_apply_damage(target: Node) -> void:
	if not is_instance_valid(target):
		return
	if target == owner or target == get_parent() or target == get_parent().get_parent():
		return
	if target in hit_targets:
		return

	if target is HurtboxComponent:
		hit_targets.append(target)
		target.receive_hit(self)
	elif target.has_method("take_damage"):
		hit_targets.append(target)
		var source_pos: Vector2 = global_position
		if owner is Node2D:
			source_pos = (owner as Node2D).global_position
		target.take_damage(damage, source_pos, knockback_force)
