extends Control

@onready var bag_window: Control = $bagwindow
@onready var quick_bar_slots = $QuickBar.get_children()
@onready var bag_grid_slots = $bagwindow/baggrid.get_children()

# Danh sách gộp toàn bộ 50 ô (10 ô QuickBar + 40 ô Balo)
var all_slots: Array = []
var selected_slot: TextureRect = null

signal item_changed(item_texture)

func _ready():
	if bag_window:
		bag_window.visible = false
	
	# Gom toàn bộ các ô vào một danh sách
	all_slots = quick_bar_slots + bag_grid_slots
	
	# Kết nối sự kiện click chuột cho từng ô
	for slot in all_slots:
		if slot is TextureRect:
			slot.gui_input.connect(_on_slot_gui_input.bind(slot))
			slot.modulate = Color(0.8, 0.8, 0.8) # Màu mặc định hơi tối nhẹ
	
	# Mặc định chọn ô đầu tiên của QuickBar khi bắt đầu
	if quick_bar_slots.size() > 0 and quick_bar_slots[0] is TextureRect:
		select_slot(quick_bar_slots[0])

func _unhandled_input(event):
	# Phím E bật/tắt balo
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			if bag_window:
				bag_window.visible = not bag_window.visible
		
		# Hỗ trợ bấm phím số 1-9 và 0 để chọn nhanh trên QuickBar
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx = event.keycode - KEY_1
			if idx < quick_bar_slots.size():
				select_slot(quick_bar_slots[idx])
		elif event.keycode == KEY_0:
			if quick_bar_slots.size() >= 10:
				select_slot(quick_bar_slots[9])

# Hàm xử lý khi bấm chuột vào một ô bất kỳ
func _on_slot_gui_input(event: InputEvent, slot: TextureRect):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			select_slot(slot)

# Chọn và làm sáng ô
func select_slot(slot: TextureRect):
	# Trả các ô khác về màu bình thường
	for s in all_slots:
		if s is TextureRect:
			s.modulate = Color(0.8, 0.8, 0.8)
	
	# Làm sáng ô được click
	selected_slot = slot
	selected_slot.modulate = Color(1.5, 1.5, 1.5) # Trắng sáng nổi bật
	
	# Phát tín hiệu mang texture của món đồ đó ra ngoài tay Player
	item_changed.emit(selected_slot.texture)
