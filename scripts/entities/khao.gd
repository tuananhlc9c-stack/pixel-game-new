extends CharacterBody2D

@export var speed: float = 30.0
@export var max_distance: float = 60.0 # Bán kính giới hạn di chuyển quanh điểm xuất phát
@export var is_merchant: bool = false
@export var is_stationary: bool = false
@export_enum("all", "egg_milk", "fish", "furniture") var shop_type: String = "all"
@export var patrol_offsets: PackedVector2Array = PackedVector2Array()
@export var wait_at_point_time: float = 1.2

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area: Area2D = $Area2D if has_node("Area2D") else null

var start_position: Vector2
var move_direction: Vector2 = Vector2.ZERO
var timer: float = 0.0
var change_time: float = 2.5 # Thời gian đi theo một hướng trước khi đổi ý
var current_patrol_index: int = 0
var patrol_wait_timer: float = 0.0

var player_nearby: bool = false
var overhead_label: Label = null
var shop_layer: CanvasLayer = null
var shop_panel: Panel = null
var items_list_vbox: VBoxContainer = null
var status_label: Label = null
var gold_header_label: Label = null

const EGG_MILK_CATALOG: Array[Dictionary] = [
	{
		"id": "egg",
		"name": "Egg",
		"display_name": "Egg",
		"price": 15,
		"scene_path": "res://scenes/objects/egg_item.tscn",
		"region": Rect2(80, 0, 16, 16)
	},
	{
		"id": "cow_milk",
		"name": "Cow Milk",
		"display_name": "Cow Milk",
		"price": 30,
		"scene_path": "res://scenes/objects/cow_milk_item.tscn",
		"region": Rect2(32, 0, 16, 16)
	},
	{
		"id": "goat_milk",
		"name": "Goat Milk",
		"display_name": "Goat Milk",
		"price": 40,
		"scene_path": "res://scenes/objects/goat_milk_item.tscn",
		"region": Rect2(16, 0, 16, 16)
	},
	{
		"id": "pork",
		"name": "Pork",
		"display_name": "Pork",
		"price": 50,
		"scene_path": "res://scenes/objects/pork_item.tscn",
		"region": Rect2(48, 0, 16, 16)
	}
]

const FISH_CATALOG: Array[Dictionary] = [
	{
		"id": "fish_carp",
		"name": "Carp",
		"display_name": "Carp",
		"price": 20,
		"scene_path": "res://scenes/objects/fish_item.tscn",
		"region": Rect2(0, 48, 16, 16)
	},
	{
		"id": "fish_perch",
		"name": "Perch",
		"display_name": "Perch",
		"price": 25,
		"scene_path": "res://scenes/objects/fish_item.tscn",
		"region": Rect2(16, 48, 16, 16)
	},
	{
		"id": "fish_shrimp",
		"name": "Silver Shrimp",
		"display_name": "Silver Shrimp",
		"price": 30,
		"scene_path": "res://scenes/objects/fish_item.tscn",
		"region": Rect2(160, 48, 16, 16)
	},
	{
		"id": "fish_crab",
		"name": "Red Crab",
		"display_name": "Red Crab",
		"price": 35,
		"scene_path": "res://scenes/objects/fish_item.tscn",
		"region": Rect2(144, 48, 16, 16)
	},
	{
		"id": "fish_salmon",
		"name": "Red Salmon",
		"display_name": "Red Salmon",
		"price": 45,
		"scene_path": "res://scenes/objects/fish_item.tscn",
		"region": Rect2(32, 48, 16, 16)
	},
	{
		"id": "fish_gold",
		"name": "Goldfish",
		"display_name": "Goldfish",
		"price": 60,
		"scene_path": "res://scenes/objects/fish_item.tscn",
		"region": Rect2(48, 48, 16, 16)
	},
	{
		"id": "fish_tuna",
		"name": "Tuna",
		"display_name": "Tuna",
		"price": 75,
		"scene_path": "res://scenes/objects/fish_item.tscn",
		"region": Rect2(80, 48, 16, 16)
	},
	{
		"id": "fish_octopus",
		"name": "Octopus",
		"display_name": "Octopus",
		"price": 90,
		"scene_path": "res://scenes/objects/fish_item.tscn",
		"region": Rect2(176, 48, 16, 16)
	}
]

