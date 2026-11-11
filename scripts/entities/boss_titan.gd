extends CharacterBody2D

# BOSS 3: TITAN CỰ THẠCH (EARTH TITAN / COLOSSUS)
# - Kỹ năng 1: Lao vào húc/đâm dũng mãnh (Charge / Dash Attack)
# - Kỹ năng 2: Quả cầu đá khổng lồ từ trên trời rơi xuống (Falling Meteor / Rock Orbs)
# - Kỹ năng 3: Động đất làm nứt toác mặt đất, đá nát phun trào (Earthquake & Ground Shatter)
# - Trí tuệ AI chiến đấu hoàn chỉnh, trạng thái Enrage khi dưới 50% HP

@export var boss_title: String = "TITAN - CỰ THẠCH HANG SÂU"
@export var aggro_range: float = 340.0
@export var move_speed: float = 48.0
@export var charge_speed: float = 260.0
@export var contact_damage: int = 18
@export var charge_damage: int = 32
@export var rock_fall_damage: int = 35
@export var earthquake_damage: int = 28
@export var knockback_force: float = 260.0
@export var boss_sheet_tex: Texture2D = preload("res://Content T1/Character/Monter/Boss/boss3.png")

enum State {
	IDLE,
	CHASE,
	CHARGE_WINDUP,
	CHARGING,
	CAST_FALLING_ROCKS,
	CAST_EARTHQUAKE,
	RECOVER
}

var current_state: State = State.IDLE
var player: Node2D = null
var is_enraged: bool = false
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
	boss_hud = CanvasLayer.new()
	boss_hud.visible = false
	add_child(boss_hud)

	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	container.custom_minimum_size = Vector2(0, 44)
	boss_hud.add_child(container)

	title_label = Label.new()
	title_label.text = boss_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 9)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	title_label.position = Vector2(80, 4)
	title_label.size = Vector2(320, 14)
	container.add_child(title_label)

	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.position = Vector2(100, 20)
	hp_bar.size = Vector2(280, 8)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.08, 0.05, 0.85)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_right = 3
	bg_style.corner_radius_bottom_left = 3
	hp_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.95, 0.52, 0.18, 1.0)
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_right = 3
	fill_style.corner_radius_bottom_left = 3
	hp_bar.add_theme_stylebox_override("fill", fill_style)

	if health_comp:
		hp_bar.max_value = health_comp.max_health
		hp_bar.value = health_comp.current_health

	container.add_child(hp_bar)

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var dist_to_player := global_position.distance_to(player.global_position) if player else 9999.0
	if dist_to_player <= aggro_range:
		if boss_hud and not boss_hud.visible:
			boss_hud.visible = true

	state_timer -= delta

	# Cập nhật các hiệu ứng rơi và mặt đất nứt
	_process_falling_rocks(delta)
	_process_earthquake_shards(delta)

	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			if anim and anim.animation != "idle":
				anim.play("idle")
			if dist_to_player <= aggro_range and state_timer <= 0.0:
				current_state = State.CHASE
				state_timer = randf_range(1.4, 2.4)

		State.CHASE:
			if not player:
				current_state = State.IDLE
				state_timer = 1.0
			else:
				var move_dir := (player.global_position - global_position).normalized()
				var cur_speed := move_speed * (1.35 if is_enraged else 1.0)
				velocity = move_dir * cur_speed
				if anim:
					anim.flip_h = (move_dir.x < 0)
					if anim.animation != "walk":
						anim.play("walk")

				# Khi đuổi tới gần hoặc hết thời gian rượt đuổi -> tung kỹ năng
				if state_timer <= 0.0 or dist_to_player <= 75.0:
					_choose_next_skill()

		State.CHARGE_WINDUP:
			velocity = Vector2.ZERO
			if anim and anim.animation != "charge":
				anim.play("charge")
			if player:
				charge_direction = (player.global_position - global_position).normalized()
				anim.flip_h = (charge_direction.x < 0)

			# Rung lắc tạo cảm giác lấy đà húc
			if anim:
				anim.position.x = randf_range(-2.5, 2.5)

			if state_timer <= 0.0:
				if anim:
					anim.position.x = 0.0
				current_state = State.CHARGING
				charge_duration_timer = 0.9 if not is_enraged else 1.2
				state_timer = charge_duration_timer

		State.CHARGING:
			velocity = charge_direction * (charge_speed * (1.25 if is_enraged else 1.0))
			if anim and anim.animation != "charge":
				anim.play("charge")

			# Để lại các chấn động nhỏ trên đường lao
			if fmod(state_timer, 0.12) < delta:
				_spawn_mini_dust(global_position)

			# Va vào tường hoặc hết thời gian lao
			if is_on_wall() or state_timer <= 0.0:
				_on_charge_impact()

		State.CAST_FALLING_ROCKS:
			velocity = Vector2.ZERO
			if anim and anim.animation != "charge":
				anim.play("charge")
			if state_timer <= 0.0:
				current_state = State.RECOVER
				state_timer = 0.8 if not is_enraged else 0.5

		State.CAST_EARTHQUAKE:
			velocity = Vector2.ZERO
			if anim and anim.animation != "charge":
				anim.play("charge")
			if state_timer <= 0.0:
				current_state = State.RECOVER
				state_timer = 0.9 if not is_enraged else 0.6

		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)
			if anim and anim.animation != "idle":
				anim.play("idle")
			if state_timer <= 0.0:
				current_state = State.CHASE
				state_timer = randf_range(1.2, 2.0)

	move_and_slide()
	queue_redraw()

