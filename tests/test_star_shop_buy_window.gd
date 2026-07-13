extends GutTest
# StarShopBuyWindow 9 节点照源 starshopbuywindow 装配测试（P1-9 确认窗）。
# 源 starshopbuywindow editorui 9 节点：frame/line/cancel/ok/title_1/icon_container/amount/title_2/name。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 9 节点：资源缺 frame 图/line 跳过，剩 cancel/ok(2 Button) + title_1/amount/title_2/name(4 Label) + icon_container(1 Control) = 7 直接子。
func test_buy_window_assembles_9_source_nodes() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	var mgr := ShopManager.new(cm)
	var panel := StarShopPanel.new("starshop", {})
	add_child(panel)
	panel.setup_panel(mgr, pd, BattleRng.new(1))
	var win := StarShopBuyWindow.new("starshopbuy", {})
	add_child(win)
	win.setup_buy(mgr, pd, BattleRng.new(1), 0, panel)
	var frame: Control = win._frame
	var lbl := 0
	var btn := 0
	var ctl := 0
	for c in frame.get_children():
		if c is Button:
			btn += 1
		elif c is Label:
			lbl += 1
		elif c is Control:
			ctl += 1
	assert_eq(lbl, 4, "title_1 + amount_label + title_2 + name_label = 4 Label")
	assert_eq(btn, 2, "cancel_button + ok_button = 2 Button")
	assert_eq(ctl, 1, "icon_container = 1 Control（frame 图/line 资源缺跳过）")
	panel.free()
	win.free()


# title_1 显源 LSTR ARE_YOU_SURE_TO_USE_IT（"确定兑换？"）。
func test_title_1_uses_lstr() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	var mgr := ShopManager.new(cm)
	var panel := StarShopPanel.new("starshop", {})
	add_child(panel)
	panel.setup_panel(mgr, pd, BattleRng.new(1))
	var win := StarShopBuyWindow.new("starshopbuy", {})
	add_child(win)
	win.setup_buy(mgr, pd, BattleRng.new(1), 0, panel)
	var has_title: bool = false
	for c in win._frame.get_children():
		if c is Label and String((c as Label).text).find("兑换") >= 0:
			has_title = true
			break
	assert_true(has_title, "title_1 显 LSTR ARE_YOU_SURE_TO_USE_IT（含\"兑换\"）")
	panel.free()
	win.free()
