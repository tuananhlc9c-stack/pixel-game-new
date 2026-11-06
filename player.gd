extends CharacterBody2D

@export var speed: float = 120.0
@export var roll_speed: float = 260.0
@export var roll_duration: float = 0.25

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var cam: Camera2D = $Camera2D if has_node("Camera2D") else null
@onready var weapon_pivot: Marker2D = $WeaponPivot
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $WeaponPivot/hitbox if has_node("WeaponPivot/hitbox") else null
@onready var slash_effect: AnimatedSprite2D = $WeaponPivot/SlashEffect if has_node("WeaponPivot/SlashEffect") else null

var last_direction: String = "down"
var is_rolling: bool = false
var is_attacking: bool = false

func _ready():
	# 1. Chuẩn hóa tâm nhân vật nếu bị lệch trong scene
	if anim and anim.position != Vector2.ZERO:
		var visual_offset = anim.position
		global_position += visual_offset
		anim.position = Vector2.ZERO
		if col_shape:
			col_shape.position -= visual_offset
		if cam:
			cam.position = Vector2.ZERO

	# 2. Thiết lập trạng thái ban đầu cho vũ khí
	if weapon_pivot:
		weapon_pivot.position = Vector2.ZERO
		weapon_pivot.z_index = 10
		weapon_pivot.hide()

	if hitbox:
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true

	if slash_effect:
		slash_effect.hide()

	if SceneManager and SceneManager.use_spawn_position:
		set_deferred("global_position", SceneManager.spawn_position)
		SceneManager.use_spawn_position = false

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("attack"):
		if not is_attacking and not is_rolling:
			start_weapon_swing()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_attacking and not is_rolling:
			start_weapon_swing()

func _physics_process(_delta):
	if is_rolling or is_attacking:
		move_and_slide()
		return

	var input_x = Input.get_axis("move_left", "move_right")
	if input_x == 0:
		input_x = Input.get_axis("ui_left", "ui_right")

	var input_y = Input.get_axis("move_up", "move_down")
	if input_y == 0:
		input_y = Input.get_axis("ui_up", "ui_down")

	var direction = Vector2(input_x, input_y).normalized()

	if Input.is_action_just_pressed("roll") or Input.is_action_just_pressed("ui_accept"):
		start_roll(direction)
		return

	if direction != Vector2.ZERO:
		velocity = direction * speed

		if direction.x < 0:
			anim.flip_h = true
			last_direction = "left"
		elif direction.x > 0:
			anim.flip_h = false
			last_direction = "right"

		if abs(direction.x) > abs(direction.y):
			if anim.flip_h and anim.sprite_frames.has_animation("walk_left"):
				anim.play("walk_left")
			else:
				anim.play("walk_right")
		else:
			if direction.y > 0:
				anim.play("walk_down")
				if direction.x == 0:
					last_direction = "down"
			else:
				anim.play("walk_up")
				if direction.x == 0:
					last_direction = "up"
	else:
		velocity = Vector2.ZERO
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

# Cơ chế chém mượt mà quét vòng cung theo hướng chuột
func start_weapon_swing():
	if not weapon_pivot:
		return

	is_attacking = true
	velocity = Vector2.ZERO

	# 1. Hiển thị kiếm và các node con
	weapon_pivot.show()
	if has_node("WeaponPivot/WeaponSprite"):
		$WeaponPivot/WeaponSprite.show()

	# 2. Lấy góc hướng về phía chuột
	var local_mouse = get_local_mouse_position()
	if local_mouse.length() < 2.0:
		local_mouse = Vector2.RIGHT

	var mouse_angle = local_mouse.angle()
	weapon_pivot.position = Vector2.ZERO
	weapon_pivot.rotation = mouse_angle

	# Xoay mặt nhân vật theo hướng chuột
	if abs(local_mouse.x) > abs(local_mouse.y):
		if local_mouse.x < 0:
			anim.flip_h = true
			last_direction = "left"
		else:
			anim.flip_h = false
			last_direction = "right"
	else:
		if local_mouse.y > 0:
			anim.flip_h = false
			last_direction = "down"
		else:
			anim.flip_h = false
			last_direction = "up"

	# Bật hiệu ứng vệt chém (nếu có)
	if slash_effect:
		slash_effect.show()
		slash_effect.frame = 0
		if slash_effect.sprite_frames and slash_effect.sprite_frames.has_animation("slash"):
			slash_effect.play("slash")

	# Bật hitbox gây sát thương
	if hitbox:
		hitbox.show()
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = false

	# 3. Dùng Tween vung quét 120 độ mượt mà từ hướng chuột
	var target_angle = mouse_angle + deg_to_rad(120)
	var tween = create_tween()
	tween.tween_property(weapon_pivot, "rotation", target_angle, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await tween.finished

	# 4. Kết thúc đòn chém: ẩn vũ khí và tắt hitbox
	if hitbox:
		hitbox.hide()
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true

	if slash_effect:
		slash_effect.hide()
		
	weapon_pivot.hide()
	is_attacking = false

func start_roll(dir: Vector2):
	is_rolling = true
	var roll_dir = dir

	if roll_dir == Vector2.ZERO:
		match last_direction:
			"up": roll_dir = Vector2.UP
			"down": roll_dir = Vector2.DOWN
			"left": roll_dir = Vector2.LEFT
			"right": roll_dir = Vector2.RIGHT

	if roll_dir.x < 0 or (roll_dir.x == 0 and last_direction == "left"):
		anim.flip_h = true
	else:
		anim.flip_h = false

	if anim.sprite_frames.has_animation("rolling"):
		anim.play("rolling")

	velocity = roll_dir * roll_speed

	await get_tree().create_timer(roll_duration).timeout
	is_rolling = false
	velocity = Vector2.ZERO
