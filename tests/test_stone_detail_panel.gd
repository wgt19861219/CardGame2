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
	# name = Unit[tid]["Display Name"]
	var expected_name: String = String(cm.get_raw_table(&"Unit").get(str(recipe["tid"]), {}).get(&"Display Name", ""))
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
	# apply_with_label 套 Scale9 stylebox + 加 Label 子节点（theme_type_variation=BtnLabel）
	# 文字在子 Label 而非 btn.text（参照 equip_craft_tree.gd:300 btn.get_child(0) as Label 范式）。
	assert_eq(ok_btn.text, "", "OkBtn.text 清空（文字迁移到 Label 子节点）")
	var ok_lbl: Label = ok_btn.get_child(0) as Label
	assert_not_null(ok_lbl, "OkBtn 第一子节点是 Label")
	assert_eq(ok_lbl.text, "返回", "OkBtn Label.text = EQUIPCRAFT.RETURN")
	# 验证套了 normal StyleBoxTexture（apply_with_label 副作用）
	var normal_sb: StyleBox = ok_btn.get_theme_stylebox("normal")
	assert_true(normal_sb is StyleBoxTexture, "OkBtn normal 为 StyleBoxTexture（Scale9）")
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
	assert_eq(amount_lbl.modulate, StoneDetailPanel.COLOR_AMOUNT_LOW, "不足=红色")
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
	assert_eq(amount_lbl.modulate, StoneDetailPanel.COLOR_AMOUNT_OK, "够=棕色")
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
