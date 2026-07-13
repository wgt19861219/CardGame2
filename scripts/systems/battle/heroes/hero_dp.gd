extends RefCounted

## DP（末日使者）英雄 hook（Logic 层）— 照源 battle/heroes/DP.lua（46 行）。
## DP_ult.createBuff：buff.update/onRemoved hook（周期随机目标 AP 伤害累计 total_dmg，onRemoved 治疗 total_dmg*0.5）。
## 依赖 take_effect_on 返 [succ, dmg] 双值（Phase 2.7续7 重构）— buff.update 解构 r[1] 累计。

const INTERVAL: float = 0.375  # 源 :1 周期伤害间隔
const HEAL_RATIO: float = 0.5  # 源 :30 onRemoved 治疗 total_dmg*0.5


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("DP_ult")
	if skillult:
		skillult.hero_hooks["createBuff"] = Callable(self, "_ult_create_buff")


# 源 :33-40 createBuff：basefunc + 设 attack_timer/total_dmg + 注册 update/onRemoved hook。
func _ult_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)  # basefunc
	buff.custom_data["attack_timer"] = INTERVAL  # 源 :35 buff.attack_timer = interval
	buff.custom_data["total_dmg"] = 0.0  # 源 :36 buff.total_dmg = 0
	buff.hero_hooks["update"] = Callable(self, "_buff_update")
	buff.hero_hooks["onRemoved"] = Callable(self, "_buff_on_removed")
	return buff


# 源 :2-28 update：周期（attack_timer 倒计，每 interval 触发）wraptable AP 随机目标 takeEffectOn 累计 dmg + basefunc。
func _buff_update(buff: Variant, dt: float) -> void:
	var timer: float = float(buff.custom_data.get("attack_timer", INTERVAL)) - dt
	while timer <= 0.0:
		timer += INTERVAL
		var skill: Variant = buff.caster.skills.get("DP_ult")
		var originfo: Dictionary = skill.info
		var origtarget: Variant = skill.target
		var wrapped: Dictionary = originfo.duplicate()  # 源 ed.wraptable
		wrapped["Buff ID"] = 0
		wrapped["Damage Type"] = "AP"
		wrapped["Target Camp"] = -1
		wrapped["Affected Camp"] = -1
		wrapped["Target Type"] = "random"
		skill.info = wrapped
		var target: Variant = skill._select_target(null)  # 源 skill:selectTarget()
		if target != null:
			var r: Array = skill.take_effect_on(target, buff.caster)  # 源 local succ, dmg = takeEffectOn
			if bool(r[0]):  # 源 if dmg then（dmg 非 nil = 命中成功）
				buff.custom_data["total_dmg"] = float(buff.custom_data.get("total_dmg", 0.0)) + float(r[1])
		skill.info = originfo
		skill.target = origtarget
	buff.custom_data["attack_timer"] = timer
	buff._update_default(dt)  # basefunc


# 源 :29-32 onRemoved：takeHeal(total_dmg*0.5, "hp", caster) + basefunc。
func _buff_on_removed(buff: Variant) -> void:
	var total_dmg: float = float(buff.custom_data.get("total_dmg", 0.0))
	buff.caster.take_heal(total_dmg * HEAL_RATIO, "hp", buff.caster)
	buff._on_removed_default()  # basefunc
