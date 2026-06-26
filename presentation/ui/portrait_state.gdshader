shader_type canvas_item;
// 頭像狀態效果：tint 染色 + grayscale 去色 + brightness 明暗。
// 受傷=紅暈、受擊=紅閃；暈倒/死亡若無共用圖時用灰階+變暗當 fallback。

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float grayscale : hint_range(0.0, 1.0) = 0.0;
uniform float brightness = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(c.rgb, vec3(g), grayscale);
	rgb *= brightness * tint.rgb;
	COLOR = vec4(rgb, c.a);
}
