class_name HeroInstance
extends RefCounted

## 玩家拥有的英雄实例（Data 层）：强类型 + 显式默认值。
## 治旧版 Lua nil 默认值（_stars 未初始化返回 nil）——GDScript 强类型天然避免。

var inst_id: int = 0  # 管理器内唯一实例 id
var tid: int = 0      # 模板 id（对应 Unit 表）
var rank: int = 1     # 品质阶位（影响装备槽）
var level: int = 1
var stars: int = 1    # 星级（影响属性成长，1-5）
var exp: int = 0
var skill_levels: Array[int] = [1, 1, 1, 1]  # 4 个技能等级
var equip_slots: Array[int] = [0, 0, 0, 0, 0, 0]  # 6 装备槽（item_id，0=空）
var equip_exp: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]  # 6 装备槽强化经验（源 hero._items[slot] exp，供 readequip_data exp_map）
var gs: int = 0  # 战斗力（单一事实来源：recalc_hero_gs 全属性加权，一切养成入口落地后重算）
var awake: bool = false  # 觉醒状态（源 ed.protoAwake(proto)，C++ compiled 无定义；玩家养成控制，protoAwake hook 守卫）

func _init(hero_tid: int = 0, initial_stars: int = 1, id: int = 0) -> void:
	tid = hero_tid
	stars = initial_stars
	inst_id = id


## 战斗 proto 组装（与 StageManager 玩家英雄装配同源：_tid/_level/_stars/_rank/_items 带
## 各槽强化经验/_awake/_skill_levels）。供 HeroManager.recalc_hero_gs 构建战斗单位算加权战力，
## 保证显示战力与真实战斗单位同源。
func to_battle_proto() -> Dictionary:
	var items: Array = []
	for i in range(equip_slots.size()):
		var item_id: int = int(equip_slots[i])
		if item_id > 0:
			items.append({"_item_id": item_id, "_exp": float(equip_exp[i])})
	return {
		"_tid": tid, "_level": level, "_stars": stars, "_rank": rank,
		"_items": items, "_awake": awake,
		"_skill_levels": skill_levels_by_slot(),
	}


## SkillGroup 槽字符串键字典（供战斗装配 proto._skill_levels；源 main.lua:1590）。
func skill_levels_by_slot() -> Dictionary:
	var out: Dictionary = {}
	for i in skill_levels.size():
		out[str(i + 1)] = int(skill_levels[i])
	return out
