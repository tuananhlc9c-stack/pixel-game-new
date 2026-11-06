extends CharacterBody2D

@export var speed: float = 25.0
@export var max_distance: float = 48.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var start_position: Vector2
var move_direction: Vector2 = Vector2.RIGHT
var timer: float = 0.0
var change_time: float = 2.0

func _ready():
	start_position = global_position
	if anim.sprite_frames and anim.sprite_frames.has_animation("walk"):
		anim.play("walk")
	elif anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")
	_pick_random_direction()

func _physics_process(delta):
	timer += delta
	if timer >= change_time:
		timer = 0.0
		_pick_random_direction()

	if global_position.distance_to(start_position) > max_distance:
		move_direction = -move_direction

	velocity = move_direction * speed
	move_and_slide()

	if move_direction.x < 0:
		anim.flip_h = true
	elif move_direction.x > 0:
		anim.flip_h = false

func _pick_random_direction():
	var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.ZERO]
	move_direction = directions.pick_random()

func take_damage(_amount: int):
	queue_free()
