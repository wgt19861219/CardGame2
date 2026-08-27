extends GutTest
# StarShopPanel 测试（P1-9 商品项；2026-08-16 批 2 两件套改造）。
# 源对照：ui/market/shop.lua create("starshop") + createStarList(:512-597) +
# uieditor/itemstarshop.lua 声明表（8 节点商品格模板，fix_wh=显示尺寸，position=中心点）。
# 结构：chrome 静态树守卫（star_shop_content.tscn）+ 商品格行模板守卫
# （star_shop_item.tscn）+ fill 行为（价格色/售罄）+ 零静态构造白名单。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel(p_items: Dictionary = {}) -> StarShopPanel:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	for k in p_items:
		pd.items[int(k)] = int(p_items[k])
	var panel := StarShopPanel.new("starshop", {})
	add_child(panel)
	panel.setup_panel(ShopManager.new(cm), pd, BattleRng.new(1))
	return panel


# 源 createStarList :535-594：5 件灵魂石商品（STAR_TYPES=[0,0,1,1,2]），每件 = itemstarshop
# 声明表 8 节点（item_bg/item_name/item_icon_container/cost_title_label/cost_bg/item_press/
# stone_container/stone_name）+ fill 附挂 noneTag。两件套后走 star_shop_item.tscn 模板。
func test_goods_items_from_item_template() -> void:
	var panel: StarShopPanel = _make_panel()
	var items: Array = panel._item_layer.get_children()
	assert_eq(items.size(), 5, "5 件灵魂石商品")
	for it in items:
		assert_true(it is TextureButton, "商品格是 star_shop_item.tscn 模板实例（TextureButton root）")
	var first: TextureButton = items[0] as TextureButton
	assert_not_null(first.texture_normal, "item_bg 纹理（root texture_normal）")
	assert_not_null(first.texture_pressed, "item_press 高亮纹理（root texture_pressed，源 :204 按下显示）")
	# 声明表 7 子节点（item_press 由 root pressed 态承担）：name/icon_host/cost_title/cost_bg/stone_host/stone_name/none_tag
	var wanted := ["%ItemName", "%ItemIconHost", "CostTitleLabel", "CostBg", "%StoneHost", "%StoneName", "%NoneTag"]
	for w in wanted:
		assert_true(first.has_node(w), "声明表子节点存在: " + w)
	panel.free()


# 源 draglist cliprect CCRectMake(65,35,670,325)（shop.lua:738）→ 场景空间直译
# (145,200)-(815,525)；商品格 getItemPos(:516-518) ox=90 oy=35 dx=212（listLayer=场景
# 原点）→ 首格全局左上 (170, 560-(35+286.72)=238.28)。
func test_goods_list_in_scroll_container() -> void:
	var panel: StarShopPanel = _make_panel()
	var scroll: ScrollContainer = panel._item_layer.get_parent() as ScrollContainer
	assert_not_null(scroll, "商品列表在 ScrollContainer 内（源 draglist 横滚）")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_NEVER, "横向滚动启用但指示条不显示（E5：源 draglist 无横条）")
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "纵向禁滚（单行商品）")
	assert_almost_eq(scroll.offset_left, 65.0, 0.5, "裁剪层左 = 65+80（cliprect 直译）")
	assert_almost_eq(scroll.offset_top, 120.0, 0.5, "裁剪层顶 = 560-(35+325)")
	assert_almost_eq(scroll.offset_right, 735.0, 0.5, "裁剪层右 = 735+80")
	assert_almost_eq(scroll.offset_bottom, 445.0, 0.5, "裁剪层底 = 560-35")
	var first: Control = panel._item_layer.get_child(0) as Control
	assert_almost_eq(first.global_position.x, 90.0, 0.5, "首格全局 x = 90+80（getItemPos ox=90）")
	assert_almost_eq(first.global_position.y, 158.28, 0.5, "首格全局 y = 560-(35+286.72)（oy=35 底对齐）")
	assert_almost_eq((panel._item_layer.get_child(1) as Control).global_position.x, 302.0, 0.5,
		"次格全局 x = 170+212（dx）")
	panel.free()


