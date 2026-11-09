extends Node

# Vị trí xuất hiện của nhân vật ở map tiếp theo
var spawn_position: Vector2 = Vector2.ZERO
var use_spawn_position: bool = false
var is_changing_scene: bool = false

# Lưu máu của Player khi chuyển cảnh (-1 nghĩa là dùng max_health mặc định)
var saved_player_health: int = -1

# Bảng ánh xạ UID sang đường dẫn Scene mới sau khi tái cấu trúc thư mục
const SCENE_UID_MAP: Dictionary = {
	"uid://couwdjdsc2a3n": "res://scenes/maps/farm house.tscn",
	"uid://bee5tdiyupuf5": "res://scenes/maps/farm house 2.tscn",
	"uid://ctog71q3jotnh": "res://scenes/maps/map1.tscn",
	"uid://cilcixq22rqv6": "res://scenes/maps/map2.tscn",
	"uid://dpgpe2viw51nm": "res://scenes/maps/map3.tscn",
	"uid://bdk11e7un5d8k": "res://scenes/maps/map4.tscn",
	"uid://8kv8uybb5dkn": "res://scenes/maps/map5.tscn",
	"uid://c364bdboabr5r": "res://scenes/maps/map6.tscn",
	"uid://bcmh41qeochc1": "res://scenes/maps/map7.tscn",
	"uid://b28c7xw4xp5i2": "res://scenes/maps/map8.tscn",
	"uid://bdpjwsvv8g8fr": "res://scenes/maps/house map.tscn",
	"uid://bvl5kusbaxc84": "res://scenes/maps/house_map.tscn",
	"uid://be3wlbhmv6ee": "res://scenes/dungeons/forbidden area.tscn",
	"uid://c4s77yagjg46k": "res://scenes/dungeons/danger.tscn",
	"uid://dmdc22vb8f5mk": "res://scenes/dungeons/danger1.tscn",
	"uid://cdepwknworn1s": "res://scenes/dungeons/danger2.tscn",
	"uid://dumlx6wwc85n1": "res://scenes/dungeons/danger3.tscn"
}

func change_scene(scene_path: String, target_pos: Vector2) -> void:
	if is_changing_scene or scene_path == "":
		return
	is_changing_scene = true
	spawn_position = target_pos
	use_spawn_position = true
	var resolved_path: String = SCENE_UID_MAP.get(scene_path, scene_path)
	call_deferred("_deferred_change_scene", resolved_path)

func _deferred_change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
	is_changing_scene = false
