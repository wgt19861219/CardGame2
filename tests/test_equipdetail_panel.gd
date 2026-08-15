extends GutTest
# equipdetail 弹窗测试（2026-07-05 第 26 段；批 1 Task 7 两件套改造 2026-08-15）。
# 照源 equipdetail.lua：静态框架（bg/close/icon/amount/scroll）+ 3 段滚动
# （可合成装备/可装备英雄/获得途径）静态进 tscn，行走行模板 instantiate。
# 守卫断言语义：结构存在/rect 值/variation 名/stylebox 贴图/fill 绑定/零静态 .new()。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _find_equip_with_drop() -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		if int(raw[tid_str].get("Drop 1", 0)) > 0:
			return int(tid_str)
	return 0


# 找作为某配方 component 的装备（源 getEquipData equipList>0 段显示条件）。
func _find_equip_with_recipe() -> int:
	var craft: Dictionary = cm.get_raw_table(&"Equipcraft")
	for tid_str in craft:
		var row: Dictionary = craft[tid_str]
		for i in range(1, 5):
			var comp: int = int(row.get("Component" + str(i), 0))
			if comp > 0:
				return comp
	return 0


# 返回 [equip_id, hero_tid]：该英雄某 rank 配方含该装备（源 getEquipData heroList）。
func _find_hero_equip_pair() -> Array:
	var he: Dictionary = cm.get_raw_table(&"Hero_equip")
	for tid_str in he:
		var ranks: Dictionary = he[tid_str]
		for rk_str in ranks:
			for j in range(1, 7):
				var eid: int = int(ranks[rk_str].get("Equip" + str(j) + " ID", 0))
				if eid > 0:
					return [eid, int(tid_str)]
	return [0, 0]


func _find_equip_with_how_to_get() -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		if String(raw[tid_str].get("How To Get", "")) != "":
			return int(tid_str)
	return 0


func _make_panel(equip_id: int, pd: PlayerData) -> EquipdetailPanel:
	var panel := EquipdetailPanel.new("equipdetail", {})
	panel.setup_panel(equip_id, cm, pd)
	panel.show_window(self)
	return panel


# content 实例根（% 唯一名的 owner 是 content 场景根，从 panel 直取越 owner
# 边界——批 1 Task 6 踩坑修正，测试统一走本 helper）。
func _content_of(panel: EquipdetailPanel) -> Control:
	return panel.container.get_child(0) as Control


# ── 旧用例（第 26 段迁移期）──


func test_setup_builds_frame() -> void:
	var pd := PlayerData.new(cm)
	var panel := _make_panel(_find_equip_with_drop(), pd)
	assert_gt(panel.container.get_child_count(), 0, "frame 已建（container 有子）")
	panel.remove_window()


func test_close_removes_window() -> void:
	var pd := PlayerData.new(cm)
	var panel := _make_panel(_find_equip_with_drop(), pd)
	panel._on_close_pressed()
	await get_tree().process_frame
	assert_false(is_instance_valid(panel), "close 后 panel 销毁")


# EquipboardPanel prop 右按钮 → 弹 EquipdetailPanel（第 26 段接 check）。
func test_equipboard_prop_opens_detail() -> void:
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_with_drop()
	var cell: Dictionary = {"id": eid, "makeId": eid, "amount": 1, "category": "EQUIP.PARTS", "type": 1}
	var board := EquipboardPanel.new("equipboard", {})
	board.setup_panel(cell, cm, pd)
	board.show_window(self)
	board._on_right_pressed()   # prop → _open_detail
	var has_detail: bool = false
	for c in get_children():
		if c is EquipdetailPanel:
			has_detail = true
			c.queue_free()
			break
	assert_true(has_detail, "EquipboardPanel prop 右按钮弹 EquipdetailPanel")
	board.remove_window()


