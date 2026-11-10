extends Area2D

@export var barn_title: String = "Goat Barn"
@export var product_id: String = "goat_milk"
@export var product_name: String = "Goat Milk"
@export var product_short_label: String = "Milk"
@export var product_scene_path: String = "res://scenes/objects/goat_milk_item.tscn"
@export var product_icon_region: Rect2 = Rect2(16, 0, 16, 16)
@export var milk_duration: float = 10.0

enum State { IDLE, PRODUCING, READY }
var current_state: State = State.IDLE
var time_left: float = 0.0

var ui_panel: Panel
var title_label: Label
var status_label: Label
var action_btn: Button
var close_btn: Button
var overhead_hint: Label

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	_build_ui()

func _build_ui() -> void:
	# Nhãn nhỏ báo hiệu trên mái chuồng khi thu hoạch sẵn sàng
	overhead_hint = Label.new()
	overhead_hint.name = "OverheadHint"
	overhead_hint.text = "%s Ready!" % product_short_label
	overhead_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overhead_hint.position = Vector2(-50, -78)
	overhead_hint.size = Vector2(100, 20)
	overhead_hint.z_index = 25
	overhead_hint.add_theme_font_size_override("font_size", 10)
	overhead_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35, 1.0))
	overhead_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02, 1.0))
	overhead_hint.add_theme_constant_override("outline_size", 3)
	overhead_hint.visible = false
	add_child(overhead_hint)

	# Bảng điều khiển hiện ra khi bấm vào chuồng
	ui_panel = Panel.new()
	ui_panel.name = "BarnPopup"
	ui_panel.position = Vector2(-75, -125)
	ui_panel.size = Vector2(150, 84)
	ui_panel.z_index = 40
	ui_panel.visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.12, 0.07, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.82, 0.58, 0.3, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	ui_panel.add_theme_stylebox_override("panel", style)
	add_child(ui_panel)

	title_label = Label.new()
	title_label.text = barn_title
	title_label.position = Vector2(10, 5)
	title_label.size = Vector2(110, 18)
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65, 1.0))
	ui_panel.add_child(title_label)

	close_btn = Button.new()
	close_btn.text = "X"
	close_btn.flat = true
	close_btn.position = Vector2(126, 2)
	close_btn.size = Vector2(20, 20)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(func(): ui_panel.visible = false)
	ui_panel.add_child(close_btn)

	status_label = Label.new()
	status_label.text = "Ready to produce"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(6, 25)
	status_label.size = Vector2(138, 20)
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	ui_panel.add_child(status_label)

	action_btn = Button.new()
	action_btn.text = "Start %s" % product_short_label
	action_btn.position = Vector2(20, 48)
	action_btn.size = Vector2(110, 26)
	action_btn.add_theme_font_size_override("font_size", 10)
	action_btn.pressed.connect(_on_action_btn_pressed)
	ui_panel.add_child(action_btn)

	_refresh_ui()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ui_panel.visible = not ui_panel.visible
		_refresh_ui()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if current_state == State.PRODUCING:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			current_state = State.READY
			if overhead_hint:
				overhead_hint.visible = true
			_refresh_ui()
		else:
			if status_label and ui_panel.visible:
				status_label.text = "%s in: %.1fs" % [product_short_label, time_left]

func _on_action_btn_pressed() -> void:
	if current_state == State.IDLE:
		current_state = State.PRODUCING
		time_left = milk_duration
		if overhead_hint:
			overhead_hint.visible = false
		_refresh_ui()
	elif current_state == State.READY:
		_collect_product()

func _collect_product() -> void:
	var food_tex: Texture2D = load("res://Content T1/Loose/Fish-food.png") as Texture2D
	var prod_scene: PackedScene = load(product_scene_path) as PackedScene
	var prod_icon: AtlasTexture = AtlasTexture.new()
	prod_icon.atlas = food_tex
	prod_icon.region = product_icon_region

	var inv = get_tree().get_first_node_in_group("inventory")
	if inv and inv.has_method("add_item"):
		if inv.add_item(prod_icon, prod_scene, product_id, product_name):
			current_state = State.IDLE
			if overhead_hint:
				overhead_hint.visible = false
			_refresh_ui()
			status_label.text = "Received: %s!" % product_name
		else:
			status_label.text = "Inventory Full!"

func _refresh_ui() -> void:
	if not status_label or not action_btn:
		return

	match current_state:
		State.IDLE:
			status_label.text = "Click button to start"
			action_btn.text = "Start %s" % product_short_label
			action_btn.disabled = false
		State.PRODUCING:
			status_label.text = "%s in: %.1fs" % [product_short_label, time_left]
			action_btn.text = "Producing..."
			action_btn.disabled = true
		State.READY:
			status_label.text = "%s is ready!" % product_name
			action_btn.text = "Collect %s" % product_short_label
			action_btn.disabled = false