# item_name 填源 getStarGoodsName（LSTR 商品名：小号行星杂物盒/中号恒星旅行箱/大号星际百宝箱）。
func test_item_name_filled_with_lstr_goods_name() -> void:
	var panel: StarShopPanel = _make_panel()
	var first: Control = panel._item_layer.get_child(0) as Control
	var name_lbl: Label = first.get_node("%ItemName") as Label
	assert_true(String(name_lbl.text).find("号") >= 0, "item_name 填商品名（小/中/大号...）: " + String(name_lbl.text))
	panel.free()


# ══════════ 批 2 两件套守卫（2026-08-16，uieditor/itemstarshop.lua 声明表直译）══════════

const CONTENT_PATH := "res://scenes/ui/star_shop_content.tscn"
const ITEM_PATH := "res://scenes/ui/star_shop_item.tscn"
const PANEL_PATH := "res://scripts/ui/star_shop_panel.gd"
const THEME_PATH := "res://resources/themes/default_theme.tres"


# chrome 静态树（star_shop_content.tscn）：rect 照源换算。
# 源 marketconfig["starshop"].ui_config：frame shop_star_frame.png(800x480px) 中心 ccp(400,220)
# 无 fix_wh → 显示 624.49x374.51（÷CS）；title shop_star_title.png(257x46px) 中心 ccp(403,382)
# → 显示 200.49x35.90；back 走 package 惯例 57.76x58.54（74x75px ÷CS）。
# draglist cliprect CCRectMake(65,35,670,325)（shop.lua:738）。
# StoneLabel 为迁移发明常驻标签（源无面板级灵魂石余额显示）→ 删（受控裁剪）。
func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var frame: TextureRect = inst.get_node("Frame") as TextureRect
	assert_almost_eq(frame.size.x, 624.49, 0.5, "Frame 宽 = 800px/CS（旧值 800 未÷CS）")
	assert_almost_eq(frame.size.y, 374.51, 0.5, "Frame 高 = 480px/CS")
	assert_almost_eq(frame.position.x + frame.size.x * 0.5, 400.0, 0.5, "Frame 中心 x = 400+80")
	assert_almost_eq(frame.position.y + frame.size.y * 0.5, 260.0, 0.5, "Frame 中心 y = 560-220")
	var title_img: TextureRect = inst.get_node("TitleImg") as TextureRect
	assert_almost_eq(title_img.size.x, 200.49, 0.5, "TitleImg 宽 = 257px/CS")
	assert_almost_eq(title_img.size.y, 35.9, 0.5, "TitleImg 高 = 46px/CS")
	assert_almost_eq(title_img.position.x + title_img.size.x * 0.5, 403.0, 0.5, "TitleImg 中心 x = 403+80")
	assert_almost_eq(title_img.position.y + title_img.size.y * 0.5, 98.0, 0.5, "TitleImg 中心 y = 560-382")
	var close_btn: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(close_btn.size.x, 57.76, 0.5, "CloseBtn 宽 = 74px/CS（package 惯例）")
	assert_almost_eq(close_btn.size.y, 58.54, 0.5, "CloseBtn 高 = 75px/CS")
	assert_eq(close_btn.stretch_mode, TextureButton.STRETCH_SCALE, "CloseBtn stretch=SCALE（4.7 默认 KEEP 溢出）")
	var scroll: ScrollContainer = inst.get_node("%GoodsScroll") as ScrollContainer
	assert_almost_eq(scroll.offset_left, 65.0, 0.5, "GoodsScroll 左照源 cliprect")
	assert_almost_eq(scroll.offset_top, 120.0, 0.5, "GoodsScroll 顶照源 cliprect")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_NEVER, "E5：横滚保留指示不显示（源 draglist 无横条）")
	# E4 倒计时行（源 shop.lua:801-851 time_title_node 三 Label 横排中心 (400,350)→(400,130)）
	var time_row: HBoxContainer = inst.get_node("%TimeRow") as HBoxContainer
	assert_almost_eq(time_row.anchor_left, 0.5, 0.001, "TimeRow 水平中心锚（源 HorizontalNode 中心 x=400）")
	assert_almost_eq(time_row.anchor_top, 130.0 / 480.0, 0.001, "TimeRow 垂直锚 y=130（to_godot(400,350)）")
	assert_eq(time_row.get_child_count(), 3, "三 Label：title/值/suffix（源 :811-850）")
	assert_eq(time_row.get_theme_constant(&"separation"), 10, "间距 10（源 HorizontalNode offset）")
	# 迁移发明删除守卫：StoneLabel（源无）
	assert_eq(inst.find_children("StoneLabel", "Control", true, false).size(), 0,
		"StoneLabel 迁移发明已删（受控裁剪）")


