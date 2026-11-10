extends CharacterBody2D

# NPC Thợ Rèn (Blacksmith NPC) đặt tại Farm House 2
# Cho phép chế tạo Vũ khí & Dụng cụ & Trang bị từ nguyên liệu:
# - Đồ Gỗ (Wood): 20 Gỗ (branch)
# - Đồ Đá (Stone): 20 Gỗ (branch) + 20 Đá (stone)
# - Đồ Đồng (Copper): 20 Gỗ (branch) + 20 Quặng đồng (copper_ore)
# - Đồ Sắt (Iron): 20 Gỗ (branch) + 20 Quặng sắt (iron_ore)
# - Đồ Vàng (Gold): 20 Gỗ (branch) + 20 Quặng vàng (gold_ore)
# - Đồ Tím (Amethyst): 20 Gỗ (branch) + 20 Đá tím (amethyst_gem)

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var interact_area: Area2D = get_node_or_null("Area2D")

var overhead_label: Label = null
var blacksmith_ui: CanvasLayer = null
var craft_panel: Panel = null
var recipe_scroll: ScrollContainer = null
var recipe_list_container: VBoxContainer = null
var status_label: Label = null
var player_nearby: bool = false
var is_ui_open: bool = false

# Danh mục công thức chế tạo (Crafting Recipes)
const CRAFTING_RECIPES: Array[Dictionary] = [
	# --- VŨ KHÍ & DỤNG CỤ GỖ (20 Gỗ) ---
	{
		"id": "wood_bow",
		"name": "Wooden Bow",
		"category": "Wood (Tier 1)",
		"atlas_path": "res://Content T1/Tilesheet/Weapon1_tilet.png",
		"region": Rect2(48, 64, 16, 16),
		"scene_path": "res://scenes/objects/wood_bow_item.tscn",
		"cost": {"branch": 20},
		"cost_desc": "20 Wood Branch"
	},
	{
		"id": "wood_spear",
		"name": "Wooden Spear",
		"category": "Wood (Tier 1)",
		"atlas_path": "res://Content T1/Tilesheet/Weapon1_tilet.png",
		"region": Rect2(48, 32, 16, 16),
		"scene_path": "res://scenes/objects/wood_spear_item.tscn",
		"cost": {"branch": 20},
		"cost_desc": "20 Wood Branch"
	},
	{
		"id": "wood_pickaxe",
		"name": "Wooden Pickaxe",
		"category": "Wood (Tier 1)",
		"atlas_path": "res://Content T1/Tilesheet/Tools1_tilet.png",
		"region": Rect2(80, 16, 16, 16),
		"scene_path": "res://scenes/objects/wood_pickaxe_item.tscn",
		"cost": {"branch": 20},
		"cost_desc": "20 Wood Branch"
	},
	{
		"id": "wood_axe",
		"name": "Wooden Axe",
		"category": "Wood (Tier 1)",
		"atlas_path": "res://Content T1/Tilesheet/Tools1_tilet.png",
		"region": Rect2(80, 80, 16, 16),
		"scene_path": "res://scenes/objects/wood_axe_item.tscn",
		"cost": {"branch": 20},
		"cost_desc": "20 Wood Branch"
	},

	# --- VŨ KHÍ & DỤNG CỤ ĐÁ (20 Gỗ + 20 Đá) ---
	{
		"id": "stone_pickaxe",
		"name": "Stone Pickaxe",
		"category": "Stone (Tier 2)",
		"atlas_path": "res://Content T1/Tilesheet/Tools1_tilet.png",
		"region": Rect2(80, 48, 16, 16),
		"scene_path": "res://scenes/objects/stone_pickaxe_item.tscn",
		"cost": {"branch": 20, "stone": 20},
		"cost_desc": "20 Wood Branch + 20 Stone"
	},
	{
		"id": "stone_axe",
		"name": "Stone Axe",
		"category": "Stone (Tier 2)",
		"atlas_path": "res://Content T1/Tilesheet/Tools1_tilet.png",
		"region": Rect2(80, 112, 16, 16),
		"scene_path": "res://scenes/objects/stone_axe_item.tscn",
		"cost": {"branch": 20, "stone": 20},
		"cost_desc": "20 Wood Branch + 20 Stone"
	},

	# --- VŨ KHÍ & DỤNG CỤ ĐỒNG (20 Gỗ + 20 Quặng Đồng) ---
	{
		"id": "copper_bow",
		"name": "Copper Bow",
		"category": "Copper (Tier 3)",
		"atlas_path": "res://Content T1/Tilesheet/Weapon1_tilet.png",
		"region": Rect2(80, 64, 16, 16),
		"scene_path": "res://scenes/objects/copper_bow_item.tscn",
		"cost": {"branch": 20, "copper_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Copper Ore"
	},
	{
		"id": "copper_spear",
		"name": "Copper Spear",
		"category": "Copper (Tier 3)",
		"atlas_path": "res://Content T1/Tilesheet/Weapon1_tilet.png",
		"region": Rect2(80, 32, 16, 16),
		"scene_path": "res://scenes/objects/copper_spear_item.tscn",
		"cost": {"branch": 20, "copper_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Copper Ore"
	},

	# --- VŨ KHÍ & DỤNG CỤ SẮT (20 Gỗ + 20 Quặng Sắt) ---
	{
		"id": "iron_bow",
		"name": "Iron Bow",
		"category": "Iron (Tier 4)",
		"atlas_path": "res://Content T1/Tilesheet/Weapon1_tilet.png",
		"region": Rect2(64, 64, 16, 16),
		"scene_path": "res://scenes/objects/iron_bow_item.tscn",
		"cost": {"branch": 20, "iron_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Iron Ore"
	},
	{
		"id": "iron_spear",
		"name": "Iron Spear",
		"category": "Iron (Tier 4)",
		"atlas_path": "res://Content T1/Tilesheet/Weapon1_tilet.png",
		"region": Rect2(64, 32, 16, 16),
		"scene_path": "res://scenes/objects/iron_spear_item.tscn",
		"cost": {"branch": 20, "iron_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Iron Ore"
	},
	{
		"id": "iron_pickaxe",
		"name": "Iron Pickaxe",
		"category": "Iron (Tier 4)",
		"atlas_path": "res://Content T1/Tilesheet/Tools1_tilet.png",
		"region": Rect2(192, 16, 16, 16),
		"scene_path": "res://scenes/objects/iron_pickaxe_item.tscn",
		"cost": {"branch": 20, "iron_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Iron Ore"
	},
	{
		"id": "iron_axe",
		"name": "Iron Axe",
		"category": "Iron (Tier 4)",
		"atlas_path": "res://Content T1/Tilesheet/Tools1_tilet.png",
		"region": Rect2(192, 80, 16, 16),
		"scene_path": "res://scenes/objects/iron_axe_item.tscn",
		"cost": {"branch": 20, "iron_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Iron Ore"
	},
	{
		"id": "hat_iron",
		"name": "Warrior Iron Helm (+10 Def)",
		"category": "Iron Armor (Tier 4)",
		"atlas_path": "res://Content T1/Character/Player/Hat.png",
		"region": Rect2(43, 0, 14, 12),
		"scene_path": "",
		"defense": 10,
		"cost": {"branch": 20, "iron_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Iron Ore"
	},
	{
		"id": "shirt_iron",
		"name": "Solid Iron Armor (+16 Def)",
		"category": "Iron Armor (Tier 4)",
		"atlas_path": "res://Content T1/Character/Player/Shirt.png",
		"region": Rect2(80, 0, 8, 8),
		"scene_path": "",
		"defense": 16,
		"cost": {"branch": 20, "iron_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Iron Ore"
	},
	{
		"id": "pants_iron",
		"name": "Iron Greaves (+12 Def)",
		"category": "Iron Armor (Tier 4)",
		"atlas_path": "res://Content T1/Character/Player/pants.png",
		"region": Rect2(4, 85, 8, 8),
		"scene_path": "",
		"defense": 12,
		"cost": {"branch": 20, "iron_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Iron Ore"
	},

	# --- VŨ KHÍ & TRANG BỊ VÀNG (20 Gỗ + 20 Quặng Vàng) ---
	{
		"id": "gold_bow",
		"name": "Gold Bow",
		"category": "Gold (Tier 5)",
		"atlas_path": "res://Content T1/Tilesheet/Weapon1_tilet.png",
		"region": Rect2(96, 64, 16, 16),
		"scene_path": "res://scenes/objects/gold_bow_item.tscn",
		"cost": {"branch": 20, "gold_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Gold Ore"
	},
	{
		"id": "gold_spear",
		"name": "Gold Spear",
		"category": "Gold (Tier 5)",
		"atlas_path": "res://Content T1/Tilesheet/Weapon1_tilet.png",
		"region": Rect2(96, 32, 16, 16),
		"scene_path": "res://scenes/objects/gold_spear_item.tscn",
		"cost": {"branch": 20, "gold_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Gold Ore"
	},
	{
		"id": "hat_gold",
		"name": "Royal Gold Crown (+15 Def)",
		"category": "Gold Armor (Tier 5)",
		"atlas_path": "res://Content T1/Character/Player/Hat.png",
		"region": Rect2(60, 2, 20, 10),
		"scene_path": "",
		"defense": 15,
		"cost": {"branch": 20, "gold_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Gold Ore"
	},
	{
		"id": "shirt_gold",
		"name": "Golden Armor (+24 Def)",
		"category": "Gold Armor (Tier 5)",
		"atlas_path": "res://Content T1/Character/Player/Shirt.png",
		"region": Rect2(40, 32, 8, 8),
		"scene_path": "",
		"defense": 24,
		"cost": {"branch": 20, "gold_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Gold Ore"
	},
	{
		"id": "pants_gold",
		"name": "Gilded Plate Pants (+18 Def)",
		"category": "Gold Armor (Tier 5)",
		"atlas_path": "res://Content T1/Character/Player/pants.png",
		"region": Rect2(3, 278, 9, 7),
		"scene_path": "",
		"defense": 18,
		"cost": {"branch": 20, "gold_ore": 20},
		"cost_desc": "20 Wood Branch + 20 Gold Ore"
	},

	# --- VŨ KHÍ & TRANG BỊ ĐÁ TÍM (20 Gỗ + 20 Đá Tím) ---
	{
		"id": "amethyst_bow",
		"name": "Amethyst Bow",
		"category": "Amethyst (Tier 6)",
		"atlas_path": "res://Content T1/Tilesheet/Weapon1_tilet.png",
		"region": Rect2(112, 64, 16, 16),
		"scene_path": "res://scenes/objects/amethyst_bow_item.tscn",
		"cost": {"branch": 20, "amethyst_gem": 20},
		"cost_desc": "20 Wood Branch + 20 Amethyst"
	},
	{
		"id": "amethyst_spear",
		"name": "Amethyst Spear",
		"category": "Amethyst (Tier 6)",
		"atlas_path": "res://Content T1/Tilesheet/Weapon1_tilet.png",
		"region": Rect2(112, 32, 16, 16),
		"scene_path": "res://scenes/objects/amethyst_spear_item.tscn",
		"cost": {"branch": 20, "amethyst_gem": 20},
		"cost_desc": "20 Wood Branch + 20 Amethyst"
	},
	{
		"id": "hat_amethyst",
		"name": "Amethyst Tiara (+22 Def)",
		"category": "Amethyst Armor (Tier 6)",
		"atlas_path": "res://Content T1/Character/Player/Hat.png",
		"region": Rect2(82, 4, 16, 10),
		"scene_path": "",
		"defense": 22,
		"cost": {"branch": 20, "amethyst_gem": 20},
		"cost_desc": "20 Wood Branch + 20 Amethyst"
	},
	{
		"id": "shirt_amethyst",
		"name": "Amethyst Robe (+35 Def)",
		"category": "Amethyst Armor (Tier 6)",
		"atlas_path": "res://Content T1/Character/Player/Shirt.png",
		"region": Rect2(64, 64, 8, 8),
		"scene_path": "",
		"defense": 35,
		"cost": {"branch": 20, "amethyst_gem": 20},
		"cost_desc": "20 Wood Branch + 20 Amethyst"
	},
	{
		"id": "pants_amethyst",
		"name": "Crystal Amethyst Pants (+26 Def)",
		"category": "Amethyst Armor (Tier 6)",
		"atlas_path": "res://Content T1/Character/Player/pants.png",
		"region": Rect2(52, 243, 8, 9),
		"scene_path": "",
		"defense": 26,
		"cost": {"branch": 20, "amethyst_gem": 20},
		"cost_desc": "20 Wood Branch + 20 Amethyst"
	}
]

func _ready() -> void:
	add_to_group("npc")
	add_to_group("blacksmith")
	y_sort_enabled = true

	if anim:
		anim.play("idle")

	_setup_overhead_ui()
	_setup_crafting_ui()

	if interact_area:
		interact_area.body_entered.connect(_on_area_body_entered)
		interact_area.body_exited.connect(_on_area_body_exited)
		interact_area.input_event.connect(_on_area_input_event)

func _setup_overhead_ui() -> void:
	overhead_label = Label.new()
	overhead_label.name = "BlacksmithOverhead"
	overhead_label.text = "Blacksmith (Craft Weapons & Armor)"
	overhead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overhead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overhead_label.position = Vector2(-120, -42)
	overhead_label.size = Vector2(240, 20)
	overhead_label.z_index = 25
	overhead_label.add_theme_font_size_override("font_size", 10)
	overhead_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	overhead_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 1.0))
	overhead_label.add_theme_constant_override("outline_size", 3)
	add_child(overhead_label)

func _setup_crafting_ui() -> void:
	blacksmith_ui = CanvasLayer.new()
	blacksmith_ui.name = "BlacksmithUILayer"
	blacksmith_ui.visible = false
	add_child(blacksmith_ui)

	# Bảng chính Giao diện Thợ Rèn
	craft_panel = Panel.new()
	craft_panel.name = "BlacksmithWindow"
	craft_panel.anchor_left = 0.5
	craft_panel.anchor_top = 0.5
	craft_panel.anchor_right = 0.5
	craft_panel.anchor_bottom = 0.5
	craft_panel.offset_left = -260.0
	craft_panel.offset_top = -180.0
	craft_panel.offset_right = 260.0
	craft_panel.offset_bottom = 180.0

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.18, 0.12, 0.08, 0.96)
	bg_style.border_width_left = 3
	bg_style.border_width_top = 3
	bg_style.border_width_right = 3
	bg_style.border_width_bottom = 3
	bg_style.border_color = Color(0.85, 0.55, 0.25, 1.0)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	bg_style.shadow_size = 10
	craft_panel.add_theme_stylebox_override("panel", bg_style)
	blacksmith_ui.add_child(craft_panel)

	# Tiêu đề bảng
	var title_lbl := Label.new()
	title_lbl.text = "⚒️ BLACKSMITH FORGE (CHẾ TẠO TRANG BỊ)"
	title_lbl.position = Vector2(20, 10)
	title_lbl.size = Vector2(400, 24)
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	craft_panel.add_child(title_lbl)

	# Nút đóng [X]
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(485, 8)
	close_btn.size = Vector2(26, 26)
	close_btn.pressed.connect(func(): toggle_crafting_window(false))
	craft_panel.add_child(close_btn)

	# Hướng dẫn nguyên liệu
	var guide_lbl := Label.new()
	guide_lbl.text = "Materials: Wood: 20 Wood | Stone: 20W+20Stone | Copper/Iron/Gold/Amethyst: 20W + 20 Ore"
	guide_lbl.position = Vector2(20, 34)
	guide_lbl.size = Vector2(480, 18)
	guide_lbl.add_theme_font_size_override("font_size", 10)
	guide_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75, 0.85))
	craft_panel.add_child(guide_lbl)

	# Vùng cuộn danh sách công thức
	recipe_scroll = ScrollContainer.new()
	recipe_scroll.position = Vector2(16, 56)
	recipe_scroll.size = Vector2(488, 260)
	craft_panel.add_child(recipe_scroll)

	recipe_list_container = VBoxContainer.new()
	recipe_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list_container.add_theme_constant_override("separation", 6)
	recipe_scroll.add_child(recipe_list_container)

	# Dòng trạng thái thông báo
	status_label = Label.new()
	status_label.text = "Click 'Craft' to forge equipment using your materials."
	status_label.position = Vector2(20, 324)
	status_label.size = Vector2(480, 22)
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1.0))
	craft_panel.add_child(status_label)

func toggle_crafting_window(open_state: bool) -> void:
	is_ui_open = open_state
	if blacksmith_ui:
		blacksmith_ui.visible = is_ui_open
	if is_ui_open:
		_refresh_recipe_list()

func _refresh_recipe_list() -> void:
	if not recipe_list_container:
		return
	for c in recipe_list_container.get_children():
		c.queue_free()

	var inv = get_tree().get_first_node_in_group("inventory")
	var current_category: String = ""

	for recipe in CRAFTING_RECIPES:
		var cat_name: String = str(recipe.get("category", "General"))
		if cat_name != current_category:
			current_category = cat_name
			var cat_lbl := Label.new()
			cat_lbl.text = "─── %s ───" % cat_name.to_upper()
			cat_lbl.add_theme_font_size_override("font_size", 11)
			cat_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35, 1.0))
			recipe_list_container.add_child(cat_lbl)

		var row := _create_recipe_row(recipe, inv)
		recipe_list_container.add_child(row)

func _create_recipe_row(recipe: Dictionary, inv: Node) -> Control:
	var row_panel := Panel.new()
	row_panel.custom_minimum_size = Vector2(464, 38)
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.12, 0.08, 0.05, 0.85)
	r_style.border_width_left = 1
	r_style.border_width_top = 1
	r_style.border_width_right = 1
	r_style.border_width_bottom = 1
	r_style.border_color = Color(0.45, 0.32, 0.18, 0.7)
	r_style.corner_radius_top_left = 4
	r_style.corner_radius_top_right = 4
	r_style.corner_radius_bottom_right = 4
	r_style.corner_radius_bottom_left = 4
	row_panel.add_theme_stylebox_override("panel", r_style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 8.0
	hbox.offset_right = -8.0
	hbox.offset_top = 4.0
	hbox.offset_bottom = -4.0
	hbox.add_theme_constant_override("separation", 10)
	row_panel.add_child(hbox)

	# Icon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(30, 30)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex = load(recipe["atlas_path"]) as Texture2D
	if tex:
		var atl := AtlasTexture.new()
		atl.atlas = tex
		atl.region = recipe["region"]
		icon_rect.texture = atl
	hbox.add_child(icon_rect)

	# Tên món đồ & Nguyên liệu yêu cầu
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 1)

	var name_lbl := Label.new()
	name_lbl.text = str(recipe.get("name", "Item"))
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85, 1.0))
	info_col.add_child(name_lbl)

	# Kiểm tra người chơi có đủ nguyên liệu không
	var cost_dict: Dictionary = recipe.get("cost", {})
	var has_all_mats: bool = true
	var mat_status_parts: Array[String] = []

	for mat_id in cost_dict.keys():
		var need_qty: int = int(cost_dict[mat_id])
		var user_qty: int = inv.count_item(mat_id) if (inv and inv.has_method("count_item")) else 0
		if user_qty < need_qty:
			has_all_mats = false
		var mat_name: String = _format_mat_name(mat_id)
		mat_status_parts.append("%s: %d/%d" % [mat_name, user_qty, need_qty])

	var cost_lbl := Label.new()
	cost_lbl.text = "Cost: " + " | ".join(mat_status_parts)
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0) if has_all_mats else Color(1.0, 0.5, 0.45, 1.0))
	info_col.add_child(cost_lbl)
	hbox.add_child(info_col)

	# Nút Chế Tạo
	var craft_btn := Button.new()
	craft_btn.text = "Craft ⚒️"
	craft_btn.custom_minimum_size = Vector2(80, 26)
	craft_btn.add_theme_font_size_override("font_size", 11)
	craft_btn.disabled = not has_all_mats
	craft_btn.pressed.connect(_on_craft_button_pressed.bind(recipe))
	hbox.add_child(craft_btn)

	return row_panel

