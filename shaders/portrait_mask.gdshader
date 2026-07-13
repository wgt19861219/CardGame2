// 头像 mask 裁剪 — 适配 Cocos CCClippingNode（源 resource_manager.lua:650 createClippingNode）。
// 源 createClippingNode(Portrait, "equip_stencil.png", 0.02)：stencil mask + alphaThreshold=0.02
// 裁剪 Portrait 成 stencil 形状（圆角头像框）。Godot canvas_item shader 等价：mask.a<threshold discard。
shader_type canvas_item;

uniform sampler2D mask_tex : hint_default_white;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.02;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec4 mask = texture(mask_tex, UV);
	if (mask.a < alpha_threshold) {
		discard;
	}
	COLOR = col;
}
