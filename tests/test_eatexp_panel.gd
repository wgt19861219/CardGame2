extends GutTest
# Phase 6 eatexplist 弹窗测试（2026-07-05 第 27 段）。
# 照源 eatexplist.lua create + doEat。单机化：去 doSendConsume 网络，即时扣物品+加经验。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 找一个 EXPERIENCE_PILL 物品（Category=CONSUMABLES + Consume Type=EXPERIENCE_PILL + Exp>0）。
func _find_exp_pill() -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		var row: Dictionary = raw[tid_str]
		if String(row.get("Category", "")) == "EQUIP.CONSUMABLES" \
				and String(row.get("Consume Type", "")) == "EQUIP.EXPERIENCE_PILL" \
				and int(row.get("Exp", 0)) > 0:
			return int(tid_str)
	return 0


# Levels 表最大 key（末位等级），+1 即超表触发满级判定。
func _levels_max_key() -> int:
	var levels: Dictionary = cm.get_raw_table(&"Levels")
	var max_k: int = 1
	for k in levels:
		max_k = max(max_k, int(k))
	return max_k


func test_setup_builds_frame() -> void:
	var pill_id: int = _find_exp_pill()
	assert_gt(pill_id, 0, "存在 EXPERIENCE_PILL 物品")
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 1)
	pd.hero_manager.add_hero(1)
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "frame 已建（container 有子）")
	panel.remove_window()
	root.queue_free()


func test_close_removes_window() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(_find_exp_pill(), 1)
	pd.hero_manager.add_hero(1)
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(_find_exp_pill(), cm, pd)
	panel.show_window(root)
	panel._on_close_pressed()
	await get_tree().process_frame
	assert_false(is_instance_valid(panel), "close 后 panel 销毁")
	if is_instance_valid(root):
		root.queue_free()


# do_eat_hero 即时扣物品 + 加经验（单机化，无网络延迟）。
func test_do_eat_consumes_item_and_adds_exp() -> void:
	var pill_id: int = _find_exp_pill()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 3)
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	var olevel: int = hero.level
	var oexp: int = hero.exp
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(root)
	panel.do_eat_hero(inst_id)
	assert_eq(int(pd.items.get(pill_id, 0)), 2, "扣 1 物品")
	var exp_added: bool = hero.level > olevel or hero.exp > oexp
	assert_true(exp_added, "经验增加（升级或当级 exp 增）")
	panel.remove_window()
	root.queue_free()


# 满级英雄（Levels 末位 +1）不喂药（源 isExpMax 拦截）。
func test_do_eat_blocked_when_max_level() -> void:
	var pill_id: int = _find_exp_pill()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 3)
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	hero.level = _levels_max_key() + 1   # 超 Levels 表 → _levelup_exp<=0 → 满级
	var oexp: int = hero.exp
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(root)
	panel.do_eat_hero(inst_id)
	assert_eq(int(pd.items.get(pill_id, 0)), 3, "满级不扣物品")
	assert_eq(hero.exp, oexp, "满级不加经验")
	panel.remove_window()
	root.queue_free()


# 持有量耗尽（源 useProp amount 上限拦截）。
func test_do_eat_blocked_when_no_item() -> void:
	var pill_id: int = _find_exp_pill()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)   # 不 add_item，持有量=0
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	var oexp: int = hero.exp
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(root)
	panel.do_eat_hero(inst_id)
	assert_eq(int(pd.items.get(pill_id, 0)), 0, "持有量 0")
	assert_eq(hero.exp, oexp, "无物品不加经验")
	panel.remove_window()
	root.queue_free()


# EquipboardPanel consume 右按钮 → 弹 EatexpPanel（第 27 段接 use）。
func test_equipboard_consume_opens_eatexp() -> void:
	var pill_id: int = _find_exp_pill()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var cell: Dictionary = {"id": pill_id, "makeId": pill_id, "amount": 1, "category": "EQUIP.CONSUMABLES", "type": 1}
	var board := EquipboardPanel.new("equipboard", {})
	board.setup_panel(cell, cm, pd)
	board.show_window(root)
	board._on_right_pressed()   # consume → _open_eatexp
	var has_eatexp: bool = false
	for c in root.get_children():
		if c is EatexpPanel:
			has_eatexp = true
			c.queue_free()
			break
	assert_true(has_eatexp, "EquipboardPanel consume 右按钮弹 EatexpPanel")
	board.remove_window()
	root.queue_free()


