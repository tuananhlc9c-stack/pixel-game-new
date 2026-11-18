extends CharacterBody2D

@export var boss_title: String = "GLURCH - THE SLIME TYRANT"
@export var jump_damage: int = 34
@export var contact_damage: int = 20
@export var slam_radius: float = 78.0
@export var aggro_range: float = 300.0
@export var knockback_force: float = 280.0
@export var projectile_scene: PackedScene = preload("res://scenes/entities/fireball_projectile.tscn")
@export var minion_scene: PackedScene = preload("res://scenes/entities/smile1.tscn")

# Toxic Trail parameters
@export var max_toxic_puddles: int = 6
@export var puddle_base_radius: float = 34.0
@export var puddle_enrage_radius: float = 48.0
@export var puddle_dot_damage: int = 8
@export var slime_burst_damage: int = 28
@export var slime_burst_radius: float = 82.0
@export var king_shockwave_max_radius: float = 135.0
@export var king_shockwave_damage: int = 30

enum State {
	IDLE,
	PREPARE_JUMP,
	AIRBORNE,
	LAND_RECOVERY,
	SPIT_BARRAGE,
	SLIME_BURST_WINDUP,
	SLIME_BURST_ACTIVE,
	SLIME_BURST_RECOVERY,
	SLIME_SPLIT_WINDUP,
	KING_ABSORB_WINDUP
}

var current_state: State = State.IDLE
var current_phase: int = 1
var is_dead: bool = false

var player: Node2D = null
var is_enraged: bool = false
var has_triggered_split: bool = false
var has_triggered_king: bool = false
var is_king_jump_sequence: bool = false

var state_timer: float = 0.0
var state_max_timer: float = 0.5
var attack_cycle: int = 0
var jump_duration: float = 0.72
var jump_elapsed: float = 0.0
var jump_start_pos: Vector2 = Vector2.ZERO
var jump_target_pos: Vector2 = Vector2.ZERO
var consecutive_jumps_left: int = 0
var shockwave_progress: float = -1.0
var spawned_minions_count: int = 0

# Toxic Puddles: { "pos": Vector2, "radius": float, "timer": float, "max_time": float, "tick_timer": float }
var toxic_puddles: Array[Dictionary] = []
# Expanding Shockwaves (King of Slime): { "pos": Vector2, "radius": float, "max_radius": float, "progress": float, "hit_player": bool }
var active_shockwaves: Array[Dictionary] = []
# Absorbing puddle visuals during King of Slime windup: { "start_pos": Vector2, "radius": float }
var absorbing_puddles: Array[Dictionary] = []

# Slime Split tracking
var split_minions: Array[Node2D] = []
var all_spawned_minions: Array[Node2D] = []
var split_merge_timer: float = -1.0

# Boss UI
var boss_hud: CanvasLayer = null
var hp_bar: ProgressBar = null
var title_label: Label = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_comp: HealthComponent = $HealthComponent
@onready var hitbox: Area2D = $Hitbox
@onready var body_col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	if health_comp:
		health_comp.died.connect(_on_died)
		health_comp.health_changed.connect(_on_health_changed)
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	if anim:
		anim.play("idle")
	_create_boss_hud()