# 商品格行模板静态树（star_shop_item.tscn）：itemstarshop.lua 声明表直译。
# item_bg fix_wh(207.03x286.72)；item_name 中心(102.73,248.05) size20；
# item_icon_container Layer 156.25x156.25 anchor(0,0) at(35.55,113.67)；
# cost_title_label 中心(103.52,89.45) size19；cost_bg fix_wh(135.16x28.91) 中心(112.11,49.61)；
# stone_container Layer 45.31x45.31 anchor(0,0) at(26.17,26.95)；
# stone_name anchor(0,0.5) at(72.27+30,51.17)（源 :591 ccpAdd(30,0)）size19；
# noneTag 源 :577-588 anchor(0,0) at(0,0) 显示 265x367px/CS≈206.83x286.51。
func test_item_template_static_rects() -> void:
	var inst: TextureButton = (load(ITEM_PATH) as PackedScene).instantiate() as TextureButton
	add_child_autofree(inst)
	assert_almost_eq(inst.size.x, 207.03, 0.5, "item 格宽 = fix_wh w 直译")
	assert_almost_eq(inst.size.y, 286.72, 0.5, "item 格高 = fix_wh h 直译")
	assert_eq(inst.stretch_mode, TextureButton.STRETCH_SCALE, "item stretch=SCALE（默认 KEEP 原尺寸溢出）")
	var icon_host: Control = inst.get_node("%ItemIconHost") as Control
	assert_almost_eq(icon_host.position.x, 35.55, 0.5, "icon_host x = 声明表 anchor(0,0) x")
	assert_almost_eq(icon_host.position.y, 286.72 - 113.67 - 156.25, 0.5, "icon_host y = H-y-h（左下锚点翻转）")
	assert_almost_eq(icon_host.size.x, 156.25, 0.5, "icon_host 宽 = scaleSize 156.25")
	assert_almost_eq(icon_host.size.y, 156.25, 0.5, "icon_host 高 = scaleSize 156.25")
	var name_lbl: Label = inst.get_node("%ItemName") as Label
	assert_almost_eq(name_lbl.position.x + name_lbl.size.x * 0.5, 102.73, 1.0, "item_name 中心 x 照声明表")
	assert_almost_eq(name_lbl.position.y + name_lbl.size.y * 0.5, 286.72 - 248.05, 1.0, "item_name 中心 y 照声明表")
	var cost_bg: TextureRect = inst.get_node("CostBg") as TextureRect
	assert_almost_eq(cost_bg.size.x, 135.16, 0.5, "cost_bg 宽 = fix_wh 135.16")
	assert_almost_eq(cost_bg.size.y, 28.91, 0.5, "cost_bg 高 = fix_wh 28.91")
	assert_almost_eq(cost_bg.position.x + cost_bg.size.x * 0.5, 112.11, 0.5, "cost_bg 中心 x 照声明表")
	assert_almost_eq(cost_bg.position.y + cost_bg.size.y * 0.5, 286.72 - 49.61, 0.5, "cost_bg 中心 y 照声明表")
	var stone_host: Control = inst.get_node("%StoneHost") as Control
	assert_almost_eq(stone_host.position.x, 26.17, 0.5, "stone_host x 照声明表")
	assert_almost_eq(stone_host.position.y, 286.72 - 26.95 - 45.31, 0.5, "stone_host y = H-y-h")
	var stone_name: Label = inst.get_node("%StoneName") as Label
	assert_almost_eq(stone_name.position.x, 102.27, 0.5, "stone_name x = 72.27+30（源 :591 +30 偏移）")
	assert_almost_eq(stone_name.position.y + stone_name.size.y * 0.5, 286.72 - 51.17, 1.0, "stone_name 垂直中心照声明表")
	var none_tag: TextureRect = inst.get_node("%NoneTag") as TextureRect
	assert_false(none_tag.visible, "noneTag 默认隐藏（源 visible=amount<1）")
	assert_almost_eq(none_tag.size.x, 206.83, 0.5, "noneTag 宽 = 265px/CS")
	assert_almost_eq(none_tag.size.y, 286.51, 0.5, "noneTag 高 = 367px/CS")


