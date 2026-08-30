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


func test_section_title_mark_centered_behind_label() -> void:
	## 详细属性 tab 分节标题（英雄介绍/英雄属性）装饰条叠放守卫（2026-08-30 修复回归）。
	## 源 attributes.lua:29-44 addListNode：des_title_bg 无 addHeight 游标不推进，与 des_title
	## 同 height 基准 + 同 list_center → mark 横条叠标题身后同中心（旧实现 VBox 上下两行致
	## 装饰物跑到标题顶上，且 mark 硬编码 80×12 远小于源显示 225.6×11.7）。
	var vbox := VBoxContainer.new()
	add_child_autofree(vbox)
	HeroDetailAttribs._add_section_title(vbox, &"test.section_title", "标题占位", null)
	await get_tree().process_frame
	var rows: Array = vbox.get_children()
	assert_eq(rows.size(), 1, "标题行单行（mark+label 叠放，非两行）")
	var row := rows[0] as CenterContainer
	assert_not_null(row, "标题行容器为 CenterContainer")
	if row == null:
		return
	var mark: TextureRect = null
	var lbl: Label = null
	for c in row.get_children():
		if c is TextureRect:
			mark = c as TextureRect
		elif c is Label:
			lbl = c as Label
	assert_not_null(mark, "行内含 title-mark 装饰条")
	assert_not_null(lbl, "行内含标题 Label")
	if mark == null or lbl == null:
		return
	assert_eq(lbl.text, "标题占位", "cm null 走 fallback 文本")
	assert_almost_eq(mark.size.x, 289.0 / 1.28125, 0.5, "mark 显示宽 = 289px ÷CS = 225.6pt（源直译）")
	assert_almost_eq(mark.size.y, 15.0 / 1.28125, 0.5, "mark 显示高 = 15px ÷CS = 11.7pt")
	var mark_center: Vector2 = mark.position + mark.size / 2.0
	var lbl_center: Vector2 = lbl.position + lbl.size / 2.0
	assert_almost_eq(mark_center.x, lbl_center.x, 1.0, "装饰条与标题水平同中心")
	assert_almost_eq(mark_center.y, lbl_center.y, 1.0, "装饰条与标题垂直同中心（非顶上）")


# ── 技能升级面板四修守卫（2026-08-30）：底板 9 宫格 / 图标框尺寸 / 标签对齐 / 达上限灰显 ──

# 源 skillstren.lua:814-868 board_i Scale9Sprite capInsets CCRectMake(15,15,15,15)（点单位）：
# patch = 15pt×CS(1.28125)=19.2→19（L/B）；60px 纹理点尺寸 46.83，R/T=(46.83-30)pt×CS=21.6→21。
# 旧值 12/23（÷CS 口径）把 ~20px 边框艺术切进拉伸区致变形（用户反馈"技能背景拉伸变形"）。
func test_skill_board_patch_margins_source_direct() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var skill_view: Node = panel._tab_views["skill"] as Node
	for slot in range(1, 5):
		var board: NinePatchRect = skill_view.get_node("%Skill" + str(slot) + "Board") as NinePatchRect
		assert_not_null(board, "slot%d Board 存在" % slot)
		if board == null:
			continue
		assert_eq(board.patch_margin_left, 19, "slot%d L=19（cap 15pt×CS=19.2）" % slot)
		assert_eq(board.patch_margin_bottom, 19, "slot%d B=19（cap y=15pt）" % slot)
		assert_eq(board.patch_margin_right, 21, "slot%d R=21（(46.83-30)pt×CS=21.6）" % slot)
		assert_eq(board.patch_margin_top, 21, "slot%d T=21" % slot)
		assert_almost_eq(board.size.x, 254.0, 0.5, "slot%d scaleSize 254 直译" % slot)
		assert_almost_eq(board.size.y, 86.0, 0.5, "slot%d scaleSize 86 直译" % slot)
	panel.remove_window()
	root.queue_free()


