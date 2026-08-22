extends GutTest
## 碎片合成面板测试（View 层）— 照源 fragmentcompose.lua（485 行单页弹窗）。
## 两部分：
## 1. LSTR 化（2026-07-16）：setup_panel 后 LSTR key 经 cm.get_lstr 解析成中文。
## 2. 两件套核对守卫（批 1 Task 6，2026-08-15）：源 readnode root = bg sprite
##    （fragmentcompose.lua:261 createSprite + :467 readnode.create(self.bg, ...)），
##    子节点 position 是 bg 局部空间（原点 = bg 纹理左下角）——坐标系坑 #1，
##    tscn 用 PanelLayer 容器承载（exercise PanelLayer / stone_detail 原点偏移同款）。
## 分支逻辑（碎片/金币/已拥有校验）由 HeroManager 单测覆盖。

const CS: float = 1.28125
# PanelLayer 高（493/CS=384.78 四舍五入，tscn 实际值）
const BG_H: float = 385.0

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 从 Fragment 表取一个英雄产物配方（key<100）：{tid, frag_id}。
func _find_hero_fragment_recipe() -> Dictionary:
	var raw: Dictionary = cm.get_raw_table(&"Fragment")
	for tid_str in raw:
		if int(tid_str) < 100:
			return {"tid": int(tid_str), "frag_id": int(raw[tid_str].get(&"Fragment ID", 0))}
	return {}


func _make_panel(p_tid: int, p_pd: PlayerData) -> FragmentComposePanel:
	var panel := FragmentComposePanel.new("fragmentcompose", {})
	panel.setup_panel(p_tid, cm, p_pd)
	return panel


# 收集 panel.container 下所有 Label 的 text（含递归子节点）。
# 重构后 panel 层从 .tscn instantiate 多一层 content（container→content→%节点），
# Label/Button 都在 content 子树，扫须递归（参照 hero_detail 测试 _count_meta_recursive 范式）。
func _collect_label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect_label_texts(c, out)