# 源 refreshCostLabel(:75-86)：costLabel(stone_name) 色 = costLabelColor ccc3(150,236,255)，
# amount>=1 且 checkMoneyEnough 不足 → ccc3(255,0,0)。
func test_cost_label_color_insufficient_red() -> void:
	var panel: StarShopPanel = _make_panel({8: 100, 9: 200, 10: 200})
	var first: Control = panel._item_layer.get_child(0) as Control
	var stone_name: Label = first.get_node("%StoneName") as Label
	assert_almost_eq(stone_name.modulate.r, 150.0 / 255.0, 0.01, "充足时 R = costLabelColor(150,236,255)")
	assert_almost_eq(stone_name.modulate.g, 236.0 / 255.0, 0.01, "充足时 G = 236/255")
	panel.free()
	var panel2: StarShopPanel = _make_panel()
	var first2: Control = panel2._item_layer.get_child(0) as Control
	var stone_name2: Label = first2.get_node("%StoneName") as Label
	assert_almost_eq(stone_name2.modulate.r, 1.0, 0.01, "灵魂石不足时红 ccc3(255,0,0)")
	assert_almost_eq(stone_name2.modulate.g, 0.0, 0.01, "不足时 G=0")
	panel2.free()


# 源 refreshGoods(:98-136)：result=true → amount=0、noneTag visible、costLabel(价格)隐藏；
# stone 分支 panel/icon/coinIcon 均无 → 不变灰（旧实现 modulate 0.5 为发明，删）。
func test_soldout_shows_none_tag_and_hides_price() -> void:
	var panel: StarShopPanel = _make_panel({8: 100, 9: 200, 10: 200})
	(panel.shop_mgr.get_star_goods()[0] as Dictionary)["amount"] = 0
	panel._rebuild()
	var first: Control = panel._item_layer.get_child(0) as Control
	assert_true((first.get_node("%NoneTag") as TextureRect).visible, "售罄 noneTag 显示")
	assert_false((first.get_node("%StoneName") as Label).visible, "售罄价格 stone_name 隐藏（源 :118）")
	assert_almost_eq(first.modulate.a, 1.0, 0.01, "整格不变灰（源 stone 分支无 panel opacity）")
	panel.free()


# panel 零静态构造（宽口径白名单）：商品格走 item 模板 tscn，仅购买窗工厂 1 处 .new(。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count("StarShopBuyWindow.new("), 1, "仅 1 处购买窗工厂 StarShopBuyWindow.new(")
	assert_eq(text.count(".new("), 1, "宽口径 .new( 总数 = 白名单之和")


