extends GutTest
# Phase 2.6 BattleEnergyBallManager（照源 energyball.lua:1-194）。
# 验 addEnergyBall（Born）+ update（Born→Available）+ consumeEnergyBall + canCastSkill 球组合匹配。


class MockUnit:
	extends RefCounted
	var skill_condition: Dictionary = {}
	func is_alive() -> bool:
		return true


func test_add_update_consume() -> void:
	var u := MockUnit.new()
	var mgr := BattleEnergyBallManager.new(u)
	mgr.add_energy_ball("ice")
	assert_eq(mgr.slots[0].ball_type, "ice", "球进槽0")
	assert_eq(mgr.slots[0].ball_status, BattleEnergyBallManager.STATUS_BORN, "Born")
	mgr.update(0.1)
	assert_eq(mgr.slots[0].ball_status, BattleEnergyBallManager.STATUS_AVAILABLE, "Born→Available（CD=0 即转）")
	mgr.add_energy_ball("fire")
	mgr.update(0.1)
	mgr.add_energy_ball("lightning")
	mgr.update(0.1)
	mgr.consume_energy_ball()
	assert_eq(mgr.slots[0].ball_type, "", "consume 清空三槽")


func test_can_cast_skill_ball_combo() -> void:
	var u := MockUnit.new()
	u.skill_condition = {10: [1, 1, 1]}
	var mgr := BattleEnergyBallManager.new(u)
	mgr.add_energy_ball("ice")
	mgr.update(0.1)
	mgr.add_energy_ball("fire")
	mgr.update(0.1)
	mgr.add_energy_ball("lightning")
	mgr.update(0.1)
	var sk := {"info": {"Skill Group ID": 10}}
	assert_true(mgr.can_cast_skill(sk), "三球 [ice,fire,lightning] 匹配 [1,1,1]")
