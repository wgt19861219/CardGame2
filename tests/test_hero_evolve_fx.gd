extends GutTest
# 灵魂石进化（升星）表现链测试（照源 herodetail/window.lua doEvolveReply :783-816 补译）：
# ①双 FCA（eff_UI_herodetail_evolution_back z=100 / front z=115，源 back 默认层/front z=115）
# ②21 属性差值多条飘字（源 playAttAdditionAnim :79-134 绿字黑描边交错 0.4s）
# ③成长公告窗 HeroEvolveAnnounce（源 announce.lua heroEvolve :785-1010：三星对比+图标行）
# ④perform_evolve 集成：成功后 panel 根下出现 FCA（挂根不随 refresh_content 重建）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_host() -> Control:
	var host := Control.new()
	host.size = Vector2(800.0, 480.0)
	add_child_autofree(host)
	return host


# 双 FCA：back z=100 + front z=115（源 container.addChild(sprFront, 115)），位置=锚点
# fallback(400,215)+源 delta(-5,+10)（rootPos ccp(395,255)-createHeroFca ccp(400,265)），
# 加法混合（源 C++ FCA 加色合成）。
func test_play_evolve_effect_dual_fca() -> void:
	var host := _make_host()
	HeroDetailEvolveFx.play_evolve_effect(host, func() -> void: pass)
	var fca_nodes := host.find_children("*", "FcaAnimation", true, false)
	assert_eq(fca_nodes.size(), 2, "back+front 双 FCA 已创建")
	var z_set: Array = []
	for n in fca_nodes:
		var fca := n as FcaAnimation
		z_set.append(fca.z_index)
		assert_eq(fca.position, Vector2(400.0, 215.0) + Vector2(-5.0, 10.0),
			"FCA 位置=英雄锚点 fallback+源 delta")
		for sp in fca.find_children("*", "Sprite2D", true, false):
			var mat := (sp as Sprite2D).material as CanvasItemMaterial
			if mat != null:
				assert_eq(mat.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD, "加法混合")
	assert_has(z_set, 100, "back z=100（默认层，盖内容 z=2~16）")
	assert_has(z_set, 115, "front z=115（源 addChild z=115 直译）")


# 差值合并口径（源 getAttChanged :60-77 badd+aadd）
func test_att_delta_merges_base_add() -> void:
	var before := {"STR": {"base": 10, "add": 5}, "HP": {"base": 100, "add": 0}}
	var after := {"STR": {"base": 13, "add": 7}, "HP": {"base": 100, "add": 0}}
	assert_eq(HeroDetailEvolveFx._att_delta(before, after, "STR"), 5, "base 差+add 差=3+2")
	assert_eq(HeroDetailEvolveFx._att_delta(before, after, "HP"), 0, "无变化=0")
	assert_eq(HeroDetailEvolveFx._att_delta(before, after, "AGI"), 0, "缺键按 0 防御")


# 多条飘字：2 属性变化 → 2 条绿字 Label（名+值格式），挂 fx host（refresh 重建后存活）
func test_play_att_multi_anim_labels() -> void:
	var host := _make_host()
	var before := {"STR": {"base": 10, "add": 0}, "INT": {"base": 8, "add": 0}, "HP": {"base": 100, "add": 0}}
	var after := {"STR": {"base": 12, "add": 0}, "INT": {"base": 8, "add": 0}, "HP": {"base": 150, "add": 0}}
	HeroDetailEvolveFx.play_att_multi_anim(host, before, after, cm, self)
	var labels: Array = host.find_children("*", "Label", true, false).filter(
		func(n: Node) -> bool:
			var t: String = (n as Label).text
			return t.contains("+") and not t.begins_with("("))
	assert_eq(labels.size(), 2, "STR/HP 两属性变化 → 2 条飘字（INT 无差不飘）")
	var texts: Array = []
	for l in labels:
		var lbl := l as Label
		texts.append(lbl.text)
		assert_eq(lbl.z_index, 100, "飘字 z=100 盖内容层")
	var str_label: String = ""
	for t in texts:
		if t.contains("力量"):
			str_label = t
	assert_true(str_label.contains("+2"), "力量飘字含差值 +2（名+值格式，源 att_anim_name+v）")


# 公告窗结构：bg + close + 双图标（旧星/新星）+ 三行成长（新旧值来自 get_growth）
func test_evolve_announce_structure() -> void:
	var root := Node.new()
	add_child_autofree(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.stars = 2
	HeroEvolveAnnounce.show_announce(root, hero, {"STR": 3, "INT": 2, "AGI": 1}, cm)
	var popup := root.get_child(root.get_child_count() - 1) as HeroEvolveAnnounce
	assert_not_null(popup, "公告窗已挂 parent")
	var bg := popup.find_children("*", "NinePatchRect", true, false)
	assert_eq(bg.size(), 1, "main_vit_tips 底板")
	var close := popup.find_children("*", "TextureButton", true, false)
	assert_eq(close.size(), 1, "右上 close 按钮")
	var icons := popup.find_children("*", "ReadheroIcon", true, false)
	assert_eq(icons.size(), 2, "旧星/新星双图标对比行")
	# 成长行：三行名（含「成长」后缀）+ 三行绿增量
	var texts: Array = []
	popup.find_children("*", "Label", true, false).map(
		func(l: Node) -> void: texts.append((l as Label).text))
	var growth_rows: int = 0
	var add_rows: int = 0
	for t in texts:
		if String(t).contains("成长"):
			growth_rows += 1
		if String(t).begins_with("(") and String(t).contains("+"):
			add_rows += 1
	assert_eq(growth_rows, 3, "STR/INT/AGI 三行成长对比")
	assert_eq(add_rows, 3, "三行绿增量（源 att-preAtt.all 口径）")
	# 成长新值=get_growth(tid, stars=2)，旧值=get_growth(tid, 1)（显示经 _fmt_growth 同口径）
	var new_growth: Dictionary = ReadheroData.get_growth(1, 2, cm)
	var old_growth: Dictionary = ReadheroData.get_growth(1, 1, cm)
	var expect_new: String = HeroEvolveAnnounce._fmt_growth(float(new_growth.get("STR", 0)))
	var expect_old: String = HeroEvolveAnnounce._fmt_growth(float(old_growth.get("STR", 0)))
	var has_new: bool = false
	var has_old: bool = false
	for t in texts:
		var s := String(t)
		if not s.contains("+") and s == expect_new:
			has_new = true
		if not s.contains("+") and not s.is_empty() and s == expect_old:
			has_old = true
	assert_true(has_new and has_old, "成长行含新星值与旧星值（get_growth stars/stars-1）")


# 集成：perform_evolve 成功 → panel 根下双 FCA（挂根范式，refresh_content 重建不波及）
func test_perform_evolve_plays_fx() -> void:
	var root := Node.new()
	add_child_autofree(root)
	var mgr := HeroManager.new(cm)
	var inst_id: int = mgr.add_hero(1)
	mgr.gold = 100000
	var frag_id: int = cm.get_int(&"Fragment", 1, &"Fragment ID")
	mgr._add_fragment(frag_id, 1000)
	var hero := mgr.get_hero(inst_id)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm, mgr)
	panel.show_window(root)
	var ok: bool = panel.perform_evolve()
	assert_true(ok, "碎片/金币充足 → 进化成功")
	var fca_nodes := panel.find_children("*", "FcaAnimation", true, false)
	assert_gte(fca_nodes.size(), 2, "进化表现链双 FCA 已创建（挂 panel 根）")
	panel.remove_window()
