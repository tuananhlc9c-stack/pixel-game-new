shader_type canvas_item;

// Tốc độ sóng cuộn
uniform float speed : hint_range(0.0, 5.0) = 1.2;
// Mật độ mắt lưới sóng (càng cao mắt sóng càng nhỏ)
uniform float wave_scale : hint_range(5.0, 80.0) = 28.0;

// Màu sắc phân tầng nước biển
uniform vec4 deep_water_color : source_color = vec4(0.12, 0.38, 0.65, 1.0);
uniform vec4 shallow_water_color : source_color = vec4(0.35, 0.72, 0.88, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);

// Cường độ bọt và ánh phản chiếu
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.58;
uniform float sparkle_intensity : hint_range(0.0, 1.0) = 0.45;

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
			) + TIME * speed * 0.8) * 0.5 + 0.5;

			vec2 diff = neighbor + point - f;
			float dist = length(diff);
			m_dist = min(m_dist, dist);
		}
	}
	return m_dist;
}

void fragment() {
	vec2 world_coord = SCREEN_UV * wave_scale;
	world_coord.x += sin(world_coord.y * 0.5 + TIME * speed * 0.6) * 0.4;
	world_coord.y += TIME * speed * 0.2;

	float wave_pattern1 = voronoi(world_coord);
	float wave_pattern2 = voronoi(world_coord * 1.5 + vec2(TIME * speed * 0.3, -TIME * speed * 0.2));
	float combined_wave = mix(wave_pattern1, wave_pattern2, 0.5);

	vec4 tile_tex = texture(TEXTURE, UV);
	vec3 water_rgb = mix(deep_water_color.rgb, shallow_water_color.rgb, combined_wave);
	water_rgb = mix(tile_tex.rgb, water_rgb, 0.65);

	float foam = smoothstep(foam_threshold, foam_threshold + 0.15, combined_wave);
	water_rgb = mix(water_rgb, foam_color.rgb, foam * sparkle_intensity);

	COLOR = vec4(water_rgb, tile_tex.a);
}
