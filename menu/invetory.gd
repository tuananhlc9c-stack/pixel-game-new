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

const SLOT_NORMAL_COLOR := Color(0.92, 0.88, 0.82, 1.0)
const SLOT_HOVER_COLOR := Color(1.05, 1.0, 0.92, 1.0)
const SLOT_SELECTED_COLOR := Color(1.12, 1.05, 0.88, 1.0)

signal item_changed(item_texture)

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

	# Chọn sẵn ô số 1 khi bắt đầu
	if all_slots.size() > 0:
		select_slot_by_index(0)

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
	if selected_slot_index == slot_idx:
		current_place_scene = null
		item_changed.emit(null)

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

func add_item(icon: Texture2D, scene_to_place: PackedScene = null) -> bool:
	for i in range(inventory_data.size()):
		if inventory_data[i] == null:
			inventory_data[i] = {
				"scene": scene_to_place,
				"icon": icon
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