# P1-12 → Task 7：panel_bg Scale9 贴图（源 :152/188/228 capInsets(10,30,400,65)）
# 两件套后走 PanelContainer variation 的 StyleBoxTexture（禁运行时 NinePatchRect.new）。
# 节点级 get_theme_* 不解析 variation（批 1 Task 1 沉淀）→ 数值断言读 theme 资源表项。
func test_panel_bg_texture_assembled() -> void:
	var pd := PlayerData.new(cm)
	var panel := _make_panel(_find_equip_with_drop(), pd)
	var panels: Array = panel.find_children("*", "PanelContainer", true, false)
	assert_gt(panels.size(), 0, "panel_bg PanelContainer 装配（variation stylebox）")
	var wired: bool = false
	for p in panels:
		if (p as PanelContainer).theme_type_variation == &"EquipDetailPanelBox":
			wired = true
			break
	assert_true(wired, "段面板走 EquipDetailPanelBox variation")
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	var sb: StyleBox = theme.get_stylebox(&"panel", &"EquipDetailPanelBox")
	assert_true(sb is StyleBoxTexture, "variation panel 项是 StyleBoxTexture")
	var tex: StyleBoxTexture = sb as StyleBoxTexture
	assert_not_null(tex.texture, "stylebox 贴图非空")
	assert_true(String(tex.texture.resource_path).find("equip_detail_panel_bg") >= 0, "panel_bg 贴图 equip_detail_panel_bg")
	# texture margins 照源 capInsets CCRectMake(10,30,400,65)（贴图 533x175，cap 左下
	# 原点 → top=H-y-h / bottom=y，批 1 终审必修 1 修正垂直互换）：
	# left=10 top=175-30-65=80 right=533-410=123 bottom=30（4.7 属性名 texture_margin_*）
	assert_eq(tex.texture_margin_left, 10.0, "capInsets left=10")
	assert_eq(tex.texture_margin_top, 80.0, "capInsets top=175-30-65")
	assert_eq(tex.texture_margin_right, 123.0, "capInsets right=533-10-400")
	assert_eq(tex.texture_margin_bottom, 30.0, "capInsets bottom=30")
	# content margin 照源网格位（面板 560-两列 520 → 左右 20；行高公式 15+55r → 顶底 7.5）
	assert_eq(tex.content_margin_left, 20.0, "网格左右余 20")
	assert_eq(tex.content_margin_top, 7.5, "网格顶 7.5")
	assert_eq(tex.content_margin_bottom, 7.5, "网格底 7.5")
	panel.remove_window()


# P1-12：获取途径关卡图标装配（key_stages/stage-N.png，源 :256 createSprite(way.res)）。
func test_get_way_stage_icon_assembled() -> void:
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_with_drop()
	var panel := _make_panel(eid, pd)
	var query_data: Dictionary = EquipdetailQuery.query(eid, cm, pd)
	var get_way: Array = query_data["get_way"]
	if get_way.size() > 0:
		var first_res: String = String((get_way[0] as Dictionary).get("res", ""))
		assert_true(_has_tex(panel, first_res), "获取途径关卡图标装配（key_stages/stage-N）")
	else:
		assert_true(true, "该装备无 get_way，跳过")
	panel.remove_window()


# 递归查 TextureRect by resource_path。
func _has_tex(node: Node, path: String) -> bool:
	if node is TextureRect and node.texture != null and node.texture.resource_path == path:
		return true
	for c in node.get_children():
		if _has_tex(c, path):
			return true
	return false


# ── 批 1 Task 7 两件套守卫 ──


# content tscn 三段静态结构（源 createDetail 三段：equip/hero/get 均为
# 标题条+panel_bg 面板+网格，段1/段2 条件显示走 visible 切换）。
func test_content_static_section_tree() -> void:
	var scene: PackedScene = load("res://scenes/ui/equipdetail_content.tscn")
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	for section in ["%EquipSection", "%HeroSection", "%GetSection"]:
		var sec: Node = inst.get_node_or_null(section)
		assert_not_null(sec, "%s 段节点常驻 tscn" % section)
	for grid in ["%EquipGrid", "%HeroGrid", "%GetGrid"]:
		var g: Node = inst.get_node_or_null(grid)
		assert_not_null(g, "%s 网格常驻 tscn" % grid)
		assert_eq((g as GridContainer).columns, 2, "%s 双列（源 260 列距 2 列布局）" % grid)
		assert_true(g is GridContainer, "%s 是 GridContainer" % grid)
	var get_panel: Node = inst.get_node_or_null("%GetPanel")
	assert_not_null(get_panel, "GetPanel 常驻 tscn")
	assert_true(get_panel is PanelContainer, "GetPanel 是 PanelContainer（stylebox 面板）")
	var how: Node = inst.get_node_or_null("%HowLabel")
	assert_not_null(how, "HowLabel 常驻 tscn（源 How To Get 条件段）")


