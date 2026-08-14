extends RefCounted

## SilverDragon（银龙）英雄 hook（Logic 层）— 照源 battle/heroes/SilverDragon.lua（42 行）。
## ice 技能 createBuff（atk2_ice/atk_ice 共用）：frozen→ice_mark.takeEffectAt+removeAllBuffs+BuffCreate(5)
##   / MSPD<0→BuffCreate(113) / else basefunc。
## setDisapearWhenDie(false) + hp ratio<=0.1 → config.dps_mod/=2。
## atk3_ice.takeEffectAt 仅 View（playEffectOnScene），Logic 层等价默认 → Phase 4 补，本轮跳过。
## skillicetakeEffectOn 源 :11-12 定义空但 init 未注册（死代码），照源不翻。

const FROZEN_MARK_BUFF_ID: int = 5
const SLOW_BUFF_ID: int = 113
const HP_RATIO_DPS_THRESHOLD: float = 0.1
const DPS_MOD_HALF: float = 0.5


func apply(hero: Variant) -> void:
	hero.set_disapear_when_die(false)
	var ratio: float = float(hero.hp) / float(hero.attribs.get("HP", 1))
	if ratio <= HP_RATIO_DPS_THRESHOLD:
		hero.config["dps_mod"] = float(hero.config.get("dps_mod", 1.0)) * DPS_MOD_HALF
	var atk2_ice: Variant = hero.skills.get("SilverDragon_atk2_ice")
	var atk_ice: Variant = hero.skills.get("SilverDragon_atk_ice")
	if atk2_ice:
		atk2_ice.hero_hooks["createBuff"] = Callable(self, "_ice_create_buff")
	if atk_ice:
		atk_ice.hero_hooks["createBuff"] = Callable(self, "_ice_create_buff")


func _ice_create_buff(skill: Variant, target: Variant) -> Variant:
	var caster: Variant = skill.caster
	if bool(target.buff_effects.get(BattleEffectKeys.FROZEN, false)):
		var ice_mark: Variant = caster.skills.get("SilverDragon_ice_mark")
		if ice_mark:
			ice_mark.take_effect_at(target.position)
		target.remove_all_buffs()
		var binfo: Variant = caster.cm.lookup(&"Buff", "", FROZEN_MARK_BUFF_ID)
		return BattleBuff.new(binfo, target, caster)
	elif float(target.attribs.get("MSPD", 0.0)) < 0.0:
		var binfo_slow: Variant = caster.cm.lookup(&"Buff", "", SLOW_BUFF_ID)
		return BattleBuff.new(binfo_slow, target, caster)
	return skill._create_buff_default(target)
