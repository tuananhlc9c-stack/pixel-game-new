extends Node

# Vị trí xuất hiện của nhân vật ở map tiếp theo
var spawn_position: Vector2 = Vector2.ZERO
var use_spawn_position: bool = false
var is_changing_scene: bool = false
var portal_cooldown: float = 0.0

func _process(delta: float) -> void:
	if portal_cooldown > 0.0:
		portal_cooldown = maxf(0.0, portal_cooldown - delta)

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

func serialize_item(item_data: Variant) -> Variant:
	if item_data == null:
		return null
	if not (item_data is Dictionary):
		return null
	var item_copy: Dictionary = item_data.duplicate()
	if item_copy.get("scene") is PackedScene:
		item_copy["scene_path"] = (item_copy["scene"] as PackedScene).resource_path
		item_copy.erase("scene")
	var icon_res = item_copy.get("icon")
	if icon_res is AtlasTexture:
		if icon_res.atlas and "resource_path" in icon_res.atlas:
			item_copy["icon_atlas_path"] = icon_res.atlas.resource_path
		var reg: Rect2 = icon_res.region
		item_copy["icon_region"] = [reg.position.x, reg.position.y, reg.size.x, reg.size.y]
	elif icon_res is Texture2D and "resource_path" in icon_res:
		item_copy["icon_path"] = icon_res.resource_path
	item_copy.erase("icon")
	return item_copy

func deserialize_item(item_dict: Variant) -> Variant:
	if item_dict == null or not (item_dict is Dictionary):
		return null
	var res: Dictionary = item_dict.duplicate()
	var sc_path: String = str(res.get("scene_path", ""))
	if sc_path != "" and ResourceLoader.exists(sc_path):
		res["scene"] = load(sc_path) as PackedScene

	var icon_tex: Texture2D = null
	if res.has("icon_atlas_path"):
		var a_path: String = str(res["icon_atlas_path"])
		if a_path != "" and ResourceLoader.exists(a_path):
			var base_atlas := load(a_path) as Texture2D
			if base_atlas:
				var atlas_tex := AtlasTexture.new()
				atlas_tex.atlas = base_atlas
				if res.has("icon_region") and res["icon_region"] is Array and res["icon_region"].size() >= 4:
					var r_arr = res["icon_region"]
					atlas_tex.region = Rect2(float(r_arr[0]), float(r_arr[1]), float(r_arr[2]), float(r_arr[3]))
				icon_tex = atlas_tex
	elif res.has("icon_path"):
		var i_path: String = str(res["icon_path"])
		if i_path != "" and ResourceLoader.exists(i_path):
			icon_tex = load(i_path) as Texture2D

	if not icon_tex:
		icon_tex = _fallback_resolve_icon(res)

	res["icon"] = icon_tex
	return res