# 2026-07-16 LSTR 化：title 经 _T 解析为当前语言（源 create title LSTR(EATEXPLIST.CHOOSE_A_HERO)）
func test_title_lstr_resolved() -> void:
	var pill_id: int = _find_exp_pill()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 1)
	pd.hero_manager.add_hero(1)
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(root)
	var title: String = panel._T(EatexpPanel.LSTR_TITLE)
	assert_ne(title, "", "EATEXPLIST.CHOOSE_A_HERO LSTR 解析非空")
	assert_ne(title, EatexpPanel.LSTR_TITLE, "LSTR 解析为译文非 key 回显")
	panel.remove_window()
	root.queue_free()


# 源 useProp :8 equip[id].Name LSTR 解析（经验药物品名，单机化 _equip_name 包装）
func test_equip_name_resolved() -> void:
	var pill_id: int = _find_exp_pill()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 1)
	pd.hero_manager.add_hero(1)
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(root)
	var name_text: String = panel._equip_name()
	assert_ne(name_text, "", "_equip_name 经验药名字非空（Equip.Name LSTR 解析）")
	panel.remove_window()
	root.queue_free()


# ── 两件套守卫（批 1 Task 3，2026-08-15）：框架照源直译 + 行模板 + theme variation + 零静态 .new() ──

const CS: float = 1.28125


func _instantiate_content() -> Control:
	var scene: PackedScene = load("res://scenes/ui/eatexp_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


func _make_eatexp_panel(pill_id: int, p_pd: PlayerData) -> EatexpPanel:
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, p_pd)
	return panel


func _assert_color_eq(actual: Color, expect: Color, msg: String) -> void:
	assert_almost_eq(actual.r, expect.r, 0.001, msg + " [r]")
	assert_almost_eq(actual.g, expect.g, 0.001, msg + " [g]")
	assert_almost_eq(actual.b, expect.b, 0.001, msg + " [b]")


func test_lstr_prompt_resolves() -> void:
	# 源 prompt LSTR key（eatexplist.lua:179，迁移期漏译本批补全）
	assert_eq(cm.get_lstr("eatexplist.1.10.1.001"), "长按英雄头像即可快速使用经验丹", "prompt LSTR 解析")


