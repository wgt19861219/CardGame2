extends GutTest
# Phase 2.4 skill（照源 skill.lua 重翻，2026-06-30）。
# MockCaster/MockTarget/MockEngine duck-type 契约（照源 skill 协作者）。
# 伤害数值/暴击公式在单位侧 take_damage（Phase 2.2续，源 unit.lua:1252），此处 MockTarget.take_damage 桩返回 amount。

class MockEngine:
	extends RefCounted
	var rng: BattleRng
	var ticks: int = 0
	var mp_bonus: float = 1.0
	var alive: Array = []
	var unfrozen: int = 0
	func _init() -> void:
		rng = BattleRng.new(12345)
	func foreach_alive_unit(_camp: int) -> Array:
		return alive
	func unfreeze(_force: bool = false) -> void:
		unfrozen += 1
	func add_projectile(_p: Variant) -> void:
		pass  # Phase 2.6 子模块
	func add_chain(_c: Variant) -> void:
		pass  # Phase 2.6

class MockCaster:
	extends RefCounted
	var info: Dictionary = {}
	var attribs: Dictionary = {"AD": 100, "AP": 80, "HEAL": 0, "HIT": 0, "LFS": 0, "INT": 50, "HP": 1000, "CDR": 0}
	var buff_effects: Dictionary = {}
	var position: Vector2 = Vector2(100, 0)
	var direction: float = 1.0
	var focamp: int = -1
	var camp: int = 1
	var mp: float = 1000.0
	var level: int = 10
	var hp: float = 1000.0
	var manually_casting: bool = false
	var current_skill: Variant = null
	var global_cd: float = 0.0
	var engine: Variant = null
	var set_mp_log: Array = []
	var healed: Array = []
	func set_mp(v: float) -> void:
		mp = v
		set_mp_log.append(v)
	func set_action(_n: String, _l: bool, _i: bool) -> void:
		pass
	func idle() -> void:
		pass
	func take_heal(amount: float, field: String, _s: Variant) -> void:
		healed.append([amount, field])
	func is_alive() -> bool:
		return hp > 0
	func is_out_of_stage() -> bool:
		return false

class MockTarget:
	extends RefCounted
	var attribs: Dictionary = {"AD": 50, "AP": 50, "ARM": 0, "MR": 0, "DODG": 0, "HP": 500}
	var buff_effects: Dictionary = {}
	var position: Vector2 = Vector2(300, 0)
	var camp: int = -1
	var level: int = 10
	var hp: float = 500.0
	var manually_casting: bool = false
	var taken: Array = []
	var healed: Array = []
	var buffs: Array = []
	var knockups: Array = []
	func is_alive() -> bool:
		return hp > 0
	func take_damage(d: Dictionary) -> float:
		taken.append(d)
		return float(d.get("amount", 0))  # 桩：真实公式在单位侧 Phase 2.2续
	func take_heal(amount: float, field: String, _s: Variant) -> void:
		healed.append([amount, field])
	func add_buff(b: Variant, _c: Variant) -> void:
		buffs.append(b)
	func knockup(t: float, vec: Vector2) -> void:
		knockups.append([t, vec])

func _make_caster() -> MockCaster:
	var c := MockCaster.new()
	c.engine = MockEngine.new()
	return c

func _make_skill(overrides: Dictionary = {}) -> BattleSkill:
	var info: Dictionary = {"Damage Type": "AD", "Plus Ratio": 1.0, "Plus Attr": "AD", "Basic Num": 0}
	info.merge(overrides, true)
	return BattleSkill.new(info, _make_caster(), 1)

# 源 power（:531-537）：返 (power, crit_mod) 双值；power=Plus Ratio × attribs[Plus Attr] + Basic Num
func test_power() -> void:
	var s := _make_skill({"Plus Ratio": 2.0, "Plus Attr": "AD", "Basic Num": 10})
	var pr: Array = BattleSkillEffect.power(s, s.caster)
	assert_eq(float(pr[0]), 210.0, "power=2×100+10=210")
	assert_eq(float(pr[1]), 1.0, "crit_mod=CRIT%/100，默认 100→1.0")

