extends CharacterBody2D

@export var speed: float = 80.0
@export var wander_radius: float = 50.0  # Khoảng cách ngắn đi loanh quanh

@export var move_duration: float = 2.0  # Thời gian di chuyển
@export var idle_duration: float = 3.0  # Thời gian đứng im stand

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var home_position: Vector2
var target_position: Vector2
var timer: float = 0.0
var is_walking: bool = false

func _ready():
	# Lưu vị trí ban đầu làm mốc quanh nhà
	home_position = global_position
	target_position = home_position

func _physics_process(delta):
	timer += delta
	
	# Đổi trạng thái qua lại giữa đi dạo và đứng stand
	if is_walking and timer >= move_duration:
		is_walking = false
		timer = 0.0
	elif not is_walking and timer >= idle_duration:
		is_walking = true
		timer = 0.0
		# Chọn ngẫu nhiên một điểm trong phạm vi gần nhà
		var random_offset = Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
		target_position = home_position + random_offset

	# Nếu đang trong thời gian đi và chưa tới đích
	if is_walking and global_position.distance_to(target_position) > 4.0:
		global_position = global_position.move_toward(target_position, speed * delta)
		
		# Tính toán hướng di chuyển 4 hướng (ưu tiên trục ngang hoặc dọc rõ rệt)
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