const FURNITURE_CATALOG: Array[Dictionary] = [
	{
		"id": "furn_oak_chair",
		"name": "Oak Chair",
		"display_name": "Oak Chair",
		"price": 80,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(0, 0, 16, 32)
	},
	{
		"id": "furn_birch_chair",
		"name": "Birch Chair",
		"display_name": "Birch Chair",
		"price": 85,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(64, 0, 16, 32)
	},
	{
		"id": "furn_emerald_chair",
		"name": "Emerald Chair",
		"display_name": "Emerald Chair",
		"price": 95,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(128, 0, 16, 32)
	},
	{
		"id": "furn_modern_chair",
		"name": "Modern Chair",
		"display_name": "Modern Chair",
		"price": 110,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(192, 0, 16, 32)
	},
	{
		"id": "furn_floor_lamp",
		"name": "Floor Lamp",
		"display_name": "Floor Lamp",
		"price": 130,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(176, 160, 16, 48)
	},
	{
		"id": "furn_oak_bench",
		"name": "Oak Bench",
		"display_name": "Oak Bench",
		"price": 150,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(0, 48, 32, 32)
	},
	{
		"id": "furn_tea_table",
		"name": "Tea Table",
		"display_name": "Tea Table",
		"price": 160,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(144, 112, 32, 32)
	},
	{
		"id": "furn_oak_table",
		"name": "Oak Dining Table",
		"display_name": "Oak Dining Table",
		"price": 180,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(0, 96, 32, 48)
	},
	{
		"id": "furn_oak_dresser",
		"name": "Oak Dresser",
		"display_name": "Oak Dresser",
		"price": 200,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(0, 160, 32, 32)
	},
	{
		"id": "furn_carrot_rug",
		"name": "Carrot Rug",
		"display_name": "Carrot Rug",
		"price": 220,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(208, 176, 48, 32)
	},
	{
		"id": "furn_bookshelf",
		"name": "Bookshelf",
		"display_name": "Bookshelf",
		"price": 250,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(128, 160, 32, 48)
	},
	{
		"id": "furn_retro_tv",
		"name": "Retro TV",
		"display_name": "Retro TV",
		"price": 280,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(240, 240, 32, 48)
	},
	{
		"id": "furn_royal_bed",
		"name": "Royal Single Bed",
		"display_name": "Royal Single Bed",
		"price": 320,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(128, 224, 32, 64)
	},
	{
		"id": "furn_blue_bed",
		"name": "Blue Double Bed",
		"display_name": "Blue Double Bed",
		"price": 360,
		"scene_path": "res://scenes/objects/furniture_item.tscn",
		"atlas_path": "res://Content T1/Tilesheet/Furniture_tilet.png",
		"region": Rect2(0, 224, 48, 64)
	}
]

func _ready() -> void:
	add_to_group("npc")
	if is_merchant:
		add_to_group("merchant")
	start_position = global_position

	if _should_stand_still():
		move_direction = Vector2.ZERO
		velocity = Vector2.ZERO
		if anim and anim.sprite_frames:
			if anim.sprite_frames.has_animation("walk_down"):
				anim.animation = &"walk_down"
			anim.stop()
			anim.frame = 0
	else:
		_pick_random_direction()

	if is_merchant:
		_setup_merchant_overhead_ui()
		_setup_merchant_shop_ui()
		if interact_area:
			interact_area.input_pickable = true
			if not interact_area.body_entered.is_connected(_on_area_body_entered):
				interact_area.body_entered.connect(_on_area_body_entered)
			if not interact_area.body_exited.is_connected(_on_area_body_exited):
				interact_area.body_exited.connect(_on_area_body_exited)
			if not interact_area.input_event.is_connected(_on_area_input_event):
				interact_area.input_event.connect(_on_area_input_event)

		# Kết nối tín hiệu cập nhật Balo & Vàng để làm mới cửa hàng
		call_deferred("_connect_inventory_signals")

func _should_stand_still() -> bool:
	return is_stationary or speed <= 0.0 or max_distance <= 0.0

func _connect_inventory_signals() -> void:
	var inv := get_tree().get_first_node_in_group("inventory")
	if inv and inv.has_signal("inventory_updated"):
		if not inv.inventory_updated.is_connected(_refresh_shop_items):
			inv.inventory_updated.connect(_refresh_shop_items)
	if SceneManager and not SceneManager.gold_changed.is_connected(_on_gold_changed):
		SceneManager.gold_changed.connect(_on_gold_changed)

