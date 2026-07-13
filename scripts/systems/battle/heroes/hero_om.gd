extends RefCounted

## OM 英雄 hook（Logic 层）— 照源 battle/heroes/OM.lua（111 行）。
## 多重施法（multicast）：OM_rand 按概率表（Skill Name → 概率）随机选次数 →
## OM_ult takeEffectOn 循环 basefunc times 次 / OM_atk2 createProjectile 选多目标各发弹 /
## OM_atk3 takeEffectOn 各目标命中。全用已有 hook 点（takeEffectOn/createProjectile）。
## View Popup（multicast_xN，run_with_scene）分层 Phase 4。

# 源 :2-20 multicast_table（各技能 multicast 概率表，索引=次数，值为百分比；和=100）
const MULTICAST_TABLE: Dictionary = {
	"OM_ult": [0, 40, 35, 25],
	"OM_atk2": [60, 32, 8],
	"OM_atk3": [50, 35, 10, 5],
}
# 抛物线求飞行时间（源 :78-82；照源重复，各英雄独立）
const G_HALF: float = 0.5
const DISC_K: float = 4.0
const DEN_K: float = 2.0
const RAND_PERCENT: float = 100.0  # 源 :23 rand*100 概率基数


func apply(hero: Variant) -> void:
	var skill_ult: Variant = hero.skills.get("OM_ult")
	var skill_atk2: Variant = hero.skills.get("OM_atk2")
	var skill_atk3: Variant = hero.skills.get("OM_atk3")
	if skill_ult:
		skill_ult.hero_hooks["takeEffectOn"] = Callable(self, "_ult_take_effect_on")
	if skill_atk2:
		skill_atk2.hero_hooks["createProjectile"] = Callable(self, "_atk2_create_projectile")
	if skill_atk3:
		skill_atk3.hero_hooks["takeEffectOn"] = Callable(self, "_atk3_take_effect_on")


# 源 :21-45 OM_rand（按概率表随机 multicast 次数）。
func _om_rand(skill: Variant) -> int:
	var prob_table: Array = MULTICAST_TABLE.get(str(skill.info.get("Skill Name", "")), [])
	var rand_val: float = skill.caster.engine.rng.randf() * RAND_PERCENT
	var times: int = prob_table.size()
	for i in range(prob_table.size()):
		rand_val -= float(prob_table[i])
		if rand_val < 0.0:
			times = i + 1  # Lua ipairs 1-based i → Godot 0-based +1
			break
	if times > 1:
		_show_multicast_popup(skill, times)
	return times


# 源 :46-64 OM_select_targets（rand 次数 + 随机排序选前 count 目标）。
func _om_select_targets(skill: Variant) -> Array:
	var times: int = _om_rand(skill)
	var list: Array = []
	for unit in skill.caster.engine.foreach_alive_unit(int(skill._affected_camp())):
		list.append([unit, skill.caster.engine.rng.randf()])
	list.sort_custom(Callable(self, "_sort_rand_desc"))
	var count: int = min(times, list.size())
	var ret: Array = []
	for i in range(count):
		ret.append(list[i][0])
	return ret


# 源 :55-57 sort 降序（rand 大的优先选）。
func _sort_rand_desc(a: Array, b: Array) -> bool:
	return float(a[1]) > float(b[1])


# 源 :65-70 skillult_takeEffectOn（multicast 循环 basefunc times 次）。
func _ult_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var times: int = _om_rand(skill)
	for _i in range(times):
		BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc
	return [true, 0.0]  # 源单返 true（循环内 dmg 未累计，latent）


# 源 :71-89 skill2_createProjectile（选多目标各发抛物线弹）。
func _atk2_create_projectile(skill: Variant) -> Variant:
	var targets: Array = _om_select_targets(skill)
	for unit in targets:
		var projectile: Variant = BattleProjectile.new(skill)  # basefunc
		var h: float = float(projectile.height)
		var v: float = float(projectile.z_speed)
		var a: float = float(skill.info.get("Tile Gravity", 0.0))
		var qa: float = G_HALF * a
		var qb: float = v
		var qc: float = h
		var delta: float = qb * qb - DISC_K * qa * qc
		var t: float = (-qb - sqrt(delta)) / (DEN_K * qa)
		# 源 :84 edpSub(target_pos, projectile.position)——注意用 projectile.position 非 caster
		var distance: Vector2 = unit.position - projectile.position
		projectile.velocity = distance * (1.0 / t)
		skill.caster.engine.add_projectile(projectile)
	return null


# 源 :90-95 skill3_takeEffectOn（选多目标各 basefunc 命中）。
func _atk3_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var targets: Array = _om_select_targets(skill)
	for unit in targets:
		BattleSkillEffect.take_effect_on(skill, unit, src)  # basefunc per target
	return [true, 0.0]  # 源单返 true（latent）


# 源 OM.lua:32-43 multicast_xN 飘字（caster actor，camp player→red/else→blue，text style；times≤1 不弹）。
func _show_multicast_popup(skill: Variant, times: int) -> void:
	var str_text: String = "multicast_x" + str(times)
	var actor: Variant = skill.caster.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	var color: String = "red" if int(skill.caster.camp) == BattleEngine.CAMP_PLAYER else "blue"
	actor.spawn_popup(str_text, color, false, "text")
