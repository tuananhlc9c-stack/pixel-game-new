shader_type canvas_item;

// Tốc độ gió thổi
uniform float speed : hint_range(0.0, 10.0) = 3.0;
// Biên độ đung đưa của ngọn lá
uniform float strength : hint_range(0.0, 30.0) = 8.0;
// Ngưỡng phân chia thân và tán lá (0.0 là đỉnh ngọn, 1.0 là gốc chạm đất)
// Mặc định 0.6 nghĩa là 40% phần thân bên dưới sẽ đứng yên hoàn toàn
uniform float trunk_height : hint_range(0.0, 1.0) = 0.6;

void vertex() {
	// UV.y: 0.0 là đỉnh trên cùng, 1.0 là đáy dưới cùng của ô tile
	// Nếu vị trí nằm ở thân cây (UV.y > trunk_height) -> sway_factor = 0 (đứng yên)
	// Nếu nằm ở tán lá (UV.y < trunk_height) -> hệ số tăng dần khi càng lên cao
	float sway_factor = clamp((trunk_height - UV.y) / trunk_height, 0.0, 1.0);
	
	// Dùng hàm pow để chuyển động uốn cong mềm mại tự nhiên hơn
	sway_factor = pow(sway_factor, 1.5);
	
	// Chỉ dịch chuyển phần ngọn lá theo trục ngang
	VERTEX.x += sin(TIME * speed + VERTEX.y * 0.1) * (strength * sway_factor);
}
