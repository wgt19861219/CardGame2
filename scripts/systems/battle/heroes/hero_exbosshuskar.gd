extends RefCounted

## ExBossHuskar 英雄 hook（Logic 层）— 照源 battle/heroes/ExBossHuskar.lua（84 行）。
## BossHuskar 进阶版：reset 首次出场加 Buff152（has_resetted 守卫）+ atk2 createProjectile（按 target 是否
##   召唤物改 atk5 CD：short5.5/long10 wraptable + cd_remaining 比例缩放 + enableTrack）+ atk3 takeEffectOn
##   （counter==1 冲撞 / else Buff98 + perc24.3 自残 setHP + walk_v=0 + basefunc）。
## 注：源 skillult_finish 空透传（等价默认 _finish_default，不挂）；源 skillatk2_power 定义但 init_hero 未挂（死代码，跳过）。

const HERO_NAME: String = "ExBossHuskar"
const TIMEGAP: float = 0.25
const COLLIDE_DIS: float = 30.0
const RESET_BUFF_ID: int = 152
const CHARGE_BUFF_ID: int = 98
const SELF_HURT_PERC: float = 24.3
const SELF_HURT_FLOOR_RATIO: float = 0.003
const SHORT_CD: float = 5.5
const LONG_CD: float = 10.0
const PERC_DENOM: float = 100.0


func _reset(hero: Variant) -> void:
	hero._reset_default()
	if not bool(hero.custom_data.get("has_resetted", false)):
		hero.custom_data["has_resetted"] = true
		var binfo: Variant = hero.cm.lookup(&"Buff", "", RESET_BUFF_ID)
		hero.add_buff(binfo, hero)


func _atk2_create_projectile(skill: Variant) -> Variant:
	var caster: Variant = skill.caster
	var skill5: Variant = caster.skills.get(HERO_NAME + "_atk5")
	var target: Variant = skill.target
	var is_summoned: bool = target != null and bool(target.config.get("is_summoned", false))
	var new_cd: float = SHORT_CD if is_summoned else LONG_CD
	if skill5:
		var old_cd: float = float(skill5.info.get("CD", 0.0))
		if old_cd > 0.0:
			skill5.cd_remaining = float(skill5.cd_remaining) / old_cd * new_cd
		var originfo: Dictionary = skill5.custom_data.get("originfo", skill5.info)
		var wrapped: Dictionary = originfo.duplicate()
		wrapped["CD"] = new_cd
		skill5.info = wrapped
	var projectile: Variant = skill._create_projectile_default()  # basefunc = ed.ProjectileCreate
	if target != null:
		projectile.enable_track(target)
	return projectile


func _atk3_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var caster: Variant = skill.caster
	if int(skill.attack_counter) == 1:
		var d: Vector2 = skill.target.position - caster.position
		if d == Vector2.ZERO:
			caster.walk_v = Vector2.ZERO
		else:
			var d2: Vector2 = d - d.normalized() * COLLIDE_DIS
			caster.walk_v = d2 / TIMEGAP
		return [true, 0.0]
	var binfo: Variant = caster.cm.lookup(&"Buff", "", CHARGE_BUFF_ID)
	caster.add_buff(binfo, caster)
	var full_hp: float = float(caster.attribs.get("HP", 0))
	var left_hp: float = max(full_hp * SELF_HURT_FLOOR_RATIO, float(caster.hp) - full_hp * SELF_HURT_PERC / PERC_DENOM)
	var hurt: float = float(caster.hp) - left_hp
	caster.set_hp(int(left_hp))
	caster.walk_v = Vector2.ZERO
	_show_self_hurt_popup(caster, hurt)
	return BattleSkillEffect.take_effect_on(skill, target, src)


func apply(hero: Variant) -> void:
	hero.hero_hooks["reset"] = Callable(self, "_reset")
	var skill2: Variant = hero.skills.get(HERO_NAME + "_atk2")
	if skill2:
		skill2.hero_hooks["createProjectile"] = Callable(self, "_atk2_create_projectile")
	var skillult: Variant = hero.skills.get(HERO_NAME + "_atk3")
	if skillult:
		skillult.hero_hooks["takeEffectOn"] = Callable(self, "_atk3_take_effect_on")
	var skill5: Variant = hero.skills.get(HERO_NAME + "_atk5")
	if skill5:
		skill5.custom_data["originfo"] = skill5.info


func _show_self_hurt_popup(unit: Variant, hurt: float) -> void:
	var str_text: String = "-" + str(int(round(hurt)))
	if str_text == "-0":
		return
	var actor: Variant = unit.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	actor.spawn_popup(str_text, "orange", false, "damage")
