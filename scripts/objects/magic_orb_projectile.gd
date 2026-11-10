extends Area2D

@export var speed: float = 230.0
@export var damage: int = 35
@export var knockback_force: float = 180.0
@export var lifetime: float = 3.5
@export var orb_color: Color = Color(0.8, 0.4, 1.0, 1.0)

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var _elapsed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(dir: Vector2, spd: float, dmg: int, tint: Color = Color(0.8, 0.4, 1.0, 1.0), source_node: Node = null) -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	speed = spd
	damage = dmg
	orb_color = tint
	shooter = source_node
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(_elapsed * 16.0) * 0.18
	var outer_r := 8.0 * pulse
	var inner_r := 5.0 * pulse
	# Glow
	draw_circle(Vector2.ZERO, outer_r + 4.0, Color(orb_color.r, orb_color.g, orb_color.b, 0.25))
	# Main body
	draw_circle(Vector2.ZERO, outer_r, orb_color)
	# Bright core
	draw_circle(Vector2.ZERO, inner_r, Color.WHITE)
	# Orbiting particles or arcs
	draw_arc(Vector2.ZERO, outer_r + 2.0, _elapsed * 8.0, _elapsed * 8.0 + PI * 1.2, 16, Color(1.0, 1.0, 1.0, 0.7), 1.5)

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
