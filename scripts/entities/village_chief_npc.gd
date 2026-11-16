extends CharacterBody2D

# NPC Trưởng Làng (Village Chief) tại Farm House 2
# Nhấp chuột trái vào NPC hoặc đứng gần bấm phím F / E để mở hội thoại

@export var npc_name: String = "Village Chief"
@export_multiline var dialogue_text: String = "I am currently the village chief. Please try to rescue those 5 contestants—they are being held captive. Good luck!"

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var interact_area: Area2D = get_node_or_null("Area2D")

var overhead_label: Label = null
var dialogue_layer: CanvasLayer = null
var dialogue_panel: Panel = null
var dialogue_content_lbl: RichTextLabel = null
var dialogue_name_lbl: Label = null
var dialogue_prompt_lbl: Label = null
var is_dialogue_open: bool = false
var player_nearby: bool = false
var typing_tween: Tween = null
var is_typing: bool = false

func _ready() -> void:
	add_to_group("npc")
	add_to_group("village_chief")
	
	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation("walk_down"):
			anim.animation = &"walk_down"
		anim.stop()
		anim.frame = 0

	_setup_overhead_ui()
	_setup_dialogue_ui()

	if interact_area:
		interact_area.body_entered.connect(_on_area_body_entered)
		interact_area.body_exited.connect(_on_area_body_exited)
		interact_area.input_event.connect(_on_area_input_event)

func _setup_overhead_ui() -> void:
	overhead_label = Label.new()
	overhead_label.name = "OverheadLabel"
	overhead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overhead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overhead_label.position = Vector2(-75, -42)
	overhead_label.size = Vector2(150, 18)
	overhead_label.add_theme_font_size_override("font_size", 9)
	overhead_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	overhead_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	overhead_label.add_theme_constant_override("shadow_offset_x", 1)
	overhead_label.add_theme_constant_override("shadow_offset_y", 1)
	overhead_label.text = "👑 " + npc_name
	add_child(overhead_label)

func _setup_dialogue_ui() -> void:
	dialogue_layer = CanvasLayer.new()
	dialogue_layer.layer = 100
	add_child(dialogue_layer)

	dialogue_panel = Panel.new()
	dialogue_panel.name = "VillageChiefDialoguePanel"
	dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_panel.offset_left = 60.0
	dialogue_panel.offset_right = -60.0
	dialogue_panel.offset_top = -125.0
	dialogue_panel.offset_bottom = -20.0

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.1, 0.06, 0.04, 0.94)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.95, 0.78, 0.35, 1.0)
	p_style.corner_radius_top_left = 8
	p_style.corner_radius_top_right = 8
	p_style.corner_radius_bottom_right = 8
	p_style.corner_radius_bottom_left = 8
	p_style.shadow_color = Color(0, 0, 0, 0.6)
	p_style.shadow_size = 8
	p_style.shadow_offset = Vector2(0, 4)
	dialogue_panel.add_theme_stylebox_override("panel", p_style)
	dialogue_layer.add_child(dialogue_panel)

	# Tên người nói
	dialogue_name_lbl = Label.new()
	dialogue_name_lbl.position = Vector2(16, 8)
	dialogue_name_lbl.size = Vector2(300, 20)
	dialogue_name_lbl.add_theme_font_size_override("font_size", 12)
	dialogue_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	dialogue_name_lbl.text = "👑 " + npc_name
	dialogue_panel.add_child(dialogue_name_lbl)

	# Nút đóng [X]
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(22, 22)
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -30.0
	close_btn.offset_top = 6.0
	close_btn.offset_right = -8.0
	close_btn.offset_bottom = 28.0
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(func(): close_dialogue())
	dialogue_panel.add_child(close_btn)

	# Nội dung hội thoại
	dialogue_content_lbl = RichTextLabel.new()
	dialogue_content_lbl.position = Vector2(16, 30)
	dialogue_content_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_content_lbl.offset_left = 16.0
	dialogue_content_lbl.offset_top = 30.0
	dialogue_content_lbl.offset_right = -16.0
	dialogue_content_lbl.offset_bottom = -24.0
	dialogue_content_lbl.add_theme_font_size_override("normal_font_size", 11)
	dialogue_content_lbl.add_theme_color_override("default_color", Color(1.0, 0.96, 0.9, 1.0))
	dialogue_content_lbl.bbcode_enabled = true
	dialogue_content_lbl.scroll_active = false
	dialogue_panel.add_child(dialogue_content_lbl)

	# Dòng chỉ dẫn tiếp tục
	dialogue_prompt_lbl = Label.new()
	dialogue_prompt_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dialogue_prompt_lbl.offset_left = -220.0
	dialogue_prompt_lbl.offset_top = -22.0
	dialogue_prompt_lbl.offset_right = -16.0
	dialogue_prompt_lbl.offset_bottom = -6.0
	dialogue_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_prompt_lbl.add_theme_font_size_override("font_size", 9)
	dialogue_prompt_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55, 0.85))
	dialogue_prompt_lbl.text = "[E / Space / Click] Close ▸"
	dialogue_panel.add_child(dialogue_prompt_lbl)

	dialogue_panel.visible = false

func open_dialogue() -> void:
	if not dialogue_panel:
		return
	is_dialogue_open = true
	dialogue_panel.visible = true
	dialogue_content_lbl.text = dialogue_text
	dialogue_content_lbl.visible_characters = 0
	is_typing = true

	if AudioManager:
		AudioManager.play_sfx("menu_open")

	if typing_tween and typing_tween.is_valid():
		typing_tween.kill()

	var duration: float = float(dialogue_text.length()) * 0.025
	typing_tween = create_tween()
	typing_tween.tween_property(dialogue_content_lbl, "visible_ratio", 1.0, duration).set_trans(Tween.TRANS_LINEAR)
	typing_tween.tween_callback(func():
		is_typing = false
	)

func close_dialogue() -> void:
	if not dialogue_panel:
		return
	is_dialogue_open = false
	dialogue_panel.visible = false
	if AudioManager:
		AudioManager.play_sfx("menu_close")

func _on_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		if overhead_label:
			overhead_label.text = "[Click / E] Talk 👑"
			overhead_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4, 1.0))

func _on_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		if overhead_label:
			overhead_label.text = "👑 " + npc_name
			overhead_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
		if is_dialogue_open:
			close_dialogue()

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_dialogue_open:
			if is_typing:
				if typing_tween and typing_tween.is_valid():
					typing_tween.kill()
				dialogue_content_lbl.visible_ratio = 1.0
				is_typing = false
			else:
				close_dialogue()
		else:
			open_dialogue()

func _unhandled_input(event: InputEvent) -> void:
	if not is_dialogue_open:
		if player_nearby and event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_E or event.physical_keycode == KEY_E or event.keycode == KEY_F or event.physical_keycode == KEY_F:
				open_dialogue()
				get_viewport().set_input_as_handled()
	else:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_F, KEY_ESCAPE]:
				if is_typing:
					if typing_tween and typing_tween.is_valid():
						typing_tween.kill()
					dialogue_content_lbl.visible_ratio = 1.0
					is_typing = false
				else:
					close_dialogue()
				get_viewport().set_input_as_handled()
