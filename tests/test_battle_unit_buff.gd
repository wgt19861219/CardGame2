extends GutTest
# Phase 2.2续-E buff 方法（照源 unit.lua:700-812 翻译，2026-07-01）。
# 验 addBuff（属性加成 + stun→hurt）/removeBuff（属性回落）/removeAllBuffs/removeSignedBuffer/battleSupply。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_unit() -> BattleUnit:
	return BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, null, {}, null)


# 源 addBuff（:733-768）：buff 实例加入 buff_list + rebuild（apply 属性加成生效）
func test_add_buff_applies_attrib() -> void:
	var u := _make_unit()
	var ad_before := float(u.attribs.get("AD", 0.0))
	var buff := BattleBuff.new({"Name": "atk", "AD": 50.0, "Control Effects": []}, u, u)
	var ret: Variant = u.add_buff(buff, u)
	assert_eq(ret, buff, "add_buff 返回 buff 实例")
	assert_true(u.buff_list.has(buff), "buff 加入 buff_list")
	assert_eq(float(u.attribs.get("AD", 0.0)), ad_before + 50.0, "AD += 50（rebuild 内 buff.apply 生效）")


# 源 rebuild :492-493：stun buff → apply 设 buff_effects.stun → rebuild 调 hurt
func test_add_buff_stun_triggers_hurt() -> void:
	var u := _make_unit()
	u.state = BattleUnit.State.IDLE
	var buff := BattleBuff.new({"Name": BattleEffectKeys.STUN, "Control Effects": [BattleEffectKeys.STUN]}, u, u)
	u.add_buff(buff, u)
	assert_true(bool(u.buff_effects.get(BattleEffectKeys.STUN, false)), "stun 控制效果蕴含生效")
	assert_eq(u.state, BattleUnit.State.HURT, "rebuild stun → hurt")


# 源 removeBuff（:771-785）：交换末尾删除 + onRemoved + rebuild（属性回落）
func test_remove_buff_reverts_attrib() -> void:
	var u := _make_unit()
	var ad_before := float(u.attribs.get("AD", 0.0))
	var buff := BattleBuff.new({"Name": "atk", "AD": 50.0, "Control Effects": []}, u, u)
	u.add_buff(buff, u)
	u.remove_buff(buff)
	assert_false(u.buff_list.has(buff), "remove 后 buff_list 不含")
	assert_eq(float(u.attribs.get("AD", 0.0)), ad_before, "AD 回落（buff 移除后 rebuild）")


# 源 removeAllBuffs（:788-797）
func test_remove_all_buffs() -> void:
	var u := _make_unit()
	u.add_buff(BattleBuff.new({"Name": "b1", "AD": 10.0, "Control Effects": []}, u, u), u)
	u.add_buff(BattleBuff.new({"Name": "b2", "AD": 20.0, "Control Effects": []}, u, u), u)
	assert_eq(u.buff_list.size(), 2, "add 2 buffs")
	u.remove_all_buffs()
	assert_eq(u.buff_list.size(), 0, "remove_all 后 buff_list 空")


# 源 removeSignedBuffer（:800-811）：清 clearOnDeathFlag 的 buff，保留其余
func test_remove_signed_buffer_clears_death_flag() -> void:
	var u := _make_unit()
	var b_keep := BattleBuff.new({"Name": "keep", "AD": 10.0, "Control Effects": [], "Clear On Death ": false}, u, u)
	var b_clear := BattleBuff.new({"Name": "clear", "AD": 20.0, "Control Effects": [], "Clear On Death ": true}, u, u)
	u.add_buff(b_keep, u)
	u.add_buff(b_clear, u)
	u.remove_signed_buffer()
	assert_true(u.buff_list.has(b_keep), "非死亡清标记 buff 保留")
	assert_false(u.buff_list.has(b_clear), "死亡清标记 buff 移除")


# 源 battleSupply（:700-708）：HPS 回血 + MPS×coefficient 回蓝
func test_battle_supply_heals() -> void:
	var u := _make_unit()
	u.attribs["HPS"] = 100.0
	u.attribs["MPS"] = 50.0
	u.set_hp(1)
	u.set_mp(0)
	u.battle_supply(1.0)
	assert_eq(u.hp, 101, "HPS 回血（hp 1→101）")
	assert_eq(u.mp, 50, "MPS×1.0 回蓝（mp 0→50）")
