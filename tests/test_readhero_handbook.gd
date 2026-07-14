extends GutTest
# ReadheroHandbook 测试（P0-1 整行卡片重建）：碎片查询 + 未召唤列表 + 图鉴分类。
# 照源 readhero.lua getStoneid/getStoneAmount/getStoneNeed/checkStoneEnough/getMissList/classify 翻译验证。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 getStoneid :642-648 — Fragment[tid]["Fragment Id"]。
func test_get_stone_id_from_fragment_table() -> void:
	var sid: int = ReadheroHandbook.get_stone_id(1, cm)
	assert_gt(sid, 0, "Fragment 表 tid=1 应有 Fragment Id > 0")


# 源 getStoneAmount :649-653 — player.equip_qunty[stone_id]；本项目 fragments 容器。
func test_get_stone_amount_no_fragment_zero() -> void:
	var mgr := HeroManager.new(cm)
	assert_eq(ReadheroHandbook.get_stone_amount(1, cm, mgr), 0, "无碎片时 amount=0")


func test_get_stone_amount_with_fragment() -> void:
	var mgr := HeroManager.new(cm)
	var sid: int = ReadheroHandbook.get_stone_id(1, cm)
	mgr.add_fragment(sid, 10)
	assert_eq(ReadheroHandbook.get_stone_amount(1, cm, mgr), 10, "加 10 碎片后 amount=10")


# 源 getStoneNeed :654-671 — 未拥有查 HeroStars[Initial Stars]["Summon Fragments"]。
func test_get_stone_need_unowned_positive() -> void:
	var mgr := HeroManager.new(cm)
	var need: int = ReadheroHandbook.get_stone_need(2, cm, mgr)
	assert_gt(need, 0, "未拥有英雄 tid=2 召唤碎片需求应 > 0")


# 源 checkStoneEnough :684-693 — amount >= need。
func test_check_stone_enough_false_when_empty() -> void:
	var mgr := HeroManager.new(cm)
	assert_false(ReadheroHandbook.check_stone_enough(2, cm, mgr), "无碎片不可召唤")


func test_check_stone_enough_true_when_full() -> void:
	var mgr := HeroManager.new(cm)
	var sid: int = ReadheroHandbook.get_stone_id(2, cm)
	var need: int = ReadheroHandbook.get_stone_need(2, cm, mgr)
	mgr.add_fragment(sid, need)
	assert_true(ReadheroHandbook.check_stone_enough(2, cm, mgr), "碎片达需求可召唤")


# 源 getMissList :694-715 — Unit 表 hero(id<100) 且未拥有 且碎片>0，升序。
func test_get_miss_list_empty_without_fragment() -> void:
	var mgr := HeroManager.new(cm)
	var ml: Array[int] = ReadheroHandbook.get_miss_list(cm, mgr)
	assert_eq(ml.size(), 0, "无碎片 → 未召唤列表空")


func test_get_miss_list_includes_hero_with_fragment() -> void:
	var raw: Dictionary = cm.get_raw_table(&"Unit")
	if not raw.has("2"):
		pending("Unit 表无 tid=2，跳过")
		return
	var mgr := HeroManager.new(cm)
	var sid: int = ReadheroHandbook.get_stone_id(2, cm)
	mgr.add_fragment(sid, 1)
	var ml: Array[int] = ReadheroHandbook.get_miss_list(cm, mgr)
	assert_true(ml.has(2), "tid=2 有碎片应入 miss_list")


# 源 getMissList 排除 monster（id>=100）。
func test_get_miss_list_excludes_monster() -> void:
	var mgr := HeroManager.new(cm)
	# 给一个 monster tid 加碎片（若存在），不应入 miss_list
	var raw: Dictionary = cm.get_raw_table(&"Unit")
	var monster_tid: int = 0
	for tid_str in raw:
		if tid_str.is_valid_int() and int(tid_str) >= 100:
			monster_tid = int(tid_str)
			break
	if monster_tid == 0:
		pending("Unit 表无 monster tid>=100，跳过")
		return
	var sid: int = ReadheroHandbook.get_stone_id(monster_tid, cm)
	mgr.add_fragment(sid, 10)
	var ml: Array[int] = ReadheroHandbook.get_miss_list(cm, mgr)
	assert_false(ml.has(monster_tid), "monster tid 不应入 hero miss_list")


# 源 classify("handbook","position") :920-938 — 已拥有英雄进 all + 按位置分。
func test_classify_handbook_includes_owned() -> void:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var cls: Dictionary = ReadheroHandbook.classify_handbook(cm, mgr)
	var all: Array = cls["all"]
	assert_true(_list_has_tid(all, 1), "已拥有英雄 tid=1 应在 all 列表")


func test_classify_handbook_miss_in_all_with_fragment() -> void:
	var raw: Dictionary = cm.get_raw_table(&"Unit")
	if not raw.has("2"):
		pending("Unit 表无 tid=2，跳过")
		return
	var mgr := HeroManager.new(cm)
	var sid: int = ReadheroHandbook.get_stone_id(2, cm)
	mgr.add_fragment(sid, 1)
	var cls: Dictionary = ReadheroHandbook.classify_handbook(cm, mgr)
	var all: Array = cls["all"]
	assert_true(_list_has_tid(all, 2), "tid=2 有碎片应在 all 列表（未召唤条目）")


# 源 orderHeroFunction — level desc 排序（高 level 在前）。
func test_order_heroes_by_level_desc() -> void:
	var mgr := HeroManager.new(cm)
	var id1: int = mgr.add_hero(1)
	var id2: int = mgr.add_hero(2)
	var h1: HeroInstance = mgr.get_hero(id1)
	var h2: HeroInstance = mgr.get_hero(id2)
	h1.level = 5
	h2.level = 10
	var ordered: Array = ReadheroHandbook.order_heroes([h1, h2])
	assert_eq(ReadheroHandbook.entry_tid(ordered[0]), 2, "高 level (tid=2 lv10) 排前")
	assert_eq(ReadheroHandbook.entry_tid(ordered[1]), 1, "低 level (tid=1 lv5) 排后")


func _list_has_tid(list: Array, tid: int) -> bool:
	for v in list:
		if ReadheroHandbook.entry_tid(v) == tid:
			return true
	return false
