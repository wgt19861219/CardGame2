extends RefCounted

## JUGG 英雄 hook（Logic 层）— 照源 battle/heroes/JUGG.lua（76 行）。
## JUGG_ult：start（Buff 48 + 记 JUGGUltPosition）/ onAttackFrame（counter==6 回位）/ takeEffectOn（传送到 target）
## JUGG_atk2：start（Buff 49 + 冲撞）/ onAttackFrame（counter==4 反向 / ==8 停）/ finish（停 walk_v + 翻转 direction）
## finish 是新 hook 点（void 分发，battle_skill.finish 拆 _finish_default 当 basefunc）。
## cm 访问：caster.cm.lookup（Buff 48/49）。

const ULT_BUFF_ID: int = 48
const ATK2_BUFF_ID: int = 49
const ATK2_SPEED: float = 180.0
const ULT_RETURN_FRAME: int = 6
const ATK2_REVERSE_FRAME: int = 4
const ATK2_STOP_FRAME: int = 8


func apply(hero: Variant) -> void:
	var skill_ult: Variant = hero.skills.get("JUGG_ult")
	var skill_atk2: Variant = hero.skills.get("JUGG_atk2")
	if skill_ult:
		skill_ult.hero_hooks["start"] = Callable(self, "_ult_start")
		skill_ult.hero_hooks["onAttackFrame"] = Callable(self, "_ult_on_attack_frame")
		skill_ult.hero_hooks["takeEffectOn"] = Callable(self, "_ult_take_effect_on")
	if skill_atk2:
		skill_atk2.hero_hooks["start"] = Callable(self, "_atk2_start")
		skill_atk2.hero_hooks["onAttackFrame"] = Callable(self, "_atk2_on_attack_frame")
		skill_atk2.hero_hooks["finish"] = Callable(self, "_atk2_finish")


func _ult_start(skill: Variant, target: Variant) -> void:
	var caster: Variant = skill.caster
	var binfo: Variant = caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	caster.add_buff(binfo, caster)
	caster.custom_data["JUGGUltPosition"] = caster.position
	skill._start_default(target)


func _ult_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	var caster: Variant = skill.caster
	if int(skill.attack_counter) == ULT_RETURN_FRAME and caster.custom_data.has("JUGGUltPosition"):
		caster.position = caster.custom_data["JUGGUltPosition"]


func _ult_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var caster: Variant = skill.caster
	caster.position = Vector2(target.position.x, target.position.y - 1)
	return BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc


func _atk2_start(skill: Variant, target: Variant) -> void:
	var caster: Variant = skill.caster
	var binfo: Variant = caster.cm.lookup(&"Buff", "", ATK2_BUFF_ID)
	caster.add_buff(binfo, caster)
	caster.walk_v = Vector2(float(caster.direction) * ATK2_SPEED, 0.0)
	skill._start_default(target)


func _atk2_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	var caster: Variant = skill.caster
	var counter: int = int(skill.attack_counter)
	if counter == ATK2_REVERSE_FRAME:
		caster.walk_v = Vector2(-caster.walk_v.x, 0.0)
	elif counter == ATK2_STOP_FRAME:
		caster.walk_v = Vector2.ZERO


func _atk2_finish(skill: Variant) -> void:
	var caster: Variant = skill.caster
	caster.walk_v = Vector2.ZERO
	caster.direction = int(caster.direction) * -1
	skill._finish_default()
