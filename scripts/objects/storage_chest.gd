extends StaticBody2D

const CHEST_SLOT_COUNT: int = 40
const CHEST_TEXTURE_PATH := "res://Content T1/Loose/Cursors 2.png"
const SLOT_BG_PATH := "res://Content T1/New/tool/menu1.png"

const CHEST_FRAMES: Array[Rect2] = [
	Rect2(256, 75, 32, 30),
	Rect2(288, 75, 32, 30),
	Rect2(320, 75, 32, 30),
	Rect2(352, 75, 32, 30)
]

const SLOT_NORMAL_COLOR := Color(0.92, 0.88, 0.82, 1.0)
const SLOT_HOVER_COLOR := Color(1.08, 1.02, 0.92, 1.0)

@onready var chest_sprite: Sprite2D = $ChestSprite if has_node("ChestSprite") else null

var chest_data: Array = []
var chest_slots: Array[Control] = []
var is_open: bool = false
var is_mouse_hovering: bool = false
var anim_frame_idx: int = 0
var anim_tween: Tween = null

var prompt_label: Label = null
var ui_layer: CanvasLayer = null
var chest_panel: Panel = null
var count_label: Label = null
var status_label: Label = null

# Drag & Drop helper script cho từng ô trong Rương
class ChestSlotControl extends TextureRect:
	var slot_index: int = -1
	var chest_owner: Node = null

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if not chest_owner or slot_index < 0 or slot_index >= chest_owner.chest_data.size():
			return null
		var data = chest_owner.chest_data[slot_index]
		if data == null:
			return null

		var preview_texture := TextureRect.new()
		preview_texture.texture = data.get("icon")
		preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_texture.size = Vector2(36, 36)

		var preview_control := Control.new()
		preview_control.add_child(preview_texture)
		preview_texture.position = -0.5 * preview_texture.size
		set_drag_preview(preview_control)

		return {
			"from_chest_slot": slot_index,
			"chest_ref": chest_owner
		}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false
		return data.has("from_slot") or data.has("from_chest_slot")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not chest_owner or typeof(data) != TYPE_DICTIONARY:
			return
		if data.has("from_slot"):
			var inv = get_tree().get_first_node_in_group("inventory")
			if inv:
				inv.dropped_inside_slot = true
			chest_owner.transfer_or_swap_from_inventory(int(data["from_slot"]), slot_index)
		elif data.has("from_chest_slot"):
			var from_c_idx := int(data["from_chest_slot"])
			if from_c_idx != slot_index:
				chest_owner.swap_chest_slots(from_c_idx, slot_index)

	func _gui_input(event: InputEvent) -> void:
		if not chest_owner:
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.double_click) or (event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed):
				chest_owner.quick_take_to_inventory(slot_index)
				accept_event()

func _ready() -> void:
	add_to_group("storage_chest")
	add_to_group("world_pickup_item")
	y_sort_enabled = true

	chest_data.resize(CHEST_SLOT_COUNT)
	for i in range(CHEST_SLOT_COUNT):
		chest_data[i] = null

	if SceneManager and SceneManager.saved_chest_data.size() == CHEST_SLOT_COUNT:
		chest_data = SceneManager.saved_chest_data.duplicate(true)
	elif SceneManager:
		SceneManager.saved_chest_data = chest_data.duplicate(true)

	_setup_prompt_label()
	_setup_chest_ui()
	_refresh_all_chest_slots()
	_set_chest_frame(0)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var near_player := false
	if player:
		var dist := global_position.distance_to(player.global_position)
		near_player = dist <= 72.0
		if is_open and dist > 135.0:
			close_chest()

	var world_mouse := get_global_mouse_position()
	is_mouse_hovering = is_point_over_item(world_mouse)

	if prompt_label:
		prompt_label.visible = (near_player or is_mouse_hovering) and not is_open

	if chest_sprite:
		if (near_player or is_mouse_hovering) and not is_open:
			chest_sprite.modulate = Color(1.12, 1.08, 0.98, 1.0)
		else:
			chest_sprite.modulate = Color.WHITE

