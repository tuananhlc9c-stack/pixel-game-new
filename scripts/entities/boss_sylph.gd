extends CharacterBody2D

@export var boss_title: String = "SYLPH - TEMPEST GODDESS"
@export var aggro_range: float = 340.0
@export var move_speed: float = 72.0
@export var dash_speed: float = 270.0
@export var contact_damage: int = 22
@export var lightning_damage: int = 40
@export var lightning_radius: float = 50.0
@export var knockback_force: float = 260.0
@export var projectile_scene: PackedScene = preload("res://scenes/entities/sylph_lightning_orb.tscn")
@export var boss_sheet_tex: Texture2D = preload("res://Content T1/Character/Monter/Boss/Boss2.png")
@export var chain_beam_damage: int = 24
@export var vortex_pull_speed: float = 54.0
@export var vortex_dot_damage: int = 10
@export var cage_beam_damage: int = 28
@export var storm_explosion_damage: int = 46

enum State {
	IDLE,
	FLOAT_CHASE,
	CAST_LIGHTNING,
	CAST_ORB_BARRAGE,
	CAST_HOMING_ORB,
	TEMPEST_DASH,
	CAST_CHAIN_LIGHTNING,
	CAST_STORM_VORTEX,
	CAST_THUNDER_CAGE,
	EYE_OF_STORM_MOVE,
	EYE_OF_STORM_ACTIVE,
	EYE_OF_STORM_RECOVERY
}

var current_state: State = State.IDLE
var current_phase: int = 1
var is_dead: bool = false

var player: Node2D = null
var is_enraged: bool = false
var has_triggered_eye_of_storm: bool = false
var spawn_origin: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var hover_time: float = 0.0
var attack_cycle: int = 0
var dash_target: Vector2 = Vector2.ZERO
var spiral_angle: float = 0.0
var orb_sprite_frames: SpriteFrames = null

# Danh sách các vùng Thiên Lôi giáng xuống: { "pos": Vector2, "timer": float, "max_time": float, "struck": float }
var lightning_zones: Array[Dictionary] = []

# Skill 1: Chain Lightning: { "nodes": Array[Vector2], "warn_timer": float, "max_warn": float, "active_timer": float, "tick_timer": float }
var chain_lightnings: Array[Dictionary] = []

# Skill 2: Storm Vortex: { "pos": Vector2, "radius": float, "pull_radius": float, "timer": float, "max_time": float, "tick_timer": float, "angle": float }
var storm_vortices: Array[Dictionary] = []

# Skill 3: Thunder Cage: { "pillars": Array[Vector2], "warn_timer": float, "max_warn": float, "active_timer": float, "tick_timer": float }
var thunder_cages: Array[Dictionary] = []

# Ultimate: Eye of the Storm
var storm_center: Vector2 = Vector2.ZERO
var storm_safe_radius: float = 56.0
var storm_outer_radius: float = 175.0
var storm_bolt_timer: float = 0.0
var storm_orb_angle: float = 0.0
var storm_explosion_visual: float = -1.0
var storm_rotating_orbs: Array[Dictionary] = []

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
		Rect2(20, 324, 24, 24),
		Rect2(52, 324, 24, 24),
		Rect2(84, 324, 24, 24),
		Rect2(115, 323, 24, 24),
		Rect2(148, 324, 24, 24)
	]
	for r: Rect2 in rects:
		var at := AtlasTexture.new()
		at.atlas = boss_sheet_tex
		at.region = r
		orb_sprite_frames.add_frame("orb", at)

