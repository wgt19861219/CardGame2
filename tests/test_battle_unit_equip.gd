extends GutTest
# Phase 2.2续-F BattleUnit 装备加载测试（2026-07-02）— 照源 unit.lua:147-175。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _new_unit(proto: Dictionary, camp: int, cfg: Dictionary) -> BattleUnit:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(12345)
	return BattleUnit.new(proto, camp, cfg, cm, eng, {}, null)


func test_player_equips_loaded() -> void:
	# 路径 B：proto._items 玩家装备，config 无 estimate_rank
	var proto := {"_tid": 1, "_level": 1, "_stars": 1, "_items": [{"_item_id": 101, "_exp": 500.0}]}
	var u := _new_unit(proto, BattleEngine.CAMP_PLAYER, {})
	assert_true(u.equips.size() >= 1, "玩家装备加载 1 件")
	var equip: Dictionary = u.equips[0]
	assert_eq(float(equip.get("+GS", 0.0)), 2.7, "装备 101 +GS=2.7（wraptable 保留 Equip 整行）")
	assert_true(equip.has("level"), "wraptable 加 level 字段")


func test_monster_no_equips() -> void:
	# 怪物 estimate_rank → equips=[]
	var u := _new_unit({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_ENEMY, {"estimate_rank": true})
	assert_eq(u.equips.size(), 0, "怪物 estimate_rank 不加载装备")


func test_default_equips_hero_not_crash() -> void:
	# 路径 A：estimate_max_rank → hero_equip[unit_id][max_rank] 查（max_rank 配置可能空，仅验证不崩）
	var u := _new_unit({"_tid": 1, "_level": 10, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_max_rank": true})
	assert_true(u.equips is Array, "默认装备路径不崩（equips 为 Array）")


func test_equip_attribs_applied() -> void:
	# 装备属性应进 attribs（rebuild:452-460）
	var proto := {"_tid": 1, "_level": 1, "_stars": 1, "_items": [{"_item_id": 101, "_exp": 0.0}]}
	var u := _new_unit(proto, BattleEngine.CAMP_PLAYER, {})
	# 装备 101 AGI=1（基础），level=0（exp 0）→ attribs.AGI 含装备基础 +1
	var agi: float = float(u.attribs.get("AGI", 0.0))
	assert_true(agi >= 1.0, "装备基础 AGI 进 attribs")
