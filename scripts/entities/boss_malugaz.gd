extends CharacterBody2D

@export var boss_title: String = "MALUGAZ - FLAME LORD"
@export var aggro_range: float = 320.0
@export var contact_damage: int = 24
@export var flame_strike_damage: int = 38
@export var flame_strike_radius: float = 52.0
@export var dash_speed: float = 300.0
@export var knockback_force: float = 260.0
@export var projectile_scene: PackedScene = preload("res://scenes/entities/fireball_projectile.tscn")

@export var clone_explosion_damage: int = 16
@export var clone_explosion_radius: float = 38.0
@export var cursed_ground_damage: int = 12
@export var meteor_impact_damage: int = 32
@export var meteor_radius: float = 30.0
@export var prison_explosion_damage: int = 44

enum State {
	IDLE,
	TELEPORT_OUT,
	TELEPORT_IN,
	CAST_VOLLEY,
	CAST_FLAME_STRIKE,
	PHASE2_WINDUP,
	PHASE2_DASH,
	CAST_FLAME_CLONE,
	CAST_CURSED_GROUND,
	CAST_METEOR_FLAME,
	INFERNAL_PRISON_WINDUP,
	INFERNAL_PRISON_ACTIVE,
	INFERNAL_PRISON_RECOVERY
}

var current_state: State = State.IDLE
var current_phase: int = 1
var is_dead: bool = false

var player: Node2D = null
var is_phase2: bool = false
var has_triggered_prison: bool = false
var spawn_origin: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var action_counter: int = 0
var dash_direction: Vector2 = Vector2.ZERO
var dashes_remaining: int = 0
var meteor_waves_remaining: int = 0

# Danh sách các vùng nổ Flame Strike đang đếm ngược: { "pos": Vector2, "timer": float, "max_time": float, "exploded": float }
var flame_zones: Array = []

# Skill 1: Flame Clones (Illusions): { "node": Node2D, "pos": Vector2, "timer": float, "exploded": float }
var flame_clones: Array[Dictionary] = []

# Skill 2: Cursed Ground: { "pos": Vector2, "radius": float, "warn_timer": float, "max_warn": float, "active_timer": float, "tick_timer": float, "linked_to": Vector2, "has_link": bool }
var cursed_grounds: Array[Dictionary] = []

# Skill 3: Meteor Flame: { "pos": Vector2, "radius": float, "timer": float, "max_time": float, "impacted": bool }
var falling_meteors: Array[Dictionary] = []

# Ultimate: Infernal Prison
var prison_active: bool = false
var prison_center: Vector2 = Vector2.ZERO
var prison_outer_radius: float = 165.0
var prison_current_radius: float = 165.0
var prison_min_radius: float = 78.0
var prison_timer: float = 0.0
var prison_max_duration: float = 5.0
var prison_attack_timer: float = 0.0
var prison_explosion_visual: float = -1.0
var prison_safe_pockets: Array[Vector2] = []
var prison_border_tick: float = 0.0

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
	var bar := BossHealthBar.new()
	var max_hp: float = float(health_comp.max_health) if health_comp else 100.0
	var cur_hp: float = float(health_comp.current_health) if health_comp else max_hp
	bar.setup(boss_title, Color(0.2, 0.65, 1.0), max_hp, cur_hp)
	bar.visible = false
	add_child(bar)
	boss_hud = bar
	hp_bar = bar.hp_bar
	title_label = bar.title_label

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_flame_zones(delta)
	_update_flame_clones(delta)
	_update_cursed_grounds(delta)
	_update_falling_meteors(delta)
	_update_infernal_prison(delta)

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
					_choose_next_action()

		State.TELEPORT_OUT:
			velocity = Vector2.ZERO
			state_timer -= delta
			if anim:
				anim.modulate.a = clampf(state_timer / 0.3, 0.0, 1.0)
			queue_redraw()
			if state_timer <= 0.0:
				_perform_teleport()

		State.TELEPORT_IN:
			velocity = Vector2.ZERO
			state_timer -= delta
			if anim:
				anim.modulate.a = clampf(1.0 - (state_timer / 0.3), 0.0, 1.0)
			queue_redraw()
			if state_timer <= 0.0:
				if anim:
					anim.modulate.a = 1.0
				_choose_post_teleport_skill()

		State.CAST_VOLLEY:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				_fire_volley()
				current_state = State.IDLE
				state_timer = 0.75 if is_phase2 else 0.85

		State.CAST_FLAME_STRIKE:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				current_state = State.IDLE
				state_timer = 0.8 if is_phase2 else 0.95

		State.CAST_FLAME_CLONE:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				_execute_flame_clone()
				current_state = State.IDLE
				state_timer = 0.85

		State.CAST_CURSED_GROUND:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				current_state = State.IDLE
				state_timer = 0.85

		State.CAST_METEOR_FLAME:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				if meteor_waves_remaining > 0:
					meteor_waves_remaining -= 1
					_spawn_meteor_wave()
					state_timer = 0.55
				else:
					current_state = State.IDLE
					state_timer = 0.9

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

		State.INFERNAL_PRISON_WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				_activate_infernal_prison()

		State.INFERNAL_PRISON_ACTIVE:
			velocity = Vector2.ZERO
			prison_attack_timer -= delta
			if prison_attack_timer <= 0.0:
				prison_attack_timer = 1.25
				_prison_teleport_and_attack()
			queue_redraw()

		State.INFERNAL_PRISON_RECOVERY:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				current_state = State.IDLE
				state_timer = 1.0

	move_and_slide()

