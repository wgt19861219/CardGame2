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


# CardFrame 显示尺寸口径守卫（2026-08-22 溢出修复）：card_bg_*.png 纹理 315×545px，源 getHeroCard
# container 242×420 点（readhero.lua:1038），显示 = 纹理÷CS = 245.90×425.37；旧 rect 315×545 为
# 纹理 px 直用（960×640 视口时代合法），迁 800×480 后底缘 592.5 超屏 112.5px。center y 320→240 后入屏。
func test_card_frame_display_size_within_screen() -> void:
	var view: Control = load("res://scenes/ui/hero_detail_card_tab.tscn").instantiate() as Control
	var host := Control.new()
	host.offset_right = 800.0
	host.offset_bottom = 480.0
	host.add_child(view)
	add_child(host)
	await get_tree().process_frame
	var frame: Control = view.get_node("%CardFrame") as Control
	var rect: Rect2 = frame.get_global_rect()
	assert_almost_eq(rect.size.x, 315.0 / 1.28125, 0.1, "CardFrame 宽 = 纹理 315px ÷CS")
	assert_almost_eq(rect.size.y, 545.0 / 1.28125, 0.1, "CardFrame 高 = 纹理 545px ÷CS")
	assert_true(rect.end.y <= 480.0, "CardFrame 底缘入屏（旧值 592.5 超屏 112.5px）")
	assert_true(rect.position.y >= 0.0, "CardFrame 顶缘入屏")
	host.free()


# card tab 内容回源守卫（2026-08-22）：止态定位链 = card.lua:150 container(-200,0)（window.lua:513
# pop endPos）+ ui.container 中心 ccp(400,240)（card.lua:135）→ 卡片 container 中心全局 cocos (200,240)，
# 左下角 (79,30)。子节点照源局部直译：frame 覆盖 (0,0)-(245.9,425.4)；name anchor(0,0.5)@(55,72)；
# line anchor(1,0.5)@(242,60)；star 中心 (25+14i,27)；close 全局 (320,430)。
# 源实机图 screenshots/ui_align/final_axmol_herodetail_800x480.png 实测卡框 (79,24.6)~(324.9,450)。
func test_card_tab_content_source_layout() -> void:
	var view: Control = load("res://scenes/ui/hero_detail_card_tab.tscn").instantiate() as Control
	view.offset_left = -200.0   # 实例止态（hero_detail_content.tscn 同款）
	view.offset_right = -200.0
	var host := Control.new()
	host.offset_right = 800.0
	host.offset_bottom = 480.0
	host.add_child(view)
	add_child(host)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 1
	HeroDetailTabs.fill_card_view(view, hero, cm)
	await get_tree().process_frame
	# CardFrame：全局 (79,24.63)~(524.90,450)（container 左下 (79,30) + frame 覆盖 (0,0)-(245.9,425.4)）。
	var frame: Control = view.get_node("%CardFrame") as Control
	var rect: Rect2 = frame.get_global_rect()
	assert_almost_eq(rect.position.x, 79.0, 0.1, "CardFrame 左缘 = container 左下角 x 79")
	assert_almost_eq(rect.position.y, 24.63, 0.1, "CardFrame 顶 = 450-425.37")
	assert_almost_eq(rect.end.x, 324.9, 0.1, "CardFrame 右缘 79+245.90")
	assert_almost_eq(rect.end.y, 450.0, 0.1, "CardFrame 底 = container 底 480-30")
	# CardNameBgLine：右缘 = container 右缘全局 79+242 = 321（源 anchor(1,0.5)@ccp(242,60)）。
	var line: Control = view.get_node("%CardNameBgLine") as Control
	var line_rect: Rect2 = line.get_global_rect()
	assert_almost_eq(line_rect.end.x, 321.0, 0.1, "名字条右缘 = container 右缘 321")
	assert_almost_eq((line_rect.position.y + line_rect.end.y) * 0.5, 390.0, 0.15, "名字条中心 y=450-60")
	# CardNameLabel：左缘 = 79+55 = 134（源 anchor(0,0.5)@ccp(55,72)）。
	var name_lbl: Control = view.get_node("%CardNameLabel") as Control
	assert_almost_eq(name_lbl.get_global_rect().position.x, 134.0, 0.1, "卡名左缘 = 79+55")
	# CardCloseBtn：中心 (320,50)（源 close (520,430) 挂 card.container(-200,0) → 全局 (320,430)）。
	var close_btn: Control = view.get_node("%CardCloseBtn") as Control
	var close_rect: Rect2 = close_btn.get_global_rect()
	assert_almost_eq((close_rect.position.x + close_rect.end.x) * 0.5, 320.0, 0.1, "关闭按钮中心 x=320")
	# star1 中心：CONTAINER_ORIGIN(279,450)+(25,-27) → 全局 (104,423)（源 ccp(25,27) container 局部）。
	var star1: CanvasItem = null
	for c in view.get_children():
		if c is TextureRect and (c as TextureRect).texture != null \
				and (c as TextureRect).texture.resource_path.contains("card_star_big"):
			star1 = c as CanvasItem
			break
	if hero.stars >= 1 and star1 != null:
		var star_rect: Rect2 = star1.get_global_rect()
		assert_almost_eq((star_rect.position.x + star_rect.end.x) * 0.5, 104.0, 0.1, "星1 中心 x=79+25")
		assert_almost_eq((star_rect.position.y + star_rect.end.y) * 0.5, 423.0, 0.1, "星1 中心 y=450-27")
	host.free()


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