func is_point_over_item(world_pt: Vector2) -> bool:
	var local_pt := to_local(world_pt)
	return Rect2(-18, -26, 36, 32).has_point(local_pt)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F or event.physical_keycode == KEY_F:
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if is_open:
				close_chest()
				get_viewport().set_input_as_handled()
				return
			elif player and global_position.distance_to(player.global_position) <= 80.0:
				open_chest()
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_ESCAPE and is_open:
			close_chest()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if is_point_over_item(get_global_mouse_position()):
				var player := get_tree().get_first_node_in_group("player") as Node2D
				if not player or global_position.distance_to(player.global_position) <= 160.0:
					if is_open:
						close_chest()
					else:
						open_chest()
					get_viewport().set_input_as_handled()

func open_chest() -> void:
	if is_open:
		return
	is_open = true
	_animate_chest_lid(true)
	_refresh_all_chest_slots()

	if chest_panel:
		_layout_chest_and_bag_windows(true)
		chest_panel.visible = true
		chest_panel.pivot_offset = chest_panel.size * 0.5
		chest_panel.scale = Vector2(0.92, 0.92)
		chest_panel.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(chest_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(chest_panel, "modulate:a", 1.0, 0.12)

func close_chest() -> void:
	if not is_open:
		return
	is_open = false
	_animate_chest_lid(false)
	_layout_chest_and_bag_windows(false)

	if chest_panel:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(chest_panel, "scale", Vector2(0.94, 0.94), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(chest_panel, "modulate:a", 0.0, 0.1)
		await tw.finished
		if is_instance_valid(chest_panel) and not is_open:
			chest_panel.visible = false
			chest_panel.scale = Vector2.ONE
			chest_panel.modulate.a = 1.0

func _layout_chest_and_bag_windows(opening: bool) -> void:
	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv:
		return
	if inv.has_method("set_chest_dual_view"):
		inv.set_chest_dual_view(opening, chest_panel)

func _animate_chest_lid(opening: bool) -> void:
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()
	anim_tween = create_tween()
	if opening:
		for f in [1, 2, 3]:
			anim_tween.tween_callback(_set_chest_frame.bind(f)).set_delay(0.045)
	else:
		for f in [2, 1, 0]:
			anim_tween.tween_callback(_set_chest_frame.bind(f)).set_delay(0.045)

func _set_chest_frame(frame_idx: int) -> void:
	anim_frame_idx = clampi(frame_idx, 0, CHEST_FRAMES.size() - 1)
	if chest_sprite:
		chest_sprite.region_rect = CHEST_FRAMES[anim_frame_idx]

func _setup_prompt_label() -> void:
	prompt_label = Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = "[F] / Click: Chest (40)"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-64, -38)
	prompt_label.size = Vector2(128, 18)
	prompt_label.z_index = 20
	prompt_label.add_theme_font_size_override("font_size", 9)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72, 1.0))
	prompt_label.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.03, 1.0))
	prompt_label.add_theme_constant_override("outline_size", 3)
	prompt_label.visible = false
	add_child(prompt_label)

