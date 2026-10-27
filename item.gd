extends Area2D

# Kích thước ô lưới sàn
@export var tile_size: int = 16 

# Chế độ xoay của món đồ:
# 0 = Lật 2 hướng Trái / Phải (Dùng cho Ghế dài, Tivi, Giường...)
# 1 = Xoay 4 hướng 90 độ (Dùng cho Thảm vuông, Đèn, Bàn...)
@export_enum("Flip Left/Right", "Rotate 90 Degrees") var rotation_mode: int = 0

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var previous_valid_position: Vector2 = Vector2.ZERO

@onready var tilemap: TileMap = get_parent().get_node_or_null("TileMap")
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	input_event.connect(_on_input_event)
	snap_to_tile()
	previous_valid_position = global_position

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Click chuột trái: Nhấc món đồ lên để kéo
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragging = true
		drag_offset = global_position - get_global_mouse_position()
		z_index = 10

func _unhandled_input(event: InputEvent) -> void:
	if not is_dragging:
		return

	# Bấm CHUỘT PHẢI hoặc PHÍM R khi đang kéo để xoay/đổi hướng
	var wants_to_rotate: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		wants_to_rotate = true
	elif event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_R:
		wants_to_rotate = true

	if wants_to_rotate:
		handle_rotation()
		return

	# Thả chuột trái: Đặt đồ vật xuống ô sàn
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
		z_index = 1
		snap_to_tile()
		
		if is_placement_valid():
			previous_valid_position = global_position
		else:
			global_position = previous_valid_position

func handle_rotation() -> void:
	if rotation_mode == 0:
		# Chế độ 2 hướng: Lật hình ảnh trái <-> phải
		if sprite:
			sprite.flip_h = not sprite.flip_h
	else:
		# Chế độ 4 hướng: Quay tròn 90 độ
		rotation_degrees = fmod(rotation_degrees + 90.0, 360.0)

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() + drag_offset

func snap_to_tile() -> void:
	var offset: float = tile_size / 2.0
	var snapped_x: float = floor(global_position.x / tile_size) * tile_size + offset
	var snapped_y: float = floor(global_position.y / tile_size) * tile_size + offset
	global_position = Vector2(snapped_x, snapped_y)

func is_placement_valid() -> bool:
	if not tilemap:
		return true
	
	var local_pos: Vector2 = tilemap.to_local(global_position)
	var cell_coords: Vector2i = tilemap.local_to_map(local_pos)
	var source_id: int = tilemap.get_cell_source_id(0, cell_coords)
	return source_id != -1
