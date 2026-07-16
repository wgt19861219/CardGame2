extends GutTest
# Phase 5 UI HeroDetailPanel 测试（2026-07-02）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_panel_assembles() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.level = 1
	hero.rank = 1
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	assert_not_null(panel.container, "container 创建（PopWindow）")
	# container 子节点：close + 属性 Labels + 升星按钮
	var child_count: int = panel.container.get_child_count()
	assert_gt(child_count, 0, "container 有子节点（close + 属性 + 升星）")
	panel.remove_window()
	root.queue_free()


func test_panel_shows_equip() -> void:
	var root := Node.new()
	add_child(root)
	# 无装备基线：照源 createEquipIcons 6 槽全显示（ceid=0 灰显配方 or unknown 占位）
	var hero_base := HeroInstance.new(1, 1, 1)
	var panel_base := HeroDetailPanel.new("herodetail", {})
	panel_base.setup_panel(hero_base, cm)
	panel_base.show_window(root)
	var base_slots: int = _count_equip_slots(panel_base)
	panel_base.remove_window()
	assert_eq(base_slots, 6, "无装备也显示 6 装备槽（照源 createEquipIcons）")
	# 有装备：6 槽（slot 0 已穿戴 101 + slot 1-5 灰显配方）
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = 101   # 装备 equip 101
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	assert_eq(_count_equip_slots(panel), 6, "有装备显示 6 装备槽")
	panel.remove_window()
	root.queue_free()


func _count_equip_slots(panel: HeroDetailPanel) -> int:
	var n: int = 0
	for c in panel.container.get_children():
		if c.has_meta("equip_slot"):
			n += 1
	return n


func test_evolve_signal() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var emitted: Array[bool] = [false]
	panel.evolve_requested.connect(func() -> void: emitted[0] = true)
	panel.evolve_requested.emit()
	assert_eq(emitted[0], true, "升星按钮信号")
	panel.remove_window()
	root.queue_free()


func test_split_signal() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var emitted: Array[bool] = [false]
	panel.split_requested.connect(func() -> void: emitted[0] = true)
	panel.split_requested.emit()
	assert_eq(emitted[0], true, "分解按钮信号")
	panel.remove_window()
	root.queue_free()


# perform_evolve 信号→hero_manager.evolve 闭环（碎片+金币足 → stars+1）
func test_perform_evolve_success() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id: int = mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	mgr._add_fragment(124, 100)   # Fragment[1] Fragment ID=124
	mgr.gold = 100000
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm, mgr)
	var old_stars: int = hero.stars
	var ok: bool = panel.perform_evolve()
	assert_true(ok, "perform_evolve 成功（碎片+金币足）")
	assert_eq(hero.stars, old_stars + 1, "stars+1")


func test_perform_evolve_no_mgr() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)   # 无 mgr
	assert_false(panel.perform_evolve(), "无 hero_manager → false")


# ---- 技能槽 + 升级按钮（照源 skillstren.lua createSkill）----

func test_panel_shows_skills() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7   # slot 1-4 Unlock=1/2/4/7，rank 7 全解锁
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	# rank 7 全解锁 → 4 个技能升级按钮（源 skillstren.lua:345 升级按钮图标，meta skill_upgrade）
	var upgrade_btn_count: int = 0
	for child in panel.container.get_children():
		if child.has_meta(&"skill_upgrade"):
			upgrade_btn_count += 1
	assert_eq(upgrade_btn_count, 4, "rank 7 全解锁 → 4 升级按钮")
	panel.remove_window()
	root.queue_free()


# rank 门控（照源 skillstren.lua:442 createSkillUnlockLabel：rank<Unlock 灰显+"rank X 解锁"）
func test_panel_skill_rank_gate() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 1   # 仅 slot 1（Unlock=1）解锁，slot 2/3/4 未解锁
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var upgrade_btn_count: int = 0
	var unlock_lbl_count: int = 0
	# 源 createSkillUnlockLabel :443 文案 = LSTR(HERODETAILSKILL.ADVANCED_TO__S_TO_UNLOCK) % 颜色
	var unlock_prefix: String = String(cm.get_lstr("HERODETAILSKILL.ADVANCED_TO__S_TO_UNLOCK")).split("%s")[0]
	for child in panel.container.get_children():
		if child.has_meta(&"skill_upgrade"):
			upgrade_btn_count += 1
		elif child is Label and (child as Label).text.begins_with(unlock_prefix):
			unlock_lbl_count += 1
	assert_eq(upgrade_btn_count, 1, "rank 1 仅 slot 1 解锁 → 1 升级按钮")
	assert_eq(unlock_lbl_count, 3, "slot 2/3/4 未解锁 → 3 个 rank 解锁 label")
	panel.remove_window()
	root.queue_free()


