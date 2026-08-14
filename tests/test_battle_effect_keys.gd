extends GutTest
# 阶段三 T1（2026-08-14）：BattleEffectKeys 注册表守卫。
# 断言常量值与历史字面量逐字一致（含源拼写 "immoblilize"）——值是数据事实 key，
# 改值即破坏 buff_effects 字典兼容；断言蕴含/负面表覆盖完整（16 key 全登记）。


func test_key_values_preserve_historical_literals() -> void:
	assert_eq(BattleEffectKeys.FROZEN, "frozen")
	assert_eq(BattleEffectKeys.STUN, "stun")
	assert_eq(BattleEffectKeys.IMMOBILIZE, "immoblilize", "源头拼写如此，值不可纠正")
	assert_eq(BattleEffectKeys.SILENCE, "silence")
	assert_eq(BattleEffectKeys.DISARM, "disarm")
	assert_eq(BattleEffectKeys.DISABLE_AI, "disableAI")
	assert_eq(BattleEffectKeys.IMPRISONMENT, "imprisonment")
	assert_eq(BattleEffectKeys.UNTARGETABLE, "untargetable")
	assert_eq(BattleEffectKeys.INVULNERABLE, "invulnerable")
	assert_eq(BattleEffectKeys.UNCONTROLLABLE, "uncontrollable")
	assert_eq(BattleEffectKeys.ENCHANTED, "enchanted")
	assert_eq(BattleEffectKeys.BUILDING, "building")
	assert_eq(BattleEffectKeys.STABLE, "stable")
	assert_eq(BattleEffectKeys.FIX, "fix")
	assert_eq(BattleEffectKeys.UNHEAL, "unheal")
	assert_eq(BattleEffectKeys.NO_HPR, "noHPR")


func test_inclusions_covers_all_keys() -> void:
	var all_keys: Array[String] = [
		BattleEffectKeys.FROZEN, BattleEffectKeys.STUN, BattleEffectKeys.IMMOBILIZE,
		BattleEffectKeys.SILENCE, BattleEffectKeys.DISARM, BattleEffectKeys.DISABLE_AI,
		BattleEffectKeys.IMPRISONMENT, BattleEffectKeys.UNTARGETABLE,
		BattleEffectKeys.INVULNERABLE, BattleEffectKeys.UNCONTROLLABLE,
		BattleEffectKeys.ENCHANTED, BattleEffectKeys.BUILDING, BattleEffectKeys.STABLE,
		BattleEffectKeys.FIX, BattleEffectKeys.UNHEAL, BattleEffectKeys.NO_HPR,
	]
	for k in all_keys:
		assert_true(BattleEffectKeys.INCLUSIONS.has(k), "蕴含表缺 key：%s" % k)
	assert_eq(BattleEffectKeys.INCLUSIONS.size(), all_keys.size(), "蕴含表无多余 key")


func test_negative_is_subset_of_keys() -> void:
	for neg in BattleEffectKeys.NEGATIVE:
		assert_true(BattleEffectKeys.INCLUSIONS.has(neg), "负面表 key 不在蕴含表：%s" % neg)


# 行为等价抽查：蕴含递归挂全（stun → immoblilize/silence/disarm/disableAI）+ uncontrollable 清负面
# owner 只需 duck-type 提供 buff_effects 字典（apply_effect 唯一触点）。
class FakeOwner:
	extends RefCounted
	var buff_effects: Dictionary = {}


func test_apply_effect_inclusion_chain() -> void:
	var owner := FakeOwner.new()
	var buff := BattleBuff.new({"Name": "st", "Control Effects": []}, owner, null)
	buff.apply_effect(BattleEffectKeys.STUN)
	for expected in [BattleEffectKeys.STUN, BattleEffectKeys.IMMOBILIZE, BattleEffectKeys.SILENCE, BattleEffectKeys.DISARM, BattleEffectKeys.DISABLE_AI]:
		assert_true(bool(owner.buff_effects.get(expected, false)), "蕴含应挂上：%s" % expected)


func test_apply_uncontrollable_clears_negatives() -> void:
	var owner := FakeOwner.new()
	var buff := BattleBuff.new({"Name": "st", "Control Effects": []}, owner, null)
	buff.apply_effect(BattleEffectKeys.STUN)
	buff.apply_effect(BattleEffectKeys.UNCONTROLLABLE)
	assert_true(bool(owner.buff_effects.get(BattleEffectKeys.UNCONTROLLABLE, false)), "uncontrollable 自身挂上")
	for neg in BattleEffectKeys.NEGATIVE:
		assert_false(bool(owner.buff_effects.get(neg, false)), "负面应被清除：%s" % neg)
