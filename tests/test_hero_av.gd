extends GutTest
# Phase 2.7：AV 英雄 hook 验证（照源 AV.lua 5 hook 跨 3 技能）。
# 验证 hook 注册 + willCast 逻辑 + atk3 counter==0 查 Buff addBuff 链路（caster.cm.lookup→add_buff）+ counter==11 停止。


class MockSkill:
	extends RefCounted
	var info: Dictionary = {}
	var hero_hooks: Dictionary = {}
	var target: Variant = null
	var caster: Variant = null
	var attack_counter: int = 0
	func _start_default(_t: Variant) -> void: pass
	func _will_cast_default() -> bool: return true
	func _on_attack_frame_default() -> void: pass


class MockCaster:
	extends RefCounted
	var skills: Dictionary = {}
	var current_skill: Variant = null
	var direction: int = 1
	var position: Vector2 = Vector2.ZERO
	var walk_v: Vector2 = Vector2.ZERO
	var custom_data: Dictionary = {}
	var cm: Variant = null
	var added_buffs: Array = []
	func add_buff(_b: Variant, _c: Variant) -> Variant:
		added_buffs.append(_b)
		return null


class MockCm:
	extends RefCounted
	func lookup(_t: StringName, _c: String, _k: Variant) -> Variant:
		return {"Name": str(_k)}  # 假 buff row


class MockHero:
	extends RefCounted
	var skills: Dictionary = {}


# apply 后 5 hook 全注册（AV_ult start/createProjectile/willCast + AV_atk3 onAttackFrame + AV_atk2 createProjectile）。
func test_av_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["AV_ult"] = MockSkill.new()
	hero.skills["AV_atk3"] = MockSkill.new()
	hero.skills["AV_atk2"] = MockSkill.new()
	BattleHeroRegistry.apply("battle/heroes/AV", hero)
	var ult: MockSkill = hero.skills["AV_ult"]
	var atk3: MockSkill = hero.skills["AV_atk3"]
	var atk2: MockSkill = hero.skills["AV_atk2"]
	assert_true(ult.hero_hooks.has("start"), "AV_ult start")
	assert_true(ult.hero_hooks.has("createProjectile"), "AV_ult createProjectile")
	assert_true(ult.hero_hooks.has("willCast"), "AV_ult willCast")
	assert_true(atk3.hero_hooks.has("onAttackFrame"), "AV_atk3 onAttackFrame")
	assert_true(atk2.hero_hooks.has("createProjectile"), "AV_atk2 createProjectile")


# willCast：current_skill==AV_atk3 返 false（不放该技能），否则 true。
func test_av_will_cast() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	var atk3 := MockSkill.new()
	var caster := MockCaster.new()
	caster.skills["AV_atk3"] = atk3
	ult.caster = caster
	hero.skills["AV_ult"] = ult
	hero.skills["AV_atk3"] = atk3
	BattleHeroRegistry.apply("battle/heroes/AV", hero)
	var h: Callable = ult.hero_hooks["willCast"]
	caster.current_skill = atk3
	assert_false(h.call(ult), "current==AV_atk3 → false")
	caster.current_skill = null
	assert_true(h.call(ult), "current!=AV_atk3 → true")


# atk3 counter==0：记录 AVultposition + 查 Buff + addBuff + basefunc（caster.cm.lookup→add_buff 链路）。
func test_av_atk3_counter0_addbuff() -> void:
	var hero := MockHero.new()
	var atk3 := MockSkill.new()
	atk3.info["Script Arg1"] = "burn"
	atk3.attack_counter = 0
	var caster := MockCaster.new()
	caster.cm = MockCm.new()
	caster.skills["AV_atk3"] = atk3
	atk3.caster = caster
	hero.skills["AV_atk3"] = atk3
	BattleHeroRegistry.apply("battle/heroes/AV", hero)
	var h: Callable = atk3.hero_hooks["onAttackFrame"]
	h.call(atk3)
	assert_true(caster.custom_data.has("AVultposition"), "AVultposition 记录")
	assert_eq(caster.added_buffs.size(), 1, "addBuff 调用一次")


# atk3 counter==11：停止冲撞（walk_v=0 + position 恢复 AVultposition），不调 basefunc/addBuff。
func test_av_atk3_counter11_stop() -> void:
	var hero := MockHero.new()
	var atk3 := MockSkill.new()
	atk3.attack_counter = 11
	var caster := MockCaster.new()
	var saved_pos := Vector2(100, 50)
	caster.custom_data["AVultposition"] = saved_pos
	caster.position = Vector2(500, 0)
	atk3.caster = caster
	hero.skills["AV_atk3"] = atk3
	BattleHeroRegistry.apply("battle/heroes/AV", hero)
	var h: Callable = atk3.hero_hooks["onAttackFrame"]
	h.call(atk3)
	assert_eq(caster.walk_v, Vector2.ZERO, "walk_v 清零")
	assert_eq(caster.position, saved_pos, "position 恢复 AVultposition")
	assert_eq(caster.added_buffs.size(), 0, "counter==11 不 addBuff")
