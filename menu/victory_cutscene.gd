extends CanvasLayer

# Victory Sequence Cutscene sau khi hạ gục Boss ở Danger 3
# Bước 1: Hiện ảnh "5 intity.png" + thoại "You have rescued 5 members to continue the journey."
# Bước 2: Hiện ảnh "victory.png" + thoại "They have won the championship."

@onready var bg_texture: TextureRect = $Background
@onready var text_label: RichTextLabel = $StoryPanel/MarginContainer/VBoxContainer/TextLabel
@onready var prompt_label: Label = $StoryPanel/MarginContainer/VBoxContainer/HBoxBottom/PromptLabel
@onready var continue_btn: Button = $StoryPanel/MarginContainer/VBoxContainer/HBoxBottom/ContinueBtn
@onready var fade_rect: ColorRect = $FadeRect

const CUTSCENE_PAGES: Array[Dictionary] = [
	{
		"texture": "res://Content T1/New/tool/5 intity.png",
		"text": "You have rescued 5 members to continue the journey.",
		"btn": "Continue ▸"
	},
	{
		"texture": "res://Content T1/New/tool/victory.png",
		"text": "They have won the championship.",
		"btn": "🏆 Complete"
	}
]

var current_step: int = 0
var is_typing: bool = false
var typing_tween: Tween = null
var is_transitioning: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_btn.pressed.connect(_advance_cutscene)
	continue_btn.mouse_entered.connect(func():
		if AudioManager:
			AudioManager.play_sfx("select")
	)
	_start_prompt_blink()
	_show_step(0)

func _input(event: InputEvent) -> void:
	if is_transitioning:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_F]:
			_advance_cutscene()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_cutscene()
		get_viewport().set_input_as_handled()

func _show_step(idx: int) -> void:
	if idx >= CUTSCENE_PAGES.size():
		_finish_victory()
		return

	current_step = idx
	var data: Dictionary = CUTSCENE_PAGES[current_step]
	
	var tex_res = load(str(data["texture"])) as Texture2D
	if tex_res:
		bg_texture.texture = tex_res

	var full_text: String = str(data["text"])
	text_label.text = full_text
	text_label.visible_characters = 0
	is_typing = true

	if typing_tween and typing_tween.is_valid():
		typing_tween.kill()

	var duration: float = float(full_text.length()) * 0.03
	typing_tween = create_tween()
	typing_tween.tween_property(text_label, "visible_ratio", 1.0, duration).set_trans(Tween.TRANS_LINEAR)
	typing_tween.tween_callback(func():
		is_typing = false
		if current_step == CUTSCENE_PAGES.size() - 1:
			prompt_label.text = "[E / Click] Finish ▸"
			continue_btn.text = str(data["btn"])
		else:
			prompt_label.text = "[E / Click] Continue ▸ (%d/%d)" % [current_step + 1, CUTSCENE_PAGES.size()]
			continue_btn.text = str(data["btn"])
	)

func _advance_cutscene() -> void:
	if is_typing:
		if typing_tween and typing_tween.is_valid():
			typing_tween.kill()
		text_label.visible_ratio = 1.0
		is_typing = false
		var data: Dictionary = CUTSCENE_PAGES[current_step]
		if current_step == CUTSCENE_PAGES.size() - 1:
			prompt_label.text = "[E / Click] Finish ▸"
			continue_btn.text = str(data["btn"])
		else:
			prompt_label.text = "[E / Click] Continue ▸ (%d/%d)" % [current_step + 1, CUTSCENE_PAGES.size()]
			continue_btn.text = str(data["btn"])
		if AudioManager:
			AudioManager.play_sfx("select")
	else:
		if AudioManager:
			AudioManager.play_sfx("click")
		if current_step + 1 < CUTSCENE_PAGES.size():
			_show_step(current_step + 1)
		else:
			_finish_victory()

func _finish_victory() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	if AudioManager:
		AudioManager.play_sfx("menu_close")

	fade_rect.visible = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	# Sau khi kết thúc đoạn dẫn truyện/cutscene chiến thắng, người chơi vẫn ở lại map Danger 3 để loot hòm hoặc khám phá tiếp
	var tw_out := create_tween()
	tw_out.tween_property(fade_rect, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_out.finished

	queue_free()

func _start_prompt_blink() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(prompt_label, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(prompt_label, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
