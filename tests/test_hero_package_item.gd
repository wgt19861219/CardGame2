extends GutTest
# HeroPackageItem 测试（P0-1 整行卡片重建）：照源 heroitem.lua baseheroitem + packageheroitem。
# 已拥有→装备槽路径；未拥有→灵魂石进度条路径。is_miss/tid 字段 + bg 子节点结构验证。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 baseheroitem create + packageheroitem create（拥有分支）：createHeroEquips。
func test_item_owned_is_not_miss() -> void:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var hero: HeroInstance = mgr.find_hero_by_tid(1)
	assert_not_null(hero, "tid=1 英雄应存在")
	var item := HeroPackageItem.create_from_entry(hero, cm, mgr)
	assert_false(item.is_miss, "已拥有英雄 → is_miss=false")
	assert_eq(item.tid, 1, "tid 从 HeroInstance 传递")
	assert_eq(item.custom_minimum_size, HeroPackageItem.CELL_SIZE, "cell 最小尺寸 = 260×100")


# 源 packageheroitem create（miss 分支）：setSpriteGray + createHeroStone。
func test_item_miss_has_stone_bar() -> void:
	var entry: Dictionary = {"tid": 2, "miss": true}
	var mgr := HeroManager.new(cm)
	var item := HeroPackageItem.create_from_entry(entry, cm, mgr)
	assert_true(item.is_miss, "未拥有 dict → is_miss=true")
	assert_eq(item.tid, 2, "tid 从 miss dict 取")
	assert_not_null(item.head, "miss 路径仍建 head ReadheroIcon")


# 源 baseheroitem :20-25 — miss 用 createIcon{id,rank=1}（无 level/stars），ori_icon 灰化。
func test_item_miss_head_grayed() -> void:
	var entry: Dictionary = {"tid": 2, "miss": true}
	var mgr := HeroManager.new(cm)
	var item := HeroPackageItem.create_from_entry(entry, cm, mgr)
	if item.head == null or item.head.ori_icon == null:
		pending("head/ori_icon 未建（纹理缺失），跳过灰化检查")
		return
	assert_eq(item.head.ori_icon.modulate, HeroPackageItem.GRAY_MODULATE, "未拥有头像灰化")


# bg TextureRect 应作为首子节点（源 baseheroitem bg 为容器根）。
func test_item_has_bg_texture() -> void:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var hero: HeroInstance = mgr.find_hero_by_tid(1)
	var item := HeroPackageItem.create_from_entry(hero, cm, mgr)
	# Phase A 重构（2026-07-18）：bg 在 content 子场景下，递归扫描（坑 6 .tscn 多一层 content）。
	var bg: TextureRect = _find_first_texture_rect(item)
	assert_not_null(bg, "item 应含 TextureRect bg 子节点（content 下）")


# 子节点全部 mouse_filter=IGNORE（装饰不吞点击），唯 item 自身 STOP（源 bg 点击由 draglist 捕获）。
func test_item_decorations_ignore_mouse() -> void:
	var entry: Dictionary = {"tid": 2, "miss": true}
	var mgr := HeroManager.new(cm)
	var item := HeroPackageItem.create_from_entry(entry, cm, mgr)
	# Phase A 重构（2026-07-18）：装饰在 content 子树，递归收集 Control（head 是 Node2D 自动断链不进）。
	var decos: Array = []
	_collect_controls(item, decos)
	for c in decos:
		assert_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "装饰子节点应 IGNORE 鼠标")
	assert_gt(decos.size(), 5, "应收集多个装饰节点（bg/name/mark/slot/bar 等）")


# Phase A 重构辅助：递归找首个 TextureRect（.tscn 多一层 content，坑 6）。
static func _find_first_texture_rect(node: Node) -> TextureRect:
	for c in node.get_children():
		if c is TextureRect:
			return c as TextureRect
		var sub: TextureRect = _find_first_texture_rect(c)
		if sub != null:
			return sub
	return null


# Phase A 重构辅助：递归收集 Control（head 是 Node2D 自动断链不进 head 子树）。
static func _collect_controls(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Control:
			out.append(c)
			_collect_controls(c, out)


# ── 两件套守卫（批 1 Task 9，2026-08-15）：theme variation 接线 + mark 等比 + 零静态 .new() 白名单 ──

const CS: float = 1.28125


# item 内容场景实例（.tscn 直查静态树）。
func _instantiate_item_content() -> Control:
	var scene: PackedScene = load("res://scenes/ui/hero_package_item_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


# 名字/后缀走 HeroPackageNameLabel variation（源 heroitem.lua:32 size20 白+黑阴影(0,2)，
# readhero.createHeroNameByInfo 同规格），tscn 不再 theme_override_*。
# 石头进度文字走 HeroPackageStoneLabel size18（源 :151 createttf(text,18)，旧 14 随手值修正）。
func test_item_theme_variations() -> void:
	var inst: Control = _instantiate_item_content()
	var name_lbl: Label = inst.get_node("%NameHost/NameLabel") as Label
	assert_eq(name_lbl.theme_type_variation, &"HeroPackageNameLabel", "NameLabel 走 variation")
	assert_false(name_lbl.has_theme_font_size_override("font_size"), "NameLabel 无字号 override")
	assert_false(name_lbl.has_theme_color_override("font_shadow_color"), "NameLabel 无阴影色 override")
	var suffix_lbl: Label = inst.get_node("%NameHost/SuffixLabel") as Label
	assert_eq(suffix_lbl.theme_type_variation, &"HeroPackageNameLabel", "SuffixLabel 走 variation（色 fill 动态 override）")
	var stone_lbl: Label = inst.get_node("%StoneGroup/StoneLabel") as Label
	assert_eq(stone_lbl.theme_type_variation, &"HeroPackageStoneLabel", "StoneLabel 走 variation")
	assert_false(stone_lbl.has_theme_font_size_override("font_size"), "StoneLabel 无字号 override")


# mark 等比（源 heroitem.lua:38-42 markIcon scale 0.8 等比）：纹理 59×59 → 显示 59/CS×0.8=36.8 方形。
# 旧 tscn 37×32 非等比拉伸变形 → 本批修正为等比（位置保留 d50674d 照源验收值）。
func test_item_mark_rect_aspect() -> void:
	var inst: Control = _instantiate_item_content()
	var mark: TextureRect = inst.get_node("%MarkRect") as TextureRect
	assert_almost_eq(mark.offset_right - mark.offset_left, 59.0 / CS * 0.8, 0.1, "mark 宽=59/CS×0.8 等比")
	assert_almost_eq(mark.offset_bottom - mark.offset_top, 59.0 / CS * 0.8, 0.1, "mark 高=59/CS×0.8 等比")


# 白名单式 .new( 断言：HeroPackageItem.new（自身工厂）+ ReadheroIcon（head 动态工厂）+
# TextureRect（plusSign/equip icon 动态数据图标，源运行时按槽位状态创建）。静态结构（bg/slot/bar 组）零 .new(。
func test_item_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_package_item.gd")
	assert_eq(text.count(".new("), text.count("HeroPackageItem.new(") + text.count("ReadheroIcon.new(")
		+ text.count("TextureRect.new("), "静态节点零 .new(，仅工厂与动态图标白名单")
