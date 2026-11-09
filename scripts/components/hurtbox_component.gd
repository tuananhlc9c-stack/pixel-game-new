class_name HurtboxComponent
extends Area2D

signal hurt(hitbox: HitboxComponent)

@export var health_component: HealthComponent

func receive_hit(hitbox: HitboxComponent) -> void:
	if not hitbox:
		return
	if health_component:
		health_component.take_damage(hitbox.damage)
	hurt.emit(hitbox)
