extends Area2D

const CROPS_DATA: Array[Dictionary] = [
	{
		"id": "crop_parsnip",
		"name": "Parsnip",
		"display_name": "Parsnip",
		"growth_time": 60.0,
		"price": 35,
		"row": 0,
		"seed_col": 0,
		"harvest_col": 4,
		"mature_y_offset": 0
	},
	{
		"id": "crop_green_bean",
		"name": "Green Bean",
		"display_name": "Green Bean",
		"growth_time": 70.0,
		"price": 40,
		"row": 1,
		"seed_col": 0,
		"harvest_col": 4,
		"mature_y_offset": 0
	},
	{
		"id": "crop_cauliflower",
		"name": "Cauliflower",
		"display_name": "Cauliflower",
		"growth_time": 90.0,
		"price": 85,
		"row": 2,
		"seed_col": 0,
		"harvest_col": 5,
		"mature_y_offset": 0
	},
	{
		"id": "crop_potato",
		"name": "Potato",
		"display_name": "Potato",
		"growth_time": 65.0,
		"price": 50,
		"row": 3,
		"seed_col": 0,
		"harvest_col": 5,
		"mature_y_offset": 0
	},
	{
		"id": "crop_garlic",
		"name": "Garlic",
		"display_name": "Garlic",
		"growth_time": 60.0,
		"price": 45,
		"row": 4,
		"seed_col": 0,
		"harvest_col": 4,
		"mature_y_offset": 0
	},
	{
		"id": "crop_kale",
		"name": "Kale",
		"display_name": "Kale",
		"growth_time": 75.0,
		"price": 60,
		"row": 5,
		"seed_col": 0,
		"harvest_col": 4,
		"mature_y_offset": 0
	},
	{
		"id": "crop_rhubarb",
		"name": "Rhubarb",
		"display_name": "Rhubarb",
		"growth_time": 100.0,
		"price": 110,
		"row": 6,
		"seed_col": 0,
		"harvest_col": 5,
		"mature_y_offset": 0
	},
	{
		"id": "crop_melon",
		"name": "Melon",
		"display_name": "Melon",
		"growth_time": 120.0,
		"price": 140,
		"row": 7,
		"seed_col": 0,
		"harvest_col": 5,
		"mature_y_offset": 0
	},
	{
		"id": "crop_tomato",
		"name": "Tomato",
		"display_name": "Tomato",
		"growth_time": 80.0,
		"price": 65,
		"row": 8,
		"seed_col": 0,
		"harvest_col": 5,
		"mature_y_offset": 0
	},
	{
		"id": "crop_blueberry",
		"name": "Blueberry",
		"display_name": "Blueberry",
		"growth_time": 90.0,
		"price": 80,
		"row": 9,
		"seed_col": 0,
		"harvest_col": 5,
		"mature_y_offset": 0
	}
]

enum State { IDLE, GROWING, READY }

var current_state: State = State.IDLE
var selected_crop_index: int = -1
var time_left: float = 0.0
var total_growth_time: float = 60.0

var ui_canvas: CanvasLayer
var ui_panel: PanelContainer
var crop_list_container: VBoxContainer
var status_banner: Label
var active_crop_label: Label
var progress_bar: ProgressBar
var harvest_btn: Button
var overhead_hint: Label

var crops_texture: Texture2D

func _ready() -> void:
	crops_texture = load("res://Content T1/Tilesheet/crops.png") as Texture2D
	input_pickable = true
	input_event.connect(_on_input_event)
	_build_overhead_hint()
	_build_ui()

func _build_overhead_hint() -> void:
	overhead_hint = Label.new()
	overhead_hint.name = "GreenhouseOverheadHint"
	overhead_hint.text = "🌿 Crop Ready! Click to Harvest"
	overhead_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overhead_hint.position = Vector2(-100, -80)
	overhead_hint.size = Vector2(200, 22)
	overhead_hint.z_index = 30
	overhead_hint.add_theme_font_size_override("font_size", 11)
	overhead_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35, 1.0))
	overhead_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.03, 1.0))
	overhead_hint.add_theme_constant_override("outline_size", 4)
	overhead_hint.visible = false
	add_child(overhead_hint)

