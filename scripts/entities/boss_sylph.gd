extends CharacterBody2D

@export var boss_title: String = "SYLPH - NỮ THẦN BÃO TỐ"
@export var aggro_range: float = 310.0
@export var move_speed: float = 58.0
@export var dash_speed: float = 230.0
@export var contact_damage: int = 15
@export var lightning_damage: int = 28
@export var lightning_radius: float = 42.0
@export var knockback_force: float = 230.0
@export var projectile_scene: PackedScene = preload("res://scenes/entities/fireball_projectile.tscn")
@export var boss_sheet_tex: Texture2D = preload("res://Content T1/Character/Monter/Boss/Boss2.png")

enum State { IDLE, FLOAT_CHASE, CAST_LIGHTNING, CAST_ORB_BARRAGE, CAST_HOMING_ORB, TEMPEST_DASH }
var current_state: State = State.IDLE

var player: Node2D = null
var is_enraged: bool = false
var spawn_origin: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var hover_time: float = 0.0
var attack_cycle: int = 0
var dash_target: Vector2 = Vector2.ZERO
var spiral_angle: float = 0.0
var orb_sprite_frames: SpriteFrames = null

# Danh sách các vùng Thiên Lôi giáng xuống: { "pos": Vector2, "timer": float, "max_time": float, "struck": float }
var lightning_zones: Array[Dictionary] = []

# Boss UI
var boss_hud: CanvasLayer = null
var hp_bar: ProgressBar = null
var title_label: Label = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_comp: HealthComponent = $HealthComponent
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	spawn_origin = global_position
	state_timer = 0.9

	if health_comp:
		health_comp.died.connect(_on_died)
		health_comp.health_changed.connect(_on_health_changed)
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	if anim:
		anim.play("idle")

	_build_orb_sprite_frames()
	_create_boss_hud()

func _build_orb_sprite_frames() -> void:
	if not boss_sheet_tex:
		return
	orb_sprite_frames = SpriteFrames.new()
	orb_sprite_frames.add_animation("orb")
	orb_sprite_frames.set_animation_loop("orb", true)
	orb_sprite_frames.set_animation_speed("orb", 10.0)
	var rects := [
		Rect2(18, 322, 28, 28),
		Rect2(50, 322, 28, 28),
		Rect2(82, 322, 28, 28),
		Rect2(113, 320, 28, 28),
		Rect2(146, 322, 28, 28)
	]
	for r: Rect2 in rects:
		var at := AtlasTexture.new()
		at.atlas = boss_sheet_tex
		at.region = r
		orb_sprite_frames.add_frame("orb", at)

func _create_boss_hud() -> void:
	boss_hud = CanvasLayer.new()
	boss_hud.visible = false
	add_child(boss_hud)

	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	container.custom_minimum_size = Vector2(0, 42)
	boss_hud.add_child(container)

	title_label = Label.new()
	title_label.text = boss_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 8)
	title_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_label.position = Vector2(80, 4)
	title_label.size = Vector2(320, 14)
	container.add_child(title_label)

	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.position = Vector2(110, 18)
	hp_bar.size = Vector2(260, 8)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.16, 0.14, 0.92)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.3, 0.95, 0.7, 1.0)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.18, 0.9, 0.58, 1.0)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	if health_comp:
		hp_bar.max_value = health_comp.max_health
		hp_bar.value = health_comp.current_health
	container.add_child(hp_bar)