func test_content_frame_layout_follows_source() -> void:
	# 框架照源 eatexplist.lua create(:33-111) 直译。frame package_herolist_bg(700x485)
	# fix_wh={h=345}（readnode setConfig :215-218 只 setScaleY）→ 宽不变=纹理/CS、高=345，
	# 中心 to_godot(400,215)=(480,345)；title_bg 中心 (480,161)；title_bg_1/title 中心 (480,181)；
	# close 中心 (748,200)；列表区=源 draglist rect(120,55,570,320) 触摸区 + cliprect 垂直界。
	var inst: Control = _instantiate_content()
	var bg: TextureRect = inst.get_node("Bg") as TextureRect
	assert_almost_eq((bg.offset_left + bg.offset_right) / 2.0, 480.0, 0.5, "frame 中心 x=480")
	assert_almost_eq((bg.offset_top + bg.offset_bottom) / 2.0, 345.0, 0.5, "frame 中心 y=345")
	assert_almost_eq(bg.offset_right - bg.offset_left, 700.0 / CS, 0.5, "frame 宽=纹理/CS（fix_wh 只缩 Y）")
	assert_almost_eq(bg.offset_bottom - bg.offset_top, 345.0, 0.5, "frame 高=源 fix_wh h=345")
	var tbg: TextureRect = inst.get_node("TitleBg") as TextureRect
	assert_almost_eq((tbg.offset_left + tbg.offset_right) / 2.0, 480.0, 0.5, "title_bg 中心 x=480")
	assert_almost_eq((tbg.offset_top + tbg.offset_bottom) / 2.0, 161.0, 0.5, "title_bg 中心 y=161")
	var tbg1: TextureRect = inst.get_node("TitleBg1") as TextureRect
	assert_almost_eq((tbg1.offset_left + tbg1.offset_right) / 2.0, 480.0, 0.5, "title_bg_1 中心 x=480")
	assert_almost_eq((tbg1.offset_top + tbg1.offset_bottom) / 2.0, 181.0, 0.5, "title_bg_1 中心 y=181")
	var close: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq((close.offset_left + close.offset_right) / 2.0, 748.0, 0.5, "close 中心 x=748")
	assert_almost_eq((close.offset_top + close.offset_bottom) / 2.0, 200.0, 0.5, "close 中心 y=200")
	var scroll: ScrollContainer = inst.get_node("%ScrollHost") as ScrollContainer
	assert_almost_eq(scroll.offset_left, 200.0, 0.5, "scroll 左=源触摸 rect x=120+80")
	assert_almost_eq(scroll.offset_right, 770.0, 0.5, "scroll 右=源触摸 rect 右 690+80")
	assert_almost_eq(scroll.offset_top, 185.0, 0.5, "scroll 顶=源 cliprect 上沿 y=375→185")
	assert_almost_eq(scroll.offset_bottom, 505.0, 0.5, "scroll 底=源 cliprect 下沿 y=55→505")
	assert_eq(scroll.horizontal_scroll_mode, 0, "水平不滚动（源列表仅纵向）")


func test_content_title_variation() -> void:
	# 源 title fontinfo ui_normal_button + size=24 + ccc3(250,205,16)
	# → EatexpTitleLabel variation（数值断言走 theme 表项：GUT 节点级不解析 variation）。
	var inst: Control = _instantiate_content()
	var title: Label = inst.get_node("%TitleLabel") as Label
	assert_not_null(title, "标题常驻 tscn")
	assert_eq(title.theme_type_variation, &"EatexpTitleLabel", "标题走 EatexpTitleLabel")
	assert_false(title.has_theme_color_override("font_color"), "标题无 font_color override")
	assert_false(title.has_theme_font_size_override("font_size"), "标题无 font_size override")
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EatexpTitleLabel"), 24,
		"标题字号 24 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EatexpTitleLabel") as Color,
		Color(250.0 / 255.0, 205.0 / 255.0, 16.0 / 255.0), "标题金色 (250,205,16) 照源")


func test_prompt_row_filled_with_item_name() -> void:
	# 源 createList :176-185 prompt Label（"长按英雄头像…" + 物品名）挂 listLayer 顶部，
	# 中心全屏 (480,230) → ListHost 局部 (280,45)。迁移期漏译，本批补全。
	var root := Node.new()
	add_child(root)
	var pill_id: int = _find_exp_pill()
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 1)
	pd.hero_manager.add_hero(1)
	var panel := _make_eatexp_panel(pill_id, pd)
	panel.show_window(root)
	var prompt: Label = panel._content.get_node("%PromptLabel")
	assert_eq(prompt.text, "%s %s" % [cm.get_lstr("eatexplist.1.10.1.001"), panel._equip_name()],
		"prompt=LSTR+空格+物品名")
	assert_almost_eq((prompt.offset_left + prompt.offset_right) / 2.0, 280.0, 0.5,
		"prompt 中心 x=280（全屏 480）")
	assert_almost_eq((prompt.offset_top + prompt.offset_bottom) / 2.0, 45.0, 0.5,
		"prompt 中心 y=45（全屏 230）")
	panel.remove_window()
	root.queue_free()


