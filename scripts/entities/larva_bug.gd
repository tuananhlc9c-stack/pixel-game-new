extends CharacterBody2D


enum State { PATROL, CHASE, WINDUP, LUNGE, RECOVER }

@export var patrol_speed: float = 32.0
@export var chase_speed: float = 55.0
@export var lunge_speed: float = 195.0
@export var max_distance: float = 90.0
@export var max_health: int = 65
@export var contact_damage: int = 12
@export var lunge_damage: int = 18
@export var chase_radius: float = 115.0
@export var lunge_range: float = 68.0
@export var lunge_cooldown: float = 2.4

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var area: Area2D = $Area2D if has_node("Area2D") else null

var health_component: HealthComponent
var state: State = State.PATROL
var start_position: Vector2
var move_direction: Vector2 = Vector2.DOWN
var lunge_direction: Vector2 = Vector2.DOWN
var state_timer: float = 0.0
var cooldown_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemy")
	start_position = global_position

	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	health_component.max_health = max_health
	health_component.invincibility_duration = 0.15
	add_child(health_component)
	health_component.reset_health()
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

	if area:
		area.body_entered.connect(_on_area_body_entered)

	_pick_random_direction()

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if knockback_velocity.length() > 5.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 550.0 * delta)
		move_and_slide()
		queue_redraw()
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D

	match state:
		State.PATROL:
			state_timer += delta
			if state_timer >= 2.0:
				state_timer = 0.0
				_pick_random_direction()
			if global_position.distance_to(start_position) > max_distance:
				move_direction = (start_position - global_position).normalized()
			velocity = move_direction * patrol_speed
			_update_directional_anim(move_direction)

			if player and is_instance_valid(player):
				if global_position.distance_to(player.global_position) <= chase_radius:
					state = State.CHASE

		State.CHASE:
			if not player or not is_instance_valid(player):
				state = State.PATROL
				return
			var dist := global_position.distance_to(player.global_position)
			if dist > chase_radius * 1.4:
				state = State.PATROL
				return

			move_direction = (player.global_position - global_position).normalized()
			velocity = move_direction * chase_speed
			_update_directional_anim(move_direction)

			if dist <= lunge_range and cooldown_timer <= 0.0:
				state = State.WINDUP
				state_timer = 0.45
				lunge_direction = move_direction
				velocity = Vector2.ZERO

		State.WINDUP:
			state_timer -= delta
			velocity = Vector2.ZERO
			if anim:
				anim.position = Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
				anim.modulate = Color(1.8, 0.75, 0.3, 1.0)
			if state_timer <= 0.0:
				if anim:
					anim.position = Vector2.ZERO
					anim.modulate = Color(2.0, 0.4, 0.3, 1.0)
				state = State.LUNGE
				state_timer = 0.28
				cooldown_timer = lunge_cooldown

		State.LUNGE:
			state_timer -= delta
			velocity = lunge_direction * lunge_speed
			_update_directional_anim(lunge_direction)
			if state_timer <= 0.0:
				if anim:
					anim.modulate = Color.WHITE
				state = State.RECOVER
				state_timer = 0.35

		State.RECOVER:
			state_timer -= delta
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
			if state_timer <= 0.0:
				state = State.CHASE

	move_and_slide()
	queue_redraw()

func _update_directional_anim(dir: Vector2) -> void:
	if not anim or not anim.sprite_frames:
		return
	if dir.length() < 0.05:
		anim.stop()
		return
	if abs(dir.x) > abs(dir.y):
		anim.play("walk_right" if dir.x > 0 else "walk_left")
	else:
		anim.play("walk_down" if dir.y > 0 else "walk_up")

func _pick_random_direction() -> void:
	var dirs: Array = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.ZERO]
	move_direction = dirs.pick_random()

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback_force: float = 130.0) -> void:
	if not health_component or health_component.is_invincible:
		return
	if source_pos != Vector2.ZERO:
		var dir := (global_position - source_pos).normalized()
		knockback_velocity = (dir if dir != Vector2.ZERO else Vector2.UP) * knockback_force
	if anim:
		anim.position = Vector2.ZERO
		anim.modulate = Color(2.5, 0.4, 0.4, 1.0)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", Color.WHITE, 0.18)
	health_component.take_damage(amount)

func _on_area_body_entered(body: Node) -> void:
	if (body.is_in_group("player") or body.name == "Player") and body.has_method("take_damage"):
		var dmg := lunge_damage if state == State.LUNGE else contact_damage
		body.take_damage(dmg, global_position, 150.0)

func _on_health_changed(_current: int, _max: int) -> void:
	queue_redraw()

func _on_died() -> void:
	queue_free()

func _draw() -> void:
	# Vẽ vệt cảnh báo đỏ khi sâu đang gồng chuẩn bị lao húc
	if state == State.WINDUP:
		draw_line(Vector2.ZERO, lunge_direction * 46.0, Color(1.0, 0.25, 0.15, 0.65), 3.0)
		draw_circle(lunge_direction * 46.0, 4.0, Color(1.0, 0.25, 0.15, 0.75))

	if health_component and health_component.current_health < health_component.max_health and health_component.current_health > 0:
		var bw: float = 22.0
		var bh: float = 3.0
		var bp := Vector2(-bw / 2.0, -14.0)
		var ratio := float(health_component.current_health) / float(health_component.max_health)
		draw_rect(Rect2(bp, Vector2(bw, bh)), Color(0.15, 0.15, 0.15, 0.85))
		draw_rect(Rect2(bp, Vector2(bw * ratio, bh)), Color(0.95, 0.35, 0.2, 0.95))
