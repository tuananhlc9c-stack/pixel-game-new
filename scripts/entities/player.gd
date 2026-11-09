extends CharacterBody2D

@export var speed: float = 120.0
@export var roll_speed: float = 260.0
@export var roll_duration: float = 0.25
@export var max_health: int = 100
@export var attack_damage: int = 25
@export var attack_knockback: float = 140.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var cam: Camera2D = $Camera2D if has_node("Camera2D") else null
@onready var weapon_pivot: Marker2D = $WeaponPivot if has_node("WeaponPivot") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var hitbox: Area2D = $WeaponPivot/hitbox if has_node("WeaponPivot/hitbox") else null
@onready var slash_effect: AnimatedSprite2D = $WeaponPivot/SlashEffect if has_node("WeaponPivot/SlashEffect") else null

var health_component: HealthComponent
var hp_bar_fill: ColorRect
var hp_label: Label

var last_direction: String = "down"
var is_rolling: bool = false
var is_attacking: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var hit_targets: Array[Node] = []
var initial_spawn_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")

	# 1. Chuẩn hóa tâm nhân vật nếu bị lệch trong scene
	if anim and anim.position != Vector2.ZERO:
		var visual_offset := anim.position
		global_position += visual_offset
		anim.position = Vector2.ZERO
		if col_shape:
			col_shape.position -= visual_offset
		if cam:
			cam.position = Vector2.ZERO

	# 2. Thiết lập trạng thái ban đầu cho vũ khí & kết nối hitbox
	if weapon_pivot:
		weapon_pivot.position = Vector2.ZERO
		weapon_pivot.z_index = 10
		weapon_pivot.hide()

	if hitbox:
		if not hitbox.body_entered.is_connected(_on_weapon_hitbox_body_entered):
			hitbox.body_entered.connect(_on_weapon_hitbox_body_entered)
		if not hitbox.area_entered.is_connected(_on_weapon_hitbox_area_entered):
			hitbox.area_entered.connect(_on_weapon_hitbox_area_entered)
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true

	if slash_effect:
		slash_effect.hide()

	# 3. Khởi tạo Hệ thống Máu (HealthComponent) và HUD
	_setup_health_system()

	# 4. Đặt vị trí spawn khi chuyển cảnh
	if SceneManager and SceneManager.use_spawn_position:
		global_position = SceneManager.spawn_position
		SceneManager.use_spawn_position = false

	initial_spawn_position = global_position

func _setup_health_system() -> void:
	if has_node("HealthComponent"):
		health_component = $HealthComponent
	else:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		health_component.max_health = max_health
		health_component.invincibility_duration = 0.6
		add_child(health_component)

	health_component.max_health = max_health
	if SceneManager and SceneManager.saved_player_health > 0:
		health_component.current_health = min(SceneManager.saved_player_health, max_health)
	else:
		health_component.current_health = max_health

	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_player_died)

	# Tạo HUD thanh máu ở góc trên bên trái màn hình
	var hud := CanvasLayer.new()
	hud.name = "PlayerHUD"
	add_child(hud)

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.15, 0.85)
	bg.position = Vector2(16, 16)
	bg.size = Vector2(144, 18)
	hud.add_child(bg)

	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = Color(0.85, 0.22, 0.25, 1.0)
	hp_bar_fill.position = Vector2(18, 18)
	hp_bar_fill.size = Vector2(140, 14)
	hud.add_child(hp_bar_fill)

	hp_label = Label.new()
	hp_label.position = Vector2(22, 14)
	hp_label.add_theme_font_size_override("font_size", 12)
	hud.add_child(hp_label)

	_on_health_changed(health_component.current_health, health_component.max_health)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		if not is_attacking and not is_rolling:
			start_weapon_swing()

func _physics_process(delta: float) -> void:
	if knockback_velocity.length() > 5.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return

	if is_rolling or is_attacking:
		move_and_slide()
		return

	var input_x := Input.get_axis("move_left", "move_right")
	if input_x == 0:
		input_x = Input.get_axis("ui_left", "ui_right")

	var input_y := Input.get_axis("move_up", "move_down")
	if input_y == 0:
		input_y = Input.get_axis("ui_up", "ui_down")

	var direction := Vector2(input_x, input_y).normalized()

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
func start_weapon_swing() -> void:
	if not weapon_pivot:
		return

	is_attacking = true
	velocity = Vector2.ZERO
	hit_targets.clear()

	# 1. Hiển thị kiếm và các node con
	weapon_pivot.show()
	if has_node("WeaponPivot/WeaponSprite"):
		$WeaponPivot/WeaponSprite.show()

	# 2. Lấy góc hướng về phía chuột
	var local_mouse := get_local_mouse_position()
	if local_mouse.length() < 2.0:
		local_mouse = Vector2.RIGHT

	var mouse_angle := local_mouse.angle()
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
	var target_angle := mouse_angle + deg_to_rad(120)
	var tween := create_tween()
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

func _on_weapon_hitbox_body_entered(body: Node) -> void:
	_apply_weapon_hit(body)

func _on_weapon_hitbox_area_entered(area: Area2D) -> void:
	if area.get_parent() and area.get_parent() != self:
		_apply_weapon_hit(area.get_parent())

func _apply_weapon_hit(target: Node) -> void:
	if not is_attacking or not is_instance_valid(target) or target == self:
		return
	if target in hit_targets:
		return
	if target.has_method("take_damage"):
		hit_targets.append(target)
		target.take_damage(attack_damage, global_position, attack_knockback)

func start_roll(dir: Vector2) -> void:
	is_rolling = true
	var roll_dir := dir

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
	if is_instance_valid(self):
		is_rolling = false
		velocity = Vector2.ZERO

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback_force: float = 140.0) -> void:
	if is_rolling or not health_component or health_component.is_invincible:
		return

	if source_pos != Vector2.ZERO:
		var dir := (global_position - source_pos).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.DOWN
		knockback_velocity = dir * knockback_force

	if anim:
		anim.modulate = Color(2.5, 0.35, 0.35, 1.0)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", Color.WHITE, 0.25)

	health_component.take_damage(amount)

func _on_health_changed(current: int, maximum: int) -> void:
	if SceneManager:
		SceneManager.saved_player_health = current
	if hp_bar_fill and maximum > 0:
		var ratio := clampf(float(current) / float(maximum), 0.0, 1.0)
		hp_bar_fill.size.x = 140.0 * ratio
	if hp_label:
		hp_label.text = "HP: %d / %d" % [current, maximum]

func _on_player_died() -> void:
	# Khi hết máu, hồi phục lại đầy máu và đưa về điểm xuất phát của map hiện tại
	health_component.reset_health()
	global_position = initial_spawn_position
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
