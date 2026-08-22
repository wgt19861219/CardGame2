extends GutTest

# LanguageChangePanel 两件套守卫测试（批 4 Task 1，2026-08-17）。
# 照源 ui/popwindow/languagechange.lua（267 行）：
#   frame main_vit_tips cap(10,10,58,26) scaleSize(630,440) 中心(400,232)；
#   cancel 挂 frame（readnode root=frame）局部 (610,425) 中心锚 = 弹窗右上骑边；
#   语言按钮 createLanguageButton frame 局部绝对网格（x=100..540 间隔 110 /
#   y=340/250 间隔 90，标签 y+45 在按钮上方）；
#   标签 size20 ccc3(220,176,103)；源 title 被注释（:52-66）无标题。
# 点空间直译（批 3 定稿）：frame 子树坐标 = frame contentSize(630x440) 左下原点
# 点值直译（y' = 440-y）+ frame 左上(165,108)；贴图显示尺寸 = 像素/CS(1.28125)
# （本弹窗贴图均无 TextureConfig 条目，PIL 实测 2026-08-17）。
# 守卫：content 静态树 rect / NinePatch cap 公式 / close 层序（后于内容层）/
# 语言按钮 fill 语义（源坐标直译 + 显示尺寸÷CS + 源创建顺序）/ variation 接线 /
# panel 静态构造白名单 / 同语言点击 no-op。

const CONTENT_PATH: String = "res://scenes/ui/language_change_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/language_change_panel.gd"
const THEME_PATH: String = "res://resources/themes/default_theme.tres"
# lang/<key>.png 全语言实测 96x62 像素 → /CS = 74.93x48.39（PIL 2026-08-17）
const LANG_W: float = 74.93
const LANG_H: float = 48.39
# common_tips_button_close_1/2 65x66 → /CS = 50.73x51.51
const CLOSE_W: float = 50.73
const CLOSE_H: float = 51.51
# main_vit_tips 103x61，源 scaleSize(630,440) 中心(400,232) → (165,108)-(795,548)
const FRAME_L: float = 85.0
const FRAME_T: float = 28.0
const FRAME_W: float = 630.0
const FRAME_H: float = 440.0

var _cm: ConfigManager
var _lm: LanguageManager


func before_all() -> void:
	_cm = ConfigManager.new()
	_cm.load_all()
	_lm = LanguageManager.new()
	_lm.init(_cm, "zh-CN")


# ── content 静态树（源 :46-50 frame / :67-90 cancel 挂 frame / 语言按钮宿主）──

func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# Frame（源 Scale9 main_vit_tips scaleSize(630,440) 中心(400,232) →
	# Godot 中心 (480,328) → 左上 (480-315, 328-220)）
	var frame: NinePatchRect = inst.get_node("%Frame") as NinePatchRect
	assert_almost_eq(frame.offset_left, FRAME_L, 0.1, "Frame 左 = to_godot(400,232).x - 630/2")
	assert_almost_eq(frame.offset_top, FRAME_T, 0.1, "Frame 顶 = to_godot(400,232).y - 440/2")
	assert_almost_eq(frame.offset_right - frame.offset_left, FRAME_W, 0.1, "Frame 宽 = 源 scaleSize 直译")
	assert_almost_eq(frame.offset_bottom - frame.offset_top, FRAME_H, 0.1, "Frame 高 = 源 scaleSize 直译")
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/main_vit_tips.png",
		"Frame 贴图照源 main_vit_tips")
	# cap(10,10,58,26) 批 1 公式（贴图 103x61）：left=10 top=61-10-26=25
	# right=103-10-58=35 bottom=10（现值 top/bottom 曾写反，2026-08-17 修正）
	assert_eq(frame.patch_margin_left, 10, "NinePatch left = cap.x")
	assert_eq(frame.patch_margin_top, 25, "NinePatch top = H-y-h = 61-10-26")
	assert_eq(frame.patch_margin_right, 35, "NinePatch right = W-x-w = 103-10-58（水平不反转）")
	assert_eq(frame.patch_margin_bottom, 10, "NinePatch bottom = cap.y")
	# CloseBtn（源 cancel frame 局部(610,425) 中心锚 → 全屏中心
	# (165+610, 108+(440-425)) = (775,123)，右上骑边；65x66/CS）
	var close_btn: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(close_btn.offset_left, 695.0 - CLOSE_W * 0.5, 0.1,
		"CloseBtn 左 = 775-50.73/2（源 frame 局部 610,425 直译）")
	assert_almost_eq(close_btn.offset_top, 43.0 - CLOSE_H * 0.5, 0.1, "CloseBtn 顶 = 123-51.51/2")
	assert_almost_eq(close_btn.offset_right - close_btn.offset_left, CLOSE_W, 0.1, "CloseBtn 宽 = 65/CS")
	assert_almost_eq(close_btn.offset_bottom - close_btn.offset_top, CLOSE_H, 0.1, "CloseBtn 高 = 66/CS")
	assert_eq(close_btn.texture_normal.resource_path,
		"res://assets/ui/alpha/HVGA/common/common_tips_button_close_1.png", "normal 照源 cancel")
	assert_eq(close_btn.texture_pressed.resource_path,
		"res://assets/ui/alpha/HVGA/common/common_tips_button_close_2.png",
		"源 cancel_press Sprite visible 切换 → texture_pressed 等价（1.1 scale 放大受控裁剪）")
	assert_eq(close_btn.stretch_mode, TextureButton.STRETCH_SCALE,
		"TextureButton stretch_mode=0 显式（默认 KEEP 不填 rect，批 2 方法论）")
	# LangHost（语言按钮宿主，Frame 全域；源语言按钮 readnode root=ui.bg(frame)）
	var host: Control = inst.get_node("%LangHost") as Control
	assert_eq(host.get_parent(), frame, "LangHost 挂 Frame 子树（源 readnode root=frame）")
	assert_almost_eq(host.offset_right - host.offset_left, FRAME_W, 0.1, "LangHost 覆盖 Frame 全域")
	assert_almost_eq(host.offset_bottom - host.offset_top, FRAME_H, 0.1, "LangHost 覆盖 Frame 全域")
	assert_eq(host.mouse_filter, Control.MOUSE_FILTER_IGNORE, "LangHost 装饰容器不吞点击")


