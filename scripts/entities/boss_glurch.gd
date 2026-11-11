extends CharacterBody2D

@export var boss_title: String = "GLURCH - THE SLIME TYRANT"
@export var jump_damage: int = 34
@export var contact_damage: int = 20
@export var slam_radius: float = 78.0
@export var aggro_range: float = 300.0
@export var knockback_force: float = 280.0
@export var projectile_scene: PackedScene = preload("res://scenes/entities/fireball_projectile.tscn")
@export var minion_scene: PackedScene = preload("res://scenes/entities/smile1.tscn")

enum State { IDLE, PREPARE_JUMP, AIRBORNE, LAND_RECOVERY, SPIT_BARRAGE }
var current_state: State = State.IDLE

var player: Node2D = null
var is_enraged: bool = false
var state_timer: float = 0.0
var jump_duration: float = 0.72
var jump_elapsed: float = 0.0
var jump_start_pos: Vector2 = Vector2.ZERO
var jump_target_pos: Vector2 = Vector2.ZERO
var consecutive_jumps_left: int = 0
var shockwave_progress: float = -1.0
var spawned_minions_count: int = 0

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
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_label.position = Vector2(90, 4)
	title_label.size = Vector2(300, 14)
	container.add_child(title_label)

	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.position = Vector2(110, 18)
	hp_bar.size = Vector2(260, 8)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.08, 0.12, 0.9)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.9, 0.7, 0.3, 1.0)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.9, 0.2, 0.35, 1.0)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	if health_comp:
		hp_bar.max_value = health_comp.max_health
		hp_bar.value = health_comp.current_health
	container.add_child(hp_bar)

func _physics_process(delta: float) -> void:
	if shockwave_progress >= 0.0:
		shockwave_progress += delta * 2.8
		if shockwave_progress > 1.0:
			shockwave_progress = -1.0
		queue_redraw()

	_find_player()
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
					consecutive_jumps_left = 2 if is_enraged else 1
					_start_prepare_jump()

		State.PREPARE_JUMP:
			velocity = Vector2.ZERO
			state_timer -= delta
			# Hiệu ứng nén người chuẩn bị bật nhảy
			if anim:
				anim.scale = Vector2(2.9, 2.0)
			queue_redraw()
			if state_timer <= 0.0:
				_launch_jump()

		State.AIRBORNE:
			jump_elapsed += delta
			var t: float = clamp(jump_elapsed / jump_duration, 0.0, 1.0)
			global_position = jump_start_pos.lerp(jump_target_pos, t)
			# Parabol độ cao giả lập 2.5D
			var height_offset: float = sin(t * PI) * 85.0
			if anim:
				anim.position = Vector2(0, -10.0 - height_offset)
				anim.scale = Vector2(2.3, 2.7)
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
					_start_spit_barrage()

		State.SPIT_BARRAGE:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.IDLE
				state_timer = 0.65 if is_enraged else 1.15

	if current_state != State.AIRBORNE:
		move_and_slide()

func _start_prepare_jump() -> void:
	current_state = State.PREPARE_JUMP
	state_timer = 0.35 if is_enraged else 0.52
	if player and is_instance_valid(player):
		var to_player: Vector2 = player.global_position - global_position
		var max_leap: float = 135.0 if is_enraged else 105.0
		if to_player.length() > max_leap:
			to_player = to_player.normalized() * max_leap
		jump_target_pos = global_position + to_player
	else:
		jump_target_pos = global_position

func _launch_jump() -> void:
	current_state = State.AIRBORNE
	jump_elapsed = 0.0
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
	state_timer = 0.35 if is_enraged else 0.55
	shockwave_progress = 0.0
	if anim:
		anim.position = Vector2(0, -10)
		anim.scale = Vector2(2.5, 2.5)
		anim.play("idle")
	if body_col:
		body_col.set_deferred("disabled", false)
	if hitbox:
		hitbox.set_deferred("monitoring", true)

	# Gây sát thương AoE nếu Player đứng trong vùng dậm đất
	if AudioManager:
		AudioManager.play_sfx_random_pitch("explosion", 2.0, 0.85, 1.0)
	if player and is_instance_valid(player):
		var d: float = global_position.distance_to(player.global_position)
		if d <= slam_radius and player.has_method("take_damage"):
			player.take_damage(jump_damage, global_position, knockback_force)

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
			proj.setup(dir, 115.0 if is_enraged else 95.0, 12)
		get_parent().add_child(proj)

func _spawn_minion() -> void:
	if not minion_scene or not get_parent() or spawned_minions_count >= 4:
		return
	spawned_minions_count += 1
	var m: Node2D = minion_scene.instantiate()
	var offset := Vector2.RIGHT.rotated(randf() * TAU) * 42.0
	m.global_position = global_position + offset
	get_parent().call_deferred("add_child", m)

func _draw() -> void:
	# Vẽ bóng đen và vòng tròn cảnh báo vị trí rơi khi Glurch đang chuẩn bị nhảy / đang trên không
	if current_state == State.PREPARE_JUMP or current_state == State.AIRBORNE:
		var local_target: Vector2 = jump_target_pos - global_position
		draw_circle(local_target, slam_radius, Color(0.95, 0.15, 0.2, 0.22))
		draw_arc(local_target, slam_radius, 0.0, TAU, 40, Color(1.0, 0.25, 0.25, 0.85), 2.0)
		# Bóng của Glurch dưới mặt đất
		draw_circle(Vector2.ZERO, 24.0, Color(0.0, 0.0, 0.0, 0.38))

	# Sóng chấn động khi tiếp đất
	if shockwave_progress >= 0.0:
		var r: float = slam_radius * shockwave_progress
		var alpha: float = 1.0 - shockwave_progress
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 42, Color(1.0, 0.45, 0.65, alpha), 3.5)

func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player")
	if not player and get_parent():
		player = get_parent().get_node_or_null("Player")

func _on_hitbox_body_entered(body: Node2D) -> void:
	if current_state == State.AIRBORNE:
		return
	if (body.name == "Player" or body.is_in_group("player")) and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position, knockback_force * 0.8)

func take_damage(amount: int, _source_pos: Vector2 = Vector2.ZERO, _kb_force: float = 0.0) -> void:
	if current_state == State.AIRBORNE:
		return
	if health_comp:
		health_comp.take_damage(amount)

func _on_health_changed(current: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current

	# Kích hoạt Phase 2 Enrage khi máu <= 50%
	if not is_enraged and current <= max_hp * 0.5 and current > 0:
		is_enraged = true
		if title_label:
			title_label.text = boss_title + " (CUỒNG NỘ)"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		_spawn_minion()
		_spawn_minion()

	if anim:
		var base_col: Color = Color(1.0, 0.55, 0.45) if is_enraged else Color.WHITE
		anim.modulate = Color(1.0, 0.2, 0.2)
		var tween := create_tween()
		tween.tween_property(anim, "modulate", base_col, 0.15)

func _on_died() -> void:
	if SceneManager and SceneManager.has_method("add_player_exp"):
		SceneManager.add_player_exp(90)
	set_physics_process(false)
	if boss_hud:
		boss_hud.visible = false
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