func _format_mat_name(mat_id: String) -> String:
	match mat_id:
		"branch": return "Wood"
		"stone": return "Stone"
		"copper_ore": return "Copper"
		"iron_ore": return "Iron"
		"gold_ore": return "Gold"
		"amethyst_gem": return "Amethyst"
	return mat_id.capitalize()

func _on_craft_button_pressed(recipe: Dictionary) -> void:
	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv:
		return

	if inv.has_method("has_inventory_space") and not inv.has_inventory_space():
		_set_status("Backpack is full! Free up a slot to craft.", Color(1.0, 0.4, 0.4, 1.0))
		return

	var cost_dict: Dictionary = recipe.get("cost", {})
	# Kiểm tra lại số lượng trước khi trừ
	for mat_id in cost_dict.keys():
		var need_qty: int = int(cost_dict[mat_id])
		if inv.count_item(mat_id) < need_qty:
			_set_status("Not enough materials to craft %s!" % str(recipe.get("name")), Color(1.0, 0.4, 0.4, 1.0))
			_refresh_recipe_list()
			return

	# Trừ nguyên liệu
	for mat_id in cost_dict.keys():
		var need_qty: int = int(cost_dict[mat_id])
		inv.remove_items_by_id(mat_id, need_qty)

	# Thêm thành phẩm vào Balo
	var tex = load(recipe["atlas_path"]) as Texture2D
	var icon := AtlasTexture.new()
	icon.atlas = tex
	icon.region = recipe["region"]
	var scene_res = load(recipe["scene_path"]) as PackedScene if recipe["scene_path"] != "" else null
	var def_val: int = int(recipe.get("defense", 0))

	inv.add_item(icon, scene_res, recipe["id"], recipe["name"], def_val)

	_set_status("Successfully crafted: %s!" % str(recipe.get("name")), Color(0.4, 1.0, 0.5, 1.0))
	_show_floating_craft_text("Crafted: %s!" % str(recipe.get("name")))
	_refresh_recipe_list()

