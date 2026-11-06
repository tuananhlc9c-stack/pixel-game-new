extends CharacterBody2D

@export var speed: float = 30.0
@export var max_distance: float = 60.0 # Bán kính giới hạn di chuyển quanh điểm xuất phát (khoảng vài ô vuông)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var start_position: Vector2
var move_direction: Vector2 = Vector2.ZERO
var timer: float = 0.0
var change_time: float = 2.5 # Thời gian đi theo một hướng trước khi đổi ý

func _ready():
	start_position = global_position # Lưu lại vị trí ban đầu
	_pick_random_direction()

func _physics_process(delta):
	timer += delta
	if timer >= change_time:
		timer = 0.0
		_pick_random_direction()

	# Nếu NPC đi quá xa điểm xuất phát, tự động đảo ngược hướng để đi ngược lại
	if global_position.distance_to(start_position) > max_distance:
		move_direction = -move_direction

	# Gán vận tốc và di chuyển
	velocity = move_direction * speed
	move_and_slide()

	# Cập nhật hoạt ảnh 4 hướng dựa theo vector di chuyển
	_update_animation()

func _pick_random_direction():
	# Chọn ngẫu nhiên các hướng: Lên, Xuống, Trái, Phải hoặc đứng yên (Vector2.ZERO)
	var directions = [
		Vector2.UP, 
		Vector2.DOWN, 
		Vector2.LEFT, 
		Vector2.RIGHT, 
		Vector2.ZERO
	]
	move_direction = directions.pick_random()

func _update_animation():
	if move_direction == Vector2.ZERO:
		# Nếu đứng yên, có thể giữ nguyên frame cuối hoặc phát hoạt ảnh đứng (tuỳ bạn chọn)
		return

	# Ưu tiên chiều di chuyển ngang hay dọc
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