func _setup_chest_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "StorageChestLayer"
	ui_layer.layer = 20
	add_child(ui_layer)

	chest_panel = Panel.new()
	chest_panel.name = "ChestWindow"
	chest_panel.add_to_group("merchant_shop_ui")
	chest_panel.add_to_group("storage_chest_ui")
	chest_panel.anchor_left = 0.5
	chest_panel.anchor_top = 0.5
	chest_panel.anchor_right = 0.5
	chest_panel.anchor_bottom = 0.5
	chest_panel.offset_left = -504.0
	chest_panel.offset_top = -152.0
	chest_panel.offset_right = -8.0
	chest_panel.offset_bottom = 112.0
	chest_panel.visible = false

	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0.22, 0.13, 0.08, 0.96)
	win_style.border_width_left = 4
	win_style.border_width_top = 4
	win_style.border_width_right = 4
	win_style.border_width_bottom = 4
	win_style.border_color = Color(0.86, 0.62, 0.28, 1.0)
	win_style.corner_radius_top_left = 8
	win_style.corner_radius_top_right = 8
	win_style.corner_radius_bottom_right = 8
	win_style.corner_radius_bottom_left = 8
	win_style.shadow_color = Color(0, 0, 0, 0.55)
	win_style.shadow_size = 12
	win_style.shadow_offset = Vector2(0, 5)
	chest_panel.add_theme_stylebox_override("panel", win_style)
	ui_layer.add_child(chest_panel)

	# Icon rương nhỏ trên thanh tiêu đề lấy từ Loose/Cursors 2.png
	var header_icon := TextureRect.new()
	header_icon.position = Vector2(14, 6)
	header_icon.size = Vector2(26, 26)
	header_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cursors2_tex := load(CHEST_TEXTURE_PATH) as Texture2D
	if cursors2_tex:
		var atlas := AtlasTexture.new()
		atlas.atlas = cursors2_tex
		atlas.region = CHEST_FRAMES[0]
		header_icon.texture = atlas
	chest_panel.add_child(header_icon)

	var title_lbl := Label.new()
	title_lbl.text = "Storage Chest (40 Slots)"
	title_lbl.position = Vector2(44, 10)
	title_lbl.size = Vector2(220, 24)
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1.0))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.1, 0.05, 0.02, 0.9))
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	chest_panel.add_child(title_lbl)

	count_label = Label.new()
	count_label.text = "0 / 40"
	count_label.position = Vector2(258, 11)
	count_label.size = Vector2(70, 22)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.48, 1.0))
	chest_panel.add_child(count_label)

	var store_btn := Button.new()
	store_btn.text = "Store Held"
	store_btn.position = Vector2(338, 8)
	store_btn.size = Vector2(108, 24)
	store_btn.add_theme_font_size_override("font_size", 11)
	store_btn.pressed.connect(_on_store_selected_pressed)
	chest_panel.add_child(store_btn)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.flat = true
	close_btn.position = Vector2(456, 8)
	close_btn.size = Vector2(26, 24)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.65, 1.0))
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.35, 1.0))
	close_btn.pressed.connect(close_chest)
	chest_panel.add_child(close_btn)

	var inner_well := Panel.new()
	inner_well.name = "InnerWell"
	inner_well.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_well.offset_left = 14.0
	inner_well.offset_top = 38.0
	inner_well.offset_right = -14.0
	inner_well.offset_bottom = -30.0
	inner_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var well_style := StyleBoxFlat.new()
	well_style.bg_color = Color(0.14, 0.08, 0.05, 0.9)
	well_style.border_width_left = 2
	well_style.border_width_top = 2
	well_style.border_width_right = 2
	well_style.border_width_bottom = 2
	well_style.border_color = Color(0.45, 0.28, 0.15, 1.0)
	well_style.corner_radius_top_left = 4
	well_style.corner_radius_top_right = 4
	well_style.corner_radius_bottom_right = 4
	well_style.corner_radius_bottom_left = 4
	inner_well.add_theme_stylebox_override("panel", well_style)
	chest_panel.add_child(inner_well)

	var grid := GridContainer.new()
	grid.name = "ChestGrid"
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.anchor_left = 0.5
	grid.anchor_top = 0.5
	grid.anchor_right = 0.5
	grid.anchor_bottom = 0.5
	grid.offset_left = -227.0
	grid.offset_top = -85.0
	grid.offset_right = 227.0
	grid.offset_bottom = 93.0
	chest_panel.add_child(grid)

	var slot_tex := load(SLOT_BG_PATH) as Texture2D
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(1.0, 0.96, 0.85, 0.12)
	hover_style.border_width_left = 1
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	hover_style.border_color = Color(0.95, 0.78, 0.45, 0.9)
	hover_style.corner_radius_top_left = 3
	hover_style.corner_radius_top_right = 3
	hover_style.corner_radius_bottom_right = 3
	hover_style.corner_radius_bottom_left = 3

	chest_slots.clear()
	for i in range(CHEST_SLOT_COUNT):
		var slot := ChestSlotControl.new()
		slot.slot_index = i
		slot.chest_owner = self
		slot.custom_minimum_size = Vector2(40, 40)
		slot.texture = slot_tex
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.self_modulate = SLOT_NORMAL_COLOR
		slot.pivot_offset = Vector2(20, 20)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 5.0
		icon.offset_top = 5.0
		icon.offset_right = -5.0
		icon.offset_bottom = -5.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(icon)

		var hover_frame := Panel.new()
		hover_frame.name = "HoverFrame"
		hover_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		hover_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hover_frame.add_theme_stylebox_override("panel", hover_style)
		hover_frame.visible = false
		slot.add_child(hover_frame)

		slot.mouse_entered.connect(_on_chest_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_chest_slot_mouse_exited.bind(slot))
		grid.add_child(slot)
		chest_slots.append(slot)

	status_label = Label.new()
	status_label.name = "HintLabel"
	status_label.text = "Drag & Drop or Right-Click to Store / Take  •  [F / ESC] Close"
	status_label.anchor_top = 1.0
	status_label.anchor_right = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_left = 14.0
	status_label.offset_top = -26.0
	status_label.offset_right = -14.0
	status_label.offset_bottom = -6.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.85, 0.74, 0.56, 0.92))
	chest_panel.add_child(status_label)

