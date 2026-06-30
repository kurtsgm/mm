shader_type canvas_item;

// 對話情境圖的邊緣羽化：四邊 alpha 漸隱 + 輕微壓暗，讓矩形照片融入羊皮紙、
// 消除生硬的直角邊界。以 UV 比例計算，解析度/圖片尺寸無關。
uniform float feather : hint_range(0.0, 0.35) = 0.12;     // 各邊羽化寬度（UV 比例）
uniform float edge_darken : hint_range(0.0, 1.0) = 0.20;  // 邊緣壓暗強度（增加「嵌進羊皮紙」感）

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float dx = min(UV.x, 1.0 - UV.x);
	float dy = min(UV.y, 1.0 - UV.y);
	float edge = min(dx, dy);              // 到最近邊的距離（0=邊、0.5=中心）
	float a = smoothstep(0.0, feather, edge);
	col.rgb *= mix(1.0 - edge_darken, 1.0, a);  // 邊緣壓暗
	col.a *= a;                                 // 邊緣淡出 → 露出底下羊皮紙
	COLOR = col;
}
