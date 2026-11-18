extends CharacterBody2D


@export var boss_title: String = "TITAN - ANCIENT COLOSSUS"
@export var aggro_range: float = 350.0
@export var move_speed: float = 40.0
@export var charge_speed: float = 280.0
@export var contact_damage: int = 26
@export var charge_damage: int = 46
@export var rock_fall_damage: int = 48
@export var earthquake_damage: int = 38
@export var knockback_force: float = 300.0
@export var boss_sheet_tex: Texture2D = preload("res://Content T1/Character/Monter/Boss/boss3.png")
@export var fist_damage: int = 38
@export var spike_damage: int = 32
@export var world_breaker_damage: int = 44

enum State {
	IDLE,
	CHASE,
	CHARGE_WINDUP,
	CHARGING,
	CAST_FALLING_ROCKS,
	CAST_EARTHQUAKE,
	CAST_ANCIENT_ARMOR,
	TITAN_FIST_WINDUP,
	TITAN_FIST_STRIKE,
	CAST_EARTH_SPIKES,
	WORLD_BREAKER_WINDUP,
	WORLD_BREAKER_ACTIVE,
	STUNNED,
	RECOVER
}

var current_state: State = State.IDLE
var current_phase: int = 1
var is_dead: bool = false

var player: Node2D = null
var is_enraged: bool = false
var has_triggered_world_breaker: bool = false
var spawn_origin: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var attack_cycle: int = 0
var charge_direction: Vector2 = Vector2.ZERO
var charge_duration_timer: float = 0.0

# Danh sách vùng động đất và quả cầu rơi
# rock_zones: { "target_pos": Vector2, "timer": float, "max_time": float, "has_impacted": bool, "radius": float }
var rock_zones: Array[Dictionary] = []
# quake_shards: { "pos": Vector2, "timer": float, "max_time": float, "has_hit": bool, "radius": float, "frame_idx": int }
var quake_shards: Array[Dictionary] = []

# Skill 1: Ancient Armor & Weak-point Crystals
var is_armored: bool = false
var armor_cooldown: float = 0.0
# weak_points: { "offset": Vector2, "hp": int, "max_hp": int }
var weak_points: Array[Dictionary] = []

# Skill 2: Titan Fist
var punches_remaining: int = 0
var is_final_punch: bool = false
var fist_target_pos: Vector2 = Vector2.ZERO
var fist_direction: Vector2 = Vector2.DOWN
var fist_radius: float = 38.0
# fist_waves: { "pos": Vector2, "dir": Vector2, "dist": float, "max_dist": float, "radius": float, "hit": bool }
var fist_waves: Array[Dictionary] = []

# Skill 3: Earth Spikes
# earth_spikes: { "pos": Vector2, "warn_timer": float, "max_warn": float, "active_timer": float, "erupted": bool, "radius": float, "body": StaticBody2D }
var earth_spikes: Array[Dictionary] = []

# Ultimate: World Breaker
# world_cracks: { "pos": Vector2, "warn_timer": float, "max_warn": float, "exploded": float, "radius": float, "is_safe": bool }
var world_cracks: Array[Dictionary] = []

# Mảnh vỡ mặt đất từ sprite boss3.png (x=417..641, y=120..160, mỗi frame 32x38)
var ground_shard_textures: Array[AtlasTexture] = []

# Boss HUD
var boss_hud: CanvasLayer = null
var hp_bar: ProgressBar = null
var title_label: Label = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var health_comp: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	spawn_origin = global_position
	state_timer = 1.0

	_build_ground_shard_textures()

	if health_comp:
		health_comp.died.connect(_on_died)
		health_comp.health_changed.connect(_on_health_changed)
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	if anim:
		anim.play("idle")

	_create_boss_hud()

func _build_ground_shard_textures() -> void:
	if not boss_sheet_tex:
		return
	ground_shard_textures.clear()
	for i in range(7):
		var atl := AtlasTexture.new()
		atl.atlas = boss_sheet_tex
		atl.region = Rect2(417 + i * 32, 120, 32, 40)
		ground_shard_textures.append(atl)