func _create_boss_hud() -> void:
	var bar := BossHealthBar.new()
	var max_hp: float = float(health_comp.max_health) if health_comp else 100.0
	var cur_hp: float = float(health_comp.current_health) if health_comp else max_hp
	bar.setup(boss_title, Color(0.18, 0.9, 0.58), max_hp, cur_hp)
	bar.visible = false
	add_child(bar)
	boss_hud = bar
	hp_bar = bar.hp_bar
	title_label = bar.title_label

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	hover_time += delta
	if anim:
		# Hiệu ứng bay lơ lửng mềm mại trên không trung
		anim.position.y = -12.0 + sin(hover_time * 3.6) * 4.0

	_update_lightning_zones(delta)
	_update_chain_lightnings(delta)
	_update_storm_vortices(delta)
	_update_thunder_cages(delta)
	_update_eye_of_storm_visuals(delta)

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

			if anim and absf(to_player.x) > 4.0:
				anim.flip_h = to_player.x < 0.0

			state_timer -= delta
			if state_timer <= 0.0:
				_choose_next_attack()

		State.CAST_LIGHTNING, State.CAST_ORB_BARRAGE, State.CAST_CHAIN_LIGHTNING, State.CAST_STORM_VORTEX, State.CAST_THUNDER_CAGE:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				current_state = State.FLOAT_CHASE
				state_timer = 0.85 if is_enraged else 1.2
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

		State.EYE_OF_STORM_MOVE:
			var to_center := storm_center - global_position
			state_timer -= delta
			queue_redraw()
			if to_center.length() <= 10.0 or state_timer <= 0.0:
				global_position = storm_center
				velocity = Vector2.ZERO
				_activate_eye_of_storm()
			else:
				velocity = to_center.normalized() * (dash_speed * 1.15)

		State.EYE_OF_STORM_ACTIVE:
			velocity = Vector2.ZERO
			state_timer -= delta
			_process_eye_of_storm_active(delta)
			queue_redraw()
			if state_timer <= 0.0:
				_finish_eye_of_storm()

		State.EYE_OF_STORM_RECOVERY:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				current_state = State.FLOAT_CHASE
				state_timer = 1.0
				if anim:
					anim.play("idle")

	move_and_slide()

func _choose_next_attack() -> void:
	attack_cycle += 1
	if not is_enraged:
		# Phase 1: Lightning, Orb Barrage, Homing Orb, Tempest Dash
		var mode := attack_cycle % 4
		match mode:
			1:
				_start_cast_orb_barrage()
			2:
				_start_cast_homing_orb()
			3:
				_start_cast_lightning()
			_:
				_start_tempest_dash()
	else:
		# Phase 2: Chain Lightning, Storm Vortex, Thunder Cage + existing Phase 1 skills
		var mode := attack_cycle % 6
		match mode:
			0:
				_start_cast_chain_lightning()
			1:
				_start_cast_storm_vortex()
			2:
				_start_cast_thunder_cage()
			3:
				_start_cast_orb_barrage()
			4:
				_start_cast_lightning()
			_:
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


# Triệu hồi 5 quả cầu sét dàn ngang theo hướng vuông góc
func _fire_lightning_orbs() -> void:
	if not projectile_scene or not get_parent() or not player or not is_instance_valid(player):
		return
	var base_dir := (player.global_position - global_position).normalized()

	if base_dir == Vector2.ZERO:
		base_dir = Vector2.DOWN
	var perpendicular := Vector2(-base_dir.y, base_dir.x)
	var offsets := [-48.0, -24.0, 0.0, 24.0, 48.0]

	var spd := 155.0 if is_enraged else 130.0

	# Vị trí trung tâm của hàng cầu sét
	var center_pos := global_position + Vector2(0.0, -18.0)

	for offset: float in offsets:
		var proj: Node2D = projectile_scene.instantiate()
		proj.global_position = center_pos + perpendicular * offset
		proj.shooter = self

		if proj.has_method("setup_lightning_orb"):
			proj.setup_lightning_orb(
				orb_sprite_frames,
				base_dir,
				spd,
				15,
				0.38,
				false,
				3.8
			)

			proj.lock_dir_on_launch = true
			proj.row_origin_pos = center_pos

		elif proj.has_method("setup"):
			proj.setup(base_dir, spd, 15)

		get_parent().add_child(proj)


# Kỹ năng: Triệu hồi 1 Cầu Sét lớn bay từ từ đuổi theo Player trong 6 giây rồi biến mất
func _start_cast_homing_orb() -> void:
	current_state = State.CAST_HOMING_ORB
	state_timer = 0.48
	if anim:
		anim.play("cast")
	queue_redraw()