# 源 readhero.lua:1011-1022 createSkillIcon：icon=SkillGroup Icon 78×78px÷CS=60.9 中心
# ccp(320,ori_height-90(i-1))；frame=equip_frame_white 94×95px÷CS=73.4×74.2 为 icon 子节点
# @局部(30,29)（≈同中心，偏 (-0.44,+1.44)），后绘制盖 icon 上。旧 40/48 系 CS 换算遗漏（图标太小）。
func test_skill_icon_frame_size_source_direct() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var skill_view: Node = panel._tab_views["skill"] as Node
	var icon: TextureButton = skill_view.get_node("%Skill1Icon") as TextureButton
	var frame: TextureRect = skill_view.get_node("%Skill1Frame") as TextureRect
	assert_not_null(icon, "Skill1Icon 存在")
	assert_not_null(frame, "Skill1Frame 存在")
	if icon == null or frame == null:
		return
	assert_almost_eq(icon.size.x, 78.0 / 1.28125, 0.5, "icon 显示宽=78px÷CS≈60.9（旧 40）")
	assert_almost_eq(icon.size.y, 78.0 / 1.28125, 0.5, "icon 显示高=78px÷CS")
	assert_almost_eq(frame.size.x, 94.0 / 1.28125, 0.5, "frame 显示宽=94px÷CS≈73.4（旧 48）")
	assert_almost_eq(frame.size.y, 95.0 / 1.28125, 0.5, "frame 显示高=95px÷CS≈74.2")
	assert_eq(frame.z_index, 1, "frame 盖 icon 上（源 bg 为 icon 子节点后绘制）")
	var icon_center: Vector2 = icon.position + icon.size / 2.0
	var frame_center: Vector2 = frame.position + frame.size / 2.0
	assert_almost_eq(frame_center.x, icon_center.x - 0.44, 0.5, "frame 中心 x=icon 中心-0.44（源局部 30 vs 30.44）")
	assert_almost_eq(frame_center.y, icon_center.y + 1.44, 0.5, "frame 中心 y=icon 中心+1.44（源局部 29 vs 30.44 翻转）")
	# icon 中心照源 ccp(320,350) → Godot (320,130)
	assert_almost_eq(icon_center.x, 320.0, 0.5, "icon 中心 x=320（源直译）")
	assert_almost_eq(icon_center.y, 130.0, 0.5, "icon 中心 y=130（源 ccp(320,350)→480-350）")
	panel.remove_window()
	root.queue_free()


# 标签对齐照源：cost 15pt 中心锚（skillstren.lua:384-393 anchor 默认 0.5）；
# name 18pt（:422 createttf 18）；信息栏 18pt 三段组居中 @ccp(400,420)（:675-721）。
# 旧实现 Cost/SkillPointLabel 默认左对齐偏左（用户反馈"标签字段对齐方式有问题"）。
func test_skill_labels_alignment_source_direct() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var skill_view: Node = panel._tab_views["skill"] as Node
	var cost: Label = skill_view.get_node("%Skill1Cost") as Label
	assert_eq(cost.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "cost 水平居中（源中心锚）")
	assert_eq(cost.get_theme_font_size(&"font_size"), 15, "cost 15pt（源 :388 size=15）")
	var name_lbl: Label = skill_view.get_node("%Skill1Name") as Label
	assert_eq(name_lbl.get_theme_font_size(&"font_size"), 18, "name 18pt（源 :422 createttf 18）")
	assert_eq(name_lbl.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "name 左对齐（源 anchor(0,0.5)）")
	var sp: Label = skill_view.get_node("%SkillPointLabel") as Label
	assert_eq(sp.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "技能点信息栏居中（源三段组居中 @400）")
	assert_eq(sp.get_theme_font_size(&"font_size"), 18, "信息栏 18pt（源 :689/699/713 size=18）")
	panel.remove_window()
	root.queue_free()


# 源 refreshLevelBoard:256-263：cacheSkillLevel >= hero._level → setSpriteGray（升级按钮灰显）。
# 用户反馈"加点完全无法加"根因之一：1 级英雄技能达上限静默拒绝无任何视觉/提示（port 缺灰显+Toast）。
func test_skill_btn_gray_at_level_cap() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	hero.level = 1   # skill_levels[0]=1 >= 1 → 达上限
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var btn: TextureButton = (panel._tab_views["skill"] as Node).get_node("%Skill1Btn") as TextureButton
	assert_eq(btn.modulate, HeroDetailTabs.SKILL_GRAY_MODULATE, "1 级英雄 slot1 达上限 → 按钮灰显")
	panel.remove_window()
	root.queue_free()
	# 反例：hero level 5 → 未达上限白显
	var root2 := Node.new()
	add_child(root2)
	var hero2 := HeroInstance.new(1, 1, 1)
	hero2.rank = 7
	hero2.level = 5
	var panel2 := HeroDetailPanel.new("herodetail", {})
	panel2.setup_panel(hero2, cm)
	panel2.show_window(root2)
	var btn2: TextureButton = (panel2._tab_views["skill"] as Node).get_node("%Skill1Btn") as TextureButton
	assert_eq(btn2.modulate, Color.WHITE, "5 级英雄 slot1（lv1<5）→ 按钮白显可点")
	panel2.remove_window()
	root2.queue_free()