func _physics_process(delta: float) -> void:
	# NPC đứng yên hoặc đang mở cửa hàng / người chơi đứng gần nói chuyện
	if _should_stand_still() or (is_merchant and ((shop_panel and shop_panel.visible) or player_nearby)):
		velocity = Vector2.ZERO
		move_direction = Vector2.ZERO
		_update_animation()
		return

	if patrol_offsets.size() >= 2:
		if patrol_wait_timer > 0.0:
			patrol_wait_timer -= delta
			velocity = Vector2.ZERO
			move_direction = Vector2.ZERO
			_update_animation()
			return

		var target_pos: Vector2 = start_position + patrol_offsets[current_patrol_index]
		var to_target: Vector2 = target_pos - global_position
		if to_target.length() <= 6.0:
			current_patrol_index = (current_patrol_index + 1) % patrol_offsets.size()
			patrol_wait_timer = wait_at_point_time
			velocity = Vector2.ZERO
			move_direction = Vector2.ZERO
			_update_animation()
			return

		move_direction = to_target.normalized()
		velocity = move_direction * speed
		move_and_slide()
		if is_on_wall():
			current_patrol_index = (current_patrol_index + 1) % patrol_offsets.size()
			patrol_wait_timer = 0.4
		_update_animation()
		return

	timer += delta
	if timer >= change_time:
		timer = 0.0
		_pick_random_direction()

	# Nếu NPC đi quá xa điểm xuất phát, hướng về lại điểm xuất phát
	if global_position.distance_to(start_position) > max_distance:
		move_direction = (start_position - global_position).normalized()

	velocity = move_direction * speed
	move_and_slide()

	if is_on_wall():
		timer = 0.0
		_pick_random_direction()

	_update_animation()

func _unhandled_input(event: InputEvent) -> void:
	if not is_merchant:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F or event.physical_keycode == KEY_F:
			if player_nearby or _is_player_close(75.0):
				toggle_shop_window()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and shop_panel and shop_panel.visible:
			toggle_shop_window(false)
			get_viewport().set_input_as_handled()

	# Hỗ trợ click chuột trực tiếp vào NPC Thương Nhân để mở bảng bán hàng
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if shop_panel and shop_panel.visible:
			return
		var world_mouse := get_global_mouse_position()
		if global_position.distance_to(world_mouse) <= 24.0:
			toggle_shop_window(true)
			get_viewport().set_input_as_handled()

func _is_player_close(max_dist: float = 75.0) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		return global_position.distance_to(player.global_position) <= max_dist
	return false

func _get_overhead_default_text() -> String:
	match shop_type:
		"egg_milk":
			return "Farm Shop (Egg, Milk & Pork)"
		"fish":
			return "Fish Shop"
		"furniture":
			return "Furniture Shop"
		_:
			return "Merchant Shop"

func _get_overhead_nearby_text() -> String:
	match shop_type:
		"egg_milk":
			return "[F / Click] Farm Shop"
		"fish":
			return "[F / Click] Fish Shop"
		"furniture":
			return "[F / Click] Furniture Shop"
		_:
			return "[F / Click] Open Shop"

func _get_shop_title_text() -> String:
	match shop_type:
		"egg_milk":
			return "FARM SHOP (EGG, MILK & PORK)"
		"fish":
			return "FISH & SEAFOOD SHOP"
		"furniture":
			return "HOME FURNITURE SHOP (FOR HOUSE MAP)"
		_:
			return "MERCHANT SHOP"

func _get_price_guide_text() -> String:
	match shop_type:
		"egg_milk":
			return "Prices: Egg 15G | Cow Milk 30G | Goat Milk 40G | Pork 50G (Buy & Sell)"
		"fish":
			return "Prices: Carp 20G | Perch 25G | Shrimp 30G | Crab 35G | Salmon 45G | Goldfish 60G | Tuna 75G | Octopus 90G"
		"furniture":
			return "Prices: Chairs 80-110G | Lamp 130G | Tables/Bench 150-180G | Dresser/Rug/Shelf 200-250G | TV & Beds 280-360G"
		_:
			return "Prices: Egg 15G | Cow Milk 30G | Goat Milk 40G | Pork 50G | Fish 20G~90G | Furniture 80G~360G"

func _is_item_matching_shop(item_data: Variant) -> bool:
	if typeof(item_data) != TYPE_DICTIONARY or item_data == null:
		return false
	var id_str: String = str(item_data.get("id", "")).to_lower()
	var name_str: String = str(item_data.get("name", "")).to_lower()
	if id_str == "fishing_rod":
		return false

	var is_fish_item: bool = (
		id_str.begins_with("fish")
		or "fish" in name_str
		or "cá" in name_str
		or "carp" in name_str
		or "perch" in name_str
		or "shrimp" in name_str
		or "crab" in name_str
		or "salmon" in name_str
		or "tuna" in name_str
		or "octopus" in name_str
	)
	var is_egg_milk_item: bool = (
		id_str in ["egg", "cow_milk", "goat_milk", "pork"]
		or "egg" in name_str
		or "trứng" in name_str
		or "milk" in name_str
		or "sữa" in name_str
		or "pork" in name_str
		or "meat" in name_str
	)
	var icon_tex = item_data.get("icon")
	var is_furniture_item: bool = (
		id_str.begins_with("furn_")
		or (icon_tex is AtlasTexture and icon_tex.atlas and "Furniture_tilet" in icon_tex.atlas.resource_path)
		or "chair" in name_str
		or "table" in name_str
		or "bench" in name_str
		or "lamp" in name_str
		or "dresser" in name_str
		or "rug" in name_str
		or "bookshelf" in name_str
		or "tv" in name_str
		or "bed" in name_str
	)

	match shop_type:
		"egg_milk":
			return is_egg_milk_item
		"fish":
			return is_fish_item
		"furniture":
			return is_furniture_item
		_:
			return is_egg_milk_item or is_fish_item or is_furniture_item