func _spawn_homing_lightning_orb() -> void:
	if not projectile_scene or not get_parent():
		return
	if AudioManager:
		AudioManager.play_sfx_random_pitch("projectile", 0.0, 1.1, 1.25)

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

# SKILL 1: CHAIN LIGHTNING (3 TRỤ ĐIỆN NỐI TIA SÉT)
func _start_cast_chain_lightning() -> void:
	current_state = State.CAST_CHAIN_LIGHTNING
	state_timer = 0.65
	if anim:
		anim.play("cast")
	if not player or not is_instance_valid(player):
		return

	var base_ang: float = randf() * TAU
	var p_pos: Vector2 = player.global_position
	var n0: Vector2 = p_pos + Vector2.RIGHT.rotated(base_ang) * 72.0
	var n1: Vector2 = p_pos + Vector2.RIGHT.rotated(base_ang + PI * 0.72) * 76.0
	var n2: Vector2 = p_pos + Vector2.RIGHT.rotated(base_ang - PI * 0.72) * 76.0
	var nodes_arr: Array[Vector2] = [n0, n1, n2]

	chain_lightnings.append({
		"nodes": nodes_arr,
		"warn_timer": 1.15,
		"max_warn": 1.15,
		"active_timer": 2.6,
		"tick_timer": 0.0
	})
	queue_redraw()

func _update_chain_lightnings(delta: float) -> void:
	if chain_lightnings.is_empty():
		return
	var i: int = chain_lightnings.size() - 1
	while i >= 0:
		var cl: Dictionary = chain_lightnings[i]
		var w_t: float = float(cl["warn_timer"])
		var nodes_arr: Array = cl["nodes"]
		if w_t > 0.0:
			w_t -= delta
			cl["warn_timer"] = w_t
			if w_t <= 0.0 and AudioManager:
				AudioManager.play_sfx_random_pitch("explosion", 1.0, 1.15, 1.3)
		else:
			cl["active_timer"] = float(cl["active_timer"]) - delta
			cl["tick_timer"] = maxf(0.0, float(cl["tick_timer"]) - delta)
			if float(cl["active_timer"]) <= 0.0:
				chain_lightnings.remove_at(i)
				i -= 1
				continue

			if player and is_instance_valid(player) and float(cl["tick_timer"]) <= 0.0 and nodes_arr.size() >= 3:
				var p_pos: Vector2 = player.global_position
				var pt0: Vector2 = nodes_arr[0]
				var pt1: Vector2 = nodes_arr[1]
				var pt2: Vector2 = nodes_arr[2]
				var c1: Vector2 = Geometry2D.get_closest_point_to_segment(p_pos, pt0, pt1)
				var c2: Vector2 = Geometry2D.get_closest_point_to_segment(p_pos, pt0, pt2)
				if p_pos.distance_to(c1) <= 12.0 or p_pos.distance_to(c2) <= 12.0:
					cl["tick_timer"] = 0.65
					if player.has_method("take_damage"):
						player.take_damage(chain_beam_damage, pt0, knockback_force * 0.7)
		chain_lightnings[i] = cl
		i -= 1
	queue_redraw()

# SKILL 2: STORM VORTEX
func _start_cast_storm_vortex() -> void:
	current_state = State.CAST_STORM_VORTEX
	state_timer = 0.62
	if anim:
		anim.play("cast")
	if not player or not is_instance_valid(player):
		return

	var v_pos: Vector2 = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 42.0
	storm_vortices.append({
		"pos": v_pos,
		"radius": 38.0,
		"pull_radius": 115.0,
		"timer": 4.5,
		"max_time": 4.5,
		"tick_timer": 0.0,
		"angle": 0.0
	})

	# Khi Enrage tạo thêm 1 xoáy điện phụ nhỏ hơn
	if is_enraged:
		var v2_pos: Vector2 = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 78.0
		storm_vortices.append({
			"pos": v2_pos,
			"radius": 26.0,
			"pull_radius": 85.0,
			"timer": 4.0,
			"max_time": 4.0,
			"tick_timer": 0.0,
			"angle": 0.0
		})
	queue_redraw()

