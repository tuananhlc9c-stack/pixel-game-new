extends Area2D

# Kích thước ô lưới (sửa lại theo Tile Size của bạn, ví dụ 16 hoặc 32)
@export var tile_size: int = 16 

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var previous_valid_position: Vector2 = Vector2.ZERO

@onready var tilemap: TileMap = get_parent().get_node_or_null("TileMap")

func _ready():
	input_event.connect(_on_input_event)
	snap_to_tile()
	previous_valid_position = global_position

func _on_input_event(_viewport, event, _shape_idx):
	# Click chuột trái vào đồ vật để bắt đầu kéo
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			is_dragging = true
			drag_offset = global_position - get_global_mouse_position()
			z_index = 10

func _unhandled_input(event):
	# Thả chuột trái ra
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.is_pressed() and is_dragging:
			is_dragging = false
			z_index = 1
			snap_to_tile()
			
			if is_placement_valid():
				previous_valid_position = global_position
			else:
				global_position = previous_valid_position

	# Bấm phím R khi đang kéo để xoay 90 độ
	if is_dragging and event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_R:
			rotation_degrees += 90.0
			if rotation_degrees >= 360.0:
				rotation_degrees = 0.0

func _process(_delta):
	if is_dragging:
		global_position = get_global_mouse_position() + drag_offset

func snap_to_tile():
	var snapped_x = floor(global_position.x / tile_size) * tile_size + (tile_size / 2.0)
	var snapped_y = floor(global_position.y / tile_size) * tile_size + (tile_size / 2.0)
	global_position = Vector2(snapped_x, snapped_y)

func is_placement_valid() -> bool:
	if not tilemap:
		return true
	
	var local_pos = tilemap.to_local(global_position)
	var cell_coords = tilemap.local_to_map(local_pos)
	var source_id = tilemap.get_cell_source_id(0, cell_coords)
	return source_id != -1
