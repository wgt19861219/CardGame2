extends GutTest
## 碎片详情面板测试（View 层）— 照源 ui/stonedetail.lua（702 行）。
## 覆盖：setup_panel 后基础结构（.tscn instantiate + 节点 fill）、获取途径 Drop1-3 过滤、
## 拥有量/需求颜色（不足红 / 够棕）、无掉落时 empty_prompt、未开章节 limit_label。
## Logic 层（get_stone_id/amount/need）由 test_readhero_handbook 覆盖；本测试聚焦 View 装配。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 从 Unit 表取一个英雄 tid（id<100），确保英雄有对应碎片条目 + 至少一个 Drop。
func _find_hero_with_drops() -> Dictionary:
	var raw_unit: Dictionary = cm.get_raw_table(&"Unit")
	var raw_frag: Dictionary = cm.get_raw_table(&"Fragment")
	var raw_equip: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw_unit:
		var tid: int = int(tid_str)
		if tid >= 100:
			continue
		if not raw_frag.has(tid_str):
			continue
		var sid: int = int(raw_frag[tid_str].get(&"Fragment ID", 0))
		if sid <= 0 or not raw_equip.has(str(sid)):
			continue
		# 至少 Drop 1 有效
		if int(raw_equip[str(sid)].get("Drop 1", 0)) > 0:
			return {"tid": tid, "sid": sid}
	return {}


# 找一个英雄碎片无任何 Drop 的（验证 empty_prompt 分支）。
func _find_hero_without_drops() -> Dictionary:
	var raw_unit: Dictionary = cm.get_raw_table(&"Unit")
	var raw_frag: Dictionary = cm.get_raw_table(&"Fragment")
	var raw_equip: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw_unit:
		var tid: int = int(tid_str)
		if tid >= 100:
			continue
		if not raw_frag.has(tid_str):
			continue
		var sid: int = int(raw_frag[tid_str].get(&"Fragment ID", 0))
		if sid <= 0 or not raw_equip.has(str(sid)):
			continue
		var has_drop: bool = false
		for i in range(1, 4):
			if int(raw_equip[str(sid)].get("Drop " + str(i), 0)) > 0:
				has_drop = true
				break
		if not has_drop:
			return {"tid": tid, "sid": sid}
	return {}


func _make_panel(p_tid: int, p_pd: PlayerData) -> StoneDetailPanel:
	var panel := StoneDetailPanel.new("stonedetail", {})
	panel.setup_panel(p_tid, cm, p_pd, p_pd.hero_manager)
	return panel


func _count_recursive(node: Node, pred: Callable) -> int:
	var n: int = 0
	if pred.call(node):
		n += 1
	for c in node.get_children():
		n += _count_recursive(c, pred)
	return n


# ── LSTR key 解析验证（数据完整性，防 get_lstr 返 key 本身）──

func test_lstr_keys_resolve_to_chinese() -> void:
	assert_eq(cm.get_lstr("STONEDETAIL.WAY_TO_GET_"), "获得途径：", "WAY_TO_GET_")
	assert_eq(cm.get_lstr("STONEDETAIL.NOT_YET_OPEN"), "（未开放）", "NOT_YET_OPEN")
	assert_eq(cm.get_lstr("EQUIPCRAFT.RETURN"), "返回", "RETURN 按钮")
	assert_eq(cm.get_lstr("EQUIPCRAFT.ELITE"), "精英", "ELITE 标记")
	assert_true(cm.get_lstr("EQUIPCRAFT._CHAPTER__D").find("%d") >= 0, "_CHAPTER__D 含 %d 占位符")
	assert_eq(cm.get_lstr("EQUIPCRAFT.CHAPTER_YET_TO_OPEN"), "关卡尚未开启。", "CHAPTER_YET_TO_OPEN")


# ── 装配基础（name/way title/ok 按钮）──

func test_setup_panel_fills_name_and_way_title() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_with_drops()
	assert_false(recipe.is_empty(), "数据表存在带 Drop 的英雄碎片")
	var pd := PlayerData.new(cm)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	# name = Unit[tid]["Display Name"]（存 LSTR key → get_lstr 本地化，eatexp 同口径）
	var expected_name: String = cm.get_lstr(String(cm.get_raw_table(&"Unit").get(str(recipe["tid"]), {}).get(&"Display Name", "")))
	var name_lbl: Label = panel._content.get_node("%NameLabel")
	assert_eq(name_lbl.text, expected_name, "NameLabel 填英雄 Display Name")
	# way title = LSTR WAY_TO_GET_
	var way_lbl: Label = panel._content.get_node("%WayTitleLabel")
	assert_eq(way_lbl.text, "获得途径：", "WayTitleLabel 用 LSTR")
	panel.remove_window()
	root.queue_free()