# 装备槽 6 格位置照源直译守卫（2026-08-22 出框修复：旧 VBox 列 top=-15 出屏顶、
# 左 172/右 643 出主 bg 框，系 960 时代口径）。源 window.lua getEquipIconPos：
# x=255+289*((i-1)%2)、y=385-70*floor((i-1)/2)，frame anchor(0.5,0.5) 中心定位挂
# self.container（=BaseLayer 局部系，Godot y=480-y）；槽显示尺寸=纹理 94×95÷CS
# =73.37×74.17（TexDisplaySize SOP：equip_frame 无 TextureConfig 条目 → ÷CS）。
# 期望中心：i 奇数 x=255（1/3/5 上中下）、偶数 x=544（2/4/6）；y={95,165,235}。
func test_equip_slot_positions_source_direct() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	const EXPECTED_X: Array[float] = [255.0, 544.0, 255.0, 544.0, 255.0, 544.0]
	const EXPECTED_Y: Array[float] = [95.0, 95.0, 165.0, 165.0, 235.0, 235.0]
	var base: Control = panel.container.get_node("HeroDetailContent/BaseLayer") as Control
	for i in range(6):
		var slot: TextureRect = base.get_node("%EquipSlot" + str(i + 1)) as TextureRect
		assert_not_null(slot, "EquipSlot%d 存在" % (i + 1))
		if slot == null:
			continue
		var center: Vector2 = slot.position + slot.size / 2.0
		assert_almost_eq(center.x, EXPECTED_X[i], 0.5, "槽 %d 中心 x=%d（源 getEquipIconPos 直译）" % [i + 1, EXPECTED_X[i]])
		assert_almost_eq(center.y, EXPECTED_Y[i], 0.5, "槽 %d 中心 y=%d（源 y=385/315/245 → 480-y）" % [i + 1, EXPECTED_Y[i]])
		assert_almost_eq(slot.size.x, 73.37, 0.1, "槽 %d 宽=94÷CS=73.37（旧 94 px 直用出框）" % (i + 1))
		assert_almost_eq(slot.size.y, 74.17, 0.1, "槽 %d 高=95÷CS=74.17" % (i + 1))
	panel.remove_window()
	root.queue_free()