func _create_boss_hud() -> void:
	var bar := BossHealthBar.new()
	var max_hp: float = float(health_comp.max_health) if health_comp else 100.0
	var cur_hp: float = float(health_comp.current_health) if health_comp else max_hp
	bar.setup(boss_title, Color(0.9, 0.2, 0.35), max_hp, cur_hp)
	bar.visible = false
	add_child(bar)
	boss_hud = bar
	hp_bar = bar.hp_bar
	title_label = bar.title_label

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if shockwave_progress >= 0.0:
		shockwave_progress += delta * 2.8
		if shockwave_progress > 1.0:
			shockwave_progress = -1.0
		queue_redraw()

	_find_player()
	_update_toxic_puddles(delta)
	_update_expanding_shockwaves(delta)
	_update_split_minions(delta)

	if not player or not is_instance_valid(player):
		return

	var dist: float = global_position.distance_to(player.global_position)
	if boss_hud:
		boss_hud.visible = dist <= aggro_range * 1.4

	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			if dist <= aggro_range:
				state_timer -= delta
				if state_timer <= 0.0:
					_choose_next_action()

		State.PREPARE_JUMP:
			velocity = Vector2.ZERO
			state_timer -= delta
			# Hiệu ứng nén người chuẩn bị bật nhảy (WINDUP)
			if anim:
				var BaseScale := 2.25 if split_merge_timer > 0.0 else 2.5
				anim.scale = Vector2(BaseScale * 1.16, BaseScale * 0.8)
			queue_redraw()
			if state_timer <= 0.0:
				_launch_jump()

		State.AIRBORNE:
			jump_elapsed += delta
			var t: float = clampf(jump_elapsed / jump_duration, 0.0, 1.0)
			global_position = jump_start_pos.lerp(jump_target_pos, t)
			# Parabol độ cao giả lập 2.5D (ACTIVE)
			var height_offset: float = sin(t * PI) * (105.0 if is_king_jump_sequence else 85.0)
			if anim:
				var BaseScale := 2.25 if split_merge_timer > 0.0 else 2.5
				anim.position = Vector2(0, -10.0 - height_offset)
				anim.scale = Vector2(BaseScale * 0.92, BaseScale * 1.08)
			queue_redraw()
			if t >= 1.0:
				_land_slam()

		State.LAND_RECOVERY:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				consecutive_jumps_left -= 1
				if consecutive_jumps_left > 0:
					_start_prepare_jump()
				else:
					if is_king_jump_sequence:
						is_king_jump_sequence = false
						current_state = State.IDLE
						state_timer = 1.05
					else:
						_start_spit_barrage()

		State.SPIT_BARRAGE:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.IDLE
				state_timer = 0.65 if is_enraged else 1.15

		State.SLIME_BURST_WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			var progress: float = clampf(1.0 - (state_timer / maxf(state_max_timer, 0.01)), 0.0, 1.0)
			if anim:
				var BaseScale := 2.25 if split_merge_timer > 0.0 else 2.5
				var swell: float = 1.0 + progress * 0.38 + sin(progress * PI * 8.0) * 0.06
				anim.scale = Vector2(BaseScale * swell, BaseScale * swell)
			queue_redraw()
			if state_timer <= 0.0:
				_execute_slime_burst()

		State.SLIME_BURST_ACTIVE:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				current_state = State.SLIME_BURST_RECOVERY
				state_timer = 0.65 if is_enraged else 0.85
				if anim:
					var BaseScale := 2.25 if split_merge_timer > 0.0 else 2.5
					anim.scale = Vector2(BaseScale, BaseScale)

		State.SLIME_BURST_RECOVERY:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.IDLE
				state_timer = 0.6 if is_enraged else 0.95

		State.SLIME_SPLIT_WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			if anim:
				anim.position.x = randf_range(-3.0, 3.0)
				anim.scale = Vector2(2.85, 2.15)
			queue_redraw()
			if state_timer <= 0.0:
				if anim:
					anim.position.x = 0.0
				_execute_slime_split()

		State.KING_ABSORB_WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			if anim:
				var pulse := 1.0 + sin(state_timer * 20.0) * 0.12
				anim.scale = Vector2(2.75 * pulse, 2.75 * pulse)
			queue_redraw()
			if state_timer <= 0.0:
				absorbing_puddles.clear()
				is_king_jump_sequence = true
				consecutive_jumps_left = 3
				_start_prepare_jump()

	if current_state != State.AIRBORNE:
		move_and_slide()

func _choose_next_action() -> void:
	attack_cycle += 1
	if current_phase >= 2 and attack_cycle % 2 == 0:
		_start_slime_burst()
	else:
		consecutive_jumps_left = 2 if is_enraged else 1
		_start_prepare_jump()

func _start_prepare_jump() -> void:
	current_state = State.PREPARE_JUMP
	# Give the player enough time to dodge each attack during King of Slime
	if is_king_jump_sequence:
		state_timer = 0.62
	else:
		state_timer = 0.38 if is_enraged else 0.52
	state_max_timer = state_timer

	if player and is_instance_valid(player):
		var to_player: Vector2 = player.global_position - global_position
		var max_leap: float = 155.0 if is_king_jump_sequence else (135.0 if is_enraged else 105.0)
		if to_player.length() > max_leap:
			to_player = to_player.normalized() * max_leap
		jump_target_pos = global_position + to_player
	else:
		jump_target_pos = global_position

