extends Control

@onready var bag_window: Control = $bagwindow
@onready var quick_bar: Control = $QuickBar
@onready var bag_grid: Control = $bagwindow/baggrid
@onready var quick_bar_bg: Control = get_node_or_null("QuickBarBg")
@onready var close_btn: Button = get_node_or_null("bagwindow/CloseBtn")

var all_slots: Array = []
var selected_slot_index: int = -1
var selected_slot: Control = null
var inventory_data: Array = []
var current_place_scene: PackedScene = null

# Lưu chỉ số ô đang được giữ chuột kéo đi
var dragging_slot_index: int = -1
# Kiểm tra xem có thả vào ô khác hay thả ra ngoài sàn
var dropped_inside_slot: bool = false

# Hiển thị Vàng trên thanh công cụ
var gold_panel: Panel = null
var gold_label: Label = null

# Giao diện Trang bị (Mũ, Áo, Quần) và Bảng Thuộc Tính (Level, HP, Mana)
var equip_panel: Panel = null
var equip_slots: Dictionary = {
	"hat": null,
	"shirt": null,
	"pants": null
}
var equipment_data: Dictionary = {
	"hat": null,
	"shirt": null,
	"pants": null
}
var stats_labels: Dictionary = {}

# Hệ thống Nấu Ăn (Cooking System)
var cooking_panel: Panel = null
var cooking_tab_btn: Button = null
var inventory_tab_btn: Button = null
var guide_side_btn: Button = null
var guide_modal: Panel = null
var cooking_recipes_vbox: VBoxContainer = null
var cooking_status_lbl: Label = null
var current_cooking_job: Dictionary = {} # {"recipe": Dictionary, "remaining": float, "total": float, "pbar": ProgressBar, "btn": Button}
var is_cooking_view: bool = false

# Danh mục các công thức nấu ăn (Nguyên liệu, thời gian nấu 30s, lượng máu hồi phục, icon)
const COOKING_RECIPES: Array[Dictionary] = [
	{
		"id": "cooked_egg",
		"name": "Fried Egg",
		"heal_amount": 20,
		"cook_time": 30.0,
		"ingredients": {"egg": 1},
		"desc": "Delicious sunny-side-up fried egg. Restores +20 HP.",
		"region": Rect2(0, 32, 16, 16),
		"atlas_path": "res://Content T1/Tilesheet/iteamdoan.png",
		"price": 35
	},
	{
		"id": "grilled_fish",
		"name": "Herb Grilled Fish",
		"heal_amount": 22,
		"cook_time": 30.0,
		"ingredients": {"fish": 1},
		"desc": "Whole grilled fish with seasoned herbs. Restores +22 HP.",
		"region": Rect2(32, 32, 16, 16),
		"atlas_path": "res://Content T1/Tilesheet/iteamdoan.png",
		"price": 55
	},
	{
		"id": "cooked_pork",
		"name": "Grilled Steak",
		"heal_amount": 25,
		"cook_time": 30.0,
		"ingredients": {"pork": 1},
		"desc": "Juicy and tender grilled meat steak. Restores +25 HP.",
		"region": Rect2(0, 0, 16, 16),
		"atlas_path": "res://Content T1/Tilesheet/iteamdoan.png",
		"price": 85
	},
	{
		"id": "noodle_soup",
		"name": "Hot Noodle Soup",
		"heal_amount": 25,
		"cook_time": 30.0,
		"ingredients": {"egg": 1, "pork": 1},
		"desc": "Steaming bowl of ramen with meat and egg toppings. Restores +25 HP.",
		"region": Rect2(0, 16, 16, 16),
		"atlas_path": "res://Content T1/Tilesheet/iteamdoan.png",
		"price": 100
	},
	{
		"id": "omelette",
		"name": "Cheese Omelette",
		"heal_amount": 25,
		"cook_time": 30.0,
		"ingredients": {"egg": 1, "cow_milk": 1},
		"desc": "Fluffy egg omelette with rich creamy milk. Restores +25 HP.",
		"region": Rect2(32, 16, 16, 16),
		"atlas_path": "res://Content T1/Tilesheet/iteamdoan.png",
		"price": 110
	},
	{
		"id": "pumpkin_soup",
		"name": "Golden Stew",
		"heal_amount": 25,
		"cook_time": 30.0,
		"ingredients": {"cow_milk": 1, "egg": 1},
		"desc": "Creamy golden stew made with fresh milk and egg. Restores +25 HP.",
		"region": Rect2(48, 32, 16, 16),
		"atlas_path": "res://Content T1/Tilesheet/iteamdoan.png",
		"price": 125
	},
	{
		"id": "roast_meat",
		"name": "Roast Feast",
		"heal_amount": 28,
		"cook_time": 30.0,
		"ingredients": {"pork": 2},
		"desc": "Generous platter of crisp roasted meat. Restores +28 HP.",
		"region": Rect2(48, 16, 16, 16),
		"atlas_path": "res://Content T1/Tilesheet/iteamdoan.png",
		"price": 140
	},
	{
		"id": "seafood_salad",
		"name": "Garden Salad",
		"heal_amount": 24,
		"cook_time": 30.0,
		"ingredients": {"fish": 1, "egg": 1},
		"desc": "Fresh garden salad tossed with fish and egg slices. Restores +24 HP.",
		"region": Rect2(16, 32, 16, 16),
		"atlas_path": "res://Content T1/Tilesheet/iteamdoan.png",
		"price": 115
	}
]

# Bảng giá vàng cho từng loại nông sản, thịt, cá, nguyên liệu và đồ nội thất
const ITEM_PRICES: Dictionary = {
	"cooked_egg": 35,
	"grilled_fish": 55,
	"cooked_pork": 85,
	"noodle_soup": 100,
	"omelette": 110,
	"pumpkin_soup": 125,
	"roast_meat": 140,
	"seafood_salad": 115,
	"salmon_steak": 120,
	"seafood_feast": 160,
	"branch": 10,
	"stone": 12,
	"egg": 15,
	"cow_milk": 30,
	"goat_milk": 40,
	"pork": 50,
	"fish": 20,
	"fish_carp": 20,
	"fish_perch": 25,
	"fish_shrimp": 30,
	"fish_crab": 35,
	"fish_salmon": 45,
	"fish_gold": 60,
	"fish_tuna": 75,
	"fish_octopus": 90,
	"furn_oak_chair": 80,
	"furn_birch_chair": 85,
	"furn_emerald_chair": 95,
	"furn_modern_chair": 110,
	"furn_floor_lamp": 130,
	"furn_oak_bench": 150,
	"furn_tea_table": 160,
	"furn_oak_table": 180,
	"furn_oak_dresser": 200,
	"furn_carrot_rug": 220,
	"furn_bookshelf": 250,
	"furn_retro_tv": 280,
	"furn_royal_bed": 320,
	"furn_blue_bed": 360,
	"storage_chest": 600,
	"crop_parsnip": 35,
	"crop_green_bean": 40,
	"crop_cauliflower": 85,
	"crop_potato": 50,
	"crop_garlic": 45,
	"crop_kale": 60,
	"crop_rhubarb": 110,
	"crop_melon": 140,
	"crop_tomato": 65,
	"crop_blueberry": 80
}

# Bảng thông số Sát Thương (Damage) & Sát Thương Kỹ Năng (Special Damage) của vũ khí và công cụ
const WEAPON_DAMAGE_CONFIG: Dictionary = {
	# Công cụ khai khoáng & chặt cây
	"wood_pickaxe": {"damage": 22, "special_damage": 50, "type": "Pickaxe"},
	"wood_axe": {"damage": 26, "special_damage": 56, "type": "Axe"},
	"stone_pickaxe": {"damage": 32, "special_damage": 68, "type": "Pickaxe"},
	"stone_axe": {"damage": 36, "special_damage": 75, "type": "Axe"},
	"iron_pickaxe": {"damage": 45, "special_damage": 92, "type": "Pickaxe"},
	"iron_axe": {"damage": 48, "special_damage": 96, "type": "Axe"},

	# Kiếm Thường / Đại Kiếm (Sword): Gỗ < Sắt < Đồng < Vàng < Đồ Tím
	"wood_sword": {"damage": 22, "special_damage": 48, "type": "Sword"},
	"iron_sword": {"damage": 38, "special_damage": 80, "type": "Sword"},
	"copper_sword": {"damage": 52, "special_damage": 110, "type": "Sword"},
	"gold_sword": {"damage": 75, "special_damage": 155, "type": "Sword"},
	"amethyst_sword": {"damage": 105, "special_damage": 215, "type": "Sword"},

	# Kiếm Quắm (Scythe): Gỗ < Sắt < Đồng < Vàng < Đồ Tím
	"wood_scythe": {"damage": 20, "special_damage": 44, "type": "Scythe"},
	"iron_scythe": {"damage": 35, "special_damage": 75, "type": "Scythe"},
	"copper_scythe": {"damage": 48, "special_damage": 100, "type": "Scythe"},
	"gold_scythe": {"damage": 70, "special_damage": 145, "type": "Scythe"},
	"amethyst_scythe": {"damage": 98, "special_damage": 200, "type": "Scythe"},

	# Giáo (Spear): Gỗ < Sắt < Đồng < Vàng < Đồ Tím
	"wood_spear": {"damage": 22, "special_damage": 48, "type": "Spear"},
	"iron_spear": {"damage": 38, "special_damage": 82, "type": "Spear"},
	"copper_spear": {"damage": 52, "special_damage": 112, "type": "Spear"},
	"gold_spear": {"damage": 75, "special_damage": 158, "type": "Spear"},
	"amethyst_spear": {"damage": 105, "special_damage": 220, "type": "Spear"},

	# Cung Tên (Bow): Gỗ < Sắt < Đồng < Vàng < Đồ Tím
	"wood_bow": {"damage": 18, "special_damage": 40, "type": "Bow"},
	"iron_bow": {"damage": 32, "special_damage": 70, "type": "Bow"},
	"copper_bow": {"damage": 45, "special_damage": 95, "type": "Bow"},
	"gold_bow": {"damage": 65, "special_damage": 138, "type": "Bow"},
	"amethyst_bow": {"damage": 95, "special_damage": 195, "type": "Bow"},

	# Vũ Khí Hiếm (Rare Weapons): Dame to hơn đồ tím (>105)
	"wood_staff": {"damage": 135, "special_damage": 275, "type": "Rare Sword"},
	"iron_staff": {"damage": 145, "special_damage": 295, "type": "Rare Sword"},
	"copper_staff": {"damage": 155, "special_damage": 315, "type": "Rare Sword"},
	"gold_staff": {"damage": 165, "special_damage": 335, "type": "Rare Dagger"},
	"amethyst_staff": {"damage": 185, "special_damage": 380, "type": "Rare Greatsword"}
}

func get_item_damage_info(item_id: String) -> Dictionary:
	if WEAPON_DAMAGE_CONFIG.has(item_id):
		return WEAPON_DAMAGE_CONFIG[item_id]
	return {}

const SLOT_NORMAL_COLOR := Color(0.92, 0.88, 0.82, 1.0)
const SLOT_HOVER_COLOR := Color(1.05, 1.0, 0.92, 1.0)
const SLOT_SELECTED_COLOR := Color(1.12, 1.05, 0.88, 1.0)

signal item_changed(item_texture)
signal inventory_updated()

