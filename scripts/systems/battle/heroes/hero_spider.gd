extends RefCounted

## Spider（蜘蛛）英雄 hook（Logic 层）— 照源 battle/heroes/Spider.lua（50 行）。
## Spider_atk2.canCastWithTarget：hp<HP*0.3 时 basefunc（可放），否则 false（hp 太多不放）。
## Spider_atk2.createBuff：buff.time_tag=1 + 覆写 update（每秒回 HP*0.1；hp 满/受控时 removeBuff + global_cd=3）。

const SPIDER_HP_RATIO: float = 0.3    # 源 :37 hp<HP*0.3 可放
const SPIDER_HEAL_RATIO: float = 0.1  # 源 :7 每秒回 HP*0.1
const SPIDER_TIME_TAG: float = 1.0    # 源 :6/+30 timeTag 周期（1 秒）
const SPIDER_CD: float = 3.0          # 源 :10/:17 hp 满/受控 global_cd


func apply(hero: Variant) -> void:
	var skillatk2: Variant = hero.skills.get("Spider_atk2")
	if skillatk2:
		skillatk2.hero_hooks["createBuff"] = Callable(self, "_create_buff")
		skillatk2.hero_hooks["canCastWithTarget"] = Callable(self, "_can_cast_with_target")


# 源 :35-41 canCastWithTarget：caster.hp < HP*0.3 → basefunc（可放）；否则 false "hp too much"。
func _can_cast_with_target(skill: Variant, target: Variant) -> Dictionary:
	var caster: Variant = skill.caster
	if float(caster.hp) < float(caster.attribs.get("HP", 0.0)) * SPIDER_HP_RATIO:
		return skill._can_cast_with_target_default(target)
	return {"ok": false, "reason": "hp too much"}


func _create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.custom_data["time_tag"] = SPIDER_TIME_TAG
	buff.hero_hooks["update"] = Callable(self, "_buff_update")
	return buff


# 源 :1-24 buffUpdate：basefunc 后 time_tag-=dt；<=0 → +1 + takeHeal(HP*0.1)；hp 满 → removeBuff+global_cd=3；
#   owner 有 stun/frozen/silence 控制 buff → removeBuff+global_cd=3。
func _buff_update(buff: Variant, dt: float) -> void:
	buff._update_default(dt)
	var owner: Variant = buff.owner
	var tt: float = float(buff.custom_data.get("time_tag", SPIDER_TIME_TAG)) - dt
	if tt <= 0.0:
		tt = tt + SPIDER_TIME_TAG
		owner.take_heal(float(owner.attribs.get("HP", 0.0)) * SPIDER_HEAL_RATIO, "hp", owner)
	buff.custom_data["time_tag"] = tt
	if int(owner.hp) == int(owner.attribs.get("HP", 0)):
		owner.global_cd = SPIDER_CD
		owner.remove_buff(buff)
		return
	for buf in owner.buff_list:
		if String(buf.info.get("Name", "")) == "Spider_atk2":
			continue  # 源 :14 跳过自身 buff
		for effect in buf.info.get("Control Effects", []):
			var eff: String = String(effect)
			if eff.find("stun") >= 0 or eff.find("frozen") >= 0 or eff.find("silence") >= 0:
				owner.global_cd = SPIDER_CD
				owner.remove_buff(buff)
				return
