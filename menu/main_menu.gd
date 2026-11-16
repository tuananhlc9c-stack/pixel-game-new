extends Control

@onready var new_game_btn: Button = $VBoxButtons/NewGameBtn
@onready var continue_btn: Button = $VBoxButtons/ContinueBtn
@onready var quit_btn: Button = $VBoxButtons/QuitBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Kiểm tra xem đã có save game chưa để kích hoạt hoặc làm mờ nút Continue
	var can_continue: bool = false
	if SceneManager and SceneManager.has_method("has_save_file"):
		can_continue = SceneManager.has_save_file()
	
	continue_btn.disabled = not can_continue
	if not can_continue:
		continue_btn.modulate = Color(0.65, 0.65, 0.65, 0.45)
	else:
		continue_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	new_game_btn.mouse_entered.connect(func(): _play_hover_sound())
	continue_btn.mouse_entered.connect(func(): if can_continue: _play_hover_sound())
	quit_btn.mouse_entered.connect(func(): _play_hover_sound())

	_setup_button_hover_effects()

func _play_hover_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("select")

func _on_new_game_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("click")
	if SceneManager and SceneManager.has_method("reset_for_new_game"):
		SceneManager.reset_for_new_game()
	get_tree().change_scene_to_file("res://menu/intro_story.tscn")

func _on_continue_pressed() -> void:
	if continue_btn.disabled:
		return
	if AudioManager:
		AudioManager.play_sfx("click")
	if SceneManager and SceneManager.has_method("load_game"):
		SceneManager.load_game()
	
	var target_map: String = "res://scenes/maps/farm house.tscn"
	if SceneManager and SceneManager.saved_map_scene_path != "":
		target_map = SceneManager.saved_map_scene_path
	
	get_tree().change_scene_to_file(target_map)

func _on_quit_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("menu_close")
	get_tree().quit()

func _setup_button_hover_effects() -> void:
	for btn in [new_game_btn, continue_btn, quit_btn]:
		btn.pivot_offset = btn.size * 0.5
		btn.mouse_entered.connect(func():
			if not btn.disabled:
				var tw := create_tween()
				tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
		btn.mouse_exited.connect(func():
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)