func _choose_next_action() -> void:
	if is_phase2 and action_counter % 4 == 3:
		action_counter += 1
		dashes_remaining = 3
		_start_phase2_windup()
	else:
		_start_teleport_out()

func _choose_post_teleport_skill() -> void:
	action_counter += 1
	if not is_phase2:
		# Phase 1: Teleport, Fireball Volley, Flame Strike
		if action_counter % 2 == 0:
			_start_cast_flame_strike()
		else:
			_start_cast_volley()
	else:
		# Phase 2: Flame Clone, Cursed Ground, Meteor Flame + existing Volley / Flame Strike
		var slot: int = action_counter % 5
		match slot:
			0:
				_start_cast_flame_clone()
			1:
				_start_cast_cursed_ground()
			2:
				_start_cast_meteor_flame()
			3:
				_start_cast_volley()
			_:
				_start_cast_flame_strike()

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
	if AudioManager:
		AudioManager.play_sfx_random_pitch("projectile", 0.0, 0.95, 1.1)
	var base_dir: Vector2 = (player.global_position - global_position).normalized()
	_play_dir_anim(base_dir)
	var angles := [-0.4, -0.2, 0.0, 0.2, 0.4]
	for a: float in angles:
		var dir: Vector2 = base_dir.rotated(a)
		var proj: Node2D = projectile_scene.instantiate()
		proj.global_position = global_position + dir * 16.0
		if proj.has_method("setup"):
			proj.setup(dir, 145.0, 15, Color.WHITE, self)
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

# -------------------------------------------------------------
# SKILL 1: FLAME CLONE (PHÂN THÂN HỎA ẢNH)
# -------------------------------------------------------------
func _start_cast_flame_clone() -> void:
	current_state = State.CAST_FLAME_CLONE
	state_timer = 0.5
	queue_redraw()