func _create_boss_hud() -> void:
	var bar := BossHealthBar.new()
	var max_hp: float = float(health_comp.max_health) if health_comp else 100.0
	var cur_hp: float = float(health_comp.current_health) if health_comp else max_hp
	bar.setup(boss_title, Color(0.95, 0.52, 0.18), max_hp, cur_hp)
	bar.visible = false
	add_child(bar)
	boss_hud = bar
	hp_bar = bar.hp_bar
	title_label = bar.title_label

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var dist_to_player := global_position.distance_to(player.global_position) if player else 9999.0
	if dist_to_player <= aggro_range:
		if boss_hud and not boss_hud.visible:
			boss_hud.visible = true

	state_timer -= delta
	if armor_cooldown > 0.0:
		armor_cooldown -= delta

	# Cập nhật các hiệu ứng kỹ năng
	_process_falling_rocks(delta)
	_process_earthquake_shards(delta)
	_process_fist_waves(delta)
	_process_earth_spikes(delta)
	_process_world_cracks(delta)

	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			if anim and anim.animation != "idle":
				anim.play("idle")
			if dist_to_player <= aggro_range and state_timer <= 0.0:
				current_state = State.CHASE
				state_timer = randf_range(1.2, 2.1)

		State.CHASE:
			if not player:
				current_state = State.IDLE
				state_timer = 1.0
			else:
				var move_dir := (player.global_position - global_position).normalized()
				var armor_mult := 0.65 if is_armored else 1.0
				var cur_speed := move_speed * (1.3 if is_enraged else 1.0) * armor_mult
				velocity = move_dir * cur_speed
				if anim:
					anim.flip_h = (move_dir.x < 0)
					if anim.animation != "walk":
						anim.play("walk")

				# Khi đuổi tới gần hoặc hết thời gian rượt đuổi -> tung kỹ năng
				if state_timer <= 0.0 or dist_to_player <= 78.0:
					_choose_next_skill()

		State.CHARGE_WINDUP:
			velocity = Vector2.ZERO
			if anim and anim.animation != "charge":
				anim.play("charge")
			if player:
				charge_direction = (player.global_position - global_position).normalized()
				if anim:
					anim.flip_h = (charge_direction.x < 0)

			# Rung lắc tạo cảm giác lấy đà húc
			if anim:
				anim.position.x = randf_range(-2.5, 2.5)

			if state_timer <= 0.0:
				if anim:
					anim.position.x = 0.0
				current_state = State.CHARGING
				charge_duration_timer = 0.9 if not is_enraged else 1.15
				state_timer = charge_duration_timer

		State.CHARGING:
			var armor_mult := 0.8 if is_armored else 1.0
			velocity = charge_direction * (charge_speed * (1.22 if is_enraged else 1.0) * armor_mult)
			if anim and anim.animation != "charge":
				anim.play("charge")

			# Để lại các chấn động nhỏ trên đường lao
			if fmod(state_timer, 0.12) < delta:
				_spawn_mini_dust(global_position)

			# Va vào tường hoặc hết thời gian lao
			if is_on_wall() or state_timer <= 0.0:
				_on_charge_impact()

		State.CAST_FALLING_ROCKS, State.CAST_EARTHQUAKE, State.CAST_ANCIENT_ARMOR, State.CAST_EARTH_SPIKES:
			velocity = Vector2.ZERO
			if anim and anim.animation != "charge":
				anim.play("charge")
			if state_timer <= 0.0:
				current_state = State.RECOVER
				state_timer = 0.75 if not is_enraged else 0.55

		State.TITAN_FIST_WINDUP:
			velocity = Vector2.ZERO
			if anim and anim.animation != "charge":
				anim.play("charge")
			if anim:
				anim.position.y = -28.0 - sin(clampf(1.0 - state_timer / 0.55, 0.0, 1.0) * PI * 0.5) * 6.0
			if state_timer <= 0.0:
				if anim:
					anim.position.y = -28.0
				_execute_titan_fist_strike()

		State.TITAN_FIST_STRIKE:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				if punches_remaining > 0:
					_start_next_titan_fist()
				else:
					current_state = State.RECOVER
					state_timer = 0.8

		State.WORLD_BREAKER_WINDUP:
			velocity = Vector2.ZERO
			if anim:
				anim.play("charge")
				anim.position.x = randf_range(-3.5, 3.5)
			if state_timer <= 0.0:
				if anim:
					anim.position.x = 0.0
				_execute_world_breaker_active()

		State.WORLD_BREAKER_ACTIVE:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				# Sau khi hoàn tất World Breaker, Titan bị choáng ngắn (stunned briefly)
				_enter_stun_state(2.2)

		State.STUNNED:
			velocity = Vector2.ZERO
			if anim:
				anim.play("idle")
				anim.position.x = sin(state_timer * 28.0) * 1.5
			if state_timer <= 0.0:
				if anim:
					anim.position.x = 0.0
				current_state = State.CHASE
				state_timer = 1.2

		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)
			if anim and anim.animation != "idle":
				anim.play("idle")
			if state_timer <= 0.0:
				current_state = State.CHASE
				state_timer = randf_range(1.1, 1.8)

	move_and_slide()
	queue_redraw()

