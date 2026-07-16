class_name UiButton
extends RefCounted

## 通用图按钮工厂（替项目普遍的 Button.new()+text 降级）。
## 源 Sprite + press 双层切 visible（如 herodetail-detail-close/close_press、tavern_button_1/2、
## classbtn/classbtnselected）→ Godot TextureButton texture_normal/texture_pressed 等价。
## 所有二级面板共用：close（backbtn）/ 抽卡（tavern_button）/ tab（classbtn）/ 动作（herodetail-detail）。
## center_pos 为按钮中心（源 anchor 0.5,0.5），自动按纹理尺寸左上对齐。

const OUTLINE_COLOR: Color = Color.BLACK
# 源 hello.lua:311 setContentScaleFactor=1.28125（iPhone 档）：cocos sprite 显示=纹理/CS。
# UiButton 制造的按钮（close/抽卡/tab/动作）源都是纯 Sprite 无 fix_size → 照源 /CS。
const CONTENT_SCALE: float = 1.28125


# 创建图按钮（normal + pressed 纹理 + 可选 label）。center_pos = 按钮中心点。
static func make(res_normal: String, res_pressed: String, center_pos: Vector2, label_text: String = "", label_color: Color = Color.WHITE) -> TextureButton:
	var btn := TextureButton.new()
	var normal_tex: Texture2D = _load(res_normal)
	btn.texture_normal = normal_tex
	btn.texture_pressed = _load(res_pressed) if ResourceLoader.exists(res_pressed) else normal_tex
	btn.ignore_texture_size = true
	var sz: Vector2 = (normal_tex.get_size() / CONTENT_SCALE) if normal_tex != null else Vector2(100.0, 40.0)
	btn.position = center_pos - sz * 0.5
	btn.size = sz
	if not label_text.is_empty():
		var lbl := Label.new()
		lbl.text = label_text
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.add_theme_color_override("font_color", label_color)
		lbl.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		lbl.add_theme_constant_override("outline_size", 2)
		btn.add_child(lbl)
	return btn


# 左上角 position（非中心），沿用既有 Godot 坐标的按钮（如 tavern ONCE_BTN_POS）。
static func make_at(res_normal: String, res_pressed: String, top_left: Vector2, label_text: String = "", label_color: Color = Color.WHITE) -> TextureButton:
	var btn := TextureButton.new()
	var normal_tex: Texture2D = _load(res_normal)
	btn.texture_normal = normal_tex
	btn.texture_pressed = _load(res_pressed) if ResourceLoader.exists(res_pressed) else normal_tex
	btn.ignore_texture_size = true
	btn.position = top_left
	if normal_tex != null:
		btn.size = normal_tex.get_size() / CONTENT_SCALE
	if not label_text.is_empty():
		var lbl := Label.new()
		lbl.text = label_text
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.add_theme_color_override("font_color", label_color)
		lbl.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		lbl.add_theme_constant_override("outline_size", 2)
		btn.add_child(lbl)
	return btn


static func _load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