func _instantiate_content() -> Control:
	var scene: PackedScene = load("res://scenes/ui/fragment_compose_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


# panel.container 首子节点即 content 实例（% 唯一名 owner 是 content 根，
# 从 container 直接 get_node("%X") 越过 owner 边界不可达）。
func _panel_content(panel: FragmentComposePanel) -> Control:
	return panel.container.get_child(0) as Control


# PanelLayer 局部 rect 中心（子节点挂 PanelLayer 下，anchor 0，offset 即局部 rect）。
func _center_in_panel_layer(inst: Control, p_path: String) -> Vector2:
	var n: Control = inst.get_node(p_path) as Control
	return Vector2(
		(n.offset_left + n.offset_right) / 2.0,
		(n.offset_top + n.offset_bottom) / 2.0
	)


# ── LSTR 化精修验证（源 :273/:369/:459 + JSON 值核对）──

func test_lstr_keys_resolve_to_chinese_not_fallback() -> void:
	# 记忆：lstr 生成器字符集曾漏字符致 key 缺失，get_lstr 静默返 key 本身。
	# 6 个 key 全部命中 LSTR_zh-CN.json 才算数据完整（grep 已核对，断言固化防回归）。
	assert_eq(cm.get_lstr("EQUIPCRAFT.SYNTHESIS"), "合成", "EQUIPCRAFT.SYNTHESIS 前缀解析")
	assert_eq(cm.get_lstr("EQUIPCRAFT.SYNTHESIS_COST_"), "合成花费：", "EQUIPCRAFT.SYNTHESIS_COST_ 费用标题（源 :369 带尾下划线）")
	assert_eq(cm.get_lstr("FRAGMENTCOMPOSE.CONFIRM_SYNTHESIS"), "确认合成", "CONFIRM_SYNTHESIS 确认按钮")
	assert_eq(cm.get_lstr("FRAGMENTCOMPOSE.SUCCESSFULLY_SYNTHESIZED_FRAGMENT"), "碎片合成成功", "合成成功 toast")
	assert_eq(cm.get_lstr("FRAGMENTCOMPOSE.INSUFFICIENT_FRAGMENT_SYNTHESIS_FAILED"), "碎片不足，无法合成", "碎片不足 toast")
	assert_eq(cm.get_lstr("FRAGMENTCOMPOSE.YOU_HAVE_ALREADY_GOT_THIS_HERO"), "已拥有该英雄", "已拥有英雄 toast")


func test_setup_panel_renders_lstr_cost_title_and_name_prefix() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	assert_false(recipe.is_empty(), "Fragment 表有英雄配方（key<100）")
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_fragment(int(recipe["frag_id"]), 5)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	var texts: Array = []
	_collect_label_texts(panel.container, texts)
	# name 标题 = cm.get_lstr("EQUIPCRAFT.SYNTHESIS") + " " + makeName（源 :273-274）
	var expected_name: String = cm.get_lstr("EQUIPCRAFT.SYNTHESIS") + " "
	assert_true(texts.any(func(t: String) -> bool: return t.begins_with(expected_name)), "name label 用 LSTR 前缀（不再硬编码 '合成 '）")
	# cost title = cm.get_lstr("EQUIPCRAFT.SYNTHESIS_COST_")（源 :369，旧硬编码 "合成费用 "）
	var expected_cost_title: String = cm.get_lstr("EQUIPCRAFT.SYNTHESIS_COST_")
	assert_true(texts.has(expected_cost_title), "cost title 用 LSTR（不再硬编码 '合成费用 '）")
	panel.remove_window()
	root.queue_free()


func test_setup_panel_fills_ok_button_text() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_fragment(int(recipe["frag_id"]), 5)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	# ok 按钮文字 = Button.text（源 :459 ok_label fontinfo ui_normal_button →
	# FragmentComposeOkButton variation 字体配置，两件套 Task 6 起 UiScale9Button 退役）
	var ok_btn: Button = _panel_content(panel).get_node("%OkBtn") as Button
	assert_eq(ok_btn.text, cm.get_lstr("FRAGMENTCOMPOSE.CONFIRM_SYNTHESIS"), "OkBtn.text = LSTR 确认合成（源 :459）")
	assert_eq(ok_btn.theme_type_variation, &"FragmentComposeOkButton", "OkBtn 走 FragmentComposeOkButton variation")
	assert_false(ok_btn.has_theme_stylebox_override("normal"), "OkBtn 无运行时 normal stylebox override（样式入 theme）")
	panel.remove_window()
	root.queue_free()


# ── 布局守卫：源 bg 局部空间 → PanelLayer 容器（坐标系坑 #1，Task 6 核对修正）──
# 源 bg（fragmentcompose.lua:261-263）createSprite fragment_compose_bg.png 369x493
# 中心 ccp(400,240) → Godot 中心 (480,320)，显示 369/CS x 493/CS = 288x385，
# 左上 = (480-144, 320-192.5) = (336,127.5) = PanelLayer rect 原点。

func test_panel_layer_origin_and_size() -> void:
	var inst: Control = _instantiate_content()
	var pl: Control = inst.get_node("%PanelLayer") as Control
	assert_almost_eq(pl.offset_left, 256.0, 0.5, "PanelLayer left=336（bg 左上 x，源 bg 中心 400-144）")
	assert_almost_eq(pl.offset_top, 47.5, 0.5, "PanelLayer top=127.5（bg 左上 y，源 bg 中心 240 映射 320-192.5）")
	assert_almost_eq(pl.offset_right - pl.offset_left, 369.0 / CS, 0.5, "PanelLayer 宽 = 369/CS（bg 纹理显示宽）")
	assert_almost_eq(pl.offset_bottom - pl.offset_top, BG_H, 0.5, "PanelLayer 高 = 385（493/CS=384.78 四舍五入）")


# 子节点中心 = 源局部 p 的 (p.x, 385-p.y)（PanelLayer 局部左上原点）。
# 对照源 ui_info（:268-466 readnode 挂 bg）：position 即 bg 局部坐标。
func test_child_centers_match_source_bg_local_coords() -> void:
	var inst: Control = _instantiate_content()
	# name 标题（源 :277 ccp(142,348) 中心锚）
	var c := _center_in_panel_layer(inst, "%NameLabel")
	assert_almost_eq(c.x, 142.0, 0.5, "name 中心 x=142（源 :277）")
	assert_almost_eq(c.y, BG_H - 348.0, 0.5, "name 中心 y=385-348（源 :277）")
	# 箭头（源 :305 ccp(145,230)）
	c = _center_in_panel_layer(inst, "%PanelLayer/Arrow")
	assert_almost_eq(c.x, 145.0, 0.5, "arrow 中心 x=145（源 :305）")
	assert_almost_eq(c.y, BG_H - 230.0, 0.5, "arrow 中心 y=385-230")
	# 通用碎片提示（源 :346 ccp(145,130)）
	c = _center_in_panel_layer(inst, "%UniversalLabel")
	assert_almost_eq(c.x, 145.0, 0.5, "universal 中心 x=145（源 :346）")
	assert_almost_eq(c.y, BG_H - 130.0, 0.5, "universal 中心 y=385-130")
	# 关闭按钮（源 :413 ccp(280,375)——骑面板右上边，顶缘越出 bg 属源原生）
	var close_btn: Control = inst.get_node("%CloseBtn") as Control
	assert_almost_eq(_center_in_panel_layer(inst, "%CloseBtn").x, 280.0, 0.5, "close 中心 x=280（源 :413）")
	assert_almost_eq(_center_in_panel_layer(inst, "%CloseBtn").y, BG_H - 375.0, 0.5, "close 中心 y=385-375（骑右上边照源）")
	assert_true(close_btn.offset_top < 0.0, "close 顶缘越出 PanelLayer（源 bg 高 385 < close 中心 375+半高，骑边照源）")
	# 合成按钮（源 :434 ccp(145,45) scaleSize 250x49）
	var ok_btn: Control = inst.get_node("%OkBtn") as Control
	assert_almost_eq(_center_in_panel_layer(inst, "%OkBtn").x, 145.0, 0.5, "ok 中心 x=145（源 :434）")
	assert_almost_eq(_center_in_panel_layer(inst, "%OkBtn").y, BG_H - 45.0, 0.5, "ok 中心 y=385-45")
	assert_almost_eq(ok_btn.offset_right - ok_btn.offset_left, 250.0, 0.5, "ok 宽 250（源 scaleSize 直译）")
	assert_almost_eq(ok_btn.offset_bottom - ok_btn.offset_top, 49.0, 0.5, "ok 高 49")


# 行内锚定元素：源 anchor(1,0.5)/(0,0.5) 同点 (78,178)（:316/:331）
# → 数字右缘与 "/need" 左缘相接于局部 x=78，行中心 y=385-178。
func test_amount_labels_anchored_edges_meet_at_source_x() -> void:
	var inst: Control = _instantiate_content()
	var amount: Label = inst.get_node("%AmountLabel") as Label
	var need: Label = inst.get_node("%AmountNeedLabel") as Label
	assert_almost_eq(amount.offset_right, 78.0, 0.5, "amount 右缘 x=78（源 :316 anchor(1,0.5)）")
	assert_almost_eq(need.offset_left, 78.0, 0.5, "need 左缘 x=78（源 :331 anchor(0,0.5)）")
	assert_almost_eq(_center_in_panel_layer(inst, "%AmountLabel").y, BG_H - 178.0, 0.5, "amount 行中心 y=385-178")
	assert_eq(amount.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "amount 右对齐")
	assert_eq(need.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "need 左对齐")


# 费用行（源 :359-399）：cost_bg(142,95) fix_size 260x32 直译（不÷CS）；
# cost_title(72,94)、cost_icon(152,95)、cost(180,94) anchor(0,0.5) 左缘。
func test_cost_row_layout_matches_source() -> void:
	var inst: Control = _instantiate_content()
	var cost_bg: Control = inst.get_node("%PanelLayer/CostBg") as Control
	var c := _center_in_panel_layer(inst, "%PanelLayer/CostBg")
	assert_almost_eq(c.x, 142.0, 0.5, "cost_bg 中心 x=142（源 :359）")
	assert_almost_eq(c.y, BG_H - 95.0, 0.5, "cost_bg 中心 y=385-95")
	assert_almost_eq(cost_bg.offset_right - cost_bg.offset_left, 260.0, 0.5, "cost_bg 宽 260（源 fix_size 直译）")
	assert_almost_eq(cost_bg.offset_bottom - cost_bg.offset_top, 32.0, 0.5, "cost_bg 高 32")
	c = _center_in_panel_layer(inst, "%CostTitleLabel")
	assert_almost_eq(c.x, 72.0, 0.5, "cost_title 中心 x=72（源 :374）")
	c = _center_in_panel_layer(inst, "%PanelLayer/CostIcon")
	assert_almost_eq(c.x, 152.0, 0.5, "cost_icon 中心 x=152（源 :387）")
	assert_almost_eq(inst.get_node("%PanelLayer/CostIcon").scale.x, 0.8, 0.01, "cost_icon scale 0.8（源 :388）")
	var cost_lbl: Control = inst.get_node("%CostLabel") as Control
	assert_almost_eq(cost_lbl.offset_left, 180.0, 0.5, "cost 左缘 x=180（源 :399 anchor(0,0.5)）")


# 碎片/产物图标挂点（源 :471/:475 fragmentIcon(78,230)/makeIcon(212,230) 中心锚）
# → 零尺寸点 host 置图标中心，icon 挂后负半偏移居中（stone_detail/shop 同款）。
func test_icon_hosts_at_source_icon_centers() -> void:
	var inst: Control = _instantiate_content()
	var frag_host: Control = inst.get_node("%FragmentIconHost") as Control
	var make_host: Control = inst.get_node("%MakeIconHost") as Control
	assert_almost_eq(frag_host.offset_left, 78.0, 0.5, "碎片图标挂点 x=78（源 :471）")
	assert_almost_eq(frag_host.offset_top, BG_H - 230.0, 0.5, "碎片图标挂点 y=385-230")
	assert_almost_eq(make_host.offset_left, 212.0, 0.5, "产物图标挂点 x=212（源 :475）")
	assert_almost_eq(make_host.offset_top, BG_H - 230.0, 0.5, "产物图标挂点 y 同行")


# 贴图接线（源 res 字段直译）+ 显示尺寸 = 像素÷CS。
func test_textures_wired_with_display_size() -> void:
	var inst: Control = _instantiate_content()
	var bg: TextureRect = inst.get_node("%PanelLayer/Bg") as TextureRect
	assert_not_null(bg.texture, "bg 贴图接线")
	assert_true(bg.texture.resource_path.ends_with("fragment_compose_bg.png"), "bg = fragment_compose_bg.png（源 :261）")
	var arrow: TextureRect = inst.get_node("%PanelLayer/Arrow") as TextureRect
	assert_true(arrow.texture.resource_path.ends_with("fragment_compose_arrow.png"), "arrow = fragment_compose_arrow.png（源 :301）")
	assert_almost_eq(arrow.offset_right - arrow.offset_left, 37.0 / CS, 0.5, "arrow 宽 = 37/CS")
	var cost_bg: TextureRect = inst.get_node("%PanelLayer/CostBg") as TextureRect
	assert_true(cost_bg.texture.resource_path.ends_with("equip_craft_money_bg.png"), "cost_bg = equip_craft_money_bg.png（源 :356）")
	var gold: TextureRect = inst.get_node("%PanelLayer/CostIcon") as TextureRect
	assert_true(gold.texture.resource_path.ends_with("goldicon.png"), "cost_icon = goldicon.png（源 :383）")
	var close_btn: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_true(close_btn.texture_normal.resource_path.ends_with("herodetail-detail-close.png"), "close normal（源 :409）")
	assert_true(close_btn.texture_pressed.resource_path.ends_with("herodetail-detail-close-p.png"), "close pressed（源 :419，双态合并 TextureButton）")


# variation 接线（GUT 下节点级 get_theme_font_size 不解析 variation，断 tscn 属性 +
# default_theme.tres 文本表项——批 1 方法学）。
func test_labels_use_theme_variations() -> void:
	var inst: Control = _instantiate_content()
	assert_eq((inst.get_node("%NameLabel") as Label).theme_type_variation, &"FragmentComposeNameLabel", "Name variation")
	assert_eq((inst.get_node("%AmountLabel") as Label).theme_type_variation, &"FragmentComposeDynLabel18", "Amount variation（动态色）")
	assert_eq((inst.get_node("%AmountNeedLabel") as Label).theme_type_variation, &"FragmentComposeLabel18Brown", "AmountNeed variation")
	assert_eq((inst.get_node("%UniversalLabel") as Label).theme_type_variation, &"FragmentComposeUniversalLabel", "Universal variation")
	assert_eq((inst.get_node("%CostTitleLabel") as Label).theme_type_variation, &"FragmentComposeLabel18Brown", "CostTitle variation（与 AmountNeed 同规格共用）")
	assert_eq((inst.get_node("%CostLabel") as Label).theme_type_variation, &"FragmentComposeDynLabel18", "Cost variation（动态色）")
	var tres: String = FileAccess.get_file_as_string("res://resources/themes/default_theme.tres")
	assert_true(tres.contains("FragmentComposeNameLabel/colors/font_color = Color(0.721569, 0.023529, 0.023529, 1)"), "Name 18px ccc3(184,6,6)（源 :281）")
	assert_true(tres.contains("FragmentComposeLabel18Brown/colors/font_color = Color(0.196078, 0.160784, 0.121569, 1)"), "棕 18px ccc3(50,41,31)（源 :334/:377）")
	assert_true(tres.contains("FragmentComposeUniversalLabel/colors/font_color = Color(0.713726, 0.254902, 0.082353, 1)"), "Universal 20px ccc3(182,65,21)（源 :348）")
	assert_true(tres.contains("FragmentComposeOkButton/styles/normal = SubResource(\"SB_fc_ok_n\")"), "ok 按钮 normal 样式入 theme")


# ── fill 语义守卫（照源行为）──

# universal 提示（源 :341-350）：text = lackText（两分支同为 INSUFFICIENT 文案，
# 源 :236-240 复制粘贴死分支，照可见行为直译），visible = 专属碎片不足。
func test_universal_label_source_lack_text_semantics() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_fragment(int(recipe["frag_id"]), 0)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	var uni_lbl: Label = _panel_content(panel).get_node("%UniversalLabel") as Label
	assert_true(uni_lbl.visible, "碎片不足时显示（源 visible=lackAmount~=0）")
	assert_eq(uni_lbl.text, cm.get_lstr("FRAGMENTCOMPOSE.INSUFFICIENT_FRAGMENT_SYNTHESIS_FAILED"), "text=源 lackText（不再自创 '通用碎片 x/y'）")
	panel.remove_window()
	# 碎片足够 → 隐藏
	var pd2 := PlayerData.new(cm)
	var frag_need: int = cm.get_int(&"Fragment", int(recipe["tid"]), &"Fragment Count")
	pd2.hero_manager.add_fragment(int(recipe["frag_id"]), frag_need)
	var panel2 := _make_panel(int(recipe["tid"]), pd2)
	panel2.show_window(root)
	assert_false((_panel_content(panel2).get_node("%UniversalLabel") as Label).visible, "碎片足够时隐藏")
	panel2.remove_window()
	root.queue_free()


# amount 颜色（源 getInformation :241-245 可见行为）：不足红 ccc3(255,0,0)，足 ccc3(169,91,28)。
func test_amount_color_source_palette() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	var pd := PlayerData.new(cm)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	var amount_lbl: Label = _panel_content(panel).get_node("%AmountLabel") as Label
	assert_eq(amount_lbl.get_theme_color("font_color"), Color(1, 0, 0), "不足=红 ccc3(255,0,0)（源 :242）")
	panel.remove_window()
	root.queue_free()


# cost 颜色（源 refreshCostColor :108-119，create :481-482 末尾刷新覆盖初始色）：
# 不足 ccc3(232,18,18)，足 ccc3(182,65,21)。
func test_cost_color_source_palette() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 0
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	var cost_lbl: Label = _panel_content(panel).get_node("%CostLabel") as Label
	assert_eq(cost_lbl.get_theme_color("font_color"), Color(232.0 / 255.0, 18.0 / 255.0, 18.0 / 255.0), "金币不足=红 ccc3(232,18,18)（源 :113）")
	panel.remove_window()
	root.queue_free()


# 信号链：close/ok pressed 已 connect（源 doCloseButtonTouch/doOKButtonTouch）。
func test_close_ok_signals_connected() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	var pd := PlayerData.new(cm)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	var close_btn: TextureButton = _panel_content(panel).get_node("%CloseBtn") as TextureButton
	assert_true(close_btn.pressed.is_connected(Callable(panel, "_on_close_pressed")), "close pressed → _on_close_pressed")
	var ok_btn: Button = _panel_content(panel).get_node("%OkBtn") as Button
	assert_true(ok_btn.pressed.is_connected(Callable(panel, "_on_compose_pressed")), "ok pressed → _on_compose_pressed")
	panel.remove_window()
	root.queue_free()