func _choose_next_skill() -> void:
	attack_cycle += 1
	if not is_enraged:
		# Phase 1: Charge, Falling Rocks, Earthquake
		var slot := attack_cycle % 3
		match slot:
			0:
				current_state = State.CHARGE_WINDUP
				state_timer = 0.65
				if player:
					charge_direction = (player.global_position - global_position).normalized()
			1:
				current_state = State.CAST_FALLING_ROCKS
				state_timer = 0.6
				_trigger_falling_rocks_skill()
			_:
				current_state = State.CAST_EARTHQUAKE
				state_timer = 0.7
				_trigger_earthquake_skill()
	else:
		# Phase 2: Ancient Armor, Titan Fist, Earth Spikes + Charge & Falling Rocks
		if not is_armored and armor_cooldown <= 0.0 and attack_cycle % 4 == 0:
			_start_ancient_armor()
			return

		var slot := attack_cycle % 5
		match slot:
			0:
				_start_titan_fist_combo()
			1:
				_start_earth_spikes()
			2:
				current_state = State.CHARGE_WINDUP
				state_timer = 0.48
				if player:
					charge_direction = (player.global_position - global_position).normalized()
			3:
				current_state = State.CAST_FALLING_ROCKS
				state_timer = 0.6
				_trigger_falling_rocks_skill()
			_:
				current_state = State.CAST_EARTHQUAKE
				state_timer = 0.65
				_trigger_earthquake_skill()

func _on_charge_impact() -> void:
	# Khi tông vào tường hoặc kết thúc lao, tạo vụ nổ chấn động đất
	_trigger_earthquake_burst(global_position, 48.0)
	current_state = State.RECOVER
	state_timer = 0.9 if not is_enraged else 0.6

# -------------------------------------------------------------
# SKILL 1: ANCIENT ARMOR & WEAK-POINT CRYSTALS
# -------------------------------------------------------------
func _start_ancient_armor() -> void:
	current_state = State.CAST_ANCIENT_ARMOR
	state_timer = 0.65
	is_armored = true
	armor_cooldown = 16.0
	weak_points.clear()
	# Tạo 3 tinh thể điểm yếu phát sáng quanh cơ thể Titan
	var offsets: Array[Vector2] = [
		Vector2(-24, -22),
		Vector2(24, -22),
		Vector2(0, -44)
	]
	for off in offsets:
		weak_points.append({
			"offset": off,
			"hp": 90,
			"max_hp": 90
		})
	if AudioManager:
		AudioManager.play_sfx_random_pitch("set", 1.5, 0.75, 0.9)
	queue_redraw()

func _enter_stun_state(duration: float) -> void:
	current_state = State.STUNNED
	state_timer = duration
	is_armored = false
	weak_points.clear()
	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 1.5, 0.85, 1.0)
	queue_redraw()

# -------------------------------------------------------------
# SKILL 2: TITAN FIST (NẮM ĐẤM ĐÁ KHỔNG LỒ & SÓNG CHẤN ĐỘNG HƯỚNG)
# -------------------------------------------------------------
func _start_titan_fist_combo() -> void:
	punches_remaining = 3 if is_enraged else 2
	_start_next_titan_fist()

func _start_next_titan_fist() -> void:
	punches_remaining -= 1
	is_final_punch = (punches_remaining == 0)
	current_state = State.TITAN_FIST_WINDUP
	state_timer = 0.62 if is_final_punch else 0.48
	fist_radius = 52.0 if is_final_punch else 36.0

	if player and is_instance_valid(player):
		var to_p: Vector2 = player.global_position - global_position
		fist_direction = to_p.normalized() if to_p.length() > 1.0 else Vector2.DOWN
		var dist: float = clampf(to_p.length(), 32.0, 110.0)
		fist_target_pos = global_position + fist_direction * dist
		if anim:
			anim.flip_h = (fist_direction.x < 0)
	else:
		fist_direction = Vector2.DOWN
		fist_target_pos = global_position + Vector2.DOWN * 55.0
	queue_redraw()

func _execute_titan_fist_strike() -> void:
	current_state = State.TITAN_FIST_STRIKE
	state_timer = 0.32
	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 2.0, 0.8, 0.95)

	if player and is_instance_valid(player):
		if player.has_method("apply_screen_shake"):
			player.apply_screen_shake(5.0 if is_final_punch else 3.2, 0.22)
		if player.global_position.distance_to(fist_target_pos) <= fist_radius and player.has_method("take_damage"):
			var dmg: int = int(float(fist_damage) * (1.25 if is_final_punch else 1.0))
			player.take_damage(dmg, fist_target_pos, knockback_force)

	_spawn_ground_shatter_at(fist_target_pos)

	# Tạo sóng xung kích định hướng (Directional Shockwave)
	fist_waves.append({
		"pos": fist_target_pos,
		"dir": fist_direction,
		"dist": 0.0,
		"max_dist": 135.0 if is_final_punch else 95.0,
		"radius": 24.0 if is_final_punch else 16.0,
		"hit": false
	})
	queue_redraw()