func _update_storm_vortices(delta: float) -> void:
	if storm_vortices.is_empty():
		return
	var i: int = storm_vortices.size() - 1
	while i >= 0:
		var sv: Dictionary = storm_vortices[i]
		sv["timer"] = float(sv["timer"]) - delta
		sv["tick_timer"] = maxf(0.0, float(sv["tick_timer"]) - delta)
		sv["angle"] = float(sv["angle"]) + delta * 8.5
		if float(sv["timer"]) <= 0.0:
			storm_vortices.remove_at(i)
			i -= 1
			continue

		if player and is_instance_valid(player):
			var v_pos: Vector2 = sv["pos"]
			var p_pos: Vector2 = player.global_position
			var dist: float = p_pos.distance_to(v_pos)
			var pull_r: float = float(sv["pull_radius"])
			var dmg_r: float = float(sv["radius"])
			if dist <= pull_r and dist > 4.0:
				var pull_dir: Vector2 = (v_pos - p_pos).normalized()
				var strength: float = vortex_pull_speed * (0.55 + 0.45 * (1.0 - dist / pull_r))
				if player.has_method("apply_external_pull"):
					player.apply_external_pull(pull_dir * strength)
			if dist <= dmg_r and float(sv["tick_timer"]) <= 0.0:
				sv["tick_timer"] = 0.75
				if player.has_method("take_damage"):
					player.take_damage(vortex_dot_damage, v_pos, 40.0)
		storm_vortices[i] = sv
		i -= 1
	queue_redraw()

# SKILL 3: THUNDER CAGE 
func _start_cast_thunder_cage() -> void:
	current_state = State.CAST_THUNDER_CAGE
	state_timer = 0.65
	if anim:
		anim.play("cast")
	if not player or not is_instance_valid(player):
		return

	var half_size: float = 58.0 if is_enraged else 46.0
	_spawn_single_cage(player.global_position, half_size, 1.35)
	if is_enraged:
		var offset_pos: Vector2 = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 65.0
		_spawn_single_cage(offset_pos, 42.0, 1.55)
	queue_redraw()

func _spawn_single_cage(center: Vector2, half_sz: float, warn_dur: float) -> void:
	var pillars: Array[Vector2] = [
		center + Vector2(-half_sz, -half_sz),
		center + Vector2(half_sz, -half_sz),
		center + Vector2(half_sz, half_sz),
		center + Vector2(-half_sz, half_sz)
	]
	thunder_cages.append({
		"pillars": pillars,
		"warn_timer": warn_dur,
		"max_warn": warn_dur,
		"active_timer": 2.8,
		"tick_timer": 0.0
	})

func _update_thunder_cages(delta: float) -> void:
	if thunder_cages.is_empty():
		return
	var i: int = thunder_cages.size() - 1
	while i >= 0:
		var tc: Dictionary = thunder_cages[i]
		var w_t: float = float(tc["warn_timer"])
		var pillars: Array = tc["pillars"]
		if w_t > 0.0:
			w_t -= delta
			tc["warn_timer"] = w_t
			if w_t <= 0.0 and AudioManager:
				AudioManager.play_sfx_random_pitch("explosion", 1.2, 1.1, 1.25)
		else:
			tc["active_timer"] = float(tc["active_timer"]) - delta
			tc["tick_timer"] = maxf(0.0, float(tc["tick_timer"]) - delta)
			if float(tc["active_timer"]) <= 0.0:
				thunder_cages.remove_at(i)
				i -= 1
				continue

			if player and is_instance_valid(player) and float(tc["tick_timer"]) <= 0.0 and pillars.size() == 4:
				var p_pos: Vector2 = player.global_position
				var hit_edge: bool = false
				for idx in range(4):
					var a_pt: Vector2 = pillars[idx]
					var b_pt: Vector2 = pillars[(idx + 1) % 4]
					var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p_pos, a_pt, b_pt)
					if p_pos.distance_to(closest) <= 11.0:
						hit_edge = true
						break
				if hit_edge and player.has_method("take_damage"):
					tc["tick_timer"] = 0.65
					player.take_damage(cage_beam_damage, p_pos, knockback_force * 0.8)
		thunder_cages[i] = tc
		i -= 1
	queue_redraw()