# 达上限 perform 失败 → Toast「已达到当前等级上限」（源 doClickLvupButton:155-156，2026-08-30 补静默缺失）。
func test_perform_upgrade_skill_cap_fail_toast() -> void:
	var pd := PlayerData.new(cm)
	pd.skill_points = 5
	pd.hero_manager.gold = 10000
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 1   # InitLevel=1 >= 1 → 达上限
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm, pd.hero_manager, pd)
	Toast._queue.clear()
	assert_false(panel.perform_upgrade_skill(0), "1 级达上限 → 升级失败")
	assert_eq(hero.skill_levels[0], 1, "等级不变")
	assert_eq(pd.skill_points, 5, "技能点未扣")
	assert_eq(pd.hero_manager.gold, 10000, "金币未扣")
	assert_gt(Toast.pending_count(), 0, "失败有 Toast 反馈（旧实现静默）")
	Toast._queue.clear()


# 技能点不足失败分支 Toast（源 :164-165 herodetailskill.1.10.1.002「技能点已用完」）。
func test_perform_upgrade_skill_no_point_toast() -> void:
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	pd.hero_manager.gold = 10000
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 5   # 未达上限，有金币，仅缺技能点
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm, pd.hero_manager, pd)
	Toast._queue.clear()
	assert_false(panel.perform_upgrade_skill(0), "技能点不足 → 升级失败")
	assert_gt(Toast.pending_count(), 0, "技能点不足有 Toast 反馈")
	Toast._queue.clear()


# levelAdd "+N" 动态贴 lv 文字右侧 +2（源 skillstren.lua:335 getRightSidePos(lui.level, 2)；
# 旧静态 397 在 lv.10 时与 lv 文字叠字）。纯单元：两 Label 直调 _fill_skill_lvl_add。
func test_lvl_add_dynamic_position() -> void:
	var lvl := Label.new()
	lvl.text = "lv.10"
	var add_lbl := Label.new()
	add_lbl.position = Vector2(397.0, 125.0)   # 旧静态位
	HeroDetailUpgradeFx._fill_skill_lvl_add(add_lbl, 5, lvl)
	assert_eq(add_lbl.text, "+5", "levelAdd 文本 +N")
	assert_true(add_lbl.visible, "skl_add>0 → 可见")
	assert_almost_eq(add_lbl.position.x, lvl.position.x + lvl.get_minimum_size().x + 2.0, 0.1,
		"levelAdd x = lv 文字右缘+2（源 getRightSidePos）")
	assert_almost_eq(add_lbl.position.y, lvl.position.y, 0.1, "levelAdd y 与 lv 同行")
	HeroDetailUpgradeFx._fill_skill_lvl_add(add_lbl, 0, lvl)
	assert_false(add_lbl.visible, "skl_add=0 → 隐藏")


# ── 购买技能点按钮可点击 + 重建不重播侧滑守卫（2026-08-30 二轮修复）──

# 购买键曾 mouse_filter=2（IGNORE）+ 无 ignore_texture_size：真实点击穿透到面板 shade 吞掉
# （购买从未执行），且按钮被 97×67 纹理原尺寸撑大压首行技能。源 createcdBar:592-620
# herodetail-upgrade.png 97×67px÷CS=75.7×52.3 中心 ccp(325,420)。
func test_buy_skill_point_btn_clickable_and_sized() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var btn: TextureButton = (panel._tab_views["skill"] as Node).get_node("%BuySkillPointBtn") as TextureButton
	assert_ne(btn.mouse_filter, Control.MOUSE_FILTER_IGNORE, "购买键不可 IGNORE（真实点击须可达）")
	assert_true(btn.ignore_texture_size, "ignore_texture_size（防纹理原尺寸撑大）")
	assert_almost_eq(btn.size.x, 76.0, 0.5, "购买键宽=97px÷CS≈75.7（tscn offsets 直译 76）")
	assert_almost_eq(btn.size.y, 52.0, 0.5, "购买键高=67px÷CS≈52.3（tscn offsets 直译 52）")
	panel.remove_window()
	root.queue_free()