# 源 takeEffectOn AD（:570-590）：触发 target.take_damage（crit_mod=CRIT%/100）
func test_take_effect_on_ad() -> void:
	var s := _make_skill({"Plus Ratio": 1.0, "Plus Attr": "AD", "Basic Num": 50, "CRIT%": 100})
	var t := MockTarget.new()
	BattleSkillEffect.take_effect_on(s, t)
	assert_eq(t.taken.size(), 1, "AD 命中 → take_damage")
	assert_eq(float(t.taken[0]["amount"]), 150.0, "amount=power=1×100+50")
	assert_eq(str(t.taken[0]["damage_type"]), "AD", "damage_type")

# 源 takeEffectOn 返 [succ, dmg]（:552 末尾 return true, dmg）— DP buff.update 周期累计 dmg 依赖。
func test_take_effect_on_returns_dmg() -> void:
	var s := _make_skill({"Plus Ratio": 1.0, "Plus Attr": "AD", "Basic Num": 50})
	var t := MockTarget.new()
	var r: Array = BattleSkillEffect.take_effect_on(s, t)
	assert_true(bool(r[0]), "命中成功 succ=true（r[0]）")
	assert_eq(float(r[1]), 150.0, "dmg 透传=power=1×100+50=150（r[1]）")

# 源 takeEffectOn Heal（:563-569）：take_heal(power×(1+HEAL/100))
func test_take_effect_on_heal() -> void:
	var s := _make_skill({"Damage Type": "Heal", "Plus Ratio": 1.0, "Plus Attr": "AD"})  # Basic Num 默认 0
	s.caster.attribs["HEAL"] = 50
	var t := MockTarget.new()
	BattleSkillEffect.take_effect_on(s, t)
	assert_eq(t.healed.size(), 1, "Heal → take_heal")
	assert_eq(float(t.healed[0][0]), 150.0, "power=1×100+0=100；100×(1+50/100)=150")
	assert_eq(t.taken.size(), 0, "Heal 无伤害")

# 源 takeEffectOn AD 闪避（:571-585）：dodg/(100+dodg) > rand → Miss
func test_take_effect_on_ad_dodge() -> void:
	var s := _make_skill({"Plus Ratio": 1.0, "Plus Attr": "AD"})
	var t := MockTarget.new()
	t.attribs["DODG"] = 999  # prob=999/1099≈0.91，几乎必 Miss
	BattleSkillEffect.take_effect_on(s, t)
	assert_eq(t.taken.size(), 0, "高 DODG → 闪避 Miss")

# 源 takeEffectOn（:610-623）：Buff ID + checkAddBuff 通过 → add_buff
func test_take_effect_on_buff_attach() -> void:
	var s := _make_skill({"Plus Ratio": 1.0, "Plus Attr": "AD", "Buff ID": 1, "buff_info": {"Name": "Stun", "Level Check Dice": 0}})
	var t := MockTarget.new()
	BattleSkillEffect.take_effect_on(s, t)
	assert_eq(t.buffs.size(), 1, "Buff 命中 → add_buff")

# 源 takeEffectOn（:624-637）：Knock Back > 0 → knockup
func test_take_effect_on_knockback() -> void:
	var s := _make_skill({"Plus Ratio": 1.0, "Plus Attr": "AD", "Knock Back": 50})
	var t := MockTarget.new()
	BattleSkillEffect.take_effect_on(s, t)
	assert_eq(t.knockups.size(), 1, "Knock Back → knockup")
	assert_eq(float(t.knockups[0][0]), 0.0, "Knock Up=0（仅 Back）")

