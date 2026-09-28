extends GutTest
# Phase 2.7 Phoenix 英雄 hook 验证（照源 Phoenix.lua）。
# P0-2 回归：ult onAttackFrame hp==1 直接 die（照源 :152）；源 :140-151 护盾抵消是 Lua 作用域死代码
#   （buff/stype 是 :125-133 if 块内 local 离开不可见，:140 if buff then 引用全局 nil 恒 false）。


class MockSkill:
	extends RefCounted
	var info: Dictionary = {}
	var hero_hooks: Dictionary = {}
	var caster: Variant = null
	var attack_counter: int = 0
	func _on_attack_frame_default() -> void: pass


class MockCm:
	extends RefCounted
	func lookup(_t: StringName, _c: String, _k: Variant) -> Variant:
		return {"ID": int(_k), "Name": str(_k), "HPR": 0}


class MockBuff:
	extends RefCounted
	var info: Dictionary = {}
	var shield: float = 100.0


class MockOwner:
	extends RefCounted
	var cm: Variant = null
	var attribs: Dictionary = {"HP": 1000}
	var hp: int = 1
	var buff_list: Array = []
	var died: int = 0
	func add_buff(_b: Variant, _c: Variant) -> void: pass
	func die(_src: Variant) -> void:
		died += 1


class MockHero:
	extends RefCounted
	var skills: Dictionary = {}
	var hero_hooks: Dictionary = {}


# P0-2：counter!=1 + hp==1 + 有 shield buff（Buff31）→ 照源直接 die。
# 修复前：buff128=null（counter!=1），shield_buff=buff31，absorption=stype(0)*0.8=0 < shield(100) → return 不 die（bug）。
# 修复后：hp==1 直接 die（源 :140-151 抵消是死代码不实现）。
func test_phoenix_ult_hp1_with_shield_dies() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	ult.attack_counter = 0
	var owner := MockOwner.new()
	owner.cm = MockCm.new()
	owner.hp = 1
	var b31 := MockBuff.new()
	b31.info["ID"] = 31
	b31.shield = 100.0
	owner.buff_list = [b31]
	ult.caster = owner
	hero.skills["Phoenix_ult"] = ult
	BattleHeroScripts.apply("battle/heroes/Phoenix", hero)
	var h: Callable = ult.hero_hooks["onAttackFrame"]
	h.call(ult)
	assert_eq(owner.died, 1, "P0-2：hp==1 + shield buff 照源直接 die（源 :140-151 抵消是死代码）")


# 对照：hp!=1 不 die（die 仅 hp==1 触发）。
func test_phoenix_ult_hp_full_no_die() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	ult.attack_counter = 0
	var owner := MockOwner.new()
	owner.cm = MockCm.new()
	owner.hp = 100
	ult.caster = owner
	hero.skills["Phoenix_ult"] = ult
	BattleHeroScripts.apply("battle/heroes/Phoenix", hero)
	var h: Callable = ult.hero_hooks["onAttackFrame"]
	h.call(ult)
	assert_eq(owner.died, 0, "hp!=1 不 die")


# counter==1 + hp==1：照源 die（counter==1 块创建 Buff128 HPR debuff + hp==1 die）。
func test_phoenix_ult_counter1_hp1_dies() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	ult.attack_counter = 1
	var owner := MockOwner.new()
	owner.cm = MockCm.new()
	owner.hp = 1
	ult.caster = owner
	hero.skills["Phoenix_ult"] = ult
	BattleHeroScripts.apply("battle/heroes/Phoenix", hero)
	var h: Callable = ult.hero_hooks["onAttackFrame"]
	h.call(ult)
	assert_eq(owner.died, 1, "counter==1 + hp==1 照源 die")


# P1-3（2026-09-28 审查）：lookup 返共享行时 HPR 改写不得污染 cm 表行
# （原直接在共享行上写 -HP×ratio，跨场次污染所有取该行建的 buff）。
class SharedRowCm:
	extends RefCounted
	var row: Dictionary = {"ID": 31, "Name": "phoenix_ult", "HPR": -0.05}
	func lookup(_t: StringName, _c: String, _k: Variant) -> Variant:
		return row


func test_ult_hpr_write_does_not_pollute_shared_row() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	ult.attack_counter = 1
	var owner := RecordingOwner.new()
	owner.cm = SharedRowCm.new()
	owner.hp = 100
	owner.attribs = {"HP": 5000}
	ult.caster = owner
	hero.skills["Phoenix_ult"] = ult
	BattleHeroScripts.apply("battle/heroes/Phoenix", hero)
	var h: Callable = ult.hero_hooks["onAttackFrame"]
	h.call(ult)
	assert_almost_eq(float((owner.cm as SharedRowCm).row.get("HPR", 0.0)), -0.05, 0.0001, "共享表行 HPR 保持原值")
	assert_eq(owner.added_buffs.size(), 1, "buff 已加")
	var b: Variant = owner.added_buffs[0]
	assert_almost_eq(float((b as BattleBuff).info.get("HPR", 0.0)), -750.0, 0.001, "buff 实例 HPR=-HP×0.15（局部副本）")


class RecordingOwner:
	extends RefCounted
	var cm: Variant = null
	var attribs: Dictionary = {"HP": 1000}
	var hp: int = 1
	var buff_list: Array = []
	var died: int = 0
	var added_buffs: Array = []
	func add_buff(b: Variant, _c: Variant) -> void:
		added_buffs.append(b)
	func die(_src: Variant) -> void:
		died += 1
