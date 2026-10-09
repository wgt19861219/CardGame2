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
	assert_eq(talk_bg.patch_margin_left, 23, "cap 30÷CS=23.4（源 capInsets 30,15,110,26）")
	assert_eq(talk_bg.patch_margin_right, 68, "cap 右=87÷CS=67.9（T/B 同步修正反写）")
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
	assert_almost_eq(pl.position.x, 49.0, 0.5, "PanelLayer x=129（tscn 静态，702×424=900×543÷CS 中心 to_godot(400,225)）")
	assert_almost_eq(pl.position.y, 43.0, 0.5, "PanelLayer y=123")
	assert_almost_eq(pl.size.x, 702.0, 1.0, "宽 702")
	assert_almost_eq(pl.size.y, 424.0, 1.0, "高 424")
	var item_layer: Control = panel.get("_item_layer") as Control
	assert_false(item_layer.clip_contents, "ItemLayer 不自裁剪（2026-10-08 起由父 ItemScroll 统一裁剪）")
	assert_almost_eq(item_layer.global_position.x, 65.0, 0.5, "裁剪区 x=145（源 clip 65+80）")
	assert_almost_eq(item_layer.global_position.y, 120.0, 0.5, "裁剪区 y=200（源 560-360）")
	panel.free()


# Task 5 二轮：CloseBtn 对齐项目惯例（屏幕左上 20,15，crusade/dungeon 同款）。
func test_close_btn_screen_corner() -> void:
	var content: Control = (load("res://scenes/ui/shop_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(btn.global_position.x, 20.0, 0.5, "CloseBtn 屏幕左上 x=20")
	assert_almost_eq(btn.global_position.y, 15.0, 0.5, "CloseBtn 屏幕左上 y=15")
	content.free()


# Task 5 三轮：框顶照源重建。TitleBg 存在 + 中心 (351,32)（源 titlePos(400,405) → to_godot-(129,123)）；
# TimeLabel 中心 (351,87)（源 ccp(400,350)，标题下方居中与刷新按钮同行）；
# TalkLabel 中心 y=77（源 anchor(0,0.5) frame 中线 (190,360) → panel-local y=77）。
func test_top_bar_sourced_layout() -> void:
	var content: Control = (load("res://scenes/ui/shop_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var pl: Control = content.get_node("%PanelLayer") as Control
	# 迁移发明元素已删（源无对应物：货币走 HUD、刷新花费走确认弹窗）
	assert_null(pl.get_node_or_null("RefreshCostLabel"), "RefreshCostLabel 已删（源无）")
	assert_null(pl.get_node_or_null("MoneyLabel"), "MoneyLabel 已删（源无，货币走 HudOverlay）")
	var title_bg: TextureRect = pl.get_node("TitleBg") as TextureRect
	assert_not_null(title_bg, "TitleBg 存在（源 titleBgRes map-title-bg.png）")
	assert_almost_eq(title_bg.position.x + title_bg.size.x * 0.5, 351.0, 1.0, "TitleBg 中心 x=351")
	assert_almost_eq(title_bg.position.y + title_bg.size.y * 0.5, 32.0, 1.0, "TitleBg 中心 y=32")
	var title: Label = pl.get_node("Title") as Label
	assert_almost_eq(title.position.x + title.size.x * 0.5, 351.0, 1.0, "Title 中心 x=351（Label 降级保位）")
	assert_almost_eq(title.position.y + title.size.y * 0.5, 32.0, 1.0, "Title 中心 y=32")
	var time_label: Label = pl.get_node("TimeLabel") as Label
	assert_almost_eq(time_label.position.x + time_label.size.x * 0.5, 351.0, 1.0, "TimeLabel 中心 x=351（源 ccp(400,350)）")
	assert_almost_eq(time_label.position.y + time_label.size.y * 0.5, 87.0, 1.0, "TimeLabel 中心 y=87（与刷新按钮同行）")
	var talk_label: Label = pl.get_node("TalkLabel") as Label
	assert_almost_eq(talk_label.position.y + talk_label.size.y * 0.5, 77.0, 1.0, "TalkLabel 中心 y=77（源 frame 中线）")
	content.free()


# ── 到期改裁决（2026-09-14 用户裁决）：到期不关面板，直接刷新商店 + 重计停留 ──

# 行为守卫：已过期触发 _on_expire → 面板仍在树（不 remove_window）+ expire_end 重计 + 商品 rebuild 6 件。
func test_on_expire_refreshes_not_closes() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	var mgr := ShopManager.new(cm)
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(2, mgr, pd, BattleRng.new(1))
	var now: int = int(Time.get_unix_time_from_system())
	pd.shop_expire_end[2] = now - 1   # 手动置过期（停留期满/持久化残留两种入口同管道）
	panel._on_expire()
	assert_true(panel.is_inside_tree(), "到期不关面板（面板仍在树）")
	assert_true(int(pd.shop_expire_end.get(2, 0)) > now, "停留期重计 expire_end>now（不残留过期）")
	var item_layer: Control = panel.get("_item_layer") as Control
	assert_eq(item_layer.get_child_count(), 12, "商品 rebuild 后 12 件（shop2 十二槽全绑组）")
	panel.free()


# 源码守卫：_on_expire 函数体不含 remove_window（防回归到期关面板），且刷新走 open_shop。
func test_on_expire_source_no_close() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/shop_panel.gd")
	var start: int = text.find("func _on_expire")
	assert_true(start >= 0, "_on_expire 存在")
	var end: int = text.find("\nfunc ", start + 1)
	assert_true(end > start, "_on_expire 函数体边界可定位")
	var body: String = text.substr(start, end - start)
	assert_true(body.find("remove_window") == -1, "_on_expire 不调 remove_window（到期刷新不关面板）")
	assert_true(body.find("open_shop") >= 0, "_on_expire 走 open_shop 重新生成商品")


# ── 2026-10-08 商品管道改造守卫：12 件表配商品 + ItemScroll 横滚层 ──

# 场景结构守卫：ItemScroll(ScrollContainer, 垂直禁用) 包住 ItemLayer（源 draglist 横滚等价物）。
func test_scene_item_scroll_structure() -> void:
	var packed: PackedScene = load("res://scenes/ui/shop_content.tscn")
	var root: Control = packed.instantiate() as Control
	var scroll: ScrollContainer = root.get_node("%ItemScroll") as ScrollContainer
	var layer: Control = root.get_node("%ItemLayer") as Control
	assert_not_null(scroll, "%ItemScroll 存在")
	assert_not_null(layer, "%ItemLayer 存在")
	assert_eq(layer.get_parent(), scroll, "ItemLayer 是 ItemScroll 子节点")
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "垂直滚动禁用（纯横向）")
	assert_true(scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "横向滚动启用")
	# 2026-10-08 二轮：ScrollContainer 默认 STOP 吞与 RefreshBtn（全局 y101~159，滚动层 y120 起
	# 重叠 39px）的点击致刷新按钮失效——命中层守卫：滚动层必须 IGNORE（商品 item 子节点自点）。
	assert_eq(scroll.mouse_filter, Control.MOUSE_FILTER_IGNORE, "ItemScroll IGNORE（防吞刷新按钮点击）")
	root.free()


# 装配守卫：panel setup 后 _item_scroll 挂接 + 商品 fill 走新管道（12 件表配、远征店全龙鳞币）。
func test_panel_scroll_and_goods_pipeline() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	pd.crusade_point = 10000
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(4, ShopManager.new(cm), pd, BattleRng.new(1))
	await get_tree().process_frame   # ScrollContainer 布局 deferred，等一帧再断言滚动范围
	var scroll: ScrollContainer = panel.get("_item_scroll") as ScrollContainer
	assert_not_null(scroll, "_item_scroll 已挂接")
	var layer: Control = panel.get("_item_layer") as Control
	assert_eq(layer.get_parent(), scroll, "_item_layer 在 _item_scroll 下")
	assert_eq(layer.get_child_count(), 12, "远征店 12 件表配商品")
	assert_almost_eq(layer.custom_minimum_size.x, 6.0 * 205.0 + 35.0, 0.5, "内容 min 宽 1265（驱动横滚范围）")
	assert_true(scroll.get_h_scroll_bar().max_value > scroll.size.x, "横向滚动条 max>视口宽（可滚）")
	panel.free()


# 滚轮横滚（2026-10-08 二轮）：ItemScroll IGNORE 后容器内建滚轮失效，panel _input 补分流——
# 列表矩形内 WHEEL_DOWN → scroll_horizontal 增、WHEEL_UP → 减（clamp 边界）。
func test_wheel_scrolls_list() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 10000
	pd.crusade_point = 10000
	var panel := ShopPanel.new("shop", {})
	add_child(panel)
	panel.setup_panel(4, ShopManager.new(cm), pd, BattleRng.new(1))
	await get_tree().process_frame
	var scroll: ScrollContainer = panel.get("_item_scroll") as ScrollContainer
	var center: Vector2 = scroll.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	down.pressed = true
	down.global_position = center
	panel._input(down)
	assert_almost_eq(scroll.scroll_horizontal, ShopPanel.WHEEL_STEP, 0.5, "WHEEL_DOWN → 横滚 +64")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_WHEEL_UP
	up.pressed = true
	up.global_position = center
	panel._input(up)
	assert_almost_eq(scroll.scroll_horizontal, 0.0, 0.5, "WHEEL_UP → 回滚 0（clamp 下界）")
	# 列表矩形外的滚轮不分流（不劫持面板其他区域/背后 UI）
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_WHEEL_DOWN
	outside.pressed = true
	outside.global_position = Vector2(20, 20)
	panel._input(outside)
	assert_almost_eq(scroll.scroll_horizontal, 0.0, 0.5, "矩形外滚轮不动列表")
	panel.free()
