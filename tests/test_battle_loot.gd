extends GutTest
# Phase 2.6 BattleLoot（照源 loot.lua:65-79 物理）。
# 验 update（抛物运动 + 右边界反弹 + life 衰减）+ on_tapped 终止。


class MockMonster:
	extends RefCounted
	var position: Vector2 = Vector2(700, 0)


func test_loot_physics_and_bounce() -> void:
	var monster := MockMonster.new()
	monster.position = Vector2(0, 0)
	var loot := BattleLoot.new("icon", "gold", monster, 1, 100)
	loot.update(0.1)
	assert_true(loot.position.x > 0.0, "x 推进")
	assert_true(loot.height > 0.0, "height 上升（velocity.z=300）")
	assert_true(loot.life < 0.6, "life 衰减")
	monster.position = Vector2(786, 0)  # 近右边界（BOUND_LIMIT=785）
	var loot2 := BattleLoot.new("icon", "gold", monster, 2, 100)
	loot2.update(0.033)  # 786>785 → 反弹
	assert_true(loot2.velocity.x < 0.0, "超边界 785 反弹 x 负向")


func test_loot_tap_terminates() -> void:
	var monster := MockMonster.new()
	var loot := BattleLoot.new("icon", "gold", monster, 1, 100)
	loot.on_tapped()
	assert_true(loot.terminated, "on_tapped 终止")