func _fallback_resolve_icon(item_data: Dictionary) -> Texture2D:
	var item_id: String = str(item_data.get("id", ""))
	var sc_path: String = str(item_data.get("scene_path", ""))

	# 1. Thử load icon từ scene tương ứng
	if sc_path != "" and ResourceLoader.exists(sc_path):
		var sc := load(sc_path) as PackedScene
		if sc:
			var inst = sc.instantiate()
			if inst:
				var found_tex: Texture2D = null
				if "item_icon" in inst and inst.item_icon:
					found_tex = inst.item_icon
				elif inst.has_node("Sprite2D"):
					var spr = inst.get_node("Sprite2D") as Sprite2D
					if spr and spr.texture:
						if spr.region_enabled:
							var at := AtlasTexture.new()
							at.atlas = spr.texture
							at.region = spr.region_rect
							found_tex = at
						else:
							found_tex = spr.texture
				inst.free()
				if found_tex:
					return found_tex

	# 2. Trang phục / Mũ / Áo / Quần
	var hat_path := "res://Content T1/Character/Player/Hat.png"
	var clothes_regions: Dictionary = {
		"hat_straw": {"path": hat_path, "region": Rect2(1, 4, 18, 9)},
		"hat_leather": {"path": hat_path, "region": Rect2(23, 3, 14, 9)},
		"hat_iron": {"path": hat_path, "region": Rect2(43, 0, 14, 12)},
		"hat_gold": {"path": hat_path, "region": Rect2(60, 2, 20, 10)},
		"hat_amethyst": {"path": hat_path, "region": Rect2(82, 4, 16, 10)},
		"shirt_cloth": {"path": "res://Content T1/Character/Player/Body.png", "region": Rect2(48, 0, 8, 8)},
		"shirt_leather": {"path": "res://Content T1/Character/Player/Body.png", "region": Rect2(8, 0, 8, 8)},
		"shirt_iron": {"path": "res://Content T1/Character/Player/Body.png", "region": Rect2(80, 0, 8, 8)},
		"shirt_gold": {"path": "res://Content T1/Character/Player/Body.png", "region": Rect2(40, 32, 8, 8)},
		"shirt_amethyst": {"path": "res://Content T1/Character/Player/Body.png", "region": Rect2(64, 64, 8, 8)},
		"pants_cloth": {"path": "res://Content T1/Character/Player/Body.png", "region": Rect2(20, 23, 8, 5)},
		"pants_leather": {"path": "res://Content T1/Character/Player/Body.png", "region": Rect2(82, 23, 12, 5)},
		"pants_iron": {"path": "res://Content T1/Character/Player/Body.png", "region": Rect2(4, 85, 8, 8)},
		"pants_gold": {"path": "res://Content T1/Character/Player/Body.png", "region": Rect2(3, 278, 9, 7)},
		"pants_amethyst": {"path": "res://Content T1/Character/Player/Body.png", "region": Rect2(52, 243, 8, 9)}
	}
	if clothes_regions.has(item_id):
		var info: Dictionary = clothes_regions[item_id]
		var tex := load(info["path"]) as Texture2D
		if tex:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = info["region"]
			return at

	# 3. Dụng cụ & Cần câu
	var tools_tex := load("res://Content T1/Tilesheet/Tools1_tilet.png") as Texture2D
	if tools_tex:
		var tool_regions: Dictionary = {
			"fishing_rod": Rect2(0, 144, 16, 16),
			"wood_pickaxe": Rect2(80, 16, 16, 16),
			"wood_axe": Rect2(80, 80, 16, 16),
			"stone_pickaxe": Rect2(80, 48, 16, 16),
			"stone_axe": Rect2(80, 112, 16, 16),
			"iron_pickaxe": Rect2(192, 16, 16, 16),
			"iron_axe": Rect2(192, 80, 16, 16)
		}
		if tool_regions.has(item_id):
			var at := AtlasTexture.new()
			at.atlas = tools_tex
			at.region = tool_regions[item_id]
			return at

	# 4. Vũ khí
	var weapon_tex := load("res://Content T1/Tilesheet/Weapon1_tilet.png") as Texture2D
	if weapon_tex:
		var weapon_regions: Dictionary = {
			"wood_sword": Rect2(48, 112, 16, 16),
			"iron_sword": Rect2(64, 112, 16, 16),
			"copper_sword": Rect2(80, 112, 16, 16),
			"gold_sword": Rect2(96, 112, 16, 16),
			"amethyst_sword": Rect2(112, 112, 16, 16),
			"wood_scythe": Rect2(48, 80, 16, 16),
			"iron_scythe": Rect2(64, 80, 16, 16),
			"copper_scythe": Rect2(80, 80, 16, 16),
			"gold_scythe": Rect2(96, 80, 16, 16),
			"amethyst_scythe": Rect2(112, 80, 16, 16),
			"wood_bow": Rect2(48, 64, 16, 16),
			"iron_bow": Rect2(64, 64, 16, 16),
			"copper_bow": Rect2(80, 64, 16, 16),
			"gold_bow": Rect2(96, 64, 16, 16),
			"amethyst_bow": Rect2(112, 64, 16, 16),
			"wood_spear": Rect2(48, 32, 16, 16),
			"iron_spear": Rect2(64, 32, 16, 16),
			"copper_spear": Rect2(80, 32, 16, 16),
			"gold_spear": Rect2(96, 32, 16, 16),
			"amethyst_spear": Rect2(112, 32, 16, 16),
			"wood_staff": Rect2(48, 96, 16, 16),
			"iron_staff": Rect2(64, 96, 16, 16),
			"copper_staff": Rect2(80, 96, 16, 16),
			"gold_staff": Rect2(96, 96, 16, 16),
			"amethyst_staff": Rect2(112, 96, 16, 16)
		}
		if weapon_regions.has(item_id):
			var at := AtlasTexture.new()
			at.atlas = weapon_tex
			at.region = weapon_regions[item_id]
			return at

	# 5. Đồ ăn nấu nướng (iteamdoan.png)
	var food_regions: Dictionary = {
		"cooked_egg": Rect2(0, 32, 16, 16),
		"grilled_fish": Rect2(32, 32, 16, 16),
		"cooked_pork": Rect2(0, 0, 16, 16),
		"noodle_soup": Rect2(0, 16, 16, 16),
		"omelette": Rect2(32, 16, 16, 16),
		"pumpkin_soup": Rect2(48, 32, 16, 16),
		"roast_meat": Rect2(48, 16, 16, 16),
		"seafood_salad": Rect2(16, 32, 16, 16)
	}
	if food_regions.has(item_id):
		var food_tex := load("res://Content T1/Tilesheet/iteamdoan.png") as Texture2D
		if food_tex:
			var at := AtlasTexture.new()
			at.atlas = food_tex
			at.region = food_regions[item_id]
			return at

	# 6. Cá tươi & Nông sản (Fish-food.png)
	var fish_food_tex := load("res://Content T1/Loose/Fish-food.png") as Texture2D
	if fish_food_tex:
		var ff_regions: Dictionary = {
			"egg": Rect2(80, 0, 16, 16),
			"cow_milk": Rect2(32, 0, 16, 16),
			"goat_milk": Rect2(32, 0, 16, 16),
			"fish_carp": Rect2(0, 48, 16, 16),
			"fish_perch": Rect2(16, 48, 16, 16),
			"fish_salmon": Rect2(32, 48, 16, 16),
			"fish_gold": Rect2(48, 48, 16, 16),
			"fish_tuna": Rect2(80, 48, 16, 16),
			"fish_crab": Rect2(144, 48, 16, 16),
			"fish_shrimp": Rect2(160, 48, 16, 16),
			"fish_octopus": Rect2(176, 48, 16, 16)
		}
		if ff_regions.has(item_id):
			var at := AtlasTexture.new()
			at.atlas = fish_food_tex
			at.region = ff_regions[item_id]
			return at

	return null

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
		inv_serializable.append(serialize_item(item))

	var equip_serializable: Dictionary = {}
	for k in saved_equipment_data.keys():
		equip_serializable[k] = serialize_item(saved_equipment_data[k])

	var chest_serializable: Array = []
	for c_item in saved_chest_data:
		chest_serializable.append(serialize_item(c_item))

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
		"chest_data": chest_serializable,
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

	# Khôi phục dữ liệu Túi Đồ (Inventory)
	if data.has("inventory") and data["inventory"] is Array:
		saved_inventory_data.clear()
		for item_raw in data["inventory"]:
			saved_inventory_data.append(deserialize_item(item_raw))

	# Khôi phục dữ liệu Trang Bị (Equipment)
	if data.has("equipment") and data["equipment"] is Dictionary:
		for k in ["hat", "shirt", "pants"]:
			if data["equipment"].has(k):
				saved_equipment_data[k] = deserialize_item(data["equipment"][k])

	# Khôi phục dữ liệu Rương Đồ (Chest)
	if data.has("chest_data") and data["chest_data"] is Array:
		saved_chest_data.clear()
		for c_item in data["chest_data"]:
			saved_chest_data.append(deserialize_item(c_item))

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

