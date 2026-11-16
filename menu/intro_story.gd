extends Control

@onready var bg_texture: TextureRect = $Background
@onready var text_label: RichTextLabel = $StoryPanel/MarginContainer/VBoxContainer/TextLabel
@onready var prompt_label: Label = $StoryPanel/MarginContainer/VBoxContainer/HBoxBottom/PromptLabel
@onready var continue_btn: Button = $StoryPanel/MarginContainer/VBoxContainer/HBoxBottom/ContinueBtn

# 3 đoạn dẫn truyện theo nội dung
const STORY_PAGES: Array[String] = [
	"Once upon a time, in the kingdom of E-Sportia, people lived in peace, with T1 standing as a symbol of strength and hope.\n\nDuring the World Championship finals, a devoted T1 fan—while watching the match—was suddenly pulled into the screen and plunged into a dark, foreboding world.",
	"There, a malevolent entity known as \"ANTI-FAN\"—a creature that feeds on online hatred and psychological pressure—laid an ambush, capturing all five members of T1 and imprisoning them in a dungeon.",
	"Driven by the unwavering faith of a true supporter, the fan embarked on a journey across E-Sportia: gathering resources, crafting gear to combat the darkness, and defeating the sinister guardians.\n\nUltimately, the fan confronted ANTI-FAN in a decisive battle to rescue the five players. As ANTI-FAN was defeated, the darkness began to dissipate, revealing that this world was, in fact, the inner minds of the players themselves—and that the fan served as the final spark of hope, empowering them to keep moving forward.\n\nAwakening in a mysterious pixel realm, the journey begins..."
]

var current_page: int = 0
var is_typing: bool = false
var typing_tween: Tween = null
var is_transitioning: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_btn.pressed.connect(_advance_story)
	continue_btn.mouse_entered.connect(func():
		if AudioManager:
			AudioManager.play_sfx("select")
	)
	_start_prompt_blink()
	_display_page(0)

func _input(event: InputEvent) -> void:
	if is_transitioning:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Nhấn phím E hoặc Space / Enter để tiếp tục
		if event.keycode == KEY_E or event.physical_keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_advance_story()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Click chuột trái cũng có thể tương tác tiếp
		_advance_story()
		get_viewport().set_input_as_handled()

func _display_page(index: int) -> void:
	if index >= STORY_PAGES.size():
		_go_to_farm_house()
		return

	current_page = index
	var full_text: String = STORY_PAGES[current_page]
	text_label.text = full_text
	text_label.visible_characters = 0
	is_typing = true

	if typing_tween and typing_tween.is_valid():
		typing_tween.kill()

	# Hiệu ứng gõ chữ Typewriter mượt mà
	var duration: float = float(full_text.length()) * 0.02
	typing_tween = create_tween()
	typing_tween.tween_property(text_label, "visible_ratio", 1.0, duration).set_trans(Tween.TRANS_LINEAR)
	typing_tween.tween_callback(func():
		is_typing = false
		if current_page == STORY_PAGES.size() - 1:
			prompt_label.text = "[E] Begin Journey (Farm House) ▸"
			continue_btn.text = "⚔️ Start Adventure"
		else:
			prompt_label.text = "[E] Continue ▸ (%d/%d)" % [current_page + 1, STORY_PAGES.size()]
			continue_btn.text = "Continue ▸"
	)

func _advance_story() -> void:
	if is_typing:
		# If typing animation is running, pressing E finishes it immediately
		if typing_tween and typing_tween.is_valid():
			typing_tween.kill()
		text_label.visible_ratio = 1.0
		is_typing = false
		if current_page == STORY_PAGES.size() - 1:
			prompt_label.text = "[E] Begin Journey (Farm House) ▸"
			continue_btn.text = "⚔️ Start Adventure"
		else:
			prompt_label.text = "[E] Continue ▸ (%d/%d)" % [current_page + 1, STORY_PAGES.size()]
			continue_btn.text = "Continue ▸"
		if AudioManager:
			AudioManager.play_sfx("select")
	else:
		# Đã hiện xong trang hiện tại, chuyển sang trang tiếp theo hoặc kết thúc
		if AudioManager:
			AudioManager.play_sfx("click")
		if current_page + 1 < STORY_PAGES.size():
			_display_page(current_page + 1)
		else:
			_go_to_farm_house()

func _go_to_farm_house() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	
	if AudioManager:
		AudioManager.play_sfx("menu_close")
	
	# Mờ dần màn hình chuyển cảnh vào farm house
	var fade_rect: ColorRect = $FadeRect
	fade_rect.visible = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/maps/farm house.tscn")

func _start_prompt_blink() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(prompt_label, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(prompt_label, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