# 绘制序守卫（excavate 批方法论：close 后声明防内容盖 close 拦截输入）。
# 源声明序 frame(:46) → cancel(:67) → 语言按钮(:96-100 z=200)——源按钮区域
# (x≤540) 与 cancel(610,425) 不重叠无视觉冲突，Godot 侧统一 close 收尾声明。
func test_close_draw_order() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var frame: CanvasItem = inst.get_node("%Frame") as CanvasItem
	var close_btn: CanvasItem = inst.get_node("%CloseBtn") as CanvasItem
	var host: CanvasItem = inst.get_node("%LangHost") as CanvasItem
	assert_lt(frame.get_index(), close_btn.get_index(), "Frame 先于 CloseBtn（兄弟声明序，close 收尾）")


# ── panel fill 语义（源 :96-100 七语言创建顺序 + :125-191 createLanguageButton）──

# 语言按钮网格照源直译：frame 局部点值（y'=440-y）中心锚 + 显示尺寸 96x62/CS。
# 源创建顺序：en-US de-DE ko-KR zh-CN ru-RU（y=340 行）/ tr-TR pt-BR（y=250 行）。
func test_lang_buttons_layout() -> void:
	var panel: LanguageChangePanel = LanguageChangePanel.new()
	panel.setup_panel(_lm)
	add_child_autofree(panel)
	await get_tree().process_frame
	var host: Control = panel._content.get_node("%LangHost") as Control
	# 源 readnode 平挂 frame：每语言 button+label 兄弟交替（源 :131-180 三节点平级 z=200）
	var btn_count: int = 0
	var lbl_count: int = 0
	for i in range(host.get_child_count()):
		if host.get_child(i) is TextureButton:
			btn_count += 1
		elif host.get_child(i) is Label:
			lbl_count += 1
	assert_eq(btn_count, 7, "语言按钮数 = 源启用 7 语言（其余源注释未启用）")
	assert_eq(lbl_count, 7, "语言名标签数 = 7（每语言 button+label 平挂）")
	# 首个 en-US：frame 局部中心 (100, 440-340=100) → 左上 (100-37.47, 100-24.20)
	var first: TextureButton = host.get_child(0) as TextureButton
	assert_almost_eq(first.position.x + first.size.x * 0.5, 100.0, 0.1,
		"en-US 中心 x = 源 x=100 直译（frame 局部）")
	assert_almost_eq(first.position.y + first.size.y * 0.5, 100.0, 0.1, "en-US 中心 y = 440-340（y' 翻转）")
	assert_almost_eq(first.size.x, LANG_W, 0.1, "按钮宽 = 96/CS（非原始像素）")
	assert_almost_eq(first.size.y, LANG_H, 0.1, "按钮高 = 62/CS（非原始像素）")
	assert_eq(first.texture_normal.resource_path,
		"res://assets/ui/alpha/HVGA/lang/en-US.png", "贴图照源 getLanguagePng(en-US)")
	assert_eq(first.stretch_mode, TextureButton.STRETCH_SCALE,
		"procedural 按钮显式 stretch_mode=SCALE（默认 KEEP 不缩放贴图）")
	# 第 2 列间隔 = 源 x 间隔 110 直译（btn+lbl 交替，第 2 个按钮 index=2）
	var second: TextureButton = host.get_child(2) as TextureButton
	assert_almost_eq(second.position.x - first.position.x, 110.0, 0.1, "列距 = 源 x=100→210 直译")
	# 第 6 个语言 tr-TR（btn index = 5*2=10）：第 2 行 (100, 440-250=190)
	var sixth: TextureButton = host.get_child(10) as TextureButton
	assert_almost_eq(sixth.position.x + sixth.size.x * 0.5, 100.0, 0.1, "tr-TR 中心 x = 源二行 x=100")
	assert_almost_eq(sixth.position.y + sixth.size.y * 0.5, 190.0, 0.1, "tr-TR 中心 y = 440-250（二行）")
	# global 级防 parenting：frame 左上 (165,108) + 局部 → 全屏 (265,208)
	assert_almost_eq(first.global_position.x + first.size.x * 0.5, 185.0, 0.5,
		"en-US 全屏中心 x = 165+100（frame 局部→全屏防 parenting 错位）")
	assert_almost_eq(first.global_position.y + first.size.y * 0.5, 128.0, 0.5,
		"en-US 全屏中心 y = 108+100")