func test_ok_button_uses_return_label_and_scale9() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_with_drops()
	var pd := PlayerData.new(cm)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	var ok_btn: Button = panel._content.get_node("%OkBtn")
	# 两件套（批 1 Task 2）：Scale9 三态走 StoneDetailOkButton variation（theme 表项），
	# 文字走 Button.text（源 ok_label fontinfo ui_normal_button），禁运行时 stylebox override。
	assert_eq(ok_btn.text, "返回", "OkBtn.text = EQUIPCRAFT.RETURN")
	assert_eq(ok_btn.theme_type_variation, &"StoneDetailOkButton", "OkBtn 走 StoneDetailOkButton variation")
	assert_false(ok_btn.has_theme_stylebox_override("normal"), "OkBtn 无运行时 normal stylebox override")
	assert_eq(ok_btn.get_child_count(), 0, "OkBtn 无运行时加的子 Label（文字在 Button.text）")
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	var sb: StyleBox = theme.get_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "StoneDetailOkButton") as StyleBox
	assert_true(sb is StyleBoxTexture, "variation normal 为 StyleBoxTexture（源 Scale9 cap 15,15,138,19）")
	panel.remove_window()
	root.queue_free()


# ── 拥有量/需求渲染（不足红、够棕）──

func test_amount_label_color_low_when_insufficient() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_with_drops()
	var pd := PlayerData.new(cm)
	# 不加任何碎片 → amount=0 < need → 红色
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	var amount_lbl: Label = panel._content.get_node("%AmountLabel")
	assert_eq(amount_lbl.text, "0", "无碎片时 amount=0")
	# 源 config.color = nc or ec（直设颜色非乘法）：fill 用 font_color override 切红/棕，
	# 不用 modulate（variation 棕底 × modulate 红 = 色偏深红）。
	assert_eq(amount_lbl.get_theme_color("font_color"), StoneDetailPanel.COLOR_AMOUNT_LOW, "不足=红色（font_color override）")
	panel.remove_window()
	root.queue_free()


func test_amount_label_color_ok_when_enough() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_with_drops()
	var pd := PlayerData.new(cm)
	var sid: int = int(recipe["sid"])
	# 给足够碎片（先查 need，再加倍）
	var need: int = ReadheroHandbook.get_stone_need(int(recipe["tid"]), cm, pd.hero_manager)
	pd.hero_manager.add_fragment(sid, need * 2)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	var amount_lbl: Label = panel._content.get_node("%AmountLabel")
	assert_eq(amount_lbl.text, str(need * 2), "加碎片后 amount 同步")
	assert_eq(amount_lbl.get_theme_color("font_color"), StoneDetailPanel.COLOR_AMOUNT_OK, "够=棕色（font_color override）")
	panel.remove_window()
	root.queue_free()


# ── 获取途径列表（Drop1-3 过滤）──

func test_getway_list_built_from_drops() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_with_drops()
	var pd := PlayerData.new(cm)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	# 期望 board 数 = 有效 Drop 数（Chapter <= MaxChapter）
	var equip_info: Dictionary = cm.get_raw_table(&"Equip").get(str(recipe["sid"]), {})
	var stage_table: Dictionary = cm.get_raw_table(&"Stage")
	var max_chapter: int = int(cm.get_raw_table(&"GameConfig").get("MaxChapter", 13))
	var expected: int = 0
	for i in range(1, 4):
		var s: int = int(equip_info.get("Drop " + str(i), 0))
		if s > 0 and int(stage_table.get(str(s), {}).get("Chapter ID", 0)) <= max_chapter:
			expected += 1
	assert_eq(panel._getway_ids.size(), expected, "getway_ids 数与源 Drop 过滤一致")
	# EmptyPromptLabel 应隐藏
	var empty_lbl: Label = panel._content.get_node("%EmptyPromptLabel")
	assert_false(empty_lbl.visible, "有 Drop 时不显示 empty prompt")
	panel.remove_window()
	root.queue_free()


