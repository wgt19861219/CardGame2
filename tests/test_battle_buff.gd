extends GutTest
# Phase 2.3 buff（照源 buff.lua 重翻，2026-06-30）。
# MockOwner duck-type 契约（attribs/buff_effects/config/hp/dPSStatisticsRatio/dmg_statistics/camp/engine/remove_buff/push_puppet/remove_puppet）。

class MockOwner:
	extends RefCounted
	var attribs: Dictionary = {"AD": 100, "HP": 1000}
	var buff_effects: Dictionary = {}
	var config: Dictionary = {"hp_mod": 1.0}
	var hp: int = 1000
	var dPSStatisticsRatio: float = 1.0  # 源 :208 驼峰（与 BattleUnit 一致；蛇形 get 大小写敏感失效）
	var dmg_statistics: float = 0.0  # 源 buff.lua:40 浮点累加记入 caster
	var camp: int = 1
	var engine: Variant = null
	var removed_buffs: Array = []
	var pushed_puppets: Array = []
	func remove_buff(b: Variant) -> void:
		removed_buffs.append(b)
	func push_puppet(p: String) -> int:
		pushed_puppets.append(p)
		return pushed_puppets.size()
	func remove_puppet(_id: int) -> void:
		pass

func _make_owner() -> MockOwner:
	return MockOwner.new()

func _make_caster() -> MockOwner:
	return MockOwner.new()

# 源 BuffCreate（buff.lua:8-28）：timer/shield 从 info 读取
func test_create_reads_timer_and_shield() -> void:
	var b := BattleBuff.new({"Name": "Stun3", "Time": 3.0}, _make_owner(), _make_caster())
	assert_eq(b.name, "Stun3", "name")
	assert_true(b.has_timer, "Time>0 → has_timer")
	assert_eq(b.timer, 3.0, "timer=Time")
	assert_false(b.has_shield, "无 Shield Value")

func test_create_shield_value() -> void:
	var b := BattleBuff.new({"Name": "Sh", "Shield Value": 500, "Shield Type": "AD"}, _make_owner(), _make_caster())
	assert_true(b.has_shield, "Shield Value>0 → has_shield")
	assert_eq(b.shield, 500.0, "hp_mod=1 → shield 不缩放")

# 源 apply（buff.lua:90-108）：属性加成 info[name]
func test_apply_adds_attribs() -> void:
	var owner := _make_owner()
	BattleBuff.new({"Name": "ADBuff", "AD": 50}, owner, _make_caster()).apply()
	assert_eq(int(owner.attribs["AD"]), 150, "AD +50")

# 源 applyEffect（buff.lua:137-154）：stun 蕴含 immoblilize/silence/disarm/disableAI
func test_apply_stun_inclusions() -> void:
	var owner := _make_owner()
	BattleBuff.new({"Name": "S", "Control Effects": ["stun"]}, owner, _make_caster()).apply()
	assert_true(bool(owner.buff_effects.get("stun")), "stun")
	assert_true(bool(owner.buff_effects.get("silence")), "蕴含 silence")
	assert_true(bool(owner.buff_effects.get("disarm")), "蕴含 disarm")
	assert_true(bool(owner.buff_effects.get("immoblilize")), "蕴含 immoblilize（源拼写）")
	assert_true(bool(owner.buff_effects.get("disableAI")), "蕴含 disableAI")

# 源 applyEffect uncontrollable 清负面（buff.lua:149-153）
func test_uncontrollable_clears_negative() -> void:
	var owner := _make_owner()
	owner.buff_effects["stun"] = true
	BattleBuff.new({"Name": "U", "Control Effects": ["uncontrollable"]}, owner, _make_caster()).apply()
	assert_true(bool(owner.buff_effects.get("uncontrollable")), "uncontrollable")
	assert_false(owner.buff_effects.has("stun"), "清除负面 stun")

# 源 onDamaged（buff.lua:250-275）：shield 抵伤（Shield Type 匹配）
func test_on_damaged_shield() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "S", "Shield Value": 100, "Shield Type": "AD"}, owner, _make_caster())
	assert_eq(b.on_damaged(60, "AD"), 0.0, "AD 伤被 AD shield 全抵")
	assert_eq(b.shield, 40.0, "shield 剩 40")
	var overflow := b.on_damaged(50, "AD")
	assert_eq(int(overflow), 10, "超 shield 部分穿透（-shield=10）")
	assert_eq(owner.removed_buffs.size(), 1, "shield 破后 remove_buff")

# 源 onDamaged：Shield Type 不匹配 → 不抵
func test_on_damaged_type_mismatch() -> void:
	var b := BattleBuff.new({"Name": "S", "Shield Value": 100, "Shield Type": "AD"}, _make_owner(), _make_caster())
	assert_eq(b.on_damaged(60, "AP"), 60.0, "AP 伤不被 AD shield 抵")

# 源 update（buff.lua:34-49）：timer 到期 removeBuff
func test_update_timer_expiry() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "T", "Time": 1.0}, owner, _make_caster())
	b.update(0.5)
	assert_eq(owner.removed_buffs.size(), 0, "未到期不 remove")
	b.update(0.6)
	assert_eq(owner.removed_buffs.size(), 1, "到期 remove_buff")