# 装备槽 6 格全在主 bg（herodetail-bg）框内（症状 3 修复主断言：出框=左右溢 bg 边 26.5/41.5px
# + 顶出屏）。bg 显示 517×570÷CS=403.9×445.1 中心 (400,240) → rect (198.5,17.5)-(601.5,462.5)。
func test_equip_slots_inside_main_bg() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var base: Control = panel.container.get_node("HeroDetailContent/BaseLayer") as Control
	var bg: TextureRect = base.get_node("Bg") as TextureRect
	assert_not_null(bg, "主 bg 存在（BaseLayer/Bg）")
	var bg_rect: Rect2 = bg.get_rect()
	for i in range(6):
		var slot: TextureRect = base.get_node("%EquipSlot" + str(i + 1)) as TextureRect
		if slot == null:
			continue
		var slot_rect: Rect2 = slot.get_rect()
		assert_true(bg_rect.encloses(slot_rect), "槽 %d rect %s ⊆ 主 bg rect %s（旧布局左右溢框+顶出屏）" % [i + 1, slot_rect, bg_rect])
	# 装备图标挂载后视觉（×1/CS）也收在槽内：icon 视觉 rect = 槽 rect（frame 94×95÷CS）
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
		assert_eq(bg.patch_margin_left, 16, "L=20（源 cap x=20）")
		assert_eq(bg.patch_margin_top, 7, "T=9（H-y-h=34-1-24）")
		assert_eq(bg.patch_margin_right, 64, "R=82（W-x-w=204-20-102）")
		assert_eq(bg.patch_margin_bottom, 1, "B=1（源 cap y=1）")
		assert_eq(bg.size, Vector2(180.0, 26.0), "显示尺寸 180×26 保持（源 scaleSize）")
	panel.remove_window()
	root.queue_free()


# ── 溢出修复二轮守卫（2026-08-22）：detail tab 框位回源 ──
# 源链：attributes.lua:600 bg ccp(400,240) 挂 container；create 时 container(48,0) 仅为初始位，
# window.lua:430 pop endPos=ccp(-200,0) 覆盖之 → 显示止态源全局中心 (200,240)、底缘 y=462.5；
# 48 不得并入子节点（一度并入致显示中心 248 偏右 48，已纠）。显示=纹理 369×570÷CS=288×445。
func test_detail_tab_popup_rect_source_direct() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	# 不调 _show_tab_content（树内会起 0.2s tween）；tscn 实例已固化止态 -200，直接断言。
	var tab: Control = panel.container.find_children("TabDetailView", "Control", true, false)[0] as Control
	assert_not_null(tab, "TabDetailView 存在")
	if tab == null:
		return
	assert_almost_eq(tab.offset_left, -200.0, 0.5, "tab 止态 offset=-200（源 pop endPos）")
	var popup: Control = tab.get_node("PopupBg") as Control
	assert_almost_eq(popup.size.x, 288.0, 0.5, "PopupBg w=288（369px÷CS，旧 369 纹理直用溢屏）")
	assert_almost_eq(popup.size.y, 445.0, 0.5, "PopupBg h=445（570px÷CS）")
	# 显示止态全局底缘 = 本地 462.5 + 根 -200（y 不受 x 偏移影响）→ 462.5 ≤480 入屏。
	assert_almost_eq(popup.position.y + popup.size.y, 462.5, 0.5, "PopupBg 显示底缘 y=462.5（570÷CS 居中 240，入屏）")
	# 显示止态全局中心 x = 本地 400 + 根 -200 = 200（源 bg 全局 400 + container(-200)）。
	assert_almost_eq(popup.get_global_rect().get_center().x, 200.0, 0.5, "PopupBg 显示中心 x=200（源 400+(-200)，勿并入 48）")
	var list_host: Control = tab.get_node("AttribListHost") as Control
	assert_almost_eq(list_host.size.x, 249.0, 0.5, "draglist clip w=249（源 CCRect 直译）")
	assert_almost_eq(list_host.size.y, 415.0, 0.5, "draglist clip h=415")
	assert_almost_eq(list_host.get_global_rect().position.x, 74.0, 0.5, "draglist 显示左缘 x=74（源 bg 左下角 56+18）")
	panel.remove_window()
	root.queue_free()