func _ready() -> void:
	# Tránh chạy lại _ready() của root trên các ô con được gán cùng script
	if get_meta("is_slot", false) or get_meta("is_equip_slot", false):
		return

	# Kiểm tra nếu đây không phải là root node inventory thì bỏ qua
	if not quick_bar or not bag_grid:
		quick_bar = get_node_or_null("QuickBar")
		bag_grid = get_node_or_null("bagwindow/baggrid")
		if not quick_bar:
			return

	add_to_group("inventory")

	if bag_window:
		bag_window.visible = false
		bag_window.pivot_offset = bag_window.size * 0.5

	if close_btn and not close_btn.pressed.is_connected(_on_close_btn_pressed):
		close_btn.pressed.connect(_on_close_btn_pressed)

	all_slots.clear()
	inventory_data.clear()

	var q_children := quick_bar.get_children()
	for child in q_children:
		if child is TextureRect:
			all_slots.append(child)
	for child in bag_grid.get_children():
		if child is TextureRect:
			all_slots.append(child)

	var select_style := StyleBoxFlat.new()
	select_style.bg_color = Color(1.0, 0.88, 0.35, 0.14)
	select_style.border_width_left = 2
	select_style.border_width_top = 2
	select_style.border_width_right = 2
	select_style.border_width_bottom = 2
	select_style.border_color = Color(1.0, 0.86, 0.22, 1.0)
	select_style.corner_radius_top_left = 3
	select_style.corner_radius_top_right = 3
	select_style.corner_radius_bottom_right = 3
	select_style.corner_radius_bottom_left = 3

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(1.0, 0.96, 0.85, 0.1)
	hover_style.border_width_left = 1
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	hover_style.border_color = Color(0.95, 0.78, 0.45, 0.85)
	hover_style.corner_radius_top_left = 3
	hover_style.corner_radius_top_right = 3
	hover_style.corner_radius_bottom_right = 3
	hover_style.corner_radius_bottom_left = 3

	for i in range(all_slots.size()):
		inventory_data.append(null)
		var slot: TextureRect = all_slots[i]
		slot.set_meta("is_slot", true)
		slot.set_meta("slot_idx", i)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.pivot_offset = Vector2(20, 20)
		slot.modulate = Color.WHITE
		slot.self_modulate = SLOT_NORMAL_COLOR

		var icon_node := _get_slot_icon_node(slot)
		if icon_node:
			icon_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# Khung viền khi di chuột (HoverFrame)
		if not slot.has_node("HoverFrame"):
			var hover_frame := Panel.new()
			hover_frame.name = "HoverFrame"
			hover_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
			hover_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hover_frame.add_theme_stylebox_override("panel", hover_style)
			hover_frame.visible = false
			slot.add_child(hover_frame)

		# Khung viền vàng khi chọn ô (SelectFrame)
		if not slot.has_node("SelectFrame"):
			var select_frame := Panel.new()
			select_frame.name = "SelectFrame"
			select_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
			select_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			select_frame.add_theme_stylebox_override("panel", select_style)
			select_frame.visible = false
			slot.add_child(select_frame)

		# Hiển thị số phím tắt (1..9, 0) cho 10 ô trên thanh QuickBar
		if i < 10 and not slot.has_node("KeyLabel"):
			var key_label := Label.new()
			key_label.name = "KeyLabel"
			key_label.text = str((i + 1) % 10)
			key_label.position = Vector2(3, 1)
			key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			key_label.add_theme_font_size_override("font_size", 9)
			key_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 0.9))
			key_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.03, 1.0))
			key_label.add_theme_constant_override("outline_size", 3)
			slot.add_child(key_label)

		slot.set_script(self.get_script())
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_mouse_exited.bind(slot))

	_setup_equipment_ui()
	_setup_cooking_ui()
	_setup_gold_toolbar_ui()
	if SceneManager and not SceneManager.gold_changed.is_connected(_on_gold_changed):
		SceneManager.gold_changed.connect(_on_gold_changed)

	# Khôi phục dữ liệu balo nếu đã lưu hoặc cấp sẵn Cần Câu Cá & Bộ Công Cụ lúc mới vào game
	if SceneManager and SceneManager.saved_inventory_data.size() == all_slots.size():
		inventory_data = SceneManager.saved_inventory_data.duplicate(true)
		for i in range(all_slots.size()):
			update_slot_display(i)
		_give_starter_tools()
		_give_starter_clothes()
		select_slot_by_index(clampi(SceneManager.saved_selected_slot, 0, all_slots.size() - 1))
	else:
		if all_slots.size() > 0:
			select_slot_by_index(0)
		if not SceneManager or not SceneManager.has_received_starter_items:
			if SceneManager:
				SceneManager.has_received_starter_items = true
			_give_starter_fishing_rod()
		if not SceneManager or not SceneManager.has_received_starter_tools:
			if SceneManager:
				SceneManager.has_received_starter_tools = true
			_give_starter_tools()
		if not SceneManager or not SceneManager.get("has_received_starter_clothes"):
			if SceneManager:
				SceneManager.has_received_starter_clothes = true
			_give_starter_clothes()
		_sync_to_scene_manager()

	_restore_equipment_from_scene_manager()

func _give_starter_fishing_rod() -> void:
	var tools_tex := load("res://Content T1/Tilesheet/Tools1_tilet.png") as Texture2D
	var rod_scene := load("res://scenes/objects/fishing_rod_item.tscn") as PackedScene
	if tools_tex:
		var rod_icon := AtlasTexture.new()
		rod_icon.atlas = tools_tex
		rod_icon.region = Rect2(0, 144, 16, 16)
		add_item(rod_icon, rod_scene, "fishing_rod", "Fishing Rod")

func _give_starter_tools() -> void:
	var tools_tex := load("res://Content T1/Tilesheet/Tools1_tilet.png") as Texture2D
	if not tools_tex:
		return
	var starter_tools: Array[Dictionary] = [
		{
			"id": "wood_pickaxe",
			"name": "Wooden Pickaxe",
			"region": Rect2(80, 16, 16, 16),
			"scene": "res://scenes/objects/wood_pickaxe_item.tscn"
		},
		{
			"id": "wood_axe",
			"name": "Wooden Axe",
			"region": Rect2(80, 80, 16, 16),
			"scene": "res://scenes/objects/wood_axe_item.tscn"
		},
		{
			"id": "stone_pickaxe",
			"name": "Stone Pickaxe",
			"region": Rect2(80, 48, 16, 16),
			"scene": "res://scenes/objects/stone_pickaxe_item.tscn"
		},
		{
			"id": "stone_axe",
			"name": "Stone Axe",
			"region": Rect2(80, 112, 16, 16),
			"scene": "res://scenes/objects/stone_axe_item.tscn"
		},
		{
			"id": "iron_pickaxe",
			"name": "Iron Pickaxe",
			"region": Rect2(192, 16, 16, 16),
			"scene": "res://scenes/objects/iron_pickaxe_item.tscn"
		},
		{
			"id": "iron_axe",
			"name": "Iron Axe",
			"region": Rect2(192, 80, 16, 16),
			"scene": "res://scenes/objects/iron_axe_item.tscn"
		}
	]
	var weapon_tex := load("res://Content T1/Tilesheet/Weapon1_tilet.png") as Texture2D
	var starter_weapons: Array[Dictionary] = [
		{"id": "wood_sword", "name": "Wooden Sword", "region": Rect2(48, 112, 16, 16), "scene": "res://scenes/objects/wood_sword_item.tscn"},
		{"id": "iron_sword", "name": "Iron Sword", "region": Rect2(64, 112, 16, 16), "scene": "res://scenes/objects/iron_sword_item.tscn"},
		{"id": "copper_sword", "name": "Copper Sword", "region": Rect2(80, 112, 16, 16), "scene": "res://scenes/objects/copper_sword_item.tscn"},
		{"id": "gold_sword", "name": "Gold Sword", "region": Rect2(96, 112, 16, 16), "scene": "res://scenes/objects/gold_sword_item.tscn"},
		{"id": "amethyst_sword", "name": "Amethyst Sword", "region": Rect2(112, 112, 16, 16), "scene": "res://scenes/objects/amethyst_sword_item.tscn"},
		{"id": "wood_scythe", "name": "Wooden Scythe", "region": Rect2(48, 80, 16, 16), "scene": "res://scenes/objects/wood_scythe_item.tscn"},
		{"id": "iron_scythe", "name": "Iron Scythe", "region": Rect2(64, 80, 16, 16), "scene": "res://scenes/objects/iron_scythe_item.tscn"},
		{"id": "copper_scythe", "name": "Copper Scythe", "region": Rect2(80, 80, 16, 16), "scene": "res://scenes/objects/copper_scythe_item.tscn"},
		{"id": "gold_scythe", "name": "Gold Scythe", "region": Rect2(96, 80, 16, 16), "scene": "res://scenes/objects/gold_scythe_item.tscn"},
		{"id": "amethyst_scythe", "name": "Amethyst Scythe", "region": Rect2(112, 80, 16, 16), "scene": "res://scenes/objects/amethyst_scythe_item.tscn"},
		{"id": "wood_bow", "name": "Wooden Bow", "region": Rect2(48, 64, 16, 16), "scene": "res://scenes/objects/wood_bow_item.tscn"},
		{"id": "iron_bow", "name": "Iron Bow", "region": Rect2(64, 64, 16, 16), "scene": "res://scenes/objects/iron_bow_item.tscn"},
		{"id": "copper_bow", "name": "Copper Bow", "region": Rect2(80, 64, 16, 16), "scene": "res://scenes/objects/copper_bow_item.tscn"},
		{"id": "gold_bow", "name": "Gold Bow", "region": Rect2(96, 64, 16, 16), "scene": "res://scenes/objects/gold_bow_item.tscn"},
		{"id": "amethyst_bow", "name": "Amethyst Bow", "region": Rect2(112, 64, 16, 16), "scene": "res://scenes/objects/amethyst_bow_item.tscn"},
		{"id": "wood_spear", "name": "Wooden Spear", "region": Rect2(48, 32, 16, 16), "scene": "res://scenes/objects/wood_spear_item.tscn"},
		{"id": "iron_spear", "name": "Iron Spear", "region": Rect2(64, 32, 16, 16), "scene": "res://scenes/objects/iron_spear_item.tscn"},
		{"id": "copper_spear", "name": "Copper Spear", "region": Rect2(80, 32, 16, 16), "scene": "res://scenes/objects/copper_spear_item.tscn"},
		{"id": "gold_spear", "name": "Gold Spear", "region": Rect2(96, 32, 16, 16), "scene": "res://scenes/objects/gold_spear_item.tscn"},
		{"id": "amethyst_spear", "name": "Amethyst Spear", "region": Rect2(112, 32, 16, 16), "scene": "res://scenes/objects/amethyst_spear_item.tscn"},
		{"id": "wood_staff", "name": "Wooden Staff", "region": Rect2(48, 96, 16, 16), "scene": "res://scenes/objects/wood_staff_item.tscn"},
		{"id": "iron_staff", "name": "Iron Staff", "region": Rect2(64, 96, 16, 16), "scene": "res://scenes/objects/iron_staff_item.tscn"},
		{"id": "copper_staff", "name": "Copper Staff", "region": Rect2(80, 96, 16, 16), "scene": "res://scenes/objects/copper_staff_item.tscn"},
		{"id": "gold_staff", "name": "Gold Staff", "region": Rect2(96, 96, 16, 16), "scene": "res://scenes/objects/gold_staff_item.tscn"},
		{"id": "amethyst_staff", "name": "Amethyst Staff", "region": Rect2(112, 96, 16, 16), "scene": "res://scenes/objects/amethyst_staff_item.tscn"}
	]
	var all_give = starter_tools.duplicate()
	if weapon_tex:
		for w in starter_weapons:
			all_give.append(w)
	for t in all_give:
		var already_has := false
		for slot_item in inventory_data:
			if typeof(slot_item) == TYPE_DICTIONARY and slot_item != null and slot_item.get("id", "") == t["id"]:
				already_has = true
				break
		if not already_has:
			var icon := AtlasTexture.new()
			if t["id"].find("pickaxe") != -1 or t["id"].find("axe") != -1:
				icon.atlas = tools_tex
			else:
				icon.atlas = weapon_tex
			icon.region = t["region"]
			var sc := load(str(t["scene"])) as PackedScene
			add_item(icon, sc, str(t["id"]), str(t["name"]))

func _sync_to_scene_manager() -> void:
	if SceneManager:
		SceneManager.saved_inventory_data = inventory_data.duplicate(true)
		SceneManager.saved_selected_slot = selected_slot_index
		SceneManager.saved_equipment_data = equipment_data.duplicate(true)
	inventory_updated.emit()

func get_selected_item_data() -> Variant:
	if selected_slot_index >= 0 and selected_slot_index < inventory_data.size():
		return inventory_data[selected_slot_index]
	return null

func is_holding_fishing_rod() -> bool:
	var data = get_selected_item_data()
	return data != null and data.get("id", "") == "fishing_rod"