func _launch_jump() -> void:
	current_state = State.AIRBORNE
	jump_elapsed = 0.0
	if is_king_jump_sequence:
		jump_duration = 0.68
	else:
		jump_duration = 0.55 if is_enraged else 0.72
	jump_start_pos = global_position
	# Khi đang trên không thì tắt va chạm để nhảy qua đầu Player
	if body_col:
		body_col.set_deferred("disabled", true)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	if anim:
		anim.play("jump")

func _land_slam() -> void:
	current_state = State.LAND_RECOVERY
	if is_king_jump_sequence:
		state_timer = 0.58 # Đủ thời gian để người chơi né đòn nhảy tiếp theo
	else:
		state_timer = 0.35 if is_enraged else 0.55
	shockwave_progress = 0.0
	if anim:
		var BaseScale := 2.25 if split_merge_timer > 0.0 else 2.5
		anim.position = Vector2(0, -10)
		anim.scale = Vector2(BaseScale, BaseScale)
		anim.play("idle")
	if body_col:
		body_col.set_deferred("disabled", false)
	if hitbox:
		hitbox.set_deferred("monitoring", true)

	# Gây sát thương AoE nếu Player đứng trong vùng dậm đất
	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 2.0, 0.85, 1.0)
	if player and is_instance_valid(player):
		if player.has_method("apply_screen_shake"):
			player.apply_screen_shake(5.5 if is_king_jump_sequence else 3.5, 0.25)
		var d: float = global_position.distance_to(player.global_position)
		if d <= slam_radius and player.has_method("take_damage"):
			player.take_damage(jump_damage, global_position, knockback_force)

	# Skill 1: Toxic Trail - tạo vũng chất độc mỗi khi tiếp đất
	_spawn_toxic_puddle(global_position)

	# Ultimate: King of Slime - sóng chấn động lớn lan tỏa khi tiếp đất
	if is_king_jump_sequence:
		active_shockwaves.append({
			"pos": global_position,
			"radius": slam_radius * 0.4,
			"max_radius": king_shockwave_max_radius,
			"progress": 0.0,
			"hit_player": false
		})

	queue_redraw()

# -------------------------------------------------------------
# SKILL 1: TOXIC TRAIL (VŨNG ĐỘC SLIME)
# -------------------------------------------------------------
func _spawn_toxic_puddle(pos: Vector2, custom_radius: float = -1.0) -> void:
	if is_dead:
		return
	var r: float = custom_radius if custom_radius > 0.0 else (puddle_enrage_radius if is_enraged else puddle_base_radius)
	var dur: float = randf_range(5.0, 7.0)
	while toxic_puddles.size() >= max_toxic_puddles:
		toxic_puddles.pop_front()
	toxic_puddles.append({
		"pos": pos,
		"radius": r,
		"timer": dur,
		"max_time": dur,
		"tick_timer": 0.0
	})
	queue_redraw()

func _update_toxic_puddles(delta: float) -> void:
	if toxic_puddles.is_empty():
		return
	var player_in_any_puddle: bool = false
	var i: int = toxic_puddles.size() - 1
	while i >= 0:
		var p: Dictionary = toxic_puddles[i]
		p["timer"] = float(p["timer"]) - delta
		p["tick_timer"] = maxf(0.0, float(p["tick_timer"]) - delta)
		if float(p["timer"]) <= 0.0:
			toxic_puddles.remove_at(i)
			i -= 1
			continue

		if player and is_instance_valid(player):
			var p_pos: Vector2 = p["pos"]
			var dist: float = player.global_position.distance_to(p_pos)
			if dist <= float(p["radius"]):
				player_in_any_puddle = true
				if float(p["tick_timer"]) <= 0.0:
					p["tick_timer"] = 0.85
					if player.has_method("take_damage"):
						player.take_damage(puddle_dot_damage, p_pos, 45.0)
		toxic_puddles[i] = p
		i -= 1

	if player_in_any_puddle and player and is_instance_valid(player):
		if player.has_method("apply_speed_modifier"):
			player.apply_speed_modifier(0.70, 0.2) # Giảm 30% tốc độ di chuyển
	queue_redraw()

