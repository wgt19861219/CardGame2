extends GutTest

## MailOverfullPopup 验证（P1-4：照源 mail/overfull.lua 溢满弹窗替 Toast 降级）。
## 2026-08-16 批 2 Task 5 两件套改造：uieditor/mailoverfull.lua 声明表直译守卫 +
## Frame/TitleBg Scale9 → NinePatchRect 守卫（B 类误用修正核心点）+ 按钮运行时
## UiScale9Button → theme variation + DescScroll 补齐 + 零静态构造白名单。

const CONTENT_PATH := "res://scenes/ui/mail_overfull_popup_content.tscn"
const POPUP_PATH := "res://scripts/ui/mail_overfull_popup.gd"
const THEME_PATH := "res://resources/themes/default_theme.tres"


# frame（common_alert_bg）+ 2 按钮（强行领取/稍后领取）装配。
# 批 2：按钮从运行时 UiScale9Button.apply_with_label 改 tscn 静态 Button + theme variation。
func test_popup_assembles_frame_and_buttons() -> void:
	var popup := MailOverfullPopup.new()
	popup.setup([{"id": 371, "amount": 5}], GameData.config)
	add_child(popup)
	await get_tree().process_frame   # 等 _ready → _build_content
	assert_true(_has_tex(popup, popup.FRAME_TEX), "frame 装配（common_alert_bg）")
	var btns: Array = popup.find_children("*", "Button", true, false)
	assert_eq(btns.size(), 2, "2 按钮（强行领取+稍后领取）")
	popup.free()


# left_button「强行领取」→ emit confirmed（源 overfull.lua:10-16 leftCallback）。
func test_popup_confirmed_signal() -> void:
	var popup := MailOverfullPopup.new()
	popup.setup([{"id": 371, "amount": 5}], GameData.config)
	add_child(popup)
	await get_tree().process_frame
	var received: Array = []   # Array 引用类型避 GDScript lambda 捕获 bool 值副本坑
	popup.confirmed.connect(func() -> void: received.append(true))
	popup._on_left()
	assert_eq(received.size(), 1, "left 触发 confirmed signal")
	popup.free()


# 溢出物品 4 列网格（源 overfull.lua:68-70 4 列）。批 2：GridContainer 静态化进 tscn
# （fill 只挂 icon），仍在 desc2/desc3 之间。
func test_popup_grid_4_cols() -> void:
	var popup := MailOverfullPopup.new()
	popup.setup([{"id": 371, "amount": 5}, {"id": 372, "amount": 3}], GameData.config)
	add_child(popup)
	await get_tree().process_frame
	var grids: Array = popup.find_children("*", "GridContainer", true, false)
	assert_eq(grids.size(), 1, "1 个 GridContainer")
	var grid: GridContainer = grids[0]
	assert_eq(grid.columns, 4, "网格 4 列（源 :68-70）")
	assert_eq(grid.get_child_count(), 2, "2 溢出物品图标")
	var vbox: VBoxContainer = grid.get_parent() as VBoxContainer
	assert_eq(vbox.get_child(2), grid, "Grid 位于 desc2(1)/desc3(3) 之间（源 ChaosNode 垂直顺序）")
	popup.free()


# P1（2026-07-16）：UI 文案 LSTR 化验证（title/desc/按钮文本走 GameData.config.get_lstr）。
func test_popup_texts_use_lstr() -> void:
	var popup := MailOverfullPopup.new()
	popup.setup([{"id": 371, "amount": 5}], GameData.config)
	add_child(popup)
	await get_tree().process_frame
	var cfg: ConfigManager = GameData.config
	var texts: Array = []
	for l in popup.find_children("*", "Label", true, false):
		texts.append(String(l.text))
	for b in popup.find_children("*", "Button", true, false):
		texts.append(String(b.text))
	assert_true(texts.has(cfg.get_lstr("mailoverfull.1.10.1.003")), "title 走 LSTR mailoverfull.1.10.1.003")
	assert_true(texts.has(cfg.get_lstr("overfull.1.10.1.001")), "desc1 走 LSTR overfull.1.10.1.001")
	assert_true(texts.has(cfg.get_lstr("overfull.1.10.1.002")), "desc2 走 LSTR overfull.1.10.1.002")
	assert_true(texts.has(cfg.get_lstr("overfull.1.10.1.003")), "desc3 走 LSTR overfull.1.10.1.003")
	assert_true(texts.has(cfg.get_lstr("mailoverfull.1.10.1.001")), "left 按钮 LSTR mailoverfull.1.10.1.001")
	assert_true(texts.has(cfg.get_lstr("mailoverfull.1.10.1.002")), "right 按钮 LSTR mailoverfull.1.10.1.002")
	popup.free()


# ══════════ 批 2 两件套守卫（2026-08-16，uieditor/mailoverfull.lua 声明表直译）══════════