# 标签（源 :164-179 language_label size20 ccc3(220,176,103) position (x,y+45) 中心锚）：
# variation 接线 + 中心点照源（按钮中心上方 45）+ 文案走 LSTR。
func test_lang_label_variation_and_position() -> void:
	var panel: LanguageChangePanel = LanguageChangePanel.new()
	panel.setup_panel(_lm)
	add_child_autofree(panel)
	var host: Control = panel._content.get_node("%LangHost") as Control
	var lbl: Label = host.get_child(1) as Label
	assert_eq(String(lbl.theme_type_variation), "LangNameLabel",
		"语言名走 LangNameLabel variation（禁运行时 color override）")
	assert_eq(lbl.text, _lm.get_lstr("CONFIGURE.LANGUAGE.EN-US"),
		"文案照源 T(LSTR(CONFIGURE.LANGUAGE.<LANG>))")
	assert_eq(lbl.mouse_filter, Control.MOUSE_FILTER_IGNORE, "标签装饰不吞点击")
	# 中心锚点照源（x, y+45 → Godot (x, 440-y-45)）；四锚同点 + grow both
	assert_almost_eq(lbl.anchor_left * FRAME_W, 100.0, 0.1, "标签锚 x = 源 x=100（按钮正上）")
	assert_almost_eq(lbl.anchor_top * FRAME_H, 55.0, 0.1, "标签锚 y = 440-340-45（源 y+45 上方）")
	assert_eq(lbl.anchor_left, lbl.anchor_right, "标签四锚同点 x（源 readnode 默认中心锚）")
	assert_eq(lbl.anchor_top, lbl.anchor_bottom, "标签四锚同点 y（禁单侧锚点写法）")


# theme variation 接线（GUT 下节点级不解析 variation，读 tres 文本表项）。
func test_theme_variation_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("LangNameLabel/base_type = &\"Label\""),
		"LangNameLabel variation 注册")
	assert_true(t.contains("LangNameLabel/font_sizes/font_size = 20"),
		"LangNameLabel 字号 20（源 size=20）")
	assert_true(t.contains("LangNameLabel/colors/font_color = Color(0.862745, 0.690196, 0.403914, 1)"),
		"LangNameLabel 色 = 220,176,103（/255）")


# panel 静态构造白名单（宽口径）：静态结构全在 tscn，panel 内 .new( 仅允许
# 语言行动态构造（TextureButton + Label，源 createLanguageButton procedural 行）。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count(".new("), 2,
		"panel .new( 仅 2 处（TextureButton/Label 语言行动态白名单；VBox/GridContainer 壳已消亡）")


# 同语言点击 no-op（源 doClickChangeLanguage :241-243 currentLang == planguage return），
# 不触发 reload_current_scene。
func test_same_lang_click_noop() -> void:
	var panel: LanguageChangePanel = LanguageChangePanel.new()
	panel.setup_panel(_lm)
	add_child_autofree(panel)
	var host: Control = panel._content.get_node("%LangHost") as Control
	var zh_btn: TextureButton = host.get_child(6) as TextureButton
	assert_eq(zh_btn.texture_normal.resource_path,
		"res://assets/ui/alpha/HVGA/lang/zh-CN.png", "第 4 个 = zh-CN（源创建顺序）")
	zh_btn.pressed.emit()
	assert_eq(_lm.get_language(), "zh-CN", "同语言点击 no-op（不切换不 reload）")
