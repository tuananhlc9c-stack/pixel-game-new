extends Node2D

func _unhandled_input(event: InputEvent) -> void:
	# Click CHUỘT TRÁI ra sàn nhà
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var inv = get_tree().root.find_child("Invetory", true, false)
		
		# Nếu balo đang có món đồ nội thất được chọn
		if inv and inv.current_place_scene != null:
			var new_item = inv.current_place_scene.instantiate()
			new_item.global_position = get_global_mouse_position()
			add_child(new_item)
			
			# Dọn ô trong Balo sau khi đặt xong
			if inv.selected_slot:
				inv.selected_slot.texture = null
				inv.selected_slot.set_meta("placed_scene", null)
				inv.selected_slot.modulate = Color(0.8, 0.8, 0.8)
			
			inv.current_place_scene = null
			print("Đã đặt đồ vật ra sàn thành công!")