# -------------------------------------------------------------
# ULTIMATE: EYE OF THE STORM (MẮT BÃO VĨNH HẰNG - 7 GIÂY)
# -------------------------------------------------------------
func _start_eye_of_the_storm() -> void:
	current_state = State.EYE_OF_STORM_MOVE
	state_timer = 0.9
	storm_center = spawn_origin
	if player and is_instance_valid(player) and spawn_origin.distance_to(player.global_position) > 150.0:
		storm_center = global_position.lerp(player.global_position, 0.4)
	if anim:
		anim.play("cast")
	queue_redraw()

func _activate_eye_of_storm() -> void:
	current_state = State.EYE_OF_STORM_ACTIVE
	state_timer = 6.8 # Kéo dài khoảng 6-8 giây theo yêu cầu
	storm_bolt_timer = 0.45
	storm_orb_angle = 0.0
	storm_rotating_orbs.clear()
	for i in range(6):
		storm_rotating_orbs.append({
			"angle": (TAU / 6.0) * float(i),
			"dist": 102.0,
			"hit_cooldown": 0.0
		})
	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 2.0, 0.85, 1.0)
	queue_redraw()

func _process_eye_of_storm_active(delta: float) -> void:
	storm_orb_angle += delta * 2.1
	# Cập nhật các quả cầu điện xoay quanh đấu trường
	for i in range(storm_rotating_orbs.size()):
		var ro: Dictionary = storm_rotating_orbs[i]
		ro["angle"] = float(ro["angle"]) + delta * 2.0
		ro["hit_cooldown"] = maxf(0.0, float(ro["hit_cooldown"]) - delta)
		var orb_world: Vector2 = storm_center + Vector2.RIGHT.rotated(float(ro["angle"])) * float(ro["dist"])
		if player and is_instance_valid(player) and float(ro["hit_cooldown"]) <= 0.0:
			if player.global_position.distance_to(orb_world) <= 16.0 and player.has_method("take_damage"):
				ro["hit_cooldown"] = 0.65
				player.take_damage(18, orb_world, 150.0)
		storm_rotating_orbs[i] = ro

	# Triệu hồi sét đánh liên hoàn ngoài vùng Mắt Bão an toàn
	storm_bolt_timer -= delta
	if storm_bolt_timer <= 0.0:
		storm_bolt_timer = 0.72
		for b in range(2):
			var ang: float = randf() * TAU
			var r_dist: float = randf_range(storm_safe_radius + 26.0, storm_outer_radius - 15.0)
			lightning_zones.append({
				"pos": storm_center + Vector2.RIGHT.rotated(ang) * r_dist,
				"timer": 0.65,
				"max_time": 0.65,
				"struck": -1.0
			})

func _finish_eye_of_storm() -> void:
	storm_rotating_orbs.clear()
	storm_explosion_visual = 0.0
	current_state = State.EYE_OF_STORM_RECOVERY
	state_timer = 1.15
	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 2.5, 0.75, 0.9)
	# Kết thúc bằng vụ nổ sét diện rộng ngoài vành đai Mắt Bão
	if player and is_instance_valid(player):
		if player.has_method("apply_screen_shake"):
			player.apply_screen_shake(6.0, 0.35)
		var d: float = player.global_position.distance_to(storm_center)
		if d > storm_safe_radius + 8.0 and d <= storm_outer_radius:
			if player.has_method("take_damage"):
				player.take_damage(storm_explosion_damage, storm_center, knockback_force)
	queue_redraw()

func _update_eye_of_storm_visuals(delta: float) -> void:
	if storm_explosion_visual >= 0.0:
		storm_explosion_visual += delta * 2.4
		if storm_explosion_visual >= 1.0:
			storm_explosion_visual = -1.0
		queue_redraw()

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
	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 1.0, 1.1, 1.3)
	if player and is_instance_valid(player):
		if player.global_position.distance_to(zone_pos) <= lightning_radius and player.has_method("take_damage"):
			player.take_damage(lightning_damage, zone_pos, knockback_force)