func get_selected_tool_id() -> String:
	var data = get_selected_item_data()
	if typeof(data) != TYPE_DICTIONARY or data == null:
		return ""
	var id_str: String = str(data.get("id", ""))
	if id_str in [
		"wood_pickaxe", "wood_axe", "stone_pickaxe", "stone_axe", "iron_pickaxe", "iron_axe",
		"wood_sword", "iron_sword", "copper_sword", "gold_sword", "amethyst_sword",
		"wood_scythe", "iron_scythe", "copper_scythe", "gold_scythe", "amethyst_scythe",
		"wood_bow", "iron_bow", "copper_bow", "gold_bow", "amethyst_bow",
		"wood_spear", "iron_spear", "copper_spear", "gold_spear", "amethyst_spear",
		"wood_staff", "iron_staff", "copper_staff", "gold_staff", "amethyst_staff"
	]:
		return id_str
	return ""

func is_holding_tool() -> bool:
	return get_selected_tool_id() != ""

func is_furniture_item(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data == null:
		return false
	var id_str: String = str(data.get("id", "")).to_lower()
	if id_str.begins_with("furn_") or id_str == "storage_chest":
		return true
	var name_str: String = str(data.get("name", "")).to_lower()
	if "chest" in name_str or "rương" in name_str:
		return true
	var icon_tex = data.get("icon")
	if icon_tex != null and icon_tex is AtlasTexture:
		var atlas_res = icon_tex.atlas
		if atlas_res != null and "resource_path" in atlas_res:
			var path_str: String = str(atlas_res.resource_path)
			if path_str.find("Furniture_tilet") != -1 or path_str.find("Cursors 2.png") != -1:
				return true
	return false

func is_holding_furniture() -> bool:
	return is_furniture_item(get_selected_item_data())

func is_in_house_map() -> bool:
	var cur_scene := get_tree().current_scene
	if not cur_scene:
		return false
	if cur_scene.is_in_group("house_map"):
		return true
	var path_lower := cur_scene.scene_file_path.to_lower()
	return "house map" in path_lower or "house_map" in path_lower

func is_mouse_over_inventory_ui() -> bool:
	var mouse_pos := get_viewport().get_mouse_position()
	if quick_bar and quick_bar.is_visible_in_tree() and quick_bar.get_global_rect().grow(10.0).has_point(mouse_pos):
		return true
	if quick_bar_bg and quick_bar_bg.is_visible_in_tree() and quick_bar_bg.get_global_rect().grow(8.0).has_point(mouse_pos):
		return true
	if gold_panel and gold_panel.is_visible_in_tree() and gold_panel.get_global_rect().grow(6.0).has_point(mouse_pos):
		return true
	if bag_window and bag_window.is_visible_in_tree() and bag_window.get_global_rect().has_point(mouse_pos):
		return true
	for shop_panel in get_tree().get_nodes_in_group("merchant_shop_ui"):
		if shop_panel is Control and shop_panel.is_visible_in_tree() and shop_panel.get_global_rect().has_point(mouse_pos):
			return true
	return false

func place_selected_furniture_at_mouse() -> bool:
	if selected_slot_index < 0 or selected_slot_index >= inventory_data.size():
		return false
	var data = inventory_data[selected_slot_index]
	if not is_furniture_item(data):
		return false
	if is_mouse_over_inventory_ui():
		return false
	place_dragged_item_to_world(selected_slot_index)
	return true

func _show_inventory_notice(msg: String, col: Color = Color(1.0, 0.9, 0.4, 1.0)) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.anchor_top = 1.0
	lbl.anchor_bottom = 1.0
	lbl.offset_left = -220.0
	lbl.offset_right = 220.0
	lbl.offset_top = -95.0
	lbl.offset_bottom = -65.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.01, 1.0))
	lbl.add_theme_constant_override("outline_size", 4)
	add_child(lbl)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(lbl, "offset_top", lbl.offset_top - 22.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.1).set_delay(0.35)
	await tween.finished
	if is_instance_valid(lbl):
		lbl.queue_free()

func _on_close_btn_pressed() -> void:
	toggle_bag_window(false)

