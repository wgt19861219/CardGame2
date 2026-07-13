extends GutTest
# P1-5：BattleEngineBall.deliver_ball 遍历同阵营单位调 show_ball（照源 battle_engine.lua:1763-1770）。


class MockUnit:
	extends RefCounted
	var camp: int = 1
	var show_ball: Variant = null
	var ball_calls: Array = []
	# deliver_ball 调 cb.call(u, unit, skill, idx) → _on_show(self=绑定实例, kael=u, deliverer=unit, skill, idx)
	func _on_show(kael: Variant, deliverer: Variant, skill: Variant, idx: int) -> void:
		kael.ball_calls.append([deliverer, skill, idx])
	func _init(c: int = 1, has_ball: bool = false) -> void:
		camp = c
		if has_ball:
			show_ball = Callable(self, "_on_show")


class MockEngine:
	extends RefCounted
	var unit_list: Array = []


# P1-5：deliver_ball 遍历同阵营 + 有 show_ball 的单位调；异阵营 / 无 show_ball 不调。
func test_deliver_ball_calls_same_camp_show_ball() -> void:
	var eng := MockEngine.new()
	var kael := MockUnit.new(1, true)  # 同阵营 + show_ball
	var enemy := MockUnit.new(-1, true)  # 异阵营 + show_ball
	var ally_no_ball := MockUnit.new(1, false)  # 同阵营无 show_ball
	eng.unit_list = [kael, enemy, ally_no_ball]
	var deliverer := MockUnit.new(1, false)
	BattleEngineBall.deliver_ball(eng, deliverer, "skill1", 1)
	assert_eq(kael.ball_calls.size(), 1, "同阵营 Kael show_ball 被调")
	assert_eq(enemy.ball_calls.size(), 0, "异阵营不调")
	assert_eq(ally_no_ball.ball_calls.size(), 0, "同阵营无 show_ball 不调")