func _execute_flame_clone() -> void:
	_clear_flame_clones()
	if not player or not is_instance_valid(player):
		return
	if AudioManager:
		AudioManager.play_sfx_random_pitch("fire", 1.0, 0.95, 1.15)

	# Tạo đội hình 3 điểm quanh Player (1 Malugaz thật + 2 ảo ảnh)
	var base_ang: float = randf() * TAU
	var real_idx: int = randi() % 3
	for i in range(3):
		var ang: float = base_ang + (TAU / 3.0) * float(i)
		var pos: Vector2 = player.global_position + Vector2.RIGHT.rotated(ang) * 92.0
		if pos.distance_to(spawn_origin) > 145.0:
			pos = spawn_origin + (pos - spawn_origin).normalized() * 115.0

		if i == real_idx:
			global_position = pos
			_play_dir_anim((player.global_position - global_position).normalized())
		else:
			var clone_spr: AnimatedSprite2D = null
			if anim and get_parent():
				clone_spr = AnimatedSprite2D.new()
				clone_spr.sprite_frames = anim.sprite_frames
				clone_spr.animation = anim.animation
				clone_spr.scale = anim.scale
				clone_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				clone_spr.modulate = Color(1.15, 0.48, 0.28, 0.72) # Hiệu ứng mờ ảo để phân biệt với Boss thật
				clone_spr.global_position = pos + Vector2(0, -10)
				clone_spr.play(anim.animation)
				get_parent().add_child(clone_spr)
			flame_clones.append({
				"node": clone_spr,
				"pos": pos,
				"timer": 3.4,
				"exploded": -1.0
			})
	queue_redraw()

func _update_flame_clones(delta: float) -> void:
	if flame_clones.is_empty():
		return
	var i: int = flame_clones.size() - 1
	while i >= 0:
		var c: Dictionary = flame_clones[i]
		var c_pos: Vector2 = c["pos"]
		var exp_val: float = float(c["exploded"])
		if exp_val < 0.0:
			c["timer"] = float(c["timer"]) - delta
			var player_near: bool = false
			if player and is_instance_valid(player):
				if player.global_position.distance_to(c_pos) <= 36.0:
					player_near = true
			if player_near or float(c["timer"]) <= 0.0:
				c["exploded"] = 0.0
				var c_node: Node2D = c["node"]
				if c_node and is_instance_valid(c_node):
					c_node.queue_free()
				c["node"] = null
				if AudioManager:
					AudioManager.play_sfx_random_pitch("fire", 0.5, 1.0, 1.2)
				if player and is_instance_valid(player) and player.global_position.distance_to(c_pos) <= clone_explosion_radius:
					if player.has_method("take_damage"):
						player.take_damage(clone_explosion_damage, c_pos, knockback_force * 0.7)
		else:
			c["exploded"] = exp_val + delta * 3.5
			if float(c["exploded"]) >= 1.0:
				flame_clones.remove_at(i)
				i -= 1
				continue
		flame_clones[i] = c
		i -= 1
	queue_redraw()

func _clear_flame_clones() -> void:
	for c in flame_clones:
		var c_node: Node2D = c["node"]
		if c_node and is_instance_valid(c_node):
			c_node.queue_free()
	flame_clones.clear()

# -------------------------------------------------------------
# SKILL 2: CURSED GROUND (VÙNG ĐẤT NGUYỀN RỦA & ĐƯỜNG LỬA NỐI)
# -------------------------------------------------------------
func _start_cast_cursed_ground() -> void:
	current_state = State.CAST_CURSED_GROUND
	state_timer = 0.58
	if not player or not is_instance_valid(player):
		return

	var count: int = 4 if is_phase2 else 3
	var prev_pos: Vector2 = Vector2.ZERO
	for i in range(count):
		var angle: float = (TAU / float(count)) * float(i) + randf_range(-0.3, 0.3)
		var dist: float = 0.0 if i == 0 else randf_range(52.0, 88.0)
		var z_pos: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * dist
		var has_link: bool = (is_phase2 and i > 0)
		cursed_grounds.append({
			"pos": z_pos,
			"radius": 34.0,
			"warn_timer": 1.5,
			"max_warn": 1.5,
			"active_timer": 4.0,
			"tick_timer": 0.0,
			"linked_to": prev_pos,
			"has_link": has_link
		})
		prev_pos = z_pos
	queue_redraw()

