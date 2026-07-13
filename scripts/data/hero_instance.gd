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
var gs: int = 0  # 战斗力（源 hero._gs，add_hero 时 calc_gs 初始化=GS_BASE player.lua:1490；wear/upgrade 后更新）
var awake: bool = false  # 觉醒状态（源 ed.protoAwake(proto)，C++ compiled 无定义；玩家养成控制，protoAwake hook 守卫）

func _init(hero_tid: int = 0, initial_stars: int = 1, id: int = 0) -> void:
	tid = hero_tid
	stars = initial_stars
	inst_id = id
