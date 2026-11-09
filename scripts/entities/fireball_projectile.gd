extends Area2D

@export var speed: float = 150.0
@export var damage: int = 12
@export var knockback_force: float = 130.0
@export var lifetime: float = 3.5
@export var projectile_color: Color = Color.WHITE

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var _elapsed: float = 0.0

# Tùy chỉnh mở rộng cho Cầu Sét (Lightning Orb) & Cầu Sét Truy Đuổi (Homing Orb)
var hover_delay: float = 0.0
var lock_dir_on_launch: bool = false
var row_origin_pos: Vector2 = Vector2.ZERO
var is_homing: bool = false
var homing_turn_speed: float = 3.5
var ignore_walls: bool = false
var is_lightning_style: bool = false
var _launched: bool = true

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
	rotation = 0.0 if is_lightning_style else direction.angle()
	if anim:
		anim.modulate = projectile_color

func setup_lightning_orb(orb_frames: SpriteFrames, dir: Vector2, spd: float, dmg: int, delay_before_fly: float = 0.0, homing: bool = false, total_lifetime: float = 4.0) -> void:
	is_lightning_style = true
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	speed = spd
	damage = dmg
	hover_delay = delay_before_fly
	_launched = delay_before_fly <= 0.0
	is_homing = homing
	ignore_walls = homing
	lifetime = total_lifetime
	rotation = 0.0
	if anim and orb_frames:
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		anim.scale = Vector2(0.85, 0.85)
		anim.sprite_frames = orb_frames
		anim.play("orb")
		anim.modulate = Color.WHITE
	if delay_before_fly > 0.0:
		scale = Vector2(0.2, 0.2)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, minf(delay_before_fly * 0.8, 0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return

	# Giai đoạn dàn hàng chờ phóng (hover_delay)
	if not _launched:
		if _elapsed >= hover_delay:
			_launched = true
			if lock_dir_on_launch:
				var p := get_tree().get_first_node_in_group("player") as Node2D
				if p and is_instance_valid(p):
					var origin := row_origin_pos if row_origin_pos != Vector2.ZERO else global_position
					var to_p := (p.global_position - origin).normalized()
					if to_p != Vector2.ZERO:
						direction = to_p
		queue_redraw()
		return

	# Chế độ Cầu Sét Truy Đuổi bay từ từ theo Player
	if is_homing:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p and is_instance_valid(p):
			var desired := (p.global_position - global_position).normalized()
			if desired != Vector2.ZERO:
				direction = direction.lerp(desired, clampf(homing_turn_speed * delta, 0.0, 1.0)).normalized()

		# Mờ dần trong 0.6 giây cuối trước khi biến mất
		var time_left := lifetime - _elapsed
		if time_left <= 0.6:
			modulate.a = clampf(time_left / 0.6, 0.0, 1.0)

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
	elif not ignore_walls and (body is TileMap or body is TileMapLayer or body is StaticBody2D):
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
	if is_lightning_style:
		var pulse := 1.0 + sin(_elapsed * 14.0) * 0.15
		var r := (12.0 if is_homing else 8.5) * pulse
		draw_circle(Vector2.ZERO, r, Color(0.2, 0.95, 0.72, 0.22))
		if is_homing:
			draw_arc(Vector2.ZERO, r + 2.5, _elapsed * 6.0, _elapsed * 6.0 + PI * 1.3, 18, Color(0.45, 1.0, 0.85, 0.8), 1.6)
			draw_arc(Vector2.ZERO, r + 2.5, _elapsed * 6.0 + PI, _elapsed * 6.0 + PI * 2.1, 18, Color(0.85, 1.0, 0.5, 0.7), 1.4)
		return

	# Vẽ quầng sáng nhỏ quanh đạn để nổi bật trong hầm ngục
	draw_circle(Vector2.ZERO, 6.0, Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.28))