# 购买键「购买」Label（源 skillstren.lua:611-620 cdButtonLabel：T(LSTR("EQUIPINFO.PURCHASE"))
# 18pt @按钮局部中心 (42,25)（cocos 锚 0.5,0.5 → y 翻转 52-25=27）；结构性新增曾受红线约束
# 遗留编辑器会话，2026-08-30 经 godot-mcp 补齐。
func test_buy_skill_point_btn_label() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var btn: TextureButton = (panel._tab_views["skill"] as Node).get_node("%BuySkillPointBtn") as TextureButton
	var lbl: Label = btn.get_node_or_null("BuySkillPointLabel") as Label
	assert_not_null(lbl, "购买键有「购买」Label 子节点（源 cdButtonLabel）")
	if lbl != null:
		assert_eq(lbl.text, "购买", "Label 文本=购买（EQUIPINFO.PURCHASE）")
		assert_eq(lbl.get_theme_font_size("font_size"), 18, "18pt 照源")
		assert_eq(lbl.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "水平居中")
		assert_eq(lbl.vertical_alignment, VERTICAL_ALIGNMENT_CENTER, "垂直居中")
		assert_almost_eq((lbl.offset_left + lbl.offset_right) / 2.0, 42.0, 0.5,
			"Label 中心 x=42（源 ccp(42,·)）")
		assert_almost_eq((lbl.offset_top + lbl.offset_bottom) / 2.0, 27.0, 0.5,
			"Label 中心 y=27（源 25 → y 翻转 52-25）")
		assert_eq(lbl.mouse_filter, Control.MOUSE_FILTER_IGNORE, "装饰 Label 不吞按钮点击")
	panel.remove_window()
	root.queue_free()


# 滑入反馈按来源区分（2026-08-30 七轮用户定谳：仅升级技能要滑动反馈，装备/进阶/翻页等
# 其余 refresh_content 刷新不滑）。升级路径=hero_package 接线 refresh_content(true)。
func test_rebuild_slide_only_on_upgrade_path() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	panel._show_tab_content("skill")
	hero.level = 10
	# ① 默认刷新（装备穿戴等）→ 不重播滑入
	panel.refresh_content()
	await get_tree().create_timer(0.1).timeout   # deferred 重建完成
	var sv_a: Control = panel._tab_views["skill"] as Control
	assert_almost_eq(sv_a.offset_left, -200.0, 0.5, "默认刷新止态直设（装备等不滑）")
	assert_eq(panel._current_tab, "skill", "重建保持当前 tab")
	# ①b 重建后 base 层止态直设（旧实现新 BaseLayer 从 0 起 tween→整界面右挫 ~140px，
	# 用户录屏逐帧互相关实锤 -70~-95px→0 位移，2026-08-30 十一轮）
	assert_almost_eq(panel._base_layer.position.x, 140.0, 0.5, "重建后 base 立即 140（无 0 起点滑动）")
	# ② 升级路径 refresh_content(true) → 重播滑入（400 起跳→-200 止态）
	panel.refresh_content(true)
	await get_tree().create_timer(0.1).timeout   # deferred 重建+tween 已起步
	var sv_b: Control = panel._tab_views["skill"] as Control
	assert_gt(sv_b.offset_left, -150.0, "升级路径重建滑入中（0.1s 处未到止态 -200 即在滑）")
	await get_tree().create_timer(0.3).timeout
	assert_almost_eq((panel._tab_views["skill"] as Control).offset_left, -200.0, 0.5,
		"0.4s 后滑入止态 -200")
	panel.remove_window()
	root.queue_free()


# 描述浮层位置随槽下移（源 createDescBoard :23-25 ccp(525, 387-90*(i-1))；旧固定 (400,100)
# = 点低槽浮层跑到首行「力量强化说明放到幽灵船上」错位，2026-08-30 修）。
func test_skill_desc_board_position_follows_slot() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	for slot in range(4):
		var bg: Control = HeroDetailTabs.build_skill_desc(hero, slot, cm)
		assert_almost_eq(bg.position.x, 525.0, 0.5, "slot%d x=525（源直译）" % slot)
		assert_almost_eq(bg.position.y, 93.0 + 90.0 * slot, 0.5,
			"slot%d y=93+90×slot 随槽下移（源 387-90×i 翻转）" % slot)
		bg.free()
