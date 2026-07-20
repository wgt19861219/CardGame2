shader_type canvas_item;

// 照源 createClippingNode（resource_manager.lua:650）：用 art_mask.png 做 alpha mask 裁剪 Art 立绘。
// 源 CCClippingNode:setStencil(art_mask) + setAlphaThreshold(0.5)，mask.a < threshold 的像素不显示。
// UV 0-1 覆盖整个 TextureRect size（对应源 stencil setScaleX/Y 拉伸到 Art 纹理尺寸）。
uniform sampler2D mask_tex;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// COLOR 初始 = texture × 节点 modulate（Godot CanvasItem 默认含 modulate）。
	// 乘 mask alpha 裁剪（< threshold → alpha=0 透明），保留 modulate（提亮生效）。
	vec4 mask = texture(mask_tex, UV);
	COLOR.a *= step(alpha_threshold, mask.a);
}


