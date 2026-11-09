shader_type canvas_item;

// Tốc độ gió thổi
uniform float speed : hint_range(0.0, 10.0) = 3.0;
// Biên độ đung đưa của ngọn lá
uniform float strength : hint_range(0.0, 30.0) = 8.0;
// Ngưỡng phân chia thân và tán lá (0.0 là đỉnh ngọn, 1.0 là gốc chạm đất)
uniform float trunk_height : hint_range(0.0, 1.0) = 0.6;

void vertex() {
	float sway_factor = clamp((trunk_height - UV.y) / trunk_height, 0.0, 1.0);
	sway_factor = pow(sway_factor, 1.5);
	VERTEX.x += sin(TIME * speed + VERTEX.y * 0.1) * (strength * sway_factor);
}
