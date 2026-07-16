extends GutTest
## 碎片合成面板测试（View 层）— 照源 fragmentcompose.lua（485 行单页弹窗）。
## 本测试聚焦 2026-07-16 LSTR 化精修：验证 setup_panel 后 _build_ui 用过的
## LSTR key（EQUIPCRAFT.SYNTHESIS / EQUIPCRAFT.SYNTHESIS_COST_ /
## FRAGMENTCOMPOSE.CONFIRM_SYNTHESIS）经 cm.get_lstr 正确解析成中文，
## 不再是旧的硬编码常量。分支逻辑（碎片/金币/已拥有校验）由 HeroManager 单测覆盖。

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
func _collect_label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect_label_texts(c, out)


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


func test_setup_panel_renders_lstr_ok_button_label() -> void:
	var root := Node.new()
	add_child(root)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_fragment(int(recipe["frag_id"]), 5)
	var panel := _make_panel(int(recipe["tid"]), pd)
	panel.show_window(root)
	# ok 按钮 = UiScale9Button.make_centered(..., cm.get_lstr("FRAGMENTCOMPOSE.CONFIRM_SYNTHESIS"))
	# （源 :459，旧硬编码 "确认合成"）。容器内查 Button 文字。
	var ok_texts: Array = []
	for c in panel.container.get_children():
		if c is Button and (c as Button).text != "":
			ok_texts.append((c as Button).text)
	assert_true(ok_texts.has(cm.get_lstr("FRAGMENTCOMPOSE.CONFIRM_SYNTHESIS")), "ok 按钮文字 = cm.get_lstr(CONFIRM_SYNTHESIS)")
	panel.remove_window()
	root.queue_free()