# 源 takeEffectOn（:555）：invulnerable 免疫
func test_take_effect_on_invulnerable() -> void:
	var s := _make_skill({"Plus Ratio": 1.0, "Plus Attr": "AD"})
	var t := MockTarget.new()
	t.buff_effects["invulnerable"] = true
	BattleSkillEffect.take_effect_on(s, t)
	assert_eq(t.taken.size(), 0, "invulnerable 免疫")

# 源 canCastWithTarget（:255）：Cost MP > mp → mp
func test_can_cast_mp() -> void:
	var s := _make_skill({"Cost MP": 2000})
	var res := s.can_cast_with_target(MockTarget.new())
	assert_false(bool(res["ok"]), "mp 不足")
	assert_eq(str(res["reason"]), "mp")

# 源 canCastWithTarget（:258）：cd_remaining > 0 → cd
func test_can_cast_cd() -> void:
	var s := _make_skill({"Cost MP": 0})
	s.cd_remaining = 5.0
	var res := s.can_cast_with_target(MockTarget.new())
	assert_false(bool(res["ok"]), "cd 中")
	assert_eq(str(res["reason"]), "cd")

# 源 canCastWithTarget（:261）：stun
func test_can_cast_stun() -> void:
	var s := _make_skill({"Cost MP": 0})
	s.caster.buff_effects["stun"] = true
	var res := s.can_cast_with_target(MockTarget.new())
	assert_eq(str(res["reason"]), "stun")

# 源 affectedCamp（:182-185）：focamp × Affected Camp × -1
func test_affected_camp() -> void:
	var s := _make_skill({"Affected Camp": -1})
	assert_eq(s._affected_camp(), -1, "focamp=-1 × Affected Camp=-1 × -1 = -1")

# 源 SkillCreate（:72-77）：Target Type self → Target Camp 0
func test_target_type_self_sets_camp() -> void:
	var s := _make_skill({"Target Type": "self"})
	assert_eq(int(s.info.get("Target Camp", 99)), 0, "self → Target Camp 0")

# 源 testPointInShape（:474-487）
func test_point_in_shape_circle() -> void:
	assert_true(BattleSkillEffect.test_point_in_shape(Vector2(3, 0), "circle", 5, 0), "圆内")
	assert_false(BattleSkillEffect.test_point_in_shape(Vector2(6, 0), "circle", 5, 0), "圆外")

func test_point_in_shape_rectangle() -> void:
	assert_true(BattleSkillEffect.test_point_in_shape(Vector2(2, 0), "rectangle", 5, 4), "矩形内")
	assert_false(BattleSkillEffect.test_point_in_shape(Vector2(2, 3), "rectangle", 5, 4), "矩形外（|y|>2）")


# 源 testPointInShape:476 halfcircle：x>=0 且 x²+y²<=arg1²（右半圆）
func test_point_in_shape_halfcircle() -> void:
	assert_true(BattleSkillEffect.test_point_in_shape(Vector2(3, 0), "halfcircle", 5, 0), "右半圆内（x>0）")
	assert_false(BattleSkillEffect.test_point_in_shape(Vector2(-3, 0), "halfcircle", 5, 0), "左半外（x<0 排除）")
	assert_false(BattleSkillEffect.test_point_in_shape(Vector2(6, 0), "halfcircle", 5, 0), "圆外")


# 源 testPointInShape:477 quartercircle：x>=0 且 |y|<=x 且 x²+y²<=arg1²（右上 ±45° 扇形）
func test_point_in_shape_quartercircle() -> void:
	assert_true(BattleSkillEffect.test_point_in_shape(Vector2(3, 1), "quartercircle", 5, 0), "扇形内（|y|<x）")
	assert_false(BattleSkillEffect.test_point_in_shape(Vector2(1, 3), "quartercircle", 5, 0), "外（|y|>x）")
	assert_false(BattleSkillEffect.test_point_in_shape(Vector2(-3, 0), "quartercircle", 5, 0), "左侧外（x<0）")


