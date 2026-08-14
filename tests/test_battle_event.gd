extends GutTest
# 阶段三 T4-B1（2026-08-14）：BattleEvent 事件队列机制守卫。
# Logic 表现出口唯一化——实体 emit 糖方法经 engine.events 入队，View drain 取走清空。


func test_emit_without_engine_no_crash() -> void:
	var u := BattleEntity.new()
	u.emit_popup("100", "red")   # headless 裸实体（engine null）静默丢弃，不崩
	assert_true(true)

func test_drain_returns_and_clears() -> void:
	var eng := BattleEngine.new()
	var u := BattleEntity.new()
	u.engine = eng
	u.emit_popup("100", "red", true, "damage")
	u.emit_add_effect("eff_buff_burn", 2)
	var batch: Array[BattleEvent] = eng.drain_events()
	assert_eq(batch.size(), 2, "drain 取走 2 条")
	assert_eq(eng.drain_events().size(), 0, "二次 drain 为空（已清）")
	assert_eq(batch[0].type, BattleEvent.Type.POPUP)
	assert_eq(batch[0].text, "100")
	assert_eq(batch[0].color, "red")
	assert_true(batch[0].flag, "crit 透传")
	assert_eq(batch[0].text2, "damage", "style 透传")
	assert_eq(batch[1].type, BattleEvent.Type.ADD_EFFECT)
	assert_eq(batch[1].text, "eff_buff_burn")
	assert_eq(int(batch[1].value), 2, "zorder 透传")

func test_reset_battle_clears_events() -> void:
	var eng := BattleEngine.new()
	var u := BattleEntity.new()
	u.engine = eng
	u.emit_tint(0.4, 0.4, 0.4)
	eng.reset_battle()
	assert_eq(eng.events.size(), 0, "重置后队列清空")

func test_event_unit_binding() -> void:
	var eng := BattleEngine.new()
	var u := BattleEntity.new()
	u.engine = eng
	u.emit_shake(10.0, 0.5, 3)
	var e: BattleEvent = eng.drain_events()[0]
	assert_eq(e.unit, u, "事件绑定主体单位")
	assert_eq(e.type, BattleEvent.Type.SHAKE)
	assert_eq(e.value, 10.0)
	assert_eq(e.value2, 0.5)
	assert_eq(int(e.value3), 3)
