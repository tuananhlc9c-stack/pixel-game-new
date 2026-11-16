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

# Cài đặt Game (Settings)
var master_volume: float = 0.8
var mouse_sensitivity: float = 1.0
var is_fullscreen: bool = false
var saved_map_scene_path: String = "res://scenes/maps/farm house.tscn"

const SAVE_FILE_PATH: String = "user://game_save.json"

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

func reset_for_new_game() -> void:
	spawn_position = Vector2.ZERO
	use_spawn_position = false
	is_changing_scene = false
	saved_player_health = -1
	saved_player_mana = -1.0
	saved_player_level = 1
	saved_player_exp = 0
	saved_inventory_data = []
	saved_selected_slot = 0
	saved_equipment_data = {
		"hat": null,
		"shirt": null,
		"pants": null
	}
	has_received_starter_items = false
	has_received_starter_tools = false
	has_received_starter_clothes = false
	saved_gold = 0
	has_saved_house_furniture = false
	saved_house_furniture.clear()
	saved_chest_data = []
	chopped_trees_respawn_time.clear()
	saved_map_scene_path = "res://scenes/maps/farm house.tscn"

func apply_audio_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if master_volume <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			var db := linear_to_db(master_volume)
			AudioServer.set_bus_volume_db(bus_idx, db)

func apply_screen_mode(fullscreen: bool) -> void:
	is_fullscreen = fullscreen
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func save_game(current_player: Node2D = null) -> bool:
	if current_player and is_instance_valid(current_player):
		if "health_component" in current_player and current_player.health_component:
			saved_player_health = current_player.health_component.current_health
		if "current_mana" in current_player:
			saved_player_mana = current_player.current_mana
		spawn_position = current_player.global_position
		use_spawn_position = true

	var cur_scene = get_tree().current_scene
	if cur_scene and cur_scene.scene_file_path != "":
		saved_map_scene_path = cur_scene.scene_file_path

	var inv_serializable: Array = []
	for item in saved_inventory_data:
		if item == null:
			inv_serializable.append(null)
		elif item is Dictionary:
			var item_copy: Dictionary = item.duplicate()
			item_copy.erase("icon")
			if item_copy.get("scene") is PackedScene:
				item_copy["scene_path"] = (item_copy["scene"] as PackedScene).resource_path
				item_copy.erase("scene")
			inv_serializable.append(item_copy)

	var equip_serializable: Dictionary = {}
	for k in saved_equipment_data.keys():
		var eq_item = saved_equipment_data[k]
		if eq_item == null:
			equip_serializable[k] = null
		elif eq_item is Dictionary:
			var eq_copy: Dictionary = eq_item.duplicate()
			eq_copy.erase("icon")
			if eq_copy.get("scene") is PackedScene:
				eq_copy["scene_path"] = (eq_copy["scene"] as PackedScene).resource_path
				eq_copy.erase("scene")
			equip_serializable[k] = eq_copy

	var save_dict: Dictionary = {
		"settings": {
			"master_volume": master_volume,
			"mouse_sensitivity": mouse_sensitivity,
			"is_fullscreen": is_fullscreen
		},
		"player": {
			"health": saved_player_health,
			"mana": saved_player_mana,
			"level": saved_player_level,
			"exp": saved_player_exp,
			"spawn_pos_x": spawn_position.x,
			"spawn_pos_y": spawn_position.y,
			"use_spawn_pos": use_spawn_position,
			"map_scene": saved_map_scene_path
		},
		"gold": saved_gold,
		"inventory": inv_serializable,
		"selected_slot": saved_selected_slot,
		"equipment": equip_serializable,
		"has_received_starter_items": has_received_starter_items,
		"has_received_starter_tools": has_received_starter_tools,
		"has_received_starter_clothes": has_received_starter_clothes,
		"chest_data": saved_chest_data,
		"house_furniture": saved_house_furniture,
		"has_saved_house_furniture": has_saved_house_furniture
	}

	var json_str := JSON.stringify(save_dict, "\t")
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		return true
	return false

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		return false
	var json_str := file.get_as_text()
	file.close()

	var test_json := JSON.new()
	var parse_err := test_json.parse(json_str)
	if parse_err != OK:
		return false

	var data = test_json.data
	if not (data is Dictionary):
		return false

	var settings_data = data.get("settings", {})
	if settings_data is Dictionary:
		master_volume = float(settings_data.get("master_volume", 0.8))
		mouse_sensitivity = float(settings_data.get("mouse_sensitivity", 1.0))
		is_fullscreen = bool(settings_data.get("is_fullscreen", false))
		apply_audio_volume(master_volume)
		apply_screen_mode(is_fullscreen)

	var pdata = data.get("player", {})
	if pdata is Dictionary:
		saved_player_health = int(pdata.get("health", -1))
		saved_player_mana = float(pdata.get("mana", -1.0))
		saved_player_level = int(pdata.get("level", 1))
		saved_player_exp = int(pdata.get("exp", 0))
		spawn_position = Vector2(float(pdata.get("spawn_pos_x", 0.0)), float(pdata.get("spawn_pos_y", 0.0)))
		use_spawn_position = bool(pdata.get("use_spawn_pos", false))
		saved_map_scene_path = str(pdata.get("map_scene", "res://scenes/maps/farm house.tscn"))

	saved_gold = int(data.get("gold", 0))
	saved_selected_slot = int(data.get("selected_slot", 0))
	has_received_starter_items = bool(data.get("has_received_starter_items", false))
	has_received_starter_tools = bool(data.get("has_received_starter_tools", false))
	has_received_starter_clothes = bool(data.get("has_received_starter_clothes", false))

	if data.has("chest_data") and data["chest_data"] is Array:
		saved_chest_data = data["chest_data"]
	if data.has("house_furniture") and data["house_furniture"] is Array:
		saved_house_furniture.clear()
		for item in data["house_furniture"]:
			if item is Dictionary:
				saved_house_furniture.append(item)
	has_saved_house_furniture = bool(data.get("has_saved_house_furniture", false))

	return true

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
