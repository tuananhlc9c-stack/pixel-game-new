extends Area2D

@export var tile_size: int = 16 
@export var item_icon: Texture2D

# THÊM DÒNG NÀY: Để gắn file scene .tscn của chiếc ghế vào
@export var item_scene: PackedScene

@export_enum("Flip Left/Right", "Rotate 90 Degrees") var rotation_mode: int = 0

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var previous_valid_position: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D

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
			if inv.add_item(icon, scene_to_save):
				print("Đã đóng gói và cất ghế thành công!")
				queue_free()
		return

	# 2. BẤM CHUỘT TRÁI: NHẤC ĐỒ DI CHUYỂN TRÊN SÀN
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragging = true
		drag_offset = global_position - get_global_mouse_position()
		z_index = 10

	

func _unhandled_input(event: InputEvent) -> void:
	if not is_dragging:
		return

	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_R:
		handle_rotation()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
		z_index = 1
		snap_to_tile()
		previous_valid_position = global_position

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
