class_name BattleUnitBuff
extends RefCounted

## 单位 buff 方法（Logic 层）— 照源 unit.lua:700-812 buff 段翻译（Phase 2.2续-E，2026-07-01）。
## 从 battle_unit.gd 拆出（≤300 行铁律）。全静态，u 为 BattleUnit（duck-type：state/buff_list/buff_effects/
##   attribs/take_heal/rebuild）。buff 闭环：addBuff（uncontrollable 冲突处理）/removeBuff/
##   removeAllBuffs/removeSignedBuffer/battleSupply。View 副作用（buffImpactEffect/onAddedClient）桩。

# 源 battleSupply（unit.lua:700-708）：HPS 回血 + MPS×coefficient 回蓝
static func battle_supply(u: Variant, coefficient: float) -> void:
	var attribs: Dictionary = u.attribs
	var hps: float = float(attribs.get("HPS", 0.0))
	if hps > 0.0:
		u.take_heal(hps, "hp", null)
	var mps: float = float(attribs.get("MPS", 0.0))
	if mps > 0.0:
		u.take_heal(mps * coefficient, "mp", null)


# 源 isHasUncontrolBufEffect（unit.lua:711-718）
static func is_has_uncontrol_buff_effect(u: Variant) -> bool:
	return bool(u.buff_effects.get("uncontrollable", false))


# 源 removeBuffsConlictWithUncontrol（unit.lua:720-730）：清与 uncontrollable 冲突的负面 buff
static func remove_buffs_conflict_with_uncontrol(u: Variant) -> void:
	var temp: Array = u.buff_list
	u.buff_list = []
	for buff in temp:
		if bool(buff.is_negative_conflict_uncontrollable()):
			buff.on_removed()
		else:
			u.buff_list.append(buff)


# 源 addBuff（unit.lua:733-768）。buff_or_binfo 可为 BattleBuff 实例或 buff_info dict（BuffCreate 包装）。
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
	# 源 :753-761 buffImpactEffect（View 表现，impactEffect/impactEffectZorder）桩
	buff.on_added_server()
	buff.on_added_client()  # 源 :763 run_with_scene → onAddedClient（Effect/Shader/飘字）
	u.rebuild()
	return buff


# 源 removeBuff（unit.lua:771-785）：交换末尾删除 + onRemoved + rebuild
static func remove_buff(u: Variant, buff: Variant) -> void:
	var list: Array = u.buff_list
	for i in range(list.size()):
		if list[i] == buff:
			list[i] = list[list.size() - 1]
			list.remove_at(list.size() - 1)
			break
	buff.on_removed()
	# 源 :781-783 buffImpactEffect 清理（View）桩
	u.rebuild()


# 源 removeAllBuffs（unit.lua:788-797）：逐个 onRemoved + 清空 + rebuild
static func remove_all_buffs(u: Variant) -> void:
	for buff in u.buff_list:
		# 源 :790-792 buffImpactEffect 清理（View）桩
		buff.on_removed()
	u.buff_list = []
	u.rebuild()


# 源 removeSignedBuffer（unit.lua:800-811）：清 clearOnDeathFlag 的 buff（死亡清标记 buff）
static func remove_signed_buffer(u: Variant) -> void:
	var temp: Array = u.buff_list
	u.buff_list = []
	for buff in temp:
		if bool(buff.clear_on_death):
			buff.on_removed()
		else:
			u.buff_list.append(buff)
	u.rebuild()
