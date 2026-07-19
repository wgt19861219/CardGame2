shader_type canvas_item;
// 源 createClippingNode(cardres, art_mask.png) 圆角遮罩的 Godot 近似（hero_detail card 立绘边角圆角）。
uniform float radius : hint_range(0.0, 0.5) = 0.06;

void fragment() {
	vec2 p = abs(UV - 0.5);
	float r = radius;
	vec2 q = p - vec2(0.5 - r);
	float a = 1.0;
	if (q.x > 0.0 && q.y > 0.0) {
		a = 1.0 - step(r, length(q));
	}
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= a;
}
