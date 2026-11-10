extends CharacterBody2D

@export var speed: float = 120.0
@export var roll_speed: float = 260.0
@export var roll_duration: float = 0.25
@export var max_health: int = 100
@export var attack_damage: int = 25
@export var attack_knockback: float = 140.0
@export_group("Special Attack (Right Click)")
@export var special_attack_damage: int = 60
@export var special_attack_knockback: float = 240.0
@export var special_attack_cooldown: float = 3.0
@export var special_attack_scale: float = 1.45
@export var special_lunge_speed: float = 180.0

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
var special_cd_bar_fill: ColorRect
var special_cd_label: Label

var last_direction: String = "down"
var is_rolling: bool = false
var is_attacking: bool = false
var is_special_attacking: bool = false
var special_cooldown_timer: float = 0.0
var current_attack_damage: int = 25
var current_attack_knockback: float = 140.0
var special_wave_progress: float = -1.0
var special_wave_angle: float = 0.0
var swing_combo_dir: int = 1
var combo_reset_timer: float = 0.0
var is_recording_trail: bool = false
var trail_is_special: bool = false
var slash_trail: Array[Dictionary] = []
var swing_tween: Tween = null
var knockback_velocity: Vector2 = Vector2.ZERO
var hit_targets: Array[Node] = []
var initial_spawn_position: Vector2 = Vector2.ZERO

# Hệ thống Câu Cá (Fishing System)
enum FishingState { NONE, CASTING, WAITING, BITE, CAUGHT }
var fishing_state: FishingState = FishingState.NONE
var fishing_timer: float = 0.0
var fishing_time_elapsed: float = 0.0
var bobber_target_local: Vector2 = Vector2.ZERO
var bobber_current_local: Vector2 = Vector2.ZERO
var rod_tip_local: Vector2 = Vector2.ZERO
var held_rod_sprite: Sprite2D = null
var fishing_status_label: Label = null
var caught_fish_sprite: Sprite2D = null

const FISH_POOL: Array[Dictionary] = [
	{"id": "fish_carp", "name": "Carp", "region": Rect2(0, 48, 16, 16)},
	{"id": "fish_perch", "name": "Perch", "region": Rect2(16, 48, 16, 16)},
	{"id": "fish_salmon", "name": "Red Salmon", "region": Rect2(32, 48, 16, 16)},
	{"id": "fish_gold", "name": "Goldfish", "region": Rect2(48, 48, 16, 16)},
	{"id": "fish_tuna", "name": "Tuna", "region": Rect2(80, 48, 16, 16)},
	{"id": "fish_crab", "name": "Red Crab", "region": Rect2(144, 48, 16, 16)},
	{"id": "fish_shrimp", "name": "Silver Shrimp", "region": Rect2(160, 48, 16, 16)},
	{"id": "fish_octopus", "name": "Octopus", "region": Rect2(176, 48, 16, 16)}
]

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
		hitbox.position = Vector2(18, 0)
		if not hitbox.body_entered.is_connected(_on_weapon_hitbox_body_entered):
			hitbox.body_entered.connect(_on_weapon_hitbox_body_entered)
		if not hitbox.area_entered.is_connected(_on_weapon_hitbox_area_entered):
			hitbox.area_entered.connect(_on_weapon_hitbox_area_entered)
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.position = Vector2.ZERO
				child.disabled = true

	if slash_effect:
		slash_effect.hide()

	# 3. Khởi tạo Hệ thống Máu (HealthComponent) và HUD
	_setup_health_system()
	_setup_fishing_visuals()

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

	# Thanh hiển thị hồi chiêu Chém Đặc Biệt (Chuột Phải) ngay dưới thanh máu
	var cd_bg := ColorRect.new()
	cd_bg.color = Color(0.12, 0.12, 0.15, 0.85)
	cd_bg.position = Vector2(16, 38)
	cd_bg.size = Vector2(144, 14)
	hud.add_child(cd_bg)

	special_cd_bar_fill = ColorRect.new()
	special_cd_bar_fill.color = Color(0.95, 0.72, 0.18, 1.0)
	special_cd_bar_fill.position = Vector2(18, 40)
	special_cd_bar_fill.size = Vector2(140, 10)
	hud.add_child(special_cd_bar_fill)

	special_cd_label = Label.new()
	special_cd_label.position = Vector2(22, 36)
	special_cd_label.add_theme_font_size_override("font_size", 10)
	hud.add_child(special_cd_label)

	_on_health_changed(health_component.current_health, health_component.max_health)
	_update_special_cooldown_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		if _is_holding_fishing_rod():
			_handle_fishing_action()
			return
		elif fishing_state != FishingState.NONE:
			_cancel_fishing()
			return
		if not is_attacking and not is_rolling:
			start_weapon_swing(false)
	elif event.is_action_pressed("special_attack") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		if fishing_state != FishingState.NONE:
			_cancel_fishing("Canceled")
			return
		if not is_attacking and not is_rolling:
			if special_cooldown_timer <= 0.0:
				start_weapon_swing(true)
			else:
				_flash_cooldown_warning()