# Frame NinePatch 守卫（本 task 核心修正点）：源 Scale9Sprite common_alert_bg
# (593x252px) capInsets CCRectMake(66.41,93.75,335.94,7.81) 纹理像素直读 →
# top=252-93.75-7.81=150.44 / bottom=93.75 / left=66.41 / right=593-66.41-335.94=190.65
# （NinePatchRect patch_margin 为 int，取 round：66/150/191/94）。
# 旧 TextureRect 整拉 463x363 高度方向 196.68→363.28 四角变形 → NinePatchRect 修正。
func test_frame_ninepatch_margins() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var frame: NinePatchRect = inst.get_node("Frame") as NinePatchRect
	assert_not_null(frame, "Frame 是 NinePatchRect（源 Scale9 cap(66.41,93.75,335.94,7.81)）")
	assert_eq(frame.patch_margin_left, 66, "Frame left = round(cap x 66.41)")
	assert_eq(frame.patch_margin_top, 150, "Frame top = round(H-y-h = 252-93.75-7.81 = 150.44)")
	assert_eq(frame.patch_margin_right, 191, "Frame right = round(W-x-w = 593-66.41-335.94 = 190.65)")
	assert_eq(frame.patch_margin_bottom, 94, "Frame bottom = round(cap y 93.75)")
	assert_almost_eq(frame.size.x, 463.28, 0.5, "Frame 显示宽 = scaleSize 463.28（保持）")
	assert_almost_eq(frame.size.y, 363.28, 0.5, "Frame 显示高 = scaleSize 363.28（保持）")
	# title_bg 同为声明表 Scale9Sprite → NinePatchRect
	# herodetail-title-mark(289x15px) cap(78.13,0,69.53,11.72)：
	# top=15-0-11.72=3.28 right=289-78.13-69.53=141.34（round：78/3/141/0）
	var title_bg: NinePatchRect = inst.get_node("TitleBg") as NinePatchRect
	assert_not_null(title_bg, "TitleBg 是 NinePatchRect（源 Scale9 cap(78.13,0,69.53,11.72)）")
	assert_eq(title_bg.patch_margin_left, 78, "TitleBg left = round(cap x 78.13)")
	assert_eq(title_bg.patch_margin_right, 141, "TitleBg right = round(289-78.13-69.53 = 141.34)")
	assert_almost_eq(title_bg.size.x, 359.38, 0.5, "TitleBg 宽 = scaleSize 359.38（宽向 1.59x 拉伸保角）")
	assert_almost_eq(title_bg.size.y, 11.72, 0.5, "TitleBg 高 = scaleSize 11.72")


# chrome 静态树 rect 照源声明表直译（layout.position=中心点，anchor(0.5,0.5)）：
# frame 463.28x363.28 中心 (400.78,216.41)；title_bg 359.38x11.72 中心 (400,355.47)；
# title size23 ccc3(253,215,17) 中心 (400,357.03)；left_button 121.09x54.69 中心
# (311.72,88.28)；right_button 同尺寸 中心 (487.5,89.06)。
# desc 滚动区源 overfull.lua:30 cliprect DGRectMake(65,130,455,230)（readnode:13-17
# ×0.78125 → (50.78,101.56,355.47,179.69)）——C1 修正：cliprect 是 frame 局部坐标
# （draglist container=self.ui.frame，原点=frame 左下角场景 (169.14,34.77) y-up，
# frame=463.28x363.28 中心(400.78,216.41)），+frame 原点再 to_godot 翻转 →
# Godot (299.92,243.98)-(655.39,423.67)。旧值误当场景空间直译致滚动区偏出 frame。
func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var frame: Control = inst.get_node("Frame") as Control
	assert_almost_eq(frame.position.x + frame.size.x * 0.5, 480.78, 0.5, "Frame 中心 x = 400.78+80")
	assert_almost_eq(frame.position.y + frame.size.y * 0.5, 343.59, 0.5, "Frame 中心 y = 560-216.41")
	var title_bg: Control = inst.get_node("TitleBg") as Control
	assert_almost_eq(title_bg.position.x + title_bg.size.x * 0.5, 480.0, 0.5, "TitleBg 中心 x = 400+80")
	assert_almost_eq(title_bg.position.y + title_bg.size.y * 0.5, 204.53, 0.5, "TitleBg 中心 y = 560-355.47")
	var title: Label = inst.get_node("%TitleLabel") as Label
	assert_almost_eq(title.position.x + title.size.x * 0.5, 480.0, 0.5, "Title 中心 x = 400+80")
	assert_almost_eq(title.position.y + title.size.y * 0.5, 202.97, 0.5, "Title 中心 y = 560-357.03")
	var left_btn: Button = inst.get_node("%LeftBtn") as Button
	assert_almost_eq(left_btn.size.x, 121.09, 0.5, "LeftBtn 宽 = scaleSize 121.09")
	assert_almost_eq(left_btn.size.y, 54.69, 0.5, "LeftBtn 高 = scaleSize 54.69")
	assert_almost_eq(left_btn.position.x + left_btn.size.x * 0.5, 391.72, 0.5, "LeftBtn 中心 x = 311.72+80")
	assert_almost_eq(left_btn.position.y + left_btn.size.y * 0.5, 471.72, 0.5, "LeftBtn 中心 y = 560-88.28")
	var right_btn: Button = inst.get_node("%RightBtn") as Button
	assert_almost_eq(right_btn.position.x + right_btn.size.x * 0.5, 567.5, 0.5, "RightBtn 中心 x = 487.5+80")
	assert_almost_eq(right_btn.position.y + right_btn.size.y * 0.5, 470.94, 0.5, "RightBtn 中心 y = 560-89.06")
	var scroll: ScrollContainer = inst.get_node("%DescScroll") as ScrollContainer
	assert_almost_eq(scroll.offset_left, 299.92, 0.5, "DescScroll 左 = frame左下169.14+DG(65)+80（frame 局部+原点）")
	assert_almost_eq(scroll.offset_top, 243.98, 0.5, "DescScroll 顶 = 560-(34.77+DG(130)+DG(230))")
	assert_almost_eq(scroll.offset_right, 655.39, 0.5, "DescScroll 右 = 299.92+DG(455)")
	assert_almost_eq(scroll.offset_bottom, 423.67, 0.5, "DescScroll 底 = 560-(34.77+DG(130))")
	# desc1 源 dimension DGSizeMake(400,0) = 312.5 宽（readnode:19-22 ×0.78125）
	var vbox: VBoxContainer = scroll.get_node("DescVBox") as VBoxContainer
	var desc1: Label = vbox.get_node("Desc1Label") as Label
	assert_almost_eq(desc1.size.x, 312.5, 0.5, "desc1 宽 = DG(400)=312.5（autowrap）")


