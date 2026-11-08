extends Control

# Liên kết đến node BagWindow chứa 40 ô balo
@onready var bag_window: Control = $bagwindow 

func _ready():
	# Mặc định khi vào game: Thanh QuickBar bên ngoài vẫn hiện, còn balo 40 ô sẽ ẩn đi
	if bag_window:
		bag_window.visible = false

func _input(event):
	# Bấm phím 'E' để bật/tắt bảng balo 40 ô
	if event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
		if bag_window:
			bag_window.visible = not bag_window.visible
