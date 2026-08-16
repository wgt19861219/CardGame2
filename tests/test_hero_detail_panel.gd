extends GutTest
# Phase 5 UI HeroDetailPanel 测试（2026-07-02，Phase A+B .tscn 重构 2026-07-17）。

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
	# container 子节点：content（.tscn root，含 BaseLayer + 3 tab view）
	var child_count: int = panel.container.get_child_count()
	assert_gt(child_count, 0, "container 有子节点（content）")
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
	# base 层从 .tscn instantiate（container → content → %BaseLayer → %EquipSlotHost → icon），递归扫全子树。
	return _count_meta_recursive(panel.container, "equip_slot")


func _count_meta_recursive(node: Node, meta_key: String) -> int:
	var n: int = 1 if node.has_meta(meta_key) else 0
	for c in node.get_children():
		n += _count_meta_recursive(c, meta_key)
	return n


# 通用递归计数（按谓词，含类型判断）。Phase B tab 内容常驻（visible 切换），扫描需递归 + 可按类型/meta。
func _count_if_recursive(node: Node, fn: Callable) -> int:
	var n: int = 1 if fn.call(node) else 0
	for c in node.get_children():
		n += _count_if_recursive(c, fn)
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
	panel._show_tab_content("skill")   # Phase B 只切 visible，skill 内容已在 _build_content fill
	# rank 7 全解锁 → 4 个技能升级按钮（源 skillstren.lua:345 升级按钮图标，meta skill_upgrade）
	# Phase B：skill 内容常驻 %SkillListHost，递归扫全子树。
	var upgrade_btn_count: int = _count_meta_recursive(panel.container, "skill_upgrade")
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
	panel._show_tab_content("skill")
	var upgrade_btn_count: int = _count_meta_recursive(panel.container, "skill_upgrade")
	# 源 createSkillUnlockLabel :443 文案 = LSTR(HERODETAILSKILL.ADVANCED_TO__S_TO_UNLOCK) % 颜色
	var unlock_prefix: String = String(cm.get_lstr("HERODETAILSKILL.ADVANCED_TO__S_TO_UNLOCK")).split("%s")[0]
	var unlock_lbl_count: int = _count_if_recursive(panel.container, func(n: Node) -> bool:
		return n is Label and (n as Label).text.begins_with(unlock_prefix))
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
	panel._show_tab_content("skill")
	# 4 边框 TextureRect（%Skill1Frame..%Skill4Frame）+ 4 图标 TextureButton（meta skill_icon）。
	# 静态化后 frame 是 TextureRect（非 Sprite2D），按 unique name 数 %Skill{1..4}Frame。
	var frame_count: int = 0
	for slot in range(1, 5):
		if (panel._tab_views["skill"] as Node).has_node("%Skill" + str(slot) + "Frame"):
			frame_count += 1
	var icon_btn_count: int = _count_meta_recursive(panel._tab_views["skill"] as Node, "skill_icon")
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
	pd.skill_points = 0   # 重置初始 5（A7 默认值）以独立验证 add+consume 语义
	SkillPointManager.add(pd, 5)
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
	# 源 gs 数字独立 label（gs_title"战力:"独立 label，refreshgsLabel:1175 text=hero._gs 纯数字）
	var expected_gs_text: String = str(current_gs)
	assert_eq(panel._gs_label.text, expected_gs_text, "gs ≠ _pre_gs → label 更新为 calc_gs 数字（title 独立）")
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
	# Phase A：tab 按钮静态化进 .tscn %TabBtn（container → content → %BaseLayer → %TabBtn），递归扫。
	var tab_count: int = _count_meta_recursive(panel.container, "tab_button")
	assert_eq(tab_count, 3, "底栏 3 tab 按钮（detail/card/skill）")
	assert_eq(panel._tab_buttons.size(), 3, "_tab_buttons 字典 3 键")
	panel.remove_window()
	root.queue_free()


