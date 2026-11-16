extends Area2D

# Hòm Thần Khí Rơi Từ Boss (Boss Drop Chest)
# Rơi ra khi người chơi tiêu diệt Boss (Titan, Glurch, Malugaz, Sylph).
# Khi người chơi đến gần tương tác (phím F hoặc click chuột):
# - Hòm phát âm thanh mở rương, nảy hoạt ảnh mở nắp.
# - Random chọn 1 trong 10 loại thần khí cực phẩm từ ảnh để thưởng cho người chơi.
# - Nếu balo còn chỗ, nhận trực tiếp vào balo và hiện popup thông báo.
# - Nếu balo đầy, spawn vật phẩm thần khí rơi dưới đất ngay cạnh rương.

const CHEST_TEXTURE_PATH := "res://Content T1/Loose/Cursors 2.png"
const CHEST_FRAMES: Array[Rect2] = [
	Rect2(256, 75, 32, 30),
	Rect2(288, 75, 32, 30),
	Rect2(320, 75, 32, 30),
	Rect2(352, 75, 32, 30)
]

# 10 loại thần khí cực phẩm trong ảnh người dùng gửi:
# Hàng trên (5 món):
# 1. wood_staff: Obsidian Darkblade (Rect2(48, 96, 16, 16))
# 2. iron_staff: Emerald Sunblade (Rect2(64, 96, 16, 16))
# 3. copper_staff: Frost Diamond Saber (Rect2(80, 96, 16, 16))
# 4. gold_staff: Crimson Blood Dagger (Rect2(96, 96, 16, 16))
# 5. amethyst_staff: Void Nether Greatsword (Rect2(112, 96, 16, 16))
# Hàng dưới (5 món):
# 6. wood_sword: Azure Ice Shortsword (Rect2(48, 112, 16, 16))
# 7. iron_sword: Pirate Cutlass (Rect2(64, 112, 16, 16))
# 8. copper_sword: Knight Rapier (Rect2(80, 112, 16, 16))
# 9. gold_sword: Flamberge Waveblade (Rect2(96, 112, 16, 16))
# 10. amethyst_sword: Holy Excalibur (Rect2(112, 112, 16, 16))

const BOSS_WEAPONS: Array[Dictionary] = [
	{
		"id": "wood_staff",
		"name": "Obsidian Darkblade",
		"scene_path": "res://scenes/objects/wood_staff_item.tscn",
		"region": Rect2(48, 96, 16, 16)
	},
	{
		"id": "iron_staff",
		"name": "Emerald Sunblade",
		"scene_path": "res://scenes/objects/iron_staff_item.tscn",
		"region": Rect2(64, 96, 16, 16)
	},
	{
		"id": "copper_staff",
		"name": "Frost Diamond Saber",
		"scene_path": "res://scenes/objects/copper_staff_item.tscn",
		"region": Rect2(80, 96, 16, 16)
	},
	{
		"id": "gold_staff",
		"name": "Crimson Blood Dagger",
		"scene_path": "res://scenes/objects/gold_staff_item.tscn",
		"region": Rect2(96, 96, 16, 16)
	},
	{
		"id": "amethyst_staff",
		"name": "Void Nether Greatsword",
		"scene_path": "res://scenes/objects/amethyst_staff_item.tscn",
		"region": Rect2(112, 96, 16, 16)
	},
	{
		"id": "wood_sword",
		"name": "Azure Ice Shortsword",
		"scene_path": "res://scenes/objects/wood_sword_item.tscn",
		"region": Rect2(48, 112, 16, 16)
	},
	{
		"id": "iron_sword",
		"name": "Pirate Cutlass",
		"scene_path": "res://scenes/objects/iron_sword_item.tscn",
		"region": Rect2(64, 112, 16, 16)
	},
	{
		"id": "copper_sword",
		"name": "Knight Rapier",
		"scene_path": "res://scenes/objects/copper_sword_item.tscn",
		"region": Rect2(80, 112, 16, 16)
	},
	{
		"id": "gold_sword",
		"name": "Flamberge Waveblade",
		"scene_path": "res://scenes/objects/gold_sword_item.tscn",
		"region": Rect2(96, 112, 16, 16)
	},
	{
		"id": "amethyst_sword",
		"name": "Holy Excalibur",
		"scene_path": "res://scenes/objects/amethyst_sword_item.tscn",
		"region": Rect2(112, 112, 16, 16)
	}
]

var is_opened: bool = false
var is_player_nearby: bool = false
var prompt_label: Label = null
var chest_sprite: Sprite2D = null
var aura_particles: CPUParticles2D = null

func _ready() -> void:
	z_index = 2
	y_sort_enabled = true
	add_to_group("boss_reward_chest")
	
	# Tạo Sprite cho hòm
	chest_sprite = Sprite2D.new()
	chest_sprite.name = "ChestSprite"
	chest_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cur_tex := load(CHEST_TEXTURE_PATH) as Texture2D
	if cur_tex:
		chest_sprite.texture = cur_tex
		chest_sprite.region_enabled = true
		chest_sprite.region_rect = CHEST_FRAMES[0]
	chest_sprite.offset = Vector2(0, -10)
	add_child(chest_sprite)
	
	# Tạo vùng va chạm Area2D (bán kính tương tác)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 42.0
	col.shape = shape
	add_child(col)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	_setup_aura_particles()
	_setup_prompt_label()
	_play_spawn_animation()

