extends CharacterBody2D

const FIREBALL_SCENE := preload("res://scenes/entities/fireball_projectile.tscn")

enum State { PATROL, KITE, CASTING }

@export var move_speed: float = 38.0
@export var max_health: int = 75
@export var aggro_radius: float = 165.0
@export var preferred_min_dist: float = 65.0
@export var preferred_max_dist: float = 125.0
@export var cast_cooldown: float = 2.6
@export var fireball_speed: float = 155.0
@export var fireball_damage: int = 15
@export var contact_damage: int = 8

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var area: Area2D = $Area2D if has_node("Area2D") else null

var health_component: HealthComponent
var state: State = State.PATROL
var start_position: Vector2
var move_direction: Vector2 = Vector2.DOWN
var state_timer: float = 0.0
var cooldown_timer: float = 1.2
var cast_progress: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemy")
	start_position = global_position

	if has_node("HealthComponent"):
		health_component = $HealthComponent
		health_component.max_health = max_health
		health_component.reset_health()
	else:
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
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
		move_and_slide()
		queue_redraw()
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D

	match state:
		State.PATROL:
			state_timer += delta
			if state_timer >= 2.4:
				state_timer = 0.0
				_pick_random_direction()
			if global_position.distance_to(start_position) > 85.0:
				move_direction = (start_position - global_position).normalized()
			velocity = move_direction * (move_speed * 0.75)
			_update_directional_anim(move_direction)

			if player and is_instance_valid(player):
				if global_position.distance_to(player.global_position) <= aggro_radius:
					state = State.KITE

		State.KITE:
			if not player or not is_instance_valid(player):
				state = State.PATROL
				return
			var to_player := player.global_position - global_position
			var dist := to_player.length()
			if dist > aggro_radius * 1.35:
				state = State.PATROL
				return

			var dir_to_player := to_player.normalized()
			if dist < preferred_min_dist:
				# Lùi ra xa khi Player áp sát (giống Caveling Shaman)
				move_direction = -dir_to_player
				velocity = move_direction * move_speed
			elif dist > preferred_max_dist:
				move_direction = dir_to_player
				velocity = move_direction * move_speed
			else:
				# Đi ngang lách né
				var perp := Vector2(-dir_to_player.y, dir_to_player.x)
				velocity = perp * (move_speed * 0.65)
				move_direction = dir_to_player

			_update_directional_anim(move_direction)

			if cooldown_timer <= 0.0:
				state = State.CASTING
				state_timer = 0.65
				cast_progress = 0.0
				velocity = Vector2.ZERO
				if anim and anim.sprite_frames and anim.sprite_frames.has_animation("cast"):
					anim.play("cast")

		State.CASTING:
			state_timer -= delta
			cast_progress += delta / 0.65
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				_fire_spell(player)
				cooldown_timer = cast_cooldown
				state = State.KITE

	move_and_slide()
	queue_redraw()

func _fire_spell(player: Node2D) -> void:
	if not player or not is_instance_valid(player) or not get_parent():
		return
	var base_dir := (player.global_position - global_position).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.DOWN

	# Nếu máu dưới 50%, Shaman bắn 3 tia cầu lửa hình quạt
	var is_low_hp := health_component and health_component.current_health <= health_component.max_health * 0.5
	var angles: Array = [-0.24, 0.0, 0.24] if is_low_hp else [0.0]

	for angle_offset in angles:
		var fb := FIREBALL_SCENE.instantiate()
		get_parent().add_child(fb)
		fb.global_position = global_position + Vector2(0, -6)
		fb.setup(base_dir.rotated(float(angle_offset)), fireball_speed, fireball_damage, Color(1.1, 0.75, 0.3, 1.0), self)

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
		anim.modulate = Color(2.5, 0.4, 0.4, 1.0)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", Color.WHITE, 0.18)
	health_component.take_damage(amount)

func _on_area_body_entered(body: Node) -> void:
	if (body.is_in_group("player") or body.name == "Player") and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position, 120.0)

func _on_health_changed(_current: int, _max: int) -> void:
	queue_redraw()

func _on_died() -> void:
	if SceneManager and SceneManager.has_method("add_player_exp"):
		SceneManager.add_player_exp(24)
	queue_free()

func _draw() -> void:
	# Vẽ vòng ma thuật dưới chân khi Shaman đang niệm chú
	if state == State.CASTING:
		var radius := 12.0 + sin(cast_progress * PI * 4.0) * 2.5
		draw_arc(Vector2(0, 6), radius, 0.0, TAU, 24, Color(1.0, 0.45, 0.15, 0.8), 1.8)
		draw_circle(Vector2(0, -14), 4.5 * clampf(cast_progress, 0.2, 1.0), Color(0.4, 0.85, 1.0, 0.7))

	if health_component and health_component.current_health < health_component.max_health and health_component.current_health > 0:
		var bw: float = 24.0
		var bh: float = 3.0
		var bp := Vector2(-bw / 2.0, -22.0)
		var ratio := float(health_component.current_health) / float(health_component.max_health)
		draw_rect(Rect2(bp, Vector2(bw, bh)), Color(0.15, 0.15, 0.15, 0.85))
		draw_rect(Rect2(bp, Vector2(bw * ratio, bh)), Color(0.9, 0.25, 0.85, 0.95))
