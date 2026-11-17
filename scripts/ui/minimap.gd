extends Control

# Minimap / World Map (Toggle with Key M)
# Clean map view showing:
# 1. Map terrain / areas from TileMapLayers
# 2. Player position marker
# 3. English UI & map names

var map_container: Panel = null
var map_draw_surface: Control = null
var title_label: Label = null
var pos_label: Label = null
var close_btn: Button = null

# Nút bản đồ nhỏ (M) trên màn hình HUD
var hud_map_button: Button = null

var is_map_open: bool = false
var pulse_time: float = 0.0

# Bounding box of the current world
var current_world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1000, 1000))

# English map names
const MAP_NAMES: Dictionary = {
	"farm house": "Farm House",
	"farm house 2": "Farm House 2",
	"house map": "Home Interior",
	"house_map": "Home Interior",
	"map1": "Plains (Map 1)",
	"map2": "Wild Forest (Map 2)",
	"map3": "Wilderness (Map 3)",
	"map4": "Valley (Map 4)",
	"map5": "Village (Map 5)",
	"map6": "Lakeside (Map 6)",
	"map7": "Ancient Ruins (Map 7)",
	"map8": "Outer Lands (Map 8)",
	"danger": "Dungeon Entrance",
	"danger1": "Danger 1",
	"danger2": "Danger 2",
	"danger3": "Danger 3 (Boss Arena)",
	"forbidden area": "Forbidden Area"
}

func _ready() -> void:
	visible = true
	set_process_input(true)
	set_process(true)
	_setup_map_ui()

func _setup_map_ui() -> void:
	custom_minimum_size = Vector2(0, 0)
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Centered map window panel
	map_container = Panel.new()
	map_container.name = "MapWindow"
	map_container.visible = false
	map_container.custom_minimum_size = Vector2(480, 350)
	map_container.size = Vector2(500, 360)
	map_container.anchor_left = 0.5
	map_container.anchor_top = 0.5
	map_container.anchor_right = 0.5
	map_container.anchor_bottom = 0.5
	map_container.offset_left = -250.0
	map_container.offset_top = -180.0
	map_container.offset_right = 250.0
	map_container.offset_bottom = 180.0
	map_container.pivot_offset = Vector2(250, 180)

	# Vintage RPG gold border style matching inventory and chests
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.12, 0.10, 0.14, 0.94)
	frame_style.border_width_left = 3
	frame_style.border_width_top = 3
	frame_style.border_width_right = 3
	frame_style.border_width_bottom = 3
	frame_style.border_color = Color(0.85, 0.72, 0.38, 1.0)
	frame_style.set_corner_radius_all(6)
	frame_style.shadow_color = Color(0, 0, 0, 0.7)
	frame_style.shadow_size = 12
	map_container.add_theme_stylebox_override("panel", frame_style)
	add_child(map_container)

	# Header Title
	title_label = Label.new()
	title_label.position = Vector2(16, 10)
	title_label.size = Vector2(400, 26)
	title_label.text = "MAP"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	map_container.add_child(title_label)

	# Close Button [X]
	close_btn = Button.new()
	close_btn.position = Vector2(462, 8)
	close_btn.size = Vector2(28, 26)
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.4, 0.15, 0.15, 0.9)
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.85, 0.45, 0.45, 1.0)
	btn_style.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.pressed.connect(func(): toggle_map(false))
	map_container.add_child(close_btn)

	# Inner display frame
	var inner_panel := Panel.new()
	inner_panel.position = Vector2(16, 40)
	inner_panel.size = Vector2(468, 276)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.06, 0.08, 0.10, 0.98)
	inner_style.border_width_left = 2
	inner_style.border_width_top = 2
	inner_style.border_width_right = 2
	inner_style.border_width_bottom = 2
	inner_style.border_color = Color(0.35, 0.32, 0.28, 0.9)
	inner_style.set_corner_radius_all(4)
	inner_panel.add_theme_stylebox_override("panel", inner_style)
	map_container.add_child(inner_panel)

	# Canvas draw surface for map terrain and player marker
	map_draw_surface = Control.new()
	map_draw_surface.position = Vector2(8, 8)
	map_draw_surface.size = Vector2(452, 260)
	map_draw_surface.draw.connect(_on_map_draw)
	inner_panel.add_child(map_draw_surface)

	# Bottom Info Label (Position & Key Shortcut Hint)
	pos_label = Label.new()
	pos_label.position = Vector2(16, 324)
	pos_label.size = Vector2(468, 22)
	pos_label.add_theme_font_size_override("font_size", 10)
	pos_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.9))
	pos_label.text = "Press [M] to toggle | [ESC] to close"
	map_container.add_child(pos_label)

	# Nút icon bản đồ luôn hiện cạnh thanh bar có chữ M
	_setup_hud_map_button()

