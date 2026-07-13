class_name HeroCM
extends RefCounted

## CM（水晶室女）— 照源 battle/heroes/CM.lua（58 行）。
## ⚠️ 源 init_hero(:54-57) 是 dead assignment（`local skill3 = hero.skills.CM_ult; return hero`，**无 override()**），
##   skill3_start(:2-17)/skill3_takeEffectAt(:18-53) 是源死代码（定义但 init_hero 不挂）。
##   照源不挂任何 hook，CM_ult 走默认 start/take_effect_at（battle_skill_effect.gd 已忠实源默认 skill.lua:489-528）。
##   第七轮 P0 修复：删此前误激活的 start/takeEffectAt 注册（致 CM_ult AP 自己冻自己 + Point Effect 频率 + origin.y 三方差异），[[source-dead-code-activation]]。


# 源 :54-57 init_hero：dead assignment 无 override，照源 apply 不挂 hook（CM_ult 走默认）。
func apply(_hero: Variant) -> void:
	pass
