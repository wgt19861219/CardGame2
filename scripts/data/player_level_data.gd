class_name PlayerLevelData
extends RefCounted

## 战队等级数据查询（Data 层）— 照源 PlayerLevel 表翻译（Phase 5.4 起步，2026-07-02）。


# 源 PlayerLevel[level] = {Chapter, Exp, Vitality Reward, ...}。
static func get_level_info(level: int, cm: Variant) -> Dictionary:
	return cm.get_raw_table("PlayerLevel").get(str(level), {})


static func get_level_exp(level: int, cm: Variant) -> int:
	return int(get_level_info(level, cm).get("Exp", 0))


static func get_vitality_reward(level: int, cm: Variant) -> int:
	return int(get_level_info(level, cm).get("Vitality Reward", 0))