func _on_area_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_nearby = true
		if overhead_label:
			overhead_label.text = _get_overhead_nearby_text()
			overhead_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35, 1.0))

func _on_area_body_exited(body: Node) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_nearby = false
		if overhead_label:
			overhead_label.text = _get_overhead_default_text()
			overhead_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1.0))

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_shop_window(true)

# Cho phép kéo thả trực tiếp vật phẩm từ thanh công cụ/balo vào người NPC để bán ngay
func sell_from_drag_slot(slot_idx: int) -> bool:
	var inv := get_tree().get_first_node_in_group("inventory")
	if not inv or not inv.has_method("sell_item_at_slot"):
		return false
	if slot_idx < 0 or slot_idx >= inv.inventory_data.size():
		return false
	var item_data = inv.inventory_data[slot_idx]
	if item_data == null:
		return false
	if not _is_item_matching_shop(item_data):
		var reject_msg := "Only Egg, Milk & Pork!" if shop_type == "egg_milk" else ("Only Fish!" if shop_type == "fish" else ("Only Furniture!" if shop_type == "furniture" else "Cannot sell this item!"))
		_show_floating_gold_text(reject_msg, Color(1.0, 0.45, 0.4, 1.0))
		_set_shop_status(reject_msg, Color(1.0, 0.45, 0.4, 1.0))
		return true

	var res: Dictionary = inv.sell_item_at_slot(slot_idx)
	if res.get("success", false):
		var gold_earned: int = int(res.get("gold", 0))
		var item_name: String = str(res.get("name", "Item"))
		_show_floating_gold_text("+%d Gold (%s)" % [gold_earned, item_name])
		_set_shop_status("Sold %s for +%d Gold!" % [item_name, gold_earned], Color(0.45, 1.0, 0.55, 1.0))
		_refresh_shop_items()
		return true
	else:
		_show_floating_gold_text("Cannot sell!", Color(1.0, 0.45, 0.4, 1.0))
		return false

func _setup_merchant_overhead_ui() -> void:
	overhead_label = Label.new()
	overhead_label.name = "MerchantLabel"
	overhead_label.text = _get_overhead_default_text()
	overhead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overhead_label.position = Vector2(-95, -34)
	overhead_label.size = Vector2(190, 20)
	overhead_label.z_index = 20
	overhead_label.add_theme_font_size_override("font_size", 9)
	overhead_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1.0))
	overhead_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02, 1.0))
	overhead_label.add_theme_constant_override("outline_size", 3)
	add_child(overhead_label)

