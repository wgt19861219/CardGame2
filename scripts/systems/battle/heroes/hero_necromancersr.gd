extends RefCounted

## 死灵法师（Necromancersr）— 照源 Necromancersr.lua 翻译。
## Necromancersr_atk2 普攻对尸体召唤骷髅：selectTarget 遍历 unit_list 找 Dead+hasCorpse 尸体 →
## onAttackFrame takeEffectAt(target.position) → takeEffectOn 隐体（hasCorpse 守卫）→ UnitCreate 骷髅 + summonUnit。
## 复用续7 take_effect_on 返 [succ, dmg] 契约；无 AOE → takeEffectAt else 分支对 skill.target 调 takeEffectOn。

const CORPSE_LIFETIME: float = 5.0
const SKELETON_TID: int = 111


func _select_target(skill: Variant, _default: Variant) -> Variant:
	skill.target = null
	for unit in skill.caster.engine.unit_list:
		if int(unit.state) == BattleUnit.State.DEAD and bool(unit.hasCorpse) and float(unit.action_elapsed) < CORPSE_LIFETIME:
			skill.target = unit
	return skill.target


func _on_attack_frame(skill: Variant) -> void:
	skill.take_effect_at(skill.target.position)


func _take_effect_on(skill: Variant, target: Variant, _src: Variant) -> Array:
	if not bool(target.hasCorpse):
		return [false, 0.0]
	target.hasCorpse = false
	var proto: Dictionary = {"_tid": SKELETON_TID, "_level": int(target.level)}
	var config: Dictionary = {"is_monster": true, "estimate_rank": true, "estimate_skill": true}
	var caster: Variant = skill.caster
	var skeleton: BattleUnit = BattleUnit.new(proto, int(caster.camp), config, caster.cm, caster.engine, {}, caster.skill_lib)
	skeleton.direction = int(caster.direction)
	caster.engine.summon_unit(skeleton, target.position, caster)
	return [true, 0.0]


# 返有效 Callable 使 is_valid true；selectTarget hook 完全重写不调 selector，故 _corpse_selector 永不被调。
func _target_selector(_skill: Variant) -> Callable:
	return Callable(self, "_corpse_selector")


func _corpse_selector(_unit: Variant) -> float:
	return 0.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Necromancersr_atk2")
	if skill:
		skill.hero_hooks["selectTarget"] = Callable(self, "_select_target")
		skill.hero_hooks["onAttackFrame"] = Callable(self, "_on_attack_frame")
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_take_effect_on")
		skill.hero_hooks["targetSelector"] = Callable(self, "_target_selector")