func test_item_template_static_tree() -> void:
	# 行模板照源 createHero(:204-302)：bg package_hero_bg(313x123)→显示 244.4x96；
	# 满级三件（fullBar fix 145x20 / 整行 shade / "经验已满"标签）与 rank 星后缀常驻默认隐藏。
	var scene: PackedScene = load("res://scenes/ui/eatexp_item.tscn") as PackedScene
	assert_not_null(scene, "行模板 tscn 存在")
	if scene == null:
		return
	var item: Control = scene.instantiate() as Control
	add_child_autofree(item)
	assert_almost_eq(item.custom_minimum_size.x, 313.0 / CS, 0.1, "行宽=package_hero_bg/CS")
	assert_almost_eq(item.custom_minimum_size.y, 123.0 / CS, 0.1, "行高=package_hero_bg/CS")
	for path in ["Bg", "HeadHost", "ExpBarBg", "ExpBar", "ExpFullBar", "LevelLabel", "NameLabel",
			"SuffixLabel", "MarkRect", "MaxShade", "ShadeLabel"]:
		assert_not_null(item.get_node_or_null(path), "行模板 " + path + " 常驻")
	assert_not_null((item.get_node("Bg") as TextureRect).texture, "Bg 贴图接线")
	assert_not_null((item.get_node("ExpBarBg") as TextureRect).texture, "ExpBarBg 贴图接线")
	assert_not_null((item.get_node("ExpBar") as TextureRect).texture, "ExpBar 贴图接线")
	assert_not_null((item.get_node("ExpFullBar") as TextureRect).texture, "ExpFullBar 贴图接线")
	assert_not_null((item.get_node("MaxShade") as TextureRect).texture, "MaxShade 贴图接线")
	assert_false((item.get_node("ExpFullBar") as TextureRect).visible, "ExpFullBar 默认隐藏（满级 fill 显示）")
	assert_false((item.get_node("MaxShade") as TextureRect).visible, "MaxShade 默认隐藏")
	assert_false((item.get_node("ShadeLabel") as Label).visible, "ShadeLabel 默认隐藏")
	assert_false((item.get_node("SuffixLabel") as Label).visible, "SuffixLabel 默认隐藏（rank 星>0 时 fill 显示）")
	assert_eq((item.get_node("LevelLabel") as Label).theme_type_variation, &"EatexpHeroLevelLabel",
		"level 走 EatexpHeroLevelLabel")
	assert_eq((item.get_node("NameLabel") as Label).theme_type_variation, &"EatexpHeroNameLabel",
		"name 走 EatexpHeroNameLabel")
	assert_eq((item.get_node("SuffixLabel") as Label).theme_type_variation, &"EatexpHeroNameLabel",
		"suffix 走 EatexpHeroNameLabel（色 fill 动态 override）")
	assert_eq((item.get_node("ShadeLabel") as Label).theme_type_variation, &"EatexpShadeLabel",
		"shade 标签走 EatexpShadeLabel")


