extends GutTest
# ShopPanel View 装配集成测试（照源 shop.lua + market.lua 自动刷新/NPC 对话接入）。
# 验证 _next_refresh_label（下次刷新时刻）+ _talk_label（NPC 气泡）节点装配 + 自动刷新初始化。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 地精(2) Expire=3600 停留中 → _next_refresh_label 显 SHOP.MERCHANT_LEAVES_AFTER+time+SHOP.TIMES
# （"商人将于 HH:MM:SS 后离开"，expire 优先于 refresh，源 checkShopTimeType:222-229）；
# _talk_label 装配；init_auto_refresh 设 ts（地精有 Refresh Times）；init_expire 设 expire_end
func test_panel_assembles_labels_goblin() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	pd.diamond = 10000
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(2, ShopManager.new(cm), pd, BattleRng.new(1))
	var nrl: Label = panel.get("_next_refresh_label") as Label
	assert_not_null(nrl, "_next_refresh_label 节点存在")
	assert_true(String(nrl.text).find("商人将于") >= 0, "地精停留中显 MERCHANT_LEAVES_AFTER（expire 优先）: " + String(nrl.text))
	assert_not_null(panel.get("_talk_label") as Label, "_talk_label NPC 气泡节点存在")
	assert_true(pd.shop_auto_refresh.has(2), "init_auto_refresh 设地精 ts")
	assert_true(pd.shop_expire_end.has(2), "init_expire 设地精 expire_end")
	panel.free()


# 普通商人(1) Expire=0 → refresh 态 → _next_refresh_label 显 SHOP.NEXT_AUTOMATICALLY_REFRESH_TIME（无 expire 则 refresh，源 :222-229）
func test_panel_refresh_label_normal_shop() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(1, ShopManager.new(cm), pd, BattleRng.new(1))
	var nrl: Label = panel.get("_next_refresh_label") as Label
	assert_true(String(nrl.text).find("下次自动刷新") >= 0, "普通店 Expire=0 显 NEXT_AUTOMATICALLY_REFRESH_TIME（refresh 态）: " + String(nrl.text))
	assert_false(pd.shop_expire_end.has(1), "普通店 Expire=0 不 init_expire")
	panel.free()


# Shop6 Refresh Times 空（不 init_auto_refresh）但 Expire=3600 停留中 → _next_refresh_label 显"商人将于"（expire 态）
func test_panel_shop6_no_auto_refresh() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(6, ShopManager.new(cm), pd, BattleRng.new(1))
	var txt: String = String((panel.get("_next_refresh_label") as Label).text)
	assert_true(txt.find("商人将于") >= 0, "Shop6 停留中显 MERCHANT_LEAVES_AFTER: " + txt)
	assert_false(pd.shop_auto_refresh.has(6), "Shop6 无 Refresh Times 不 init_auto_refresh")
	assert_true(pd.shop_expire_end.has(6), "Shop6 init_expire 设 expire_end（Expire=3600）")
	panel.free()


# head_touch NPC 头像触摸层装配（点头像→Touch 对话）
func test_panel_head_touch_assembled() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(1, ShopManager.new(cm), pd, BattleRng.new(1))
	var head: Control = panel.get("_head_touch") as Control
	assert_not_null(head, "_head_touch 装配")
	assert_eq(head.mouse_filter, Control.MOUSE_FILTER_STOP, "head_touch 接点击")
	panel.free()