func _draw() -> void:
	if is_dead:
		return

	# Bóng mờ dưới mặt đất khi Boss đang bay lơ lửng
	draw_circle(Vector2(0, 14), 14.0, Color(0.0, 0.0, 0.0, 0.32))

	# Vòng ma pháp Lục Bảo dưới chân Boss khi niệm phép hoặc lướt bão tố
	if current_state in [State.CAST_LIGHTNING, State.CAST_ORB_BARRAGE, State.CAST_HOMING_ORB, State.TEMPEST_DASH, State.CAST_CHAIN_LIGHTNING, State.CAST_STORM_VORTEX, State.CAST_THUNDER_CAGE, State.EYE_OF_STORM_ACTIVE]:
		var aura_col := Color(0.35, 1.0, 0.65, 0.8) if not is_enraged else Color(0.95, 1.0, 0.35, 0.88)
		draw_arc(Vector2(0, -10), 34.0, 0.0, TAU, 36, aura_col, 2.2)
		draw_arc(Vector2(0, -10), 26.0, 0.0, TAU, 28, Color(0.2, 0.9, 0.8, 0.45), 1.4)

	# 1. Vẽ Chain Lightning (Skill 1)
	for cl in chain_lightnings:
		var nodes_arr: Array = cl["nodes"]
		if nodes_arr.size() < 3:
			continue
		var l0: Vector2 = (nodes_arr[0] as Vector2) - global_position
		var l1: Vector2 = (nodes_arr[1] as Vector2) - global_position
		var l2: Vector2 = (nodes_arr[2] as Vector2) - global_position
		var w_t: float = float(cl["warn_timer"])
		for pt in [l0, l1, l2]:
			draw_circle(pt, 7.0, Color(0.3, 1.0, 0.85, 0.9))
			draw_arc(pt, 11.0, 0.0, TAU, 20, Color(0.8, 1.0, 0.95, 0.8), 1.5)
		if w_t > 0.0:
			var prog_cl: float = clampf(1.0 - (w_t / maxf(float(cl["max_warn"]), 0.01)), 0.0, 1.0)
			draw_line(l0, l1, Color(1.0, 0.95, 0.3, 0.35 + 0.5 * prog_cl), 2.0)
			draw_line(l0, l2, Color(1.0, 0.95, 0.3, 0.35 + 0.5 * prog_cl), 2.0)
		else:
			draw_line(l0, l1, Color(0.25, 0.95, 0.85, 0.65), 8.0)
			draw_line(l0, l1, Color(1.0, 1.0, 1.0, 0.95), 2.8)
			draw_line(l0, l2, Color(0.25, 0.95, 0.85, 0.65), 8.0)
			draw_line(l0, l2, Color(1.0, 1.0, 1.0, 0.95), 2.8)

	# 2. Vẽ Storm Vortex (Skill 2)
	for sv in storm_vortices:
		var local_v: Vector2 = (sv["pos"] as Vector2) - global_position
		var r_v: float = float(sv["radius"])
		var pull_r: float = float(sv["pull_radius"])
		var ang_v: float = float(sv["angle"])
		draw_circle(local_v, r_v, Color(0.15, 0.85, 0.75, 0.22))
		draw_arc(local_v, pull_r, 0.0, TAU, 40, Color(0.3, 0.95, 0.8, 0.28), 1.4)
		for s_i in range(3):
			var a_start: float = ang_v + (TAU / 3.0) * float(s_i)
			draw_arc(local_v, r_v * 0.85, a_start, a_start + PI * 0.8, 18, Color(0.45, 1.0, 0.9, 0.85), 2.4)
			draw_arc(local_v, r_v * 0.45, -a_start, -a_start + PI * 0.9, 14, Color(0.9, 1.0, 0.6, 0.9), 2.0)

	# 3. Vẽ Thunder Cage (Skill 3)
	for tc in thunder_cages:
		var pillars: Array = tc["pillars"]
		if pillars.size() != 4:
			continue
		var w_tc: float = float(tc["warn_timer"])
		for idx in range(4):
			var p_a: Vector2 = (pillars[idx] as Vector2) - global_position
			var p_b: Vector2 = (pillars[(idx + 1) % 4] as Vector2) - global_position
			draw_circle(p_a, 6.5, Color(0.35, 1.0, 0.8, 0.95))
			if w_tc > 0.0:
				draw_line(p_a, p_b, Color(1.0, 0.9, 0.25, 0.55), 2.0)
			else:
				draw_line(p_a, p_b, Color(0.3, 1.0, 0.85, 0.65), 7.0)
				draw_line(p_a, p_b, Color(1.0, 1.0, 1.0, 0.95), 2.4)

	# 4. Vẽ Eye of the Storm (Ultimate)
	if current_state in [State.EYE_OF_STORM_MOVE, State.EYE_OF_STORM_ACTIVE]:
		var local_sc: Vector2 = storm_center - global_position
		# Vòng an toàn Mắt Bão ở trung tâm
		draw_circle(local_sc, storm_safe_radius, Color(0.2, 0.95, 0.65, 0.14))
		draw_arc(local_sc, storm_safe_radius, 0.0, TAU, 44, Color(0.35, 1.0, 0.75, 0.9), 2.5)
		draw_arc(local_sc, storm_outer_radius, 0.0, TAU, 64, Color(0.95, 1.0, 0.35, 0.75), 3.0)
		for ro in storm_rotating_orbs:
			var orb_local: Vector2 = local_sc + Vector2.RIGHT.rotated(float(ro["angle"])) * float(ro["dist"])
			draw_circle(orb_local, 12.0, Color(0.25, 1.0, 0.8, 0.35))
			draw_circle(orb_local, 7.5, Color(0.85, 1.0, 0.95, 0.95))

	if storm_explosion_visual >= 0.0:
		var local_sc: Vector2 = storm_center - global_position
		var a_st: float = clampf(1.0 - storm_explosion_visual, 0.0, 1.0)
		draw_arc(local_sc, lerpf(storm_safe_radius, storm_outer_radius, 0.5), 0.0, TAU, 64, Color(0.4, 1.0, 0.85, a_st * 0.75), storm_outer_radius - storm_safe_radius)

	# 5. Vẽ các vùng cảnh báo & Tia Sét Thiên Lôi giáng xuống
	for z in lightning_zones:
		var local_pos: Vector2 = (z["pos"] as Vector2) - global_position
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
	if is_dead:
		return
	if (body.name == "Player" or body.is_in_group("player")) and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position, knockback_force)

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
	if not is_enraged and hp_ratio <= 0.55:
		is_enraged = true
		current_phase = 2
		if title_label:
			title_label.text = boss_title + " (CUỒNG PHONG)"
			title_label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.35))
		if boss_hud and boss_hud.has_method("set_accent"):
			boss_hud.set_accent(Color(0.85, 0.95, 0.25))

	# Phase 3 Ultimate: Eye of the Storm (<= 25% HP, triggers once)
	if not has_triggered_eye_of_storm and hp_ratio <= 0.25:
		has_triggered_eye_of_storm = true
		current_phase = 3
		if title_label:
			title_label.text = boss_title + " (MẮT BÃO VĨNH HẰNG)"
			title_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.95))
		_start_eye_of_the_storm()

	if anim:
		var base_col: Color = Color(1.15, 1.25, 0.85) if is_enraged else Color.WHITE
		anim.modulate = Color(2.2, 0.35, 0.35)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", base_col, 0.16)

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true

	if SceneManager and SceneManager.has_method("add_player_exp"):
		SceneManager.add_player_exp(180)

	# Rơi ra hòm phần thưởng ngẫu nhiên 1 trong 10 vũ khí thần khí
	_spawn_reward_chest()

	set_physics_process(false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	lightning_zones.clear()
	chain_lightnings.clear()
	storm_vortices.clear()
	thunder_cages.clear()
	storm_rotating_orbs.clear()
	if boss_hud:
		boss_hud.visible = false
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.55)
	tween.tween_callback(queue_free)

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
