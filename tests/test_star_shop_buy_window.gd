extends GutTest
# StarShopBuyWindow 测试（P1-9 确认窗；2026-08-16 批 2 两件套改造）。
# 源对照：uieditor/starshopbuywindow.lua 声明表（9 节点，root=frame，position=中心点，
# fix_wh=显示尺寸）+ popwindow/starshopbuywindow.lua（fill/信号/show 动画）。
# 结构：静态树守卫（rect 照源直译）+ fill 行为 + 零静态构造白名单。

var cm: ConfigManager
var _panel: StarShopPanel   # 顺手修（批 2 Task 5 滚清单）：_make_window 建的宿主面板，用例结尾统一 free


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_window(p_items: Dictionary = {}) -> StarShopBuyWindow:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	for k in p_items:
		pd.items[int(k)] = int(p_items[k])
	var mgr := ShopManager.new(cm)
	var panel := StarShopPanel.new("starshop", {})
	add_child(panel)
	_panel = panel
	panel.setup_panel(mgr, pd, BattleRng.new(1))
	var win := StarShopBuyWindow.new("starshopbuy", {})
	add_child(win)
	win.setup_buy(mgr, pd, BattleRng.new(1), 0, panel)
	return win


# 9 节点：frame/line/cancel_button/ok_button/title_1/icon_container/amount_label/title_2/name_label。
# frame 图（shop_star_tips_frame/delimeter/button_1/2.png）源导出物未含 → StyleBox/Button variation 降级。
func test_buy_window_assembles_9_source_nodes() -> void:
	var win: StarShopBuyWindow = _make_window()
	var frame: Control = win._frame
	for w in ["Line", "%CancelBtn", "%OkBtn", "%Title1Label", "%IconContainer", "%AmountLabel", "%Title2Label", "%NameLabel"]:
		assert_true(frame.has_node(w), "声明表子节点存在: " + w)
	_panel.free()
	win.free()


# fill：title_1 显源 LSTR ARE_YOU_SURE_TO_USE_IT（"确定兑换？"）；amount "x{cost}"；
# title_2 EXCHANGE；name 商品名（源 starshopbuywindow.lua :104-105 + 声明表 T() 文案）。
func test_window_fill_texts() -> void:
	var win: StarShopBuyWindow = _make_window()
	var frame: Control = win._frame
	var title1: Label = frame.get_node("%Title1Label") as Label
	assert_true(String(title1.text).find("兑换") >= 0, "title_1 显 LSTR ARE_YOU_SURE_TO_USE_IT（含\"兑换\"）")
	var amount: Label = frame.get_node("%AmountLabel") as Label
	assert_true(String(amount.text).begins_with("x"), "amount_label 填 x{stone_amount}: " + String(amount.text))
	var title2: Label = frame.get_node("%Title2Label") as Label
	assert_eq(String(title2.text), cm.get_lstr("STARSHOPBUYWINDOW.EXCHANGE"), "title_2 显 LSTR EXCHANGE")
	var name_lbl: Label = frame.get_node("%NameLabel") as Label
	assert_true(String(name_lbl.text).find("号") >= 0, "name_label 填商品名: " + String(name_lbl.text))
	var cancel: Button = frame.get_node("%CancelBtn") as Button
	assert_eq(String(cancel.text), cm.get_lstr("CHATCONFIG.CANCEL"), "cancel 显 LSTR CHATCONFIG.CANCEL")
	var ok: Button = frame.get_node("%OkBtn") as Button
	assert_eq(String(ok.text), cm.get_lstr("CHATCONFIG.CONFIRM"), "ok 显 LSTR CHATCONFIG.CONFIRM")
	_panel.free()
	win.free()


# ══════════ 批 2 两件套守卫（2026-08-16，uieditor/starshopbuywindow.lua 声明表直译）══════════

const CONTENT_PATH := "res://scenes/ui/star_shop_buy_window_content.tscn"
const WINDOW_PATH := "res://scripts/ui/star_shop_buy_window.gd"
const THEME_PATH := "res://resources/themes/default_theme.tres"