func test_row_layout_follows_source() -> void:
	# 行内坐标照源 createHero（bg 局部 cocos y-up 左下原点 → Godot y-down：gy=96-y）：
	# head anchor(0,0) at (7,9)→左上(7,-17)；level anchor(0,0.5) at (96,40)；name 右端 178 中心 y72；
	# mark 中心 (110,72) scale0.8；expBarBg 中心 (162,20)；expBar anchor(0,0.5) at (93.5,20)。
	var root := Node.new()
	add_child(root)
	var pill_id: int = _find_exp_pill()
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 1)
	pd.hero_manager.add_hero(1)
	var panel := _make_eatexp_panel(pill_id, pd)
	panel.show_window(root)
	var grid: GridContainer = panel._content.get_node("%Grid")
	assert_gt(grid.get_child_count(), 0, "有英雄行")
	var row: Control = grid.get_child(0) as Control
	var level: Label = row.get_node("LevelLabel") as Label
	assert_almost_eq(level.position.x, 96.0, 0.5, "level 左端 x=96")
	assert_almost_eq(level.position.y + level.size.y * 0.5, 96.0 - 40.0, 1.0, "level 中心 y=96-40")
	var bar: TextureRect = row.get_node("ExpBar") as TextureRect
	assert_almost_eq(bar.position.x, 93.5, 0.5, "bar 左端 x=93.5")
	assert_almost_eq(bar.position.y + bar.size.y * 0.5, 96.0 - 20.0, 1.0, "bar 中心 y=96-20")
	assert_almost_eq(bar.pivot_offset.x, 0.0, 0.01, "bar pivot 左端（源 scalexy 从左缩）")
	var bar_bg: TextureRect = row.get_node("ExpBarBg") as TextureRect
	assert_almost_eq(bar_bg.position.x + bar_bg.size.x * 0.5, 162.0, 0.5, "bar_bg 中心 x=162")
	var mark: TextureRect = row.get_node("MarkRect") as TextureRect
	assert_almost_eq(mark.position.x + mark.size.x * 0.5, 110.0, 0.5, "mark 中心 x=110")
	assert_almost_eq(mark.position.y + mark.size.y * 0.5, 96.0 - 72.0, 0.5, "mark 中心 y=96-72")
	assert_almost_eq(mark.size.x, 59.0 / CS * 0.8, 0.5, "mark 显示=59/CS*0.8（源 scale 0.8）")
	var head_host: Control = row.get_node("HeadHost") as Control
	assert_almost_eq(head_host.position.x, 7.0, 0.5, "head 左 x=7")
	assert_almost_eq(head_host.position.y, 96.0 - 9.0 - 104.0, 0.5, "head 顶 y=96-9-104（anchor(0,0) at (7,9)）")
	# name 右端对齐 178（源 nameLabel 右端 x=178 向左延伸，超宽 min(ow=100,w) 等比缩）
	var name_lbl: Label = row.get_node("NameLabel") as Label
	var suffix: Label = row.get_node("SuffixLabel") as Label
	var total_w: float = name_lbl.get_combined_minimum_size().x
	if suffix.visible:
		total_w += suffix.get_combined_minimum_size().x
	assert_almost_eq(name_lbl.position.x + total_w * name_lbl.scale.x, 178.0, 1.5,
		"name+suffix 右端 x=178")
	# mark 按 Main Attrib fill（icon 资产 2026-07-18 已补齐，源 HERO_EQUIP.STRENGTH 等对应物）
	var attrib: String = String(cm.get_raw_table(&"Unit").get("1", {}).get("Main Attrib", ""))
	assert_eq(mark.visible, not attrib.is_empty(), "mark 可见性=Unit.Main Attrib 存在")
	if not attrib.is_empty():
		assert_not_null(mark.texture, "mark 贴图按 Main Attrib fill")
	panel.remove_window()
	root.queue_free()


func test_max_level_row_shade_full() -> void:
	# 源 setExpMax(:397-437)：满级行 expBar 隐藏 + fullBar(fix 145x20 at (90,20)) +
	# 整行 package_hero_shade + "经验已满" size22 (255,148,62) at (190,42)。
	var root := Node.new()
	add_child(root)
	var pill_id: int = _find_exp_pill()
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(pd.hero_manager.heroes.keys()[0])
	hero.level = _levels_max_key() + 1   # 超 Levels 表 → 满级
	var panel := _make_eatexp_panel(pill_id, pd)
	panel.show_window(root)
	var grid: GridContainer = panel._content.get_node("%Grid")
	var row: Control = grid.get_child(0) as Control
	assert_true((row.get_node("MaxShade") as TextureRect).visible, "满级行 MaxShade 显示")
	var shade_lbl: Label = row.get_node("ShadeLabel") as Label
	assert_true(shade_lbl.visible, "满级行 经验已满 标签显示")
	assert_eq(shade_lbl.text, "经验已满", "标签文本=LSTR EXPERIENCE_FULL")
	assert_almost_eq((shade_lbl.offset_left + shade_lbl.offset_right) / 2.0, 190.0, 0.5,
		"shade 标签中心 x=190（源 :431 ccp(190,42)）")
	var full: TextureRect = row.get_node("ExpFullBar") as TextureRect
	assert_true(full.visible, "满级 fullBar 显示")
	assert_almost_eq(full.position.x, 90.0, 0.5, "fullBar 左端 x=90")
	assert_almost_eq(full.size.y, 20.0, 0.5, "fullBar 高=源 fix CCSizeMake(145,20)")
	assert_false((row.get_node("ExpBar") as TextureRect).visible, "满级普通 bar 隐藏")
	panel.remove_window()
	root.queue_free()


