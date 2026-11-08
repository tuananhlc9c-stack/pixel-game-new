extends CharacterBody2D

@export var speed: float = 120.0
@export var stop_distance: float = 45.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta):
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
	
	var player = players[0]
	var distance = global_position.distance_to(player.global_position)
	
	if distance > stop_distance:
		# Dùng move_toward để di chuyển bám sát mượt mà tuyệt đối
		global_position = global_position.move_toward(player.global_position, speed * delta)
		
		# Cập nhật hướng animation di chuyển
		var direction = global_position.direction_to(player.global_position)
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
		# Đã đến gần thì đứng chờ và bật hoạt ảnh "stand"
		if anim.sprite_frames and anim.sprite_frames.has_animation("stand"):
			anim.play("stand")
