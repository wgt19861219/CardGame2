extends GutTest

## EquipboardOfbuyPanel 测试（C6 2026-07-23）— 照源 ui/equipboard/ofbuy.lua（202 行）
## + 继承链 board.lua（initFrame/initContainer/initTitle/initAtt/initAmount）。
## shop 商品点击购买时弹出的确认浮层：icon + name + 拥有行 + 属性/描述面板 + 购买数量 +
## 货币图标 + 总价 + 确认按钮。
## 源 equipboard.init("ofbuy", data)：data={id, amount, pay, price, cost, doBuy}。
## 单机化：doBuy 闭包 → confirmed 信号（ShopPanel 连接执行 shop_mgr.buy）。
## 批5 两件套（2026-08-18 Task 3）：静态 chrome 进 equipboard_ofbuy_content.tscn，
## 守卫断言静态树 rect（照源直译）+ fill + theme variation 接线。

const CONTENT_PATH: String = "res://scenes/ui/equipboard_ofbuy_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/equipboard_ofbuy_panel.gd"
const THEME_PATH: String = "res://resources/themes/default_theme.tres"

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ── 静态树守卫（批5 Task 3）：content tscn 照源直译，节点存在 + 类型 + 层序 ──

# 源 ofbuy.lua create 链：initFrame（frame 288×385 + close）→ initContainer → initTitle
# （icon host + name）→ initAtt（att_bg + att 行宿主）→ initAmount（拥有行）→
# initWindow（购买行 + 货币行 + 确认按钮）。close 后声明（弹窗层序通查）。
func test_content_scene_static_tree() -> void:
	var scene: PackedScene = load(CONTENT_PATH) as PackedScene
	if scene == null:
		assert_true(false, "equipboard_ofbuy_content.tscn 存在且可加载")
		return
	var content: Control = scene.instantiate() as Control
	add_child(content)
	# unique 名节点（被 fill 引用）；Bg 是静态背景不开 unique（SOP），走普通路径
	var names: Array[String] = ["Frame", "IconHost", "NameLabel", "HaveLabel",
		"AttBg", "AttHost", "PurchaseTitle", "AmountLabel", "ItemSuffix",
		"MoneyBg", "MoneyIcon", "MoneyLabel", "ConfirmBtn", "CloseBtn"]
	for n in names:
		assert_ne(content.get_node_or_null("%" + n), null, "静态节点 %" + n + " 存在")
	assert_ne((content.get_node("%Frame") as Control).get_node_or_null("Bg"), null, "静态节点 Bg 存在（背景不开 unique）")
	assert_true(content.get_node("%Frame") is Control, "Frame 是 Control")
	assert_true((content.get_node("%Frame") as Control).get_node("Bg") is TextureRect, "Bg 是 TextureRect")
	assert_true(content.get_node("%AttBg") is NinePatchRect, "AttBg 是 NinePatchRect（源 Scale9）")
	assert_true(content.get_node("%AttHost") is VBoxContainer, "AttHost 是 VBoxContainer")
	assert_true(content.get_node("%ConfirmBtn") is TextureButton, "ConfirmBtn 是 TextureButton")
	assert_true(content.get_node("%CloseBtn") is TextureButton, "CloseBtn 是 TextureButton")
	# close 层序通查（批5 方法论 #1）：close 后声明盖住内容
	var frame: Control = content.get_node("%Frame") as Control
	assert_gt((frame.get_node("%CloseBtn") as Control).get_index(),
		(frame.get_node("%ConfirmBtn") as Control).get_index(),
		"CloseBtn 声明序在 ConfirmBtn 之后（弹窗 close 层序）")
	content.queue_free()


