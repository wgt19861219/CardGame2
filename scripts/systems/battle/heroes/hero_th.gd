extends RefCounted

## TH（潮汐）英雄 hook（Logic 层）— 照源 TH.lua（60 行）。
## 单位 update（protoAwake 守卫）：hp 下降超 awake_threshold（HP*0.15）→ 清负面 debuff + 加 Buff145。
## 待 protoAwake Phase5 激活。skillult_waterEffect 纯 View 跳过。

const AWAKE_THRESHOLD: float = 0.15  # 源 :2 threshold
const BUFF_TH_ID: int = 145          # 源 :26 觉醒 buff


# 源 :3-33 update：basefunc + hp 下降超阈值（HP*awake_threshold）→ 清异营 debuff + 加 Buff145 + 更新 last_hp。
func _hero_update(hero: Variant, dt: float) -> void:
	hero._update_default(dt)
	var cur_hp: int = int(hero.hp)
	var last_hp: int = int(hero.custom_data.get("last_hp", cur_hp))
	if cur_hp >= last_hp:
		hero.custom_data["last_hp"] = cur_hp
		return
	var hp_max: float = float(hero.attribs.get("HP", 0))
	if float(last_hp - cur_hp) >= hp_max * float(hero.custom_data.get("awake_threshold", AWAKE_THRESHOLD)):
		var debuff_list: Array = []
		var my_camp: int = int(hero.camp)
		for buff in hero.buff_list:
			if buff == null:
				continue
			var bc: Variant = buff.caster
			if bc == null or int(bc.camp) != my_camp:
				debuff_list.append(buff)
		for buff in debuff_list:
			hero.remove_buff(buff)
		var binfo: Variant = hero.cm.lookup(&"Buff", "", BUFF_TH_ID)
		hero.add_buff(BattleBuff.new(binfo, hero, hero), hero)
		hero.custom_data["last_hp"] = cur_hp


# 源 :51-58 init_hero：protoAwake→设 last_hp/awake_threshold/skillult_waterEffect + update hook（waterEffect 纯 View 跳过）。
func apply(hero: Variant) -> void:
	if BattleHeroRegistry.proto_awake(hero.proto):
		hero.custom_data["last_hp"] = int(hero.hp)
		hero.custom_data["awake_threshold"] = AWAKE_THRESHOLD
		hero.hero_hooks["update"] = Callable(self, "_hero_update")