func _setup_merchant_shop_ui() -> void:
	shop_layer = CanvasLayer.new()
	shop_layer.name = "MerchantShopLayer"
	shop_layer.layer = 15
	add_child(shop_layer)

	shop_panel = Panel.new()
	shop_panel.name = "MerchantShopPanel"
	shop_panel.add_to_group("merchant_shop_ui")
	shop_panel.anchor_left = 0.5
	shop_panel.anchor_top = 0.5
	shop_panel.anchor_right = 0.5
	shop_panel.anchor_bottom = 0.5
	shop_panel.offset_left = -250.0
	shop_panel.offset_top = -175.0
	shop_panel.offset_right = 250.0
	shop_panel.offset_bottom = 140.0
	shop_panel.visible = false

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.12, 0.07, 0.96)
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.border_color = Color(0.88, 0.65, 0.25, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.55)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0, 4)
	shop_panel.add_theme_stylebox_override("panel", panel_style)
	shop_layer.add_child(shop_panel)

	# Tiêu đề cửa hàng
	var title_lbl := Label.new()
	title_lbl.text = _get_shop_title_text()
	title_lbl.position = Vector2(16, 10)
	title_lbl.size = Vector2(310, 24)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 1.0))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.01, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 3)
	shop_panel.add_child(title_lbl)

	# Hiển thị số vàng hiện có ngay trên góc cửa hàng
	gold_header_label = Label.new()
	gold_header_label.position = Vector2(315, 10)
	gold_header_label.size = Vector2(140, 24)
	gold_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_header_label.add_theme_font_size_override("font_size", 13)
	gold_header_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22, 1.0))
	gold_header_label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.01, 1.0))
	gold_header_label.add_theme_constant_override("outline_size", 3)
	shop_panel.add_child(gold_header_label)

	# Nút đóng (X)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(462, 8)
	close_btn.size = Vector2(28, 26)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func(): toggle_shop_window(false))
	shop_panel.add_child(close_btn)

	# Bảng giá niêm yết tóm tắt
	var price_guide := Label.new()
	price_guide.text = _get_price_guide_text()
	price_guide.position = Vector2(16, 34)
	price_guide.size = Vector2(468, 18)
	price_guide.add_theme_font_size_override("font_size", 9)
	price_guide.add_theme_color_override("font_color", Color(0.92, 0.82, 0.65, 1.0))
	shop_panel.add_child(price_guide)

	# Khung danh sách vật phẩm mua & bán
	var well_panel := Panel.new()
	well_panel.position = Vector2(14, 56)
	well_panel.size = Vector2(472, 198)
	var well_style := StyleBoxFlat.new()
	well_style.bg_color = Color(0.13, 0.08, 0.04, 0.92)
	well_style.border_width_left = 2
	well_style.border_width_top = 2
	well_style.border_width_right = 2
	well_style.border_width_bottom = 2
	well_style.border_color = Color(0.48, 0.3, 0.16, 1.0)
	well_style.corner_radius_top_left = 5
	well_style.corner_radius_top_right = 5
	well_style.corner_radius_bottom_right = 5
	well_style.corner_radius_bottom_left = 5
	well_panel.add_theme_stylebox_override("panel", well_style)
	shop_panel.add_child(well_panel)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 6)
	scroll.size = Vector2(456, 186)
	well_panel.add_child(scroll)

	items_list_vbox = VBoxContainer.new()
	items_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(items_list_vbox)

	# Dòng trạng thái thông báo kết quả mua / bán
	status_label = Label.new()
	status_label.text = "Select an item above to Buy or Sell."
	status_label.position = Vector2(16, 258)
	status_label.size = Vector2(468, 18)
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.72, 1.0))
	shop_panel.add_child(status_label)

	# Nút Bán Ô Đang Chọn
	var sell_selected_btn := Button.new()
	sell_selected_btn.text = "Sell Selected Slot"
	sell_selected_btn.position = Vector2(14, 280)
	sell_selected_btn.size = Vector2(225, 26)
	sell_selected_btn.add_theme_font_size_override("font_size", 12)
	sell_selected_btn.pressed.connect(_on_sell_selected_pressed)
	shop_panel.add_child(sell_selected_btn)

	# Nút Bán Tất Cả theo loại cửa hàng
	var sell_all_btn := Button.new()
	if shop_type == "egg_milk":
		sell_all_btn.text = "Sell All Farm Products"
	elif shop_type == "fish":
		sell_all_btn.text = "Sell All Fish in Bag"
	elif shop_type == "furniture":
		sell_all_btn.text = "Sell All Furniture in Bag"
	else:
		sell_all_btn.text = "Sell All Items in Bag"
	sell_all_btn.position = Vector2(255, 280)
	sell_all_btn.size = Vector2(231, 26)
	sell_all_btn.add_theme_font_size_override("font_size", 12)
	sell_all_btn.pressed.connect(_on_sell_all_pressed)
	shop_panel.add_child(sell_all_btn)

	_update_gold_header()

func toggle_shop_window(force_state: Variant = null) -> void:
	if not shop_panel:
		return
	var target_vis: bool = (not shop_panel.visible) if force_state == null else bool(force_state)
	if target_vis:
		for other_panel in get_tree().get_nodes_in_group("merchant_shop_ui"):
			if other_panel != shop_panel and other_panel is Control:
				other_panel.visible = false
	shop_panel.visible = target_vis
	if target_vis:
		_update_gold_header()
		_refresh_shop_items()

func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_header()

func _update_gold_header() -> void:
	if gold_header_label:
		var g: int = SceneManager.get_gold() if SceneManager else 0
		gold_header_label.text = "Gold: %d G" % g

func _get_buy_catalog() -> Array[Dictionary]:
	match shop_type:
		"egg_milk":
			return EGG_MILK_CATALOG
		"fish":
			return FISH_CATALOG
		"furniture":
			return FURNITURE_CATALOG
		_:
			var combined: Array[Dictionary] = []
			combined.append_array(EGG_MILK_CATALOG)
			combined.append_array(FISH_CATALOG)
			combined.append_array(FURNITURE_CATALOG)
			return combined

