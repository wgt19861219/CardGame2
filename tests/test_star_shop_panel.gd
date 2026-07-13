extends GutTest
# StarShopPanel 商品项 8 节点照源 itemstarshop 装配测试（P1-9 商品项）。
# 源 createStarList :535-594 填充 itemstarshop 8 节点模板 + draglist 横滚。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 itemstarshop 8 节点：item_bg/item_press/item_name/item_icon_container/cost_title_label/cost_bg/stone_container/stone_name。
func test_goods_item_assembles_8_source_nodes() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	var panel := StarShopPanel.new("starshop", {})
	add_child(panel)
	panel.setup_panel(ShopManager.new(cm), pd, BattleRng.new(1))
	var items: Array = panel._item_layer.get_children()
	assert_eq(items.size(), 5, "5 件灵魂石商品")
	assert_eq(panel._item_presses.size(), 5, "每件装配 item_press 高亮节点（源 :204 点击 setVisible）")
	var first: Control = items[0]
	var tex: int = 0
	var lbl: int = 0
	var ctl: int = 0
	for c in first.get_children():
		if c is TextureRect:
			tex += 1
		elif c is Label:
			lbl += 1
		elif c is Control:
			ctl += 1
	# item_bg + item_press + cost_bg = 3 TextureRect（售罄额外 noneTag → >=3）
	assert_true(tex >= 3, "item_bg + item_press + cost_bg 至少 3 TextureRect: " + str(tex))
	assert_eq(lbl, 3, "item_name + cost_title_label + stone_name = 3 Label")
	assert_eq(ctl, 2, "item_icon_container + stone_container = 2 Control")
	panel.free()


# 源 draglist 横滚（createStarList :519-531 getListWidth dx*len+40）→ ScrollContainer。
func test_goods_list_in_scroll_container() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	var panel := StarShopPanel.new("starshop", {})
	add_child(panel)
	panel.setup_panel(ShopManager.new(cm), pd, BattleRng.new(1))
	var scroll: ScrollContainer = panel._item_layer.get_parent() as ScrollContainer
	assert_not_null(scroll, "商品列表在 ScrollContainer 内（源 draglist 横滚）")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "横向滚动启用")
	panel.free()


# item_name 填源 getStarGoodsName（LSTR 商品名：小号行星杂物盒/中号恒星旅行箱/大号星际百宝箱）。
func test_item_name_filled_with_lstr_goods_name() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	var panel := StarShopPanel.new("starshop", {})
	add_child(panel)
	panel.setup_panel(ShopManager.new(cm), pd, BattleRng.new(1))
	var first: Control = panel._item_layer.get_child(0)
	var name_lbl: Label = null
	for c in first.get_children():
		if c is Label and String((c as Label).text).length() > 1 and String((c as Label).text).find("x") != 0 and String((c as Label).text).find("灵魂石") < 0:
			name_lbl = c as Label
			break
	assert_not_null(name_lbl, "找到 item_name Label")
	assert_true(String(name_lbl.text).find("号") >= 0, "item_name 填商品名（小/中/大号...）: " + String(name_lbl.text))
	panel.free()