# theme variation 接线（GUT 下节点级不解析 variation，读 tres 文本表项）。
# 源字号/色：item_name size20 ccc3(255,255,255)（声明表）；cost_title size19
# ccc3(150,236,255)（声明表）；stone_name size19 动态色（fill modulate 控色只定号）。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("StarShopItemNameLabel/font_sizes/font_size = 20"), "item_name 字号 20")
	assert_true(t.contains("StarShopCostTitleLabel/colors/font_color = Color(0.588235, 0.92549, 1, 1)"),
		"cost_title 色 = ccc3(150,236,255)")
	assert_true(t.contains("StarShopStoneNameLabel/font_sizes/font_size = 19"), "stone_name 字号 19")


# 灵魂石 icon 缩放/对齐守卫：源 shop.lua:571 createIcon(stone_id,46) → 显示 46 点 +
# anchor(0,0) at(0,0) 左下对齐 stone_container。9bc640e 起 create_icon 内部统一 ÷CS
# （产物 frame 显示 94/CS≈73.37）→ 外层基准须用产物显示宽 94/CS（2026-08-22 巡检订正：
# 旧 94 纹理基准双重缩小实显 35.9 vs 源 46）。
func test_stone_icon_scale_and_bottom_align() -> void:
	var panel := _make_panel()
	var row: TextureButton = panel._item_layer.get_child(0) as TextureButton
	var host: Control = row.get_node("%StoneHost") as Control
	assert_gt(host.get_child_count(), 0, "stone icon 已 fill")
	var icon: Control = host.get_child(0) as Control
	var base: float = 94.0 / 1.28125
	assert_almost_eq(icon.scale.x, 46.0 / base, 0.0001, "icon scale=46/(94/CS)（视觉宽 46）")
	var vis_h: float = (95.0 / 1.28125) * 46.0 / base
	assert_almost_eq(icon.position.x, 0.0, 0.01, "icon 左=0（源 anchor(0,0)）")
	assert_almost_eq(icon.position.y, 45.31 - vis_h, 0.01, "icon 底=容器底（左下对齐 y=45.31-46.49）")
	panel.free()


# ── 批 E E3/E4（2026-08-27）──

# E3：灵魂石 icon 走 hero 分支（源 player.lua:1178 itemType id<100="hero" → Unit.Portrait），
# 产物含英雄头像 sprite（负 z 根修后画序=衬底/内容/边框）。
func test_stone_icon_uses_hero_portrait() -> void:
	var panel := _make_panel()
	var row: TextureButton = panel._item_layer.get_child(0) as TextureButton
	var host: Control = row.get_node("%StoneHost") as Control
	var icon: Control = host.get_child(0) as Control
	var found_portrait := false
	for c in icon.get_children():
		if c is Sprite2D and String((c as Sprite2D).texture.resource_path).find("/HERO/") >= 0:
			found_portrait = true
	assert_true(found_portrait, "stone_id 8 → Unit.Portrait 英雄头像 sprite（批 E E3）")
	panel.free()


# E4：倒计时行 fill（源 shop.lua:757-759 expire 态文案 + :662 gethmsNString 值）。
func test_time_row_filled_expire_state() -> void:
	var panel := _make_panel()
	var title: Label = panel._time_label.get_parent().get_node("TimeTitle") as Label
	assert_eq(title.text, "商人将于", "title LSTR SHOP.MERCHANT_LEAVES_AFTER")
	var suffix: Label = panel._time_label.get_parent().get_node("TimeSuffix") as Label
	assert_eq(suffix.text, "后离开", "suffix LSTR SHOP.TIMES")
	var hms: PackedStringArray = panel._time_label.text.split(":")
	assert_eq(hms.size(), 3, "值 gethmsNString HH:MM:SS 三段")
	assert_gt(int(hms[0]), 700, "开店即≈720h（30 天 expire，参考图 719:34:34 同源）")
	panel.free()