func _on_chest_slot_mouse_entered(slot: Control) -> void:
	slot.self_modulate = SLOT_HOVER_COLOR
	var hf := slot.get_node_or_null("HoverFrame") as Control
	if hf:
		hf.visible = true

func _on_chest_slot_mouse_exited(slot: Control) -> void:
	slot.self_modulate = SLOT_NORMAL_COLOR
	var hf := slot.get_node_or_null("HoverFrame") as Control
	if hf:
		hf.visible = false

func _sync_chest_to_scene_manager() -> void:
	if SceneManager:
		SceneManager.saved_chest_data = chest_data.duplicate(true)

func _refresh_all_chest_slots() -> void:
	var used_count := 0
	for i in range(CHEST_SLOT_COUNT):
		update_chest_slot_display(i)
		if chest_data[i] != null:
			used_count += 1
	if count_label:
		count_label.text = "%d / %d" % [used_count, CHEST_SLOT_COUNT]

func update_chest_slot_display(idx: int) -> void:
	if idx < 0 or idx >= chest_slots.size():
		return
	var slot := chest_slots[idx]
	var icon := slot.get_node_or_null("Icon") as TextureRect
	var data = chest_data[idx]
	if data != null and typeof(data) == TYPE_DICTIONARY:
		if icon:
			icon.texture = data.get("icon")
		var nm := str(data.get("name", "Item"))
		slot.tooltip_text = "%s\n(Right-Click or Drag to Inventory)" % (nm if nm != "" else "Item")
	else:
		if icon:
			icon.texture = null
		slot.tooltip_text = "Empty Chest Slot"

