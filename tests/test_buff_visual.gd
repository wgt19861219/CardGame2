extends GutTest
# Phase 4 buff 视觉接入测试：on_added_client（Effect/Shader/飘字）+ freeze tint + on_removed 清理。
# MockActor duck-type 契约（add_effect/remove_effect/push_shader/remove_shader/tint/spawn_popup/set_shader_modulate）。

class MockActor:
	extends RefCounted
	var effects: Dictionary = {}
	var shader_stack: Array[String] = []
	var modulate: Color = Color.WHITE
	var popups: Array = []
	const SHADER_COLORS: Dictionary = {
		"FrozenShader": Color(0.6, 0.7, 1.0), "StoneShader": Color(0.5, 0.5, 0.5),
		"PoisonShader": Color(0.5, 1.0, 0.5), "BanishShader": Color(1.0, 0.5, 0.5, 0.5),
		"InvisibleShader": Color(1.0, 1.0, 1.0, 0.3), "IceShader": Color(0.5, 0.8, 1.0),
	}
	func add_effect(name: String, z: int = 0) -> void:
		effects[name] = {zorder = z}
	func remove_effect(name: String) -> void:
		effects.erase(name)
	func push_shader(shader: String) -> int:
		shader_stack.append(shader)
		modulate = SHADER_COLORS.get(shader, Color.WHITE)
		return shader_stack.size()
	func remove_shader(id: int) -> void:
		if id >= 1 and id <= shader_stack.size():
			shader_stack[id - 1] = ""
			while shader_stack.size() > 0 and shader_stack[-1] == "":
				shader_stack.pop_back()
		modulate = SHADER_COLORS.get(shader_stack[-1], Color.WHITE) if shader_stack.size() > 0 else Color.WHITE
	func tint(r: float, g: float, b: float) -> void:
		modulate = Color(clampf(r, 0, 1), clampf(g, 0, 1), clampf(b, 0, 1))
	func set_shader_modulate(c: Color) -> void:
		modulate = c
	func spawn_popup(text: String, color: String, crit: bool = false, style: String = "damage") -> void:
		popups.append({text = text, color = color, crit = crit, style = style})
	# has_method 继承 Object 原生（MockActor 定义了所有方法，has_method 会返回 true）

class MockOwner:
	extends RefCounted
	var actor: Variant = null
	var camp: int = 0
	var buff_effects: Dictionary = {}
	var attribs: Dictionary = {}
	var config: Dictionary = {}
	var hp: int = 1000
	var dPSStatisticsRatio: float = 1.0
	var dmg_statistics: float = 0.0
	var engine: Variant = null
	func remove_buff(_b: Variant) -> void: pass


func _make_owner() -> MockOwner:
	var o := MockOwner.new()
	o.actor = MockActor.new()
	return o


func _make_caster() -> MockOwner:
	return MockOwner.new()


func test_on_added_client_effect() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "Frozen", "Effect": "eff_buff_CM_atk2.cha"}, owner, _make_caster())
	b.on_added_client()
	assert_true(owner.actor.effects.has("eff_buff_CM_atk2.cha"), "Effect 字段应触发 add_effect")
	assert_eq(b.effect_id, 1, "effect_id 应标记为有 effect")


func test_on_added_client_shader() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "Slow", "Shader": "FrozenShader"}, owner, _make_caster())
	b.on_added_client()
	assert_eq(owner.actor.shader_stack.size(), 1, "Shader 字段应 push_shader")
	assert_eq(b.shader_id, 1, "shader_id 应记录栈 ID")


func test_on_added_client_popup_ad() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "ADBuff", "AD": 50}, owner, _make_caster())
	b.on_added_client()
	assert_eq(owner.actor.popups.size(), 1, "AD>0 应触发飘字")
	assert_eq(owner.actor.popups[0].text, "inc_attack", "AD>0 应是 inc_attack")
	assert_eq(owner.actor.popups[0].color, "blue", "player camp 应 blue")
	assert_eq(owner.actor.popups[0].style, "text", "buff 飘字 style=text")


func test_on_added_client_popup_text_override() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "Silence", "AD": 50, "Popup Text": "silence"}, owner, _make_caster())
	b.on_added_client()
	assert_eq(owner.actor.popups.size(), 1)
	assert_eq(owner.actor.popups[0].text, "silence", "Popup Text 应覆盖 AD 飘字")


func test_on_removed_clears_effect() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "Frozen", "Effect": "eff_buff_CM_atk2.cha"}, owner, _make_caster())
	b.on_added_client()
	assert_true(owner.actor.effects.size() > 0, "添加后应有 effect")
	b.on_removed()
	assert_false(owner.actor.effects.has("eff_buff_CM_atk2.cha"), "移除后应清 effect")


func test_on_removed_restores_modulate() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "Slow", "Shader": "StoneShader"}, owner, _make_caster())
	b.on_added_client()
	assert_ne(owner.actor.modulate, Color.WHITE, "Shader 应改 modulate")
	b.on_removed()
	assert_eq(owner.actor.shader_stack.size(), 0, "移除后 shader 栈空")


func test_freeze_tint() -> void:
	var owner := _make_owner()
	var unit := BattleEntity.new()
	unit.actor = owner.actor
	unit.freeze()
	assert_eq(owner.actor.modulate, Color(0.4, 0.4, 0.4), "freeze 应 tint(0.4) 变暗")
	assert_true(unit.frozen_actor, "frozen_actor 应 true")


func test_unfreeze_tint() -> void:
	var owner := _make_owner()
	var unit := BattleEntity.new()
	unit.actor = owner.actor
	unit.freeze()
	unit.unfreeze()
	# tint(2.5) 被 clamp 到 1.0 = WHITE
	assert_eq(owner.actor.modulate, Color.WHITE, "unfreeze 应 tint(2.5) clamp 到 WHITE")
	assert_false(unit.frozen_actor, "frozen_actor 应 false")


func test_freeze_no_repeat_tint() -> void:
	var owner := _make_owner()
	var unit := BattleEntity.new()
	unit.actor = owner.actor
	unit.freeze()
	unit.freeze()  # 重复 freeze 不应重复 tint
	assert_eq(owner.actor.modulate, Color(0.4, 0.4, 0.4), "重复 freeze 不应改变 tint")