# Rơi tiền xu ngẫu nhiên từ 10 - 15 Gold tại vị trí quái chết
func spawn_monster_gold_drop(drop_pos: Vector2, parent_node: Node = null) -> void:
	var coin_scene := load("res://scenes/objects/coin_drop.tscn") as PackedScene
	if not coin_scene:
		return
	var coin = coin_scene.instantiate() as Node2D
	if not coin:
		return
	
	# Random số tiền từ 10 đến 15
	var rand_amount: int = randi_range(10, 15)
	coin.set("gold_amount", rand_amount)
	
	# Vị trí rơi có độ lệch tự nhiên nhẹ quanh quái
	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * randf_range(6.0, 16.0)
	coin.global_position = drop_pos
	
	var target_parent = parent_node
	if not target_parent or not is_instance_valid(target_parent):
		target_parent = Engine.get_main_loop().current_scene
		
	if target_parent:
		target_parent.call_deferred("add_child", coin)
		var tw := coin.create_tween().set_parallel(true)
		tw.tween_property(coin, "global_position", drop_pos + offset, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "scale", Vector2.ONE, 0.28).from(Vector2(0.3, 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

func respawn_player_at_farm_house() -> void:
	is_changing_scene = true
	saved_player_health = -1
	saved_player_mana = -1.0
	spawn_position = Vector2(53, 403)
	use_spawn_position = true
	saved_map_scene_path = "res://scenes/maps/farm house.tscn"
	portal_cooldown = 1.0

	# Lưu trạng thái sạch sẽ về file để không bị dữ liệu cũ ghi đè
	save_game(null)

	# Gán lại spawn position & map chuẩn sau khi save_game
	spawn_position = Vector2(53, 403)
	use_spawn_position = true
	saved_map_scene_path = "res://scenes/maps/farm house.tscn"

	call_deferred("_deferred_change_scene", "res://scenes/maps/farm house.tscn")

func change_scene(scene_path: String, target_pos: Vector2) -> void:
	if is_changing_scene or scene_path == "":
		return
	is_changing_scene = true

	# Tự động lưu game trước khi di chuyển sang map mới
	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node and get_tree().current_scene:
		player_node = get_tree().current_scene.find_child("Player", true, false)
	save_game(player_node)

	# QUAN TRỌNG: Thiết lập target spawn position SAU KHI save_game
	# để spawn_position không bị save_game ghi đè bởi current_player.global_position!
	spawn_position = target_pos
	use_spawn_position = true
	portal_cooldown = 0.5

	var resolved_path: String = SCENE_UID_MAP.get(scene_path, scene_path)
	call_deferred("_deferred_change_scene", resolved_path)

func _deferred_change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
	is_changing_scene = false