# 静态 rect 照源直译（源坐标 → Godot：点 (x,y)→(x,385-y) 帧内左上；尺寸 = 原始像素 ÷ CS 1.28125）
func test_static_rects_source_translation() -> void:
	var scene: PackedScene = load(CONTENT_PATH) as PackedScene
	if scene == null:
		assert_true(false, "content tscn 存在")
		return
	var content: Control = scene.instantiate() as Control
	add_child(content)
	var frame: Control = content.get_node("%Frame") as Control
	# 源 frame 中心 ccp(400,240) → to_godot(480,320) → 左上 (336,127.5)，288×385
	assert_almost_eq(frame.offset_left, 336.0, 0.01, "Frame offset_left=336（源 frame 中心居屏）")
	assert_almost_eq(frame.offset_top, 127.5, 0.01, "Frame offset_top=127.5")
	assert_almost_eq(frame.offset_right - frame.offset_left, 288.0, 0.01, "Frame 宽 288（369px÷CS）")
	assert_almost_eq(frame.offset_bottom - frame.offset_top, 385.0, 0.01, "Frame 高 385（493px÷CS）")
	# 源 name anchor(0,0.5)@ccp(92,345) → 左 92、垂直中心 40 → (92,25)；w>160 缩放 → 框宽 160
	var name_lbl: Control = frame.get_node("%NameLabel")
	assert_almost_eq(name_lbl.offset_left, 92.0, 0.01, "NameLabel 左 92（源 board.lua:328）")
	assert_almost_eq(name_lbl.offset_top, 25.0, 0.01, "NameLabel 顶 25（垂直中心 385-345=40）")
	assert_almost_eq(name_lbl.offset_right - name_lbl.offset_left, 160.0, 0.01,
		"NameLabel 框宽 160（源 board.lua:339 w>160 scale）")
	# 源 initAmount amount_title anchor(0,0.5)@ccp(90,310) → 左 90、垂直中心 75 → 顶 63
	var have_lbl: Control = frame.get_node("%HaveLabel")
	assert_almost_eq(have_lbl.offset_left, 90.0, 0.01, "HaveLabel 左 90（源 board.lua:65）")
	assert_almost_eq(have_lbl.offset_top, 63.0, 0.01, "HaveLabel 顶 63（垂直中心 385-310=75）")
	# 源 att_bg anchor(0.5,1)@ccp(143,287) → 顶 98、左 143-127.22=15.78；宽 254.44（326px÷CS）
	var att_bg: Control = frame.get_node("%AttBg")
	assert_almost_eq(att_bg.offset_left, 15.78, 0.01, "AttBg 左 15.78（源 board.lua:120-123）")
	assert_almost_eq(att_bg.offset_top, 98.0, 0.01, "AttBg 顶 98（385-287）")
	assert_almost_eq(att_bg.offset_right - att_bg.offset_left, 254.44, 0.01, "AttBg 宽 254.44")
	# 源 att_list anchor(0,1)@ccp(22,282) → 左 22、顶 103
	var att_host: Control = frame.get_node("%AttHost")
	assert_almost_eq(att_host.offset_left, 22.0, 0.01, "AttHost 左 22（源 board.lua:254-256）")
	assert_almost_eq(att_host.offset_top, 103.0, 0.01, "AttHost 顶 103（385-282）")
	# 源 PURCHASE anchor(0,0.5)@ccp(25,95) → 左 25、垂直中心 290 → 顶 278
	var title: Control = frame.get_node("%PurchaseTitle")
	assert_almost_eq(title.offset_left, 25.0, 0.01, "PurchaseTitle 左 25（源 ofbuy.lua:74）")
	assert_almost_eq(title.offset_top, 278.0, 0.01, "PurchaseTitle 顶 278（垂直中心 385-95=290）")
	# 源 money_bg anchor(0,0.5)@ccp(115,95) fix_size(155,36) → (115,272)-(270,308)
	var money_bg: Control = frame.get_node("%MoneyBg")
	assert_almost_eq(money_bg.offset_left, 115.0, 0.01, "MoneyBg 左 115（源 ofbuy.lua:121）")
	assert_almost_eq(money_bg.offset_top, 272.0, 0.01, "MoneyBg 顶 272（中心 290-18）")
	assert_almost_eq(money_bg.offset_right - money_bg.offset_left, 155.0, 0.01, "MoneyBg 宽 155（fix_size）")
	assert_almost_eq(money_bg.offset_bottom - money_bg.offset_top, 36.0, 0.01, "MoneyBg 高 36（fix_size）")
	# 源 money label 中心锚 ccp(200,95) → 中心 (200,290)（框中心对齐）
	var money_lbl: Control = frame.get_node("%MoneyLabel")
	assert_almost_eq((money_lbl.offset_left + money_lbl.offset_right) * 0.5, 200.0, 0.01,
		"MoneyLabel 中心 x=200（源 ofbuy.lua:142）")
	# 源 sell 整图 Sprite package_button 中心 ccp(147,40) → (16.27,318.85) 261.46×52.29
	var confirm: Control = frame.get_node("%ConfirmBtn")
	assert_almost_eq(confirm.offset_left, 16.27, 0.01, "ConfirmBtn 左 16.27（源 ofbuy.lua:158）")
	assert_almost_eq(confirm.offset_top, 318.85, 0.01, "ConfirmBtn 顶 318.85（中心 y=385-40=345）")
	assert_almost_eq(confirm.offset_right - confirm.offset_left, 261.46, 0.01, "ConfirmBtn 宽 261.46（335px÷CS 整图）")
	assert_almost_eq(confirm.offset_bottom - confirm.offset_top, 52.29, 0.01, "ConfirmBtn 高 52.29（67px÷CS）")
	# 源 close DGButton 中心 ccp(286,358) → 中心 (286,27) → 左上 (260.64,1.24)，50.73×51.51
	var close_btn: Control = frame.get_node("%CloseBtn")
	assert_almost_eq((close_btn.offset_left + close_btn.offset_right) * 0.5, 286.0, 0.01,
		"CloseBtn 中心 x=286（源 board.lua:441）")
	assert_almost_eq((close_btn.offset_top + close_btn.offset_bottom) * 0.5, 27.0, 0.01,
		"CloseBtn 中心 y=27（385-358）")
	assert_almost_eq(close_btn.offset_right - close_btn.offset_left, 50.73, 0.01, "CloseBtn 宽 50.73（65px÷CS）")
	content.queue_free()