# -------------------------------------------------------------
# SKILL 2: SLIME SPLIT (PHÂN TÁCH SLIME KHI HP < 40%)
# -------------------------------------------------------------
func _start_slime_split() -> void:
	current_state = State.SLIME_SPLIT_WINDUP
	state_timer = 0.65
	state_max_timer = 0.65
	if body_col:
		body_col.set_deferred("disabled", false)
	if hitbox:
		hitbox.set_deferred("monitoring", true)
	if anim:
		anim.position = Vector2(0, -10)
		anim.play("idle")
	queue_redraw()

func _execute_slime_split() -> void:
	split_minions.clear()
	split_merge_timer = 10.0
	if anim:
		anim.scale = Vector2(2.25, 2.25)
	if AudioManager:
		AudioManager.play_sfx_random_pitch("projectile", 1.5, 0.75, 0.95)

	if minion_scene and get_parent():
		for i in range(2):
			var m: Node2D = minion_scene.instantiate()
			var side_angle := (0.0 if i == 0 else PI) + randf_range(-0.3, 0.3)
			m.global_position = global_position + Vector2.RIGHT.rotated(side_angle) * 44.0
			m.scale = Vector2(1.3, 1.3)
			if "can_jump_chase" in m:
				m.set("can_jump_chase", true)
			if "chase_radius" in m:
				m.set("chase_radius", 320.0)
			if "chase_speed" in m:
				m.set("chase_speed", 64.0)
			if "max_health" in m:
				m.set("max_health", 85)
			get_parent().call_deferred("add_child", m)
			split_minions.append(m)
			all_spawned_minions.append(m)

	current_state = State.IDLE
	state_timer = 0.6
	queue_redraw()

func _update_split_minions(delta: float) -> void:
	if split_merge_timer < 0.0:
		return

	# Lọc các minion còn sống
	var alive_list: Array[Node2D] = []
	for m in split_minions:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			alive_list.append(m)
	split_minions = alive_list

	if split_minions.is_empty():
		split_merge_timer = -1.0
		if anim:
			anim.scale = Vector2(2.5, 2.5)
		return

	split_merge_timer -= delta
	# Trong 1.2 giây cuối, kéo các minion còn sống về phía Glurch để hợp thể
	if split_merge_timer <= 1.2:
		for m in split_minions:
			if is_instance_valid(m):
				m.global_position = m.global_position.lerp(global_position, delta * 6.5)
		queue_redraw()

	if split_merge_timer <= 0.0:
		var surviving_count: int = split_minions.size()
		for m in split_minions:
			if is_instance_valid(m):
				m.queue_free()
		split_minions.clear()
		split_merge_timer = -1.0
		if anim:
			anim.scale = Vector2(2.5, 2.5)
		if health_comp and surviving_count > 0 and not is_dead:
			var heal_amount: int = 45 * surviving_count
			health_comp.heal(heal_amount)
			if hp_bar:
				hp_bar.value = health_comp.current_health
			if AudioManager:
				AudioManager.play_sfx_random_pitch("set", 1.0, 0.85, 1.05)

# -------------------------------------------------------------
# SKILL 3: SLIME BURST (PHÌNH TO PHÁT NỔ BẮN 8 HƯỚNG)
# -------------------------------------------------------------
func _start_slime_burst() -> void:
	current_state = State.SLIME_BURST_WINDUP
	state_timer = 0.68 if is_enraged else 0.85
	state_max_timer = state_timer
	queue_redraw()

