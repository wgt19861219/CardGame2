extends RefCounted

## CW 英雄 hook（Logic 层）— 照源 battle/heroes/CW.lua（26 行）。
## CW_atk3.start：传送到 400-450·camp 位置 + walk_v 冲撞（250·camp）。
## CW_atk3.onAttackFrame：停 walk_v + 自增 counter，counter==2 才 basefunc（冲撞中仅第 2 帧触发攻击）。
## basefunc（_on_attack_frame_default）内部再 counter+=1，源 wrapper :13 自增 + :14 条件调 basefunc。

const POS_X_BASE: float = 400.0  # 源 :4 position = 400 - 450·camp
const POS_X_CAMP: float = 450.0
const CHARGE_V: float = 250.0    # 源 :6 walk_v = {250·camp, 0}
const ATTACK_FRAME_HIT: int = 2  # 源 :14 counter==2 才 basefunc


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("CW_atk3")
	if skill:
		skill.hero_hooks["start"] = Callable(self, "_start")
		skill.hero_hooks["onAttackFrame"] = Callable(self, "_on_attack_frame")


# 源 :1-9 skillatk3_start（basefunc → 传送 + 冲撞 walk_v）。
func _start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)  # basefunc
	var caster: Variant = skill.caster
	caster.position = Vector2(POS_X_BASE - POS_X_CAMP * float(caster.camp), caster.position.y)
	caster.walk_v = Vector2(CHARGE_V * float(caster.camp), 0.0)


# 源 :10-17 skillatk3_onAttackFrame（停 walk_v + counter++ → counter==2 调 basefunc）。
func _on_attack_frame(skill: Variant) -> void:
	skill.caster.walk_v = Vector2.ZERO
	skill.attack_counter = int(skill.attack_counter) + 1
	if int(skill.attack_counter) == ATTACK_FRAME_HIT:
		skill._on_attack_frame_default()  # basefunc（内部再 counter+=1）
