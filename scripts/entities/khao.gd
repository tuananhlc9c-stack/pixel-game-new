extends CharacterBody2D

@export var speed: float = 30.0
@export var max_distance: float = 60.0 # Bán kính giới hạn di chuyển quanh điểm xuất phát

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var start_position: Vector2
var move_direction: Vector2 = Vector2.ZERO
var timer: float = 0.0
var change_time: float = 2.5 # Thời gian đi theo một hướng trước khi đổi ý

func _ready() -> void:
	add_to_group("npc")
	start_position = global_position
	_pick_random_direction()

func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= change_time:
		timer = 0.0
		_pick_random_direction()

	# Nếu NPC đi quá xa điểm xuất phát, hướng về lại điểm xuất phát
	if global_position.distance_to(start_position) > max_distance:
		move_direction = (start_position - global_position).normalized()

	velocity = move_direction * speed
	move_and_slide()

	_update_animation()

func _pick_random_direction() -> void:
	var directions: Array[Vector2] = [
		Vector2.UP,
		Vector2.DOWN,
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2.ZERO
	]
	move_direction = directions.pick_random()

func _update_animation() -> void:
	if not anim or not anim.sprite_frames:
		return

	if move_direction == Vector2.ZERO:
		if anim.is_playing():
			anim.stop()
			anim.frame = 0
		return

	if abs(move_direction.x) > abs(move_direction.y):
		if move_direction.x < 0:
			if anim.sprite_frames.has_animation("walk_left"):
				anim.play("walk_left")
		else:
			if anim.sprite_frames.has_animation("walk_right"):
				anim.play("walk_right")
	else:
		if move_direction.y > 0:
			if anim.sprite_frames.has_animation("walk_down"):
				anim.play("walk_down")
		else:
			if anim.sprite_frames.has_animation("walk_up"):
				anim.play("walk_up")
