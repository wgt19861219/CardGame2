class_name ReadheroData
extends RefCounted

## 英雄数据查询（Data 层）— 照源 readhero.lua 数据查询方法翻译（Phase 5.1 起步，2026-07-02）。
## 独立查表工具（不依赖 HeroManager/UnitCreate/View），供 herodetail/UI 消费。
## createIcon 在 ReadheroIcon（View 层）；属性查询 getHeroAtt（依赖 UnitCreate）留后续。


# 源 readhero.lua:44-48 getHeroInitStars — Unit 表 "Initial Stars"。
static func get_hero_init_stars(tid: int, cm: Variant) -> int:
	var v: Variant = cm.lookup("Unit", "Initial Stars", tid)
	return int(v) if v != null else 0


# 源 readhero.lua:116-143 getGrowthByHero — Unit 表 "+STR"+star / "+AGI"+star / "+INT"+star。
# 源 keys = {STR="+STR", AGI="+AGI", INT="+INT"}，列名 = key .. star。
static func get_growth(tid: int, star: int, cm: Variant) -> Dictionary:
	if star <= 0:
		return {}
	var growth: Dictionary = {}
	var s := str(star)
	var str_v: Variant = cm.lookup("Unit", "+STR" + s, tid)
	var agi_v: Variant = cm.lookup("Unit", "+AGI" + s, tid)
	var int_v: Variant = cm.lookup("Unit", "+INT" + s, tid)
	growth["STR"] = float(str_v) if str_v != null else 0.0
	growth["AGI"] = float(agi_v) if agi_v != null else 0.0
	growth["INT"] = float(int_v) if int_v != null else 0.0
	return growth