func _update_cursed_grounds(delta: float) -> void:
	if cursed_grounds.is_empty():
		return
	var i: int = cursed_grounds.size() - 1
	while i >= 0:
		var cg: Dictionary = cursed_grounds[i]
		var w_timer: float = float(cg["warn_timer"])
		var cg_pos: Vector2 = cg["pos"]
		var cg_r: float = float(cg["radius"])

		if w_timer > 0.0:
			w_timer -= delta
			cg["warn_timer"] = w_timer
			if w_timer <= 0.0 and AudioManager:
				AudioManager.play_sfx_random_pitch("fire", 1.0, 0.85, 1.05)
		else:
			cg["active_timer"] = float(cg["active_timer"]) - delta
			cg["tick_timer"] = maxf(0.0, float(cg["tick_timer"]) - delta)
			if float(cg["active_timer"]) <= 0.0:
				cursed_grounds.remove_at(i)
				i -= 1
				continue

			if player and is_instance_valid(player) and float(cg["tick_timer"]) <= 0.0:
				var p_pos: Vector2 = player.global_position
				var hit: bool = p_pos.distance_to(cg_pos) <= cg_r
				if not hit and bool(cg["has_link"]):
					var link_pt: Vector2 = cg["linked_to"]
					var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p_pos, cg_pos, link_pt)
					if p_pos.distance_to(closest) <= 14.0:
						hit = true
				if hit and player.has_method("take_damage"):
					cg["tick_timer"] = 0.75
					player.take_damage(cursed_ground_damage, cg_pos, 60.0)
		cursed_grounds[i] = cg
		i -= 1
	queue_redraw()

# -------------------------------------------------------------
# SKILL 3: METEOR FLAME (MƯA THIÊN THẠCH LỬA)
# -------------------------------------------------------------
func _start_cast_meteor_flame() -> void:
	current_state = State.CAST_METEOR_FLAME
	state_timer = 0.55
	meteor_waves_remaining = 1 if is_phase2 else 0
	_spawn_meteor_wave()
	queue_redraw()

func _spawn_meteor_wave() -> void:
	if not player or not is_instance_valid(player):
		return
	var count: int = randi_range(5, 7)
	for i in range(count):
		var offset := Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(randf() * TAU) * randf_range(34.0, 105.0)
		falling_meteors.append({
			"pos": player.global_position + offset,
			"radius": meteor_radius,
			"timer": 0.0,
			"max_time": 1.05 + float(i) * 0.14,
			"impacted": false
		})

func _update_falling_meteors(delta: float) -> void:
	if falling_meteors.is_empty():
		return
	var i: int = falling_meteors.size() - 1
	while i >= 0:
		var m: Dictionary = falling_meteors[i]
		m["timer"] = float(m["timer"]) + delta
		var cur_t: float = float(m["timer"])
		var max_t: float = float(m["max_time"])
		var m_pos: Vector2 = m["pos"]
		var m_r: float = float(m["radius"])

		if cur_t >= max_t and not bool(m["impacted"]):
			m["impacted"] = true
			if AudioManager:
				AudioManager.play_sfx_random_pitch("explosion", 1.2, 0.95, 1.15)
			if player and is_instance_valid(player):
				if player.has_method("apply_screen_shake"):
					player.apply_screen_shake(2.8, 0.15)
				if player.global_position.distance_to(m_pos) <= m_r and player.has_method("take_damage"):
					player.take_damage(meteor_impact_damage, m_pos, knockback_force * 0.85)
			# Mỗi thiên thạch rơi xuống để lại một vùng lửa tạm thời
			cursed_grounds.append({
				"pos": m_pos,
				"radius": 24.0,
				"warn_timer": 0.0,
				"max_warn": 0.1,
				"active_timer": 2.6,
				"tick_timer": 0.35,
				"linked_to": Vector2.ZERO,
				"has_link": false
			})

		if cur_t >= max_t + 0.3:
			falling_meteors.remove_at(i)
			i -= 1
			continue
		falling_meteors[i] = m
		i -= 1
	queue_redraw()