func _choose_next_skill() -> void:
	attack_cycle = (attack_cycle + 1) % 3

	match attack_cycle:
		0:
			# Kỹ năng 1: Lao vào húc/đâm dũng mãnh
			current_state = State.CHARGE_WINDUP
			state_timer = 0.65 if not is_enraged else 0.45
			if player:
				charge_direction = (player.global_position - global_position).normalized()
		1:
			# Kỹ năng 2: Gọi các khối cầu đá / thiên thạch từ trên trời rơi xuống
			current_state = State.CAST_FALLING_ROCKS
			state_timer = 0.6
			_trigger_falling_rocks_skill()
		2:
			# Kỹ năng 3: Dộng chân làm nứt vỡ mặt đất, đá nát phun trào diện rộng
			current_state = State.CAST_EARTHQUAKE
			state_timer = 0.7
			_trigger_earthquake_skill()

func _on_charge_impact() -> void:
	# Khi tông vào tường hoặc kết thúc lao, tạo vụ nổ chấn động đất
	_trigger_earthquake_burst(global_position, 48.0)
	current_state = State.RECOVER
	state_timer = 0.9 if not is_enraged else 0.6

# -------------------------------------------------------------
# KỸ NĂNG 2: QUẢ CẦU ĐÁ / THIÊN THẠCH RƠI XUỐNG
# -------------------------------------------------------------
func _trigger_falling_rocks_skill() -> void:
	var rock_count := 4 if not is_enraged else 6
	for i in range(rock_count):
		var target: Vector2 = global_position
		if player and is_instance_valid(player):
			if i == 0:
				# Quả cầu đầu tiên nhắm thẳng vào chân player
				target = player.global_position
			else:
				# Các quả cầu tiếp theo rơi rải rác xung quanh player và boss
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

			# Gây sát thương nổ khi cầu đá chạm đất
			if player and is_instance_valid(player) and player.has_method("take_damage"):
				if player.global_position.distance_to(hit_pos) <= r:
					player.take_damage(rock_fall_damage, hit_pos, knockback_force)

			# Để lại vết nứt đất tại điểm rơi
			_spawn_ground_shatter_at(hit_pos)

		# Sau khi rơi xong 0.5s thì xóa vùng cảnh báo
		if cur_t >= max_t + 0.45:
			rock_zones.remove_at(i)
		i -= 1