func _build_ui() -> void:
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 55
	add_child(ui_canvas)

	ui_panel = PanelContainer.new()
	ui_panel.name = "GreenhousePanel"
	ui_panel.visible = false
	ui_panel.custom_minimum_size = Vector2(460, 420)
	ui_panel.anchors_preset = Control.PRESET_CENTER
	ui_panel.anchor_left = 0.5
	ui_panel.anchor_top = 0.5
	ui_panel.anchor_right = 0.5
	ui_panel.anchor_bottom = 0.5
	ui_panel.offset_left = -230
	ui_panel.offset_top = -210
	ui_panel.offset_right = 230
	ui_panel.offset_bottom = 210

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.17, 0.13, 0.96)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.42, 0.78, 0.45, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	ui_panel.add_theme_stylebox_override("panel", style)
	ui_canvas.add_child(ui_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	ui_panel.add_child(main_vbox)

	# --- Header ---
	var header_hbox := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "🌱 GREENHOUSE CROP GARDEN"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.8, 1.0))
	header_hbox.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = " X "
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func(): ui_panel.visible = false)
	header_hbox.add_child(close_btn)
	main_vbox.add_child(header_hbox)

	# --- Banner trạng thái hiện tại ---
	var banner_panel := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.08, 0.12, 0.08, 0.9)
	b_style.border_width_left = 1
	b_style.border_width_top = 1
	b_style.border_width_right = 1
	b_style.border_width_bottom = 1
	b_style.border_color = Color(0.3, 0.5, 0.3, 0.8)
	b_style.corner_radius_top_left = 5
	b_style.corner_radius_top_right = 5
	b_style.corner_radius_bottom_right = 5
	b_style.corner_radius_bottom_left = 5
	b_style.content_margin_left = 8
	b_style.content_margin_top = 6
	b_style.content_margin_right = 8
	b_style.content_margin_bottom = 6
	banner_panel.add_theme_stylebox_override("panel", b_style)

	var banner_vbox := VBoxContainer.new()
	banner_vbox.add_theme_constant_override("separation", 4)

	active_crop_label = Label.new()
	active_crop_label.text = "Soil is empty. Choose a crop below to plant!"
	active_crop_label.add_theme_font_size_override("font_size", 11)
	active_crop_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	banner_vbox.add_child(active_crop_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 14)
	progress_bar.show_percentage = false
	progress_bar.value = 0.0
	banner_vbox.add_child(progress_bar)

	var act_hbox := HBoxContainer.new()
	status_banner = Label.new()
	status_banner.text = "Time left: 0s"
	status_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_banner.add_theme_font_size_override("font_size", 10)
	status_banner.add_theme_color_override("font_color", Color(0.8, 0.85, 0.8, 1.0))
	act_hbox.add_child(status_banner)

	harvest_btn = Button.new()
	harvest_btn.text = "Harvest Crop"
	harvest_btn.disabled = true
	harvest_btn.add_theme_font_size_override("font_size", 11)
	harvest_btn.pressed.connect(_on_harvest_pressed)
	act_hbox.add_child(harvest_btn)

	banner_vbox.add_child(act_hbox)
	banner_panel.add_child(banner_vbox)
	main_vbox.add_child(banner_panel)

	# --- Tiêu đề danh sách cây ---
	var sub_title := Label.new()
	sub_title.text = "▼ SELECT CROP TO PLANT (Grow Time: 1 - 2 mins):"
	sub_title.add_theme_font_size_override("font_size", 10)
	sub_title.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7, 1.0))
	main_vbox.add_child(sub_title)

	# --- ScrollContainer danh sách cây ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	crop_list_container = VBoxContainer.new()
	crop_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crop_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(crop_list_container)

	_populate_crop_list()
	_update_ui_state()

func _populate_crop_list() -> void:
	for child in crop_list_container.get_children():
		child.queue_free()

	for i in range(CROPS_DATA.size()):
		var data: Dictionary = CROPS_DATA[i]
		var row := _create_crop_row(i, data)
		crop_list_container.add_child(row)

func _create_crop_row(index: int, data: Dictionary) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 36)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.18, 0.23, 0.18, 0.85)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.border_color = Color(0.3, 0.45, 0.3, 0.6)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.content_margin_left = 6
	row_style.content_margin_top = 4
	row_style.content_margin_right = 6
	row_style.content_margin_bottom = 4
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	# Icon quả chín
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var atlas := AtlasTexture.new()
	atlas.atlas = crops_texture
	var row_idx: int = int(data.get("row", 0))
	var col_idx: int = int(data.get("harvest_col", 4))
	atlas.region = Rect2(col_idx * 16, row_idx * 32, 16, 32)
	icon_rect.texture = atlas
	hbox.add_child(icon_rect)

	# Tên + Thời gian
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 1)

	var name_lbl := Label.new()
	name_lbl.text = str(data.get("display_name", data.get("name", "")))
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	info_vbox.add_child(name_lbl)

	var sub_lbl := Label.new()
	var g_time: float = float(data.get("growth_time", 60.0))
	var minutes := int(g_time) / 60
	var seconds := int(g_time) % 60
	var time_str := "%dm %ds" % [minutes, seconds] if minutes > 0 else "%ds" % seconds
	sub_lbl.text = "Grow Time: %s | Sell Price: %dG" % [time_str, int(data.get("price", 35))]
	sub_lbl.add_theme_font_size_override("font_size", 9)
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75, 1.0))
	info_vbox.add_child(sub_lbl)

	hbox.add_child(info_vbox)

	# Nút Trồng
	var plant_btn := Button.new()
	plant_btn.text = "Plant"
	plant_btn.name = "PlantBtn_%d" % index
	plant_btn.custom_minimum_size = Vector2(80, 26)
	plant_btn.add_theme_font_size_override("font_size", 10)
	plant_btn.pressed.connect(_on_plant_crop_selected.bind(index))
	hbox.add_child(plant_btn)

	return row_panel

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ui_panel.visible = not ui_panel.visible
		_update_ui_state()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if current_state == State.GROWING:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			current_state = State.READY
			if overhead_hint:
				overhead_hint.visible = true
			_update_ui_state()
		else:
			if ui_panel and ui_panel.visible:
				_update_progress_display()