# 源 takeEffectAt:494 AOE Origin=self → location=caster.position（忽略传入 location）
func test_take_effect_at_self_uses_caster_pos() -> void:
	var s := _make_skill({"Plus Ratio": 1.0, "Plus Attr": "AD", "Basic Num": 50, "Affected Camp": -1,
		"AOE Origin": "self", "AOE Shape": "circle", "Shape Arg1": 500.0})
	var t := MockTarget.new()
	t.camp = -1
	t.position = Vector2(s.caster.position.x + 10, s.caster.position.y)  # caster 附近 10px
	s.caster.engine.alive = [t]
	BattleSkillEffect.take_effect_at(s, Vector2(9999, 9999))  # 传远离 location，self 应回退 caster.pos
	assert_eq(t.taken.size(), 1, "AOE Origin=self → 用 caster.pos，附近目标命中（远离 location 被忽略）")


# 源 takeEffectOn:601 LFS 吸血：dmg×lfs/(100+lfs+level)×LFS%×0.01 → caster.take_heal
func test_take_effect_on_lfs_life_steal() -> void:
	var s := _make_skill({"Plus Ratio": 1.0, "Plus Attr": "AD", "Basic Num": 0, "LFS%": 100})
	s.caster.attribs["LFS"] = 100
	var t := MockTarget.new()
	t.level = 10
	BattleSkillEffect.take_effect_on(s, t)
	# power=1×100+0=100；heal=100×100/(100+100+10)×100×0.01=10000/210≈47.62
	assert_eq(s.caster.healed.size(), 1, "LFS%>0 → caster 吸血 take_heal")
	assert_almost_eq(float(s.caster.healed[0][0]), 100.0 * 100.0 / (100.0 + 100.0 + 10.0), 0.5, "吸血量=dmg×lfs/(100+lfs+level)")


# 源 takeEffectOn:571-585 No Dodge=true 跳过闪避判定（必中，高 DODG 仍命中）
func test_take_effect_on_no_dodge() -> void:
	var s := _make_skill({"Plus Ratio": 1.0, "Plus Attr": "AD", "No Dodge": true})
	var t := MockTarget.new()
	t.attribs["DODG"] = 999  # 正常 prob≈0.91 必闪
	BattleSkillEffect.take_effect_on(s, t)
	assert_eq(t.taken.size(), 1, "No Dodge=true → 跳过闪避判定，高 DODG 仍命中")


# 源 takeEffectOn:566 Affect MP=true → affect_field=mp（伤害打蓝量）
func test_take_effect_on_affect_mp() -> void:
	var s := _make_skill({"Plus Ratio": 1.0, "Plus Attr": "AD", "Basic Num": 50, "Affect MP": true})
	var t := MockTarget.new()
	BattleSkillEffect.take_effect_on(s, t)
	assert_eq(t.taken.size(), 1, "Affect MP 命中")
	assert_eq(str(t.taken[0]["field"]), "mp", "Affect MP → field=mp（打蓝）")


# 源 takeEffectOn Heal（:563-609）不 return，fall-through 到 :610 buff 命中（P0-1 回归）。
# 原 bug：Heal 分支提前 return 跳过 buff 命中，Bone_ult/HumanPriest_atk 治疗+buff 技能不施加 buff。
func test_take_effect_on_heal_with_buff() -> void:
	var s := _make_skill({"Damage Type": "Heal", "Plus Ratio": 1.0, "Plus Attr": "AD", "Buff ID": 1, "buff_info": {"Name": "HealBuff", "Level Check Dice": 0}})
	s.caster.attribs["HEAL"] = 50
	var t := MockTarget.new()
	BattleSkillEffect.take_effect_on(s, t)
	assert_eq(t.healed.size(), 1, "Heal → take_heal")
	assert_eq(t.buffs.size(), 1, "P0-1：Heal + Buff ID → fall-through buff 命中 add_buff（照源 :610-614）")