func _physics_process(delta: float) -> void:
	hover_time += delta
	if anim:
		# Hiệu ứng bay lơ lửng mềm mại trên không trung
		anim.position.y = -12.0 + sin(hover_time * 3.6) * 4.0

	_update_lightning_zones(delta)
	_find_player()
	if not player or not is_instance_valid(player):
		return

	var dist: float = global_position.distance_to(player.global_position)
	if boss_hud:
		boss_hud.visible = dist <= aggro_range * 1.45

	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			if dist <= aggro_range:
				state_timer -= delta
				if state_timer <= 0.0:
					current_state = State.FLOAT_CHASE
					state_timer = 1.0 if is_enraged else 1.4
					if anim:
						anim.play("idle")

		State.FLOAT_CHASE:
			var to_player := player.global_position - global_position
			if to_player.length() > 75.0:
				velocity = to_player.normalized() * (move_speed * (1.28 if is_enraged else 1.0))
			else:
				velocity = Vector2.ZERO

			if anim and abs(to_player.x) > 4.0:
				anim.flip_h = to_player.x < 0.0

			state_timer -= delta
			if state_timer <= 0.0:
				_choose_next_attack()

		State.CAST_LIGHTNING:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				current_state = State.FLOAT_CHASE
				state_timer = 0.85 if is_enraged else 1.25
				if anim:
					anim.play("idle")

		State.CAST_ORB_BARRAGE:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				current_state = State.FLOAT_CHASE
				state_timer = 0.8 if is_enraged else 1.2
				if anim:
					anim.play("idle")

		State.CAST_HOMING_ORB:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				_spawn_homing_lightning_orb()
				current_state = State.FLOAT_CHASE
				state_timer = 0.9 if is_enraged else 1.35
				if anim:
					anim.play("idle")

		State.TEMPEST_DASH:
			var to_target := dash_target - global_position
			state_timer -= delta
			queue_redraw()
			if to_target.length() <= 10.0 or state_timer <= 0.0 or is_on_wall():
				velocity = Vector2.ZERO
				_fire_radial_burst()
				current_state = State.FLOAT_CHASE
				state_timer = 0.75 if is_enraged else 1.15
				if anim:
					anim.play("idle")
			else:
				velocity = to_target.normalized() * (dash_speed * (1.2 if is_enraged else 1.0))

	move_and_slide()

func _choose_next_attack() -> void:
	attack_cycle += 1
	var mode := attack_cycle % 4
	if mode == 1:
		_start_cast_orb_barrage()
	elif mode == 2:
		_start_cast_homing_orb()
	elif mode == 3:
		_start_cast_lightning()
	else:
		_start_tempest_dash()

func _start_cast_lightning() -> void:
	current_state = State.CAST_LIGHTNING
	state_timer = 0.65 if is_enraged else 0.8
	if anim:
		anim.play("cast")

	if not player or not is_instance_valid(player):
		return

	var bolt_count: int = 5 if is_enraged else 3
	var warn_time: float = 0.68 if is_enraged else 0.82
	for i in range(bolt_count):
		var offset := Vector2.ZERO
		if i > 0:
			var ang := (TAU / float(bolt_count - 1)) * float(i - 1) + randf_range(-0.35, 0.35)
			offset = Vector2.RIGHT.rotated(ang) * randf_range(36.0, 78.0)
		lightning_zones.append({
			"pos": player.global_position + offset,
			"timer": warn_time,
			"max_time": warn_time,
			"struck": -1.0
		})
	queue_redraw()

func _start_cast_orb_barrage() -> void:
	current_state = State.CAST_ORB_BARRAGE
	state_timer = 0.55 if is_enraged else 0.65
	if anim:
		anim.play("cast")
	_fire_lightning_orbs()
	queue_redraw()

# Triệu hồi 5 quả cầu sét dàn ngang rồi bay thẳng theo hướng Player
func _fire_lightning_orbs() -> void:
	if not projectile_scene or not get_parent() or not player or not is_instance_valid(player):
		return

	var base_dir := (player.global_position - global_position).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.DOWN

	var horizontal_offsets := [-48.0, -24.0, 0.0, 24.0, 48.0]
	var spd := 155.0 if is_enraged else 130.0
	var center_row_pos := global_position + Vector2(0.0, -18.0)
	for x_off: float in horizontal_offsets:
		var proj: Node2D = projectile_scene.instantiate()
		proj.global_position = global_position + Vector2(x_off, -18.0)
		proj.shooter = self
		if proj.has_method("setup_lightning_orb"):
			proj.setup_lightning_orb(orb_sprite_frames, base_dir, spd, 15, 0.38, false, 3.8)
			proj.lock_dir_on_launch = true
			proj.row_origin_pos = center_row_pos
		elif proj.has_method("setup"):
			proj.setup(base_dir, spd, 15)
		get_parent().add_child(proj)