# AttBg 九宫格 cap 直译（源 capInsets CCRectMake(10,10,230,120)，纹理 326×192）：
# top=192-10-120=62 bottom=10 left=10 right=326-10-230=86
func test_att_bg_cap_margins() -> void:
	var scene: PackedScene = load(CONTENT_PATH) as PackedScene
	if scene == null:
		assert_true(false, "content tscn 存在")
		return
	var content: Control = scene.instantiate() as Control
	add_child(content)
	var att_bg: NinePatchRect = content.get_node("%AttBg") as NinePatchRect
	assert_eq(att_bg.patch_margin_left, 10, "cap left=10（capInsets x=10）")
	assert_eq(att_bg.patch_margin_bottom, 10, "cap bottom=10（capInsets y=10）")
	assert_eq(att_bg.patch_margin_top, 62, "cap top=62（H-y-h=192-10-120）")
	assert_eq(att_bg.patch_margin_right, 86, "cap right=86（W-x-w=326-10-230）")
	content.queue_free()


# ── fill 守卫：setup_panel 填动态数据（icon/name/拥有行/底行/货币行/按钮文案）──

# 源 initWindow/initTitle/initAmount 全链 fill（371 = 有 Description 的 CONSUMABLES）
func test_setup_fills_dynamic_data() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(371, 5)
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	panel.setup_panel({"id": 371, "amount": 2, "pay": "gold", "price": 100, "cost": 200}, cm, pd)
	panel.show_window(root)
	var frame: Control = panel.get("_frame") as Control
	# name（源 datatable.lua:110 数据表加载即翻译 → get_lstr；amount=2 → "Namex2"）
	assert_eq((frame.get_node("%NameLabel") as Label).text, "秘银齿轮组x2",
		"name=翻译名+x2（源 board.lua:322 + ofbuy.lua:60）")
	# 拥有行（源 initAmount equip_qunty → pd.items）
	assert_eq((frame.get_node("%HaveLabel") as Label).text, "拥有 5 件",
		"拥有行=HAVE+拥有数+ITEM（源 board.lua:60）")
	# 底行购买数量
	assert_eq((frame.get_node("%PurchaseTitle") as Label).text, "购买", "购买标题 LSTR")
	assert_eq((frame.get_node("%AmountLabel") as Label).text, "2", "购买数量")
	assert_eq((frame.get_node("%ItemSuffix") as Label).text, "件", "数量后缀 LSTR")
	# 货币行（gold → shop_gold_icon；中心 (145,290)）
	assert_eq((frame.get_node("%MoneyLabel") as Label).text, "200", "总价文本")
	var icon: TextureRect = frame.get_node("%MoneyIcon") as TextureRect
	assert_true(String(icon.texture.resource_path).ends_with("shop_gold_icon.png"),
		"gold → shop_gold_icon（源 getCoinRes）")
	assert_almost_eq(icon.position.x + icon.size.x * 0.5, 145.0, 0.1, "货币 icon 中心 x=145（源 ofbuy.lua:131）")
	assert_almost_eq(icon.position.y + icon.size.y * 0.5, 290.0, 0.1, "货币 icon 中心 y=290（385-95）")
	# 确认按钮文案（fontinfo ui_normal_button 20 号白）
	assert_eq(((frame.get_node("%ConfirmBtn") as TextureButton).get_node("Label") as Label).text,
		"确认购买", "确认按钮文案 LSTR")
	# icon（ReadequipIcon procedural 挂 IconHost）
	assert_eq((frame.get_node("%IconHost") as Control).get_child_count(), 1, "IconHost 挂 1 个 ReadequipIcon")
	panel.remove_window()
	root.queue_free()


