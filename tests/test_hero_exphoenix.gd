extends GutTest
# Phase 2.7 ExPhoenix 英雄 hook 验证（照源 ExPhoenix.lua）。
# P0-3 回归：ult onAttackFrame hp==1 直接 die（照源 :187）；源 :175-186 护盾抵消是 Lua 作用域死代码
#   （buff/stype 是 :160-168 if 块内 local 离开不可见，:175 if buff then 引用全局 nil 恒 false）。


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
	var level: int = 1  # ExPhoenix apply 读（P1-10）
	var max_shield: int = 0  # ExPhoenix apply 设（P1-10）


# P0-3：counter!=1 + hp==1 + 有 shield buff（Buff31）→ 照源直接 die（与 Phoenix 同构修复）。
func test_exphoenix_ult_hp1_with_shield_dies() -> void:
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
	hero.skills["ExPhoenix_ult"] = ult
	BattleHeroRegistry.apply("battle/heroes/ExPhoenix", hero)
	var h: Callable = ult.hero_hooks["onAttackFrame"]
	h.call(ult)
	assert_eq(owner.died, 1, "P0-3：hp==1 + shield buff 照源直接 die（源 :175-186 抵消是死代码）")


# 对照：hp!=1 不 die。
func test_exphoenix_ult_hp_full_no_die() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	ult.attack_counter = 0
	var owner := MockOwner.new()
	owner.cm = MockCm.new()
	owner.hp = 100
	ult.caster = owner
	hero.skills["ExPhoenix_ult"] = ult
	BattleHeroRegistry.apply("battle/heroes/ExPhoenix", hero)
	var h: Callable = ult.hero_hooks["onAttackFrame"]
	h.call(ult)
	assert_eq(owner.died, 0, "hp!=1 不 die")


# counter==1 + hp==1：照源 die。
func test_exphoenix_ult_counter1_hp1_dies() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	ult.attack_counter = 1
	var owner := MockOwner.new()
	owner.cm = MockCm.new()
	owner.hp = 1
	ult.caster = owner
	hero.skills["ExPhoenix_ult"] = ult
	BattleHeroRegistry.apply("battle/heroes/ExPhoenix", hero)
	var h: Callable = ult.hero_hooks["onAttackFrame"]
	h.call(ult)
	assert_eq(owner.died, 1, "counter==1 + hp==1 照源 die")