func _set_status(msg: String, col: Color) -> void:
	if status_label:
		status_label.text = msg
		status_label.add_theme_color_override("font_color", col)

func _show_floating_craft_text(text_msg: String) -> void:
	var float_lbl := Label.new()
	float_lbl.text = text_msg
	float_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	float_lbl.position = Vector2(-80, -56)
	float_lbl.size = Vector2(160, 20)
	float_lbl.z_index = 30
	float_lbl.add_theme_font_size_override("font_size", 11)
	float_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	float_lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.01, 1.0))
	float_lbl.add_theme_constant_override("outline_size", 3)
	add_child(float_lbl)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(float_lbl, "position:y", float_lbl.position.y - 24.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(float_lbl, "modulate:a", 0.0, 0.9).set_delay(0.3)
	await tween.finished
	if is_instance_valid(float_lbl):
		float_lbl.queue_free()

func _on_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_nearby = true
		if overhead_label:
			overhead_label.text = "[Click or Press E] Blacksmith Forge"
			overhead_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4, 1.0))

func _on_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_nearby = false
		if overhead_label:
			overhead_label.text = "Blacksmith (Craft Weapons & Armor)"
			overhead_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
		toggle_crafting_window(false)

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_crafting_window(not is_ui_open)

func _unhandled_input(event: InputEvent) -> void:
	if player_nearby and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			# Chỉ mở khi đang không mở balo
			var inv = get_tree().get_first_node_in_group("inventory")
			if inv and inv.get("bag_window") and inv.bag_window.visible:
				return
			toggle_crafting_window(not is_ui_open)
		elif event.keycode == KEY_ESCAPE and is_ui_open:
			toggle_crafting_window(false)
