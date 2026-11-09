extends CharacterBody2D

@export var boss_title: String = "MALUGAZ"
@export var aggro_range: float = 290.0
@export var contact_damage: int = 16
@export var flame_strike_damage: int = 28
@export var flame_strike_radius: float = 44.0
@export var dash_speed: float = 265.0
@export var knockback_force: float = 240.0
@export var projectile_scene: PackedScene = preload("res://scenes/entities/fireball_projectile.tscn")

enum State { IDLE, TELEPORT_OUT, TELEPORT_IN, CAST_VOLLEY, CAST_FLAME_STRIKE, PHASE2_WINDUP, PHASE2_DASH }
var current_state: State = State.IDLE

var player: Node2D = null
var is_phase2: bool = false
var spawn_origin: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var action_counter: int = 0
var dash_direction: Vector2 = Vector2.ZERO
var dashes_remaining: int = 0

# Danh sách các vùng nổ Flame Strike đang đếm ngược: { "pos": Vector2, "timer": float, "max_time": float, "exploded": float }
var flame_zones: Array = []

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
	if health_comp:
		health_comp.died.connect(_on_died)
		health_comp.health_changed.connect(_on_health_changed)
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	if anim:
		anim.play("walk_down")
	_create_boss_hud()

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
	title_label.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_label.position = Vector2(80, 4)
	title_label.size = Vector2(320, 14)
	container.add_child(title_label)

	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.position = Vector2(110, 18)
	hp_bar.size = Vector2(260, 8)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.1, 0.18, 0.92)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.4, 0.75, 1.0, 1.0)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.65, 1.0, 1.0)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	if health_comp:
		hp_bar.max_value = health_comp.max_health
		hp_bar.value = health_comp.current_health
	container.add_child(hp_bar)

func _physics_process(delta: float) -> void:
	_update_flame_zones(delta)
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
					if is_phase2:
						dashes_remaining = 3
						_start_phase2_windup()
					else:
						_start_teleport_out()

		State.TELEPORT_OUT:
			velocity = Vector2.ZERO
			state_timer -= delta
			if anim:
				anim.modulate.a = clamp(state_timer / 0.3, 0.0, 1.0)
			queue_redraw()
			if state_timer <= 0.0:
				_perform_teleport()

		State.TELEPORT_IN:
			velocity = Vector2.ZERO
			state_timer -= delta
			if anim:
				anim.modulate.a = clamp(1.0 - (state_timer / 0.3), 0.0, 1.0)
			queue_redraw()
			if state_timer <= 0.0:
				if anim:
					anim.modulate.a = 1.0
				action_counter += 1
				if action_counter % 2 == 0:
					_start_cast_flame_strike()
				else:
					_start_cast_volley()

		State.CAST_VOLLEY:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				_fire_volley()
				current_state = State.IDLE
				state_timer = 0.85

		State.CAST_FLAME_STRIKE:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				current_state = State.IDLE
				state_timer = 0.95

		State.PHASE2_WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			if player and is_instance_valid(player):
				dash_direction = (player.global_position - global_position).normalized()
				_play_dir_anim(dash_direction)
			queue_redraw()
			if state_timer <= 0.0:
				current_state = State.PHASE2_DASH
				state_timer = 0.38
				_spawn_side_fireballs(dash_direction)

		State.PHASE2_DASH:
			velocity = dash_direction * dash_speed
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0 or is_on_wall():
				velocity = Vector2.ZERO
				dashes_remaining -= 1
				if dashes_remaining > 0:
					_start_phase2_windup()
				else:
					_start_cast_flame_strike()

	move_and_slide()

func _start_teleport_out() -> void:
	current_state = State.TELEPORT_OUT
	state_timer = 0.3

func _perform_teleport() -> void:
	if player and is_instance_valid(player):
		var angle: float = randf() * TAU
		var radius: float = randf_range(75.0, 125.0)
		var candidate: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * radius
		# Giữ quanh khu vực đấu trường ban đầu để không kẹt ngoài tường
		if candidate.distance_to(spawn_origin) > 140.0:
			candidate = spawn_origin + (candidate - spawn_origin).normalized() * 110.0
		global_position = candidate
		_play_dir_anim((player.global_position - global_position).normalized())
	current_state = State.TELEPORT_IN
	state_timer = 0.3

func _start_cast_volley() -> void:
	current_state = State.CAST_VOLLEY
	state_timer = 0.45

func _fire_volley() -> void:
	if not projectile_scene or not get_parent() or not player or not is_instance_valid(player):
		return
	var base_dir: Vector2 = (player.global_position - global_position).normalized()
	_play_dir_anim(base_dir)
	var angles := [-0.4, -0.2, 0.0, 0.2, 0.4]
	for a: float in angles:
		var dir: Vector2 = base_dir.rotated(a)
		var proj: Node2D = projectile_scene.instantiate()
		proj.global_position = global_position + dir * 16.0
		if proj.has_method("setup"):
			proj.setup(dir, 145.0, 15)
		get_parent().add_child(proj)