func toggle_bag_window(force_state: Variant = null) -> void:
	if not bag_window:
		return
	var target_visible: bool = (not bag_window.visible) if force_state == null else bool(force_state)
	if target_visible == bag_window.visible:
		return

	bag_window.pivot_offset = bag_window.size * 0.5
	if target_visible:
		update_stats_display()
		if is_cooking_view:
			_render_cooking_recipes()
		bag_window.visible = true
		bag_window.scale = Vector2(0.92, 0.92)
		bag_window.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(bag_window, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(bag_window, "modulate:a", 1.0, 0.12)
	else:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(bag_window, "scale", Vector2(0.94, 0.94), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(bag_window, "modulate:a", 0.0, 0.1)
		await tween.finished
		if is_instance_valid(bag_window):
			bag_window.visible = false
			bag_window.scale = Vector2.ONE
			bag_window.modulate.a = 1.0
			if guide_modal and is_instance_valid(guide_modal):
				guide_modal.visible = false

func _on_slot_mouse_entered(slot: Control) -> void:
	var idx: int = slot.get_meta("slot_idx", -1)
	var hover_frame := slot.get_node_or_null("HoverFrame")
	if hover_frame:
		hover_frame.visible = true
	if idx != selected_slot_index:
		slot.self_modulate = SLOT_HOVER_COLOR

func _on_slot_mouse_exited(slot: Control) -> void:
	var idx: int = slot.get_meta("slot_idx", -1)
	var hover_frame := slot.get_node_or_null("HoverFrame")
	if hover_frame:
		hover_frame.visible = false
	slot.self_modulate = SLOT_SELECTED_COLOR if idx == selected_slot_index else SLOT_NORMAL_COLOR

func _unhandled_input(event: InputEvent) -> void:
	if not is_in_group("inventory"):
		return

	# Bật / tắt balo bằng phím E hoặc ESC khi đang mở balo
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			toggle_bag_window()
			return
		elif event.keycode == KEY_ESCAPE and bag_window and bag_window.visible:
			toggle_bag_window(false)
			return

		var q_count := quick_bar.get_child_count()
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx: int = event.keycode - KEY_1
			if idx < q_count:
				select_slot_by_index(idx)
		elif event.keycode == KEY_0:
			if q_count >= 10:
				select_slot_by_index(9)

	# Lăn chuột để chuyển nhanh giữa 10 ô trên thanh QuickBar
	if event is InputEventMouseButton and event.pressed:
		var q_count := mini(10, all_slots.size())
		if q_count > 0:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				var cur := selected_slot_index if (selected_slot_index >= 0 and selected_slot_index < q_count) else 0
				select_slot_by_index((cur - 1 + q_count) % q_count)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var cur := selected_slot_index if (selected_slot_index >= 0 and selected_slot_index < q_count) else 0
				select_slot_by_index((cur + 1) % q_count)

# ----------------- HỆ THỐNG KÉO THẢ (TRONG BALO & RA NGOÀI SÀN) -----------------
func _get_drag_data(_at_position: Vector2) -> Variant:
	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv:
		return null

	# Trường hợp 1: Kéo từ ô Trang Bị (Mũ / Áo / Quần)
	if get_meta("is_equip_slot", false):
		var slot_type: String = str(get_meta("equip_type", ""))
		var eq_data = inv.equipment_data.get(slot_type)
		if eq_data == null or typeof(eq_data) != TYPE_DICTIONARY:
			return null

		inv.dragging_slot_index = -1
		inv.dropped_inside_slot = false

		var preview_texture := TextureRect.new()
		preview_texture.texture = eq_data.get("icon")
		preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_texture.size = Vector2(36, 36)

		var preview_control := Control.new()
		preview_control.add_child(preview_texture)
		preview_texture.position = -0.5 * preview_texture.size
		set_drag_preview(preview_control)

		return {"from_equip_slot": slot_type, "item": eq_data}

	# Trường hợp 2: Kéo từ ô Balo thông thường
	var idx = get_meta("slot_idx", -1)
	if idx == -1 or inv.inventory_data[idx] == null:
		return null

	var data = inv.inventory_data[idx]

	# Ghi nhận đang bắt đầu kéo từ ô idx
	inv.dragging_slot_index = idx
	inv.dropped_inside_slot = false

	# Tạo hình ảnh đi theo con trỏ chuột khi kéo
	var preview_texture := TextureRect.new()
	preview_texture.texture = data["icon"]
	preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.size = Vector2(36, 36)

	var preview_control := Control.new()
	preview_control.add_child(preview_texture)
	preview_texture.position = -0.5 * preview_texture.size
	set_drag_preview(preview_control)

	return {"from_slot": idx}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv:
		return false

	# Nếu đích thả là ô Trang Bị
	if get_meta("is_equip_slot", false):
		var target_type: String = str(get_meta("equip_type", ""))
		if data.has("from_slot"):
			var from_idx: int = int(data["from_slot"])
			if from_idx >= 0 and from_idx < inv.inventory_data.size():
				var item = inv.inventory_data[from_idx]
				return inv.get_item_equip_type(item) == target_type
		elif data.has("from_equip_slot"):
			return str(data["from_equip_slot"]) == target_type
		return false

	# Nếu đích thả là ô Balo thông thường
	return data.has("from_slot") or data.has("from_chest_slot") or data.has("from_equip_slot")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv or typeof(data) != TYPE_DICTIONARY:
		return

	# Đích thả là ô Trang Bị
	if get_meta("is_equip_slot", false):
		var target_type: String = str(get_meta("equip_type", ""))
		inv.dropped_inside_slot = true
		if data.has("from_slot"):
			var from_idx: int = int(data["from_slot"])
			if from_idx >= 0 and from_idx < inv.inventory_data.size():
				var item_to_equip = inv.inventory_data[from_idx]
				if inv.get_item_equip_type(item_to_equip) == target_type:
					var old_item = inv.equip_item_from_data(target_type, item_to_equip)
					inv.inventory_data[from_idx] = old_item if not old_item.is_empty() else null
					inv.update_slot_display(from_idx)
					inv._sync_to_scene_manager()
		return

	# Đích thả là ô Balo thông thường
	var to_idx = get_meta("slot_idx", -1)
	inv.dropped_inside_slot = true

	if data.has("from_slot"):
		var from_idx = data["from_slot"]
		if to_idx != -1 and from_idx != to_idx:
			inv.swap_slots(from_idx, to_idx)
	elif data.has("from_equip_slot"):
		var slot_type: String = str(data["from_equip_slot"])
		if to_idx != -1:
			inv.unequip_item_to_slot(slot_type, to_idx)
	elif data.has("from_chest_slot"):
		var chest_ref = data.get("chest_ref")
		var from_chest_idx: int = int(data["from_chest_slot"])
		if chest_ref and is_instance_valid(chest_ref) and to_idx != -1:
			chest_ref.transfer_or_swap_to_inventory(from_chest_idx, to_idx)

# Tự động phát hiện khi người chơi NHẢ CHUỘT kết thúc thao tác kéo
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if not is_in_group("inventory"):
			return

		# Nếu đang kéo 1 món đồ mà người chơi nhả chuột ở NGOÀI các ô Balo -> Đặt xuống sàn!
		if dragging_slot_index != -1 and not dropped_inside_slot:
			var mouse_pos := get_viewport().get_mouse_position()
			var over_ui: bool = false

			# Kiểm tra chắc chắn chuột không nằm đè lên thanh QuickBar hay cửa sổ Bag
			if quick_bar and quick_bar.is_visible_in_tree() and quick_bar.get_global_rect().grow(10.0).has_point(mouse_pos):
				over_ui = true
			if quick_bar_bg and quick_bar_bg.is_visible_in_tree() and quick_bar_bg.get_global_rect().grow(8.0).has_point(mouse_pos):
				over_ui = true
			if gold_panel and gold_panel.is_visible_in_tree() and gold_panel.get_global_rect().grow(6.0).has_point(mouse_pos):
				over_ui = true
			if bag_window and bag_window.is_visible_in_tree() and bag_window.get_global_rect().has_point(mouse_pos):
				over_ui = true

			for shop_panel in get_tree().get_nodes_in_group("merchant_shop_ui"):
				if shop_panel is Control and shop_panel.is_visible_in_tree() and shop_panel.get_global_rect().has_point(mouse_pos):
					over_ui = true
					break

			if not over_ui:
				# Nếu thả trực tiếp lên NPC Thương Nhân ở gần thì bán luôn món đồ đó
				var sold_to_merchant: bool = false
				if get_tree().current_scene:
					var world_mouse := (get_tree().current_scene as Node2D).get_global_mouse_position()
					for npc in get_tree().get_nodes_in_group("merchant"):
						if npc is Node2D and npc.global_position.distance_to(world_mouse) <= 36.0:
							if npc.has_method("sell_from_drag_slot"):
								sold_to_merchant = npc.sell_from_drag_slot(dragging_slot_index)
								break
				if not sold_to_merchant:
					place_dragged_item_to_world(dragging_slot_index)

		dragging_slot_index = -1
		dropped_inside_slot = false

# Đặt món đồ vừa kéo thả ra thế giới 2D
func place_dragged_item_to_world(slot_idx: int) -> void:
	var data = inventory_data[slot_idx]
	if data == null or data["scene"] == null:
		return

	if is_furniture_item(data) and not is_in_house_map():
		_show_inventory_notice("Furniture can only be used inside House Map!", Color(1.0, 0.55, 0.4, 1.0))
		return

	var new_item = data["scene"].instantiate()
	var target_parent = get_tree().current_scene
	target_parent.add_child(new_item)

	# Lấy đúng vị trí chuột trên mặt sàn 2D và căn lưới 16x16
	var world_mouse_pos = target_parent.get_global_mouse_position()
	var snap_x = floor(world_mouse_pos.x / 16.0) * 16.0 + 8.0
	var snap_y = floor(world_mouse_pos.y / 16.0) * 16.0 + 8.0
	new_item.global_position = Vector2(snap_x, snap_y)
	if "previous_valid_position" in new_item:
		new_item.previous_valid_position = new_item.global_position

	# Giữ nguyên icon, id và tên của món đồ (đặc biệt là các loại cá và nội thất khác nhau) khi đặt ra sàn
	if data.get("icon") != null:
		new_item.item_icon = data["icon"]
		var spr := new_item.get_node_or_null("Sprite2D") as Sprite2D
		if spr and data["icon"] is AtlasTexture:
			var atlas_tex := data["icon"] as AtlasTexture
			spr.texture = atlas_tex.atlas
			spr.region_enabled = true
			spr.region_rect = atlas_tex.region
	if "item_id" in new_item and data.get("id", "") != "":
		new_item.item_id = data["id"]
	if "item_name" in new_item and data.get("name", "") != "":
		new_item.item_name = data["name"]
	if new_item.has_method("update_collision_from_sprite"):
		new_item.update_collision_from_sprite()
	if target_parent.has_method("save_furniture_state"):
		target_parent.call_deferred("save_furniture_state")

	print(">>> ĐÃ KÉO THẢ ĐỒ RA SÀN TẠI: ", new_item.global_position)

	# Xóa món đồ khỏi ô sau khi đặt
	inventory_data[slot_idx] = null
	update_slot_display(slot_idx)
	if selected_slot_index == slot_idx:
		current_place_scene = null
		item_changed.emit(null)
	_sync_to_scene_manager()

# Click chuột trái để chọn ô, chuột phải khi đang mở rương để cất nhanh vào rương
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var inv = get_tree().get_first_node_in_group("inventory")
		var idx = get_meta("slot_idx", -1)
		if not inv or idx == -1:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			inv.select_slot_by_index(idx)
		elif event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed):
			# Kiểm tra xem có rương đang mở không, nếu có thì cất nhanh vào rương
			var stored_in_chest: bool = false
			for chest in get_tree().get_nodes_in_group("storage_chest"):
				if is_instance_valid(chest) and chest.get("is_open") == true:
					if chest.has_method("store_item_from_inventory_slot"):
						chest.store_item_from_inventory_slot(idx)
						accept_event()
						stored_in_chest = true
						break
			if not stored_in_chest:
				# Nếu là thức ăn (Food), click chuột phải để ăn và hồi máu
				if inv.has_method("try_eat_food_from_slot") and inv.try_eat_food_from_slot(idx):
					accept_event()
				# Nếu là trang bị (mũ, áo, quần), tự động mặc vào ô trang bị khi click chuột phải
				elif inv.has_method("try_auto_equip_from_slot"):
					if inv.try_auto_equip_from_slot(idx):
						accept_event()

# ----------------- QUẢN LÝ DỮ LIỆU Ô -----------------
func _get_slot_icon_node(slot: Node) -> TextureRect:
	var target_icon := slot.get_node_or_null("Icon") as TextureRect
	if not target_icon:
		target_icon = slot.get_node_or_null("icon") as TextureRect
	return target_icon

func add_item(icon: Texture2D, scene_to_place: PackedScene = null, item_id: String = "", item_name: String = "", defense: int = 0) -> bool:
	for i in range(inventory_data.size()):
		if inventory_data[i] == null:
			var item_dict: Dictionary = {
				"scene": scene_to_place,
				"icon": icon,
				"id": item_id,
				"name": item_name
			}
			if defense > 0:
				item_dict["defense"] = defense
			inventory_data[i] = item_dict
			update_slot_display(i)
			# Hiệu ứng nảy nhẹ khi nhặt đồ vào ô
			var slot: Control = all_slots[i]
			slot.pivot_offset = slot.size * 0.5
			slot.scale = Vector2(1.18, 1.18)
			var tween := create_tween()
			tween.tween_property(slot, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if i == selected_slot_index:
				current_place_scene = scene_to_place
				item_changed.emit(icon)
			_sync_to_scene_manager()
			return true
	return false

func update_slot_display(idx: int) -> void:
	if idx < 0 or idx >= all_slots.size():
		return
	var slot = all_slots[idx]
	var data = inventory_data[idx]
	var target_icon := _get_slot_icon_node(slot)

	if data != null:
		if target_icon:
			target_icon.texture = data["icon"]
		else:
			slot.texture = data["icon"]
		var item_name_str: String = str(data.get("name", ""))
		var price: int = get_item_price(data)
		var def_val: int = int(data.get("defense", 0))
		var heal_val: int = int(data.get("heal_amount", 0))
		var tt_parts: Array[String] = [item_name_str if item_name_str != "" else "Item"]

		# Hiển thị hồi máu nếu là thức ăn
		if heal_val > 0:
			tt_parts.append("🍖 Restores: +%d HP" % heal_val)
			tt_parts.append("(Right-click to consume)")

		# Hiển thị sát thương nếu là vũ khí / công cụ
		var item_id_str: String = str(data.get("id", ""))
		var dmg_info: Dictionary = get_item_damage_info(item_id_str)
		if not dmg_info.is_empty():
			tt_parts.append("⚔️ Damage: %d" % int(dmg_info["damage"]))
			tt_parts.append("💥 Special Damage: %d" % int(dmg_info["special_damage"]))

		if def_val > 0:
			tt_parts.append("🛡️ Defense: +%d" % def_val)
		if price > 0:
			tt_parts.append("💰 Sell: %d Gold" % price)
		slot.tooltip_text = "\n".join(tt_parts)
	else:
		if target_icon:
			target_icon.texture = null
		else:
			slot.texture = null
		slot.tooltip_text = ""

func swap_slots(from_idx: int, to_idx: int) -> void:
	var temp = inventory_data[from_idx]
	inventory_data[from_idx] = inventory_data[to_idx]
	inventory_data[to_idx] = temp

	update_slot_display(from_idx)
	update_slot_display(to_idx)
	select_slot_by_index(to_idx)
	_sync_to_scene_manager()

func select_slot_by_index(idx: int) -> void:
	if idx < 0 or idx >= all_slots.size():
		return

	for i in range(all_slots.size()):
		var s: Control = all_slots[i]
		s.self_modulate = SLOT_NORMAL_COLOR
		var sel_frame := s.get_node_or_null("SelectFrame")
		if sel_frame:
			sel_frame.visible = false

	selected_slot_index = idx
	selected_slot = all_slots[idx]
	selected_slot.self_modulate = SLOT_SELECTED_COLOR
	var active_frame := selected_slot.get_node_or_null("SelectFrame")
	if active_frame:
		active_frame.visible = true

	var data = inventory_data[idx]
	if data != null:
		current_place_scene = data["scene"]
		item_changed.emit(data["icon"])
	else:
		current_place_scene = null
		item_changed.emit(null)
	_sync_to_scene_manager()

func count_item(item_id: String) -> int:
	var count: int = 0
	for item in inventory_data:
		if typeof(item) == TYPE_DICTIONARY and item != null:
			if str(item.get("id", "")) == item_id:
				count += 1
	return count

func remove_items_by_id(item_id: String, amount_to_remove: int) -> bool:
	if count_item(item_id) < amount_to_remove:
		return false
	var remaining: int = amount_to_remove
	for i in range(inventory_data.size()):
		var item = inventory_data[i]
		if typeof(item) == TYPE_DICTIONARY and item != null:
			if str(item.get("id", "")) == item_id:
				inventory_data[i] = null
				update_slot_display(i)
				remaining -= 1
				if remaining <= 0:
					break
	_sync_to_scene_manager()
	emit_signal("inventory_updated")
	return true

func has_inventory_space() -> bool:
	for item in inventory_data:
		if item == null:
			return true
	return false

# ----------------- HỆ THỐNG HIỂN THỊ VÀNG & BÁN HÀNG -----------------
func _setup_gold_toolbar_ui() -> void:
	if has_node("GoldToolbarPanel"):
		gold_panel = get_node("GoldToolbarPanel") as Panel
		gold_label = gold_panel.get_node_or_null("GoldLabel") as Label
		_update_gold_display()
		return

	gold_panel = Panel.new()
	gold_panel.name = "GoldToolbarPanel"
	gold_panel.anchor_left = 1.0
	gold_panel.anchor_top = 0.0
	gold_panel.anchor_right = 1.0
	gold_panel.anchor_bottom = 0.0
	# Đặt ở góc trên bên phải màn hình
	gold_panel.offset_left = -152.0
	gold_panel.offset_top = 16.0
	gold_panel.offset_right = -16.0
	gold_panel.offset_bottom = 56.0
	gold_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.12, 0.07, 0.94)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.95, 0.75, 0.22, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.expand_margin_left = 4.0
	style.expand_margin_top = 4.0
	style.expand_margin_right = 4.0
	style.expand_margin_bottom = 4.0
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	gold_panel.add_theme_stylebox_override("panel", style)
	add_child(gold_panel)

	# Biểu tượng đồng xu vàng trên thanh công cụ
	var coin_badge := Panel.new()
	coin_badge.name = "CoinBadge"
	coin_badge.position = Vector2(8, 9)
	coin_badge.size = Vector2(22, 22)
	coin_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin_style := StyleBoxFlat.new()
	coin_style.bg_color = Color(1.0, 0.82, 0.18, 1.0)
	coin_style.border_width_left = 2
	coin_style.border_width_top = 2
	coin_style.border_width_right = 2
	coin_style.border_width_bottom = 2
	coin_style.border_color = Color(0.72, 0.45, 0.06, 1.0)
	coin_style.corner_radius_top_left = 11
	coin_style.corner_radius_top_right = 11
	coin_style.corner_radius_bottom_right = 11
	coin_style.corner_radius_bottom_left = 11
	coin_badge.add_theme_stylebox_override("panel", coin_style)
	gold_panel.add_child(coin_badge)

	var coin_sym := Label.new()
	coin_sym.text = "G"
	coin_sym.set_anchors_preset(Control.PRESET_FULL_RECT)
	coin_sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_sym.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_sym.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_sym.add_theme_font_size_override("font_size", 11)
	coin_sym.add_theme_color_override("font_color", Color(0.32, 0.16, 0.02, 1.0))
	coin_badge.add_child(coin_sym)

	gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.position = Vector2(34, 0)
	gold_label.size = Vector2(92, 40)
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_label.add_theme_font_size_override("font_size", 13)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35, 1.0))
	gold_label.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.02, 1.0))
	gold_label.add_theme_constant_override("outline_size", 4)
	gold_panel.add_child(gold_label)

	_update_gold_display()

