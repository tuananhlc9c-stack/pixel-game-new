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

# Bảng giá vàng cho từng loại nông sản, thịt, cá, nguyên liệu và đồ nội thất
const ITEM_PRICES: Dictionary = {
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
	"furn_blue_bed": 360
}

const SLOT_NORMAL_COLOR := Color(0.92, 0.88, 0.82, 1.0)
const SLOT_HOVER_COLOR := Color(1.05, 1.0, 0.92, 1.0)
const SLOT_SELECTED_COLOR := Color(1.12, 1.05, 0.88, 1.0)

signal item_changed(item_texture)
signal inventory_updated()

func _ready() -> void:
	# Tránh chạy lại _ready() của root trên các ô con được gán cùng script
	if get_meta("is_slot", false):
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

	_setup_gold_toolbar_ui()
	if SceneManager and not SceneManager.gold_changed.is_connected(_on_gold_changed):
		SceneManager.gold_changed.connect(_on_gold_changed)

	# Khôi phục dữ liệu balo nếu đã lưu hoặc cấp sẵn Cần Câu Cá & Bộ Công Cụ lúc mới vào game
	if SceneManager and SceneManager.saved_inventory_data.size() == all_slots.size():
		inventory_data = SceneManager.saved_inventory_data.duplicate(true)
		for i in range(all_slots.size()):
			update_slot_display(i)
		_give_starter_tools()
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
		_sync_to_scene_manager()

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
		}
	]
	for t in starter_tools:
		var already_has := false
		for slot_item in inventory_data:
			if typeof(slot_item) == TYPE_DICTIONARY and slot_item != null and slot_item.get("id", "") == t["id"]:
				already_has = true
				break
		if not already_has:
			var icon := AtlasTexture.new()
			icon.atlas = tools_tex
			icon.region = t["region"]
			var sc := load(str(t["scene"])) as PackedScene
			add_item(icon, sc, str(t["id"]), str(t["name"]))

func _sync_to_scene_manager() -> void:
	if SceneManager:
		SceneManager.saved_inventory_data = inventory_data.duplicate(true)
		SceneManager.saved_selected_slot = selected_slot_index
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
	if id_str in ["wood_pickaxe", "wood_axe", "stone_pickaxe", "stone_axe", "iron_pickaxe"]:
		return id_str
	return ""

func is_holding_tool() -> bool:
	return get_selected_tool_id() != ""

func is_furniture_item(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data == null:
		return false
	var id_str: String = str(data.get("id", "")).to_lower()
	if id_str.begins_with("furn_"):
		return true
	var icon_tex = data.get("icon")
	if icon_tex is AtlasTexture and icon_tex.atlas and "Furniture_tilet" in icon_tex.atlas.resource_path:
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
	return typeof(data) == TYPE_DICTIONARY and data.has("from_slot")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv:
		return
	var to_idx = get_meta("slot_idx", -1)
	var from_idx = data["from_slot"]

	# Đánh dấu là đã thả vào bên trong một ô hợp lệ của Balo
	inv.dropped_inside_slot = true

	if to_idx != -1 and from_idx != to_idx:
		inv.swap_slots(from_idx, to_idx)

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

# Click chuột trái đơn thuần chỉ để sáng ô chọn (không tự đặt đồ gây lỗi nữa)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var inv = get_tree().get_first_node_in_group("inventory")
		var idx = get_meta("slot_idx", -1)
		if inv and idx != -1:
			inv.select_slot_by_index(idx)

# ----------------- QUẢN LÝ DỮ LIỆU Ô -----------------
func _get_slot_icon_node(slot: Node) -> TextureRect:
	var target_icon := slot.get_node_or_null("Icon") as TextureRect
	if not target_icon:
		target_icon = slot.get_node_or_null("icon") as TextureRect
	return target_icon

func add_item(icon: Texture2D, scene_to_place: PackedScene = null, item_id: String = "", item_name: String = "") -> bool:
	for i in range(inventory_data.size()):
		if inventory_data[i] == null:
			inventory_data[i] = {
				"scene": scene_to_place,
				"icon": icon,
				"id": item_id,
				"name": item_name
			}
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
		if price > 0:
			slot.tooltip_text = "%s (Sell: %d Gold)" % [item_name_str if item_name_str != "" else "Item", price]
		else:
			slot.tooltip_text = item_name_str
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
	if item_id in ["fishing_rod", "wood_pickaxe", "wood_axe", "stone_pickaxe", "stone_axe", "iron_pickaxe"]:
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
