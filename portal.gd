extends Area2D

# Kéo thả file Scene map muốn chuyển tới vào đây
@export_file("*.tscn") var next_scene_path: String
# Tọa độ nhân vật sẽ đứng ở map mới
@export var target_spawn_position: Vector2 = Vector2.ZERO

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Kiểm tra nếu đúng là Player bước vào cổng
	if body.name == "Player" or body is CharacterBody2D:
		if next_scene_path != "":
			SceneManager.change_scene(next_scene_path, target_spawn_position)