# 技能图标加载（照源 readhero.lua:1011 createSkillIcon：SkillGroup.Icon + equip_frame_white 边框）
func test_panel_skill_icon() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	# 4 边框 Sprite2D + 4 图标 TextureButton（可点击触发描述弹板）
	var frame_count: int = 0
	var icon_btn_count: int = 0
	for child in panel.container.get_children():
		if child is Sprite2D:
			frame_count += 1
		elif child is TextureButton and child.has_meta(&"skill_icon"):
			icon_btn_count += 1
	assert_eq(frame_count, 4, "4 equip_frame_white 边框")
	assert_eq(icon_btn_count, 4, "4 技能图标 TextureButton")
	panel.remove_window()
	root.queue_free()


func test_upgrade_skill_signal() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var received: Array = [-1]
	panel.upgrade_skill_requested.connect(func(idx: int) -> void: received[0] = idx)
	panel.upgrade_skill_requested.emit(2)
	assert_eq(received[0], 2, "技能升级信号带 idx")
	panel.remove_window()
	root.queue_free()


func test_perform_upgrade_skill_success() -> void:
	var pd := PlayerData.new(cm)
	pd.add_skill_point(5)
	pd.hero_manager.gold = 10000
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 5
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm, pd.hero_manager, pd)
	var old_lvl: int = hero.skill_levels[0]
	assert_true(panel.perform_upgrade_skill(0), "perform_upgrade_skill 成功")
	assert_eq(hero.skill_levels[0], old_lvl + 1, "技能等级+1")
	assert_eq(pd.skill_points, 4, "扣 1 技能点")
	assert_eq(pd.hero_manager.gold, 9900, "扣金币 100")


func test_perform_upgrade_skill_no_pd() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)   # 无 pd
	assert_false(panel.perform_upgrade_skill(0), "无 pd → false")


# 技能描述弹板（照源 skillstren.lua:14 createDescBoard：点击图标 toggle 描述）
func test_toggle_skill_desc() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	assert_null(panel._desc_label, "初始无描述")
	panel._toggle_skill_desc(0)   # 点击 slot 0 → 显示
	assert_not_null(panel._desc_label, "点击图标 → 描述 Label 创建")
	panel._toggle_skill_desc(0)   # 再点 → 隐藏
	assert_null(panel._desc_label, "再点同一 slot → 隐藏")
	panel.remove_window()
	root.queue_free()


# ---- GS 战斗力显示（照源 window.lua createInfoBoard gs label + refreshgsAfterWear）----

# GS Label 显示 hero.gs（照源 createInfoBoard:1254-1268 gs label + :1293 pregs 初始化）
func test_panel_shows_gs() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	var inst_id: int = mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm, mgr)
	panel.show_window(root)
	assert_not_null(panel._gs_label, "_gs_label 创建")
	assert_true(panel._gs_label.text.ends_with(str(hero.gs)), "GS label 显示 hero.gs")
	assert_eq(panel._pre_gs, hero.gs, "_pre_gs 初始化为 hero.gs")
	panel.remove_window()
	root.queue_free()


# refresh_gs_after_wear：gs ≠ _pre_gs → 更新 label + _pre_gs（照源 refreshgsAfterWear:170-191）
func test_refresh_gs_after_wear_updates() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	var inst_id: int = mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm, mgr)
	panel.show_window(root)
	var current_gs: int = mgr.calc_gs(hero)
	panel._pre_gs = current_gs - 1   # 模拟穿戴后 gs 已变（_pre_gs 旧 ≠ calc_gs 新）
	panel.refresh_gs_after_wear()
	# 源 gs_title LSTR("HERODETAIL.POWER_")="战力：" + gs 数字
	var expected_gs_text: String = String(cm.get_lstr("HERODETAIL.POWER_")) + str(current_gs)
	assert_eq(panel._gs_label.text, expected_gs_text, "gs ≠ _pre_gs → label 更新为 LSTR POWER + calc_gs 值")
	assert_eq(panel._pre_gs, current_gs, "_pre_gs 同步到 calc_gs")
	panel.remove_window()
	root.queue_free()


