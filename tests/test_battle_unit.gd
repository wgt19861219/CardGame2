extends GutTest
# Phase 2.2 单位属性层（照源 unit.lua Unit 重翻，2026-06-30）。
# 覆盖：构造身份/rebuild 属性计算/hp_mp 初始化/is_alive/is_hero/set_hp cap/display/rank 估算。
# 战斗行为（update/takeDamage/die）待 Phase 2.2续。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()

func _make_hero(tid: int = 1, level: int = 1, stars: int = 1) -> BattleUnit:
	var proto: Dictionary = {"_tid": tid, "_level": level, "_stars": stars}
	return BattleUnit.new(proto, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm)

# 源 UnitCreate 身份字段（unit.lua:124-143）
func test_construct_sets_identity() -> void:
	var u := _make_hero(1, 10, 2)
	assert_eq(u.tid, 1, "tid")
	assert_eq(u.level, 10, "level")
	assert_eq(u.stars, 2, "stars")
	assert_eq(u.camp, BattleEngine.CAMP_PLAYER, "camp")
	assert_true(u.name.length() > 0, "name 从 Unit 表加载")

# 源 rebuild（unit.lua:418-524）：属性从 Unit/UnitRank 表计算
func test_rebuild_computes_attribs() -> void:
	var u := _make_hero(1, 1, 1)
	assert_true(int(u.attribs["HP"]) > 0, "HP 从 Unit 表算 >0")
	assert_true(int(u.attribs.get("AD", 0)) > 0 or int(u.attribs.get("AP", 0)) > 0, "AD/AP >0")
	assert_true(int(u.attribs["STR"]) >= 0, "STR 基础属性")
	assert_true(u.gs > 0, "gs 战力 >0")

# 源 attrib_trans（unit.lua:286-294,498-505）：STR→HP/ARM, INT→AP/MR, AGI→AD/CRIT/ARM 派生
func test_attrib_trans_derives_secondary() -> void:
	var u := _make_hero(1, 1, 1)
	# STR 派生 HP：trans 后 attribs.HP 含 STR*18（基础 HP 之上）
	assert_true(u.attribs.has("HP"), "HP 字段存在")
	assert_true(u.attribs.has("ARM"), "ARM 字段存在（STR/AGI 派生）")

# 源 initHpMpInfo（unit.lua:54-73）：dynaData 空 → hp=max_hp, mp=0
func test_hp_mp_initialized() -> void:
	var u := _make_hero(1, 1, 1)
	assert_eq(u.hp, int(u.attribs["HP"]), "hp 初始 = max_hp（hp_perc=1）")
	assert_eq(u.mp, 0, "mp 初始 0（非 monster，mp_perc=0）")

# 源 isAlive（unit.lua:872）+ isHero（unit.lua:695）
func test_is_alive_and_is_hero_default() -> void:
	var u := _make_hero(1, 1, 1)
	assert_true(u.is_alive(), "新单位默认存活")
	assert_true(u.is_hero(), "Unit Type=Hero 且非 monster → is_hero")

# 源 setHP cap（unit.lua:848-856）
func test_set_hp_clamps_to_range() -> void:
	var u := _make_hero(1, 1, 1)
	var max_hp: int = int(u.attribs["HP"])
	u.set_hp(max_hp + 1000)
	assert_eq(u.hp, max_hp, "set_hp 上限 max_hp")
	u.set_hp(-50)
	assert_eq(u.hp, 0, "set_hp 下限 0")

# 源 setMP cap（unit.lua:859-867）
func test_set_mp_clamps_to_zero() -> void:
	var u := _make_hero(1, 1, 1)
	u.set_mp(-10)
	assert_eq(u.mp, 0, "set_mp 下限 0")

# 源 display（unit.lua:239-241）：camp==1→"[+]"
func test_display_camp_sign() -> void:
	var u := _make_hero(1, 1, 1)
	assert_true(u.display().begins_with("[+"), "玩家方 display 以 [+] 开头")
	var enemy := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_ENEMY, {"estimate_rank": true}, cm)
	assert_true(enemy.display().begins_with("[-"), "敌方 display 以 [-] 开头")

# 源 rank 估算（unit.lua:127-129）：estimate_rank → floor((level+9)/10)
func test_rank_estimate_from_level() -> void:
	var u10 := _make_hero(1, 10, 1)
	assert_eq(u10.rank, 1, "level 10 → rank 1（floor(19/10)）")
	var u20 := _make_hero(1, 20, 1)
	assert_eq(u20.rank, 2, "level 20 → rank 2（floor(29/10)）")

# 源 foe camp（unit.lua:144）：foecamp = -camp
func test_foe_camp_negation() -> void:
	var u := _make_hero(1, 1, 1)
	assert_eq(u.focamp, BattleEngine.CAMP_ENEMY, "玩家方 focamp = -1（敌方）")

# 源 hp_mod 应用（unit.lua:506）：attribs.HP *= config.hp_mod
func test_hp_mod_scales_max_hp() -> void:
	var proto: Dictionary = {"_tid": 1, "_level": 1, "_stars": 1}
	var u_base := BattleUnit.new(proto, BattleEngine.CAMP_PLAYER, {"estimate_rank": true, "hp_mod": 1.0}, cm)
	var u_double := BattleUnit.new(proto, BattleEngine.CAMP_PLAYER, {"estimate_rank": true, "hp_mod": 2.0}, cm)
	assert_eq(int(u_double.attribs["HP"]), int(u_base.attribs["HP"]) * 2, "hp_mod=2 → HP 翻倍")