func _process_fist_waves(delta: float) -> void:
	if fist_waves.is_empty():
		return
	var i: int = fist_waves.size() - 1
	while i >= 0:
		var fw: Dictionary = fist_waves[i]
		fw["dist"] = float(fw["dist"]) + delta * 240.0
		var cur_d: float = float(fw["dist"])
		var max_d: float = float(fw["max_dist"])
		var wave_pos: Vector2 = (fw["pos"] as Vector2) + (fw["dir"] as Vector2) * cur_d
		var r_fw: float = float(fw["radius"])

		if not bool(fw["hit"]) and player and is_instance_valid(player):
			if player.global_position.distance_to(wave_pos) <= r_fw and player.has_method("take_damage"):
				fw["hit"] = true
				player.take_damage(fist_damage - 8, wave_pos, knockback_force * 0.85)

		if cur_d >= max_d:
			fist_waves.remove_at(i)
			i -= 1
			continue
		fist_waves[i] = fw
		i -= 1
	queue_redraw()

# -------------------------------------------------------------
# SKILL 3: EARTH SPIKES (GAI ĐÁ TRỒI LÊN TUẦN TỰ & CHẶN ĐƯỜNG)
# -------------------------------------------------------------
func _start_earth_spikes() -> void:
	current_state = State.CAST_EARTH_SPIKES
	state_timer = 0.65
	var base_dir: Vector2 = Vector2.DOWN
	if player and is_instance_valid(player):
		base_dir = (player.global_position - global_position).normalized()
		if base_dir == Vector2.ZERO:
			base_dir = Vector2.DOWN

	var spike_count: int = 6 if is_enraged else 5
	for i in range(spike_count):
		var s_pos: Vector2 = global_position + base_dir * (38.0 + float(i) * 28.0)
		earth_spikes.append({
			"pos": s_pos,
			"warn_timer": 0.45 + float(i) * 0.14,
			"max_warn": 0.45 + float(i) * 0.14,
			"active_timer": 3.2,
			"erupted": false,
			"radius": 18.0,
			"body": null
		})
	queue_redraw()

func _process_earth_spikes(delta: float) -> void:
	if earth_spikes.is_empty():
		return
	var i: int = earth_spikes.size() - 1
	while i >= 0:
		var sp: Dictionary = earth_spikes[i]
		var s_pos: Vector2 = sp["pos"]
		var r_sp: float = float(sp["radius"])

		if not bool(sp["erupted"]):
			sp["warn_timer"] = float(sp["warn_timer"]) - delta
			if float(sp["warn_timer"]) <= 0.0:
				sp["erupted"] = true
				if AudioManager:
					AudioManager.play_sfx_random_pitch("explosion", 0.5, 1.0, 1.2)
				if player and is_instance_valid(player) and player.global_position.distance_to(s_pos) <= r_sp:
					if player.has_method("take_damage"):
						player.take_damage(spike_damage, s_pos, knockback_force * 0.8)
				# Tạo vật cản tạm thời chặn di chuyển
				if get_parent():
					var sb := StaticBody2D.new()
					sb.global_position = s_pos
					var col := CollisionShape2D.new()
					var c_shape := CircleShape2D.new()
					c_shape.radius = 12.0
					col.shape = c_shape
					sb.add_child(col)
					get_parent().add_child(sb)
					sp["body"] = sb
		else:
			sp["active_timer"] = float(sp["active_timer"]) - delta
			if float(sp["active_timer"]) <= 0.0:
				var b_node: Node2D = sp["body"]
				if b_node and is_instance_valid(b_node):
					b_node.queue_free()
				earth_spikes.remove_at(i)
				i -= 1
				continue
		earth_spikes[i] = sp
		i -= 1
	queue_redraw()

func _clear_earth_spikes() -> void:
	for sp in earth_spikes:
		var b_node: Node2D = sp["body"]
		if b_node and is_instance_valid(b_node):
			b_node.queue_free()
	earth_spikes.clear()

# -------------------------------------------------------------
# ULTIMATE: WORLD BREAKER (ĐẠI ĐỊA CHẤN NỨT VỠ ĐẤU TRƯỜNG)
# -------------------------------------------------------------
func _start_world_breaker() -> void:
	current_state = State.WORLD_BREAKER_WINDUP
	state_timer = 0.95
	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 2.5, 0.65, 0.8)
	queue_redraw()

