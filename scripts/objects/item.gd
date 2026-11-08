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

@onready var tilemap: Node2D = _find_tilemap_node()
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	input_event.connect(_on_input_event)
	snap_to_tile()
	previous_valid_position = global_position

func _find_tilemap_node() -> Node2D:
	var parent_node := get_parent()
	if not parent_node:
		return null
	if parent_node is TileMap or parent_node is TileMapLayer:
		return parent_node as Node2D
	var tm := parent_node.get_node_or_null("TileMap")
	if tm:
		return tm as Node2D
	var tml := parent_node.get_node_or_null("TileMapLayer")
	if tml:
		return tml as Node2D
	return null

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Click chuột trái: Nhấc món đồ lên để kéo
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragging = true
		drag_offset = global_position - get_global_mouse_position()
		z_index = 10
		get_viewport().set_input_as_handled()

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
		get_viewport().set_input_as_handled()
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
		get_viewport().set_input_as_handled()

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
	if tilemap is TileMapLayer:
		var tml := tilemap as TileMapLayer
		var cell_coords: Vector2i = tml.local_to_map(local_pos)
		return tml.get_cell_source_id(cell_coords) != -1
	elif tilemap is TileMap:
		var tm := tilemap as TileMap
		var cell_coords: Vector2i = tm.local_to_map(local_pos)
		return tm.get_cell_source_id(0, cell_coords) != -1
	return true