func _execute_slime_burst() -> void:
	current_state = State.SLIME_BURST_ACTIVE
	state_timer = 0.25
	shockwave_progress = 0.0

	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 1.5, 0.95, 1.15)

	# Gây sát thương vùng nổ quanh thân nếu Player đứng trong vòng cảnh báo
	if player and is_instance_valid(player):
		if player.has_method("apply_screen_shake"):
			player.apply_screen_shake(4.0, 0.22)
		if global_position.distance_to(player.global_position) <= slime_burst_radius and player.has_method("take_damage"):
			player.take_damage(slime_burst_damage, global_position, knockback_force)

	# Bắn 8 viên đạn Slime theo 8 hướng; một số viên tạo vũng độc khi đáp đất
	if projectile_scene and get_parent():
		var proj_speed: float = 155.0 if is_enraged else 115.0
		for i in range(8):
			var angle: float = (TAU / 8.0) * float(i)
			var dir: Vector2 = Vector2.RIGHT.rotated(angle)
			var proj: Node2D = projectile_scene.instantiate()
			proj.global_position = global_position + dir * 20.0
			if proj.has_method("setup"):
				proj.setup(dir, proj_speed, 15, Color(0.45, 0.95, 0.35, 1.0), self)
			# Cứ viên chẵn thì có thời gian bay ngắn và tạo vũng chất độc khi chạm đất
			if i % 2 == 0:
				proj.set("lifetime", randf_range(0.75, 1.05))
				var boss_ref: WeakRef = weakref(self)
				proj.set("on_expire_callback", func(land_pos: Vector2) -> void:
					var b: Object = boss_ref.get_ref()
					if b and is_instance_valid(b) and not b.get("is_dead"):
						b.call("_spawn_toxic_puddle", land_pos, 26.0)
				)
			get_parent().add_child(proj)
	queue_redraw()

# -------------------------------------------------------------
# ULTIMATE: KING OF SLIME (HẤP THỤ VŨNG ĐỘC & 3 CÚ DẬM ĐẠI CHẤN)
# -------------------------------------------------------------
func _start_king_of_slime() -> void:
	current_state = State.KING_ABSORB_WINDUP
	state_timer = 0.85
	state_max_timer = 0.85
	if body_col:
		body_col.set_deferred("disabled", false)
	if hitbox:
		hitbox.set_deferred("monitoring", true)
	if anim:
		anim.position = Vector2(0, -10)
		anim.play("idle")

	# Hấp thụ toàn bộ các vũng chất độc đang hoạt động trên sân
	absorbing_puddles.clear()
	var absorbed_count: int = toxic_puddles.size()
	for p in toxic_puddles:
		absorbing_puddles.append({
			"start_pos": p["pos"],
			"radius": p["radius"]
		})
	toxic_puddles.clear()

	if absorbed_count > 0 and health_comp and not is_dead:
		health_comp.heal(absorbed_count * 15)
		if hp_bar:
			hp_bar.value = health_comp.current_health

	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 2.0, 0.7, 0.85)
	queue_redraw()

func _update_expanding_shockwaves(delta: float) -> void:
	if active_shockwaves.is_empty():
		return
	var i: int = active_shockwaves.size() - 1
	while i >= 0:
		var sw: Dictionary = active_shockwaves[i]
		sw["progress"] = float(sw["progress"]) + delta * 1.45
		var prog: float = float(sw["progress"])
		var cur_r: float = lerpf(slam_radius * 0.35, float(sw["max_radius"]), clampf(prog, 0.0, 1.0))
		sw["radius"] = cur_r

		if not bool(sw["hit_player"]) and player and is_instance_valid(player):
			var sw_pos: Vector2 = sw["pos"]
			var dist: float = player.global_position.distance_to(sw_pos)
			# Kiểm tra nếu người chơi đứng ngay trên vành sóng xung kích đang lan rộng
			if absf(dist - cur_r) <= 18.0 and player.has_method("take_damage"):
				sw["hit_player"] = true
				player.take_damage(king_shockwave_damage, sw_pos, knockback_force * 1.15)

		if prog >= 1.0:
			active_shockwaves.remove_at(i)
			i -= 1
			continue
		active_shockwaves[i] = sw
		i -= 1
	queue_redraw()

func _start_spit_barrage() -> void:
	current_state = State.SPIT_BARRAGE
	state_timer = 0.45
	if not projectile_scene or not get_parent():
		return
	var count: int = 10 if is_enraged else 6
	var base_angle: float = randf() * TAU
	if AudioManager:
		AudioManager.play_sfx_random_pitch("projectile", 0.0, 0.9, 1.1)
	for i in range(count):
		var angle: float = base_angle + (TAU / float(count)) * float(i)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var proj: Node2D = projectile_scene.instantiate()
		proj.global_position = global_position + dir * 18.0
		if proj.has_method("setup"):
			proj.setup(dir, 115.0 if is_enraged else 95.0, 12, Color(0.95, 0.35, 0.65, 1.0), self)
		get_parent().add_child(proj)