func _start_cast_flame_strike() -> void:
	current_state = State.CAST_FLAME_STRIKE
	state_timer = 0.55
	if not player or not is_instance_valid(player):
		return
	# Đặt 2-3 vòng tròn nổ dưới chân Player và xung quanh
	var count: int = 3 if is_phase2 else 2
	for i in range(count):
		var offset := Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(randf() * TAU) * randf_range(38.0, 72.0)
		flame_zones.append({
			"pos": player.global_position + offset,
			"timer": 0.8,
			"max_time": 0.8,
			"exploded": -1.0
		})
	queue_redraw()

func _start_phase2_windup() -> void:
	current_state = State.PHASE2_WINDUP
	state_timer = 0.42
	if player and is_instance_valid(player):
		dash_direction = (player.global_position - global_position).normalized()

func _spawn_side_fireballs(dir: Vector2) -> void:
	if not projectile_scene or not get_parent():
		return
	for side in [-PI * 0.5, PI * 0.5, 0.0]:
		var d: Vector2 = dir.rotated(side)
		var proj: Node2D = projectile_scene.instantiate()
		proj.global_position = global_position + d * 14.0
		if proj.has_method("setup"):
			proj.setup(d, 130.0, 14)
		get_parent().add_child(proj)

func _update_flame_zones(delta: float) -> void:
	if flame_zones.is_empty():
		return
	var i: int = flame_zones.size() - 1
	while i >= 0:
		var z: Dictionary = flame_zones[i]
		if z["exploded"] < 0.0:
			z["timer"] -= delta
			if z["timer"] <= 0.0:
				z["exploded"] = 0.0
				_trigger_flame_zone_damage(z["pos"])
		else:
			z["exploded"] += delta * 3.5
			if z["exploded"] >= 1.0:
				flame_zones.remove_at(i)
				i -= 1
				continue
		flame_zones[i] = z
		i -= 1
	queue_redraw()

func _trigger_flame_zone_damage(zone_pos: Vector2) -> void:
	if player and is_instance_valid(player):
		if player.global_position.distance_to(zone_pos) <= flame_strike_radius and player.has_method("take_damage"):
			player.take_damage(flame_strike_damage, zone_pos, knockback_force)

func _draw() -> void:
	# Vẽ vòng tròn cổ ngữ dưới chân Malugaz khi niệm phép hoặc dịch chuyển
	if current_state in [State.TELEPORT_OUT, State.TELEPORT_IN, State.CAST_VOLLEY, State.CAST_FLAME_STRIKE]:
		var col := Color(1.0, 0.35, 0.2, 0.75) if is_phase2 else Color(0.25, 0.75, 1.0, 0.75)
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, col, 2.0)
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, col, 1.2)

	# Vẽ đường cảnh báo húc lửa ở Phase 2
	if current_state == State.PHASE2_WINDUP:
		draw_line(Vector2.ZERO, dash_direction * 95.0, Color(1.0, 0.3, 0.1, 0.85), 3.0)

	# Vẽ các vòng tròn Flame Strike AoE trên mặt đất
	for z in flame_zones:
		var local_pos: Vector2 = z["pos"] - global_position
		if z["exploded"] < 0.0:
			var progress: float = clamp(1.0 - (z["timer"] / z["max_time"]), 0.0, 1.0)
			draw_circle(local_pos, flame_strike_radius, Color(0.2, 0.65, 1.0, 0.16))
			draw_circle(local_pos, flame_strike_radius * progress, Color(0.35, 0.85, 1.0, 0.32))
			draw_arc(local_pos, flame_strike_radius, 0.0, TAU, 36, Color(0.4, 0.9, 1.0, 0.9), 2.0)
		else:
			var ex: float = z["exploded"]
			var alpha: float = 1.0 - ex
			draw_circle(local_pos, flame_strike_radius * (0.6 + 0.5 * ex), Color(1.0, 0.55, 0.15, alpha * 0.65))
			draw_arc(local_pos, flame_strike_radius * (1.0 + 0.25 * ex), 0.0, TAU, 36, Color(1.0, 0.85, 0.3, alpha), 3.5)

func _play_dir_anim(dir: Vector2) -> void:
	if not anim:
		return
	if abs(dir.x) > abs(dir.y):
		anim.play("walk_right" if dir.x > 0 else "walk_left")
	else:
		anim.play("walk_down" if dir.y > 0 else "walk_up")

func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player")
	if not player and get_parent():
		player = get_parent().get_node_or_null("Player")

func _on_hitbox_body_entered(body: Node2D) -> void:
	if (body.name == "Player" or body.is_in_group("player")) and body.has_method("take_damage"):
		var dmg: int = contact_damage + (8 if current_state == State.PHASE2_DASH else 0)
		body.take_damage(dmg, global_position, knockback_force)

func take_damage(amount: int, _source_pos: Vector2 = Vector2.ZERO, _kb_force: float = 0.0) -> void:
	if health_comp:
		health_comp.take_damage(amount)

func _on_health_changed(current: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current

	if not is_phase2 and current <= max_hp * 0.45 and current > 0:
		is_phase2 = true
		if title_label:
			title_label.text = boss_title + " (HÓA HỎA THẦN)"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))

	if anim:
		var base_col: Color = Color(1.0, 0.6, 0.35) if is_phase2 else Color.WHITE
		anim.modulate = Color(1.0, 0.25, 0.25)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", base_col, 0.15)

func _on_died() -> void:
	set_physics_process(false)
	flame_zones.clear()
	if boss_hud:
		boss_hud.visible = false
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