# 静态树 rect 照源直译（frame 局部空间 = Cocos 左下原点 y-up → Godot Frame 容器内
# (x, H-y)，H=289.84）：
# frame fix_wh(466.41x289.84) 中心(409.38,200) → 全屏 (256.18,215.08)-(722.58,504.92)；
# line fix_wh(405.47x7.81) 中心(230.86,102.73)；cancel fix_wh(120.31x53.91) 中心(141.02,66.8)；
# ok 同尺寸 中心(308.98,64.45)；title_1 中心(240,140)；icon_container Layer 42.97x42.97
# anchor(0,0) at(180,155)；amount anchor(0,0.5) at(240,180)；title_2 中心(140,220)；
# name anchor(0,0.5) at(186.33,220)。
func test_content_static_tree_source_rects() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var frame: Control = inst.get_node("%Frame") as Control
	assert_almost_eq(frame.size.x, 466.41, 0.5, "Frame 宽 = fix_wh 466.41")
	assert_almost_eq(frame.size.y, 289.84, 0.5, "Frame 高 = fix_wh 289.84")
	assert_almost_eq(frame.position.x + frame.size.x * 0.5, 409.38, 0.5, "Frame 中心 x = 409.38+80")
	assert_almost_eq(frame.position.y + frame.size.y * 0.5, 280.0, 0.5, "Frame 中心 y = 560-200")
	var line: Control = frame.get_node("Line") as Control
	assert_almost_eq(line.position.x + line.size.x * 0.5, 230.86, 0.5, "line 中心 x 照声明表")
	assert_almost_eq(line.position.y + line.size.y * 0.5, 289.84 - 102.73, 0.5, "line 中心 y = H-102.73")
	assert_almost_eq(line.size.x, 405.47, 0.5, "line 宽 = fix_wh 405.47")
	var cancel: Button = frame.get_node("%CancelBtn") as Button
	assert_almost_eq(cancel.position.x + cancel.size.x * 0.5, 141.02, 0.5, "cancel 中心 x 照声明表")
	assert_almost_eq(cancel.position.y + cancel.size.y * 0.5, 289.84 - 66.8, 0.5, "cancel 中心 y = H-66.8")
	assert_almost_eq(cancel.size.x, 120.31, 0.5, "cancel 宽 = fix_wh 120.31")
	assert_almost_eq(cancel.size.y, 53.91, 0.5, "cancel 高 = fix_wh 53.91")
	var ok: Button = frame.get_node("%OkBtn") as Button
	assert_almost_eq(ok.position.x + ok.size.x * 0.5, 308.98, 0.5, "ok 中心 x 照声明表")
	assert_almost_eq(ok.position.y + ok.size.y * 0.5, 289.84 - 64.45, 0.5, "ok 中心 y = H-64.45")
	var title1: Label = frame.get_node("%Title1Label") as Label
	assert_almost_eq(title1.position.x + title1.size.x * 0.5, 240.0, 1.0, "title_1 中心 x 照声明表")
	assert_almost_eq(title1.position.y + title1.size.y * 0.5, 289.84 - 140.0, 1.0, "title_1 中心 y = H-140")
	var icon_host: Control = frame.get_node("%IconContainer") as Control
	assert_almost_eq(icon_host.position.x, 180.0, 0.5, "icon_container x = 声明表 anchor(0,0) x")
	assert_almost_eq(icon_host.position.y, 289.84 - 155.0 - 42.97, 0.5, "icon_container y = H-y-h")
	assert_almost_eq(icon_host.size.x, 42.97, 0.5, "icon_container 宽 = scaleSize 42.97")
	var amount: Label = frame.get_node("%AmountLabel") as Label
	assert_almost_eq(amount.position.x, 240.0, 0.5, "amount x = 声明表 anchor(0,0.5) x")
	assert_almost_eq(amount.position.y + amount.size.y * 0.5, 289.84 - 180.0, 1.0, "amount 垂直中心 = H-180")
	var title2: Label = frame.get_node("%Title2Label") as Label
	assert_almost_eq(title2.position.x + title2.size.x * 0.5, 140.0, 1.0, "title_2 中心 x 照声明表")
	assert_almost_eq(title2.position.y + title2.size.y * 0.5, 289.84 - 220.0, 1.0, "title_2 中心 y = H-220")
	var name_lbl: Label = frame.get_node("%NameLabel") as Label
	assert_almost_eq(name_lbl.position.x, 186.33, 0.5, "name x = 声明表 anchor(0,0.5) x")
	assert_almost_eq(name_lbl.position.y + name_lbl.size.y * 0.5, 289.84 - 220.0, 1.0, "name 垂直中心 = H-220")


# global_position 级防 parenting 回归：Frame 挂 content root 直下（源 frame 挂 editorui 根
# CCLayer = 场景空间），root 全屏 960x640。Frame 全局左上 = (256.18, 215.08)。
func test_frame_global_position_guard() -> void:
	var win: StarShopBuyWindow = _make_window()
	var frame: Control = win._frame
	assert_almost_eq(frame.global_position.x, 176.18, 0.5, "Frame 全局 x = 409.38-233.20+80")
	assert_almost_eq(frame.global_position.y, 135.08, 0.5, "Frame 全局 y = 560-200-144.92")
	_panel.free()
	win.free()


# 窗口零静态构造（宽口径白名单）：仅开箱结果弹窗工厂 PopTavernLoot.new( 1 处。
func test_window_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(WINDOW_PATH)
	assert_eq(text.count("PopTavernLoot.new("), 1, "仅 1 处开箱弹窗工厂 PopTavernLoot.new(")
	assert_eq(text.count(".new("), 1, "宽口径 .new( 总数 = 白名单之和")


# theme variation 接线（读 tres 文本表项；图缺降级走 variation 不走 theme_override_colors）。
# 源字号/色：title_1/title_2 size20 ccc3(129,204,255)；amount/name size20 ccc3(131,240,255)
# （声明表 config）；按钮 fontinfo ui_normal_button 无 size 覆盖 → 默认 17 白+shadow(63,5,0)。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("StarShopBuyTitleLabel/colors/font_color = Color(0.505882, 0.8, 1, 1)"),
		"title_1/2 色 = ccc3(129,204,255)")
	assert_true(t.contains("StarShopBuyTitleLabel/font_sizes/font_size = 20"), "title_1/2 字号 20")
	assert_true(t.contains("StarShopBuyValueLabel/colors/font_color = Color(0.513726, 0.941176, 1, 1)"),
		"amount/name 色 = ccc3(131,240,255)")
	assert_true(t.contains("StarShopBuyValueLabel/font_sizes/font_size = 20"), "amount/name 字号 20")
	assert_true(t.contains("StarShopBuyBtn/styles/normal = SubResource(\"SB_ssbuy_n\")"),
		"buy 按钮三态 variation（图缺 StyleBox 降级）")
	assert_true(t.contains("StarShopBuyBtn/font_sizes/font_size = 17"),
		"按钮文字 fontinfo 默认 17（Button variation 直接接管，package HandbookLabel 同款先例）")