func _spawn_minion() -> void:
	if not minion_scene or not get_parent() or spawned_minions_count >= 4 or is_dead:
		return
	spawned_minions_count += 1
	var m: Node2D = minion_scene.instantiate()
	var offset := Vector2.RIGHT.rotated(randf() * TAU) * 42.0
	m.global_position = global_position + offset
	get_parent().call_deferred("add_child", m)
	all_spawned_minions.append(m)

func _draw() -> void:
	if is_dead:
		return

	# 1. Vẽ các vũng chất độc (Skill 1: Toxic Trail)
	for p in toxic_puddles:
		var local_p: Vector2 = p["pos"] - global_position
		var r: float = float(p["radius"])
		var life_ratio: float = clampf(float(p["timer"]) / maxf(float(p["max_time"]), 0.01), 0.0, 1.0)
		var alpha: float = clampf(life_ratio * 1.5, 0.0, 1.0)
		draw_circle(local_p, r, Color(0.22, 0.82, 0.28, 0.28 * alpha))
		draw_circle(local_p, r * 0.68, Color(0.35, 0.95, 0.38, 0.22 * alpha))
		draw_arc(local_p, r, 0.0, TAU, 32, Color(0.3, 1.0, 0.35, 0.75 * alpha), 1.8)

	# 2. Vẽ hiệu ứng hút các vũng chất độc về phía Glurch khi kích hoạt King of Slime
	if current_state == State.KING_ABSORB_WINDUP:
		var t_absorb: float = clampf(1.0 - (state_timer / maxf(state_max_timer, 0.01)), 0.0, 1.0)
		for ap in absorbing_puddles:
			var cur_world: Vector2 = (ap["start_pos"] as Vector2).lerp(global_position, t_absorb)
			var local_ap: Vector2 = cur_world - global_position
			var r_ap: float = float(ap["radius"]) * (1.0 - t_absorb * 0.7)
			draw_circle(local_ap, r_ap, Color(0.35, 1.0, 0.4, 0.55 * (1.0 - t_absorb)))
			draw_line(local_ap, Vector2.ZERO, Color(0.45, 1.0, 0.5, 0.6 * (1.0 - t_absorb)), 2.0)
		draw_arc(Vector2.ZERO, slam_radius * (1.3 - t_absorb * 0.8), 0.0, TAU, 40, Color(1.0, 0.85, 0.2, 0.85), 2.5)

	# 3. Vẽ cảnh báo Slime Burst (Skill 3)
	if current_state == State.SLIME_BURST_WINDUP:
		var prog: float = clampf(1.0 - (state_timer / maxf(state_max_timer, 0.01)), 0.0, 1.0)
		draw_circle(Vector2.ZERO, slime_burst_radius, Color(0.35, 0.95, 0.35, 0.16))
		draw_circle(Vector2.ZERO, slime_burst_radius * prog, Color(0.45, 1.0, 0.4, 0.28))
		draw_arc(Vector2.ZERO, slime_burst_radius, 0.0, TAU, 40, Color(0.4, 1.0, 0.35, 0.9), 2.2)
		# Vẽ 8 đường định hướng tia bắn
		for i in range(8):
			var dir := Vector2.RIGHT.rotated((TAU / 8.0) * float(i))
			draw_line(dir * 20.0, dir * (slime_burst_radius + 22.0), Color(0.5, 1.0, 0.45, 0.45 + prog * 0.4), 1.8)

	# 4. Vẽ cảnh báo Slime Split (Skill 2) và dây liên kết hợp thể
	if current_state == State.SLIME_SPLIT_WINDUP:
		draw_arc(Vector2.ZERO, 48.0, 0.0, TAU, 32, Color(0.4, 1.0, 0.6, 0.85), 2.2)
	if split_merge_timer > 0.0 and split_merge_timer <= 2.5:
		for m in split_minions:
			if is_instance_valid(m):
				draw_line(Vector2.ZERO, m.global_position - global_position, Color(0.4, 1.0, 0.5, 0.65), 2.0)

	# 5. Vẽ bóng đen và vòng tròn cảnh báo vị trí rơi khi Glurch đang chuẩn bị nhảy / đang trên không
	if current_state == State.PREPARE_JUMP or current_state == State.AIRBORNE:
		var local_target: Vector2 = jump_target_pos - global_position
		draw_circle(local_target, slam_radius, Color(0.95, 0.15, 0.2, 0.22))
		draw_arc(local_target, slam_radius, 0.0, TAU, 40, Color(1.0, 0.25, 0.25, 0.85), 2.0)
		if is_king_jump_sequence:
			draw_arc(local_target, king_shockwave_max_radius, 0.0, TAU, 48, Color(1.0, 0.75, 0.2, 0.45), 1.6)
		# Bóng của Glurch dưới mặt đất
		draw_circle(Vector2.ZERO, 24.0, Color(0.0, 0.0, 0.0, 0.38))

	# 6. Sóng chấn động khi tiếp đất thường
	if shockwave_progress >= 0.0:
		var r: float = slam_radius * shockwave_progress
		var alpha: float = 1.0 - shockwave_progress
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 42, Color(1.0, 0.45, 0.65, alpha), 3.5)

	# 7. Sóng chấn động khổng lồ (King of Slime)
	for sw in active_shockwaves:
		var local_sw: Vector2 = sw["pos"] - global_position
		var r_sw: float = float(sw["radius"])
		var alpha_sw: float = clampf(1.0 - float(sw["progress"]), 0.0, 1.0)
		draw_arc(local_sw, r_sw, 0.0, TAU, 48, Color(1.0, 0.82, 0.25, alpha_sw * 0.95), 4.5)
		draw_arc(local_sw, maxf(4.0, r_sw - 8.0), 0.0, TAU, 44, Color(0.35, 1.0, 0.45, alpha_sw * 0.65), 2.2)

