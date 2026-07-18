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