func test_eat_amount_label_x_count() -> void:
	# 源 showEatAmount(:519-557)：飘字 "x"+累计次数（eatAmount 累加），位置 (210,42)。
	# 本项目无 light_orange 数字图资源 → Label 近似（受控偏离，见任务报告）。
	var root := Node.new()
	add_child(root)
	var pill_id: int = _find_exp_pill()
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 5)
	var inst_id: int = pd.hero_manager.add_hero(1)
	var panel := _make_eatexp_panel(pill_id, pd)
	panel.show_window(root)
	panel.do_eat_hero(inst_id)
	var row: Control = (panel._content.get_node("%Grid") as GridContainer).get_child(0) as Control
	var float_lbl: Label = null
	for c in row.get_children():
		if c is Label and (c as Label).text.begins_with("x"):
			float_lbl = c as Label
			break
	assert_not_null(float_lbl, "吃经验后行内有 xN 飘字")
	if float_lbl == null:
		panel.remove_window()
		root.queue_free()
		return
	assert_eq(float_lbl.text, "x1", "首次吃显示 x1（源 eatAmount 累计语义）")
	assert_almost_eq(float_lbl.position.x, 210.0, 0.5, "飘字 x=210（源 :543 ccp(210,42)）")
	panel.do_eat_hero(inst_id)
	var found_x2: bool = false
	for c in row.get_children():
		if c is Label and (c as Label).text == "x2":
			found_x2 = true
			break
	assert_true(found_x2, "连续吃累计 x2")
	panel.remove_window()
	root.queue_free()


func test_panel_no_static_construction() -> void:
	# 两件套红线：静态结构零 .new()（行结构在 eatexp_item.tscn）。
	# 白名单：ReadheroIcon（head 动态数据工厂）+ Label（吃经验 xN 飘字，源运行时创建销毁）。
	# 计数用 ".new(" 宽口径（带参构造不含 ".new()" 字面，窄口径漏检）。
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/eatexp_panel.gd")
	assert_eq(text.count(".new("), text.count("ReadheroIcon.new(") + text.count("Label.new("),
		"静态节点零 .new(，仅 head 工厂与飘字白名单")


func test_theme_eatexp_entries() -> void:
	# variation 数值断言走 theme 资源表项（方法学沉淀：GUT 节点级不解析 variation 回落 16）。
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	# title（源 :57-72 size24 ccc3(250,205,16) + ui_normal_button 阴影(63,5,0)偏移(0,2)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EatexpTitleLabel"), 24,
		"title 字号 24 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EatexpTitleLabel") as Color,
		Color(250.0 / 255.0, 205.0 / 255.0, 16.0 / 255.0), "title 色 (250,205,16) 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_shadow_color", "EatexpTitleLabel") as Color,
		Color(63.0 / 255.0, 5.0 / 255.0, 0.0), "title 阴影 (63,5,0) 照源 ui_normal_button")
	# prompt（源 :176-185 size20 无色配置 → 白）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EatexpPromptLabel"), 20,
		"prompt 字号 20 照源")
	# level（源 :225-238 size16 ccc3(68,51,51)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EatexpHeroLevelLabel"), 16,
		"level 字号 16 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EatexpHeroLevelLabel") as Color,
		Color(68.0 / 255.0, 51.0 / 255.0, 51.0 / 255.0), "level 色 (68,51,51) 照源")
	# name（源 readhero.lua:939-985 createttf size20 白+黑阴影(0,2)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EatexpHeroNameLabel"), 20,
		"name 字号 20 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EatexpHeroNameLabel") as Color,
		Color.WHITE, "name 白色照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_shadow_color", "EatexpHeroNameLabel") as Color,
		Color.BLACK, "name 黑阴影照源")
	# shade 标签（源 :424-436 size22 ccc3(255,148,62)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EatexpShadeLabel"), 22,
		"shade 字号 22 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EatexpShadeLabel") as Color,
		Color(1.0, 148.0 / 255.0, 62.0 / 255.0), "shade 色 (255,148,62) 照源")