func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player")
	if not player and get_parent():
		player = get_parent().get_node_or_null("Player")

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead or current_state == State.AIRBORNE:
		return
	if (body.name == "Player" or body.is_in_group("player")) and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position, knockback_force * 0.8)

func take_damage(amount: int, _source_pos: Vector2 = Vector2.ZERO, _kb_force: float = 0.0) -> void:
	if is_dead or current_state == State.AIRBORNE:
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

	# Kích hoạt Phase 2 Enrage khi máu <= 50% (chỉ 1 lần)
	if not is_enraged and hp_ratio <= 0.50:
		is_enraged = true
		current_phase = 2
		if title_label:
			title_label.text = boss_title + " (CUỒNG NỘ)"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		if boss_hud and boss_hud.has_method("set_accent"):
			boss_hud.set_accent(Color(0.95, 0.32, 0.2))
		_spawn_minion()
		_spawn_minion()

	# Kích hoạt Skill 2: Slime Split khi máu <= 40% (chỉ 1 lần)
	if not has_triggered_split and hp_ratio <= 0.40:
		has_triggered_split = true
		if current_state != State.AIRBORNE:
			_start_slime_split()

	# Kích hoạt Phase 3 Ultimate: King of Slime khi máu <= 20% (chỉ 1 lần)
	if not has_triggered_king and hp_ratio <= 0.20:
		has_triggered_king = true
		current_phase = 3
		if title_label:
			title_label.text = boss_title + " (VUA SLIME)"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_start_king_of_slime()

	if anim:
		var base_col: Color = Color(1.0, 0.55, 0.45) if is_enraged else Color.WHITE
		anim.modulate = Color(1.0, 0.2, 0.2)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", base_col, 0.15)

func _cleanup_all_minions_and_effects() -> void:
	toxic_puddles.clear()
	active_shockwaves.clear()
	absorbing_puddles.clear()
	for m in split_minions:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			m.queue_free()
	split_minions.clear()
	for m in all_spawned_minions:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			m.queue_free()
	all_spawned_minions.clear()

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true

	if SceneManager and SceneManager.has_method("add_player_exp"):
		SceneManager.add_player_exp(90)

	_cleanup_all_minions_and_effects()

	# Rơi ra hòm phần thưởng ngẫu nhiên 1 trong 10 vũ khí thần khí
	_spawn_reward_chest()

	set_physics_process(false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	if body_col:
		body_col.set_deferred("disabled", true)
	if boss_hud:
		boss_hud.visible = false
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
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
