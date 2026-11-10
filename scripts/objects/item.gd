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
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

const FURNITURE_REGION_MAP: Array[Dictionary] = [
	{"id": "furn_oak_chair", "name": "Oak Chair", "region": Rect2(0, 0, 16, 32)},
	{"id": "furn_birch_chair", "name": "Birch Chair", "region": Rect2(64, 0, 16, 32)},
	{"id": "furn_emerald_chair", "name": "Emerald Chair", "region": Rect2(128, 0, 16, 32)},
	{"id": "furn_modern_chair", "name": "Modern Chair", "region": Rect2(192, 0, 16, 32)},
	{"id": "furn_floor_lamp", "name": "Floor Lamp", "region": Rect2(176, 160, 16, 48)},
	{"id": "furn_oak_bench", "name": "Oak Bench", "region": Rect2(0, 48, 32, 32)},
	{"id": "furn_tea_table", "name": "Tea Table", "region": Rect2(144, 112, 32, 32)},
	{"id": "furn_oak_table", "name": "Oak Dining Table", "region": Rect2(0, 96, 32, 48)},
	{"id": "furn_oak_dresser", "name": "Oak Dresser", "region": Rect2(0, 160, 32, 32)},
	{"id": "furn_carrot_rug", "name": "Carrot Rug", "region": Rect2(208, 176, 48, 32)},
	{"id": "furn_bookshelf", "name": "Bookshelf", "region": Rect2(128, 160, 32, 48)},
	{"id": "furn_retro_tv", "name": "Retro TV", "region": Rect2(240, 240, 32, 48)},
	{"id": "furn_royal_bed", "name": "Royal Single Bed", "region": Rect2(128, 224, 32, 64)},
	{"id": "furn_blue_bed", "name": "Blue Double Bed", "region": Rect2(0, 224, 48, 64)}
]

func _ready() -> void:
	input_pickable = true
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	# Chuẩn hóa vị trí Sprite2D & CollisionShape2D nếu bị lệch tâm trong scene cũ
	if sprite and sprite.position != Vector2.ZERO:
		global_position += sprite.position
		sprite.position = Vector2.ZERO
	if col_shape and col_shape.position != Vector2.ZERO:
		col_shape.position = Vector2.ZERO

	if _is_furniture_node():
		add_to_group("furniture_item")
		_auto_detect_furniture_metadata()

	update_collision_from_sprite()

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

func _is_furniture_node() -> bool:
	if item_id.begins_with("furn_"):
		return true
	if sprite and sprite.texture and "Furniture_tilet" in sprite.texture.resource_path:
		return true
	return false

func _auto_detect_furniture_metadata() -> void:
	if not sprite or not sprite.region_enabled:
		return
	var reg := sprite.region_rect
	for entry in FURNITURE_REGION_MAP:
		var target_reg: Rect2 = entry["region"]
		if reg.position.distance_to(target_reg.position) <= 2.0 and reg.size.distance_to(target_reg.size) <= 2.0:
			if item_id == "":
				item_id = str(entry["id"])
			if item_name == "":
				item_name = str(entry["name"])
			return
	if item_id == "":
		item_id = "furn_oak_chair"
	if item_name == "":
		item_name = "Home Furniture"

func update_collision_from_sprite() -> void:
	if not sprite:
		return
	if sprite.region_enabled:
		var atlas := AtlasTexture.new()
		atlas.atlas = sprite.texture
		atlas.region = sprite.region_rect
		item_icon = atlas
	if col_shape:
		var rect_shape := RectangleShape2D.new()
		var sz := sprite.region_rect.size if sprite.region_enabled else (sprite.texture.get_size() if sprite.texture else Vector2(16, 16))
		rect_shape.size = Vector2(maxf(12.0, sz.x), maxf(12.0, sz.y))
		col_shape.shape = rect_shape
		col_shape.position = Vector2.ZERO

func is_point_over_item(world_point: Vector2) -> bool:
	if not sprite:
		return global_position.distance_to(world_point) <= 12.0
	var local_pt := to_local(world_point)
	var sz := sprite.region_rect.size if sprite.region_enabled else (sprite.texture.get_size() if sprite.texture else Vector2(16, 16))
	var half := sz * 0.5
	return Rect2(-half, sz).grow(2.0).has_point(local_pt)

func _notify_house_furniture_changed() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("save_furniture_state"):
		scene.call_deferred("save_furniture_state")

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
			var scene_to_save: PackedScene = item_scene
			if scene_to_save == null:
				if _is_furniture_node():
					scene_to_save = load("res://scenes/objects/furniture_item.tscn") as PackedScene
				elif scene_file_path != "":
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
				get_viewport().set_input_as_handled()
				queue_free()
				_notify_house_furniture_changed()
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
		_notify_house_furniture_changed()
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
		_notify_house_furniture_changed()
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
