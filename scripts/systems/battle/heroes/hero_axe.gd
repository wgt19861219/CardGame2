extends RefCounted

## Axe 英雄 hook（Logic 层）— 照源 battle/heroes/Axe.lua（48 行）。
## Axe_ult.takeEffectOn：目标血量 < 32%（killratio）→ wraptable 强化（Knock Up=1/No Dodge/
##   Basic Num·3/Plus Ratio·3）→ basefunc → 击杀非召唤物回 300 mp。
## Axe_ult.willCast：basefunc + 目标血量 ≤ 31% 才放（斩杀线，略低于 takeEffectOn 防边界抖动）。
## View 特效（eff_point_Axe_ult / Popup culling，run_with_scene）分层 Phase 4。

const KILL_RATIO: float = 0.32  # 源 :3 takeEffectOn 斩杀血量线
const CAST_RATIO: float = 0.31  # 源 :37 willCast 斩杀线（略低防边界抖动）
const KILL_HEAL_MP: int = 300   # 源 :27 击杀回 mp
const BASIC_NUM_MULT: int = 3   # 源 :20 Basic Num·3
const PLUS_RATIO_MULT: int = 3  # 源 :21 Plus Ratio·3


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Axe_ult")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_take_effect_on")
		skill.hero_hooks["willCast"] = Callable(self, "_will_cast")


# 源 :2-30 skillult_takeEffectOn（斩杀线 wraptable 强化 + basefunc + 击杀回 mp）。
func _take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var hpratio: float = float(target.hp) / float(target.attribs.HP)
	var orig_info: Dictionary = skill.info
	if KILL_RATIO > hpratio:
		skill.info = orig_info.duplicate()  # 源 ed.wraptable(originfo, {...})
		skill.info["Knock Up"] = 1
		skill.info["No Dodge"] = true
		skill.info["Basic Num"] = int(orig_info.get("Basic Num", 0)) * BASIC_NUM_MULT
		skill.info["Plus Ratio"] = float(orig_info.get("Plus Ratio", 0.0)) * float(PLUS_RATIO_MULT)
		_show_culling_popup(target)  # 源 Axe.lua:14-15 斩杀线 culling 飘字
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc [succ, dmg]
	skill.info = orig_info
	var succ: bool = bool(r[0])
	if succ and not bool(target.is_alive()) and not bool(target.config.get("is_summoned", false)):
		skill.caster.take_heal(float(KILL_HEAL_MP), "mp", skill.caster)  # 源 takeHeal(300,"mp",caster)
	return r  # 透传 [succ, dmg]


# 源 :31-41 willCast（basefunc + 目标血量 ≤ 31% 才放）。
func _will_cast(skill: Variant) -> bool:
	var ret: bool = skill._will_cast_default()  # basefunc
	if ret:
		var target: Variant = skill.target
		if target != null:
			var hpratio: float = float(target.hp) / float(target.attribs.HP)
			return hpratio <= CAST_RATIO
	return ret


# 源 Axe.lua:14-15 斩杀线命中 culling 飘字（target actor，camp enemy→blue/else→red，crit=true）。
func _show_culling_popup(target: Variant) -> void:
	var actor: Variant = target.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	var color: String = "blue" if int(target.camp) == BattleEngine.CAMP_ENEMY else "red"
	actor.spawn_popup("culling", color, true, "text")