# -------------------------------------------------------------
# ULTIMATE: INFERNAL PRISON (NGỤC TÙ ĐỊA NGỤC)
# -------------------------------------------------------------
func _start_infernal_prison() -> void:
	current_state = State.INFERNAL_PRISON_WINDUP
	state_timer = 0.85
	if anim:
		anim.modulate.a = 1.0
	prison_center = player.global_position if (player and is_instance_valid(player)) else spawn_origin
	if prison_center.distance_to(spawn_origin) > 80.0:
		prison_center = spawn_origin.lerp(prison_center, 0.5)
	prison_outer_radius = 160.0
	prison_current_radius = prison_outer_radius
	prison_safe_pockets.clear()
	for i in range(3):
		var ang: float = (TAU / 3.0) * float(i) + PI * 0.25
		prison_safe_pockets.append(prison_center + Vector2.RIGHT.rotated(ang) * 52.0)
	if AudioManager:
		AudioManager.play_sfx_random_pitch("fire", 2.0, 0.75, 0.9)
	queue_redraw()

func _activate_infernal_prison() -> void:
	current_state = State.INFERNAL_PRISON_ACTIVE
	prison_active = true
	prison_timer = prison_max_duration
	prison_attack_timer = 0.65
	prison_border_tick = 0.0
	queue_redraw()

func _prison_teleport_and_attack() -> void:
	if is_dead:
		return
	var ang: float = randf() * TAU
	global_position = prison_center + Vector2.RIGHT.rotated(ang) * maxf(45.0, prison_current_radius - 18.0)
	if player and is_instance_valid(player):
		_play_dir_anim((player.global_position - global_position).normalized())
	# Bắn 3 tia cầu lửa vào trong lồng giam
	if projectile_scene and get_parent() and player and is_instance_valid(player):
		if AudioManager:
			AudioManager.play_sfx_random_pitch("projectile", 0.0, 1.0, 1.15)
		var base_dir: Vector2 = (player.global_position - global_position).normalized()
		for a_off in [-0.28, 0.0, 0.28]:
			var dir: Vector2 = base_dir.rotated(float(a_off))
			var proj: Node2D = projectile_scene.instantiate()
			proj.global_position = global_position + dir * 14.0
			if proj.has_method("setup"):
				proj.setup(dir, 130.0, 13, Color(1.0, 0.55, 0.2, 1.0), self)
			get_parent().add_child(proj)

func _update_infernal_prison(delta: float) -> void:
	if prison_explosion_visual >= 0.0:
		prison_explosion_visual += delta * 2.5
		if prison_explosion_visual >= 1.0:
			prison_explosion_visual = -1.0
		queue_redraw()

	if not prison_active:
		return

	prison_timer -= delta
	prison_border_tick = maxf(0.0, prison_border_tick - delta)
	var progress: float = clampf(1.0 - (prison_timer / prison_max_duration), 0.0, 1.0)
	prison_current_radius = lerpf(prison_outer_radius, prison_min_radius, progress)

	# Nếu người chơi bước ra ngoài vành lửa ngục tù thì chịu sát thương bỏng
	if player and is_instance_valid(player) and prison_border_tick <= 0.0:
		var d_center: float = player.global_position.distance_to(prison_center)
		if d_center > prison_current_radius + 6.0 and d_center < prison_outer_radius + 35.0:
			prison_border_tick = 0.65
			if player.has_method("take_damage"):
				player.take_damage(14, prison_center + (player.global_position - prison_center).normalized() * (prison_current_radius + 20.0), 120.0)

	if prison_timer <= 0.0:
		prison_active = false
		prison_explosion_visual = 0.0
		current_state = State.INFERNAL_PRISON_RECOVERY
		state_timer = 1.05
		if AudioManager:
			AudioManager.play_sfx_random_pitch("explosion", 2.5, 0.8, 0.95)
		if player and is_instance_valid(player):
			if player.has_method("apply_screen_shake"):
				player.apply_screen_shake(6.0, 0.35)
			var in_safe_zone: bool = false
			for sp in prison_safe_pockets:
				if player.global_position.distance_to(sp) <= 28.0:
					in_safe_zone = true
					break
			if not in_safe_zone and player.global_position.distance_to(prison_center) <= prison_outer_radius:
				if player.has_method("take_damage"):
					player.take_damage(prison_explosion_damage, prison_center, knockback_force)
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
			proj.setup(d, 130.0, 14, Color.WHITE, self)
		get_parent().add_child(proj)

