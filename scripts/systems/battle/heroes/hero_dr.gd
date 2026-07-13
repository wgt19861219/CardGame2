extends RefCounted

## DR 英雄 hook（Logic 层）— 照源 battle/heroes/DR.lua（42 行）。
## DR_ult.createProjectile：按 Script Arg1 算发射数 count，循环每发：basefunc 建弹射物 →
## 抛物线 velocity 朝偏移目标（offset_list[i]·camp，X 按阵营翻转）→ 自 add。
## 多发：i>1 时 selectTarget 重选目标；目标变或首发才发射（源 :25 selectTarget/= 判定）。

# 抛物线求飞行时间（源 :16-21；照源重复）
const G_HALF: float = 0.5
const DISC_K: float = 4.0
const DEN_K: float = 2.0
const COUNT_DIVISOR: int = 5  # 源 :10 count = (Script Arg1 - attack_counter) / 5 + 1
# 源 :2-8 多发目标偏移表（索引 1..5，[dx, dy]；dx 乘 camp 翻转）
const OFFSET_LIST: Array = [
	[0, 0],
	[-19, 5],
	[5, -14],
	[-36, 28],
	[39, -50],
]


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("DR_ult")
	if skill:
		skill.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")


# 源 :9-36 createProjectile（多发循环 + 偏移目标 + 抛物线）。
func _create_projectile(skill: Variant) -> Variant:
	var arg1: int = int(skill.info.get("Script Arg1", 0))
	var count: int = (arg1 - int(skill.attack_counter)) / COUNT_DIVISOR + 1
	var orig_target: Variant = skill.target
	var caster_pos: Vector2 = skill.caster.position
	for i in range(1, count + 1):  # 源 for i=1,count
		var projectile: Variant = BattleProjectile.new(skill)  # basefunc
		var h: float = float(projectile.height)
		var v: float = float(projectile.z_speed)
		var a: float = float(skill.info.get("Tile Gravity", 0.0))
		var qa: float = G_HALF * a
		var qb: float = v
		var qc: float = h
		var delta: float = qb * qb - DISC_K * qa * qc
		var t: float = (-qb - sqrt(delta)) / (DEN_K * qa)
		if i > 1:
			skill._select_target(null)  # 源 skill:selectTarget()
		if i == 1 or skill.target != orig_target:
			var off: Array = OFFSET_LIST[i - 1]  # Lua 1-indexed → Godot 0-indexed
			var target_pos := Vector2(
				skill.target.position.x + float(off[0]) * float(skill.caster.camp),
				skill.target.position.y + float(off[1])
			)
			var distance: Vector2 = target_pos - caster_pos  # edpSub
			projectile.velocity = distance * (1.0 / t)  # edpMult
			skill.caster.engine.add_projectile(projectile)  # ed.engine:addProjectile
	return null  # 源 return nil