# 裁剪区照源 draglist cliprect CCRectMake(0,47,740,387)：可视高 387 直译
# （top=560-434=126 / bottom=560-47=513）；水平取内容面板 560 宽（源 740 为
# 不裁水平宽泛值），滚动条左置（源 bgpos x=117）→ 引擎默认右侧为受控偏离。
func test_scroll_clip_rect() -> void:
	var scene: PackedScene = load("res://scenes/ui/equipdetail_content.tscn")
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var clip: ScrollContainer = inst.get_node("%ScrollClip") as ScrollContainer
	assert_almost_eq(clip.offset_top, 126.0, 0.5, "clip 顶 = 560-(47+387)")
	assert_almost_eq(clip.offset_bottom, 513.0, 0.5, "clip 底 = 560-47")
	assert_almost_eq(clip.size.x, 560.0, 1.0, "clip 宽 = 源面板 560（内容宽）")
	assert_eq(clip.horizontal_scroll_mode, 0, "禁水平滚动（源仅 canDragY）")


# 三段标题（源 :146/182/223 createttf 24 号 ccc3(250,205,16)）走
# EquipDetailSectionTitle variation + fill 文本（LSTR 三 key）。
func test_section_title_variation_and_fill() -> void:
	var pd := PlayerData.new(cm)
	var panel := _make_panel(_find_equip_with_recipe(), pd)
	for path in ["%EquipTitleLabel", "%HeroTitleLabel", "%GetTitleLabel"]:
		var lbl: Label = _content_of(panel).get_node(path) as Label
		assert_not_null(lbl, "%s 存在" % path)
		assert_eq(lbl.theme_type_variation, &"EquipDetailSectionTitle", "%s variation 接线" % path)
	assert_eq((_content_of(panel).get_node("%GetTitleLabel") as Label).text, cm.get_lstr("EQUIPCRAFT.WAY_TO_GET"), "获得途径标题 fill")
	panel.remove_window()


# 段显隐照源条件（#equipList>0 / #heroList>0 / get 段恒显）。
func test_sections_visibility_follows_query() -> void:
	var pd := PlayerData.new(cm)
	var recipe_eid: int = _find_equip_with_recipe()
	var panel := _make_panel(recipe_eid, pd)
	var data: Dictionary = EquipdetailQuery.query(recipe_eid, cm, pd)
	var equip_sec: Control = _content_of(panel).get_node("%EquipSection") as Control
	var hero_sec: Control = _content_of(panel).get_node("%HeroSection") as Control
	var get_sec: Control = _content_of(panel).get_node("%GetSection") as Control
	assert_true(equip_sec.visible == ((data["equip_list"] as Array).size() > 0), "EquipSection 显隐照 equip_list")
	assert_true(hero_sec.visible == ((data["hero_list"] as Array).size() > 0), "HeroSection 显隐照 hero_list")
	assert_true(get_sec.visible, "GetSection 恒显（源 :220 无条件段）")
	panel.remove_window()


# 装备段行走行模板（equipdetail_item_cell.tscn：IconHost+NameLabel），
# 行数 = query equip_list 条数，name 文本 fill。
func test_item_rows_use_cell_template() -> void:
	var pd := PlayerData.new(cm)
	var recipe_eid: int = _find_equip_with_recipe()
	var panel := _make_panel(recipe_eid, pd)
	var data: Dictionary = EquipdetailQuery.query(recipe_eid, cm, pd)
	var grid: GridContainer = _content_of(panel).get_node("%EquipGrid") as GridContainer
	var expected: int = (data["equip_list"] as Array).size()
	assert_eq(grid.get_child_count(), expected, "装备段行数 = equip_list 条数")
	if expected > 0:
		var row: Control = grid.get_child(0) as Control
		assert_not_null(row.get_node_or_null("%IconHost"), "行含 %IconHost（行模板）")
		var name_lbl: Label = row.get_node_or_null("%NameLabel") as Label
		assert_not_null(name_lbl, "行含 %NameLabel（行模板）")
		var first_name: String = cm.get_lstr(String((data["equip_list"][0] as Dictionary)["name"]))
		assert_eq(name_lbl.text, first_name, "行 name 文本 fill")
	panel.remove_window()