func _create_section_header(title_text: String, color: Color) -> Label:
	var header := Label.new()
	header.text = title_text
	header.custom_minimum_size = Vector2(440, 20)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", color)
	header.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.01, 1.0))
	header.add_theme_constant_override("outline_size", 2)
	return header

func _refresh_shop_items() -> void:
	if not items_list_vbox:
		return
	for child in items_list_vbox.get_children():
		child.queue_free()

	_update_gold_header()

	# 1. Khu vực MUA HÀNG từ NPC
	var buy_catalog := _get_buy_catalog()
	if buy_catalog.size() > 0:
		var buy_title := "▼ BUY FARM PRODUCTS (Add to Bag):" if shop_type == "egg_milk" else ("▼ BUY FRESH FISH (Add to Bag):" if shop_type == "fish" else ("▼ BUY HOME FURNITURE (Place in House Map):" if shop_type == "furniture" else "▼ BUY ITEMS:"))
		items_list_vbox.add_child(_create_section_header(buy_title, Color(0.65, 0.95, 1.0, 1.0)))
		for entry in buy_catalog:
			items_list_vbox.add_child(_create_buy_item_row(entry))

	# 2. Khu vực BÁN ĐỒ TRONG TÚI lấy Vàng
	var sell_title := "▼ SELL FARM PRODUCTS FROM BAG (Earn Gold):" if shop_type == "egg_milk" else ("▼ SELL FISH FROM BAG (Earn Gold):" if shop_type == "fish" else ("▼ SELL FURNITURE FROM BAG (Earn Gold):" if shop_type == "furniture" else "▼ SELL ITEMS FROM BAG (Earn Gold):"))
	items_list_vbox.add_child(_create_section_header(sell_title, Color(1.0, 0.88, 0.38, 1.0)))

	var inv := get_tree().get_first_node_in_group("inventory")
	if not inv or not ("inventory_data" in inv):
		return

	var sellable_count: int = 0
	var data_arr: Array = inv.inventory_data
	for slot_idx in range(data_arr.size()):
		var item_data = data_arr[slot_idx]
		if item_data == null:
			continue
		if not _is_item_matching_shop(item_data):
			continue
		var price: int = inv.get_item_price(item_data) if inv.has_method("get_item_price") else 15
		if price <= 0:
			continue

		sellable_count += 1
		var row := _create_shop_item_row(slot_idx, item_data, price)
		items_list_vbox.add_child(row)

	if sellable_count == 0:
		var empty_lbl := Label.new()
		if shop_type == "egg_milk":
			empty_lbl.text = "No Eggs, Milk, or Pork in your bag to sell."
		elif shop_type == "fish":
			empty_lbl.text = "No Fish in your bag to sell."
		elif shop_type == "furniture":
			empty_lbl.text = "No Furniture in your bag to sell."
		else:
			empty_lbl.text = "No sellable items in your bag."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.custom_minimum_size = Vector2(440, 32)
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.78, 0.7, 0.58, 0.9))
		items_list_vbox.add_child(empty_lbl)

func _create_buy_item_row(entry: Dictionary) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(440, 36)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.16, 0.2, 0.14, 0.95)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.border_color = Color(0.42, 0.65, 0.38, 0.9)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.content_margin_left = 8
	row_style.content_margin_right = 8
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row_panel.add_child(hbox)

	var atlas_path: String = str(entry.get("atlas_path", "res://Content T1/Loose/Fish-food.png"))
	var item_tex := load(atlas_path) as Texture2D
	var atlas_icon := AtlasTexture.new()
	atlas_icon.atlas = item_tex
	atlas_icon.region = entry.get("region", Rect2(0, 0, 16, 16))

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.texture = atlas_icon
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.text = str(entry.get("display_name", "Item"))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 1.0, 0.92, 1.0))
	hbox.add_child(name_lbl)

	var price: int = int(entry.get("price", 15))
	var price_lbl := Label.new()
	price_lbl.text = "%d Gold" % price
	price_lbl.add_theme_font_size_override("font_size", 12)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25, 1.0))
	hbox.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Buy (%dG)" % price
	buy_btn.custom_minimum_size = Vector2(96, 26)
	buy_btn.add_theme_font_size_override("font_size", 11)
	buy_btn.pressed.connect(_on_buy_item_pressed.bind(entry))
	hbox.add_child(buy_btn)

	return row_panel

