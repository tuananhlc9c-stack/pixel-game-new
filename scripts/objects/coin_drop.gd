extends Area2D

# Vật phẩm Đồng Tiền Vàng rơi ra khi đánh quái
# Giá trị: Random từ 10 - 15 Gold
# Tự động hút về phía người chơi khi đến gần (magnet pickup)
# Phát âm thanh "coin", cộng vàng qua SceneManager và hiện số tiền bay lên (+12G)

@export var gold_amount: int = 12

var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO
var target_player: Node2D = null
var magnet_radius: float = 65.0
var pickup_radius: float = 14.0
var idle_timer: float = 0.0

@onready var coin_sprite: Node2D = $CoinSprite if has_node("CoinSprite") else null

func _ready() -> void:
	z_index = 2
	y_sort_enabled = true
	add_to_group("gold_drop")
	
	# Tạo hình ảnh đồng tiền pixel nếu chưa có sprite
	if not coin_sprite:
		coin_sprite = Node2D.new()
		coin_sprite.name = "CoinSprite"
		add_child(coin_sprite)
	
	queue_redraw()
	
	# Âm thanh đồng xu leng keng khi rơi ra
	if AudioManager and AudioManager.has_method("play_sfx_random_pitch"):
		AudioManager.play_sfx_random_pitch("coin", -4.0, 0.95, 1.15)
	
	# Tạo collision nếu chưa có
	if not has_node("CollisionShape2D"):
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 12.0
		col.shape = shape
		add_child(col)
	
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if is_collected:
		return
		
	idle_timer += delta
	
	# Tìm người chơi xung quanh
	if not target_player or not is_instance_valid(target_player):
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		if pl:
			target_player = pl
	
	if target_player and is_instance_valid(target_player):
		var dist := global_position.distance_to(target_player.global_position)
		if dist <= pickup_radius:
			collect()
			return
		elif dist <= magnet_radius:
			# Lực từ tính hút nhanh về phía người chơi
			var dir := (target_player.global_position - global_position).normalized()
			var pull_speed := lerpf(260.0, 480.0, 1.0 - (dist / magnet_radius))
			global_position += dir * pull_speed * delta
			queue_redraw()
			return

	queue_redraw()

func _draw() -> void:
	# Vẽ đồng xu pixel vàng bóng lấp lánh (bán kính ~5px)
	var bob := sin(idle_timer * 6.0) * 1.5
	var center := Vector2(0, -3.0 + bob)
	
	# Bóng mờ dưới mặt đất
	draw_circle(Vector2(0, 2), 4.5, Color(0.0, 0.0, 0.0, 0.25))
	
	# Viền ngoài vàng đồng
	draw_circle(center, 5.0, Color(0.76, 0.48, 0.08, 1.0))
	# Lõi vàng sáng rực rỡ
	draw_circle(center, 4.0, Color(1.0, 0.86, 0.22, 1.0))
	# Vết sáng phản chiếu góc
	draw_circle(center + Vector2(-1.2, -1.2), 1.5, Color(1.0, 1.0, 0.85, 0.95))

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body.name == "Player" or body.is_in_group("player"):
		collect()

func collect() -> void:
	if is_collected:
		return
	is_collected = true
	
	# Cộng vàng cho người chơi qua SceneManager
	if SceneManager and SceneManager.has_method("add_gold"):
		SceneManager.add_gold(gold_amount)
	
	# Phát âm thanh nhặt tiền leng keng vui nhộn
	if AudioManager and AudioManager.has_method("play_sfx_random_pitch"):
		AudioManager.play_sfx_random_pitch("coin", 0.0, 1.05, 1.3)
	elif AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("coin")
		
	# Hiện chữ nhảy số tiền vàng bay lên (+15 Gold)
	_show_floating_text("+%d Gold" % gold_amount)
	
	# Hoạt ảnh thu nhỏ biến mất
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "scale", Vector2.ZERO, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(queue_free)

func _show_floating_text(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-40, -26)
	lbl.size = Vector2(80, 18)
	lbl.z_index = 35
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.16, 0.08, 0.01, 1.0))
	lbl.add_theme_constant_override("outline_size", 3)
	
	# Đưa lên parent để không bị biến mất khi coin biến mất
	var parent_node := get_parent()
	if parent_node:
		lbl.global_position = global_position + Vector2(-40, -22)
		parent_node.add_child(lbl)
		var tw := lbl.create_tween().set_parallel(true)
		tw.tween_property(lbl, "position:y", lbl.position.y - 20.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.2)
		tw.chain().tween_callback(lbl.queue_free)
	else:
		add_child(lbl)
