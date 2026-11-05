shader_type canvas_item;

// Tốc độ nước đổ xuống (thác cần tốc độ cao hơn mặt biển)
uniform float fall_speed : hint_range(0.0, 15.0) = 6.0;
// Mật độ sợi nước theo chiều ngang
uniform float flow_scale : hint_range(5.0, 100.0) = 35.0;

// Màu sắc thác nước
uniform vec4 deep_water_color : source_color = vec4(0.20, 0.50, 0.80, 1.0);  // Màu lòng dòng thác
uniform vec4 shallow_water_color : source_color = vec4(0.45, 0.80, 0.95, 1.0); // Màu lớp nước ngoài
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);          // Bọt trắng nước sôi sục

// Ngưỡng bọt và ánh bọt trắng
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.52;
uniform float foam_intensity : hint_range(0.0, 1.0) = 0.70;

// Hàm tạo vệt bọt ngẫu nhiên (Voronoi)
float voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float m_dist = 1.0;
	
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 neighbor = vec2(float(i), float(j));
			vec2 point = sin(vec2(
				dot(n + neighbor, vec2(127.1, 311.7)),
				dot(n + neighbor, vec2(269.5, 183.3))
			)) * 0.5 + 0.5;
			
			vec2 diff = neighbor + point - f;
			m_dist = min(m_dist, length(diff));
		}
	}
	return m_dist;
}

void fragment() {
	// Dùng SCREEN_UV để thác nước đổ thẳng liền mạch, không bao giờ lộ vết cắt ô
	vec2 p = SCREEN_UV;
	
	// Ép dẹp trục Y để biến các chấm tròn thành các sợi nước chảy dọc
	vec2 stream_coord = vec2(p.x * flow_scale, p.y * (flow_scale * 0.25));
	
	// Nước đổ dốc thẳng từ trên xuống dưới theo thời gian
	stream_coord.y -= TIME * fall_speed;
	// Rung lắc nhẹ 2 bên mép để dòng chảy tự nhiên
	stream_coord.x += sin(stream_coord.y * 0.5 + TIME * 2.0) * 0.3;
	
	// 2 lớp sợi nước trôi lệch pha tạo cảm giác nước sôi ùng ục
	float stream1 = voronoi(stream_coord);
	float stream2 = voronoi(stream_coord * 1.3 + vec2(1.5, -TIME * fall_speed * 0.4));
	float combined_stream = mix(stream1, stream2, 0.5);
	
	vec4 tile_tex = texture(TEXTURE, UV);
	
	// Phối màu tầng nước chảy
	vec3 water_rgb = mix(deep_water_color.rgb, shallow_water_color.rgb, combined_stream);
	water_rgb = mix(tile_tex.rgb, water_rgb, 0.6);
	
	// Bọt trắng nổi bật theo từng sợi nước xé xiết
	float foam = smoothstep(foam_threshold, foam_threshold + 0.12, combined_stream);
	water_rgb = mix(water_rgb, foam_color.rgb, foam * foam_intensity);
	
	COLOR = vec4(water_rgb, tile_tex.a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