func _setup_hud_map_button() -> void:
	if has_node("HUDMapButton"):
		hud_map_button = get_node("HUDMapButton") as Button
		return

	hud_map_button = Button.new()
	hud_map_button.name = "HUDMapButton"
	hud_map_button.focus_mode = Control.FOCUS_NONE

	# Định vị ngay cạnh phải của thanh công cụ QuickBar (offset 235..275)
	hud_map_button.anchor_left = 0.5
	hud_map_button.anchor_top = 1.0
	hud_map_button.anchor_right = 0.5
	hud_map_button.anchor_bottom = 1.0
	hud_map_button.offset_left = 236.0
	hud_map_button.offset_top = -62.0
	hud_map_button.offset_right = 276.0
	hud_map_button.offset_bottom = -22.0
	hud_map_button.grow_horizontal = Control.GROW_DIRECTION_END
	hud_map_button.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# Style RPG cổ điển viền gỗ/vàng đồng bộ với QuickBar
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.2, 0.12, 0.07, 0.94)
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(0.76, 0.52, 0.27, 1.0)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.shadow_color = Color(0, 0, 0, 0.45)
	btn_normal.shadow_size = 4

	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.32, 0.18, 0.10, 0.96)
	btn_hover.border_color = Color(1.0, 0.85, 0.38, 1.0)

	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.14, 0.08, 0.04, 0.98)
	btn_pressed.border_color = Color(0.95, 0.72, 0.22, 1.0)

	hud_map_button.add_theme_stylebox_override("normal", btn_normal)
	hud_map_button.add_theme_stylebox_override("hover", btn_hover)
	hud_map_button.add_theme_stylebox_override("pressed", btn_pressed)

	# Vẽ icon bản đồ dạng cuộn giấy cổ zic-zac có vệt địa hình
	var icon_draw := Control.new()
	icon_draw.name = "MapIconDraw"
	icon_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_draw.draw.connect(func():
		# 3 nếp gấp bản đồ cuộn giấy
		var fold1 := Rect2(10, 7, 6, 17)
		var fold2 := Rect2(16, 9, 8, 17)
		var fold3 := Rect2(24, 7, 6, 17)
		icon_draw.draw_rect(fold1, Color(0.92, 0.84, 0.65, 1.0), true)
		icon_draw.draw_rect(fold2, Color(0.84, 0.74, 0.52, 1.0), true)
		icon_draw.draw_rect(fold3, Color(0.92, 0.84, 0.65, 1.0), true)
		icon_draw.draw_rect(Rect2(10, 7, 20, 19), Color(0.38, 0.25, 0.14, 1.0), false, 1.0)
		# Nếp gấp mép giấy
		icon_draw.draw_line(Vector2(16, 7), Vector2(16, 26), Color(0.65, 0.52, 0.35, 1.0), 1.0)
		icon_draw.draw_line(Vector2(24, 7), Vector2(24, 26), Color(0.65, 0.52, 0.35, 1.0), 1.0)
		# Vệt địa hình sông / núi xanh
		icon_draw.draw_line(Vector2(12, 13), Vector2(14, 15), Color(0.45, 0.65, 0.42, 1.0), 1.5)
		icon_draw.draw_line(Vector2(18, 16), Vector2(21, 13), Color(0.3, 0.55, 0.85, 1.0), 1.5)
		# Dấu X đỏ vị trí kho báu
		icon_draw.draw_line(Vector2(19, 18), Vector2(22, 22), Color(0.85, 0.2, 0.2, 1.0), 1.5)
		icon_draw.draw_line(Vector2(22, 18), Vector2(19, 22), Color(0.85, 0.2, 0.2, 1.0), 1.5)
	)
	hud_map_button.add_child(icon_draw)

	# Nhãn chữ [M] to, rõ ràng và có viền nổi bật ở góc dưới
	var m_label := Label.new()
	m_label.text = "M"
	m_label.position = Vector2(0, 24)
	m_label.size = Vector2(40, 14)
	m_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m_label.add_theme_font_size_override("font_size", 9)
	m_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	m_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02, 1.0))
	m_label.add_theme_constant_override("outline_size", 3)
	hud_map_button.add_child(m_label)

	hud_map_button.tooltip_text = "World Map [M]"
	hud_map_button.pressed.connect(func(): toggle_map())

	add_child(hud_map_button)