# panel 零静态构造（宽口径白名单）：Grid/滚动 desc 全静态化；仅 cell wrapper 的
# Control.new(（task-11：GridContainer 会重置直接 child scale → wrapper 布局载体）。
func test_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(POPUP_PATH)
	assert_eq(text.count(".new("), text.count("Control.new("),
		"宽口径 .new( 总数 = Control.new( wrapper 白名单")


# theme variation 接线（读 tres 文本表项）。
# 源字号/色：title size23 ccc3(253,215,17)（声明表）；desc 3 段 size18
# ccc3(243,194,113)（overfull.lua:40-97）；按钮 size20 labelConfig ccc3(239,230,209)
# + sell_number cap(15.63,15.63,19.53,15.63) 三态。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("MailOverfullTitleLabel/font_sizes/font_size = 23"), "title 字号 23")
	assert_true(t.contains("MailOverfullTitleLabel/colors/font_color = Color(0.992157, 0.843137, 0.066667, 1)"),
		"title 色 = ccc3(253,215,17)")
	assert_true(t.contains("MailOverfullDescLabel/font_sizes/font_size = 18"), "desc 字号 18")
	assert_true(t.contains("MailOverfullDescLabel/colors/font_color = Color(0.952941, 0.760784, 0.443137, 1)"),
		"desc 色 = ccc3(243,194,113)")
	assert_true(t.contains("MailOverfullBtn/font_sizes/font_size = 20"), "按钮字号 20（声明表 size）")
	assert_true(t.contains("MailOverfullBtn/colors/font_color = Color(0.937255, 0.901961, 0.819608, 1)"),
		"按钮色 = labelConfig ccc3(239,230,209)")
	assert_true(t.contains("MailOverfullBtn/styles/normal = SubResource(\"SB_mo_btn_n\")"),
		"按钮三态 variation（sell_number cap(15.63,15.63,19.53,15.63)）")


func _has_tex(node: Node, path: String) -> bool:
	if (node is TextureRect or node is NinePatchRect) and node.get("texture") != null:
		if String((node.get("texture") as Texture2D).resource_path) == path:
			return true
	for c in node.get_children():
		if _has_tex(c, path):
			return true
	return false


# 溢满物品 icon 缩放/格子（task-11 守卫）：源 overfull.lua:79 createIconWithAmount(id,60)
# → 显示 60 点；ReadequipIcon frame Sprite2D 按纹理原尺寸渲染（94×95px）→ scale 基准 94
# （曾 60/72 致视觉 78×79 叠格；task-11 同步 min size=视觉盒，sep 8 → icon 间距不再叠）。
func test_overfull_grid_icon_scale_and_minsize() -> void:
	var popup := MailOverfullPopup.new()
	popup.setup([{"id": 371, "amount": 5}, {"id": 371, "amount": 5}], GameData.config)
	add_child(popup)
	await get_tree().process_frame
	var grid: GridContainer = popup.find_children("*", "GridContainer", true, false)[0] as GridContainer
	assert_eq(grid.get_child_count(), 2, "2 溢出 icon")
	var wrapper0: Control = grid.get_child(0)
	assert_almost_eq(wrapper0.custom_minimum_size.x, 60.0, 0.01, "wrapper min 宽=视觉宽（格子贴合）")
	assert_almost_eq(wrapper0.custom_minimum_size.y, 95.0 * 60.0 / 94.0, 0.01, "wrapper min 高=视觉高 60.64")
	var icon0: Control = wrapper0.get_child(0)
	assert_almost_eq(icon0.scale.x, 60.0 / 94.0, 0.0001, "icon scale=60/94（视觉宽 60，内层不被容器重置）")
	popup.free()