func swap_chest_slots(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= CHEST_SLOT_COUNT or to_idx < 0 or to_idx >= CHEST_SLOT_COUNT:
		return
	var tmp = chest_data[from_idx]
	chest_data[from_idx] = chest_data[to_idx]
	chest_data[to_idx] = tmp
	_refresh_all_chest_slots()
	_sync_chest_to_scene_manager()

func transfer_or_swap_from_inventory(inv_slot_idx: int, chest_slot_idx: int) -> void:
	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv or inv_slot_idx < 0 or inv_slot_idx >= inv.inventory_data.size():
		return
	if chest_slot_idx < 0 or chest_slot_idx >= CHEST_SLOT_COUNT:
		return

	var inv_item = inv.inventory_data[inv_slot_idx]
	if inv_item == null:
		return

	var chest_item = chest_data[chest_slot_idx]
	chest_data[chest_slot_idx] = inv_item.duplicate(true) if typeof(inv_item) == TYPE_DICTIONARY else inv_item
	inv.inventory_data[inv_slot_idx] = chest_item.duplicate(true) if typeof(chest_item) == TYPE_DICTIONARY else chest_item

	inv.update_slot_display(inv_slot_idx)
	if inv.selected_slot_index == inv_slot_idx:
		inv.select_slot_by_index(inv_slot_idx)
	else:
		inv._sync_to_scene_manager()

	_refresh_all_chest_slots()
	_sync_chest_to_scene_manager()
	_bounce_slot(chest_slots[chest_slot_idx])

func transfer_or_swap_to_inventory(chest_slot_idx: int, inv_slot_idx: int) -> void:
	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv or inv_slot_idx < 0 or inv_slot_idx >= inv.inventory_data.size():
		return
	if chest_slot_idx < 0 or chest_slot_idx >= CHEST_SLOT_COUNT:
		return

	var chest_item = chest_data[chest_slot_idx]
	if chest_item == null:
		return

	var inv_item = inv.inventory_data[inv_slot_idx]
	inv.inventory_data[inv_slot_idx] = chest_item.duplicate(true) if typeof(chest_item) == TYPE_DICTIONARY else chest_item
	chest_data[chest_slot_idx] = inv_item.duplicate(true) if typeof(inv_item) == TYPE_DICTIONARY else inv_item

	inv.update_slot_display(inv_slot_idx)
	if inv.selected_slot_index == inv_slot_idx:
		inv.select_slot_by_index(inv_slot_idx)
	else:
		inv._sync_to_scene_manager()

	_refresh_all_chest_slots()
	_sync_chest_to_scene_manager()
	if inv_slot_idx < inv.all_slots.size():
		_bounce_slot(inv.all_slots[inv_slot_idx])

func store_item_from_inventory_slot(inv_slot_idx: int) -> bool:
	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv or inv_slot_idx < 0 or inv_slot_idx >= inv.inventory_data.size():
		return false
	var item = inv.inventory_data[inv_slot_idx]
	if item == null:
		return false

	for i in range(CHEST_SLOT_COUNT):
		if chest_data[i] == null:
			chest_data[i] = item.duplicate(true) if typeof(item) == TYPE_DICTIONARY else item
			inv.inventory_data[inv_slot_idx] = null
			inv.update_slot_display(inv_slot_idx)
			if inv.selected_slot_index == inv_slot_idx:
				inv.select_slot_by_index(inv_slot_idx)
			else:
				inv._sync_to_scene_manager()
			_refresh_all_chest_slots()
			_sync_chest_to_scene_manager()
			_bounce_slot(chest_slots[i])
			return true
	return false

func quick_take_to_inventory(chest_slot_idx: int) -> bool:
	if chest_slot_idx < 0 or chest_slot_idx >= CHEST_SLOT_COUNT:
		return false
	var item = chest_data[chest_slot_idx]
	if item == null:
		return false

	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv:
		return false

	for i in range(inv.inventory_data.size()):
		if inv.inventory_data[i] == null:
			inv.inventory_data[i] = item.duplicate(true) if typeof(item) == TYPE_DICTIONARY else item
			chest_data[chest_slot_idx] = null
			inv.update_slot_display(i)
			if inv.selected_slot_index == i:
				inv.select_slot_by_index(i)
			else:
				inv._sync_to_scene_manager()
			_refresh_all_chest_slots()
			_sync_chest_to_scene_manager()
			if i < inv.all_slots.size():
				_bounce_slot(inv.all_slots[i])
			return true
	return false

func _on_store_selected_pressed() -> void:
	var inv = get_tree().get_first_node_in_group("inventory")
	if not inv or inv.selected_slot_index < 0:
		return
	store_item_from_inventory_slot(inv.selected_slot_index)

func _bounce_slot(slot_ctrl: Control) -> void:
	if not is_instance_valid(slot_ctrl):
		return
	slot_ctrl.pivot_offset = slot_ctrl.size * 0.5
	slot_ctrl.scale = Vector2(1.18, 1.18)
	var tw := create_tween()
	tw.tween_property(slot_ctrl, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
