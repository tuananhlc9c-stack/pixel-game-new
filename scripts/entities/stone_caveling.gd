extends CharacterBody2D

@export_group("Stats")
@export var move_speed: float = 38.0
@export var contact_damage: int = 12
@export var slam_damage: int = 24
@export var slam_radius: float = 54.0
@export var wake_range: float = 105.0
@export var chase_range: float = 210.0
@export var slam_trigger_range: float = 46.0
@export var slam_windup_time: float = 0.65
@export var slam_cooldown: float = 2.6
@export var knockback_force: float = 220.0
@export var knockback_resistance: float = 0.45 # Kháng đẩy lùi cao

enum State { DORMANT, EMERGE, CHASE, SLAM_WINDUP, SLAM_RECOVERY, HURT }
var current_state: State = State.DORMANT

var player: Node2D = null
var state_timer: float = 0.0
var cooldown_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var shockwave_ring_progress: float = -1.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_comp: HealthComponent = $HealthComponent
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	add_to_group("enemy")
	if health_comp:
		health_comp.died.connect(_on_died)
		health_comp.health_changed.connect(_on_health_changed)
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	# Khởi đầu ở trạng thái tảng đá ngủ yên (frame đầu của emerge)
	if anim and anim.sprite_frames.has_animation("emerge"):
		anim.play("emerge")
		anim.stop()
		anim.frame = 0

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if shockwave_ring_progress >= 0.0:
		shockwave_ring_progress += delta * 3.2
		if shockwave_ring_progress > 1.0:
			shockwave_ring_progress = -1.0
		queue_redraw()

	_find_player()

	match current_state:
		State.DORMANT:
			velocity = Vector2.ZERO
			if player and is_instance_valid(player):
				if global_position.distance_to(player.global_position) <= wake_range:
					_start_emerge()

		State.EMERGE:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.CHASE

		State.HURT:
			velocity = knockback_velocity
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.CHASE

		State.CHASE:
			if not player or not is_instance_valid(player):
				velocity = Vector2.ZERO
				if anim:
					anim.stop()
			else:
				var to_player: Vector2 = player.global_position - global_position
				var dist: float = to_player.length()
				if dist <= slam_trigger_range and cooldown_timer <= 0.0:
					_start_slam_windup()
				elif dist <= chase_range:
					var dir: Vector2 = to_player.normalized()
					velocity = dir * move_speed
					_play_dir_anim(dir)
				else:
					velocity = Vector2.ZERO

		State.SLAM_WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			if anim:
				var pulse: float = abs(sin(state_timer * 24.0))
				anim.modulate = Color(1.0, 0.55 + 0.45 * pulse, 0.35)
			queue_redraw()
			if state_timer <= 0.0:
				_execute_ground_slam()

		State.SLAM_RECOVERY:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.CHASE

	move_and_slide()

func _start_emerge() -> void:
	current_state = State.EMERGE
	state_timer = 0.55
	if anim and anim.sprite_frames.has_animation("emerge"):
		anim.play("emerge")

func _start_slam_windup() -> void:
	current_state = State.SLAM_WINDUP
	state_timer = slam_windup_time
	if anim:
		anim.stop()
	queue_redraw()

func _execute_ground_slam() -> void:
	current_state = State.SLAM_RECOVERY
	state_timer = 0.5
	cooldown_timer = slam_cooldown
	shockwave_ring_progress = 0.0
	if anim:
		anim.modulate = Color.WHITE
	queue_redraw()

	# Kiểm tra sát thương AoE lên Player
	if player and is_instance_valid(player):
		var dist: float = global_position.distance_to(player.global_position)
		if dist <= slam_radius and player.has_method("take_damage"):
			player.take_damage(slam_damage, global_position, knockback_force * 1.35)

func _draw() -> void:
	# Vẽ vòng cảnh báo đỏ cam khi đang gồng đập đất (giống Core Keeper)
	if current_state == State.SLAM_WINDUP:
		var ratio: float = clamp(1.0 - (state_timer / slam_windup_time), 0.0, 1.0)
		draw_circle(Vector2.ZERO, slam_radius, Color(0.95, 0.25, 0.1, 0.18))
		draw_circle(Vector2.ZERO, slam_radius * ratio, Color(1.0, 0.45, 0.15, 0.28))
		draw_arc(Vector2.ZERO, slam_radius, 0.0, TAU, 36, Color(1.0, 0.35, 0.1, 0.85), 1.8)

	# Vẽ hiệu ứng sóng chấn động lan ra khi đập đất
	if shockwave_ring_progress >= 0.0:
		var r: float = slam_radius * shockwave_ring_progress
		var alpha: float = 1.0 - shockwave_ring_progress
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(1.0, 0.75, 0.35, alpha), 3.0)
		draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 28, Color(0.85, 0.55, 0.25, alpha * 0.7), 1.5)

	if health_comp and health_comp.current_health < health_comp.max_health and health_comp.current_health > 0:
		var bw: float = 24.0
		var bh: float = 3.0
		var bp := Vector2(-bw / 2.0, -20.0)
		var hp_ratio := float(health_comp.current_health) / float(health_comp.max_health)
		draw_rect(Rect2(bp, Vector2(bw, bh)), Color(0.15, 0.15, 0.15, 0.85))
		draw_rect(Rect2(bp, Vector2(bw * hp_ratio, bh)), Color(0.95, 0.55, 0.2, 0.95))

func _play_dir_anim(dir: Vector2) -> void:
	if not anim:
		return
	if abs(dir.x) > abs(dir.y):
		anim.play("walk_right" if dir.x > 0 else "walk_left")
	else:
		anim.play("walk_down" if dir.y > 0 else "walk_up")

func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player")
	if not player and get_parent():
		player = get_parent().get_node_or_null("Player")

func _on_hitbox_body_entered(body: Node2D) -> void:
	if current_state == State.DORMANT:
		return
	if (body.name == "Player" or body.is_in_group("player")) and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position, knockback_force)

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, kb_force: float = 140.0) -> void:
	if current_state == State.DORMANT:
		_start_emerge()
	if health_comp:
		health_comp.take_damage(amount)
	if source_pos != Vector2.ZERO and current_state != State.SLAM_WINDUP:
		var dir: Vector2 = (global_position - source_pos).normalized()
		knockback_velocity = dir * kb_force * knockback_resistance
		current_state = State.HURT
		state_timer = 0.14
	queue_redraw()

func _on_health_changed(_current: int, _max: int) -> void:
	if anim:
		anim.modulate = Color(1.0, 0.3, 0.3)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", Color.WHITE, 0.15)

func _on_died() -> void:
	set_physics_process(false)
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