func _physics_process(delta: float) -> void:
	if special_cooldown_timer > 0.0:
		special_cooldown_timer = maxf(0.0, special_cooldown_timer - delta)
		_update_special_cooldown_ui()

	if combo_reset_timer > 0.0:
		combo_reset_timer = maxf(0.0, combo_reset_timer - delta)
		if combo_reset_timer <= 0.0:
			swing_combo_dir = 1

	# Cập nhật vệt kiếm động mượt mà theo từng khung hình
	_update_slash_trail(delta)
	_update_fishing(delta)

	if special_wave_progress >= 0.0:
		special_wave_progress += delta * 4.2
		if special_wave_progress > 1.0:
			special_wave_progress = -1.0
		queue_redraw()

	# Quét va chạm liên tục trong lúc vung kiếm để đòn chém nhanh không bỏ sót mục tiêu
	if is_attacking and hitbox:
		for body in hitbox.get_overlapping_bodies():
			_apply_weapon_hit(body)
		for area in hitbox.get_overlapping_areas():
			_on_weapon_hitbox_area_entered(area)

	if knockback_velocity.length() > 5.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return

	if is_rolling:
		move_and_slide()
		return

	var input_x := Input.get_axis("move_left", "move_right")
	if input_x == 0:
		input_x = Input.get_axis("ui_left", "ui_right")

	var input_y := Input.get_axis("move_up", "move_down")
	if input_y == 0:
		input_y = Input.get_axis("ui_up", "ui_down")

	var direction := Vector2(input_x, input_y).normalized()

	# Nếu đang thả câu mà di chuyển hoặc lộn nhào thì tự động thu dây câu
	if fishing_state != FishingState.NONE:
		if direction != Vector2.ZERO or Input.is_action_just_pressed("roll") or Input.is_action_just_pressed("ui_accept"):
			if fishing_state != FishingState.CAUGHT:
				_cancel_fishing()
		else:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	# Khi đang chém: cho phép di chuyển mượt hoặc trượt theo quán tính thay vì khựng cứng
	if is_attacking:
		if is_special_attacking:
			velocity = velocity.move_toward(direction * (speed * 0.45), 520.0 * delta)
		else:
			var target_move := direction * (speed * 0.65)
			velocity = velocity.move_toward(target_move, 650.0 * delta)
		move_and_slide()
		return

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

