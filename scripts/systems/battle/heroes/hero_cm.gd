class_name HeroCM
extends RefCounted

## CM（水晶室女）— 照源 battle/heroes/CM.lua（58 行）。
## ⚠️ 源 init_hero(:54-57) 是 dead assignment（`local skill3 = hero.skills.CM_ult; return hero`，**无 override()**），
##   skill3_start(:2-17)/skill3_takeEffectAt(:18-53) 是源死代码（定义但 init_hero 不挂）。
##   第七轮 P0 修复：删此前误激活的 start/takeEffectAt 注册（致 CM_ult AP 自己冻自己 + Point Effect 频率 + origin.y 三方差异），[[source-dead-code-activation]]。


func apply(_hero: Variant) -> void:
	pass
