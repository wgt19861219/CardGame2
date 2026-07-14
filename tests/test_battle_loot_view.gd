extends GutTest
# Phase 4 loot 掉落物 View 测试（2026-07-02）。
# 验 BattleLootView：create 初始位置 / update 物理推进（x+y+h 三维 + 重力）/ 右边界反弹 / terminated 后不再 update。
# MockUnit duck-type monster.position。chest 资源已就位（_load_sprite 实载）。

class MockUnit:
	extends RefCounted
	var position: Vector2 = Vector2(100, 0)


func _make_layer() -> Node2D:
	var layer := Node2D.new()
	add_child(layer)
	return layer


func test_create_initial_position() -> void:
	var monster := MockUnit.new()
	var layer := _make_layer()
	var loot: BattleLootView = BattleLootView.create(null, "gold", monster, 1, 100, layer)
	assert_not_null(loot, "loot 应创建")
	# _update_physics_and_sync(0)：logic(100,0) + height 0 → to_godot(100,265)=(180,295)
	assert_eq(loot.position, BattleViewCoords.to_view_position(100.0, 0.0, 0.0), "初始位置 = to_view_position(100,0,0)")
	loot.queue_free()
	layer.queue_free()


func test_update_advances_physics() -> void:
	var monster := MockUnit.new()
	var layer := _make_layer()
	var loot: BattleLootView = BattleLootView.create(null, "gold", monster, 1, 100, layer)
	loot.update(0.1)
	# idx=1 → vel_x=100；vel_y=-100；vel_z=300；dt=0.1
	# logic: x=110, y=-10；height=30；view = to_godot(110,285) = (190,275)
	var expected: Vector2 = BattleViewCoords.to_view_position(110.0, -10.0, 30.0)
	assert_eq(loot.position, expected, "update 物理：x+10 / y-10 / height+30")
	loot.queue_free()
	layer.queue_free()


func test_bounce_at_right_boundary() -> void:
	var monster := MockUnit.new()
	var layer := _make_layer()
	var loot: BattleLootView = BattleLootView.create(null, "gold", monster, 1, 100, layer)
	loot._logic_pos.x = 800.0   # > BOUNCE_X(785)
	loot._vel_x = 100.0
	loot.update(0.016)
	# 源 :71 vx > 0 且 x > 785-bound → vx *= -1.5 → 100*-1.5 = -150
	assert_eq(loot._vel_x, -150.0, "右边界反弹 vel_x 100 → -150")
	loot.queue_free()
	layer.queue_free()


func test_terminated_loot_skips_update() -> void:
	var monster := MockUnit.new()
	var layer := _make_layer()
	var loot: BattleLootView = BattleLootView.create(null, "gold", monster, 1, 100, layer)
	loot.on_auto_collect()
	assert_true(loot.is_terminated(), "auto_collect 后 terminated")
	var lp: Vector2 = loot._logic_pos
	loot.update(0.1)
	assert_eq(loot._logic_pos, lp, "terminated 后 _logic_pos 不再推进（update 提前 return）")
	loot.queue_free()
	layer.queue_free()
