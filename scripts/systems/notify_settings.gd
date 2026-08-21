class_name NotifySettings
extends RefCounted

## 通知开关与游戏内提醒调度（Logic 层）— 照源 src/localnotify.lua（7 通知 data 表）
## + ui/popwindow/notification.lua（switch 读写）单机化。
##
## 单机化等价：源走手机本地推送（应用后台也推）→ 本项目为**游戏运行中**的
## Toast 提醒（View 层 HudOverlay 定时轮询 + 事件调用方检测）。
## 开关持久化 user://notify.cfg（应用级设置，照 AudioPlayer sound_switch 模式不入存档）。
##
## 通知 id 1-7 照源 data 顺序：
##   1=12:00 领体力 / 2=18:00 领体力 / 3=体力回满 / 4=9:00 商店刷新 /
##   5=21:00 领体力 / 6=技能点回满 / 7=20:55 竞技场奖励。
##
## 触发源现状（2026-08-21）：
##   - 定时 5 项（1/2/4/5/7）：HudOverlay 30s 轮询 check_time_due（当天去重，重启不重推）。
##   - 技能点回满（6）：hero_detail 打开时 SkillPointManager.recover 补算点检测 crossed_full。
##   - 体力回满（3）：⚠️ 体力恢复链路未接线（阶段三遗留待决策，player_data.gd 注释），
##     crossed_full API 已备好，接线后于恢复调用点同款检测即可。

# 测试可注入隔离路径（static var，Godot 4.1+）；生产默认 user://notify.cfg。
static var cfg_path: String = "user://notify.cfg"
const CFG_SECTION: String = "notify"
const MINUTES_PER_HOUR: int = 60   # 时间点换算（lint 禁裸数字）
# 时间点通知触发后当天只推一次（源 iTag="day" + iDate 当天去重）。
const DEFAULT_ON: bool = true

# id → {time: "HH:MM"（空=事件型）, lstr: 开关行文案, fire: 触发 Toast 文案}
# 键照源：lstr=setuplist.lua 行文案 / fire=localnotify.lua data.text。
const ENTRIES: Dictionary = {
	1: {"time": "12:00", "lstr": "PLAYERINFO.CLAIM_ENERGY", "fire": "LOCALNOTIFY.TIME_FOR_LUNCH_SMELLS_GOOD"},
	2: {"time": "18:00", "lstr": "PLAYERINFO.CLAIM_ENERGY", "fire": "LOCALNOTIFY.TIME_FOR_SUPPER_SMELLS_GOOD"},
	3: {"time": "", "lstr": "PLAYERINFO.FULL_ENERGY_RECOVERY_NOTICE", "fire": "LOCALNOTIFY.YOUR_HERO_IS_READY_TO_FIGHT"},
	4: {"time": "9:00", "lstr": "PLAYERINFO.STORE_REFRESH", "fire": "LOCALNOTIFY.SINAS_SHOP_IS_RELOADED_PLEASE_COME_AND_SHOP"},
	5: {"time": "21:00", "lstr": "PLAYERINFO.CLAIM_ENERGY", "fire": "LOCALNOTIFY.TIME_FOR_NIGHT_SMELLS_GOOD"},
	6: {"time": "", "lstr": "PLAYERINFO.SKILL_POINTS_BACK_FULL_NOTICE", "fire": "LOCALNOTIFY.SKILL_POINTS_ARE_AVAILABLE_CHOOSE_A_HERO"},
	7: {"time": "20:55", "lstr": "LOCALNOTIFY.ARENA_REWARD_PUSH_TITLE", "fire": "LOCALNOTIFY.ARENA_REWARD_PUSH_TEXT"},
}


static func entry_lstr(id: int) -> String:
	return String(ENTRIES.get(id, {}).get("lstr", ""))


static func entry_fire_lstr(id: int) -> String:
	return String(ENTRIES.get(id, {}).get("fire", ""))


## 开关状态（源 getSwitch：默认全开；关闭表存储语义简化为逐 id bool）。
static func get_switch(id: int) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return DEFAULT_ON
	return bool(cfg.get_value(CFG_SECTION, _switch_key(id), DEFAULT_ON))


static func set_switch(id: int, on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	cfg.set_value(CFG_SECTION, _switch_key(id), on)
	cfg.save(cfg_path)


static func _switch_key(id: int) -> String:
	return "switch_" + str(id)


## 到点检测：返回本次应弹 Toast 的通知 id 列表（开启 + now ≥ time + 今天未推）。
## time_dict = Time.get_time_dict_from_system()（本地时区，源 getServerTime+serverZone 折算
## → 单机直接本地时间）。返回的 id 由调用方 mark_fired + 翻译 fire 文案弹 Toast。
static func check_time_due(time_dict: Dictionary) -> Array[int]:
	var due: Array[int] = []
	var now_min: int = int(time_dict.get("hour", 0)) * MINUTES_PER_HOUR + int(time_dict.get("minute", 0))
	for id: int in ENTRIES:
		var time_str: String = String(ENTRIES[id]["time"])
		if time_str == "":
			continue
		if not get_switch(id):
			continue
		var parts: PackedStringArray = time_str.split(":")
		var tp_min: int = int(parts[0]) * MINUTES_PER_HOUR + int(parts[1])
		if now_min < tp_min:
			continue
		if _fired_today(id, time_dict):
			continue
		due.append(id)
	return due


## 当天已推标记（源 iDate 语义：跨天自动失效——日期 key 不同即视为未推）。
static func mark_fired(id: int, time_dict: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	cfg.set_value(CFG_SECTION, _fired_key(id), _day_key(time_dict))
	cfg.save(cfg_path)


static func _fired_today(id: int, time_dict: Dictionary) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return false
	return String(cfg.get_value(CFG_SECTION, _fired_key(id), "")) == _day_key(time_dict)


static func _fired_key(id: int) -> String:
	return "fired_" + str(id)


static func _day_key(time_dict: Dictionary) -> String:
	return "%04d%02d%02d" % [int(time_dict.get("year", 0)), int(time_dict.get("month", 0)), int(time_dict.get("day", 0))]


## 回满跨越检测（事件型通知 3/6 通用）：值从 < max 跨到 ≥ max 即触发。
## 源 vit_full/skill_full tag="once"——每次回满推一次，消耗后再满再推（本检测等价）。
static func crossed_full(old_value: int, new_value: int, max_value: int) -> bool:
	return old_value < max_value and new_value >= max_value
