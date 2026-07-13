class_name FeatureLimit
extends RefCounted

## 功能解锁查询（Logic 层）— 照源 playerlimit.lua（196 行）。
## 用途：① unlock 公告系统（baselsr.playerLevelup 升级时遍历 BASELSR_UNLOCK_MAP 查解锁）
##       ② UI 入口门禁（按钮灰显 + 提示文案）。
## 注入 cm（ConfigManager，duck-type），从 PlayerLevel.json 的 Unlock 字段查解锁等级。
## 照源 ed.player:getLevel()/getvip()/getStageProgress() 全局 → 本项目参数注入（headless 可测）。

# 等级常量（照源 playerlimit.lua 1-based 表遍历 + getAreaUnlockStage shop=39）
const START_LEVEL: int = 1            # 源 i=1（PlayerLevel 表 1-based，:63）
const SHOP_UNLOCK_STAGE: int = 39     # 源 us = {shop = 39}（:79）
const STAGE_PROGRESS_OFFSET: int = 1  # 源 ed.player:getStageProgress() - 1（:141）
const DEFAULT_REQUIRE_DIM: StringName = &"playerlevel"  # 源 ur[key] or "playerlevel"（:132）

# 源 playerlimit.lua 的解锁维度（unlockRequire ur 表 :107-128）：
# playerlevel 类（查 PlayerLevel.Unlock）/ stage 类（shop 提示文案）/ vip 类（查 VIP 表）。
const _REQUIRE_TABLE: Dictionary = {
	&"SkillUpgrade": &"playerlevel",
	&"Elite": &"playerlevel",
	&"PVP": &"playerlevel",
	&"Midas": &"playerlevel",
	&"COT": &"playerlevel",
	&"Enhance": &"playerlevel",
	&"Exercise": &"playerlevel",
	&"shop": &"playerlevel",
	&"sshop": &"playerlevel",
	&"ssshop": &"playerlevel",
	&"Crusade": &"playerlevel",
	&"Guild": &"playerlevel",
	&"Excavate": &"playerlevel",
	&"Awake": &"playerlevel",
	&"WorldChannel": &"playerlevel",
	&"Skill Upgrade CD Reset": &"vip",
	&"Item One-Click-Upgrade": &"vip",
	&"Raid One Function": &"vip",
	&"Raid Ten Function": &"vip",
	&"Magic Soul Box": &"vip",
	&"Multiple Midas": &"vip",
}

# 源 getAreaUnlockStage us 表（playerlimit.lua:79）：仅 shop=39（提示文案用，实际解锁走 playerlevel）
const _STAGE_UNLOCK: Dictionary = {
	&"shop": SHOP_UNLOCK_STAGE,
}

# 源 baselsr.lua:33-45 playerLevelup 11 功能表 → tutorialres unlock step 名。
# 升级时遍历此表，check_area_unlock 为 true 则触发对应 unlock 公告（Step 3 升级钩子用）。
const BASELSR_UNLOCK_MAP: Dictionary = {
	&"SkillUpgrade": &"unlockSkillUpgrade",
	&"Elite": &"unlockEliteMode",
	&"PVP": &"unlockpvp",
	&"Midas": &"unlockMidas",
	&"COT": &"unlockcot",
	&"Enhance": &"unlockEnhance",
	&"Exercise": &"unlockExercise",
	&"Crusade": &"unlockCrusade",
	&"Guild": &"unlockGuild",
	&"WorldChannel": &"unlockWorldChannel",
	&"Excavate": &"unlockExcavate",
}

# 源 class.module_switch（:7）：close_module 标记的功能返 notopen
var _module_switch: Dictionary = {}

var _cm: Variant = null


func _init(cm: Variant = null) -> void:
	_cm = cm


## 源 closeModule（playerlimit.lua:8-11）：永久关闭某功能（解锁查询返 notopen）。
func close_module(key: StringName) -> void:
	_module_switch[key] = &"close"


