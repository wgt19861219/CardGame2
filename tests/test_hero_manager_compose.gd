extends GutTest
# HeroManager.compose 碎片合成测试（照源 fragmentcompose.lua doCompose :123-149）。
# 通用碎片补足分支（2026-07-05 第 21 段）：专属优先扣，不足用通用补（≤通用需求）。
# Fragment[1]: Fragment ID=124 / Count=10 / Universal ID=335 / Count=5 / Expense=10000 → 英雄 tid=1

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 专属够（frag>=need）→ 不扣通用（源 :142-145 min(frag,need)=need，:146-149 need-frag=0）
func test_compose_full_fragment_no_universal() -> void:
	var mgr := HeroManager.new(cm)
	mgr._add_fragment(124, 10)
	mgr._add_fragment(335, 5)
	mgr.gold = 10000
	assert_true(mgr.compose(1), "专属够 → 合成成功")
	assert_eq(mgr.heroes.size(), 1, "新增英雄")
	assert_eq(mgr._fragment_count(124), 0, "扣专属 10")
	assert_eq(mgr._fragment_count(335), 5, "不扣通用（源 :146-149 frag>=need → uni_use=0）")
	assert_eq(mgr.gold, 0, "扣金币 10000")


# 专属不够通用补足（源 :146-149 uni_use=need-frag_have）
func test_compose_universal_supplement() -> void:
	var mgr := HeroManager.new(cm)
	mgr._add_fragment(124, 7)
	mgr._add_fragment(335, 5)
	mgr.gold = 10000
	assert_true(mgr.compose(1), "专属 7 + 通用补 3 → 合成成功")
	assert_eq(mgr._fragment_count(124), 0, "扣专属 7")
	assert_eq(mgr._fragment_count(335), 2, "扣通用 3（10-7，源 :146-149）")
	assert_eq(mgr.gold, 0, "扣金币 10000")


# 通用补足上限 ≤ uni_need（源 :124-127 uni_avail=min(uni_have, uni_need)）
func test_compose_universal_cap() -> void:
	var mgr := HeroManager.new(cm)
	mgr._add_fragment(124, 5)
	mgr._add_fragment(335, 10)   # > uni_need(5)，uni_avail=min(10,5)=5
	mgr.gold = 10000
	assert_true(mgr.compose(1), "专属 5 + 通用可用 5 → 合成成功")
	assert_eq(mgr._fragment_count(124), 0, "扣专属 5")
	assert_eq(mgr._fragment_count(335), 5, "扣通用 5（=uni_need，剩 5）")


# 碎片不足：frag_have + uni_avail < frag_need（源 :128）
func test_compose_insufficient_fragment() -> void:
	var mgr := HeroManager.new(cm)
	mgr._add_fragment(124, 4)
	mgr._add_fragment(335, 5)
	mgr.gold = 10000
	assert_false(mgr.compose(1), "4+5=9<10 → 碎片不足拒绝")


# 通用补足上限不够（uni_avail=min(uni_have,uni_need) 仍不够 frag_need）
func test_compose_universal_cap_insufficient() -> void:
	var mgr := HeroManager.new(cm)
	mgr._add_fragment(124, 0)
	mgr._add_fragment(335, 100)   # uni_avail=min(100,5)=5 < frag_need=10
	mgr.gold = 10000
	assert_false(mgr.compose(1), "通用上限 5 < 需求 10 → 碎片不足拒绝")


func test_compose_insufficient_gold() -> void:
	var mgr := HeroManager.new(cm)
	mgr._add_fragment(124, 10)
	mgr._add_fragment(335, 5)
	mgr.gold = 5000
	assert_false(mgr.compose(1), "金币不足 → 拒绝")


# 源 doCompose :138 hero 类型且已拥有 → 拒绝（防重复添加）
func test_compose_already_owned_rejects() -> void:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	mgr._add_fragment(124, 10)
	mgr._add_fragment(335, 5)
	mgr.gold = 10000
	assert_false(mgr.compose(1), "已有 tid=1 → 拒绝（源 :138）")
	assert_eq(mgr.heroes.size(), 1, "不重复添加")
