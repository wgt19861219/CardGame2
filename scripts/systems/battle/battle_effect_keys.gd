class_name BattleEffectKeys
extends RefCounted

## buff 控制效果 key 类型化注册表（Logic 层）— 阶段三 T1（2026-08-14）。
## 单一权威来源：key 常量 + 蕴含表 INCLUSIONS + 负面效果表 NEGATIVE。
## 治审查报告问题 13：key 纯字符串散布（135 处字面量 → 常量，拼写陷阱免疫）。
## ⚠️ 常量值是数据事实 key，逐字保持历史字面量（含源头拼写 IMMOBILIZE 的值 "immoblilize"），
## 改值会破坏 buff_effects 字典与既有存档/表的兼容；常量名纠正拼写仅供代码侧使用。

const FROZEN: String = "frozen"
const STUN: String = "stun"
const IMMOBILIZE: String = "immoblilize"  # 源拼写即如此（battle_buff 2026-06-30 起），值不可改
const SILENCE: String = "silence"
const DISARM: String = "disarm"
const DISABLE_AI: String = "disableAI"
const IMPRISONMENT: String = "imprisonment"
const UNTARGETABLE: String = "untargetable"
const INVULNERABLE: String = "invulnerable"
const UNCONTROLLABLE: String = "uncontrollable"
const ENCHANTED: String = "enchanted"
const BUILDING: String = "building"
const STABLE: String = "stable"
const FIX: String = "fix"
const UNHEAL: String = "unheal"
const NO_HPR: String = "noHPR"

## 效果蕴含：挂 key 时连带挂全部蕴含项（照源 buff.lua applyEffect，自 battle_buff.gd 迁入）。
const INCLUSIONS: Dictionary = {
	FROZEN: [STUN],
	STUN: [IMMOBILIZE, SILENCE, DISARM, DISABLE_AI],
	IMMOBILIZE: [],
	SILENCE: [],
	DISARM: [],
	DISABLE_AI: [],
	IMPRISONMENT: [STUN, UNTARGETABLE, INVULNERABLE],
	UNTARGETABLE: [],
	INVULNERABLE: [],
	UNCONTROLLABLE: [],
	ENCHANTED: [],
	BUILDING: [STABLE, FIX],
	STABLE: [],
	FIX: [],
	UNHEAL: [],
	NO_HPR: [],
}

## 负面效果集合（uncontrollable 挂上时逐一清除，自 battle_buff.gd 迁入）。
const NEGATIVE: Dictionary = {
	FROZEN: true, STUN: true, IMMOBILIZE: true, SILENCE: true,
	DISARM: true, IMPRISONMENT: true, ENCHANTED: true,
}