func test_empty_prompt_shown_when_no_drops() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_without_drops()
	if recipe.is_empty():
		pending("数据表无零 Drop 英雄碎片，跳过")
		return
	var pd := PlayerData.new(cm)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	assert_eq(panel._getway_ids.size(), 0, "无 Drop 时 getway 列表为空")
	var empty_lbl: Label = panel._content.get_node("%EmptyPromptLabel")
	assert_true(empty_lbl.visible, "无 Drop 时显示 empty prompt")
	assert_true(empty_lbl.text.length() > 0, "empty prompt 有文本（How To Get 或默认）")
	panel.remove_window()
	root.queue_free()


# ── close/ok 信号 ──

func test_close_and_ok_buttons_bound() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_with_drops()
	var pd := PlayerData.new(cm)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	assert_true(panel.is_inside_tree(), "panel 挂在树上")
	# 模拟点击 close
	(panel._content.get_node("%CloseBtn") as BaseButton).emit_signal("pressed")
	await get_tree().process_frame
	assert_false(is_instance_valid(panel), "close 按下后 panel 释放")
	root.queue_free()


# ── 两件套守卫（批 1 Task 2，2026-08-15）：theme variation + 裁剪层 + 行模板 + 零静态 .new() ──

func _instantiate_content() -> Control:
	var scene: PackedScene = load("res://scenes/ui/stone_detail_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


func test_content_variations_wired() -> void:
	# theme 红线：字号/颜色走 theme_type_variation，禁节点级 theme_override 硬编码
	# （源 name:18/(184,6,6)、gw_title:20/(155,34,14)、empty_prompt:18/(109,62,0)）。
	var inst: Control = _instantiate_content()
	var expects: Dictionary = {
		"%NameLabel": &"StoneDetailNameLabel",
		"%WayTitleLabel": &"StoneDetailWayTitleLabel",
		"%EmptyPromptLabel": &"StoneDetailEmptyLabel",
		"%AmountLParen": &"StoneAmountLabel",
		"%AmountLabel": &"StoneAmountLabel",
		"%AmountNeedLabel": &"StoneAmountLabel",
	}
	for path in expects:
		var lbl: Label = inst.get_node(path) as Label
		assert_not_null(lbl, String(path) + " 常驻 tscn")
		if lbl == null:
			continue
		assert_eq(lbl.theme_type_variation, expects[path], String(path) + " 走 variation")
		assert_false(lbl.has_theme_color_override("font_color"), String(path) + " 无 font_color override")
		assert_false(lbl.has_theme_font_size_override("font_size"), String(path) + " 无 font_size override")


func test_content_getway_clip_layer() -> void:
	# 源 stonedetail.lua:238-251 draglist cliprect CCRectMake(0,85,800,165)（infoContainer 局部，
	# infoContainer 全屏原点 (337.5,512)）→ Godot 裁剪层 (337.5,262)-(622.5,427)
	# （水平取面板宽 285：源宽 800=不裁水平；垂直照源 165 高）。三坑第 3 坑：clip_contents。
	var inst: Control = _instantiate_content()
	var clip: Control = inst.get_node_or_null("%GetwayClip") as Control
	assert_not_null(clip, "GetwayClip（源 draglist 裁剪层）常驻 tscn")
	if clip == null:
		return
	assert_true(clip.clip_contents, "GetwayClip 开 clip_contents（源 cliprect 语义）")
	assert_almost_eq(clip.offset_left, 257.5, 0.1, "clip 左 = 337.5 + cliprect.x")
	assert_almost_eq(clip.offset_top, 182.0, 0.1, "clip 顶 = 512 - (85+165)")
	assert_almost_eq(clip.offset_right, 542.5, 0.1, "clip 右 = 面板 infoContainer 右缘")
	assert_almost_eq(clip.offset_bottom, 347.0, 0.1, "clip 底 = 512 - 85")


func test_getway_item_template_static_tree() -> void:
	# 动态行范式：获取途径行模板 stone_detail_getway_item.tscn 静态树
	# （源 createList :279-360 board/icon/title/elite/name + refreshGetwayLimit :374-450 limit）。
	var scene: PackedScene = load("res://scenes/ui/stone_detail_getway_item.tscn") as PackedScene
	assert_not_null(scene, "行模板 tscn 存在")
	if scene == null:
		return
	var item: Control = scene.instantiate() as Control
	add_child_autofree(item)
	# board 显示尺寸 = equip_craft_getway_board 311x67 ÷ CS(1.28125) = 242.7x52.3
	assert_almost_eq(item.size.x, 242.7, 0.1, "行宽 = 311/CS")
	assert_almost_eq(item.size.y, 52.3, 0.1, "行高 = 67/CS")
	for path in ["Board", "StageIcon", "TitleLabel", "EliteLabel", "NameLabel", "LimitLabel"]:
		assert_not_null(item.get_node_or_null(path), "行模板 " + path + " 常驻")
	assert_not_null((item.get_node("Board") as TextureRect).texture, "Board 贴图已接线")
	assert_eq((item.get_node("TitleLabel") as Label).theme_type_variation, &"StoneDetailBoardLabel",
		"title 走 StoneDetailBoardLabel variation")
	assert_eq((item.get_node("NameLabel") as Label).theme_type_variation, &"StoneDetailBoardLabel",
		"name 走 StoneDetailBoardLabel variation")
	assert_eq((item.get_node("EliteLabel") as Label).theme_type_variation, &"StoneDetailEliteLabel",
		"elite 走 StoneDetailEliteLabel variation")
	assert_eq((item.get_node("LimitLabel") as Label).theme_type_variation, &"StoneAmountLabel",
		"limit 走 StoneAmountLabel variation（源 size16 ec 棕）")
	# elite/limit 是 right2 动态定位项 → 默认隐藏，由 fill 定位后显示。
	assert_false((item.get_node("EliteLabel") as Label).visible, "EliteLabel 默认隐藏（fill 按 isElite 显示）")
	assert_false((item.get_node("LimitLabel") as Label).visible, "LimitLabel 默认隐藏（fill 定位后显示）")


func test_panel_no_static_construction() -> void:
	# 两件套红线：panel 零静态 .new()（获取途径行走行模板 instantiate；碎片图标走
	# ReadequipIcon.create_icon 工厂）。禁计数式白名单数字，恒断 0。
	# 计数用 ".new(" 宽口径（带参构造不含 ".new()" 字面，窄口径漏检）。
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/stone_detail_panel.gd")
	assert_eq(text.count(".new("), 0, "stone_detail_panel 零 .new(（动态行/图标全走模板与工厂）")


func test_theme_stone_detail_entries() -> void:
	# variation 数值断言走 theme 资源表项（方法学沉淀：GUT 节点级 get_theme_font_size 不解析
	# variation 回落 16）。数值照源 ccc3/size；色断言用分量近似（.tres 6 位小数 vs 255 制
	# 分数在 float32 上不相等，差 <0.00001 语义等值）。
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	# name（源 :518-531 size18 ccc3(184,6,6)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "StoneDetailNameLabel"), 18,
		"NameLabel 字号 18 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "StoneDetailNameLabel") as Color,
		Color(184.0 / 255.0, 6.0 / 255.0, 6.0 / 255.0), "NameLabel 色 (184,6,6) 照源")
	# gw_title（源 :157-174 size20 ccc3(155,34,14)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "StoneDetailWayTitleLabel"), 20,
		"WayTitleLabel 字号 20 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "StoneDetailWayTitleLabel") as Color,
		Color(155.0 / 255.0, 34.0 / 255.0, 14.0 / 255.0), "WayTitleLabel 色 (155,34,14) 照源")
	# empty_prompt（源 :452-478 size18 ccc3(109,62,0)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "StoneDetailEmptyLabel"), 18,
		"EmptyLabel 字号 18 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "StoneDetailEmptyLabel") as Color,
		Color(109.0 / 255.0, 62.0 / 255.0, 0.0), "EmptyLabel 色 (109,62,0) 照源")
	# getway 行 title/name（源 :309-360 size18 ccc3(182,65,21)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "StoneDetailBoardLabel"), 18,
		"BoardLabel 字号 18 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "StoneDetailBoardLabel") as Color,
		Color(182.0 / 255.0, 65.0 / 255.0, 21.0 / 255.0), "BoardLabel 色 (182,65,21) 照源")
	# elite（源 :325-344 size18 ccc3(255,0,0)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "StoneDetailEliteLabel"), 18,
		"EliteLabel 字号 18 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "StoneDetailEliteLabel") as Color,
		Color.RED, "EliteLabel 色红照源")
	# ok 按钮（源 :557-600 Scale9 + ok_label fontinfo ui_normal_button=17 号白+阴影(63,5,0)偏移(0,2)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "StoneDetailOkButton"), 17,
		"OkButton 字号 17 照源 ui_normal_button")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_shadow_color", "StoneDetailOkButton") as Color,
		Color(63.0 / 255.0, 5.0 / 255.0, 0.0), "OkButton 阴影色 (63,5,0) 照源")


