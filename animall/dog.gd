extends CharacterBody2D

@export var speed: float = 80.0
@export var wander_radius: float = 60.0  # Bán kính đi lại loanh quanh gần nhà

@export var move_duration: float = 2.0  # Thời gian đi dạo
@export var idle_duration: float = 3.0  # Thời gian đứng im stand tại chỗ

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var home_position: Vector2      # Vị trí gốc của ngôi nhà / điểm xuất phát
var target_position: Vector2    # Mục tiêu ngẫu nhiên quanh nhà
var timer: float = 0.0
var is_walking: bool = false

func _ready():
	# Lưu lại vị trí ban đầu đặt chú thú cưng làm mốc "nhà"
	home_position = global_position
	target_position = home_position

func _physics_process(delta):
	timer += delta
	
	# Hết thời gian thì đổi trạng thái giữa Đi dạo và Đứng im (stand)
	if is_walking and timer >= move_duration:
		is_walking = false
		timer = 0.0
	elif not is_walking and timer >= idle_duration:
		is_walking = true
		timer = 0.0
		# Chọn một điểm ngẫu nhiên mới quanh nhà trong bán kính wander_radius
		var random_offset = Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
		target_position = home_position + random_offset

	# Xử lý hành động
	if is_walking and global_position.distance_to(target_position) > 5.0:
		# Di chuyển về điểm ngẫu nhiên quanh nhà
		global_position = global_position.move_toward(target_position, speed * delta)
		
		# Cập nhật animation di chuyển
		var direction = global_position.direction_to(target_position)
		if abs(direction.x) > abs(direction.y):
			anim.flip_h = direction.x < 0
			if anim.sprite_frames.has_animation("walk_right"):
				anim.play("walk_right")
		else:
			if direction.y > 0 and anim.sprite_frames.has_animation("walk_down"):
				anim.play("walk_down")
			elif direction.y < 0 and anim.sprite_frames.has_animation("walk_up"):
				anim.play("walk_up")
	else:
		# Đứng im tại chỗ và phát hoạt ảnh stand
		if anim.sprite_frames and anim.sprite_frames.has_animation("stand"):
			anim.play("stand")