func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_display()
	if gold_panel:
		gold_panel.pivot_offset = gold_panel.size * 0.5
		gold_panel.scale = Vector2(1.12, 1.12)
		var tween := create_tween()
		tween.tween_property(gold_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_gold_display() -> void:
	if not gold_label:
		return
	var current_gold: int = SceneManager.get_gold() if SceneManager else 0
	gold_label.text = "%d Gold" % current_gold

func get_item_price(data: Variant) -> int:
	if typeof(data) != TYPE_DICTIONARY or data == null:
		return 0
	var item_id: String = str(data.get("id", ""))
	if item_id in ["fishing_rod", "wood_pickaxe", "wood_axe", "stone_pickaxe", "stone_axe", "iron_pickaxe", "iron_axe", "copper_ore", "iron_ore", "gold_ore", "amethyst_gem"]:
		return 0
	if item_id.ends_with("_sword") or item_id.ends_with("_scythe") or item_id.ends_with("_bow") or item_id.ends_with("_spear") or item_id.ends_with("_staff"):
		return 0
	# Quần áo, mũ, giáp không thể bán
	if get_item_equip_type(data) != "":
		return 0
	if item_id.begins_with("hat_") or item_id.begins_with("shirt_") or item_id.begins_with("pants_"):
		return 0
	var item_name_check: String = str(data.get("name", "")).to_lower()
	if "ore" in item_name_check or "amethyst" in item_name_check:
		return 0
	if ITEM_PRICES.has(item_id):
		return int(ITEM_PRICES[item_id])
	# Fallback dựa theo tên hoặc scene path nếu vật phẩm chưa có id
	var item_name: String = str(data.get("name", "")).to_lower()
	if "pork" in item_name or "thịt" in item_name or "meat" in item_name:
		return 50
	if "goat" in item_name:
		return 40
	if "cow" in item_name or "milk" in item_name:
		return 30
	if "egg" in item_name or "trứng" in item_name:
		return 15
	if "octopus" in item_name:
		return 90
	if "tuna" in item_name:
		return 75
	if "gold" in item_name:
		return 60
	if "salmon" in item_name:
		return 45
	if "crab" in item_name:
		return 35
	if "shrimp" in item_name:
		return 30
	if "perch" in item_name:
		return 25
	if "carp" in item_name or "fish" in item_name or "cá" in item_name:
		return 20
	if "double bed" in item_name or "blue bed" in item_name:
		return 360
	if "royal" in item_name or "bed" in item_name:
		return 320
	if "tv" in item_name:
		return 280
	if "bookshelf" in item_name or "shelf" in item_name:
		return 250
	if "rug" in item_name:
		return 220
	if "dresser" in item_name:
		return 200
	if "dining table" in item_name:
		return 180
	if "tea table" in item_name or "table" in item_name:
		return 160
	if "bench" in item_name:
		return 150
	if "lamp" in item_name:
		return 130
	if "chair" in item_name or is_furniture_item(data):
		return 80
	return 15

func sell_item_at_slot(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= inventory_data.size():
		return {"success": false, "gold": 0, "name": ""}
	var data = inventory_data[slot_idx]
	if data == null:
		return {"success": false, "gold": 0, "name": ""}
	var price: int = get_item_price(data)
	if price <= 0:
		return {"success": false, "gold": 0, "name": str(data.get("name", ""))}

	var item_name: String = str(data.get("name", "Item"))
	if item_name == "":
		item_name = "Item"

	inventory_data[slot_idx] = null
	update_slot_display(slot_idx)
	if selected_slot_index == slot_idx:
		current_place_scene = null
		item_changed.emit(null)
	_sync_to_scene_manager()

	if SceneManager:
		SceneManager.add_gold(price)

	return {"success": true, "gold": price, "name": item_name}

func sell_selected_item() -> Dictionary:
	return sell_item_at_slot(selected_slot_index)

func sell_all_items() -> Dictionary:
	var total_gold: int = 0
	var count: int = 0
	for i in range(inventory_data.size()):
		var data = inventory_data[i]
		if data != null:
			var price: int = get_item_price(data)
			if price > 0:
				total_gold += price
				count += 1
				inventory_data[i] = null
				update_slot_display(i)
				if selected_slot_index == i:
					current_place_scene = null
					item_changed.emit(null)

	if count > 0:
		_sync_to_scene_manager()
		if SceneManager:
			SceneManager.add_gold(total_gold)

	return {"success": count > 0, "gold": total_gold, "count": count}

# ----------------- HỆ THỐNG TRANG BỊ & THUỘC TÍNH (EQUIPMENT & STATS) -----------------
func _setup_equipment_ui() -> void:
	if not bag_window:
		return

	# Mở rộng chiều cao bagwindow để chứa thêm ô trang bị và bảng thuộc tính
	bag_window.offset_top = -180.0
	bag_window.offset_bottom = 175.0
	bag_window.pivot_offset = bag_window.size * 0.5

	# Dời InnerWell và baggrid lên vị trí cân đối
	var inner_well = bag_window.get_node_or_null("InnerWell")
	if inner_well:
		inner_well.offset_top = 34.0
		inner_well.offset_bottom = -118.0

	if bag_grid:
		bag_grid.offset_top = -140.0
		bag_grid.offset_bottom = 38.0

	var hint_lbl = bag_window.get_node_or_null("HintLabel")
	if hint_lbl:
		hint_lbl.offset_top = -24.0
		hint_lbl.offset_bottom = -4.0
		hint_lbl.text = "[E] Inventory | Right-click gear to equip/unequip | Drag & drop to swap"

	if equip_panel and is_instance_valid(equip_panel):
		return

	equip_panel = Panel.new()
	equip_panel.name = "EquipmentPanel"
	equip_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	equip_panel.offset_left = 14.0
	equip_panel.offset_top = -112.0
	equip_panel.offset_right = -14.0
	equip_panel.offset_bottom = -28.0

	var ep_style := StyleBoxFlat.new()
	ep_style.bg_color = Color(0.12, 0.07, 0.04, 0.92)
	ep_style.border_width_left = 2
	ep_style.border_width_top = 2
	ep_style.border_width_right = 2
	ep_style.border_width_bottom = 2
	ep_style.border_color = Color(0.65, 0.44, 0.22, 1.0)
	ep_style.corner_radius_top_left = 6
	ep_style.corner_radius_top_right = 6
	ep_style.corner_radius_bottom_right = 6
	ep_style.corner_radius_bottom_left = 6
	equip_panel.add_theme_stylebox_override("panel", ep_style)
	bag_window.add_child(equip_panel)

	# Tiêu đề khu vực Trang Bị
	var title_lbl := Label.new()
	title_lbl.name = "EquipTitle"
	title_lbl.text = "EQUIPMENT & STATS"
	title_lbl.position = Vector2(14, 6)
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	equip_panel.add_child(title_lbl)

	# 3 ô trang bị: Mũ (Hat), Áo (Shirt), Quần (Pants)
	var slot_defs: Array[Dictionary] = [
		{"type": "hat", "name": "HAT", "pos": Vector2(18, 28)},
		{"type": "shirt", "name": "SHIRT", "pos": Vector2(76, 28)},
		{"type": "pants", "name": "PANTS", "pos": Vector2(134, 28)}
	]

	var slot_tex = load("res://Content T1/New/tool/menu1.png") as Texture2D

	var eq_hover_style := StyleBoxFlat.new()
	eq_hover_style.bg_color = Color(1.0, 0.96, 0.85, 0.1)
	eq_hover_style.border_width_left = 1
	eq_hover_style.border_width_top = 1
	eq_hover_style.border_width_right = 1
	eq_hover_style.border_width_bottom = 1
	eq_hover_style.border_color = Color(0.95, 0.78, 0.45, 0.85)
	eq_hover_style.corner_radius_top_left = 3
	eq_hover_style.corner_radius_top_right = 3
	eq_hover_style.corner_radius_bottom_right = 3
	eq_hover_style.corner_radius_bottom_left = 3

	for sdef in slot_defs:
		var slot_type: String = sdef["type"]
		var slot_box := TextureRect.new()
		slot_box.name = "EquipSlot_" + slot_type.capitalize()
		slot_box.custom_minimum_size = Vector2(44, 44)
		slot_box.size = Vector2(44, 44)
		slot_box.position = sdef["pos"]
		slot_box.texture = slot_tex
		slot_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot_box.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_box.set_meta("is_equip_slot", true)
		slot_box.set_meta("equip_type", slot_type)
		slot_box.set_script(self.get_script())

		# Khung viền khi di chuột (HoverFrame)
		var hover_frame := Panel.new()
		hover_frame.name = "HoverFrame"
		hover_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		hover_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hover_frame.add_theme_stylebox_override("panel", eq_hover_style)
		hover_frame.visible = false
		slot_box.add_child(hover_frame)

		# Nhãn tên loại trang bị mờ gợi ý
		var tag_lbl := Label.new()
		tag_lbl.name = "PlaceholderTag"
		tag_lbl.text = sdef["name"]
		tag_lbl.position = Vector2(0, 12)
		tag_lbl.size = Vector2(44, 20)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag_lbl.add_theme_font_size_override("font_size", 10)
		tag_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 0.45))
		slot_box.add_child(tag_lbl)

		# Icon trang bị khi được lắp vào
		var icon_rect := TextureRect.new()
		icon_rect.name = "EquipIcon"
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 4.0
		icon_rect.offset_top = 4.0
		icon_rect.offset_right = -4.0
		icon_rect.offset_bottom = -4.0
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot_box.add_child(icon_rect)

		# Kết nối sự kiện cho ô trang bị
		slot_box.gui_input.connect(_on_equip_slot_gui_input.bind(slot_type))
		slot_box.mouse_entered.connect(_on_equip_slot_mouse_entered.bind(slot_box))
		slot_box.mouse_exited.connect(_on_equip_slot_mouse_exited.bind(slot_box))

		equip_panel.add_child(slot_box)
		equip_slots[slot_type] = slot_box

	# Vách ngăn dọc mỏng giữa ô trang bị và bảng chỉ số
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.position = Vector2(196, 12)
	divider.size = Vector2(2, 64)
	divider.color = Color(0.55, 0.38, 0.22, 0.6)
	equip_panel.add_child(divider)

	# Bảng thuộc tính nhân vật bên cạnh (Level, HP, Mana, Phòng Thủ, Sát Thương)
	var stats_col := VBoxContainer.new()
	stats_col.name = "StatsContainer"
	stats_col.position = Vector2(212, 10)
	stats_col.size = Vector2(240, 68)
	stats_col.add_theme_constant_override("separation", 2)
	equip_panel.add_child(stats_col)

	var stat_keys := ["level", "hp", "mana", "defense"]
	for sk in stat_keys:
		var stat_lbl := Label.new()
		stat_lbl.name = "Stat_" + sk
		stat_lbl.add_theme_font_size_override("font_size", 11)
		stat_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88, 1.0))
		stat_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
		stat_lbl.add_theme_constant_override("shadow_offset_x", 1)
		stat_lbl.add_theme_constant_override("shadow_offset_y", 1)
		stats_col.add_child(stat_lbl)
		stats_labels[sk] = stat_lbl

	update_stats_display()

