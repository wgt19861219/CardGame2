extends GutTest
# 集成冒烟测试（战斗核心端到端，2026-07-01）。
# 验 engine.tick→unit.update→AI→find_skill_to_cast→cast_skill→skill.start→on_attack_frame→
#   take_effect_on→take_damage→die→on_unit_die→victory 全链路 Logic 正确性（无 View，headless 跑一场战斗）。
# 三部分：
#   A 真装配（SkillGroup 表）+ engine.tick 120 帧 → 链路不崩 + 装配 + 双方存活
#   B 注入 phase 的干净 skill → on_attack_frame → take_damage（target 受伤）
#   C 强伤害 → target die → on_unit_die → alive_enemy_count==0 → victory
# phase 时序已工作（lib 注入 + rebuild_phase_list 查 Puppet/AnimDuration/AnimAtkFrame 表填 phase_list，2026-07-05 验证）。
#   A 真装配 + 2000 帧真战斗 → 真伤害交换 + 分胜负；B/C controlled skill 手注 phase_list 隔离 take_damage/death 链路。
#   add_buff 占位桩（B 用无 Buff ID skill 避开）；remove_all_buffs/handle_unit_die_event 占位桩（让 C 胜利链路通）。

var cm: ConfigManager
var lib: SkillLibrary


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)


func _make_engine() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(12345)
	return eng


func _make_unit(tid: int, camp: int, eng: BattleEngine, pos: Vector2, with_lib: bool) -> BattleUnit:
	var u := BattleUnit.new({"_tid": tid, "_level": 1, "_stars": 1}, camp, {"estimate_rank": true}, cm, eng, {}, lib if with_lib else null)
	u.position = pos
	u.previous_position = pos
	return u


# controlled 伤害 skill（AD，无 Buff ID 避开 add_buff gap）+ 手注 phase_list（无 Action(s) 字段，rebuild 返空，手注触发攻击帧）。
# 返回的 sk 需由调用方 append 进 attacker.skill_list，cast_skill 后经 unit.update 推进触发攻击帧。
func _make_damage_skill(caster: BattleUnit, basic_num: float) -> BattleSkill:
	var sk := BattleSkill.new({
		"Damage Type": "AD",
		"Basic Num": basic_num,
		"Plus Ratio": 0.0,
		"Max Range": 999.0,
		"Target Type": "target",
		"Cost MP": 0.0,
		"CD": 0.0,
		"Global CD": 0.0,
	}, caster, 1)
	sk.phase_list = [{"action_name": "Attack", "event_list": [{"Time": 0.001, "Type": "Attack"}]}]
	return sk


# Part A：真装配（cm+lib，SkillGroup 表）+ engine.tick 2000 帧 → 真伤害交换 + 分胜负（phase 时序工作）。
func test_smoke_assemble_and_tick() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0), true)
	var e := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0), true)
	eng.add_unit(p)
	eng.add_unit(e)
	assert_true(p.skill_list.size() > 0, "player 从 SkillGroup 装配技能")
	assert_not_null(p.basic_skill, "player 装配 basic_skill")
	assert_true(p.basic_skill.phase_list.size() > 0, "basic_skill.phase_list 非空（rebuild 查 AnimAtkFrame 表填上）")
	for i in range(2000):
		eng.update(0.033)
		if eng.last_result != -1:
			break
	assert_ne(eng.last_result, -1, "战斗分出胜负（phase 时序工作，on_attack_frame 触发伤害交换）")
	assert_gt(int(p.dmg_statistics) + int(e.dmg_statistics), 0, "双方伤害交换（on_attack_frame 真触发）")


# Part B：注入 phase 的干净 skill → on_attack_frame → take_effect_on → take_damage（target 受伤）。
func test_smoke_damage_chain() -> void:
	var eng := _make_engine()
	var attacker := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0), false)
	var target := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(110, 0), false)
	# 受控 target：无闪避/减伤/免疫，确保伤害确定生效（避开 rng 闪避与防御公式的不确定性）
	target.attribs["ARM"] = 0.0
	target.attribs["DODG"] = 0.0
	target.attribs["PIMU"] = 0.0
	eng.add_unit(attacker)
	eng.add_unit(target)
	var hp_before := int(target.hp)
	var sk := _make_damage_skill(attacker, 200.0)
	attacker.skill_list.append(sk)
	attacker.cast_skill(sk, target)
	for i in range(10):
		eng.update(0.033)
	assert_true(int(target.hp) < hp_before, "target 受伤（hp %d → %d）" % [hp_before, int(target.hp)])


# Part C：强伤害 → target die → on_unit_die（alive_enemy_count--）→ tick 判定 → victory。
func test_smoke_death_and_victory() -> void:
	var eng := _make_engine()
	var attacker := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0), false)
	var target := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(110, 0), false)
	target.attribs["ARM"] = 0.0
	target.attribs["DODG"] = 0.0
	target.attribs["PIMU"] = 0.0
	target.set_hp(10)
	eng.add_unit(attacker)
	eng.add_unit(target)
	assert_eq(eng.alive_enemy_count, 1, "死前 enemy 存活")
	var sk := _make_damage_skill(attacker, 9999.0)
	attacker.skill_list.append(sk)
	attacker.cast_skill(sk, target)
	for i in range(10):
		eng.update(0.033)
	assert_false(bool(target.is_alive()), "target 死亡")
	assert_eq(target.state, BattleUnit.State.DYING, "target 进入 DYING 态")
	assert_eq(eng.alive_enemy_count, 0, "死后 enemy 存活 0")
	assert_eq(eng.last_result, BattleEngine.RESULT_WIN, "engine 判定胜利")