func _on_plant_crop_selected(index: int) -> void:
	if current_state != State.IDLE:
		return
	if index < 0 or index >= CROPS_DATA.size():
		return

	selected_crop_index = index
	var data: Dictionary = CROPS_DATA[index]
	total_growth_time = float(data.get("growth_time", 60.0))
	time_left = total_growth_time
	current_state = State.GROWING

	if overhead_hint:
		overhead_hint.visible = false
	_update_ui_state()

func _on_harvest_pressed() -> void:
	if current_state != State.READY or selected_crop_index < 0:
		return
	if selected_crop_index >= CROPS_DATA.size():
		return

	var crop_info: Dictionary = CROPS_DATA[selected_crop_index]
	var crop_id: String = str(crop_info.get("id", ""))
	var crop_name: String = str(crop_info.get("name", ""))
	var row_idx: int = int(crop_info.get("row", 0))
	var col_idx: int = int(crop_info.get("harvest_col", 4))

	var crop_icon := AtlasTexture.new()
	crop_icon.atlas = crops_texture
	crop_icon.region = Rect2(col_idx * 16, row_idx * 32, 16, 32)

	var crop_scene := load("res://scenes/objects/crop_item.tscn") as PackedScene

	var inv = get_tree().get_first_node_in_group("inventory")
	if inv and inv.has_method("add_item"):
		if inv.add_item(crop_icon, crop_scene, crop_id, crop_name):
			current_state = State.IDLE
			selected_crop_index = -1
			time_left = 0.0
			if overhead_hint:
				overhead_hint.visible = false
			_update_ui_state()
			status_banner.text = "Harvested +1 %s to inventory!" % crop_name
			status_banner.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))
		else:
			status_banner.text = "Inventory Full! Free up space to harvest."
			status_banner.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4, 1.0))

func _update_progress_display() -> void:
	if not progress_bar or not status_banner:
		return
	var denom: float = maxf(total_growth_time, 0.001)
	var ratio: float = 1.0 - (time_left / denom)
	progress_bar.value = clampf(ratio * 100.0, 0.0, 100.0)
	var mins: int = int(time_left) / 60
	var secs: int = int(time_left) % 60
	status_banner.text = "Growing... Time left: %02d:%02d" % [mins, secs]
	status_banner.add_theme_color_override("font_color", Color(0.95, 0.95, 0.7, 1.0))

func _update_ui_state() -> void:
	if not ui_panel:
		return

	match current_state:
		State.IDLE:
			active_crop_label.text = "Soil is empty. Choose a crop below to plant!"
			active_crop_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
			progress_bar.value = 0.0
			status_banner.text = "Status: Ready to plant"
			status_banner.add_theme_color_override("font_color", Color(0.8, 0.85, 0.8, 1.0))
			harvest_btn.disabled = true
			_set_plant_buttons_enabled(true)

		State.GROWING:
			if selected_crop_index >= 0 and selected_crop_index < CROPS_DATA.size():
				var data: Dictionary = CROPS_DATA[selected_crop_index]
				active_crop_label.text = "Currently Growing: %s" % str(data.get("display_name", ""))
			active_crop_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7, 1.0))
			_update_progress_display()
			harvest_btn.disabled = true
			_set_plant_buttons_enabled(false)

		State.READY:
			if selected_crop_index >= 0 and selected_crop_index < CROPS_DATA.size():
				var data: Dictionary = CROPS_DATA[selected_crop_index]
				active_crop_label.text = "✨ %s IS MATURE AND READY TO HARVEST! ✨" % str(data.get("display_name", "")).to_upper()
			active_crop_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35, 1.0))
			progress_bar.value = 100.0
			status_banner.text = "Done! Click 'Harvest Crop' to collect."
			status_banner.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))
			harvest_btn.disabled = false
			_set_plant_buttons_enabled(false)

func _set_plant_buttons_enabled(enabled: bool) -> void:
	if not crop_list_container:
		return
	for row in crop_list_container.get_children():
		var btn = row.find_child("PlantBtn_*", true, false)
		if btn is Button:
			btn.disabled = not enabled