func _on_buy_item_pressed(entry: Dictionary) -> void:
	var inv := get_tree().get_first_node_in_group("inventory")
	if not inv or not inv.has_method("add_item"):
		return

	var price: int = int(entry.get("price", 15))
	var disp_name: String = str(entry.get("display_name", "Item"))
	var cur_gold: int = SceneManager.get_gold() if SceneManager else 0

	if cur_gold < price:
		_set_shop_status("Not enough Gold! Need %d Gold to buy %s." % [price, disp_name], Color(1.0, 0.45, 0.4, 1.0))
		_show_floating_gold_text("Not enough Gold!", Color(1.0, 0.45, 0.4, 1.0))
		return

	var atlas_path: String = str(entry.get("atlas_path", "res://Content T1/Loose/Fish-food.png"))
	var item_tex := load(atlas_path) as Texture2D
	var item_scene := load(str(entry.get("scene_path", ""))) as PackedScene
	var icon := AtlasTexture.new()
	icon.atlas = item_tex
	icon.region = entry.get("region", Rect2(0, 0, 16, 16))

	var added: bool = inv.add_item(icon, item_scene, str(entry.get("id", "")), str(entry.get("name", "")))
	if added:
		if SceneManager:
			SceneManager.add_gold(-price)
		_set_shop_status("Bought %s (-%d Gold)!" % [disp_name, price], Color(0.45, 1.0, 0.55, 1.0))
		_show_floating_gold_text("-%dG (%s)" % [price, disp_name], Color(0.55, 1.0, 0.65, 1.0))
		_refresh_shop_items()
	else:
		_set_shop_status("Inventory Full! Cannot buy more items.", Color(1.0, 0.45, 0.4, 1.0))

func _create_shop_item_row(slot_idx: int, item_data: Dictionary, price: int) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(440, 38)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.22, 0.14, 0.08, 0.95)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.border_color = Color(0.62, 0.42, 0.22, 0.9)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.content_margin_left = 8
	row_style.content_margin_right = 8
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row_panel.add_child(hbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.texture = item_data.get("icon")
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)

	var item_name: String = _get_english_item_name(item_data)
	var name_lbl := Label.new()
	name_lbl.text = "%s (Slot %d)" % [item_name, slot_idx + 1]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 1.0))
	hbox.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "+%d Gold" % price
	price_lbl.add_theme_font_size_override("font_size", 12)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25, 1.0))
	hbox.add_child(price_lbl)

	var sell_btn := Button.new()
	sell_btn.text = "Sell (+%dG)" % price
	sell_btn.custom_minimum_size = Vector2(96, 26)
	sell_btn.add_theme_font_size_override("font_size", 11)
	sell_btn.pressed.connect(_on_sell_slot_pressed.bind(slot_idx))
	hbox.add_child(sell_btn)

	return row_panel

func _get_english_item_name(item_data: Dictionary) -> String:
	var id_str: String = str(item_data.get("id", ""))
	var raw_name: String = str(item_data.get("name", "Item"))
	match id_str:
		"egg": return "Egg"
		"cow_milk": return "Cow Milk"
		"goat_milk": return "Goat Milk"
		"pork": return "Pork"
		"fish": return "Fresh Fish"
		"fish_carp": return "Carp"
		"fish_perch": return "Perch"
		"fish_shrimp": return "Silver Shrimp"
		"fish_crab": return "Red Crab"
		"fish_salmon": return "Red Salmon"
		"fish_gold": return "Goldfish"
		"fish_tuna": return "Tuna"
		"fish_octopus": return "Octopus"
		"furn_oak_chair": return "Oak Chair"
		"furn_birch_chair": return "Birch Chair"
		"furn_emerald_chair": return "Emerald Chair"
		"furn_modern_chair": return "Modern Chair"
		"furn_floor_lamp": return "Floor Lamp"
		"furn_oak_bench": return "Oak Bench"
		"furn_tea_table": return "Tea Table"
		"furn_oak_table": return "Oak Dining Table"
		"furn_oak_dresser": return "Oak Dresser"
		"furn_carrot_rug": return "Carrot Rug"
		"furn_bookshelf": return "Bookshelf"
		"furn_retro_tv": return "Retro TV"
		"furn_royal_bed": return "Royal Single Bed"
		"furn_blue_bed": return "Blue Double Bed"
	return raw_name if raw_name != "" else "Item"

func _on_sell_slot_pressed(slot_idx: int) -> void:
	var inv := get_tree().get_first_node_in_group("inventory")
	if not inv or not inv.has_method("sell_item_at_slot"):
		return
	var res: Dictionary = inv.sell_item_at_slot(slot_idx)
	if res.get("success", false):
		var gold_earned: int = int(res.get("gold", 0))
		var item_name: String = str(res.get("name", "Item"))
		_set_shop_status("Sold %s for +%d Gold!" % [item_name, gold_earned], Color(0.45, 1.0, 0.55, 1.0))
		_show_floating_gold_text("+%d Gold" % gold_earned)
		_refresh_shop_items()