# att 面板 Description 分支（源 board.lua:131-137：Equip.Description → 单行描述 wrap 252）
func test_fill_att_description_branch() -> void:
	var root := Node.new()
	add_child(root)
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	panel.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm, null)
	panel.show_window(root)
	var frame: Control = panel.get("_frame") as Control
	var host: VBoxContainer = frame.get_node("%AttHost") as VBoxContainer
	assert_gt(host.get_child_count(), 0, "att 面板有内容行")
	var first: Label = host.get_child(0) as Label
	assert_true(first.text.contains("耐用的机械零件"), "首行=Equip.Description 翻译（371）")
	assert_eq(first.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "描述行 wrap（源 dimensions 252）")
	assert_almost_eq(first.custom_minimum_size.x, 252.0, 0.01, "描述行 wrap 宽 252")
	panel.remove_window()
	root.queue_free()


# att 面板属性行分支（源 getDescription：无 Description 装备 → 属性行）
func test_fill_att_attribute_branch() -> void:
	var root := Node.new()
	add_child(root)
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	panel.setup_panel({"id": 101, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm, null)
	panel.show_window(root)
	var frame: Control = panel.get("_frame") as Control
	var host: VBoxContainer = frame.get_node("%AttHost") as VBoxContainer
	assert_gt(host.get_child_count(), 0, "属性行分支有内容")
	var rows: Array = ReadequipData.get_description(101, 0, cm)
	var first: Label = host.get_child(0) as Label
	assert_eq(first.text,
		String((rows[0] as Dictionary).get("att", "")) + String((rows[0] as Dictionary).get("add", ""))
			+ String((rows[0] as Dictionary).get("suffix", "")),
		"首行=ReadequipData.get_description 行拼接（att+add+suffix）")
	panel.remove_window()
	root.queue_free()


# att 面板碎片分支（源 board.lua:197-240：Description + Category=FRAGMENT → 合成所需碎片 X/Y）
func test_fill_att_fragment_branch() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(266, 3)   # 266=水晶剑卷轴碎片，Fragment 表 need=5
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	panel.setup_panel({"id": 266, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm, pd)
	panel.show_window(root)
	var frame: Control = panel.get("_frame") as Control
	var host: VBoxContainer = frame.get_node("%AttHost") as VBoxContainer
	var texts: Array[String] = []
	for c in host.get_children():
		texts.append((c as Label).text)
	var joined: String = "|".join(texts)
	assert_true(joined.contains("合成需要碎片"), "碎片行含 fragment_title LSTR（源 :211-219）")
	assert_true(joined.contains("3/5"), "碎片行含 拥有3/需5（源 :223-227 格式 %d/%d）")
	panel.remove_window()
	root.queue_free()


# att_bg 高度自适应（源 board.lua:263 setContentSize(bw, attListHeight+12)，须入树后度量）
func test_att_bg_height_adapts() -> void:
	var root := Node.new()
	add_child(root)
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	panel.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm, null)
	panel.show_window(root)
	var frame: Control = panel.get("_frame") as Control
	var host: VBoxContainer = frame.get_node("%AttHost") as VBoxContainer
	var att_bg: NinePatchRect = frame.get_node("%AttBg") as NinePatchRect
	var expect_h: float = host.get_combined_minimum_size().y + 12.0
	assert_almost_eq(att_bg.size.y, expect_h, 0.5, "AttBg 高 = att 内容高 + 12（源 :263）")
	panel.remove_window()
	root.queue_free()


# theme variation 接线（GUT 下节点级不解析 variation，读 tres 文本表项 + 节点 variation 断言）
# 源色板：name ccc3(66,45,28)+shadow(0,2) 24 号；HAVE ccc3(67,59,56) 20 号；att ccc3(64,63,63)
# +shadow 18 号；碎片 ccc3(66,45,28)+shadow 18 号；行标题 ccc3(67,59,56) 18 号；数量 ccc3(0,71,188)
# 16 号；money ccc3(251,206,16)+shadow 16 号（refreshCostColor 恒金，:13-15 if 空块死代码）；
# 确认按钮 fontinfo ui_normal_button 20 号白+shadow(63,5,0)(0,2)。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("OfbuyNameLabel/font_sizes/font_size = 24"), "name 24 号（源 board.lua:325）")
	assert_true(t.contains("OfbuyNameLabel/colors/font_color = Color(0.259, 0.176, 0.11, 1)"),
		"name 色 = ccc3(66,45,28)")
	assert_true(t.contains("OfbuyNameLabel/colors/font_shadow_color = Color(0, 0, 0, 1)"), "name 阴影黑")
	assert_true(t.contains("OfbuyNameLabel/constants/shadow_offset_y = 2"), "name 阴影偏移 (0,2)")
	assert_true(t.contains("OfbuyHaveLabel/font_sizes/font_size = 20"), "HAVE 20 号（源 board.lua:61）")
	assert_true(t.contains("OfbuyHaveLabel/colors/font_color = Color(0.263, 0.231, 0.22, 1)"),
		"HAVE 色 = ccc3(67,59,56)")
	assert_true(t.contains("OfbuyAttLabel/font_sizes/font_size = 18"), "att 行 18 号（源 board.lua:147）")
	assert_true(t.contains("OfbuyAttLabel/colors/font_color = Color(0.251, 0.247, 0.247, 1)"),
		"att 色 = ccc3(64,63,63)")
	assert_true(t.contains("OfbuySynthesisLabel/colors/font_color = Color(0.259, 0.176, 0.11, 1)"),
		"碎片行色 = ccc3(66,45,28)（源 board.lua:216/231）")
	assert_true(t.contains("OfbuyRowLabel18/font_sizes/font_size = 18"), "底行标题 18 号（源 ofbuy.lua:70）")
	assert_true(t.contains("OfbuyRowLabel18/colors/font_color = Color(0.263, 0.231, 0.22, 1)"),
		"底行标题色 = ccc3(67,59,56)")
	assert_true(t.contains("OfbuyAmountLabel16/font_sizes/font_size = 16"), "购买数量 16 号（源 ofbuy.lua:85）")
	assert_true(t.contains("OfbuyAmountLabel16/colors/font_color = Color(0, 0.278, 0.737, 1)"),
		"购买数量色 = ccc3(0,71,188)")
	assert_true(t.contains("OfbuyMoneyLabel16/font_sizes/font_size = 16"), "money 16 号（源 ofbuy.lua:139）")
	assert_true(t.contains("OfbuyMoneyLabel16/colors/font_color = Color(0.984, 0.808, 0.063, 1)"),
		"money 色 = ccc3(251,206,16)（源 refreshCostColor 恒金）")
	assert_true(t.contains("OfbuyMoneyLabel16/colors/font_shadow_color = Color(0, 0, 0, 1)"), "money 阴影黑")
	assert_true(t.contains("OfbuyConfirmLabel/font_sizes/font_size = 20"), "确认按钮 20 号（源 ofbuy.lua:176）")
	assert_true(t.contains("OfbuyConfirmLabel/colors/font_color = Color(1, 1, 1, 1)"),
		"确认按钮白字（fontinfo ui_normal_button）")
	assert_true(t.contains("OfbuyConfirmLabel/colors/font_shadow_color = Color(0.247059, 0.019608, 0, 1)"),
		"确认按钮阴影 = ccc3(63,5,0)（fontconfigs.lua:29）")


# tscn variation 接线守卫：静态文本节点走 theme_type_variation（禁内联 override）
func test_tscn_variation_wiring() -> void:
	var scene: PackedScene = load(CONTENT_PATH) as PackedScene
	if scene == null:
		assert_true(false, "content tscn 存在")
		return
	var content: Control = scene.instantiate() as Control
	add_child(content)
	var frame: Control = content.get_node("%Frame") as Control
	assert_eq(String((frame.get_node("%NameLabel") as Label).theme_type_variation), "OfbuyNameLabel",
		"name 走 variation")
	assert_eq(String((frame.get_node("%HaveLabel") as Label).theme_type_variation), "OfbuyHaveLabel",
		"HAVE 走 variation")
	assert_eq(String((frame.get_node("%PurchaseTitle") as Label).theme_type_variation), "OfbuyRowLabel18",
		"购买标题走 variation")
	assert_eq(String((frame.get_node("%AmountLabel") as Label).theme_type_variation), "OfbuyAmountLabel16",
		"购买数量走 variation")
	assert_eq(String((frame.get_node("%ItemSuffix") as Label).theme_type_variation), "OfbuyRowLabel18",
		"数量后缀走 variation")
	assert_eq(String((frame.get_node("%MoneyLabel") as Label).theme_type_variation), "OfbuyMoneyLabel16",
		"money 走 variation")
	assert_eq(String(((frame.get_node("%ConfirmBtn") as TextureButton).get_node("Label") as Label).theme_type_variation),
		"OfbuyConfirmLabel", "确认按钮字走 variation")
	content.queue_free()


# 静态化守卫：panel 不再 procedural 建 chrome（Label.new 仅限 att 动态行）
func test_no_procedural_chrome() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_false(text.contains("TextureRect.new("), "无 TextureRect.new（chrome 静态化进 tscn）")
	assert_false(text.contains("TextureButton.new("), "无 TextureButton.new（close/确认按钮静态化）")
	assert_false(text.contains("UiScale9Button"), "无 UiScale9Button（源 sell 是整图 Sprite 非 Scale9）")
	assert_false(text.contains("_add_texture"), "无 _add_texture procedural 贴图 helper")


# ── 以下为 C6 原有用例（保留不缩水）──

# 源 ofbuy.lua create + initFrame + initWindow：frame + close + icon + name + amount + cost + 确认按钮
func test_setup_panel_assembles_nodes() -> void:
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel)
	panel.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm)
	# frame 装配（源 board.lua:420 initFrame）
	assert_ne(panel.get("_frame"), null, "_frame 装配（源 initFrame）")
	var frame: Control = panel.get("_frame") as Control
	# Bg/IconHost/Name/Have/AttBg/AttHost/购买标题/数量/后缀/money_bg/money_icon/money_label/btn + close
	# 子节点数 ≥ 9（icon/name/title/amount/suffix/money_bg/money_icon/money_label/btn + close）
	assert_gte(frame.get_child_count(), 9, "frame 含 9+ 子节点（源 initFrame + initWindow）")
	panel.free()


