extends Area2D

@export var speed: float = 150.0
@export var damage: int = 12
@export var knockback_force: float = 130.0
@export var lifetime: float = 3.5
@export var projectile_color: Color = Color.WHITE

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var _elapsed: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if anim:
		anim.modulate = projectile_color
		if anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
			anim.play("fly")

func setup(dir: Vector2, spd: float, dmg: int, tint: Color = Color.WHITE, source_node: Node = null) -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	speed = spd
	damage = dmg
	projectile_color = tint
	shooter = source_node
	rotation = direction.angle()
	if anim:
		anim.modulate = projectile_color

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body == shooter or body.is_in_group("enemy"):
		return
	if body.is_in_group("player") or body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position, knockback_force)
		_spawn_hit_effect()
		queue_free()
	elif body is TileMap or body is TileMapLayer or body is StaticBody2D:
		_spawn_hit_effect()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var p := area.get_parent()
	if p and (p.is_in_group("player") or p.name == "Player"):
		if p.has_method("take_damage"):
			p.take_damage(damage, global_position, knockback_force)
		_spawn_hit_effect()
		queue_free()

func _spawn_hit_effect() -> void:
	queue_redraw()

func _draw() -> void:
	# Vẽ quầng sáng nhỏ quanh đạn để nổi bật trong hầm ngục
	draw_circle(Vector2.ZERO, 6.0, Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.28))
