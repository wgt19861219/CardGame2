class_name UiScale9Button
extends RefCounted

## 通用 Scale9 功能按钮工厂（照源 Scale9Sprite + press mask + Label）。
## 源 ed.createScale9Sprite(res, CCRectMake) + scaleSize + ok_down mask 切 visible + Label 居中 →
## Godot Button + StyleBoxTexture（texture_margin 九宫格）+ pressed 切 mask stylebox。
## capInsets CCRectMake(x,y,w,h) → StyleBoxTexture texture_margin（自动按纹理尺寸算 right/bottom）。
## Button 自带 pressed 信号 + 文字居中（照源 ok_label）。配套 UiButton（TextureButton 整图 close/动作）。
## 适用：合成/领取/确认/重置等 Scale9 功能按钮（herodetail-upgrade 系列）。capInsets 各按钮不同须照源传。

const OUTLINE_COLOR: Color = Color.BLACK


# Scale9 功能按钮（左上定位）。cap_insets = Rect2(x,y,w,h) 对应源 CCRectMake(x,y,w,h)。
static func make(res_normal: String, res_pressed: String, top_left: Vector2, size: Vector2, cap_insets: Rect2, label_text: String = "", label_color: Color = Color.WHITE) -> Button:
	var btn := Button.new()
	btn.position = top_left
	btn.size = size
	_apply_style(btn, res_normal, res_pressed, cap_insets)
	if not label_text.is_empty():
		btn.text = label_text
		btn.add_theme_color_override("font_color", label_color)
		btn.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		btn.add_theme_constant_override("outline_size", 2)
	return btn


# 中心定位版（源 anchor 0.5,0.5，如 fragmentcompose ok ccp(145,45) → make_centered 传中心）。
static func make_centered(res_normal: String, res_pressed: String, center_pos: Vector2, size: Vector2, cap_insets: Rect2, label_text: String = "", label_color: Color = Color.WHITE) -> Button:
	return make(res_normal, res_pressed, center_pos - size * 0.5, size, cap_insets, label_text, label_color)


# Apply Scale9 StyleBox + Label overrides 到已存在 Button（位置/size 在 .tscn 静态化的场景）。
# 与 make() 区别：make() 创建新 Button 并设 position/size；apply_with_label() 接受 .tscn 已声明的
# Button（普通 Button 无九宫格图），仅套 normal/hover/pressed stylebox + label color/outline。
# 用于 procedural→.tscn 重构：位置可视化在 .tscn 调，运行时补九宫格视觉（参照 hero_detail 范式）。
static func apply_with_label(btn: Button, res_normal: String, res_pressed: String, cap_insets: Rect2, label_text: String = "", label_color: Color = Color.WHITE) -> void:
	_apply_style(btn, res_normal, res_pressed, cap_insets)
	if not label_text.is_empty():
		btn.text = label_text
		btn.add_theme_color_override("font_color", label_color)
		btn.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		btn.add_theme_constant_override("outline_size", 2)


static func _apply_style(btn: Button, res_normal: String, res_pressed: String, cap_insets: Rect2) -> void:
	var normal_sb: StyleBoxTexture = _make_sb(res_normal, cap_insets)
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", normal_sb)
	var pressed_res: String = res_pressed if ResourceLoader.exists(res_pressed) else res_normal
	btn.add_theme_stylebox_override("pressed", _make_sb(pressed_res, cap_insets))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# 源 Scale9Sprite capInsets CCRectMake(x,y,w,h)：中心区域 = (x,y,w,h)。
# Godot StyleBoxTexture texture_margin 四边：left=x, top=y, right=tex.w-x-w, bottom=tex.h-y-h。
static func _make_sb(res: String, cap_insets: Rect2) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var tex: Texture2D = load(res) as Texture2D
	sb.texture = tex
	sb.texture_margin_left = cap_insets.position.x
	sb.texture_margin_top = cap_insets.position.y
	if tex != null:
		sb.texture_margin_right = tex.get_width() - cap_insets.position.x - cap_insets.size.x
		sb.texture_margin_bottom = tex.get_height() - cap_insets.position.y - cap_insets.size.y
	sb.draw_center = true
	return sb
