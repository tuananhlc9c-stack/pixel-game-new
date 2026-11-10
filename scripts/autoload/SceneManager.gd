extends Node

# Vị trí xuất hiện của nhân vật ở map tiếp theo
var spawn_position: Vector2 = Vector2.ZERO
var use_spawn_position: bool = false
var is_changing_scene: bool = false

# Lưu máu, mana, level & exp của Player khi chuyển cảnh
var saved_player_health: int = -1
var saved_player_mana: float = -1.0
var saved_player_level: int = 1
var saved_player_exp: int = 0
signal exp_changed(current_exp: int, max_exp: int, level: int)
signal level_up(new_level: int)

func get_exp_required_for_level(lvl: int) -> int:
	if lvl >= 18:
		return 0
	# Cấp 1 cần 100 EXP, mỗi cấp tăng thêm 60 EXP lũy tiến
	return 100 + (lvl - 1) * 60

func add_player_exp(amount: int) -> void:
	if saved_player_level >= 18 or amount <= 0:
		return
	saved_player_exp += amount
	var req_exp: int = get_exp_required_for_level(saved_player_level)
	while saved_player_level < 18 and saved_player_exp >= req_exp:
		saved_player_exp -= req_exp
		saved_player_level += 1
		level_up.emit(saved_player_level)
		if saved_player_level >= 18:
			saved_player_exp = 0
			break
		req_exp = get_exp_required_for_level(saved_player_level)
	exp_changed.emit(saved_player_exp, get_exp_required_for_level(saved_player_level), saved_player_level)

# Lưu dữ liệu Balo (Inventory) & Trang bị (Equipment) xuyên suốt các map
var saved_inventory_data: Array = []
var saved_selected_slot: int = 0
var saved_equipment_data: Dictionary = {
	"hat": null,
	"shirt": null,
	"pants": null
}
var has_received_starter_items: bool = false
var has_received_starter_tools: bool = false
var has_received_starter_clothes: bool = false

# Lưu số Vàng (Gold) hiện tại của người chơi xuyên suốt các map
var saved_gold: int = 0
signal gold_changed(new_gold: int)

# Lưu trạng thái đồ nội thất đã đặt trong House Map xuyên suốt các lần ra vào nhà
var has_saved_house_furniture: bool = false
var saved_house_furniture: Array[Dictionary] = []

# Lưu dữ liệu Rương Đồ 40 ô trong House Map xuyên suốt các map
var saved_chest_data: Array = []

# Lưu thời điểm hồi phục (respawn timestamp) của các cây đã bị chặt xuyên suốt các map
var chopped_trees_respawn_time: Dictionary = {}

func add_gold(amount: int) -> void:
	saved_gold = max(0, saved_gold + amount)
	gold_changed.emit(saved_gold)

func get_gold() -> int:
	return saved_gold

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