func get_item_equip_type(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY or data == null:
		return ""
	var id_str: String = str(data.get("id", "")).to_lower()
	var name_str: String = str(data.get("name", "")).to_lower()
	if id_str.find("hat") != -1 or name_str.find("hat") != -1 or name_str.find("mũ") != -1 or name_str.find("nón") != -1:
		return "hat"
	elif id_str.find("shirt") != -1 or id_str.find("armor") != -1 or name_str.find("shirt") != -1 or name_str.find("áo") != -1 or name_str.find("giáp") != -1:
		return "shirt"
	elif id_str.find("pants") != -1 or name_str.find("pants") != -1 or name_str.find("quần") != -1:
		return "pants"
	return ""

func update_equip_slot_display(slot_type: String) -> void:
	if not equip_slots.has(slot_type):
		return
	var slot_box: TextureRect = equip_slots[slot_type]
	if not is_instance_valid(slot_box):
		return
	var data = equipment_data.get(slot_type)
	var icon_rect = slot_box.get_node_or_null("EquipIcon") as TextureRect
	var tag_lbl = slot_box.get_node_or_null("PlaceholderTag") as Label

	if data != null and typeof(data) == TYPE_DICTIONARY:
		if icon_rect:
			icon_rect.texture = data.get("icon")
			icon_rect.visible = true
		if tag_lbl:
			tag_lbl.visible = false
		var def_val: int = int(data.get("defense", 0))
		slot_box.tooltip_text = "%s\nDefense: +%d\n(Right-click to unequip | Drag to backpack)" % [str(data.get("name", "Equipment")), def_val]
	else:
		if icon_rect:
			icon_rect.texture = null
			icon_rect.visible = false
		if tag_lbl:
			tag_lbl.visible = true
		slot_box.tooltip_text = "Empty %s Slot\n(Drag item here or right-click from backpack)" % slot_type.capitalize()

func update_stats_display() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var level_val: int = 1
	var cur_hp: int = 100
	var max_hp: int = 100
	var cur_mana: float = 100.0
	var max_m: float = 100.0

	if player and is_instance_valid(player):
		if "level" in player:
			level_val = int(player.level)
		elif SceneManager and "saved_player_level" in SceneManager:
			level_val = int(SceneManager.saved_player_level)
		if player.get("health_component"):
			cur_hp = int(player.health_component.current_health)
			max_hp = int(player.health_component.max_health)
		elif "max_health" in player:
			max_hp = int(player.max_health)
			cur_hp = max_hp
		if "current_mana" in player:
			cur_mana = float(player.current_mana)
			max_m = float(player.max_mana)
	elif SceneManager:
		level_val = int(SceneManager.get("saved_player_level")) if SceneManager.get("saved_player_level") != null else 1
		if SceneManager.saved_player_health > 0:
			cur_hp = SceneManager.saved_player_health
		if SceneManager.saved_player_mana >= 0.0:
			cur_mana = SceneManager.saved_player_mana

	var total_defense: int = 0
	for k in equipment_data.keys():
		var eq = equipment_data[k]
		if typeof(eq) == TYPE_DICTIONARY and eq != null:
			total_defense += int(eq.get("defense", 0))

	if stats_labels.has("level") and is_instance_valid(stats_labels["level"]):
		stats_labels["level"].text = "⭐ Level: %d" % level_val
	if stats_labels.has("hp") and is_instance_valid(stats_labels["hp"]):
		stats_labels["hp"].text = "❤️ Health (HP): %d / %d" % [cur_hp, max_hp]
	if stats_labels.has("mana") and is_instance_valid(stats_labels["mana"]):
		stats_labels["mana"].text = "💧 Mana: %d / %d" % [int(cur_mana), int(max_m)]
	if stats_labels.has("defense") and is_instance_valid(stats_labels["defense"]):
		stats_labels["defense"].text = "🛡️ Defense (Armor): +%d Damage Reduction" % total_defense

func equip_item_from_data(slot_type: String, item_data: Dictionary) -> Dictionary:
	var old_item = equipment_data.get(slot_type)
	equipment_data[slot_type] = item_data
	update_equip_slot_display(slot_type)
	update_stats_display()
	_sync_to_scene_manager()

	_show_inventory_notice("Equipped: %s" % str(item_data.get("name", "Equipment")), Color(0.4, 1.0, 0.5, 1.0))
	return old_item if (typeof(old_item) == TYPE_DICTIONARY and old_item != null) else {}

func try_auto_equip_from_slot(idx: int) -> bool:
	if idx < 0 or idx >= inventory_data.size():
		return false
	var item_data = inventory_data[idx]
	if typeof(item_data) != TYPE_DICTIONARY or item_data == null:
		return false
	var slot_type = get_item_equip_type(item_data)
	if slot_type == "":
		return false

	var old_item = equip_item_from_data(slot_type, item_data)
	if old_item.is_empty():
		inventory_data[idx] = null
	else:
		inventory_data[idx] = old_item
	update_slot_display(idx)
	_sync_to_scene_manager()
	return true

func unequip_item_to_slot(slot_type: String, target_slot_idx: int) -> bool:
	var eq = equipment_data.get(slot_type)
	if typeof(eq) != TYPE_DICTIONARY or eq == null:
		return false
	if target_slot_idx < 0 or target_slot_idx >= inventory_data.size():
		return false

	var target_item = inventory_data[target_slot_idx]
	if target_item == null:
		inventory_data[target_slot_idx] = eq
		equipment_data[slot_type] = null
	else:
		var target_equip_type = get_item_equip_type(target_item)
		if target_equip_type == slot_type:
			inventory_data[target_slot_idx] = eq
			equipment_data[slot_type] = target_item
		else:
			return false

	update_slot_display(target_slot_idx)
	update_equip_slot_display(slot_type)
	update_stats_display()
	_sync_to_scene_manager()
	_show_inventory_notice("Unequipped: %s" % str(eq.get("name", "Equipment")), Color(1.0, 0.9, 0.4, 1.0))
	return true

func _on_equip_slot_gui_input(event: InputEvent, slot_type: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed):
			# Click chuột phải để tháo trang bị trở lại balo
			var eq = equipment_data.get(slot_type)
			if typeof(eq) == TYPE_DICTIONARY and eq != null:
				for i in range(inventory_data.size()):
					if inventory_data[i] == null:
						inventory_data[i] = eq
						equipment_data[slot_type] = null
						update_slot_display(i)
						update_equip_slot_display(slot_type)
						update_stats_display()
						_sync_to_scene_manager()
						_show_inventory_notice("Unequipped: %s" % str(eq.get("name", "Equipment")), Color(1.0, 0.9, 0.4, 1.0))
						return
				_show_inventory_notice("Backpack is full! Cannot unequip.", Color(1.0, 0.4, 0.4, 1.0))

func _on_equip_slot_mouse_entered(slot: Control) -> void:
	var hover_frame := slot.get_node_or_null("HoverFrame")
	if hover_frame:
		hover_frame.visible = true
	slot.self_modulate = SLOT_HOVER_COLOR

func _on_equip_slot_mouse_exited(slot: Control) -> void:
	var hover_frame := slot.get_node_or_null("HoverFrame")
	if hover_frame:
		hover_frame.visible = false
	slot.self_modulate = SLOT_NORMAL_COLOR

func _restore_equipment_from_scene_manager() -> void:
	if SceneManager and SceneManager.get("saved_equipment_data") and SceneManager.saved_equipment_data is Dictionary:
		for k in ["hat", "shirt", "pants"]:
			if SceneManager.saved_equipment_data.has(k):
				equipment_data[k] = SceneManager.saved_equipment_data[k]
			update_equip_slot_display(k)
	update_stats_display()

func _give_starter_clothes() -> void:
	var clothes: Array[Dictionary] = [
		# --- 5 MŨ (HATS) ---
		{
			"id": "hat_straw",
			"name": "Farmer Straw Hat",
			"type": "hat",
			"path": "res://Content T1/Character/Player/Hat.png",
			"region": Rect2(1, 4, 18, 9),
			"defense": 3
		},
		{
			"id": "hat_leather",
			"name": "Hunter Leather Cap",
			"type": "hat",
			"path": "res://Content T1/Character/Player/Hat.png",
			"region": Rect2(23, 3, 14, 9),
			"defense": 6
		},
		{
			"id": "hat_iron",
			"name": "Warrior Iron Helm",
			"type": "hat",
			"path": "res://Content T1/Character/Player/Hat.png",
			"region": Rect2(43, 0, 14, 12),
			"defense": 10
		},
		{
			"id": "hat_gold",
			"name": "Royal Gold Crown",
			"type": "hat",
			"path": "res://Content T1/Character/Player/Hat.png",
			"region": Rect2(60, 2, 20, 10),
			"defense": 15
		},
		{
			"id": "hat_amethyst",
			"name": "Amethyst Tiara",
			"type": "hat",
			"path": "res://Content T1/Character/Player/Hat.png",
			"region": Rect2(82, 4, 16, 10),
			"defense": 22
		},

		# --- 5 ÁO / GIÁP (SHIRTS / ARMORS) ---
		{
			"id": "shirt_cloth",
			"name": "Simple Cloth Shirt",
			"type": "shirt",
			"path": "res://Content T1/Character/Player/Shirt.png",
			"region": Rect2(48, 0, 8, 8),
			"defense": 4
		},
		{
			"id": "shirt_leather",
			"name": "Forest Leather Armor",
			"type": "shirt",
			"path": "res://Content T1/Character/Player/Shirt.png",
			"region": Rect2(8, 0, 8, 8),
			"defense": 9
		},
		{
			"id": "shirt_iron",
			"name": "Solid Iron Armor",
			"type": "shirt",
			"path": "res://Content T1/Character/Player/Shirt.png",
			"region": Rect2(80, 0, 8, 8),
			"defense": 16
		},
		{
			"id": "shirt_gold",
			"name": "Golden Armor",
			"type": "shirt",
			"path": "res://Content T1/Character/Player/Shirt.png",
			"region": Rect2(40, 32, 8, 8),
			"defense": 24
		},
		{
			"id": "shirt_amethyst",
			"name": "Amethyst Robe",
			"type": "shirt",
			"path": "res://Content T1/Character/Player/Shirt.png",
			"region": Rect2(64, 64, 8, 8),
			"defense": 35
		},

		# --- 5 QUẦN (PANTS) ---
		{
			"id": "pants_cloth",
			"name": "Work Cloth Pants",
			"type": "pants",
			"path": "res://Content T1/Character/Player/pants.png",
			"region": Rect2(20, 23, 8, 5),
			"defense": 3
		},
		{
			"id": "pants_leather",
			"name": "Explorer Leather Pants",
			"type": "pants",
			"path": "res://Content T1/Character/Player/pants.png",
			"region": Rect2(82, 23, 12, 5),
			"defense": 7
		},
		{
			"id": "pants_iron",
			"name": "Iron Greaves",
			"type": "pants",
			"path": "res://Content T1/Character/Player/pants.png",
			"region": Rect2(4, 85, 8, 8),
			"defense": 12
		},
		{
			"id": "pants_gold",
			"name": "Gilded Plate Pants",
			"type": "pants",
			"path": "res://Content T1/Character/Player/pants.png",
			"region": Rect2(3, 278, 9, 7),
			"defense": 18
		},
		{
			"id": "pants_amethyst",
			"name": "Crystal Amethyst Pants",
			"type": "pants",
			"path": "res://Content T1/Character/Player/pants.png",
			"region": Rect2(52, 243, 8, 9),
			"defense": 26
		}
	]

	# Tự động trang bị 3 món khởi đầu (Mũ Rơm, Áo Vải, Quần Vải) nếu người chơi chưa trang bị
	var default_equips: Dictionary = {
		"hat": "hat_straw",
		"shirt": "shirt_cloth",
		"pants": "pants_cloth"
	}

	for c in clothes:
		var already_exists := false
		var cur_eq = equipment_data.get(c["type"])
		if typeof(cur_eq) == TYPE_DICTIONARY and cur_eq != null and cur_eq.get("id", "") == c["id"]:
			already_exists = true
		if not already_exists:
			for s in inventory_data:
				if typeof(s) == TYPE_DICTIONARY and s != null and s.get("id", "") == c["id"]:
					already_exists = true
					break

		if not already_exists:
			var tex = load(c["path"]) as Texture2D
			if tex:
				var icon := AtlasTexture.new()
				icon.atlas = tex
				icon.region = c["region"]
				var c_data: Dictionary = {
					"id": c["id"],
					"name": c["name"],
					"icon": icon,
					"scene": null,
					"defense": c["defense"]
				}
				# Nếu ô trang bị tương ứng còn trống và đây là món đồ khởi đầu cơ bản -> trang bị luôn
				if equipment_data.get(c["type"]) == null and default_equips.get(c["type"]) == c["id"]:
					equipment_data[c["type"]] = c_data
					update_equip_slot_display(c["type"])
				else:
					add_item(icon, null, c["id"], c["name"], c["defense"])

	update_stats_display()
	_sync_to_scene_manager()

# ----------------- HỆ THỐNG NẤU ĂN (COOKING SYSTEM) -----------------
func _process(delta: float) -> void:
	if not current_cooking_job.is_empty():
		current_cooking_job["remaining"] = maxf(0.0, float(current_cooking_job["remaining"]) - delta)
		var rem: float = current_cooking_job["remaining"]
		var total: float = float(current_cooking_job.get("total", 30.0))
		var progress: float = 1.0 - (rem / total)

		var bar = current_cooking_job.get("pbar") as ProgressBar
		if bar and is_instance_valid(bar):
			bar.value = progress * 100.0

		var btn = current_cooking_job.get("btn") as Button
		if btn and is_instance_valid(btn):
			btn.text = "🔥 %ds" % int(ceil(rem))

		if rem <= 0.0:
			_finish_cooking()

func _setup_cooking_ui() -> void:
	if not bag_window:
		return

	# Tránh tạo trùng lặp nếu UI đã được khởi tạo trước đó
	var existing_tab_bar = bag_window.get_node_or_null("InventoryTabBar")
	if existing_tab_bar:
		existing_tab_bar.queue_free()

	# Tạo 2 nút chuyển Tab ở góc trên của Balo: [🎒 Kho đồ] & [🍳 Nấu ăn]
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "InventoryTabBar"
	tab_bar.position = Vector2(160, 8)
	tab_bar.size = Vector2(230, 26)
	tab_bar.add_theme_constant_override("separation", 6)
	bag_window.add_child(tab_bar)

	var tab_style_active := StyleBoxFlat.new()
	tab_style_active.bg_color = Color(0.38, 0.22, 0.12, 1.0)
	tab_style_active.border_width_left = 2
	tab_style_active.border_width_top = 2
	tab_style_active.border_width_right = 2
	tab_style_active.border_width_bottom = 2
	tab_style_active.border_color = Color(1.0, 0.82, 0.35, 1.0)
	tab_style_active.corner_radius_top_left = 5
	tab_style_active.corner_radius_top_right = 5
	tab_style_active.corner_radius_bottom_right = 5
	tab_style_active.corner_radius_bottom_left = 5

	var tab_style_normal := StyleBoxFlat.new()
	tab_style_normal.bg_color = Color(0.18, 0.11, 0.06, 0.85)
	tab_style_normal.border_width_left = 1
	tab_style_normal.border_width_top = 1
	tab_style_normal.border_width_right = 1
	tab_style_normal.border_width_bottom = 1
	tab_style_normal.border_color = Color(0.55, 0.38, 0.22, 0.8)
	tab_style_normal.corner_radius_top_left = 5
	tab_style_normal.corner_radius_top_right = 5
	tab_style_normal.corner_radius_bottom_right = 5
	tab_style_normal.corner_radius_bottom_left = 5

	inventory_tab_btn = Button.new()
	inventory_tab_btn.name = "InventoryTabBtn"
	inventory_tab_btn.text = "🎒 Inventory"
	inventory_tab_btn.custom_minimum_size = Vector2(100, 24)
	inventory_tab_btn.add_theme_font_size_override("font_size", 11)
	inventory_tab_btn.add_theme_stylebox_override("normal", tab_style_active)
	if not inventory_tab_btn.pressed.is_connected(_on_inventory_tab_pressed):
		inventory_tab_btn.pressed.connect(_on_inventory_tab_pressed)
	tab_bar.add_child(inventory_tab_btn)

	cooking_tab_btn = Button.new()
	cooking_tab_btn.name = "CookingTabBtn"
	cooking_tab_btn.text = "🍳 Cooking"
	cooking_tab_btn.custom_minimum_size = Vector2(100, 24)
	cooking_tab_btn.add_theme_font_size_override("font_size", 11)
	cooking_tab_btn.add_theme_stylebox_override("normal", tab_style_normal)
	if not cooking_tab_btn.pressed.is_connected(_on_cooking_tab_pressed):
		cooking_tab_btn.pressed.connect(_on_cooking_tab_pressed)
	tab_bar.add_child(cooking_tab_btn)

	# Nút Hướng dẫn phím chơi (Controls Guide Button) nằm ở cạnh bên phải của Inventory
	var existing_guide_btn = bag_window.get_node_or_null("GuideSideBtn")
	if existing_guide_btn:
		existing_guide_btn.queue_free()

	guide_side_btn = Button.new()
	guide_side_btn.name = "GuideSideBtn"
	guide_side_btn.text = "📖 Controls"
	guide_side_btn.custom_minimum_size = Vector2(88, 30)
	guide_side_btn.position = Vector2(496, 40) # Nằm ngay sát mép ngoài bên phải của bag_window (rộng 496px)
	guide_side_btn.add_theme_font_size_override("font_size", 11)

	var gbtn_style := StyleBoxFlat.new()
	gbtn_style.bg_color = Color(0.18, 0.11, 0.06, 0.94)
	gbtn_style.border_width_left = 2
	gbtn_style.border_width_top = 2
	gbtn_style.border_width_right = 2
	gbtn_style.border_width_bottom = 2
	gbtn_style.border_color = Color(0.95, 0.78, 0.38, 1.0)
	gbtn_style.corner_radius_top_left = 0
	gbtn_style.corner_radius_bottom_left = 0
	gbtn_style.corner_radius_top_right = 6
	gbtn_style.corner_radius_bottom_right = 6
	guide_side_btn.add_theme_stylebox_override("normal", gbtn_style)
	guide_side_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6, 1.0))
	if not guide_side_btn.pressed.is_connected(_on_guide_side_btn_pressed):
		guide_side_btn.pressed.connect(_on_guide_side_btn_pressed)
	bag_window.add_child(guide_side_btn)

	_setup_guide_modal()

	# Panel giao diện Nấu Ăn (chiếm toàn bộ vùng giữa của Balo khi bật)
	if cooking_panel and is_instance_valid(cooking_panel):
		return
	cooking_panel = Panel.new()
	cooking_panel.name = "CookingPanel"
	cooking_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooking_panel.offset_left = 14.0
	cooking_panel.offset_top = 38.0
	cooking_panel.offset_right = -14.0
	cooking_panel.offset_bottom = -28.0

	var cp_style := StyleBoxFlat.new()
	cp_style.bg_color = Color(0.14, 0.08, 0.05, 0.96)
	cp_style.border_width_left = 2
	cp_style.border_width_top = 2
	cp_style.border_width_right = 2
	cp_style.border_width_bottom = 2
	cp_style.border_color = Color(0.65, 0.44, 0.22, 1.0)
	cp_style.corner_radius_top_left = 6
	cp_style.corner_radius_top_right = 6
	cp_style.corner_radius_bottom_right = 6
	cp_style.corner_radius_bottom_left = 6
	cooking_panel.add_theme_stylebox_override("panel", cp_style)
	cooking_panel.visible = false
	bag_window.add_child(cooking_panel)

	# Tiêu đề & mô tả công thức nấu
	var c_title := Label.new()
	c_title.text = "🍳 KITCHEN - RECIPES & COOKING (30s)"
	c_title.position = Vector2(16, 8)
	c_title.add_theme_font_size_override("font_size", 11)
	c_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	cooking_panel.add_child(c_title)

	cooking_status_lbl = Label.new()
	cooking_status_lbl.name = "CookingStatusLbl"
	cooking_status_lbl.position = Vector2(16, 26)
	cooking_status_lbl.size = Vector2(430, 18)
	cooking_status_lbl.add_theme_font_size_override("font_size", 9)
	cooking_status_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	cooking_status_lbl.text = "Select a dish to cook. When finished, it will be placed in your inventory. Right-click to consume!"
	cooking_panel.add_child(cooking_status_lbl)

	# ScrollContainer chứa danh sách món ăn
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 48)
	scroll.size = Vector2(444, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cooking_panel.add_child(scroll)

	cooking_recipes_vbox = VBoxContainer.new()
	cooking_recipes_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cooking_recipes_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(cooking_recipes_vbox)

	_render_cooking_recipes()

func _on_inventory_tab_pressed() -> void:
	is_cooking_view = false
	if cooking_panel:
		cooking_panel.visible = false
	if bag_grid:
		bag_grid.visible = true
	if equip_panel:
		equip_panel.visible = true

	var inner_well := bag_window.get_node_or_null("InnerWell")
	if inner_well:
		inner_well.visible = true
	var hint_lbl := bag_window.get_node_or_null("HintLabel")
	if hint_lbl:
		hint_lbl.visible = true

	_update_tab_buttons_appearance()

func _setup_guide_modal() -> void:
	if guide_modal and is_instance_valid(guide_modal):
		return

	guide_modal = Panel.new()
	guide_modal.name = "GuideModal"
	guide_modal.custom_minimum_size = Vector2(250, 270)
	guide_modal.size = Vector2(250, 270)
	guide_modal.position = Vector2(502, 40) # Mở ngay bên phải ngoài balo (bên cạnh nút Controls)
	guide_modal.visible = false

	var gm_style := StyleBoxFlat.new()
	gm_style.bg_color = Color(0.13, 0.08, 0.05, 0.96)
	gm_style.border_width_left = 2
	gm_style.border_width_top = 2
	gm_style.border_width_right = 2
	gm_style.border_width_bottom = 2
	gm_style.border_color = Color(0.95, 0.78, 0.38, 1.0)
	gm_style.corner_radius_top_left = 8
	gm_style.corner_radius_bottom_left = 8
	gm_style.corner_radius_top_right = 8
	gm_style.corner_radius_bottom_right = 8
	guide_modal.add_theme_stylebox_override("panel", gm_style)
	bag_window.add_child(guide_modal)

	# Tiêu đề bảng Hướng Dẫn
	var title := Label.new()
	title.text = "📖 GAME CONTROLS"
	title.position = Vector2(14, 8)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	guide_modal.add_child(title)

	# Nút đóng Hướng Dẫn (X)
	var close_gbtn := Button.new()
	close_gbtn.text = "✕"
	close_gbtn.custom_minimum_size = Vector2(22, 22)
	close_gbtn.position = Vector2(220, 6)
	close_gbtn.add_theme_font_size_override("font_size", 11)
	close_gbtn.pressed.connect(func(): guide_modal.visible = false)
	guide_modal.add_child(close_gbtn)

	# Nội dung các phím điều khiển
	var content_lbl := Label.new()
	content_lbl.position = Vector2(14, 34)
	content_lbl.size = Vector2(222, 226)
	content_lbl.add_theme_font_size_override("font_size", 10)
	content_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
	content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var lines_arr: Array[String] = [
		"• WASD / Arrow Keys: Move",
		"• Shift / Space: Roll / Dash",
		"• Left Click: Attack / Use Tool",
		"• Right Click: Special Skill",
		"• 1 - 9 Keys: Quickbar Hotkeys",
		"• E Key: Open / Close Bag",
		"• F Key: Interact / Open Chest",
		"• Right Click Item: Eat / Drink",
		"• Drag & Drop: Move / Swap Items"
	]
	content_lbl.text = "\n".join(lines_arr)
	guide_modal.add_child(content_lbl)

func _on_guide_side_btn_pressed() -> void:
	if not guide_modal:
		_setup_guide_modal()
	guide_modal.visible = !guide_modal.visible
	is_cooking_view = false
	if cooking_panel:
		cooking_panel.visible = false
	if bag_grid:
		bag_grid.visible = true
	if equip_panel:
		equip_panel.visible = true

	var inner_well := bag_window.get_node_or_null("InnerWell")
	if inner_well:
		inner_well.visible = true
	var hint_lbl := bag_window.get_node_or_null("HintLabel")
	if hint_lbl:
		hint_lbl.visible = true

	_update_tab_buttons_appearance()

func _on_cooking_tab_pressed() -> void:
	is_cooking_view = true
	if cooking_panel:
		cooking_panel.visible = true
	if bag_grid:
		bag_grid.visible = false
	if equip_panel:
		equip_panel.visible = false

	var inner_well := bag_window.get_node_or_null("InnerWell")
	if inner_well:
		inner_well.visible = false
	var hint_lbl := bag_window.get_node_or_null("HintLabel")
	if hint_lbl:
		hint_lbl.visible = false

	_update_tab_buttons_appearance()
	_render_cooking_recipes()

func _update_tab_buttons_appearance() -> void:
	var active_col := Color(1.0, 0.85, 0.35, 1.0)
	var inactive_col := Color(0.75, 0.7, 0.65, 0.75)
	if inventory_tab_btn:
		inventory_tab_btn.add_theme_color_override("font_color", active_col if not is_cooking_view else inactive_col)
	if cooking_tab_btn:
		cooking_tab_btn.add_theme_color_override("font_color", active_col if is_cooking_view else inactive_col)

# Hiển thị danh sách công thức nấu ăn
func _render_cooking_recipes() -> void:
	if not cooking_recipes_vbox:
		return

	for child in cooking_recipes_vbox.get_children():
		child.queue_free()

	for recipe in COOKING_RECIPES:
		var row := _create_recipe_ui_row(recipe)
		cooking_recipes_vbox.add_child(row)

func _create_recipe_ui_row(recipe: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 42)

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.2, 0.12, 0.08, 0.9)
	p_style.border_width_left = 1
	p_style.border_width_top = 1
	p_style.border_width_right = 1
	p_style.border_width_bottom = 1
	p_style.border_color = Color(0.45, 0.32, 0.18, 0.9)
	p_style.corner_radius_top_left = 4
	p_style.corner_radius_top_right = 4
	p_style.corner_radius_bottom_right = 4
	p_style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", p_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Icon món ăn
	var icon_box := TextureRect.new()
	icon_box.custom_minimum_size = Vector2(32, 32)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = load(str(recipe.get("atlas_path", "res://Content T1/Loose/Fish-food.png"))) as Texture2D
	atlas_tex.region = recipe.get("region", Rect2(0, 0, 16, 16))
	icon_box.texture = atlas_tex
	hbox.add_child(icon_box)

	# Thông tin chi tiết món ăn (Tên, hồi máu, nguyên liệu cần)
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = "%s  [+ %d HP]" % [str(recipe["name"]), int(recipe["heal_amount"])]
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6, 1.0))
	info_vbox.add_child(name_lbl)

	# Liệt kê nguyên liệu yêu cầu & số lượng người chơi đang có
	var req_text := "Needs: "
	var ingredients: Dictionary = recipe.get("ingredients", {})
	var can_cook: bool = true
	var ing_parts: Array[String] = []

	for ing_id in ingredients.keys():
		var need_count: int = int(ingredients[ing_id])
		var current_count: int = _count_item_in_inventory(ing_id)
		var ing_name := _get_friendly_ingredient_name(ing_id)
		ing_parts.append("%s (%d/%d)" % [ing_name, current_count, need_count])
		if current_count < need_count:
			can_cook = false

	req_text += " + ".join(ing_parts)
	var ing_lbl := Label.new()
	ing_lbl.text = req_text
	ing_lbl.add_theme_font_size_override("font_size", 9)
	ing_lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8, 1.0) if can_cook else Color(1.0, 0.5, 0.5, 1.0))
	info_vbox.add_child(ing_lbl)

	# Thanh tiến trình nấu (ProgressBar) nếu món này đang được nấu
	var is_this_cooking: bool = (not current_cooking_job.is_empty() and current_cooking_job.get("recipe", {}).get("id") == recipe["id"])
	var pbar := ProgressBar.new()
	pbar.custom_minimum_size = Vector2(80, 12)
	pbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pbar.show_percentage = false
	pbar.visible = is_this_cooking
	hbox.add_child(pbar)

	# Nút hành động "Nấu"
	var cook_btn := Button.new()
	cook_btn.custom_minimum_size = Vector2(75, 26)
	cook_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cook_btn.add_theme_font_size_override("font_size", 10)

	if is_this_cooking:
		cook_btn.text = "🔥 %ds" % int(ceil(float(current_cooking_job.get("remaining", 30.0))))
		cook_btn.disabled = true
		current_cooking_job["pbar"] = pbar
		current_cooking_job["btn"] = cook_btn
	elif not current_cooking_job.is_empty():
		cook_btn.text = "Busy"
		cook_btn.disabled = true
	else:
		cook_btn.text = "🍳 Cook (30s)"
		cook_btn.disabled = not can_cook
		cook_btn.pressed.connect(_on_start_cooking_pressed.bind(recipe, pbar, cook_btn))

	hbox.add_child(cook_btn)
	return panel