func _execute_world_breaker_active() -> void:
	current_state = State.WORLD_BREAKER_ACTIVE
	state_timer = 2.6
	world_cracks.clear()

	if player and is_instance_valid(player) and player.has_method("apply_screen_shake"):
		player.apply_screen_shake(6.5, 0.45)

	# Tạo 6 đường nứt tỏa ra từ Titan, chừa rõ góc an toàn giữa các đường nứt
	var base_ang: float = randf() * TAU
	var num_lines: int = 6
	for l_idx in range(num_lines):
		var ang: float = base_ang + (TAU / float(num_lines)) * float(l_idx)
		var dir: Vector2 = Vector2.RIGHT.rotated(ang)
		for step in range(1, 6):
			var c_pos: Vector2 = global_position + dir * (float(step) * 34.0)
			var w_time: float = 0.45 + float(step) * 0.24
			world_cracks.append({
				"pos": c_pos,
				"warn_timer": w_time,
				"max_warn": w_time,
				"exploded": -1.0,
				"radius": 26.0
			})

	# Kèm theo đá tảng rơi từ trên cao xuống
	_trigger_falling_rocks_skill()
	queue_redraw()

func _process_world_cracks(delta: float) -> void:
	if world_cracks.is_empty():
		return
	var i: int = world_cracks.size() - 1
	while i >= 0:
		var wc: Dictionary = world_cracks[i]
		var exp_val: float = float(wc["exploded"])
		var c_pos: Vector2 = wc["pos"]
		var r_wc: float = float(wc["radius"])

		if exp_val < 0.0:
			wc["warn_timer"] = float(wc["warn_timer"]) - delta
			if float(wc["warn_timer"]) <= 0.0:
				wc["exploded"] = 0.0
				if AudioManager:
					AudioManager.play_sfx_random_pitch("explosion", 1.2, 0.85, 1.05)
				if player and is_instance_valid(player) and player.global_position.distance_to(c_pos) <= r_wc:
					if player.has_method("take_damage"):
						player.take_damage(world_breaker_damage, c_pos, knockback_force)
				_spawn_ground_shatter_at(c_pos)
		else:
			wc["exploded"] = exp_val + delta * 3.2
			if float(wc["exploded"]) >= 1.0:
				world_cracks.remove_at(i)
				i -= 1
				continue
		world_cracks[i] = wc
		i -= 1
	queue_redraw()

# -------------------------------------------------------------
# KỸ NĂNG CƠ BẢN: FALLING ROCKS & EARTHQUAKE
# -------------------------------------------------------------
func _trigger_falling_rocks_skill() -> void:
	var rock_count := 4 if not is_enraged else 6
	for i in range(rock_count):
		var target: Vector2 = global_position
		if player and is_instance_valid(player):
			if i == 0:
				target = player.global_position
			else:
				var angle := randf() * TAU
				var dist := randf_range(30.0, 110.0)
				target = player.global_position + Vector2.RIGHT.rotated(angle) * dist
		else:
			target = global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 120.0)

		rock_zones.append({
			"target_pos": target,
			"timer": 0.0,
			"max_time": 1.1 + float(i) * 0.18,
			"has_impacted": false,
			"radius": 34.0
		})

func _process_falling_rocks(delta: float) -> void:
	var i := rock_zones.size() - 1
	while i >= 0:
		var zone: Dictionary = rock_zones[i]
		zone["timer"] = float(zone["timer"]) + delta
		var cur_t: float = float(zone["timer"])
		var max_t: float = float(zone["max_time"])

		if cur_t >= max_t and not bool(zone["has_impacted"]):
			zone["has_impacted"] = true
			var hit_pos: Vector2 = zone["target_pos"]
			var r: float = float(zone["radius"])

			if player and is_instance_valid(player) and player.has_method("take_damage"):
				if player.global_position.distance_to(hit_pos) <= r:
					player.take_damage(rock_fall_damage, hit_pos, knockback_force)

			_spawn_ground_shatter_at(hit_pos)

		if cur_t >= max_t + 0.45:
			rock_zones.remove_at(i)
		i -= 1

func _trigger_earthquake_skill() -> void:
	var num_shards := 8 if not is_enraged else 12
	for i in range(num_shards):
		var angle := (TAU / float(num_shards)) * float(i) + randf_range(-0.15, 0.15)
		var dist := randf_range(32.0, 95.0)
		var shard_pos := global_position + Vector2.RIGHT.rotated(angle) * dist
		_spawn_ground_shatter_at(shard_pos, float(i) * 0.06)

	_trigger_earthquake_burst(global_position, 60.0)

