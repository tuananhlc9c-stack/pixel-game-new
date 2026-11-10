extends Node2D

const FURNITURE_SCENE_PATH := "res://scenes/objects/furniture_item.tscn"
const FURNITURE_ATLAS_PATH := "res://Content T1/Tilesheet/Furniture_tilet.png"

func _ready() -> void:
	add_to_group("house_map")
	call_deferred("_initialize_house_furniture")

func _initialize_house_furniture() -> void:
	if SceneManager and SceneManager.has_saved_house_furniture:
		# Xóa các đồ nội thất mặc định để khôi phục đúng vị trí người chơi đã bài trí
		for node in get_tree().get_nodes_in_group("furniture_item"):
			if is_instance_valid(node) and node.get_parent() == self:
				node.free()

		var furn_scene := load(FURNITURE_SCENE_PATH) as PackedScene
		var furn_tex := load(FURNITURE_ATLAS_PATH) as Texture2D
		if furn_scene and furn_tex:
			for entry in SceneManager.saved_house_furniture:
				var item_node := furn_scene.instantiate() as Area2D
				add_child(item_node)
				item_node.global_position = entry.get("pos", Vector2(200, 120))
				item_node.rotation_degrees = float(entry.get("rot", 0.0))
				if "item_id" in item_node:
					item_node.item_id = str(entry.get("id", "furn_oak_chair"))
				if "item_name" in item_node:
					item_node.item_name = str(entry.get("name", "Home Furniture"))
				var spr := item_node.get_node_or_null("Sprite2D") as Sprite2D
				if spr:
					spr.texture = furn_tex
					spr.region_enabled = true
					spr.region_rect = entry.get("region", Rect2(0, 0, 16, 32))
					spr.flip_h = bool(entry.get("flip_h", false))
				if item_node.has_method("update_collision_from_sprite"):
					item_node.update_collision_from_sprite()
				if "previous_valid_position" in item_node:
					item_node.previous_valid_position = item_node.global_position
	else:
		save_furniture_state()

func save_furniture_state() -> void:
	if not SceneManager:
		return
	var saved_list: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("furniture_item"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.get_parent() != self:
			continue
		var spr := node.get_node_or_null("Sprite2D") as Sprite2D
		var reg := spr.region_rect if (spr and spr.region_enabled) else Rect2(0, 0, 16, 32)
		var flip_val := spr.flip_h if spr else false
		saved_list.append({
			"id": node.get("item_id") if "item_id" in node else "furn_oak_chair",
			"name": node.get("item_name") if "item_name" in node else "Home Furniture",
			"pos": (node as Node2D).global_position,
			"rot": (node as Node2D).rotation_degrees,
			"region": reg,
			"flip_h": flip_val
		})
	SceneManager.saved_house_furniture = saved_list
	SceneManager.has_saved_house_furniture = true