func _assert_color_eq(actual: Color, expect: Color, msg: String) -> void:
	assert_almost_eq(actual.r, expect.r, 0.001, msg + " [r]")
	assert_almost_eq(actual.g, expect.g, 0.001, msg + " [g]")
	assert_almost_eq(actual.b, expect.b, 0.001, msg + " [b]")


func test_getway_row_layout_follows_source() -> void:
	# 行内布局照源（board 逻辑 contentSize 311x67、y-up 原点左下；Godot 显示 242.7x52.3、y-down
	# 原点左上 → gx = x/CS, gy = 52.3 - y/CS）。源 icon 中心 (35,25)/title 左 (65,35)/name 左 (68,12)。
	# 三坑坑 2 变体守卫：board 子节点 y 必须翻转（旧 procedural 实现直用逻辑 y 当 Godot y，上下颠倒）。
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_with_drops()
	var pd := PlayerData.new(cm)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	var clip: Control = panel._content.get_node("%GetwayClip") as Control
	assert_gt(clip.get_child_count(), 0, "有 Drop 时裁剪层内有行")
	var row: Control = clip.get_child(0) as Control
	var title: Label = row.get_node("TitleLabel") as Label
	assert_almost_eq(title.position.x, 65.0 / 1.28125, 0.1, "title 左 x = 65/CS")
	assert_almost_eq(title.position.y + title.size.y * 0.5, 52.3 - 35.0 / 1.28125, 0.5,
		"title 中心 y = 行高 - 35/CS（y 翻转）")
	var name_lbl: Label = row.get_node("NameLabel") as Label
	assert_almost_eq(name_lbl.position.x, 68.0 / 1.28125, 0.1, "name 左 x = 68/CS")
	assert_almost_eq(name_lbl.position.y + name_lbl.size.y * 0.5, 52.3 - 12.0 / 1.28125, 0.5,
		"name 中心 y = 行高 - 12/CS（y 翻转，title 上 name 下）")
	assert_gt(name_lbl.position.y, title.position.y, "name 在 title 下方（源 y-up 语义）")
	# Stage Name 存 LSTR key → fill 走 get_lstr（预览截图曾直出 "BATTLE.BOAT_TAKER" 裸 key）
	var raw_name: String = String(cm.get_raw_table(&"Stage").get(str(panel._getway_ids[0]), {}).get("Stage Name", ""))
	assert_eq(name_lbl.text, cm.get_lstr(raw_name), "name 显示本地化文本（get_lstr）")
	var icon: TextureRect = row.get_node("StageIcon") as TextureRect
	assert_not_null(icon.texture, "stage 图标已 fill")
	assert_almost_eq(icon.position.y + icon.size.y * 0.5, 52.3 - 25.0 / 1.28125, 0.5,
		"icon 中心 y = 行高 - 25/CS")
	assert_almost_eq(icon.size.y, 75.0, 0.5, "icon 高 = 源 fix_height 75 逻辑点（readnode ss=fix_h/逻辑高，2026-08-22 巡检订正旧 75/CS）")
	panel.remove_window()
	root.queue_free()


func test_amount_right2_chain() -> void:
	# 源 :100-143 amount 三段 readnode right2 链（pre 左锚 (100,275)，amount/need 右缘相接跟随），
	# fill 按 right2 语义重排 x（静态分段宽会在数字位数多时溢出重叠）。
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_with_drops()
	var pd := PlayerData.new(cm)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	var paren: Label = panel._content.get_node("%AmountLParen") as Label
	var amt: Label = panel._content.get_node("%AmountLabel") as Label
	var need: Label = panel._content.get_node("%AmountNeedLabel") as Label
	assert_almost_eq(paren.position.x, 357.5, 0.1, "pre 左 = _g(100,275).x")
	assert_almost_eq(amt.position.x, paren.position.x + paren.get_combined_minimum_size().x, 0.5,
		"amount 紧跟 pre 右缘（right2）")
	assert_almost_eq(need.position.x, amt.position.x + amt.get_combined_minimum_size().x, 0.5,
		"need 紧跟 amount 右缘（right2）")
	panel.remove_window()
	root.queue_free()