# 源 checkAddBuff（buff.lua:308-314）：Level Check Dice=0 总通过
func test_check_add_buff_dice_zero_passes() -> void:
	var rng := BattleRng.new(12345)
	assert_true(bool(BattleBuff.check_add_buff({"Name": "X", "Level Check Dice": 0}, 10, 10, {}, rng)[0]), "dice=0 总通过（P1-2 check_add_buff 返 [bool, reason]）")


# P1-2：_check_resist_attribute 返 [bool, reason]，抗性抵抗 reason="resist"（源 buff.lua:286 多返回值）
func test_check_resist_attribute_returns_resist_reason() -> void:
	var rng := BattleRng.new(12345)
	var res: Array = BattleBuff._check_resist_attribute({"Resist Attribute": "RES"}, {"RES": 200.0}, rng)
	assert_false(bool(res[0]), "高抗性 200（rand<200/100=2.0 恒 true）→ 抵抗")
	assert_eq(str(res[1]), "resist", "reason=resist（P1-2）")

# 源 isCrlEftConflictWithUncontrollable（buff.lua:111-121）
func test_is_negative_conflict() -> void:
	var b_neg := BattleBuff.new({"Name": "S", "Control Effects": ["stun"]}, _make_owner(), _make_caster())
	assert_true(b_neg.is_negative_conflict_uncontrollable(), "含 stun 负面 → 冲突")
	var b_neu := BattleBuff.new({"Name": "B", "Control Effects": ["building"]}, _make_owner(), _make_caster())
	assert_false(b_neu.is_negative_conflict_uncontrollable(), "building 非负面")


# 源 applyEffect frozen（EFFECT_INCLUSIONS:13 递归）：frozen 蕴含 stun（stun 递归含 immoblilize/silence/disarm/disableAI）
func test_apply_frozen_inclusions() -> void:
	var owner := _make_owner()
	BattleBuff.new({"Name": "F", "Control Effects": ["frozen"]}, owner, _make_caster()).apply()
	assert_true(bool(owner.buff_effects.get("frozen")), "frozen")
	assert_true(bool(owner.buff_effects.get("stun")), "蕴含 stun")
	assert_true(bool(owner.buff_effects.get("silence")), "递归蕴含 silence")
	assert_true(bool(owner.buff_effects.get("immoblilize")), "递归蕴含 immoblilize（源拼写）")


# 源 imprisonment（EFFECT_INCLUSIONS:19）：蕴含 stun+untargetable+invulnerable
func test_apply_imprisonment_inclusions() -> void:
	var owner := _make_owner()
	BattleBuff.new({"Name": "P", "Control Effects": ["imprisonment"]}, owner, _make_caster()).apply()
	assert_true(bool(owner.buff_effects.get("imprisonment")), "imprisonment")
	assert_true(bool(owner.buff_effects.get("stun")), "蕴含 stun")
	assert_true(bool(owner.buff_effects.get("untargetable")), "蕴含 untargetable")
	assert_true(bool(owner.buff_effects.get("invulnerable")), "蕴含 invulnerable")


# 源 building（EFFECT_INCLUSIONS:24）：蕴含 stable+fix（建筑类，非负面）
func test_apply_building_inclusions() -> void:
	var owner := _make_owner()
	BattleBuff.new({"Name": "Bld", "Control Effects": ["building"]}, owner, _make_caster()).apply()
	assert_true(bool(owner.buff_effects.get("building")), "building")
	assert_true(bool(owner.buff_effects.get("stable")), "蕴含 stable")
	assert_true(bool(owner.buff_effects.get("fix")), "蕴含 fix")


# 源 enchanted（EFFECT_INCLUSIONS:23）：无蕴含子效果仅自身，但属负面（NEGATIVE_EFFECTS:33）
func test_apply_enchanted_no_inclusion() -> void:
	var owner := _make_owner()
	var b := BattleBuff.new({"Name": "E", "Control Effects": ["enchanted"]}, owner, _make_caster())
	b.apply()
	assert_true(bool(owner.buff_effects.get("enchanted")), "enchanted")
	assert_true(b.is_negative_conflict_uncontrollable(), "enchanted 属负面（NEGATIVE_EFFECTS）")


# 源 update（buff.lua:34-41）：负 HPR（中毒/流血）按 dPSStatisticsRatio 缩放 + 浮点累加
# P2-1：修复前 owner.get("dps_statistics_ratio") 蛇形大小写敏感→null→1.0 失效（damage=101）
# P2-2：修复前 int()+int() 截断（50.5→50）；修复后浮点累加（50.5）
func test_update_negative_hpr_scales_by_dps_ratio() -> void:
	var owner := _make_owner()
	var caster := _make_caster()
	owner.dPSStatisticsRatio = 0.5  # 模拟 crusade/excavate（源 :211 覆盖；生产默认 1.0 无赋值入口）
	var b := BattleBuff.new({"Name": "Poison", "HPR": -101}, owner, caster)
	b.update(1.0)  # hpr=-101 → damage=min(101, owner.hp 1000)=101 ×0.5=50.5
	assert_eq(caster.dmg_statistics, 50.5, "crusade ratio=0.5 缩放（源 buff.lua:38）+ 浮点累加（:40 非 int 截断）")
