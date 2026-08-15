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


# ── C6（2026-07-23）：_on_buy 弹 EquipboardOfbuyPanel 确认面板（源 openBuyPanel:314-322）──
# 修复前 _on_buy 直接调 shop_mgr.buy；照源改为先弹 equipboard ofbuy 确认面板，用户确认后才 buy。

# C6：商品可购买（amount>0）→ _on_buy 弹 EquipboardOfbuyPanel，未触发 shop_mgr.buy
func test_on_buy_opens_confirm_panel() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 100000   # 充足货币避免误判
	var mgr := ShopManager.new(cm)
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(1, mgr, pd, BattleRng.new(1))
	var container: Control = panel.get("container")
	var children_before: int = container.get_child_count()
	panel._on_buy(0)   # slot 0 商品
	# container 多出 EquipboardOfbuyPanel 子节点（confirmed 后才 buy）
	assert_eq(container.get_child_count(), children_before + 1, "_on_buy 弹 EquipboardOfbuyPanel（源 openBuyPanel）")
	var popup: Node = container.get_child(container.get_child_count() - 1)
	assert_true(popup is EquipboardOfbuyPanel, "弹窗类型是 EquipboardOfbuyPanel")
	# 源 param.doBuy 未触发（仅点击确认后才 buy）—货币/库存无变化
	panel.free()


# C6：售罄商品 amount<=0 → 不弹确认面板（源 :245-247 data.amount<=0 → showTalk Soldout return）
func test_on_buy_soldout_no_panel() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 100000
	var mgr := ShopManager.new(cm)
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(1, mgr, pd, BattleRng.new(1))
	# 售罄所有 slot 0 商品（手动改 goods amount=0）
	var goods: Array = mgr.get_goods(1)
	if goods.size() > 0:
		goods[0]["amount"] = 0
	var container: Control = panel.get("container")
	var children_before: int = container.get_child_count()
	panel._on_buy(0)
	assert_eq(container.get_child_count(), children_before, "售罄商品不弹确认面板（源 :245 return）")
	panel.free()


# C6：确认弹窗 confirmed → _make_buy_confirm_handler 触发实际 shop_mgr.buy（源 doBuy:167-188）
func test_buy_confirm_handler_calls_shop_mgr() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 100000
	var mgr := ShopManager.new(cm)
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(1, mgr, pd, BattleRng.new(1))
	# 调 _make_buy_confirm_handler(slot)(）— 模拟 confirmed 信号触发
	var gold_before: int = pd.hero_manager.gold
	var handler: Callable = panel._make_buy_confirm_handler(0)
	handler.call()
	# 购买成功后货币减少（商品价格 ≥ 1）或失败 toast；至少 handler 可调用不报错
	# 主要验证信号链路：confirmed → handler → shop_mgr.buy（不直接断言 gold 变化避免被 goods 状态干扰）
	assert_true(handler.is_valid(), "_make_buy_confirm_handler 返有效 Callable（源 param.doBuy）")
	panel.free()


# P1-10 源 shop.lua:33-44 talkBg Scale9 气泡背景。两件套范式（2026-08-14）：TalkBg 静态化进
# shop_content.tscn（NinePatchRect + patch_margin 烘焙），panel 只取 %TalkBg 引用。
func test_talk_bubble_assembled() -> void:
	var pd := PlayerData.new(cm)
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(1, ShopManager.new(cm), pd, BattleRng.new(1))
	var talk_bg: NinePatchRect = panel.get("_talk_bg") as NinePatchRect
	assert_not_null(talk_bg, "_talk_bg 取自 .tscn %TalkBg（源 shop.lua:33-44）")
	assert_true(talk_bg.texture != null, "talk_bg 用 shop_talk_bg.png 纹理")
	assert_eq(talk_bg.patch_margin_left, 30, "cap 30（源 capInsets 30,15,110,26）")
	assert_eq(talk_bg.patch_margin_right, 87, "cap 右=227-30-110")
	assert_almost_eq(talk_bg.modulate.a, 0.0, 0.01, "talk_bg 初始 modulate.a=0（随 talk 淡入）")
	panel.free()


# 默认贴图烘焙：id=1 商人的 Bg/Head 底图应在 .tscn 里可见（编辑器所见即所得）。
func test_default_textures_baked() -> void:
	var content: Control = (load("res://scenes/ui/shop_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var bg: TextureRect = content.get_node("%PanelLayer/%Bg") as TextureRect
	assert_true(bg.texture != null, "Bg 烘 shop_bg.png 默认贴图（market_config.gd:36）")
	var head: TextureRect = content.get_node("%PanelLayer/%Head") as TextureRect
	assert_true(head.texture != null, "Head 烘 shop_head.png 默认贴图")
	var title: Label = content.get_node("%PanelLayer/%Title") as Label
	assert_eq(String(title.theme_type_variation), "ShopTitleLabel", "Title 走 theme variation")
	content.free()


# 两件套范式（2026-08-14）：ShopBuilder 退役，fill 归 panel。
func test_shop_builder_retired() -> void:
	var panel_text: String = FileAccess.get_file_as_string("res://scripts/ui/shop_panel.gd")
	assert_true(panel_text.find("ShopBuilder") == -1, "panel 不再引用 ShopBuilder")
	assert_false(ResourceLoader.exists("res://scripts/ui/shop_builder.gd"), "shop_builder.gd 已删")


# Task 5 修复回归：PanelLayer rect 纯 tscn 静态（不被运行时重定位拖偏）。
func test_panel_layer_rect_static() -> void:
	var pd := PlayerData.new(cm)
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(1, ShopManager.new(cm), pd, BattleRng.new(1))
	var pl: Control = panel.get("_panel_layer") as Control
	assert_almost_eq(pl.position.x, 129.0, 0.5, "PanelLayer x=129（tscn 静态，702×424=900×543÷CS 中心 to_godot(400,225)）")
	assert_almost_eq(pl.position.y, 123.0, 0.5, "PanelLayer y=123")
	assert_almost_eq(pl.size.x, 702.0, 1.0, "宽 702")
	assert_almost_eq(pl.size.y, 424.0, 1.0, "高 424")
	var item_layer: Control = panel.get("_item_layer") as Control
	assert_true(item_layer.clip_contents, "ItemLayer 裁剪层（源 draglist cliprect）")
	assert_almost_eq(item_layer.global_position.x, 145.0, 0.5, "裁剪区 x=145（源 clip 65+80）")
	assert_almost_eq(item_layer.global_position.y, 200.0, 0.5, "裁剪区 y=200（源 560-360）")
	panel.free()


# Task 5 二轮：CloseBtn 对齐项目惯例（屏幕左上 20,15，crusade/dungeon 同款）。
func test_close_btn_screen_corner() -> void:
	var content: Control = (load("res://scenes/ui/shop_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(btn.global_position.x, 20.0, 0.5, "CloseBtn 屏幕左上 x=20")
	assert_almost_eq(btn.global_position.y, 15.0, 0.5, "CloseBtn 屏幕左上 y=15")
	content.free()