# refresh_gs_after_wear：gs == _pre_gs → 守卫不更新（照源 :172 if gs != pregs）
func test_refresh_gs_after_wear_no_change() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	var inst_id: int = mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm, mgr)
	panel.show_window(root)
	var text_before: String = panel._gs_label.text
	panel.refresh_gs_after_wear()   # setup 后 _pre_gs == calc_gs → 守卫 return
	assert_eq(panel._gs_label.text, text_before, "gs 未变 → label 不动")
	panel.remove_window()
	root.queue_free()


# ---- 底栏 tab 切换（源 createBottomButtons detail/card/skill + setOpenMode）----

# 源 createBottomButtons（window.lua:1395-1663）：detail/card/skill 三 tab 按钮常驻 base。
func test_tab_bar_three_buttons() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var tab_count: int = 0
	for c in panel.container.get_children():
		if c.has_meta(&"tab_button"):
			tab_count += 1
	assert_eq(tab_count, 3, "底栏 3 tab 按钮（detail/card/skill）")
	assert_eq(panel._tab_buttons.size(), 3, "_tab_buttons 字典 3 键")
	panel.remove_window()
	root.queue_free()


# 默认 tab = skill（照源 setOpenMode 默认行为，技能内容渲染进 container）。
func test_default_tab_skill() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7   # 全技能解锁
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	assert_eq(panel._current_tab, "skill", "默认 tab = skill")
	var upgrade_btn_count: int = 0
	for c in panel.container.get_children():
		if c.has_meta(&"skill_upgrade"):
			upgrade_btn_count += 1
	assert_eq(upgrade_btn_count, 4, "默认 skill tab → 4 升级按钮可见")
	panel.remove_window()
	root.queue_free()


# 切 detail tab → 属性 label 显示 + 技能升级按钮消失（源 doClickDetail → setOpenMode("att")）。
func test_switch_to_detail() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	panel._on_tab_pressed("detail")
	assert_eq(panel._current_tab, "detail", "切到 detail tab")
	var upgrade_btn_count: int = 0
	var attrib_lbl_count: int = 0
	for c in panel.container.get_children():
		if c.has_meta(&"skill_upgrade"):
			upgrade_btn_count += 1
		elif c is Label and (":" in (c as Label).text):
			attrib_lbl_count += 1
	assert_eq(upgrade_btn_count, 0, "detail tab 无技能升级按钮")
	assert_gt(attrib_lbl_count, 0, "detail tab 显示属性 label")
	panel.remove_window()
	root.queue_free()


# 切 card tab → 英雄卡牌立绘显示（源 doClickCard → setOpenMode("card")）。
func test_switch_to_card() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	panel._on_tab_pressed("card")
	assert_eq(panel._current_tab, "card", "切到 card tab")
	# card frame（TextureRect tab_content）+ name label 应在 container
	var card_tab_count: int = 0
	for c in panel.container.get_children():
		if c.has_meta(&"tab_content"):
			card_tab_count += 1
	assert_gt(card_tab_count, 0, "card tab 渲染了卡牌内容（frame/art/name）")
	panel.remove_window()
	root.queue_free()


# 切回 skill tab → 技能内容恢复（源 toggle：同 tab 不重复切，异 tab 切换重建）。
func test_switch_back_to_skill() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	panel._on_tab_pressed("detail")   # 先切走
	panel._on_tab_pressed("skill")    # 再切回
	assert_eq(panel._current_tab, "skill", "切回 skill tab")
	var upgrade_btn_count: int = 0
	for c in panel.container.get_children():
		if c.has_meta(&"skill_upgrade"):
			upgrade_btn_count += 1
	assert_eq(upgrade_btn_count, 4, "切回 skill → 4 升级按钮恢复")
	panel.remove_window()
	root.queue_free()


# 装备槽在 tab 切换后仍常驻（base 常显，源 createEquipIcons 在 base window）。
func test_equips_persist_across_tabs() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	panel._on_tab_pressed("card")
	var equip_count: int = 0
	for c in panel.container.get_children():
		if c.has_meta("equip_slot"):
			equip_count += 1
	assert_eq(equip_count, 6, "card tab 下装备槽仍 6 个（base 常显）")
	panel.remove_window()
	root.queue_free()