func _update_flame_zones(delta: float) -> void:
	if flame_zones.is_empty():
		return
	var i: int = flame_zones.size() - 1
	while i >= 0:
		var z: Dictionary = flame_zones[i]
		if float(z["exploded"]) < 0.0:
			z["timer"] = float(z["timer"]) - delta
			if float(z["timer"]) <= 0.0:
				z["exploded"] = 0.0
				_trigger_flame_zone_damage(z["pos"])
		else:
			z["exploded"] = float(z["exploded"]) + delta * 3.5
			if float(z["exploded"]) >= 1.0:
				flame_zones.remove_at(i)
				i -= 1
				continue
		flame_zones[i] = z
		i -= 1
	queue_redraw()

func _trigger_flame_zone_damage(zone_pos: Vector2) -> void:
	if AudioManager:
		AudioManager.play_sfx_random_pitch("fire", 1.0, 0.9, 1.1)
	if player and is_instance_valid(player):
		if player.global_position.distance_to(zone_pos) <= flame_strike_radius and player.has_method("take_damage"):
			player.take_damage(flame_strike_damage, zone_pos, knockback_force)

func _draw() -> void:
	if is_dead:
		return

	# Hào quang chân thân của Malugaz (giúp người chơi nhận diện Boss thật khi dùng Flame Clone)
	if not flame_clones.is_empty():
		draw_arc(Vector2(0, -4), 20.0, 0.0, TAU, 28, Color(1.0, 0.92, 0.35, 0.85), 2.0)

	# Vẽ vòng tròn cổ ngữ dưới chân Malugaz khi niệm phép hoặc dịch chuyển
	if current_state in [State.TELEPORT_OUT, State.TELEPORT_IN, State.CAST_VOLLEY, State.CAST_FLAME_STRIKE, State.CAST_FLAME_CLONE, State.CAST_CURSED_GROUND, State.CAST_METEOR_FLAME, State.INFERNAL_PRISON_WINDUP]:
		var col := Color(1.0, 0.35, 0.2, 0.75) if is_phase2 else Color(0.25, 0.75, 1.0, 0.75)
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, col, 2.0)
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, col, 1.2)

	# Vẽ đường cảnh báo húc lửa ở Phase 2
	if current_state == State.PHASE2_WINDUP:
		draw_line(Vector2.ZERO, dash_direction * 95.0, Color(1.0, 0.3, 0.1, 0.85), 3.0)

	# 1. Vẽ các vùng Cursed Ground và đường lửa nối (Skill 2)
	for cg in cursed_grounds:
		var local_cg: Vector2 = cg["pos"] - global_position
		var r_cg: float = float(cg["radius"])
		var w_t: float = float(cg["warn_timer"])
		if w_t > 0.0:
			var prog: float = clampf(1.0 - (w_t / maxf(float(cg["max_warn"]), 0.01)), 0.0, 1.0)
			draw_circle(local_cg, r_cg, Color(0.95, 0.15, 0.1, 0.18))
			draw_circle(local_cg, r_cg * prog, Color(1.0, 0.3, 0.15, 0.3))
			draw_arc(local_cg, r_cg, 0.0, TAU, 32, Color(1.0, 0.2, 0.1, 0.88), 1.8)
			if bool(cg["has_link"]):
				var local_link: Vector2 = (cg["linked_to"] as Vector2) - global_position
				draw_line(local_cg, local_link, Color(1.0, 0.25, 0.1, 0.45 * prog), 6.0)
		else:
			var act_alpha: float = clampf(float(cg["active_timer"]) / 1.2, 0.0, 1.0)
			draw_circle(local_cg, r_cg, Color(1.0, 0.38, 0.08, 0.38 * act_alpha))
			draw_circle(local_cg, r_cg * 0.65, Color(1.0, 0.78, 0.2, 0.42 * act_alpha))
			draw_arc(local_cg, r_cg, 0.0, TAU, 32, Color(1.0, 0.55, 0.15, 0.85 * act_alpha), 2.2)
			if bool(cg["has_link"]):
				var local_link: Vector2 = (cg["linked_to"] as Vector2) - global_position
				draw_line(local_cg, local_link, Color(1.0, 0.42, 0.1, 0.45 * act_alpha), 16.0)
				draw_line(local_cg, local_link, Color(1.0, 0.85, 0.25, 0.75 * act_alpha), 6.0)

	# 2. Vẽ các ảo ảnh Flame Clone và vụ nổ ảo ảnh (Skill 1)
	for c in flame_clones:
		var local_c: Vector2 = (c["pos"] as Vector2) - global_position
		var exp_c: float = float(c["exploded"])
		if exp_c < 0.0:
			draw_arc(local_c, clone_explosion_radius, 0.0, TAU, 28, Color(1.0, 0.35, 0.15, 0.45), 1.5)
		else:
			var a_c: float = clampf(1.0 - exp_c, 0.0, 1.0)
			draw_circle(local_c, clone_explosion_radius * (0.6 + 0.4 * exp_c), Color(1.0, 0.45, 0.15, a_c * 0.65))
			draw_arc(local_c, clone_explosion_radius * (1.0 + 0.2 * exp_c), 0.0, TAU, 28, Color(1.0, 0.8, 0.25, a_c), 2.8)

	# 3. Vẽ thiên thạch lửa Meteor Flame (Skill 3)
	for m in falling_meteors:
		var local_m: Vector2 = (m["pos"] as Vector2) - global_position
		var cur_t: float = float(m["timer"])
		var max_t: float = float(m["max_time"])
		var r_m: float = float(m["radius"])
		if cur_t < max_t:
			var prog_m: float = clampf(cur_t / maxf(max_t, 0.01), 0.0, 1.0)
			draw_circle(local_m, r_m, Color(1.0, 0.2, 0.1, 0.16))
			draw_circle(local_m, r_m * prog_m, Color(1.0, 0.45, 0.15, 0.3))
			draw_arc(local_m, r_m, 0.0, TAU, 28, Color(1.0, 0.35, 0.1, 0.85), 1.8)
			var drop_h: float = (1.0 - prog_m) * 145.0
			var meteor_pos: Vector2 = local_m + Vector2(28.0 * (1.0 - prog_m), -drop_h)
			draw_line(meteor_pos, meteor_pos + Vector2(-10, 22), Color(1.0, 0.45, 0.1, 0.7), 4.0)
			draw_circle(meteor_pos, 10.0, Color(1.0, 0.55, 0.15, 0.95))
			draw_circle(meteor_pos, 5.5, Color(1.0, 0.95, 0.55, 0.95))

	# 4. Vẽ Infernal Prison (Ultimate)
	if current_state == State.INFERNAL_PRISON_WINDUP or prison_active:
		var local_center: Vector2 = prison_center - global_position
		draw_arc(local_center, prison_current_radius, 0.0, TAU, 56, Color(1.0, 0.28, 0.08, 0.92), 5.0)
		draw_arc(local_center, prison_current_radius + 6.0, 0.0, TAU, 56, Color(1.0, 0.65, 0.15, 0.55), 2.5)
		# Vẽ các vùng an toàn màu xanh ngọc rõ ràng để người chơi đứng tránh vụ nổ cuối
		for sp in prison_safe_pockets:
			var local_sp: Vector2 = sp - global_position
			draw_circle(local_sp, 28.0, Color(0.2, 0.95, 0.65, 0.25))
			draw_arc(local_sp, 28.0, 0.0, TAU, 28, Color(0.35, 1.0, 0.75, 0.92), 2.2)

	if prison_explosion_visual >= 0.0:
		var local_center: Vector2 = prison_center - global_position
		var a_pr: float = clampf(1.0 - prison_explosion_visual, 0.0, 1.0)
		draw_circle(local_center, prison_outer_radius, Color(1.0, 0.45, 0.1, a_pr * 0.55))
		draw_arc(local_center, prison_outer_radius * (0.8 + 0.3 * prison_explosion_visual), 0.0, TAU, 56, Color(1.0, 0.85, 0.25, a_pr), 4.5)

	# 5. Vẽ các vòng tròn Flame Strike AoE trên mặt đất
	for z in flame_zones:
		var local_pos: Vector2 = (z["pos"] as Vector2) - global_position
		var ex_val: float = float(z["exploded"])
		if ex_val < 0.0:
			var progress: float = clampf(1.0 - (float(z["timer"]) / float(z["max_time"])), 0.0, 1.0)
			draw_circle(local_pos, flame_strike_radius, Color(0.2, 0.65, 1.0, 0.16))
			draw_circle(local_pos, flame_strike_radius * progress, Color(0.35, 0.85, 1.0, 0.32))
			draw_arc(local_pos, flame_strike_radius, 0.0, TAU, 36, Color(0.4, 0.9, 1.0, 0.9), 2.0)
		else:
			var alpha: float = 1.0 - ex_val
			draw_circle(local_pos, flame_strike_radius * (0.6 + 0.5 * ex_val), Color(1.0, 0.55, 0.15, alpha * 0.65))
			draw_arc(local_pos, flame_strike_radius * (1.0 + 0.25 * ex_val), 0.0, TAU, 36, Color(1.0, 0.85, 0.3, alpha), 3.5)

