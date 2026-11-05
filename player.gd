extends CharacterBody2D

@export var speed: float = 120.0
@export var roll_speed: float = 260.0
@export var roll_duration: float = 0.25

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "down"
var is_rolling: bool = false

func _physics_process(_delta):
	# Nếu đang lộn/lướt thì chỉ di chuyển theo vận tốc lướt và bỏ qua nhận phím di chuyển
	if is_rolling:
		move_and_slide()
		return

	# Lấy hướng di chuyển từ Input Map (hỗ trợ cả nhóm phím move_* và ui_*)
	var input_x = Input.get_axis("move_left", "move_right")
	if input_x == 0:
		input_x = Input.get_axis("ui_left", "ui_right")

	var input_y = Input.get_axis("move_up", "move_down")
	if input_y == 0:
		input_y = Input.get_axis("ui_up", "ui_down")

	var direction = Vector2(input_x, input_y).normalized()

	# Bấm Space (roll) hoặc phím Enter/Space mặc định (ui_accept) để Roll
	if Input.is_action_just_pressed("roll") or Input.is_action_just_pressed("ui_accept"):
		start_roll(direction)
		return

	# Di chuyển bình thường
	if direction != Vector2.ZERO:
		velocity = direction * speed

		if abs(direction.x) > abs(direction.y):
			# Đi ngang (Trái / Phải)
			if direction.x > 0:
				anim.flip_h = false
				anim.play("walk_right")
				last_direction = "right"
			else:
				anim.flip_h = true  # Lật mặt sprite sang trái
				if anim.sprite_frames.has_animation("walk_left"):
					anim.play("walk_left")
				else:
					anim.play("walk_right")
				last_direction = "left"
		else:
			# Đi dọc (Lên / Xuống)
			anim.flip_h = false
			if direction.y > 0:
				anim.play("walk_down")
				last_direction = "down"
			else:
				anim.play("walk_up")
				last_direction = "up"
	else:
		velocity = Vector2.ZERO
		# Tư thế đứng yên theo hướng nhìn cuối cùng
		if last_direction == "up":
			anim.flip_h = false
			anim.play("stand1")
		elif last_direction == "left":
			anim.flip_h = true
			anim.play("stand")
		else:
			anim.flip_h = false
			anim.play("stand")

	move_and_slide()

# Hàm xử lý Roll có phát hoạt ảnh cuộn tròn
func start_roll(dir: Vector2):
	is_rolling = true
	var roll_dir = dir

	# Nếu đứng yên mà bấm Space thì lướt theo hướng nhìn cuối cùng
	if roll_dir == Vector2.ZERO:
		match last_direction:
			"up": roll_dir = Vector2.UP
			"down": roll_dir = Vector2.DOWN
			"left": roll_dir = Vector2.LEFT
			"right": roll_dir = Vector2.RIGHT

	# Lật ảnh khi lăn sang bên trái
	if roll_dir.x < 0 or (roll_dir.x == 0 and last_direction == "left"):
		anim.flip_h = true
	else:
		anim.flip_h = false

	# Kích hoạt hoạt ảnh rolling
	if anim.sprite_frames.has_animation("rolling"):
		anim.play("rolling")

	velocity = roll_dir * roll_speed

	# Duy trì tốc độ lướt trong khoảng roll_duration rồi dừng
	await get_tree().create_timer(roll_duration).timeout
	is_rolling = false
	velocity = Vector2.ZERO