func _on_sell_selected_pressed() -> void:
	var inv := get_tree().get_first_node_in_group("inventory")
	if not inv or not inv.has_method("get_selected_item_data"):
		return
	var sel_data = inv.get_selected_item_data()
	if sel_data == null:
		_set_shop_status("Selected toolbar slot is empty!", Color(1.0, 0.5, 0.4, 1.0))
		return
	if not _is_item_matching_shop(sel_data):
		var msg := "This shop only buys Egg, Milk & Pork!" if shop_type == "egg_milk" else ("This shop only buys Fish!" if shop_type == "fish" else ("This shop only buys Furniture!" if shop_type == "furniture" else "Cannot sell this item!"))
		_set_shop_status(msg, Color(1.0, 0.5, 0.4, 1.0))
		return
	var res: Dictionary = inv.sell_selected_item()
	if res.get("success", false):
		var gold_earned: int = int(res.get("gold", 0))
		var item_name: String = str(res.get("name", "Item"))
		_set_shop_status("Sold %s from selected slot (+%d Gold)!" % [item_name, gold_earned], Color(0.45, 1.0, 0.55, 1.0))
		_show_floating_gold_text("+%d Gold" % gold_earned)
		_refresh_shop_items()
	else:
		_set_shop_status("Selected slot is empty or cannot be sold!", Color(1.0, 0.5, 0.4, 1.0))

func _on_sell_all_pressed() -> void:
	var inv := get_tree().get_first_node_in_group("inventory")
	if not inv or not ("inventory_data" in inv):
		return
	var total_gold: int = 0
	var count: int = 0
	for i in range(inv.inventory_data.size()):
		var item_data = inv.inventory_data[i]
		if item_data != null and _is_item_matching_shop(item_data):
			var res: Dictionary = inv.sell_item_at_slot(i)
			if res.get("success", false):
				total_gold += int(res.get("gold", 0))
				count += 1
	if count > 0:
		_set_shop_status("Sold %d items for a total of +%d Gold!" % [count, total_gold], Color(1.0, 0.9, 0.3, 1.0))
		_show_floating_gold_text("+%d Gold!" % total_gold)
		_refresh_shop_items()
	else:
		var empty_msg := "No Egg, Milk, or Pork in bag to sell!" if shop_type == "egg_milk" else ("No Fish in bag to sell!" if shop_type == "fish" else ("No Furniture in bag to sell!" if shop_type == "furniture" else "No sellable items in bag!"))
		_set_shop_status(empty_msg, Color(1.0, 0.5, 0.4, 1.0))

func _set_shop_status(msg: String, col: Color) -> void:
	if status_label:
		status_label.text = msg
		status_label.add_theme_color_override("font_color", col)

func _show_floating_gold_text(text_str: String, col: Color = Color(1.0, 0.9, 0.2, 1.0)) -> void:
	var float_lbl := Label.new()
	float_lbl.text = text_str
	float_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	float_lbl.position = Vector2(-80, -48)
	float_lbl.size = Vector2(160, 20)
	float_lbl.z_index = 30
	float_lbl.add_theme_font_size_override("font_size", 11)
	float_lbl.add_theme_color_override("font_color", col)
	float_lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.01, 1.0))
	float_lbl.add_theme_constant_override("outline_size", 3)
	add_child(float_lbl)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(float_lbl, "position:y", float_lbl.position.y - 22.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(float_lbl, "modulate:a", 0.0, 0.85).set_delay(0.25)
	await tween.finished
	if is_instance_valid(float_lbl):
		float_lbl.queue_free()

func _pick_random_direction() -> void:
	if _should_stand_still():
		move_direction = Vector2.ZERO
		return
	var directions: Array[Vector2] = [
		Vector2.UP,
		Vector2.DOWN,
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2.ZERO
	]
	move_direction = directions.pick_random()

func _update_animation() -> void:
	if not anim or not anim.sprite_frames:
		return

	if move_direction == Vector2.ZERO:
		if anim.is_playing():
			anim.stop()
		anim.frame = 0
		return

	if abs(move_direction.x) > abs(move_direction.y):
		if move_direction.x < 0:
			if anim.sprite_frames.has_animation("walk_left"):
				anim.flip_h = false
				anim.play("walk_left")
			elif anim.sprite_frames.has_animation("walk_right"):
				anim.flip_h = true
				anim.play("walk_right")
		else:
			anim.flip_h = false
			if anim.sprite_frames.has_animation("walk_right"):
				anim.play("walk_right")
	else:
		anim.flip_h = false
		if move_direction.y > 0:
			if anim.sprite_frames.has_animation("walk_down"):
				anim.play("walk_down")
		else:
			if anim.sprite_frames.has_animation("walk_up"):
				anim.play("walk_up")