func _play_dir_anim(dir: Vector2) -> void:
	if not anim:
		return
	if absf(dir.x) > absf(dir.y):
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
	if is_dead:
		return
	if (body.name == "Player" or body.is_in_group("player")) and body.has_method("take_damage"):
		var dmg: int = contact_damage + (8 if current_state == State.PHASE2_DASH else 0)
		body.take_damage(dmg, global_position, knockback_force)

func take_damage(amount: int, _source_pos: Vector2 = Vector2.ZERO, _kb_force: float = 0.0) -> void:
	if is_dead:
		return
	if health_comp:
		health_comp.take_damage(amount)

func _on_health_changed(current: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current

	if current <= 0 or is_dead:
		return

	var hp_ratio: float = float(current) / float(maxf(max_hp, 1))

	# Phase 2 transition (<= 55% HP)
	if not is_phase2 and hp_ratio <= 0.55:
		is_phase2 = true
		current_phase = 2
		if title_label:
			title_label.text = boss_title + " (HÓA HỎA THẦN)"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
		if boss_hud and boss_hud.has_method("set_accent"):
			boss_hud.set_accent(Color(1.0, 0.42, 0.15))

	# Phase 3 Ultimate: Infernal Prison (<= 25% HP, triggers once)
	if not has_triggered_prison and hp_ratio <= 0.25:
		has_triggered_prison = true
		current_phase = 3
		if title_label:
			title_label.text = boss_title + " (NGỤC TÙ ĐỊA NGỤC)"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15))
		_start_infernal_prison()

	if anim:
		var base_col: Color = Color(1.0, 0.6, 0.35) if is_phase2 else Color.WHITE
		anim.modulate = Color(1.0, 0.25, 0.25)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", base_col, 0.15)

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true

	if SceneManager and SceneManager.has_method("add_player_exp"):
		SceneManager.add_player_exp(135)

	_clear_flame_clones()
	flame_zones.clear()
	cursed_grounds.clear()
	falling_meteors.clear()
	prison_active = false

	# Rơi ra hòm phần thưởng ngẫu nhiên 1 trong 10 vũ khí thần khí
	_spawn_reward_chest()

	set_physics_process(false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	if boss_hud:
		boss_hud.visible = false
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		_trigger_victory_cutscene()
		queue_free()
	)

func _spawn_reward_chest() -> void:
	var chest_scene := load("res://scenes/objects/boss_reward_chest.tscn") as PackedScene
	if chest_scene:
		var chest = chest_scene.instantiate() as Node2D
		if chest:
			chest.global_position = global_position
			var parent_node := get_parent()
			if parent_node:
				parent_node.call_deferred("add_child", chest)
			else:
				get_tree().root.call_deferred("add_child", chest)

func _trigger_victory_cutscene() -> void:
	var cutscene_scene = load("res://menu/victory_cutscene.tscn") as PackedScene
	if cutscene_scene:
		var cutscene_inst = cutscene_scene.instantiate()
		var tree_root = get_tree().root
		if tree_root:
			tree_root.add_child(cutscene_inst)