func _process(delta: float) -> void:
	if is_map_open:
		pulse_time += delta * 4.0
		if map_draw_surface:
			map_draw_surface.queue_redraw()
		_update_player_position_text()

func _update_player_position_text() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and pos_label:
		var p_pos: Vector2 = player.global_position
		pos_label.text = "Position: (X: %d, Y: %d)   |   [M] Toggle Map   |   [ESC] Close" % [int(p_pos.x), int(p_pos.y)]

func toggle_map(force_state: Variant = null) -> void:
	var target: bool = not is_map_open if force_state == null else bool(force_state)
	if target == is_map_open:
		return
	is_map_open = target

	if is_map_open:
		_calculate_map_bounds()
		map_container.visible = true
		map_container.scale = Vector2(0.92, 0.92)
		map_container.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(map_container, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(map_container, "modulate:a", 1.0, 0.12)
		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("menu_open", -1.0)
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(map_container, "scale", Vector2(0.92, 0.92), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(map_container, "modulate:a", 0.0, 0.1)
		tw.chain().tween_callback(func():
			if not is_map_open and is_instance_valid(map_container):
				map_container.visible = false
				map_container.scale = Vector2.ONE
				map_container.modulate.a = 1.0
		)
		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("menu_close", -1.0)

func _calculate_map_bounds() -> void:
	var cur_scene = get_tree().current_scene if get_tree() else null
	if not cur_scene:
		cur_scene = Engine.get_main_loop().current_scene if Engine.get_main_loop() else null
	if not cur_scene:
		return

	# Determine current map name safely
	var scene_file := ""
	if "scene_file_path" in cur_scene and cur_scene.scene_file_path != "":
		scene_file = cur_scene.scene_file_path.get_file().get_basename().to_lower()
	elif SceneManager and "saved_map_scene_path" in SceneManager and SceneManager.saved_map_scene_path != "":
		scene_file = SceneManager.saved_map_scene_path.get_file().get_basename().to_lower()
	else:
		scene_file = cur_scene.name.to_lower()

	var pretty_name: String = MAP_NAMES.get(scene_file, cur_scene.name)
	if title_label:
		title_label.text = "MAP: %s" % pretty_name.to_upper()

	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var found_tiles := false

	# Scan TileMapLayers to calculate map boundaries
	var stack: Array = [cur_scene]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is TileMapLayer:
			var used_rect: Rect2i = node.get_used_rect()
			if used_rect.size.x > 0 and used_rect.size.y > 0:
				found_tiles = true
				var tile_size := Vector2(16, 16)
				if node.tile_set:
					tile_size = Vector2(node.tile_set.tile_size)

				var top_left = node.to_global(Vector2(used_rect.position) * tile_size)
				var bottom_right = node.to_global(Vector2(used_rect.end) * tile_size)

				min_p.x = minf(min_p.x, minf(top_left.x, bottom_right.x))
				min_p.y = minf(min_p.y, minf(top_left.y, bottom_right.y))
				max_p.x = maxf(max_p.x, maxf(top_left.x, bottom_right.x))
				max_p.y = maxf(max_p.y, maxf(top_left.y, bottom_right.y))
		for child in node.get_children():
			stack.push_back(child)

	var player = get_tree().get_first_node_in_group("player")
	if not found_tiles or min_p.x >= max_p.x:
		if player:
			min_p = player.global_position - Vector2(600, 450)
			max_p = player.global_position + Vector2(600, 450)
		else:
			min_p = Vector2(0, 0)
			max_p = Vector2(1200, 900)

	var pad := Vector2(32, 32)
	min_p -= pad
	max_p += pad
	current_world_bounds = Rect2(min_p, max_p - min_p)

func _world_to_minimap(world_pos: Vector2, surface_size: Vector2) -> Vector2:
	if current_world_bounds.size.x <= 0.0 or current_world_bounds.size.y <= 0.0:
		return surface_size * 0.5

	var norm_x = (world_pos.x - current_world_bounds.position.x) / current_world_bounds.size.x
	var norm_y = (world_pos.y - current_world_bounds.position.y) / current_world_bounds.size.y

	norm_x = clampf(norm_x, 0.02, 0.98)
	norm_y = clampf(norm_y, 0.02, 0.98)

	return Vector2(norm_x * surface_size.x, norm_y * surface_size.y)

func _on_map_draw() -> void:
	if not map_draw_surface or not is_map_open:
		return

	var surf_size := map_draw_surface.size

	# 1. Subtle tactical grid
	var grid_color := Color(0.14, 0.18, 0.22, 0.45)
	var step_x := surf_size.x / 8.0
	for i in range(1, 8):
		map_draw_surface.draw_line(Vector2(i * step_x, 0), Vector2(i * step_x, surf_size.y), grid_color, 1.0)
	var step_y := surf_size.y / 6.0
	for j in range(1, 6):
		map_draw_surface.draw_line(Vector2(0, j * step_y), Vector2(surf_size.x, j * step_y), grid_color, 1.0)

	# 2. Render map terrain boundaries from TileMapLayer
	var cur_scene = Engine.get_main_loop().current_scene
	if cur_scene:
		var stack: Array = [cur_scene]
		while not stack.is_empty():
			var node = stack.pop_back()
			if node is TileMapLayer:
				var u_rect: Rect2i = node.get_used_rect()
				if u_rect.size.x > 0 and u_rect.size.y > 0:
					var tile_size := Vector2(16, 16)
					if node.tile_set:
						tile_size = Vector2(node.tile_set.tile_size)
					var w_top_left = node.to_global(Vector2(u_rect.position) * tile_size)
					var w_bottom_right = node.to_global(Vector2(u_rect.end) * tile_size)

					var m_tl := _world_to_minimap(w_top_left, surf_size)
					var m_br := _world_to_minimap(w_bottom_right, surf_size)
					var m_rect := Rect2(m_tl, m_br - m_tl)

					map_draw_surface.draw_rect(m_rect, Color(0.22, 0.32, 0.42, 0.25), true)
					map_draw_surface.draw_rect(m_rect, Color(0.35, 0.48, 0.62, 0.55), false, 1.0)
			for child in node.get_children():
				stack.push_back(child)

	# 3. Portals with destination names in English
	var portals := get_tree().get_nodes_in_group("portal")
	for portal in portals:
		if is_instance_valid(portal) and portal is Node2D:
			var p_pos := _world_to_minimap(portal.global_position, surf_size)
			# Glowing portal ring and dot
			map_draw_surface.draw_circle(p_pos, 6.0, Color(0.1, 0.65, 1.0, 0.35))
			map_draw_surface.draw_circle(p_pos, 3.5, Color(0.25, 0.85, 1.0, 0.95))
			map_draw_surface.draw_circle(p_pos, 1.5, Color(1.0, 1.0, 1.0, 1.0))

			# Destination name
			var next_path: String = portal.get("next_scene_path") if portal.get("next_scene_path") else ""
			if next_path != "":
				var p_name = next_path.get_file().get_basename().to_lower()
				var dest_title: String = MAP_NAMES.get(p_name, p_name.capitalize())
				var label_text: String = "To: %s" % dest_title
				# Draw small dark backdrop behind portal text for high readability
				var font_size: int = 9
				var str_size := ThemeDB.fallback_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var text_pos := p_pos + Vector2(6, 4)
				var bg_rect := Rect2(text_pos + Vector2(-2, -str_size.y + 2), str_size + Vector2(4, 2))
				map_draw_surface.draw_rect(bg_rect, Color(0.04, 0.06, 0.08, 0.8), true)
				map_draw_surface.draw_string(ThemeDB.fallback_font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.55, 0.9, 1.0, 0.95))

	# 4. Only show Player Position marker on the map
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var pl_pos := _world_to_minimap(player.global_position, surf_size)
		var p_wave := (sin(pulse_time) + 1.0) * 0.5

		# Pulsing radar ring
		map_draw_surface.draw_circle(pl_pos, 7.0 + p_wave * 4.0, Color(0.2, 1.0, 0.4, 0.35 * (1.0 - p_wave)))
		# Core player dot
		map_draw_surface.draw_circle(pl_pos, 4.5, Color(0.1, 0.95, 0.35, 1.0))
		map_draw_surface.draw_circle(pl_pos, 2.0, Color(1.0, 1.0, 1.0, 1.0))

		# Facing direction pointer
		var anim = player.get_node_or_null("AnimatedSprite2D")
		var dir := Vector2.DOWN
		if anim and anim.animation:
			var anim_str: String = str(anim.animation).to_lower()
			if anim_str.find("left") != -1:
				dir = Vector2.LEFT
			elif anim_str.find("right") != -1:
				dir = Vector2.RIGHT
			elif anim_str.find("up") != -1:
				dir = Vector2.UP

		map_draw_surface.draw_line(pl_pos, pl_pos + dir * 8.0, Color(1.0, 1.0, 0.3, 0.95), 2.0)
		map_draw_surface.draw_string(ThemeDB.fallback_font, pl_pos + Vector2(-10, -7), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 1.0, 0.5, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M or event.physical_keycode == KEY_M:
			toggle_map()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and is_map_open:
			toggle_map(false)
			get_viewport().set_input_as_handled()