func _on_start_cooking_pressed(recipe: Dictionary, pbar: ProgressBar, btn: Button) -> void:
	if not current_cooking_job.is_empty():
		_show_inventory_notice("The stove is currently busy!", Color(1.0, 0.6, 0.4, 1.0))
		return

	# Kiểm tra lại túi đồ còn đủ nguyên liệu không
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for ing_id in ingredients.keys():
		var need_count: int = int(ingredients[ing_id])
		if _count_item_in_inventory(ing_id) < need_count:
			_show_inventory_notice("Not enough ingredients to cook %s!" % str(recipe["name"]), Color(1.0, 0.4, 0.4, 1.0))
			return

	# Kiểm tra túi còn ô trống nhận món ăn không
	if not _has_empty_slot():
		_show_inventory_notice("Inventory is full! Free up a slot first.", Color(1.0, 0.4, 0.4, 1.0))
		return

	# Trừ nguyên liệu khỏi túi đồ
	for ing_id in ingredients.keys():
		_consume_items_from_inventory(ing_id, int(ingredients[ing_id]))

	var cook_time: float = float(recipe.get("cook_time", 30.0))
	current_cooking_job = {
		"recipe": recipe,
		"remaining": cook_time,
		"total": cook_time,
		"pbar": pbar,
		"btn": btn
	}

	pbar.visible = true
	pbar.value = 0.0
	btn.disabled = true
	btn.text = "🔥 %ds" % int(cook_time)

	if cooking_status_lbl:
		cooking_status_lbl.text = "🔥 Cooking %s... Please wait!" % str(recipe["name"])
		cooking_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25, 1.0))

	_show_inventory_notice("Started cooking %s! Takes 30 seconds." % str(recipe["name"]), Color(1.0, 0.9, 0.3, 1.0))
	_render_cooking_recipes()