## 源 getAreaUnlockLevel（playerlimit.lua:61-76）：遍历 PlayerLevel[i].Unlock 找 key 返 i，找不到返 0。
## 真实解锁等级由 PlayerLevel.json Unlock 字段决定（非硬编码）：SkillUpgrade=7/PVP=10/Elite=11/...
## Crusade/Excavate/shop/StarShop 不在表 → 返 0 → check_area_unlock 永远 true（默认已解锁，源设计）。
func get_area_unlock_level(key: StringName) -> int:
	var plt: Dictionary = _cm.get_raw_table("PlayerLevel")
	var index: int = START_LEVEL
	while plt.has(str(index)):
		var unlock: Dictionary = plt[str(index)].get("Unlock", {})
		for v in unlock.values():
			if String(v) == String(key):
				return index
		index += 1
	# 源 print（playerlimit.lua:74 debug，非 warning 级）：key 可能非 playerlevel 限制
	# Crusade/Excavate/shop/StarShop 等默认解锁（不在表 = 返 0 = limit<=current 恒 true，源设计）
	print("FeatureLimit: '%s' 不在 PlayerLevel.Unlock 表（默认解锁）" % String(key))
	return 0


## 源 getAreaUnlockStage（playerlimit.lua:78-86）：仅 shop=39（提示文案用）。
func get_area_unlock_stage(key: StringName) -> int:
	var s: int = int(_STAGE_UNLOCK.get(key, 0))
	if s == 0:
		print("FeatureLimit: '%s' 不限 stage" % String(key))
	return s


## 源 getAreaUnlockvip（playerlimit.lua:88-98）：遍历 VIP 表找含 key 的等级。
func get_area_unlock_vip(key: StringName) -> int:
	var vt: Dictionary = _cm.get_raw_table("VIP")
	var index: int = 0
	while vt.has(str(index)):
		if vt[str(index)].has(String(key)):
			return index
		index += 1
	return index


## 源 unlockRequire（playerlimit.lua:106-161）：返 {limit,type,current}（源返 limit, addition）。
## player_level/vip_level/stage_progress 注入（源 ed.player 全局）。
func unlock_require(key: StringName, player_level: int, vip_level: int = 0, stage_progress: int = 0) -> Dictionary:
	if _module_switch.get(key) == &"close":
		return {"limit": 0, "type": &"notopen", "current": 0}
	var state: StringName = _REQUIRE_TABLE.get(key, DEFAULT_REQUIRE_DIM)
	if state == &"playerlevel":
		return {"limit": get_area_unlock_level(key), "type": &"playerlevel", "current": player_level}
	elif state == &"stage":
		return {"limit": get_area_unlock_stage(key), "type": &"stage", "current": stage_progress - STAGE_PROGRESS_OFFSET}
	elif state == &"vip":
		return {"limit": get_area_unlock_vip(key), "type": &"vip", "current": vip_level}
	return {"limit": 0, "type": DEFAULT_REQUIRE_DIM, "current": player_level}


## 源 checkAreaUnlock（playerlimit.lua:162-174）：notopen→false；否则 limit <= current。
func check_area_unlock(key: StringName, player_level: int, vip_level: int = 0, stage_progress: int = 0) -> bool:
	var req: Dictionary = unlock_require(key, player_level, vip_level, stage_progress)
	if req["type"] == &"notopen":
		return false
	return int(req["limit"]) <= int(req["current"])


## 源 getAreaUnlockPrompt（playerlimit.lua:176-194）：未解锁的提示文案（已解锁返空）。
## 源用 LSTR 本地化 key，本项目无本地化系统 → 中文 fallback（照 tutorial_data.gd STEP_DESCRIPTIONS 范式）。
func get_area_unlock_prompt(key: StringName, player_level: int, vip_level: int = 0, stage_progress: int = 0) -> String:
	var req: Dictionary = unlock_require(key, player_level, vip_level, stage_progress)
	var state: StringName = req["type"]
	if check_area_unlock(key, player_level, vip_level, stage_progress):
		return ""
	var limit: int = int(req["limit"])
	if state == &"notopen":
		return "功能未开放"
	elif state == &"playerlevel":
		return "战队 %d 级开放" % limit
	elif state == &"stage":
		if key == &"shop":
			return "通关第 2 章开放"
		return "通关 %d 关开放" % limit
	elif state == &"vip":
		return "VIP %d 开放" % limit
	return ""