# -------------------------------------------------------------
# KỸ NĂNG 3: ĐỘNG ĐẤT & ĐẤT NỨT VỠ DIỆN RỘNG (EARTHQUAKE)
# -------------------------------------------------------------
func _trigger_earthquake_skill() -> void:
	# Tạo vòng tròn đất nứt lan tỏa ra xung quanh Boss
	var num_shards := 8 if not is_enraged else 12
	for i in range(num_shards):
		var angle := (TAU / float(num_shards)) * float(i) + randf_range(-0.15, 0.15)
		var dist := randf_range(32.0, 95.0)
		var shard_pos := global_position + Vector2.RIGHT.rotated(angle) * dist
		_spawn_ground_shatter_at(shard_pos, float(i) * 0.06)

	# Vụ nổ trung tâm dưới chân Boss
	_trigger_earthquake_burst(global_position, 60.0)

func _trigger_earthquake_burst(center_pos: Vector2, radius: float) -> void:
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		if player.global_position.distance_to(center_pos) <= radius:
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
# VẼ HIỆU ỨNG (DRAW): CẢNH BÁO, CẦU RƠI, MẶT ĐẤT NỨT
# -------------------------------------------------------------
func _draw() -> void:
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

	# 2. Vẽ vòng tròn cảnh báo và khối cầu đá từ trên trời lao xuống
	for zone in rock_zones:
		var target_local: Vector2 = to_local(zone["target_pos"])
		var cur_t: float = float(zone["timer"])
		var max_t: float = float(zone["max_time"])
		var r: float = float(zone["radius"])

		if cur_t < max_t:
			var progress := cur_t / max_t
			# Vòng tròn cảnh báo dưới mặt đất
			draw_arc(target_local, r, 0.0, TAU, 28, Color(1.0, 0.45, 0.1, 0.5), 1.5)
			draw_circle(target_local, r * progress, Color(0.85, 0.35, 0.08, 0.22))

			# Quả cầu thiên thạch đá đang bay từ trên cao xuống
			var drop_height := (1.0 - progress) * 160.0
			var orb_pos := target_local + Vector2(0, -drop_height)
			var orb_radius := 14.0 * (0.8 + progress * 0.3)
			# Vẽ bóng đổ và khối cầu
			draw_circle(orb_pos + Vector2(0, -2), orb_radius * 1.15, Color(1.0, 0.6, 0.2, 0.6))
			draw_circle(orb_pos, orb_radius, Color(0.4, 0.28, 0.18, 0.95))
			draw_circle(orb_pos, orb_radius * 0.5, Color(0.8, 0.55, 0.3, 0.8))
		elif cur_t < max_t + 0.3:
			# Vụ nổ khi tiếp đất
			var explode_t := (cur_t - max_t) / 0.3
			var boom_r := r * (0.8 + explode_t * 0.5)
			draw_circle(target_local, boom_r, Color(1.0, 0.5, 0.15, (1.0 - explode_t) * 0.7))

	# 3. Vẽ vệt cảnh báo hướng lao khi Boss chuẩn bị húc (CHARGE_WINDUP)
	if current_state == State.CHARGE_WINDUP and charge_direction != Vector2.ZERO:
		var dir_local := charge_direction * 180.0
		draw_line(Vector2.ZERO, dir_local, Color(1.0, 0.25, 0.1, 0.75), 3.0)
		draw_circle(dir_local, 8.0, Color(1.0, 0.2, 0.1, 0.8))

func _on_hitbox_body_entered(body: Node2D) -> void:
	if (body.name == "Player" or body.is_in_group("player")) and body.has_method("take_damage"):
		var dmg: int = charge_damage if current_state == State.CHARGING else contact_damage
		body.take_damage(dmg, global_position, knockback_force)

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
			title_label.text = boss_title + " (PHẪN NỘ - BẠO KÍCH)"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15))
		if anim:
			anim.speed_scale = 1.35
			anim.modulate = Color(1.2, 0.8, 0.7, 1.0)

func _on_died() -> void:
	# Thưởng kinh nghiệm cho người chơi khi hạ Boss Titan
	if SceneManager and SceneManager.has_method("add_player_exp"):
		SceneManager.add_player_exp(240)

	set_physics_process(false)
	rock_zones.clear()
	quake_shards.clear()
	if boss_hud:
		boss_hud.visible = false
	queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