func _finish_cooking() -> void:
	if current_cooking_job.is_empty():
		return
	var recipe: Dictionary = current_cooking_job["recipe"]
	current_cooking_job.clear()

	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = load(str(recipe.get("atlas_path", "res://Content T1/Loose/Fish-food.png"))) as Texture2D
	atlas_tex.region = recipe.get("region", Rect2(0, 0, 16, 16))

	# Tạo item thức ăn thêm vào túi đồ
	var food_id: String = str(recipe.get("id"))
	var food_name: String = str(recipe.get("name"))
	var heal_hp: int = int(recipe.get("heal_amount", 50))
	var price_val: int = int(recipe.get("price", 40))

	var added := false
	for i in range(inventory_data.size()):
		if inventory_data[i] == null:
			inventory_data[i] = {
				"id": food_id,
				"name": food_name,
				"icon": atlas_tex,
				"scene": null,
				"is_food": true,
				"heal_amount": heal_hp,
				"price": price_val
			}
			update_slot_display(i)
			added = true
			break

	if not added:
		add_item(atlas_tex, null, food_id, food_name)

	_sync_to_scene_manager()

	if cooking_status_lbl:
		cooking_status_lbl.text = "✨ Finished cooking %s! Placed in your Inventory." % food_name
		cooking_status_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1.0))

	_show_inventory_notice("🍳 Cooked: %s! Added to inventory." % food_name, Color(0.4, 1.0, 0.5, 1.0))
	_render_cooking_recipes()

func _has_empty_slot() -> bool:
	for slot in inventory_data:
		if slot == null:
			return true
	return false

func _count_item_in_inventory(target_id: String) -> int:
	var count: int = 0
	for item in inventory_data:
		if typeof(item) == TYPE_DICTIONARY and item != null:
			var i_id: String = str(item.get("id", ""))
			var i_name: String = str(item.get("name", "")).to_lower()
			if i_id == target_id:
				count += 1
			elif target_id == "fish" and (i_id.begins_with("fish_") or "fish" in i_name or "cá" in i_name):
				count += 1
			elif target_id == "pork" and (i_id == "pork" or "pork" in i_name or "thịt" in i_name):
				count += 1
			elif target_id == "egg" and (i_id == "egg" or "egg" in i_name or "trứng" in i_name):
				count += 1
	return count

func _consume_items_from_inventory(target_id: String, amount: int) -> void:
	var needed: int = amount
	for i in range(inventory_data.size()):
		var item = inventory_data[i]
		if typeof(item) == TYPE_DICTIONARY and item != null:
			var i_id: String = str(item.get("id", ""))
			var i_name: String = str(item.get("name", "")).to_lower()
			var match_item: bool = false
			if i_id == target_id:
				match_item = true
			elif target_id == "fish" and (i_id.begins_with("fish_") or "fish" in i_name or "cá" in i_name):
				match_item = true
			elif target_id == "pork" and (i_id == "pork" or "pork" in i_name or "thịt" in i_name):
				match_item = true
			elif target_id == "egg" and (i_id == "egg" or "egg" in i_name or "trứng" in i_name):
				match_item = true

			if match_item:
				inventory_data[i] = null
				update_slot_display(i)
				needed -= 1
				if needed <= 0:
					break
	_sync_to_scene_manager()

func _get_friendly_ingredient_name(ing_id: String) -> String:
	match ing_id:
		"egg": return "Egg"
		"cow_milk": return "Cow Milk"
		"goat_milk": return "Goat Milk"
		"pork": return "Pork"
		"fish": return "Fresh Fish"
		"fish_salmon": return "Salmon"
		"fish_crab": return "Crab"
		"fish_shrimp": return "Shrimp"
		_: return ing_id.capitalize()

# Consume food or drink milk to restore health (Right-click in inventory)
func try_eat_food_from_slot(idx: int) -> bool:
	if idx < 0 or idx >= inventory_data.size():
		return false
	var data = inventory_data[idx]
	if typeof(data) != TYPE_DICTIONARY or data == null:
		return false

	var heal_val: int = int(data.get("heal_amount", 0))
	var item_id_str: String = str(data.get("id", ""))
	var item_name: String = str(data.get("name", "")).to_lower()
	var is_drink: bool = false

	# Uống trực tiếp sữa bò hoặc sữa dê
	if item_id_str == "cow_milk" or "sữa bò" in item_name or "cow milk" in item_name or "milk" in item_name:
		heal_val = 20
		is_drink = true
	elif item_id_str == "goat_milk" or "sữa dê" in item_name or "goat milk" in item_name:
		heal_val = 25
		is_drink = true

	# Nhận diện nếu là món ăn đã nấu
	if heal_val <= 0:
		for r in COOKING_RECIPES:
			if r["id"] == item_id_str:
				heal_val = int(r["heal_amount"])
				break

	if heal_val <= 0:
		return false

	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return false

	var hp_comp: HealthComponent = player.get("health_component")
	if not hp_comp:
		return false

	if hp_comp.current_health >= hp_comp.max_health:
		_show_inventory_notice("Health is already full, cannot %s!" % ("drink" if is_drink else "eat"), Color(1.0, 0.8, 0.4, 1.0))
		return true

	# Thực hiện hồi máu
	hp_comp.heal(heal_val)

	# Xóa 1 phần ăn / bình sữa khỏi túi đồ
	inventory_data[idx] = null
	update_slot_display(idx)
	if idx == selected_slot_index:
		current_place_scene = null
		item_changed.emit(null)
	_sync_to_scene_manager()

	# Hiệu ứng thông báo ăn món ăn / uống sữa
	var food_display_name: String = str(data.get("name", "Item"))
	if is_drink:
		_show_inventory_notice("Drank %s (+%d HP) 🥛" % [food_display_name, heal_val], Color(0.4, 0.9, 1.0, 1.0))
	else:
		_show_inventory_notice("Yum! Ate %s (+%d HP) ❤️" % [food_display_name, heal_val], Color(0.4, 1.0, 0.5, 1.0))

	_create_eating_floating_indicator(player, heal_val)
	update_stats_display()
	return true

func _create_eating_floating_indicator(player: Node2D, heal_amount: int) -> void:
	if not player or not is_instance_valid(player):
		return
	var lbl := Label.new()
	lbl.text = "+%d HP" % heal_amount
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.3, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = player.global_position + Vector2(-20, -32)
	player.get_parent().add_child(lbl)

	var tween := lbl.create_tween().set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 24.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.2)
	await tween.finished
	if is_instance_valid(lbl):
		lbl.queue_free()
