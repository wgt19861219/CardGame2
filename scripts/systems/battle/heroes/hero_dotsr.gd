class_name HeroDOTsr
extends RefCounted

## DOTsr（暗影萨满变体）英雄 hook（Logic 层）— 照源 battle/heroes/DOTsr.lua（23 行）。
## DOTsr_atk2.createBuff：basefunc 建 buff → override buff.update（basefunc 后按 timer 分段
##   设 owner.actor.zSpeed：>2.3 时 280，否则 80*sin(time*360°)+100 振荡）。

const ZSPEED_HIGH: float = 280.0
const ZSPEED_BASE: float = 100.0
const ZSPEED_AMP: float = 80.0
const SPLIT_TIME: float = 2.3
const FREQ_DEG: float = 360.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("DOTsr_atk2")
	if skill:
		skill.hero_hooks["createBuff"] = Callable(self, "_atk2_create_buff")


func _atk2_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)  # basefunc
	buff.hero_hooks["update"] = Callable(self, "_buff_update")
	return buff


func _buff_update(buff: Variant, dt: float) -> void:
	buff._update_default(dt)  # basefunc（源 :3 basefunc(buff, dt) 在前）
	var time: float = float(buff.timer)
	var owner: Variant = buff.owner
	if owner == null or owner.actor == null:
		return
	var actor: Variant = owner.actor
	if time > SPLIT_TIME:
		if "z_speed" in actor:
			actor.z_speed = ZSPEED_HIGH
		elif "zSpeed" in actor:
			actor.zSpeed = ZSPEED_HIGH
	else:
		var oscillate: float = ZSPEED_AMP * sin(deg_to_rad(time * FREQ_DEG)) + ZSPEED_BASE
		if "z_speed" in actor:
			actor.z_speed = oscillate
		elif "zSpeed" in actor:
			actor.zSpeed = oscillate