# 默认 tab = card 图鉴（用户指示 2026-07-17；源默认 setOpenMode(nil)=doMoveBack 无 tab，用户要进显图鉴）。
# Phase B：tab view visible 切换，查 _tab_views["card"].visible + CardFrame texture fill。
func test_default_tab_card() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	assert_eq(panel._current_tab, "card", "默认 tab = card")
	assert_true((panel._tab_views["card"] as CanvasItem).visible, "card view visible")
	var card_frame: TextureRect = (panel._tab_views["card"] as Control).get_node("%CardFrame") as TextureRect
	assert_not_null(card_frame.texture, "默认 card tab → CardFrame texture fill（card 内容渲染）")
	panel.remove_window()
	root.queue_free()


# 切 detail tab → detail view visible + skill view hidden + 属性 label 显示（源 doClickDetail → setOpenMode("att")）。
# Phase B：tab 内容常驻（不 free），切 tab 只切 visible，故查 visible + 各 view 子树内容。
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
	assert_true((panel._tab_views["detail"] as CanvasItem).visible, "detail view visible")
	assert_false((panel._tab_views["skill"] as CanvasItem).visible, "skill view hidden（切走）")
	var attrib_lbl_count: int = _count_if_recursive(panel._tab_views["detail"] as Node, func(n: Node) -> bool:
		return n is Label and ":" in (n as Label).text)
	assert_gt(attrib_lbl_count, 0, "detail view 显示属性 label")
	panel.remove_window()
	root.queue_free()


# 切 card tab → card view visible + CardFrame texture（源 doClickCard → setOpenMode("card")）。
func test_switch_to_card() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	panel._on_tab_pressed("detail")   # 默认 card，先切走
	panel._on_tab_pressed("card")   # 再切回 card（异 tab 切换）
	assert_eq(panel._current_tab, "card", "切到 card tab")
	assert_true((panel._tab_views["card"] as CanvasItem).visible, "card view visible")
	var card_frame: TextureRect = (panel._tab_views["card"] as Control).get_node("%CardFrame") as TextureRect
	assert_not_null(card_frame.texture, "card tab → CardFrame texture（card 内容渲染）")
	panel.remove_window()
	root.queue_free()


# 切回 skill tab → skill view visible + 4 升级按钮（Phase B 内容常驻，visible 切换不丢）。
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
	assert_true((panel._tab_views["skill"] as CanvasItem).visible, "skill view visible")
	var upgrade_btn_count: int = _count_meta_recursive(panel._tab_views["skill"] as Node, "skill_upgrade")
	assert_eq(upgrade_btn_count, 4, "切回 skill → 4 升级按钮（内容常驻不丢）")
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
	# Phase A：装备挂 %EquipSlotHost（base 子树），递归扫全子树。
	var equip_count: int = _count_meta_recursive(panel.container, "equip_slot")
	assert_eq(equip_count, 6, "card tab 下装备槽仍 6 个（base 常显，挂 %EquipSlotHost）")
	panel.remove_window()
	root.queue_free()


# StoneBarBg 九宫格守卫（批 2 Task 8 复检 B 类修复）：源 herodetail/window.lua:2192
# stone_bar_bg Scale9Sprite capInsets CCRectMake(20,1,102,24) scaleSize(180,26)，
# 贴图 heropackage_soulstone_progress_bg 204×34 PIL 实测
# → L20/T=34-1-24=9/R=204-20-102=82/B1（批 1 fde903b 公式；旧 TextureRect 整图强拉 180×26 ratio 失真 15%）。
func test_stone_bar_bg_ninepatch_margins() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var bg: NinePatchRect = panel.container.find_children("StoneBarBg", "NinePatchRect", true, false)[0] as NinePatchRect
	assert_not_null(bg, "StoneBarBg 为 NinePatchRect（源 Scale9Sprite）")
	if bg != null:
		assert_eq(bg.patch_margin_left, 20, "L=20（源 cap x=20）")
		assert_eq(bg.patch_margin_top, 9, "T=9（H-y-h=34-1-24）")
		assert_eq(bg.patch_margin_right, 82, "R=82（W-x-w=204-20-102）")
		assert_eq(bg.patch_margin_bottom, 1, "B=1（源 cap y=1）")
		assert_eq(bg.size, Vector2(180.0, 26.0), "显示尺寸 180×26 保持（源 scaleSize）")
	panel.remove_window()
	root.queue_free()
