extends Node

# Vị trí xuất hiện của nhân vật ở map tiếp theo
var spawn_position: Vector2 = Vector2.ZERO
var use_spawn_position: bool = false

func change_scene(scene_path: String, target_pos: Vector2):
	spawn_position = target_pos
	use_spawn_position = true
	get_tree().change_scene_to_file(scene_path)