func _trigger_earthquake_burst(center_pos: Vector2, radius: float) -> void:
	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 2.0, 0.75, 0.9)
	if player and is_instance_valid(player):
		if player.has_method("apply_screen_shake"):
			player.apply_screen_shake(4.2, 0.25)
		if player.has_method("take_damage") and player.global_position.distance_to(center_pos) <= radius:
			player.take_damage(earthquake_damage, center_pos, knockback_force * 1.2)

func _spawn_ground_shatter_at(pos: Vector2, delay: float = 0.0) -> void:
	quake_shards.append({
		"pos": pos,
		"timer": -delay,
		"max_time": 2.2,
		"has_hit": false,
		"radius": 22.0,
		"frame_idx": randi() % (ground_shard_textures.size() if ground_shard_textures.size() > 0 else 1)
	})

func _process_earthquake_shards(delta: float) -> void:
	var i := quake_shards.size() - 1
	while i >= 0:
		var shard: Dictionary = quake_shards[i]
		shard["timer"] = float(shard["timer"]) + delta
		var t: float = float(shard["timer"])

		if t >= 0.0 and not bool(shard["has_hit"]):
			shard["has_hit"] = true
			var s_pos: Vector2 = shard["pos"]
			var r: float = float(shard["radius"])
			if player and is_instance_valid(player) and player.has_method("take_damage"):
				if player.global_position.distance_to(s_pos) <= r:
					player.take_damage(earthquake_damage, s_pos, knockback_force)

		if t >= float(shard["max_time"]):
			quake_shards.remove_at(i)
		i -= 1

func _spawn_mini_dust(pos: Vector2) -> void:
	quake_shards.append({
		"pos": pos + Vector2(randf_range(-8, 8), randf_range(-4, 4)),
		"timer": 0.0,
		"max_time": 0.6,
		"has_hit": true,
		"radius": 14.0,
		"frame_idx": randi() % (ground_shard_textures.size() if ground_shard_textures.size() > 0 else 1)
	})

