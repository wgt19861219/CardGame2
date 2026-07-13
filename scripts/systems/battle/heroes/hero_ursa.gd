extends RefCounted

## Ursa（拍拍熊）英雄 hook（Logic 层）— 照源 Ursa.lua（132 行）。
## Buff134 怒意叠加（类似 DOTA ursa）：pasv3 getDamage（无 Buff134 则加 + 读层数 power+=层数*0.05）+
##   ult/atk getDamage（Buff134 层数 +1 最多5 + timer=7 + power+=层数*Basic Num，无 Buff134 且 dmg>0 则加）。
## protoAwake 守卫，待 Phase5 激活。源 ult/atk takeEffectOn 空 wrapper（死代码）不挂。

const BUFF_URSA_ID: int = 134          # 源 :3/:44 怒意 buff
const PASV3_RATIO: float = 0.05        # 源 :14 pasv3 层数系数
const ULT_MAX_STACK: int = 5           # 源 :45/:84 层数上限
const BUFF_TIMER_RESET: float = 7.0    # 源 :38/:76 叠加重置 timer


# 源 :1-27 pasv3 getDamage：target 无 Buff134 标记→加 + 读 buff134 层数 power+=层数*0.05。
func _pasv3_get_damage(skill: Variant, target: Variant, power: float, dt: String, field: String, src: Variant, crit_mod: float) -> float:
	if not bool(target.custom_data.get("isBuff134", false)):
		var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", BUFF_URSA_ID)
		target.add_buff(binfo, skill.caster)
	var stack: int = 0
	var has_buff: bool = false
	for b in target.buff_list:
		if int(b.info.get("ID", 0)) == BUFF_URSA_ID:
			stack = int(b.custom_data.get("buff134", 0))
			has_buff = true
	var power134: float = power
	if has_buff:
		power134 = float(stack) * PASV3_RATIO + power
	else:
		target.custom_data["isBuff134"] = false
	return float(target.take_damage({"amount": power134, "damage_type": dt, "field": field, "source": src, "crit_mod": crit_mod}))


# 源 :28-64 ult getDamage：Buff134 层数 +1（最多5）+ timer=7 + power+=min(层数,5)*Basic Num，无 Buff134 且 dmg>0 则加。
func _ult_get_damage(skill: Variant, target: Variant, power: float, dt: String, field: String, src: Variant, crit_mod: float) -> float:
	var power134: float = power
	var has_buff: bool = _stack_up(target, skill)
	if has_buff:
		var rate: float = _awake_rate(skill.caster)
		power134 = float(_capped_stack(target)) * rate + power
	var dmg: float = float(target.take_damage({"amount": power134, "damage_type": dt, "field": field, "source": src, "crit_mod": crit_mod}))
	if not has_buff and dmg > 0.0:
		var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", BUFF_URSA_ID)
		target.add_buff(binfo, skill.caster)
	return dmg


# 源 :66-104 atk getDamage：同 ult（break after first Buff134，但 GDScript for 找首个即够）。
func _atk_get_damage(skill: Variant, target: Variant, power: float, dt: String, field: String, src: Variant, crit_mod: float) -> float:
	return _ult_get_damage(skill, target, power, dt, field, src, crit_mod)


# ult/atk 共用：找 Buff134 → 层数 +1（nil→1）+ timer=7。返是否命中。
func _stack_up(target: Variant, skill: Variant) -> bool:
	for b in target.buff_list:
		if int(b.info.get("ID", 0)) == BUFF_URSA_ID:
			var cur: int = int(b.custom_data.get("buff134", 0))
			cur = 1 if cur == 0 else cur + 1
			b.custom_data["buff134"] = cur
			b.timer = BUFF_TIMER_RESET
			return true
	return false


# 读首个 Buff134 的 capped 层数（最多 ULT_MAX_STACK）。
func _capped_stack(target: Variant) -> int:
	for b in target.buff_list:
		if int(b.info.get("ID", 0)) == BUFF_URSA_ID:
			return min(int(b.custom_data.get("buff134", 0)), ULT_MAX_STACK)
	return 0


# 读 Ursa_awake info Basic Num（ult/atk 加成系数）。
func _awake_rate(caster: Variant) -> float:
	var awake: Variant = caster.skills.get("Ursa_awake")
	if awake:
		return float(awake.info.get("Basic Num", 0))
	return 0.0


# 源 :113-131 init_hero：protoAwake→pasv3/ult/atk getDamage（ult/atk takeEffectOn 空 wrapper 死代码不挂）。
func apply(hero: Variant) -> void:
	if BattleHeroRegistry.proto_awake(hero.proto):
		var skillpasv3: Variant = hero.skills.get("Ursa_pasv3")
		if skillpasv3:
			skillpasv3.hero_hooks["getDamage"] = Callable(self, "_pasv3_get_damage")
		var skillult: Variant = hero.skills.get("Ursa_ult")
		if skillult:
			skillult.hero_hooks["getDamage"] = Callable(self, "_ult_get_damage")
		var skillatk: Variant = hero.skills.get("Ursa_atk")
		if skillatk:
			skillatk.hero_hooks["getDamage"] = Callable(self, "_atk_get_damage")
