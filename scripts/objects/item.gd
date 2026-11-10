extends Area2D

# Kích thước ô lưới sàn
@export var tile_size: int = 16
@export var item_icon: Texture2D
@export var item_id: String = ""
@export var item_name: String = ""

# THÊM DÒNG NÀY: Để gắn file scene .tscn của chiếc ghế vào
@export var item_scene: PackedScene

@export_enum("Flip Left/Right", "Rotate 90 Degrees") var rotation_mode: int = 0

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var previous_valid_position: Vector2 = Vector2.ZERO

@onready var tilemap: Node2D = _find_tilemap_node()
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	
	if not item_icon and sprite:
		if sprite.region_enabled:
			var atlas := AtlasTexture.new()
			atlas.atlas = sprite.texture
			atlas.region = sprite.region_rect
			item_icon = atlas
		else:
			item_icon = sprite.texture
		
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
	# 1. BẤM CHUỘT PHẢI: ĐÓNG GÓI NODE HIỆN TẠI VÀ CẤT VÀO BALO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var inv = get_tree().get_first_node_in_group("inventory")
		if not inv:
			inv = get_tree().root.find_child("Invetory", true, false)
			
		if inv and inv.has_method("add_item"):
			# Tự động đóng gói chính chiếc ghế này thành PackedScene (kể cả khi chưa lưu file .tscn)
			var scene_to_save: PackedScene = item_scene
			if scene_to_save == null:
				if scene_file_path != "":
					scene_to_save = load(scene_file_path)
				else:
					# Tự đóng gói node hiện tại và các node con của nó
					var copy_node = self.duplicate()
					for child in copy_node.get_children():
						child.owner = copy_node
					scene_to_save = PackedScene.new()
					scene_to_save.pack(copy_node)
					copy_node.free()
			
			var icon = item_icon if item_icon else sprite.texture
			if inv.add_item(icon, scene_to_save, item_id, item_name):
				print("Đã đóng gói và cất đồ thành công!")
				queue_free()
		return

	# 2. BẤM CHUỘT TRÁI: NHẤC ĐỒ DI CHUYỂN TRÊN SÀN
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragging = true
		drag_offset = global_position - get_global_mouse_position()
		z_index = 10
		get_viewport().set_input_as_handled()

	

func _unhandled_input(event: InputEvent) -> void:
	if not is_dragging:
		return

	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_R:
		handle_rotation()
		get_viewport().set_input_as_handled()
		return

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
		if sprite:
			sprite.flip_h = not sprite.flip_h
	else:
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
