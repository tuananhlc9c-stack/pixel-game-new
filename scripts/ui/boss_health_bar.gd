class_name BossHealthBar
extends CanvasLayer

const BAR_WIDTH := 0.6        # tỉ lệ theo chiều ngang màn hình
const BAR_HEIGHT := 18.0
const TOP_MARGIN := 10.0

var hp_bar: ProgressBar
var trail_bar: ProgressBar
var title_label: Label
var hp_label: Label
var frame: PanelContainer

var _accent: Color = Color(0.9, 0.2, 0.35)
var _trail_tween: Tween
var _flash_tween: Tween
var _fill_style: StyleBoxFlat

func setup(title: String, accent: Color, max_hp: float, current_hp: float) -> void:
	_accent = accent
	layer = 20
	_build(title)
	hp_bar.max_value = max_hp
	trail_bar.max_value = max_hp
	hp_bar.value = current_hp
	trail_bar.value = current_hp
	_update_label()

func _build(title: String) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var box := VBoxContainer.new()
	box.anchor_left = (1.0 - BAR_WIDTH) * 0.5
	box.anchor_right = 1.0 - (1.0 - BAR_WIDTH) * 0.5
	box.anchor_top = 0.0
	box.anchor_bottom = 0.0
	box.offset_top = TOP_MARGIN
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	# Tên boss
	title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", _accent.lightened(0.35))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(title_label)

	# Khung viền ngoài
	frame = PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.04, 0.03, 0.05, 0.95)
	frame_style.set_border_width_all(2)
	frame_style.border_color = _accent.lightened(0.2)
	frame_style.set_corner_radius_all(4)
	frame_style.set_content_margin_all(3)
	frame_style.shadow_color = Color(0, 0, 0, 0.5)
	frame_style.shadow_size = 4
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.custom_minimum_size = Vector2(0, BAR_HEIGHT + 6)
	box.add_child(frame)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	frame.add_child(stack)

	# Thanh "vệt máu" (trễ) phía sau
	trail_bar = _make_bar(Color(0.12, 0.08, 0.1, 1.0), Color(1.0, 0.92, 0.75, 0.9))
	stack.add_child(trail_bar)

	# Thanh máu chính
	hp_bar = _make_bar(Color(0, 0, 0, 0), _accent)
	_fill_style = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	stack.add_child(hp_bar)

	# Dải sáng phía trên tạo cảm giác nổi khối
	var shine := ColorRect.new()
	shine.color = Color(1, 1, 1, 0.14)
	shine.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shine.offset_bottom = BAR_HEIGHT * 0.4
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(shine)

	# Số máu
	hp_label = Label.new()
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hp_label.add_theme_constant_override("outline_size", 3)
	stack.add_child(hp_label)

	hp_bar.value_changed.connect(_on_value_changed)

func _make_bar(bg: Color, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg
	bg_style.set_corner_radius_all(2)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	return bar

func _on_value_changed(value: float) -> void:
	trail_bar.max_value = hp_bar.max_value
	_update_label()
	if value < trail_bar.value:
		# Nháy trắng khi trúng đòn, vệt máu tụt từ từ phía sau
		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		_fill_style.bg_color = Color(1, 1, 1)
		_flash_tween = create_tween()
		_flash_tween.tween_property(_fill_style, "bg_color", _accent, 0.18)
		if _trail_tween and _trail_tween.is_valid():
			_trail_tween.kill()
		_trail_tween = create_tween()
		_trail_tween.tween_interval(0.35)
		_trail_tween.tween_property(trail_bar, "value", value, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		trail_bar.value = value

func _update_label() -> void:
	if hp_label:
		hp_label.text = "%d / %d" % [int(hp_bar.value), int(hp_bar.max_value)]

## Đổi màu thanh máu
func set_accent(color: Color) -> void:
	_accent = color
	if _fill_style:
		_fill_style.bg_color = color
