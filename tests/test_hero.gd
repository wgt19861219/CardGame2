extends GutTest
# Step 2.1 英雄系统单测：默认值(防nil遮蔽) + 升星(消耗/max) + 分解返还 + 碎片合成 + 星级成长。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()

func before_each() -> void:
	# 每个 test 新 manager，gold 充足
	_mgr = HeroManager.new(cm)
	_mgr.gold = 1000000

var _mgr: HeroManager

func _seed_fragments(tid: int, count: int) -> void:
	# 给目标英雄的专属 + 通用碎片
	_mgr._add_fragment(cm.get_int(&"Fragment", tid, &"Fragment ID"), count)
	_mgr._add_fragment(cm.get_int(&"Fragment", tid, &"Universal Fragment ID"), count)

func test_add_hero_defaults_prevent_nil() -> void:
	var inst_id := _mgr.add_hero(1)
	var hero := _mgr.get_hero(inst_id)
	assert_not_null(hero)
	assert_eq(hero.tid, 1)
	assert_true(hero.stars >= 1, "星级默认 >=1（防旧版 nil 遮蔽）")
	assert_eq(hero.rank, 1, "rank 默认 1")
	assert_eq(hero.level, 1, "level 默认 1")

func test_evolve_increments_stars() -> void:
	_seed_fragments(1, 100)
	var inst_id := _mgr.add_hero(1)
	var hero := _mgr.get_hero(inst_id)
	var s := hero.stars
	assert_true(_mgr.evolve(inst_id), "升星应成功")
	assert_eq(hero.stars, s + 1, "星级 +1")

func test_evolve_respects_max_stars() -> void:
	_seed_fragments(1, 9999)
	var inst_id := _mgr.add_hero(1)
	var hero := _mgr.get_hero(inst_id)
	var data := HeroData.from_config(cm, 1)
	hero.stars = data.max_stars  # 直接设到上限
	assert_false(_mgr.evolve(inst_id), "达 max_stars 后不可再升")

func test_split_returns_fragments_and_removes() -> void:
	_seed_fragments(1, 100)
	var inst_id := _mgr.add_hero(1)
	var result := _mgr.split(inst_id)
	assert_true(result.size() > 0, "分解应返还碎片")
	assert_eq(int(result["count"]), cm.get_int(&"HeroStars", 1, &"Convert Fragments"))
	assert_null(_mgr.get_hero(inst_id), "分解后英雄移除")

func test_compose_creates_hero() -> void:
	_seed_fragments(1, 100)
	var before := _mgr.heroes.size()
	assert_true(_mgr.compose(1), "碎片合成应成功")
	assert_eq(_mgr.heroes.size(), before + 1, "合成后英雄 +1")

func test_compose_fails_without_fragments() -> void:
	# 不给碎片，合成应失败
	assert_false(_mgr.compose(1), "缺碎片合成应失败")

func test_hero_data_growth_applies() -> void:
	var data := HeroData.from_config(cm, 1)
	var s1 := data.str_at_stars(1)
	var s3 := data.str_at_stars(3)
	assert_true(s3 >= s1, "3星 STR 应 >= 1星（成长非负）")


# ── hero_evolve 统一入口（源 local_server.lua:905-987 双分支）──

func test_hero_evolve_existing_hero_upgrades() -> void:
	# 源 :909-933 已有英雄 → stars+1
	_seed_fragments(1, 100)
	var inst_id := _mgr.add_hero(1)
	var hero := _mgr.get_hero(inst_id)
	var old_stars: int = hero.stars
	var r: Dictionary = _mgr.hero_evolve(1)
	assert_true(bool(r["ok"]), "已有英雄 evolve 成功")
	assert_eq(int(r["inst_id"]), inst_id, "返同一 inst_id")
	assert_eq(hero.stars, old_stars + 1, "stars+1")


func test_hero_evolve_new_hero_summons() -> void:
	# 源 :934-985 未拥有 → 新英雄召唤（读 Summon Fragments + Summon Price）
	_seed_fragments(10, 100)  # 给 tid=10 充足碎片
	assert_null(_mgr.find_hero_by_tid(10), "召唤前无 tid=10")
	var r: Dictionary = _mgr.hero_evolve(10)
	assert_true(bool(r["ok"]), "新英雄召唤成功")
	assert_gt(int(r["inst_id"]), 0, "返新 inst_id")
	assert_not_null(_mgr.find_hero_by_tid(10), "召唤后有 tid=10")


func test_hero_evolve_new_hero_no_fragments() -> void:
	# 不给碎片，召唤应失败
	assert_null(_mgr.find_hero_by_tid(10), "召唤前无 tid=10")
	var r: Dictionary = _mgr.hero_evolve(10)
	assert_false(bool(r["ok"]), "缺碎片召唤失败")
	assert_null(_mgr.find_hero_by_tid(10), "失败后仍无 tid=10")