func _setup_aura_particles() -> void:
	aura_particles = CPUParticles2D.new()
	aura_particles.amount = 16
	aura_particles.lifetime = 1.2
	aura_particles.preprocess = 0.5
	aura_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura_particles.emission_sphere_radius = 16.0
	aura_particles.direction = Vector2(0, -1)
	aura_particles.spread = 45.0
	aura_particles.gravity = Vector2(0, -25)
	aura_particles.initial_velocity_min = 10.0
	aura_particles.initial_velocity_max = 25.0
	aura_particles.scale_amount_min = 2.0
	aura_particles.scale_amount_max = 3.5
	aura_particles.color = Color(1.0, 0.88, 0.35, 0.8)
	add_child(aura_particles)

func _setup_prompt_label() -> void:
	prompt_label = Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = "[F / Click] Open Boss Chest"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-75, -42)
	prompt_label.size = Vector2(150, 20)
	prompt_label.z_index = 25
	prompt_label.add_theme_font_size_override("font_size", 10)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55, 1.0))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.05, 0.0, 0.9))
	prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	prompt_label.visible = false
	add_child(prompt_label)
	
	# Hiệu ứng nhấp nháy cho text
	var tw := create_tween().set_loops()
	tw.tween_property(prompt_label, "modulate:a", 0.45, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(prompt_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

func _play_spawn_animation() -> void:
	# Hoạt ảnh rơi từ trên xuống khi boss chết
	scale = Vector2.ZERO
	position.y -= 24.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y + 24.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		is_player_nearby = true
		_update_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		is_player_nearby = false
		_update_prompt()

func _on_mouse_entered() -> void:
	if is_player_nearby and not is_opened:
		if chest_sprite:
			chest_sprite.modulate = Color(1.25, 1.25, 1.1)

func _on_mouse_exited() -> void:
	if chest_sprite:
		chest_sprite.modulate = Color.WHITE

func _update_prompt() -> void:
	if prompt_label:
		prompt_label.visible = is_player_nearby and not is_opened

func _unhandled_input(event: InputEvent) -> void:
	if is_opened or not is_player_nearby:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_F, KEY_SPACE]:
			open_chest()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var m_pos := get_global_mouse_position()
		if global_position.distance_to(m_pos) <= 52.0:
			open_chest()
			get_viewport().set_input_as_handled()

func open_chest() -> void:
	if is_opened:
		return
	is_opened = true
	
	if prompt_label:
		prompt_label.visible = false
	if aura_particles:
		aura_particles.emitting = false
	
	# Âm thanh mở rương
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("chest")
	
	# Hoạt ảnh mở nắp rương
	var tw := create_tween()
	tw.tween_callback(func(): _set_frame(1))
	tw.tween_interval(0.08)
	tw.tween_callback(func(): _set_frame(2))
	tw.tween_interval(0.08)
	tw.tween_callback(func(): _set_frame(3))
	tw.tween_interval(0.12)
	tw.tween_callback(func(): _grant_reward())

func _set_frame(idx: int) -> void:
	if chest_sprite and idx >= 0 and idx < CHEST_FRAMES.size():
		chest_sprite.region_rect = CHEST_FRAMES[idx]

func _grant_reward() -> void:
	# Random 1 trong 10 vũ khí thần khí
	randomize()
	var weapon_info: Dictionary = BOSS_WEAPONS[randi() % BOSS_WEAPONS.size()]
	var w_id: String = weapon_info["id"]
	var w_name: String = weapon_info["name"]
	var w_sc_path: String = weapon_info["scene_path"]
	var w_region: Rect2 = weapon_info["region"]
	
	# Chuẩn bị AtlasTexture icon
	var weapon_tex := load("res://Content T1/Tilesheet/Weapon1_tilet.png") as Texture2D
	var w_icon := AtlasTexture.new()
	w_icon.atlas = weapon_tex
	w_icon.region = w_region
	
	var scene_res: PackedScene = null
	if ResourceLoader.exists(w_sc_path):
		scene_res = load(w_sc_path) as PackedScene
	
	var inv = get_tree().get_first_node_in_group("inventory")
	var added_success: bool = false
	if inv and inv.has_method("add_item"):
		added_success = inv.add_item(w_icon, scene_res, w_id, w_name)
	
	if added_success:
		_show_reward_floating_text("✨ Nhận được: %s! ✨" % w_name, Color(1.0, 0.9, 0.2))
	else:
		# Balo đầy -> rơi ra đất để người chơi nhặt
		if scene_res:
			var drop_inst = scene_res.instantiate() as Node2D
			if drop_inst:
				drop_inst.global_position = global_position + Vector2(randf_range(-14.0, 14.0), randf_range(8.0, 18.0))
				get_parent().add_child(drop_inst)
		_show_reward_floating_text("Túi đầy! %s rơi dưới đất!" % w_name, Color(1.0, 0.5, 0.3))
	
	# Lưu tự động game sau khi nhận đồ hiếm
	if SceneManager and SceneManager.has_method("save_game"):
		SceneManager.save_game()
	
	# Rương mờ dần và biến mất sau 1.2s
	var end_tw := create_tween()
	end_tw.tween_interval(0.9)
	end_tw.tween_property(self, "modulate:a", 0.0, 0.45)
	end_tw.tween_callback(queue_free)

func _show_reward_floating_text(text: String, col: Color) -> void:
	var float_lbl := Label.new()
	float_lbl.text = text
	float_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	float_lbl.position = Vector2(-120, -60)
	float_lbl.size = Vector2(240, 24)
	float_lbl.z_index = 40
	float_lbl.add_theme_font_size_override("font_size", 12)
	float_lbl.add_theme_color_override("font_color", col)
	float_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	float_lbl.add_theme_constant_override("shadow_offset_x", 1)
	float_lbl.add_theme_constant_override("shadow_offset_y", 1)
	add_child(float_lbl)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(float_lbl, "position:y", float_lbl.position.y - 25.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(float_lbl, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(float_lbl.queue_free)
