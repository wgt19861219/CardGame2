extends GutTest
# Phase 2.6 BattleChain（照源 chain.lua:1-84 翻译，2026-07-01）。
# 验 ChainCreate 首跳（target 受伤）+ update 跳跃（多目标受伤 / jumps_remaining 递减 / 终止）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_engine() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(777)
	return eng


func _make_enemy(eng: BattleEngine, pos: Vector2, name_suffix: String) -> BattleUnit:
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_ENEMY, {"estimate_rank": true}, cm, eng, {}, null)
	u.position = pos
	u.previous_position = pos
	u.attribs["ARM"] = 0.0
	u.attribs["DODG"] = 0.0
	u.attribs["PIMU"] = 0.0
	u.name = name_suffix
	return u


# Chain 技能 info（AD，Chain Jumps=3，无 Buff ID；Track Type 由 _create_chain 路径不走，直接测 chain）
func _make_chain_skill(caster: BattleUnit) -> BattleSkill:
	return BattleSkill.new({
		"Chain Jumps": 3,
		"Chain Gap": 0.1,
		"Max Range": 99999.0,
		"Min Range": 0.0,
		"Damage Type": "AD",
		"Basic Num": 100.0,
		"Plus Ratio": 0.0,
		"Target Type": "target",
		"Target Camp": -1,
		"Affected Camp": 0,
		"Cost MP": 0.0,
		"CD": 0.0,
		"Global CD": 0.0,
	}, caster, 1)


# 源 ChainCreate（:10-22）+ jump（:26-37）：构造即首跳 takeEffectOn(target)
func test_chain_create_first_jump_hits_target() -> void:
	var eng := _make_engine()
	var attacker := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	attacker.position = Vector2(0, 0)
	attacker.previous_position = attacker.position
	var e1 := _make_enemy(eng, Vector2(200, 0), "e1")
	eng.add_unit(attacker)
	eng.add_unit(e1)
	var hp_before := int(e1.hp)
	var sk := _make_chain_skill(attacker)
	sk.target = e1
	var chain := BattleChain.new(sk)
	assert_eq(chain.jumps_remaining, 2, "首跳后 jumps_remaining 3→2")
	assert_true(int(e1.hp) < hp_before, "首跳 takeEffectOn 命中 e1（hp %d → %d）" % [hp_before, int(e1.hp)])


# 源 update（:40-54）+ findNextTaeget（:60-83）：jump_timer 到点 → 跳下一目标 → 多目标受伤
func test_chain_update_jumps_to_next_targets() -> void:
	var eng := _make_engine()
	var attacker := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	attacker.position = Vector2(0, 0)
	attacker.previous_position = attacker.position
	var e1 := _make_enemy(eng, Vector2(200, 0), "e1")
	var e2 := _make_enemy(eng, Vector2(250, 0), "e2")
	var e3 := _make_enemy(eng, Vector2(300, 0), "e3")
	eng.add_unit(attacker)
	eng.add_unit(e1)
	eng.add_unit(e2)
	eng.add_unit(e3)
	var sk := _make_chain_skill(attacker)
	sk.target = e1
	var chain := BattleChain.new(sk)
	eng.add_chain(chain)
	assert_eq(eng.projectile_list.size(), 1, "chain 进 projectile_list")
	for i in range(30):
		eng.update(0.033)
		if chain.terminated:
			break
	var hit_count: int = 0
	for e in [e1, e2, e3]:
		if int(e.hp) < int(e.attribs.get("HP", 0)):
			hit_count += 1
	assert_true(hit_count >= 2, "chain 跳跃命中 >=2 个目标（实际 %d）" % hit_count)
	assert_true(chain.terminated, "chain 跳跃完毕终止")