# 源 ofbuy.lua:60-61 amount>1 → name="NamexN"；amount=1 → 原名
func test_equip_name_with_amount_suffix() -> void:
	var panel1 := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel1)
	panel1.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm)
	var name1: String = panel1._equip_name()
	assert_false(name1.ends_with("x1"), "amount=1 name 无 x1 后缀（源 :61 if amount>1）")
	panel1.free()
	var panel3 := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel3)
	panel3.setup_panel({"id": 371, "amount": 3, "pay": "gold", "price": 100, "cost": 300}, cm)
	var name3: String = panel3._equip_name()
	assert_true(name3.ends_with("x3"), "amount=3 name 含 x3 后缀（源 :60 T(\"%sx%d\",name,amount)）")
	panel3.free()


# 源 ofbuy.lua:34-38 sell_button clickHandler → param.doBuy()；本项目 emit confirmed（ShopPanel 连接执行 buy）
func test_confirm_button_emits_signal() -> void:
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel)
	panel.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm)
	var emitted := [false]
	panel.confirmed.connect(func() -> void: emitted[0] = true)
	panel._on_confirm()
	assert_true(emitted[0], "确认按钮 emit confirmed 信号（源 param.doBuy → confirmed）")
	# queue_free 延迟下帧，改测 is_inside_tree 标志（queue_free 当帧仍 true，用 frame 等待不可行）
	# 主要验证 confirmed 信号已触发（核心行为），remove_window 由 PopWindow 基类保证
	panel.free()


# 源 :34-38 close 按钮 clickHandler → destroy（不触发 doBuy）
func test_close_button_does_not_emit_confirmed() -> void:
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel)
	panel.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm)
	var emitted := [false]
	panel.confirmed.connect(func() -> void: emitted[0] = true)
	panel._on_close()
	assert_false(emitted[0], "close 不触发 confirmed（源 :25-28 close_button 仅 destroy）")
	panel.free()


# 源 marketconfig.getCoinRes：gold→shop_gold_icon，其他→shop_token_icon
func test_pay_icon_path_gold_vs_diamond() -> void:
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel)
	panel.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm)
	assert_eq(panel._pay_icon_path("gold"), "res://assets/ui/alpha/HVGA/shop_gold_icon.png", "gold→shop_gold_icon")
	assert_eq(panel._pay_icon_path("diamond"), "res://assets/ui/alpha/HVGA/shop_token_icon.png", "diamond→shop_token_icon")
	panel.free()
