extends Area2D

@export var speed: float = 550.0
@export var damage: int = 25
@export var knockback_force: float = 160.0
@export var lifetime: float = 4.5
@export var projectile_color: Color = Color.WHITE

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var _elapsed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if sprite:
		sprite.modulate = projectile_color

func setup(dir: Vector2, spd: float, dmg: int, tint: Color = Color.WHITE, source_node: Node = null) -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	speed = spd
	damage = dmg
	projectile_color = tint
	shooter = source_node
	rotation = direction.angle()
	if sprite:
		sprite.modulate = projectile_color

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body == shooter or body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position, knockback_force)
		queue_free()
	elif body is TileMap or body is TileMapLayer or body is StaticBody2D:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target and target != shooter and not target.is_in_group("player"):
		if target.has_method("take_damage"):
			target.take_damage(damage, global_position, knockback_force)
			queue_free()
