class_name HeroData
extends RefCounted

## 英雄静态数据（Data 层）：从 Unit 表加载的基础属性 + 星级成长系数。
## 强类型 + 显式默认值，避免旧版 Lua _stars 遮蔽元表的 nil 默认值 bug。

const GROWTH_LEVEL_COUNT: int = 5  # +STR1..+STR5（星级 1-5）

var tid: int = 0
var base_str: float = 0.0
var base_int: float = 0.0
var base_agi: float = 0.0
var base_hp: int = 0
var base_ad: int = 0
var str_growth: Array[float] = []
var int_growth: Array[float] = []
var agi_growth: Array[float] = []
var initial_stars: int = 1
var max_stars: int = GROWTH_LEVEL_COUNT
var basic_skill: int = 0

static func from_config(cm: ConfigManager, hero_tid: int) -> HeroData:
	var data := HeroData.new()
	data.tid = hero_tid
	data.base_str = cm.get_float(&"Unit", hero_tid, &"STR")
	data.base_int = cm.get_float(&"Unit", hero_tid, &"INT")
	data.base_agi = cm.get_float(&"Unit", hero_tid, &"AGI")
	data.base_hp = cm.get_int(&"Unit", hero_tid, &"HP")
	data.base_ad = cm.get_int(&"Unit", hero_tid, &"AD")
	data.str_growth = _load_growth(cm, hero_tid, "+STR")
	data.int_growth = _load_growth(cm, hero_tid, "+INT")
	data.agi_growth = _load_growth(cm, hero_tid, "+AGI")
	data.initial_stars = cm.get_int(&"Unit", hero_tid, &"Initial Stars")
	data.max_stars = cm.get_int(&"Unit", hero_tid, &"Max Stars")
	data.basic_skill = cm.get_int(&"Unit", hero_tid, &"Basic Skill")
	return data

static func _load_growth(cm: ConfigManager, tid: int, prefix: String) -> Array[float]:
	var arr: Array[float] = []
	var i: int = 1
	while i <= GROWTH_LEVEL_COUNT:
		arr.append(cm.get_float(&"Unit", tid, StringName(prefix + str(i))))
		i += 1
	return arr

func str_at_stars(stars: int) -> float:
	return base_str + _growth_at(str_growth, stars)

func int_at_stars(stars: int) -> float:
	return base_int + _growth_at(int_growth, stars)

func agi_at_stars(stars: int) -> float:
	return base_agi + _growth_at(agi_growth, stars)

func _growth_at(growth: Array[float], stars: int) -> float:
	if growth.is_empty():
		return 0.0
	var idx: int = clampi(stars - 1, 0, growth.size() - 1)
	return growth[idx]
