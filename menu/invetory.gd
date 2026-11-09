extends Control

@onready var bag_window: Control = $bagwindow
@onready var quick_bar: Control = $QuickBar
@onready var bag_grid: Control = $bagwindow/baggrid

var all_slots: Array = []
var selected_slot_index: int = -1
var inventory_data: Array = []
var current_place_scene: PackedScene = null

# Lưu chỉ số ô đang được giữ chuột kéo đi
var dragging_slot_index: int = -1
# Kiểm tra xem có thả vào ô khác hay thả ra ngoài sàn
var dropped_inside_slot: bool = false

signal item_changed(item_texture)

func _ready() -> void:
	add_to_group("inventory")
	
	if bag_window:
		bag_window.visible = false
	
	all_slots.clear()
	inventory_data.clear()
	
	for child in quick_bar.get_children():
		if child is TextureRect:
			all_slots.append(child)
	for child in bag_grid.get_children():
		if child is TextureRect:
			all_slots.append(child)
			
	for i in range(all_slots.size()):
		inventory_data.append(null)
		var slot = all_slots[i]
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.set_meta("slot_idx", i)
		slot.set_script(self.get_script())
		slot.modulate = Color(0.8, 0.8, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	if not is_in_group("inventory"):
		return
		
	# Bật / tắt balo bằng phím E
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			if bag_window:
				bag_window.visible = not bag_window.visible
		
		var q_count = quick_bar.get_child_count()
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx: int = event.keycode - KEY_1
			if idx < q_count:
				select_slot_by_index(idx)
		elif event.keycode == KEY_0:
			if q_count >= 10:
				select_slot_by_index(9)

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
	var preview_texture = TextureRect.new()
	preview_texture.texture = data["icon"]
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.size = Vector2(24, 24)
	
	var preview_control = Control.new()
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
			var mouse_pos = get_viewport().get_mouse_position()
			var over_ui: bool = false
			
			# Kiểm tra chắc chắn chuột không nằm đè lên thanh QuickBar hay cửa sổ Bag
			if quick_bar.is_visible_in_tree() and quick_bar.get_global_rect().has_point(mouse_pos):
				over_ui = true
			if bag_window and bag_window.is_visible_in_tree() and bag_window.get_global_rect().has_point(mouse_pos):
				over_ui = true
				
			if not over_ui:
				place_dragged_item_to_world(dragging_slot_index)
				
		dragging_slot_index = -1
		dropped_inside_slot = false

# Đặt món đồ vừa kéo thả ra thế giới 2D
func place_dragged_item_to_world(slot_idx: int) -> void:
	var data = inventory_data[slot_idx]
	if data == null or data["scene"] == null:
		return
		
	var new_item = data["scene"].instantiate()
	var target_parent = get_tree().current_scene
	target_parent.add_child(new_item)
	
	# Lấy đúng vị trí chuột trên mặt sàn 2D và căn lưới 16x16
	var world_mouse_pos = target_parent.get_global_mouse_position()
	var snap_x = floor(world_mouse_pos.x / 16.0) * 16.0 + 8.0
	var snap_y = floor(world_mouse_pos.y / 16.0) * 16.0 + 8.0
	new_item.global_position = Vector2(snap_x, snap_y)
	
	print(">>> ĐÃ KÉO THẢ ĐỒ RA SÀN TẠI: ", new_item.global_position)
	
	# Xóa món đồ khỏi ô sau khi đặt
	inventory_data[slot_idx] = null
	update_slot_display(slot_idx)
	all_slots[slot_idx].modulate = Color(0.8, 0.8, 0.8)
	if selected_slot_index == slot_idx:
		selected_slot_index = -1
		current_place_scene = null

# Click chuột trái đơn thuần chỉ để sáng ô chọn (không tự đặt đồ gây lỗi nữa)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var inv = get_tree().get_first_node_in_group("inventory")
		var idx = get_meta("slot_idx", -1)
		if inv and idx != -1:
			inv.select_slot_by_index(idx)

# ----------------- QUẢN LÝ DỮ LIỆU Ô -----------------
func add_item(icon: Texture2D, scene_to_place: PackedScene = null) -> bool:
	for i in range(inventory_data.size()):
		if inventory_data[i] == null:
			inventory_data[i] = {
				"scene": scene_to_place,
				"icon": icon
			}
			update_slot_display(i)
			return true
	return false

func update_slot_display(idx: int) -> void:
	if idx < 0 or idx >= all_slots.size():
		return
	var slot = all_slots[idx]
	var data = inventory_data[idx]
	
	var target_icon = slot.get_node_or_null("Icon")
	if not target_icon:
		target_icon = slot.get_node_or_null("icon")
		
	if data != null:
		if target_icon:
			target_icon.texture = data["icon"]
		else:
			slot.texture = data["icon"]
	else:
		if target_icon:
			target_icon.texture = null
		else:
			slot.texture = null

func swap_slots(from_idx: int, to_idx: int) -> void:
	var temp = inventory_data[from_idx]
	inventory_data[from_idx] = inventory_data[to_idx]
	inventory_data[to_idx] = temp
	
	update_slot_display(from_idx)
	update_slot_display(to_idx)
	select_slot_by_index(to_idx)

func select_slot_by_index(idx: int) -> void:
	if idx < 0 or idx >= all_slots.size():
		return
		
	for s in all_slots:
		s.modulate = Color(0.8, 0.8, 0.8)
		
	selected_slot_index = idx
	all_slots[idx].modulate = Color(1.8, 1.8, 1.8)
	
	var data = inventory_data[idx]
	if data != null:
		current_place_scene = data["scene"]
		item_changed.emit(data["icon"])
	else:
		current_place_scene = null
		item_changed.emit(null)