# Cơ chế chém 3 giai đoạn mượt mà (Lấy đà -> Vung chém tốc độ cao -> Thu kiếm) + Đảo chiều Combo
func start_weapon_swing(is_special: bool = false) -> void:
	if not weapon_pivot:
		return

	if swing_tween and swing_tween.is_valid():
		swing_tween.kill()

	is_attacking = true
	is_special_attacking = is_special
	hit_targets.clear()

	var swing_dir: float = float(swing_combo_dir)
	if not is_special:
		swing_combo_dir *= -1
		combo_reset_timer = 0.75
	else:
		swing_dir = 1.0

	# Thiết lập sát thương, lực đẩy lùi và hồi chiêu
	if is_special:
		current_attack_damage = special_attack_damage
		current_attack_knockback = special_attack_knockback
		special_cooldown_timer = special_attack_cooldown
		_update_special_cooldown_ui()
	else:
		current_attack_damage = attack_damage
		current_attack_knockback = attack_knockback

	# 1. Hiển thị kiếm (ẩn tấm ảnh vệt chém tĩnh 1-frame để dùng vệt kiếm bán nguyệt động 60fps mượt hơn)
	weapon_pivot.show()
	weapon_pivot.modulate.a = 1.0
	if slash_effect:
		slash_effect.hide()

	var weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite if has_node("WeaponPivot/WeaponSprite") else null
	if weapon_sprite:
		weapon_sprite.show()
		weapon_sprite.scale = Vector2(1.014, 0.97)

	# 2. Lấy góc hướng về phía chuột
	var local_mouse := get_local_mouse_position()
	if local_mouse.length() < 2.0:
		local_mouse = Vector2.RIGHT

	var mouse_dir := local_mouse.normalized()
	var mouse_angle := local_mouse.angle()
	weapon_pivot.position = Vector2.ZERO

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

	# Tính toán góc lấy đà, góc bắt đầu và góc kết thúc đối xứng quanh con trỏ chuột
	var half_arc := deg_to_rad(125.0 if is_special else 68.0)
	var windup_start := mouse_angle - (half_arc - deg_to_rad(22.0)) * swing_dir
	var slash_start := mouse_angle - half_arc * swing_dir
	var slash_end := mouse_angle + half_arc * swing_dir
	var follow_end := slash_end + deg_to_rad(16.0) * swing_dir
	var base_scale := special_attack_scale if is_special else 1.0

	weapon_pivot.rotation = windup_start
	weapon_pivot.scale = Vector2.ONE * (base_scale * 0.88)

	if is_special:
		velocity = mouse_dir * special_lunge_speed
		special_wave_angle = mouse_angle
		special_wave_progress = 0.0
		if weapon_sprite:
			weapon_sprite.modulate = Color(2.3, 1.4, 0.35, 1.0)
		if anim:
			anim.modulate = Color(1.6, 1.35, 0.65, 1.0)
	else:
		# Nhích nhẹ về phía trước theo hướng chém để tạo cảm giác có lực
		velocity = velocity * 0.55 + mouse_dir * 48.0
		if weapon_sprite:
			weapon_sprite.modulate = Color(1.25, 1.25, 1.35, 1.0)

	# 3. Giai đoạn 1: Lấy đà nhanh (Wind-up) + Nén nhẹ người
	var windup_time := 0.055 if is_special else 0.035
	var slash_time := 0.19 if is_special else 0.13
	var follow_time := 0.075 if is_special else 0.055

	swing_tween = create_tween()
	swing_tween.set_parallel(true)
	swing_tween.tween_property(weapon_pivot, "rotation", slash_start, windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(weapon_pivot, "scale", Vector2.ONE * base_scale, windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if anim:
		swing_tween.tween_property(anim, "scale", Vector2(1.12, 0.9), windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		swing_tween.tween_property(anim, "rotation", deg_to_rad(-5.0 * swing_dir), windup_time)

	await swing_tween.finished
	if not is_instance_valid(self):
		return

	# 4. Giai đoạn 2: Vung kiếm tốc độ cao (Main Slash) + Bật Hitbox + Bật Vệt Kiếm Động
	slash_trail.clear()
	is_recording_trail = true
	trail_is_special = is_special

	if hitbox:
		hitbox.show()
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = false

	swing_tween = create_tween()
	swing_tween.tween_property(weapon_pivot, "rotation", slash_end, slash_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Phóng nhẹ kích thước kiếm ở đỉnh vòng vung tạo độ vươn mượt mà
	var scale_tween := create_tween()
	scale_tween.tween_property(weapon_pivot, "scale", Vector2.ONE * (base_scale * 1.16), slash_time * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(weapon_pivot, "scale", Vector2.ONE * base_scale, slash_time * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if anim:
		var body_tween := create_tween().set_parallel(true)
		body_tween.tween_property(anim, "scale", Vector2(0.94, 1.07), slash_time * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		body_tween.tween_property(anim, "rotation", deg_to_rad(6.0 * swing_dir), slash_time * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await swing_tween.finished
	if not is_instance_valid(self):
		return

	# 5. Giai đoạn 3: Thu kiếm theo quán tính & mờ dần (Follow-through)
	is_recording_trail = false
	if hitbox:
		hitbox.hide()
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true

	# Mở khóa di chuyển và cho phép nối đòn sớm ngay khi bước vào giai đoạn thu kiếm
	is_special_attacking = false
	is_attacking = false

	swing_tween = create_tween()
	swing_tween.set_parallel(true)
	swing_tween.tween_property(weapon_pivot, "rotation", follow_end, follow_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(weapon_pivot, "scale", Vector2.ONE * (base_scale * 0.85), follow_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing_tween.tween_property(weapon_pivot, "modulate:a", 0.0, follow_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if anim:
		swing_tween.tween_property(anim, "scale", Vector2.ONE, follow_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		swing_tween.tween_property(anim, "rotation", 0.0, follow_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if is_special:
			swing_tween.tween_property(anim, "modulate", Color.WHITE, follow_time)

	await swing_tween.finished
	if not is_instance_valid(self):
		return

	if not is_attacking:
		if weapon_sprite:
			weapon_sprite.modulate = Color.WHITE
			weapon_sprite.scale = Vector2(1.014, 0.97)
		weapon_pivot.modulate.a = 1.0
		weapon_pivot.scale = Vector2.ONE
		weapon_pivot.hide()

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
		target.take_damage(current_attack_damage, global_position, current_attack_knockback)

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
	if fishing_state != FishingState.NONE:
		_cancel_fishing()

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
	special_cooldown_timer = 0.0
	_update_special_cooldown_ui()

func _update_special_cooldown_ui() -> void:
	if not special_cd_bar_fill or not special_cd_label:
		return

	if special_cooldown_timer <= 0.0:
		special_cd_bar_fill.size.x = 140.0
		special_cd_bar_fill.color = Color(0.95, 0.72, 0.18, 1.0)
		special_cd_label.text = "Chuột Phải: SẴN SÀNG"
	else:
		var ratio := 1.0 - clampf(special_cooldown_timer / maxf(special_attack_cooldown, 0.01), 0.0, 1.0)
		special_cd_bar_fill.size.x = 140.0 * ratio
		special_cd_bar_fill.color = Color(0.45, 0.45, 0.55, 0.9)
		special_cd_label.text = "Hồi chiêu: %.1fs" % special_cooldown_timer

func _flash_cooldown_warning() -> void:
	if not special_cd_label:
		return
	special_cd_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
	var tween := create_tween()
	tween.tween_property(special_cd_label, "modulate", Color.WHITE, 0.25)

func _update_slash_trail(delta: float) -> void:
	var max_life := 0.14 if trail_is_special else 0.095
	var changed := false

	# Giảm thời gian sống của các điểm trên vệt kiếm cũ
	for i in range(slash_trail.size() - 1, -1, -1):
		slash_trail[i]["age"] += delta
		if slash_trail[i]["age"] >= max_life:
			slash_trail.remove_at(i)
		changed = true

	# Ghi nhận góc kiếm hiện tại và nội suy thêm các điểm trung gian để đường cong mượt tuyệt đối
	if is_recording_trail and weapon_pivot:
		var cur_angle := weapon_pivot.rotation
		var cur_scale := weapon_pivot.scale.x
		if slash_trail.size() > 0:
			var prev_angle: float = slash_trail[slash_trail.size() - 1]["angle"]
			var prev_scale: float = slash_trail[slash_trail.size() - 1]["scale"]
			var diff := cur_angle - prev_angle
			var steps := clampi(int(abs(diff) / deg_to_rad(6.0)), 1, 8)
			for s in range(1, steps + 1):
				var t := float(s) / float(steps)
				slash_trail.append({
					"angle": lerpf(prev_angle, cur_angle, t),
					"scale": lerpf(prev_scale, cur_scale, t),
					"age": delta * (1.0 - t)
				})
		else:
			slash_trail.append({
				"angle": cur_angle,
				"scale": cur_scale,
				"age": 0.0
			})
		changed = true

	if changed:
		queue_redraw()

func _draw() -> void:
	# 1. Vẽ vệt kiếm bán nguyệt động (Dynamic Crescent Slash Ribbon) mượt theo lưỡi kiếm
	if slash_trail.size() >= 2:
		var max_life := 0.14 if trail_is_special else 0.095
		var count := slash_trail.size()
		for i in range(count - 1):
			var p0: Dictionary = slash_trail[i]
			var p1: Dictionary = slash_trail[i + 1]
			var t0 := float(i) / float(count - 1)
			var t1 := float(i + 1) / float(count - 1)

			var life0 := clampf(1.0 - (float(p0["age"]) / max_life), 0.0, 1.0)
			var life1 := clampf(1.0 - (float(p1["age"]) / max_life), 0.0, 1.0)

			# Độ dày vệt kiếm thon nhọn ở đuôi và phình to ở đầu lưỡi kiếm
			var profile0 := sin(t0 * PI * 0.82) * life0
			var profile1 := sin(t1 * PI * 0.82) * life1

			var outer_r0 := 25.0 * float(p0["scale"])
			var outer_r1 := 25.0 * float(p1["scale"])
			var thickness0 := (13.5 if trail_is_special else 9.0) * profile0 * float(p0["scale"])
			var thickness1 := (13.5 if trail_is_special else 9.0) * profile1 * float(p1["scale"])

			var dir0 := Vector2.RIGHT.rotated(float(p0["angle"]))
			var dir1 := Vector2.RIGHT.rotated(float(p1["angle"]))

			var out0 := dir0 * outer_r0
			var out1 := dir1 * outer_r1
			var in0 := dir0 * maxf(4.0, outer_r0 - thickness0)
			var in1 := dir1 * maxf(4.0, outer_r1 - thickness1)

			var alpha := (life0 + life1) * 0.5 * t1
			var glow_col := Color(1.0, 0.42, 0.12, alpha * 0.65) if trail_is_special else Color(0.55, 0.88, 1.0, alpha * 0.48)
			var core_col := Color(1.0, 0.94, 0.45, alpha * 0.95) if trail_is_special else Color(1.0, 1.0, 1.0, alpha * 0.9)

			# Lớp hào quang bên ngoài
			draw_colored_polygon(PackedVector2Array([out0, out1, in1, in0]), glow_col)

			# Lõi sáng sắc nét ở rìa lưỡi kiếm
			var core_in0 := dir0 * maxf(4.0, outer_r0 - thickness0 * 0.48)
			var core_in1 := dir1 * maxf(4.0, outer_r1 - thickness1 * 0.48)
			draw_colored_polygon(PackedVector2Array([out0, out1, core_in1, core_in0]), core_col)

	# 2. Vẽ vòng cung sóng kiếm lan tỏa khi tung đòn Chém Đặc Biệt (Chuột Phải)
	if special_wave_progress >= 0.0:
		var radius := lerpf(18.0, 48.0, special_wave_progress)
		var alpha := 1.0 - special_wave_progress
		var start_ang := special_wave_angle - deg_to_rad(80)
		var end_ang := special_wave_angle + deg_to_rad(80)
		draw_arc(Vector2.ZERO, radius, start_ang, end_ang, 32, Color(1.0, 0.82, 0.25, alpha * 0.9), 4.0)
		draw_arc(Vector2.ZERO, radius - 4.5, start_ang, end_ang, 32, Color(1.0, 0.35, 0.15, alpha * 0.65), 2.5)

	# 3. Vẽ dây câu và phao câu cá
	if fishing_state in [FishingState.CASTING, FishingState.WAITING, FishingState.BITE]:
		_draw_fishing_line_and_bobber()

# ----------------- HỆ THỐNG CÂU CÁ ĐƠN GIẢN -----------------
func _setup_fishing_visuals() -> void:
	var tools_tex := load("res://Content T1/Tilesheet/Tools1_tilet.png") as Texture2D
	held_rod_sprite = Sprite2D.new()
	held_rod_sprite.name = "HeldRodSprite"
	held_rod_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tools_tex:
		var atlas := AtlasTexture.new()
		atlas.atlas = tools_tex
		atlas.region = Rect2(0, 144, 16, 16)
		held_rod_sprite.texture = atlas
	held_rod_sprite.z_index = 6
	held_rod_sprite.visible = false
	add_child(held_rod_sprite)

	caught_fish_sprite = Sprite2D.new()
	caught_fish_sprite.name = "CaughtFishSprite"
	caught_fish_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	caught_fish_sprite.position = Vector2(0, -24)
	caught_fish_sprite.z_index = 15
	caught_fish_sprite.visible = false
	add_child(caught_fish_sprite)

	fishing_status_label = Label.new()
	fishing_status_label.name = "FishingStatusLabel"
	fishing_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fishing_status_label.position = Vector2(-90, -38)
	fishing_status_label.size = Vector2(180, 24)
	fishing_status_label.z_index = 20
	fishing_status_label.add_theme_font_size_override("font_size", 10)
	fishing_status_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.75, 1.0))
	fishing_status_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 1.0))
	fishing_status_label.add_theme_constant_override("outline_size", 3)
	fishing_status_label.visible = false
	add_child(fishing_status_label)

func _is_holding_fishing_rod() -> bool:
	var inv = get_tree().get_first_node_in_group("inventory")
	if inv and inv.has_method("is_holding_fishing_rod"):
		return inv.is_holding_fishing_rod()
	return false

func _handle_fishing_action() -> void:
	if is_attacking or is_rolling:
		return

	if fishing_state == FishingState.NONE:
		_try_cast_fishing_rod()
	elif fishing_state == FishingState.BITE:
		_catch_fish_success()
	elif fishing_state in [FishingState.CASTING, FishingState.WAITING]:
		_cancel_fishing("Too early!")

func _try_cast_fishing_rod() -> void:
	var local_mouse := get_local_mouse_position()
	if local_mouse.length() < 4.0:
		local_mouse = Vector2.DOWN * 48.0

	# Xoay hướng nhân vật về phía quăng câu
	if abs(local_mouse.x) > abs(local_mouse.y):
		if local_mouse.x < 0:
			anim.flip_h = true
			last_direction = "left"
		else:
			anim.flip_h = false
			last_direction = "right"
		anim.play("stand")
	else:
		anim.flip_h = false
		if local_mouse.y > 0:
			last_direction = "down"
			anim.play("stand")
		else:
			last_direction = "up"
			anim.play("stand1")

	var water_world_pos := _find_water_target(local_mouse)
	if water_world_pos == Vector2.INF:
		_show_fishing_message("Stand near water to fish!", Color(1.0, 0.55, 0.45, 1.0), 1.4)
		return

	velocity = Vector2.ZERO
	fishing_state = FishingState.CASTING
	fishing_timer = 0.22
	fishing_time_elapsed = 0.0

	bobber_target_local = to_local(water_world_pos)
	_update_rod_pose(bobber_target_local)
	bobber_current_local = rod_tip_local

	_show_fishing_message("Casting...", Color(0.75, 0.92, 1.0, 1.0))
	queue_redraw()

func _update_rod_pose(target_local: Vector2) -> void:
	if not held_rod_sprite:
		return
	held_rod_sprite.visible = true
	var dir := target_local.normalized()
	held_rod_sprite.position = dir * 9.0 + Vector2(0, -2)
	held_rod_sprite.flip_h = (dir.x < 0)
	held_rod_sprite.rotation = dir.angle() * 0.35 if dir.x >= 0 else (PI - dir.angle()) * -0.35
	rod_tip_local = held_rod_sprite.position + dir * 8.0 + Vector2(0, -4)

func _find_water_target(local_mouse: Vector2) -> Vector2:
	var dir := local_mouse.normalized()
	var click_dist := clampf(local_mouse.length(), 28.0, 110.0)
	var preferred_world := global_position + dir * click_dist
	if _is_water_at_world_pos(preferred_world):
		return preferred_world

	# Tìm các điểm dọc theo hướng chuột trỏ tới (từ gần ra xa)
	var distances: Array[float] = [32.0, 48.0, 64.0, 80.0, 96.0, 112.0]
	for d: float in distances:
		var test_pos: Vector2 = global_position + dir * d
		if _is_water_at_world_pos(test_pos):
			return test_pos

	# Quét góc lân cận nếu người chơi bấm hơi lệch mép nước
	var angles: Array[float] = [-25.0, 25.0, -50.0, 50.0]
	var near_distances: Array[float] = [40.0, 64.0, 88.0]
	for angle_deg: float in angles:
		var rot_dir: Vector2 = dir.rotated(deg_to_rad(angle_deg))
		for d: float in near_distances:
			var test_pos: Vector2 = global_position + rot_dir * d
			if _is_water_at_world_pos(test_pos):
				return test_pos

	return Vector2.INF

func _is_water_at_world_pos(world_pos: Vector2) -> bool:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return false

	# 1. Kiểm tra lớp nước có shader water_caustics (ví dụ: TileMapLayer/TileMapLayer trong farm house.tscn)
	var water_overlay := scene_root.get_node_or_null("TileMapLayer/TileMapLayer") as TileMapLayer
	if water_overlay:
		var cell := water_overlay.local_to_map(water_overlay.to_local(world_pos))
		if water_overlay.get_cell_source_id(cell) != -1:
			return true

	# 2. Kiểm tra TileMapLayer gốc có dùng source_id == 2 (Water green_tilet.png) không
	var base_layer := scene_root.get_node_or_null("TileMapLayer") as TileMapLayer
	if base_layer:
		var cell := base_layer.local_to_map(base_layer.to_local(world_pos))
		if base_layer.get_cell_source_id(cell) == 2:
			return true

	return false

func _update_fishing(delta: float) -> void:
	if fishing_state == FishingState.NONE:
		if held_rod_sprite:
			held_rod_sprite.visible = _is_holding_fishing_rod() and not is_attacking and not is_rolling
			if held_rod_sprite.visible:
				var side := -1.0 if anim.flip_h else 1.0
				held_rod_sprite.position = Vector2(7.0 * side, 0.0)
				held_rod_sprite.flip_h = anim.flip_h
				held_rod_sprite.rotation = 0.0
		return

	if not _is_holding_fishing_rod() and fishing_state != FishingState.CAUGHT:
		_cancel_fishing()
		return

	fishing_time_elapsed += delta
	fishing_timer -= delta

	match fishing_state:
		FishingState.CASTING:
			var t := 1.0 - clampf(fishing_timer / 0.22, 0.0, 1.0)
			bobber_current_local = rod_tip_local.lerp(bobber_target_local, t) + Vector2(0, -sin(t * PI) * 14.0)
			if fishing_timer <= 0.0:
				bobber_current_local = bobber_target_local
				fishing_state = FishingState.WAITING
				fishing_timer = randf_range(1.5, 3.0)
				_show_fishing_message("Fishing...", Color(0.85, 0.95, 1.0, 1.0))
			queue_redraw()

		FishingState.WAITING:
			bobber_current_local = bobber_target_local + Vector2(0, sin(fishing_time_elapsed * 4.5) * 1.5)
			if fishing_timer <= 0.0:
				fishing_state = FishingState.BITE
				fishing_timer = 1.35
				_show_fishing_message("! BITE ! (Left Click)", Color(1.0, 0.9, 0.2, 1.0))
			queue_redraw()

		FishingState.BITE:
			bobber_current_local = bobber_target_local + Vector2(randf_range(-1.5, 1.5), sin(fishing_time_elapsed * 26.0) * 3.5 + 2.0)
			if fishing_timer <= 0.0:
				_cancel_fishing("Fish got away...")
			queue_redraw()

		FishingState.CAUGHT:
			if fishing_timer <= 0.0:
				fishing_state = FishingState.NONE
				if caught_fish_sprite:
					caught_fish_sprite.visible = false
				if fishing_status_label:
					fishing_status_label.visible = false
				queue_redraw()

func _catch_fish_success() -> void:
	var fish_info: Dictionary = FISH_POOL[randi() % FISH_POOL.size()]
	var fish_tex_sheet := load("res://Content T1/Loose/Fish-food.png") as Texture2D
	var fish_scene := load("res://scenes/objects/fish_item.tscn") as PackedScene

	var fish_icon := AtlasTexture.new()
	fish_icon.atlas = fish_tex_sheet
	fish_icon.region = fish_info["region"]

	var inv = get_tree().get_first_node_in_group("inventory")
	var added := false
	if inv and inv.has_method("add_item"):
		added = inv.add_item(fish_icon, fish_scene, fish_info["id"], fish_info["name"])

	if added:
		_show_fishing_message("Caught: %s!" % fish_info["name"], Color(0.45, 1.0, 0.55, 1.0), 1.6)
	else:
		_show_fishing_message("Inventory Full!", Color(1.0, 0.45, 0.4, 1.0), 1.6)

	if caught_fish_sprite:
		caught_fish_sprite.texture = fish_icon
		caught_fish_sprite.visible = true
		caught_fish_sprite.position = bobber_target_local
		caught_fish_sprite.scale = Vector2(0.5, 0.5)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(caught_fish_sprite, "position", Vector2(0, -24), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(caught_fish_sprite, "scale", Vector2(1.15, 1.15), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	fishing_state = FishingState.CAUGHT
	fishing_timer = 1.2
	queue_redraw()

func _cancel_fishing(msg: String = "") -> void:
	fishing_state = FishingState.NONE
	if caught_fish_sprite:
		caught_fish_sprite.visible = false
	if msg != "":
		_show_fishing_message(msg, Color(1.0, 0.65, 0.45, 1.0), 1.1)
	else:
		if fishing_status_label:
			fishing_status_label.visible = false
	queue_redraw()

func _show_fishing_message(text: String, color: Color = Color.WHITE, auto_hide_delay: float = 0.0) -> void:
	if not fishing_status_label:
		return
	fishing_status_label.text = text
	fishing_status_label.add_theme_color_override("font_color", color)
	fishing_status_label.visible = true
	if auto_hide_delay > 0.0:
		var current_text := text
		get_tree().create_timer(auto_hide_delay).timeout.connect(func():
			if is_instance_valid(fishing_status_label) and fishing_status_label.text == current_text and fishing_state == FishingState.NONE:
				fishing_status_label.visible = false
		)

func _draw_fishing_line_and_bobber() -> void:
	# Vẽ đường dây câu hơi võng tự nhiên
	var segments := 12
	var prev_pt := rod_tip_local
	var sag_amount := 6.0 if fishing_state != FishingState.BITE else 1.5
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var pt := rod_tip_local.lerp(bobber_current_local, t)
		pt.y += sin(t * PI) * sag_amount
		draw_line(prev_pt, pt, Color(0.92, 0.95, 1.0, 0.85), 1.2)
		prev_pt = pt

	# Vẽ vòng gợn nước quanh phao
	var ripple_r := 4.5 + sin(fishing_time_elapsed * 6.0) * 1.5
	if fishing_state == FishingState.BITE:
		ripple_r = 6.5 + fmod(fishing_time_elapsed * 18.0, 5.0)
	draw_arc(bobber_current_local + Vector2(0, 2), ripple_r, 0.0, TAU, 16, Color(0.85, 0.96, 1.0, 0.55), 1.0)

	# Vẽ phao câu đỏ - trắng
	draw_circle(bobber_current_local + Vector2(0, 1), 3.2, Color(0.9, 0.2, 0.2, 1.0))
	draw_circle(bobber_current_local + Vector2(0, -1), 2.4, Color(0.98, 0.98, 0.98, 1.0))
