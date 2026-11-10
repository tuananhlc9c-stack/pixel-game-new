extends CharacterBody2D

@export var speed: float = 25.0
@export var chase_speed: float = 42.0
@export var max_distance: float = 48.0
@export var max_health: int = 50
@export var is_hostile: bool = true
@export var contact_damage: int = 10
@export var chase_radius: float = 85.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var area: Area2D = $Area2D if has_node("Area2D") else null

var health_component: HealthComponent
var start_position: Vector2
var move_direction: Vector2 = Vector2.RIGHT
var timer: float = 0.0
var change_time: float = 2.0
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemy")
	start_position = global_position

	# Khởi tạo HealthComponent
	if has_node("HealthComponent"):
		health_component = $HealthComponent
	else:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		health_component.max_health = max_health
		health_component.invincibility_duration = 0.15
		add_child(health_component)

	health_component.max_health = max_health
	health_component.reset_health()
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

	if area:
		area.body_entered.connect(_on_area_body_entered)

	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation("walk"):
			anim.play("walk")
		elif anim.sprite_frames.has_animation("idle"):
			anim.play("idle")

	_pick_random_direction()

func _physics_process(delta: float) -> void:
	# Xử lý lực đẩy lùi (knockback) khi trúng đòn
	if knockback_velocity.length() > 5.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		return

	var current_speed: float = speed
	var chasing: bool = false

	if is_hostile:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and is_instance_valid(player):
			var dist_to_player := global_position.distance_to(player.global_position)
			var dist_from_home := player.global_position.distance_to(start_position)
			if dist_to_player <= chase_radius and dist_from_home <= max_distance * 2.2:
				move_direction = (player.global_position - global_position).normalized()
				current_speed = chase_speed
				chasing = true

	if not chasing:
		timer += delta
		if timer >= change_time:
			timer = 0.0
			_pick_random_direction()

		if global_position.distance_to(start_position) > max_distance:
			move_direction = (start_position - global_position).normalized()

	velocity = move_direction * current_speed
	move_and_slide()

	if anim:
		if move_direction.x < -0.05:
			anim.flip_h = true
		elif move_direction.x > 0.05:
			anim.flip_h = false

func _pick_random_direction() -> void:
	var directions: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP * 0.5 + Vector2.RIGHT * 0.5,
		Vector2.DOWN * 0.5 + Vector2.LEFT * 0.5,
		Vector2.ZERO
	]
	move_direction = directions.pick_random().normalized()

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback_force: float = 130.0) -> void:
	if not health_component or health_component.is_invincible:
		return

	if source_pos != Vector2.ZERO:
		var dir := (global_position - source_pos).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		knockback_velocity = dir * knockback_force

	_play_hit_flash()
	health_component.take_damage(amount)

func _play_hit_flash() -> void:
	if not anim:
		return
	anim.modulate = Color(2.5, 0.4, 0.4, 1.0)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", Color.WHITE, 0.18)

func _on_health_changed(_current: int, _max: int) -> void:
	queue_redraw()

func _on_died() -> void:
	if SceneManager and SceneManager.has_method("add_player_exp"):
		SceneManager.add_player_exp(8)
	set_physics_process(false)
	var parent_node := get_parent()
	if parent_node and parent_node != get_tree().current_scene and parent_node is Node2D and parent_node.get_child_count() == 1:
		parent_node.queue_free()
	else:
		queue_free()

func _on_area_body_entered(body: Node) -> void:
	if not is_hostile:
		return
	if (body.is_in_group("player") or body.name == "Player") and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position, 140.0)

func _draw() -> void:
	if not health_component:
		return
	if health_component.current_health < health_component.max_health and health_component.current_health > 0:
		var bar_width: float = 20.0
		var bar_height: float = 3.0
		var bar_pos := Vector2(-bar_width / 2.0, -18.0)
		var ratio := float(health_component.current_health) / float(health_component.max_health)
		draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.15, 0.15, 0.15, 0.85))
		draw_rect(Rect2(bar_pos, Vector2(bar_width * ratio, bar_height)), Color(0.9, 0.2, 0.2, 0.95))
