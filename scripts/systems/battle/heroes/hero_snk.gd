extends RefCounted

## SNK（骷髅王）英雄 hook（Logic 层）— 照源 battle/heroes/SNK.lua（47 行）。
## SNK_pasv2 被动：首次死亡重生——die 拦截进 Birth 态 + rebirth_timer 倒计时；
##   onActionFinished 重生期跳过（不进 DEAD）；update 计时到 0 则 setHP + summon 复活。
## 单位级 hook（die/onActionFinished/update），用 hero.custom_data 存 rebirth_used/rebirth_timer
##   （源 self.custom_data/self.rebirth_timer 动态字段 → GDScript strict 用 custom_data 字典键）。

const REBIRTH_TIME: float = 2.5  # 源 :5 重生倒计时（秒）


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("SNK_pasv2")
	if skill:
		hero.hero_hooks["die"] = Callable(self, "_die")
		hero.hero_hooks["onActionFinished"] = Callable(self, "_on_action_finished")
		hero.hero_hooks["update"] = Callable(self, "_update")


# 源 :2-19 die：首次死亡重生（Birth 态 + removeAllBuffs + addBuff + Death 动作），else basefunc 真死。
func _die(hero: Variant, killer: Variant) -> void:
	var skill: Variant = hero.skills.get("SNK_pasv2")
	var used: int = int(hero.custom_data.get("rebirth_used", 0))
	if skill and used != 1 and not bool(hero.buff_effects.get("unheal", false)):
		hero.custom_data["rebirth_timer"] = REBIRTH_TIME
		hero.custom_data["rebirth_used"] = 1
		hero.state = BattleUnit.State.BIRTH
		hero.remove_all_buffs()
		hero.can_cast_manual = false
		hero.walk_v = Vector2.ZERO
		hero.hp = 0
		hero.mp = 0
		var binfo: Variant = skill.info.get("buff_info", {})
		hero.add_buff(binfo, hero)
		hero.set_action("Death", false, true)
	else:
		hero._die_default(killer)


# 源 :20-25 onActionFinished：重生期（rebirth_timer 存在）跳过 basefunc，否则正常。
func _on_action_finished(hero: Variant) -> void:
	if not hero.custom_data.has("rebirth_timer"):
		hero._on_action_finished_default()


# 源 :26-37 update：先 basefunc，再 rebirth_timer 递减，到 0 则 setHP(Basic Num*hp_mod) + summon 复活。
func _update(hero: Variant, dt: float) -> void:
	hero._update_default(dt)
	if hero.custom_data.has("rebirth_timer"):
		var rt: float = float(hero.custom_data["rebirth_timer"]) - dt
		if rt <= 0.0:
			hero.custom_data.erase("rebirth_timer")
			var skill: Variant = hero.skills.get("SNK_pasv2")
			var hp_mod: float = float(hero.config.get("hp_mod", 1.0))
			hero.set_hp(int(float(skill.info.get("Basic Num", 0)) * hp_mod))
			hero.summon()
		else:
			hero.custom_data["rebirth_timer"] = rt