# 行内水平 rect 守卫（审查修复：防行组整组右偏 60px 复发）。源 :8
# offsetX=-40；行内公式（:164/:169 装备，:204/:212 英雄，:257/:262 获取
# 同构）icon 中心/name 左端 x=200/230+260*col-40（col0 即 160/190）；面板
# :154/158 中心 440-40=400 anchor(0.5,1) 宽 560 → 左缘 120 → icon 中心距
# 面板左缘 40、name 左端距 70；再减 SB_equip_detail_panel content_margin_
# left 20 → 行内 icon 中心 20、name 左端 50（col1 列内相对不变）。
func test_item_cell_row_horizontal_rect() -> void:
	var scene: PackedScene = load("res://scenes/ui/equipdetail_item_cell.tscn")
	var cell: Control = scene.instantiate() as Control
	add_child_autofree(cell)
	var host: Control = cell.get_node("%IconHost") as Control
	assert_almost_eq(host.position.x, 20.0, 0.5, "icon 中心行内 20（源 160-面板左缘 120-余 20）")
	var way: TextureRect = cell.get_node("%WayIcon") as TextureRect
	assert_almost_eq(way.position.x + way.size.x * 0.5, 20.0, 0.5,
		"WayIcon 中心行内 20（源 :257 同公式与 icon 同列）")
	var name_lbl: Label = cell.get_node("%NameLabel") as Label
	assert_almost_eq(name_lbl.position.x, 50.0, 0.5, "name 左端行内 50（源 190-120-20）")


# 英雄段 icon 照源 :198 readhero.getIcon({id,rank,length=40})（rank 框 104 容器
# 缩放 40/104）——旧版误用装备 icon 工厂，本 task 照源归位。
func test_hero_rows_use_readhero_icon() -> void:
	var pair: Array = _find_hero_equip_pair()
	var eid: int = int(pair[0])
	var hero_tid: int = int(pair[1])
	assert_gt(eid, 0, "存在英雄装备配方对")
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(hero_tid)
	var panel := _make_panel(eid, pd)
	var grid: GridContainer = _content_of(panel).get_node("%HeroGrid") as GridContainer
	assert_gt(grid.get_child_count(), 0, "已召唤英雄 → 英雄段有行")
	var found: bool = false
	for i in range(grid.get_child_count()):
		var host: Control = (grid.get_child(i) as Control).get_node_or_null("%IconHost") as Control
		if host == null:
			continue
		for c in host.get_children():
			if c is ReadheroIcon:
				found = true
	assert_true(found, "英雄行 icon 是 ReadheroIcon（源 readhero.getIcon）")
	panel.remove_window()


# How To Get 文本（源 :270-289 18 号 ccc3(238,204,119) dimension 240x0 换行+黑影）。
func test_how_label_fill_and_wrap() -> void:
	var how_eid: int = _find_equip_with_how_to_get()
	assert_gt(how_eid, 0, "存在 How To Get 样本")
	var pd := PlayerData.new(cm)
	var panel := _make_panel(how_eid, pd)
	var how: Label = _content_of(panel).get_node("%HowLabel") as Label
	assert_true(how.visible, "有 How To Get → HowLabel 显示")
	assert_eq(how.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "照源 dimension 240x0 自动换行")
	assert_almost_eq(how.size.x, 240.0, 2.0, "照源宽 240")
	assert_eq(how.theme_type_variation, &"EquipDetailHowLabel", "HowLabel variation 接线")
	panel.remove_window()


# 拥有数量（源 createIcon :307-317：x+N 18 号，>0 绿 ccc3(0,200,0) / 0 红
# ccc3(255,0,0)，直设色语义 → font_color override，黑影 (0,1)）。
func test_amount_label_fill() -> void:
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_with_drop()
	var panel := _make_panel(eid, pd)
	var lbl: Label = _content_of(panel).get_node("%AmountLabel") as Label
	assert_eq(lbl.text, "x0", "未持有 → x0")
	assert_true(lbl.has_theme_color_override("font_color"), "色走 font_color override（源直设色）")
	assert_eq(lbl.get_theme_color(&"font_color"), Color(1, 0, 0), "amount=0 红")
	panel.remove_window()


# 两件套红线：panel 零静态 .new()（12 处全数归位：段结构进 tscn、行走行模板
# instantiate、装备 icon/关卡贴图走工厂/模板静态 WayIcon）。白名单仅
# ReadheroIcon.new()（源 readhero.getIcon 工厂构造，无静态工厂入口）。
# 计数用 ".new(" 宽口径（带参构造不含 ".new()" 字面，窄口径漏检）。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/equipdetail_panel.gd")
	assert_eq(text.count(".new("), text.count("ReadheroIcon.new("),
		"零静态 .new(，仅 ReadheroIcon 工厂构造白名单")
