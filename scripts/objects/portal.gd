extends Area2D

# Kéo thả file Scene map muốn chuyển tới vào đây
@export_file("*.tscn") var next_scene_path: String
# Tọa độ nhân vật sẽ đứng ở map mới
@export var target_spawn_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("portal")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Chỉ cho phép Player kích hoạt cổng dịch chuyển (tránh quái vật/NPC tự kích hoạt)
	if body.is_in_group("player") or body.name == "Player":
		if SceneManager and SceneManager.portal_cooldown > 0.0:
			return
		if next_scene_path != "":
			SceneManager.change_scene(next_scene_path, target_spawn_position)
