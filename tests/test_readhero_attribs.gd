extends GutTest
# Phase 5.1 readhero_attribs 属性查询测试（2026-07-02）。
# 验 ReadheroAttribs.get_hero_att_by_hero：复用 BattleUnit(engine=null) 取 attribs/orig_attribs，
#   算 base/add/all。tid=1 Coco HeroInstance。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 getHeroAttByHero :11-37 — 建 BattleUnit 取 attribs → base/add/all。
func test_get_hero_att_by_hero() -> void:
	var hero := HeroInstance.new(1, 1, 1)   # tid=1 Coco, stars=1, inst_id=1
	hero.level = 1
	hero.rank = 1
	var att: Dictionary = ReadheroAttribs.get_hero_att_by_hero(hero, cm)
	assert_true(att.has("HP"), "att 含 HP（源 attribs）")
	var hp: Dictionary = att["HP"]
	assert_gt(int(hp["all"]), 0, "HP all > 0（Coco 基础 HP）")
	assert_gte(int(hp["all"]), int(hp["base"]), "all >= base（add >= 0）")


# hero null 守卫。
func test_get_hero_att_null() -> void:
	var att: Dictionary = ReadheroAttribs.get_hero_att_by_hero(null, cm)
	assert_eq(att.size(), 0, "hero null → 空 att_info（源 :12-14）")
