extends GutTest
# Phase 2.6 BattleNpc（照源 npc.lua:1-125）。
# 验 NpcCreate（position/state/进 npc_list）+ die（engine.on_npc_die + state Dying）。


func test_npc_create_and_die() -> void:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(1)
	var npc := BattleNpc.new({"Position X": 100.0, "Position Y": 50.0, "Puppet": "p1"}, eng, false, null)
	eng.add_npc(npc)
	assert_eq(npc.position, Vector2(100.0, 50.0), "NpcCreate position")
	assert_eq(npc.state, BattleNpc.STATE_IDLE, "初始 Idle")
	assert_eq(eng.npc_list.size(), 1, "进 npc_list")
	assert_true(npc.is_alive(), "alive")
	npc.die()
	assert_eq(npc.state, BattleNpc.STATE_DYING, "die 后 Dying")
	assert_eq(eng.npc_list.size(), 0, "on_npc_die 移除")
	assert_false(npc.is_alive(), "die 后 not alive")
