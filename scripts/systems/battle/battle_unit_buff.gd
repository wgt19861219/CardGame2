class_name BattleUnitBuff
extends RefCounted

## 单位 buff 方法（Logic 层）— 照源 unit.lua:700-812 buff 段翻译（Phase 2.2续-E，2026-07-01）。
## 从 battle_unit.gd 拆出（≤300 行铁律）。全静态，u 为 BattleUnit（duck-type：state/buff_list/buff_effects/
##   attribs/take_heal/rebuild）。buff 闭环：addBuff（uncontrollable 冲突处理）/removeBuff/
##   removeAllBuffs/removeSignedBuffer/battleSupply。View 副作用（buffImpactEffect/onAddedClient）桩。

static func battle_supply(u: Variant, coefficient: float) -> void:
	var attribs: Dictionary = u.attribs
	var hps: float = float(attribs.get("HPS", 0.0))
	if hps > 0.0:
		u.take_heal(hps, "hp", null)
	var mps: float = float(attribs.get("MPS", 0.0))
	if mps > 0.0:
		u.take_heal(mps * coefficient, "mp", null)


static func is_has_uncontrol_buff_effect(u: Variant) -> bool:
	return bool(u.buff_effects.get(BattleEffectKeys.UNCONTROLLABLE, false))


static func remove_buffs_conflict_with_uncontrol(u: Variant) -> void:
	var temp: Array = u.buff_list
	u.buff_list = []
	for buff in temp:
		if bool(buff.is_negative_conflict_uncontrollable()):
			buff.on_removed()
		else:
			u.buff_list.append(buff)


# 返回 buff（源 :767 return buff）。View：buffImpactEffect/onAddedClient 桩。
static func add_buff(u: Variant, buff_or_binfo: Variant, caster: Variant = null) -> Variant:
	if int(u.state) == BattleUnit.State.DEAD:
		return null
	var buff: Variant
	if buff_or_binfo is BattleBuff:
		buff = buff_or_binfo
	else:
		buff = BattleBuff.new(buff_or_binfo, u, caster)
	if is_has_uncontrol_buff_effect(u):
		remove_buffs_conflict_with_uncontrol(u)
		if bool(buff.is_negative_conflict_uncontrollable()):
			buff.on_removed()
			return null
	elif bool(buff.has_uncontrollable_effect()):
		remove_buffs_conflict_with_uncontrol(u)
	u.buff_list.append(buff)
	buff.on_added_server()
	buff.on_added_client()
	u.rebuild()
	return buff


static func remove_buff(u: Variant, buff: Variant) -> void:
	var list: Array = u.buff_list
	for i in range(list.size()):
		if list[i] == buff:
			list[i] = list[list.size() - 1]
			list.remove_at(list.size() - 1)
			break
	buff.on_removed()
	u.rebuild()


static func remove_all_buffs(u: Variant) -> void:
	for buff in u.buff_list:
		buff.on_removed()
	u.buff_list = []
	u.rebuild()


static func remove_signed_buffer(u: Variant) -> void:
	var temp: Array = u.buff_list
	u.buff_list = []
	for buff in temp:
		if bool(buff.clear_on_death):
			buff.on_removed()
		else:
			u.buff_list.append(buff)
	u.rebuild()