# -------------------------------------------------------------
# VẼ HIỆU ỨNG (DRAW): CẢNH BÁO, GIÁP CỔ ĐẠI, NẮM ĐẤM, GAI ĐÁ
# -------------------------------------------------------------
func _draw() -> void:
	if is_dead:
		return

	# 1. Vẽ các vết nứt đất vỡ (Earthquake shattered ground)
	for shard in quake_shards:
		var t: float = float(shard["timer"])
		if t < 0.0:
			continue
		var s_pos: Vector2 = to_local(shard["pos"])
		var f_idx: int = int(shard["frame_idx"])
		var alpha: float = clampf(1.0 - (t / float(shard["max_time"])), 0.0, 1.0)

		if f_idx < ground_shard_textures.size() and ground_shard_textures[f_idx] != null:
			var tex: Texture2D = ground_shard_textures[f_idx]
			var sz := tex.get_size()
			draw_texture(tex, s_pos - sz * 0.5, Color(1, 1, 1, alpha))
		else:
			draw_circle(s_pos, float(shard["radius"]) * 0.6, Color(0.42, 0.28, 0.16, alpha * 0.7))

	# 2. Vẽ Earth Spikes (Skill 3)
	for sp in earth_spikes:
		var local_sp: Vector2 = to_local(sp["pos"])
		var r_sp: float = float(sp["radius"])
		if not bool(sp["erupted"]):
			var prog_sp: float = clampf(1.0 - (float(sp["warn_timer"]) / maxf(float(sp["max_warn"]), 0.01)), 0.0, 1.0)
			draw_circle(local_sp, r_sp, Color(0.9, 0.45, 0.15, 0.22))
			draw_circle(local_sp, r_sp * prog_sp, Color(1.0, 0.55, 0.2, 0.35))
			draw_arc(local_sp, r_sp, 0.0, TAU, 24, Color(1.0, 0.4, 0.1, 0.85), 1.6)
		else:
			var act_a: float = clampf(float(sp["active_timer"]) / 0.8, 0.0, 1.0)
			var pts := PackedVector2Array([
				local_sp + Vector2(-12, 6),
				local_sp + Vector2(0, -24),
				local_sp + Vector2(12, 6)
			])
			draw_colored_polygon(pts, Color(0.48, 0.36, 0.24, act_a))
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0.85, 0.68, 0.45, act_a), 1.8)

	# 3. Vẽ Titan Fist (Skill 2) và sóng xung kích hướng
	if current_state == State.TITAN_FIST_WINDUP:
		var local_ft: Vector2 = to_local(fist_target_pos)
		draw_circle(local_ft, fist_radius, Color(1.0, 0.35, 0.1, 0.24))
		draw_arc(local_ft, fist_radius, 0.0, TAU, 32, Color(1.0, 0.25, 0.1, 0.9), 2.2)
		draw_line(local_ft, local_ft + fist_direction * (135.0 if is_final_punch else 95.0), Color(1.0, 0.55, 0.15, 0.65), 4.0)
		# Bóng nắm đấm đá từ trên giáng xuống
		var fist_vis: Vector2 = local_ft + Vector2(0, -state_timer * 90.0)
		draw_circle(fist_vis, fist_radius * 0.55, Color(0.55, 0.4, 0.25, 0.88))

	for fw in fist_waves:
		var wave_world: Vector2 = (fw["pos"] as Vector2) + (fw["dir"] as Vector2) * float(fw["dist"])
		var local_fw: Vector2 = to_local(wave_world)
		var r_fw: float = float(fw["radius"])
		draw_circle(local_fw, r_fw, Color(0.95, 0.55, 0.2, 0.55))
		draw_arc(local_fw, r_fw, 0.0, TAU, 24, Color(1.0, 0.82, 0.35, 0.9), 2.5)

	# 4. Vẽ World Breaker Cracks (Ultimate)
	if current_state == State.WORLD_BREAKER_WINDUP:
		draw_arc(Vector2.ZERO, 68.0, 0.0, TAU, 40, Color(1.0, 0.25, 0.1, 0.9), 3.2)

	for wc in world_cracks:
		var local_wc: Vector2 = to_local(wc["pos"])
		var r_wc: float = float(wc["radius"])
		var exp_wc: float = float(wc["exploded"])
		if exp_wc < 0.0:
			var prog_wc: float = clampf(1.0 - (float(wc["warn_timer"]) / maxf(float(wc["max_warn"]), 0.01)), 0.0, 1.0)
			draw_circle(local_wc, r_wc, Color(1.0, 0.25, 0.08, 0.2 + 0.25 * prog_wc))
			draw_arc(local_wc, r_wc, 0.0, TAU, 24, Color(1.0, 0.45, 0.1, 0.88), 1.8)
		else:
			var a_wc: float = clampf(1.0 - exp_wc, 0.0, 1.0)
			draw_circle(local_wc, r_wc * (0.7 + 0.5 * exp_wc), Color(1.0, 0.55, 0.15, a_wc * 0.7))
			draw_arc(local_wc, r_wc * (1.0 + 0.3 * exp_wc), 0.0, TAU, 28, Color(1.0, 0.88, 0.35, a_wc), 3.0)

	# 5. Vẽ vòng tròn cảnh báo và khối cầu đá từ trên trời lao xuống
	for zone in rock_zones:
		var target_local: Vector2 = to_local(zone["target_pos"])
		var cur_t: float = float(zone["timer"])
		var max_t: float = float(zone["max_time"])
		var r: float = float(zone["radius"])

		if cur_t < max_t:
			var progress := cur_t / max_t
			draw_arc(target_local, r, 0.0, TAU, 28, Color(1.0, 0.45, 0.1, 0.5), 1.5)
			draw_circle(target_local, r * progress, Color(0.85, 0.35, 0.08, 0.22))

			var drop_height := (1.0 - progress) * 160.0
			var orb_pos := target_local + Vector2(0, -drop_height)
			var orb_radius := 14.0 * (0.8 + progress * 0.3)
			draw_circle(orb_pos + Vector2(0, -2), orb_radius * 1.15, Color(1.0, 0.6, 0.2, 0.6))
			draw_circle(orb_pos, orb_radius, Color(0.4, 0.28, 0.18, 0.95))
			draw_circle(orb_pos, orb_radius * 0.5, Color(0.8, 0.55, 0.3, 0.8))
		elif cur_t < max_t + 0.3:
			var explode_t := (cur_t - max_t) / 0.3
			var boom_r := r * (0.8 + explode_t * 0.5)
			draw_circle(target_local, boom_r, Color(1.0, 0.5, 0.15, (1.0 - explode_t) * 0.7))

	# 6. Vẽ vệt cảnh báo hướng lao khi Boss chuẩn bị húc (CHARGE_WINDUP)
	if current_state == State.CHARGE_WINDUP and charge_direction != Vector2.ZERO:
		var dir_local := charge_direction * 180.0
		draw_line(Vector2.ZERO, dir_local, Color(1.0, 0.25, 0.1, 0.75), 3.0)
		draw_circle(dir_local, 8.0, Color(1.0, 0.2, 0.1, 0.8))

	# 7. Vẽ Ancient Armor & Tinh thể điểm yếu phát sáng (Skill 1)
	if is_armored:
		draw_arc(Vector2(0, -22), 38.0, 0.0, TAU, 36, Color(0.85, 0.72, 0.35, 0.78), 3.0)
		for wp in weak_points:
			var wp_off: Vector2 = wp["offset"]
			draw_circle(wp_off, 9.0, Color(0.2, 0.95, 1.0, 0.38))
			draw_circle(wp_off, 5.5, Color(0.65, 1.0, 1.0, 0.95))
			draw_arc(wp_off, 9.5, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.9), 1.5)

	# 8. Vẽ biểu tượng choáng (Stunned) trên đầu Titan
	if current_state == State.STUNNED:
		for s_i in range(3):
			var st_ang: float = state_timer * 6.0 + (TAU / 3.0) * float(s_i)
			var st_pos := Vector2(cos(st_ang) * 18.0, -56.0 + sin(st_ang) * 5.0)
			draw_circle(st_pos, 3.5, Color(1.0, 0.92, 0.2, 0.95))

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead or current_state == State.STUNNED:
		return
	if (body.name == "Player" or body.is_in_group("player")) and body.has_method("take_damage"):
		var dmg: int = charge_damage if current_state == State.CHARGING else contact_damage
		body.take_damage(dmg, global_position, knockback_force)

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, _kb_force: float = 0.0) -> void:
	if is_dead or not health_comp:
		return

	var final_amount: int = amount
	if is_armored:
		# Kiểm tra xem đòn đánh của người chơi có trúng vào Tinh Thể Điểm Yếu (Weak Point) không
		var hit_weak_point: bool = false
		var attack_origin: Vector2 = source_pos if source_pos != Vector2.ZERO else (player.global_position if player else global_position)
		var dir_from_boss: Vector2 = (attack_origin - global_position).normalized()
		for i in range(weak_points.size() - 1, -1, -1):
			var wp: Dictionary = weak_points[i]
			var wp_world: Vector2 = global_position + (wp["offset"] as Vector2)
			var wp_dir: Vector2 = (wp["offset"] as Vector2).normalized()
			if attack_origin.distance_to(wp_world) <= 46.0 or dir_from_boss.dot(wp_dir) >= 0.35:
				hit_weak_point = true
				wp["hp"] = int(wp["hp"]) - amount
				if int(wp["hp"]) <= 0:
					weak_points.remove_at(i)
					if AudioManager:
						AudioManager.play_sfx_random_pitch("explosion", 1.0, 1.15, 1.3)
				else:
					weak_points[i] = wp
				break

		if weak_points.is_empty():
			# Phá vỡ toàn bộ điểm yếu -> Vỡ giáp và làm choáng Titan trong 2 giây!
			_enter_stun_state(2.0)
		elif not hit_weak_point:
			# Giảm 50% sát thương nhận vào khi đang bọc giáp đá cổ đại
			final_amount = maxi(1, int(float(amount) * 0.5))

	health_comp.take_damage(final_amount)