# Kỹ năng mới: Triệu hồi 1 Cầu Sét lớn bay từ từ đuổi theo Player trong 6 giây rồi biến mất
func _start_cast_homing_orb() -> void:
	current_state = State.CAST_HOMING_ORB
	state_timer = 0.48
	if anim:
		anim.play("cast")
	queue_redraw()

func _spawn_homing_lightning_orb() -> void:
	if not projectile_scene or not get_parent():
		return

	var init_dir := Vector2.DOWN
	if player and is_instance_valid(player):
		init_dir = (player.global_position - global_position).normalized()
		if init_dir == Vector2.ZERO:
			init_dir = Vector2.DOWN

	var proj: Node2D = projectile_scene.instantiate()
	proj.global_position = global_position + Vector2(0.0, -24.0)
	proj.shooter = self
	var homing_speed := 78.0 if is_enraged else 66.0
	if proj.has_method("setup_lightning_orb"):
		proj.setup_lightning_orb(orb_sprite_frames, init_dir, homing_speed, 22, 0.25, true, 6.0)
		proj.homing_turn_speed = 3.8
		var tw := proj.create_tween()
		tw.tween_property(proj, "scale", Vector2(1.45, 1.45), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_parent().add_child(proj)

func _start_tempest_dash() -> void:
	current_state = State.TEMPEST_DASH
	state_timer = 0.52
	if anim:
		anim.play("cast")

	if player and is_instance_valid(player):
		var angle := randf() * TAU
		var candidate := player.global_position + Vector2.RIGHT.rotated(angle) * 90.0
		if candidate.distance_to(spawn_origin) > 135.0:
			candidate = spawn_origin + (candidate - spawn_origin).normalized() * 105.0
		dash_target = candidate
	else:
		dash_target = spawn_origin

func _fire_radial_burst() -> void:
	if not projectile_scene or not get_parent():
		return
	var count: int = 8 if is_enraged else 5
	spiral_angle += 0.45
	for i in range(count):
		var ang := spiral_angle + (TAU / float(count)) * float(i)
		var dir := Vector2.RIGHT.rotated(ang)
		var proj: Node2D = projectile_scene.instantiate()
		proj.global_position = global_position + dir * 18.0
		proj.shooter = self
		if proj.has_method("setup_lightning_orb"):
			proj.setup_lightning_orb(orb_sprite_frames, dir, 115.0 if is_enraged else 98.0, 12, 0.0, false, 3.5)
		get_parent().add_child(proj)

func _update_lightning_zones(delta: float) -> void:
	if lightning_zones.is_empty():
		return
	var i: int = lightning_zones.size() - 1
	while i >= 0:
		var z: Dictionary = lightning_zones[i]
		if float(z["struck"]) < 0.0:
			z["timer"] = float(z["timer"]) - delta
			if float(z["timer"]) <= 0.0:
				z["struck"] = 0.0
				_trigger_lightning_damage(z["pos"])
		else:
			z["struck"] = float(z["struck"]) + delta * 3.2
			if float(z["struck"]) >= 1.0:
				lightning_zones.remove_at(i)
				i -= 1
				continue
		lightning_zones[i] = z
		i -= 1
	queue_redraw()

func _trigger_lightning_damage(zone_pos: Vector2) -> void:
	if player and is_instance_valid(player):
		if player.global_position.distance_to(zone_pos) <= lightning_radius and player.has_method("take_damage"):
			player.take_damage(lightning_damage, zone_pos, knockback_force)

func _draw() -> void:
	# Bóng mờ dưới mặt đất khi Boss đang bay lơ lửng
	draw_circle(Vector2(0, 14), 14.0, Color(0.0, 0.0, 0.0, 0.32))

	# Vòng ma pháp Lục Bảo dưới chân Boss khi niệm phép hoặc lướt bão tố
	if current_state in [State.CAST_LIGHTNING, State.CAST_ORB_BARRAGE, State.CAST_HOMING_ORB, State.TEMPEST_DASH]:
		var aura_col := Color(0.35, 1.0, 0.65, 0.8) if not is_enraged else Color(0.95, 1.0, 0.35, 0.88)
		draw_arc(Vector2(0, -10), 34.0, 0.0, TAU, 36, aura_col, 2.2)
		draw_arc(Vector2(0, -10), 26.0, 0.0, TAU, 28, Color(0.2, 0.9, 0.8, 0.45), 1.4)

	# Vẽ các vùng cảnh báo & Tia Sét Thiên Lôi giáng xuống
	for z in lightning_zones:
		var local_pos: Vector2 = z["pos"] - global_position
		var struck_val: float = float(z["struck"])
		if struck_val < 0.0:
			var progress: float = clampf(1.0 - (float(z["timer"]) / float(z["max_time"])), 0.0, 1.0)
			draw_circle(local_pos, lightning_radius, Color(0.15, 0.9, 0.65, 0.16))
			draw_circle(local_pos, lightning_radius * progress, Color(0.3, 1.0, 0.78, 0.32))
			draw_arc(local_pos, lightning_radius, 0.0, TAU, 36, Color(0.35, 1.0, 0.8, 0.92), 2.0)
		else:
			var alpha: float = clampf(1.0 - struck_val, 0.0, 1.0)
			# Sóng xung kích mặt đất
			draw_circle(local_pos, lightning_radius * (0.55 + 0.5 * struck_val), Color(0.25, 1.0, 0.75, alpha * 0.6))
			draw_arc(local_pos, lightning_radius * (1.0 + 0.3 * struck_val), 0.0, TAU, 36, Color(0.65, 1.0, 0.88, alpha), 3.2)

			# Vẽ tia sét đánh từ bầu trời xuống tâm vòng tròn (sử dụng cả Sprite gốc trong Boss2.png + Tia sáng)
			if boss_sheet_tex:
				var src_rect := Rect2(290, 286, 48, 64)
				var dst_rect := Rect2(local_pos.x - 30.0, local_pos.y - 76.0, 60.0, 82.0)
				draw_texture_rect_region(boss_sheet_tex, dst_rect, src_rect, Color(1.0, 1.0, 1.0, alpha))

			var sky_top := local_pos + Vector2(0, -110.0)
			var mid_1 := local_pos + Vector2(-9.0, -70.0)
			var mid_2 := local_pos + Vector2(8.0, -35.0)
			draw_polyline(PackedVector2Array([sky_top, mid_1, mid_2, local_pos]), Color(0.4, 1.0, 0.85, alpha * 0.9), 4.5)
			draw_polyline(PackedVector2Array([sky_top, mid_1, mid_2, local_pos]), Color(1.0, 1.0, 1.0, alpha), 2.0)

func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player")
	if not player and get_parent():
		player = get_parent().get_node_or_null("Player")

func _on_hitbox_body_entered(body: Node2D) -> void:
	if (body.name == "Player" or body.is_in_group("player")) and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position, knockback_force)

func take_damage(amount: int, _source_pos: Vector2 = Vector2.ZERO, _kb_force: float = 0.0) -> void:
	if health_comp:
		health_comp.take_damage(amount)

func _on_health_changed(current: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current

	if not is_enraged and current <= max_hp * 0.5 and current > 0:
		is_enraged = true
		if title_label:
			title_label.text = boss_title + " (CUỒNG PHONG)"
			title_label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.35))

	if anim:
		var base_col: Color = Color(1.15, 1.25, 0.85) if is_enraged else Color.WHITE
		anim.modulate = Color(2.2, 0.35, 0.35)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", base_col, 0.16)

func _on_died() -> void:
	if SceneManager and SceneManager.has_method("add_player_exp"):
		SceneManager.add_player_exp(180)
	set_physics_process(false)
	lightning_zones.clear()
	if boss_hud:
		boss_hud.visible = false
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.55)
	tween.tween_callback(queue_free)
