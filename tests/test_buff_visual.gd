extends GutTest
const EmitStub = preload("res://tests/helpers/battle_emit_stub.gd")
# Phase 4 buff 视觉事件测试（阶段三 T4 改写：on_added_client/freeze/on_removed 产出 BattleEvent 队列断言）。
# Logic 不再持 actor；MockOwner 挂真 BattleEngine 收事件，drain 后按事件类型/字段断言。

class MockOwner extends EmitStub:
	var camp: int = 0
	var buff_effects: Dictionary = {}
	var attribs: Dictionary = {}
	var config: Dictionary = {}
	var hp: int = 1000
	var dPSStatisticsRatio: float = 1.0
	var dmg_statistics: float = 0.0
	func remove_buff(_b: Variant) -> void: pass


func _make_owner() -> MockOwner:
	var o := MockOwner.new()
	o.engine = BattleEngine.new()
	return o


func _make_caster() -> MockOwner:
	return _make_owner()


func _popups(o: MockOwner) -> Array:
	var out: Array = []
	for e in (o.engine as BattleEngine).drain_events():
		if e.type == BattleEvent.Type.POPUP:
			out.append(e)
	return out


func test_on_added_client_effect() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "Frozen", "Effect": "eff_buff_CM_atk2.cha"}, owner, _make_caster())
	b.on_added_client()
	var events: Array[BattleEvent] = (owner.engine as BattleEngine).drain_events()
	assert_eq(events.size(), 1, "Effect 字段仅产 1 条事件")
	assert_eq(events[0].type, BattleEvent.Type.ADD_EFFECT, "应是 ADD_EFFECT")
	assert_eq(events[0].text, "eff_buff_CM_atk2.cha")
	assert_eq(b.effect_id, 1, "effect_id 应标记为有 effect")


func test_on_added_client_shader() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "Slow", "Shader": "FrozenShader"}, owner, _make_caster())
	b.on_added_client()
	var events: Array[BattleEvent] = (owner.engine as BattleEngine).drain_events()
	assert_eq(events.size(), 1, "Shader 字段仅产 1 条事件")
	assert_eq(events[0].type, BattleEvent.Type.SHADER_PUSH, "应是 SHADER_PUSH")
	assert_eq(events[0].text, "FrozenShader")
	assert_true(b.shader_id > 0, "shader_id 应记录关联 token")


func test_on_added_client_shader_remove_token_consistent() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "Slow", "Shader": "StoneShader"}, owner, _make_caster())
	b.on_added_client()
	b.on_removed()
	var events: Array[BattleEvent] = (owner.engine as BattleEngine).drain_events()
	assert_eq(events.size(), 2, "PUSH + REMOVE 两条")
	assert_eq(events[1].type, BattleEvent.Type.SHADER_REMOVE)
	assert_eq(int(events[1].value), int(events[0].value), "REMOVE token 与 PUSH 一致")
	assert_eq(b.shader_id, 0, "on_removed 后 shader_id 归零")


func test_on_added_client_popup_ad() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "ADBuff", "AD": 50}, owner, _make_caster())
	b.on_added_client()
	var popups := _popups(owner)
	assert_eq(popups.size(), 1, "AD>0 应触发飘字事件")
	assert_eq(popups[0].text, "inc_attack", "AD>0 应是 inc_attack")
	assert_eq(popups[0].color, "blue", "player camp 应 blue")
	assert_eq(popups[0].text2, "text", "buff 飘字 style=text")


func test_on_added_client_popup_text_override() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "Silence", "AD": 50, "Popup Text": BattleEffectKeys.SILENCE}, owner, _make_caster())
	b.on_added_client()
	var popups := _popups(owner)
	assert_eq(popups.size(), 1)
	assert_eq(popups[0].text, BattleEffectKeys.SILENCE, "Popup Text 应覆盖 AD 飘字")


func test_on_removed_clears_effect() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "Frozen", "Effect": "eff_buff_CM_atk2.cha"}, owner, _make_caster())
	b.on_added_client()
	(owner.engine as BattleEngine).drain_events()
	b.on_removed()
	var events: Array[BattleEvent] = (owner.engine as BattleEngine).drain_events()
	assert_eq(events.size(), 1, "移除仅产 REMOVE_EFFECT")
	assert_eq(events[0].type, BattleEvent.Type.REMOVE_EFFECT)
	assert_eq(events[0].text, "eff_buff_CM_atk2.cha")


func test_freeze_tint_event() -> void:
	var unit := BattleEntity.new()
	unit.engine = BattleEngine.new()
	unit.freeze()
	var events: Array[BattleEvent] = (unit.engine as BattleEngine).drain_events()
	assert_eq(events.size(), 1, "freeze 产 1 条 TINT")
	assert_eq(events[0].rgb, Vector3(0.4, 0.4, 0.4), "freeze tint(0.4) 变暗")
	assert_true(unit.frozen_actor, "frozen_actor 应 true")


func test_unfreeze_tint_event() -> void:
	var unit := BattleEntity.new()
	unit.engine = BattleEngine.new()
	unit.freeze()
	(unit.engine as BattleEngine).drain_events()
	unit.unfreeze()
	var events: Array[BattleEvent] = (unit.engine as BattleEngine).drain_events()
	assert_eq(events.size(), 1, "unfreeze 产 1 条 TINT")
	assert_eq(events[0].rgb, Vector3(2.5, 2.5, 2.5), "unfreeze tint(2.5)（View 侧 clamp 到 WHITE）")
	assert_false(unit.frozen_actor, "frozen_actor 应 false")


func test_freeze_no_repeat_tint() -> void:
	var unit := BattleEntity.new()
	unit.engine = BattleEngine.new()
	unit.freeze()
	unit.freeze()  # 重复 freeze 不应重复 tint
	assert_eq((unit.engine as BattleEngine).drain_events().size(), 1, "重复 freeze 仅 1 条 TINT")