func _on_health_changed(current: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current

	if current <= 0 or is_dead:
		return

	var hp_ratio: float = float(current) / float(maxf(max_hp, 1))

	# Phase 2 transition (<= 60% HP)
	if not is_enraged and hp_ratio <= 0.60:
		is_enraged = true
		current_phase = 2
		if title_label:
			title_label.text = boss_title + " (PHẪN NỘ - CỔ THẠCH)"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.15))
		if boss_hud and boss_hud.has_method("set_accent"):
			boss_hud.set_accent(Color(0.95, 0.35, 0.15))
		if anim:
			anim.speed_scale = 1.25
			anim.modulate = Color(1.2, 0.85, 0.7, 1.0)
		# Kích hoạt ngay Giáp Cổ Đại khi bước vào Phase 2
		if current_state in [State.IDLE, State.CHASE, State.RECOVER]:
			_start_ancient_armor()

	# Phase 3 Ultimate: World Breaker (<= 25% HP, triggers once)
	if not has_triggered_world_breaker and hp_ratio <= 0.25:
		has_triggered_world_breaker = true
		current_phase = 3
		if title_label:
			title_label.text = boss_title + " (KẺ HỦY DIỆT THẾ GIỚI)"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
		_start_world_breaker()

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true

	# Thưởng kinh nghiệm cho người chơi khi hạ Boss Titan
	if SceneManager and SceneManager.has_method("add_player_exp"):
		SceneManager.add_player_exp(240)

	_clear_earth_spikes()
	rock_zones.clear()
	quake_shards.clear()
	fist_waves.clear()
	world_cracks.clear()
	weak_points.clear()

	# Rơi ra hòm phần thưởng ngẫu nhiên 1 trong 10 vũ khí thần khí
	_spawn_reward_chest()

	set_physics_process(false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	if boss_hud:
		boss_hud.visible = false
	queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
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
