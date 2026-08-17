class_name ExcavateMapFills
extends RefCounted

## ExcavateMapPanel 产量行 fill（两件套 SOP：panel 逼近 View 550 行门槛时 fill 下沉）。
## 照源 ui/excavate/map.lua refreshBaseRecord:318-377 + refreshCountTime:230-316。
## 纯数据绑定：填标题/数值/资源图标三选一/倒计时行布局切换，禁建静态节点、禁样式
## override（静态结构在 excavate_map_content.tscn，字号颜色走 theme variation）。

# 信息面板 fill 布局（源 refreshCountTime:238-249 常量，Godot y-down 换算
# 39.06+cy-46.88；explain_bg 右下角锚定源 anchor(1,1)）
const EXPLAIN_BW_OTHER: float = 328.0
const EXPLAIN_BW_MINE: float = 420.0
const EXPLAIN_BH_SHORT: float = 127.0
const EXPLAIN_BH_TALL: float = 168.0
const LACK_POS: Vector2 = Vector2(-106.0, -3.8125)
const SPEED_POS: Vector2 = Vector2(-106.0, 30.1875)
const COUNT_POS_Y: float = 64.1875
const COUNT_POS_X_MINE: float = -152.0
const COUNT_POS_X_OTHER: float = -113.0
const HOUR_PER_MINUTE: float = 1.0 / 60.0
# LSTR keys + fallbacks（源 map.lua:331-349 各处 T(LSTR(...))）
const LSTR_LACK_MINE_KEY: String = "MAP.MY_ACCUMULATED_RESOURCES_"
const LACK_MINE_FALLBACK: String = "我的累计资源："
const LSTR_LACK_PLUNDER_KEY: String = "MAP.YOU_CAN_PLUNDER_"
const LACK_PLUNDER_FALLBACK: String = "可以掠夺："
const LSTR_SPEED_MINE_KEY: String = "MAP.MY_PRODUCTION_SPEED_"
const SPEED_MINE_FALLBACK: String = "我的生产速度："
const LSTR_SPEED_PLUNDER_KEY: String = "EXCAVATEMAP.PRODUCTION_SPEED_"
const SPEED_PLUNDER_FALLBACK: String = "生产速度："
const LSTR_HOUR_KEY: String = "TIME.HOUR"
const HOUR_FALLBACK: String = "小时"
const LSTR_PREPARE_KEY: String = "MAP._S_AFTER_THE_START_GENERATING_RESOURCES"
const PREPARE_FALLBACK: String = "%s后开始产生资源"
const LSTR_SOON_KEY: String = "MAP.THIS_TREASURE_IS_ABOUT_TO_FINISH_MINING"
const SOON_FALLBACK: String = "此宝藏即将开采完"
const LSTR_HOURS_KEY: String = "MAP.AFTER_MINING_APPROXIMATELY__D_HOURS"
const HOURS_FALLBACK: String = "约%d小时后开采完"
const LSTR_HM_KEY: String = "MAP.ABOUT__D_HOURS__D_MINUTES_AFTER_THE_COMPLETION_OF_MINING"
const HM_FALLBACK: String = "约%d小时%d分钟后开采完"
const CYCLE_KEY_GOLD: String = "gold"
const CYCLE_KEY_DIAMOND: String = "diamond"
const CYCLE_KEY_POTION: String = "potion"
# cycle 键 → 图标节点名尾缀（源节点 lack_icon_exp 用 exp，贴图却叫 cycle_potion，名不齐照源）
const ICON_SUFFIX: Dictionary = {
	CYCLE_KEY_GOLD: "Gold",
	CYCLE_KEY_DIAMOND: "Diamond",
	CYCLE_KEY_POTION: "Exp",
}


# 产量行（源 refreshBaseRecord:318-377）：标题/数值/资源图标三选一 + 倒计时行。
# cycle_key 由 panel 按 produce_type 预算（ExcavateMapPanel._cycle_key 同源表）。
static func refresh_records(il: Control, pd: PlayerData, d: Dictionary, type_id: int, cycle_key: String) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var excavate_id: int = int(d["_id"])
	var owner: String = String(d["_owner"])
	var speed_per_min: float = float(d["_produce_speed"])
	var storage_amount: int = 0
	var speed_amount: float = speed_per_min * 60.0
	if owner == ExcavateManager.OWNER_MINE:
		(il.get_node("%ExplainContainer/LackLabelContainer/%LackTitle") as Label).text = _lstr(pd, LSTR_LACK_MINE_KEY, LACK_MINE_FALLBACK)
		(il.get_node("%ExplainContainer/SpeedLabelContainer/%SpeedTitle") as Label).text = _lstr(pd, LSTR_SPEED_MINE_KEY, SPEED_MINE_FALLBACK)
		storage_amount = pd.excavate.produce_amount(excavate_id, now)
	else:
		(il.get_node("%ExplainContainer/LackLabelContainer/%LackTitle") as Label).text = _lstr(pd, LSTR_LACK_PLUNDER_KEY, LACK_PLUNDER_FALLBACK)
		(il.get_node("%ExplainContainer/SpeedLabelContainer/%SpeedTitle") as Label).text = _lstr(pd, LSTR_SPEED_PLUNDER_KEY, SPEED_PLUNDER_FALLBACK)
		storage_amount = int(float(pd.excavate.produced_total(excavate_id, now)) * ExcavateData.loot_ratio(pd.cm, type_id))
	var icons: Array[String] = [CYCLE_KEY_GOLD, CYCLE_KEY_DIAMOND, CYCLE_KEY_POTION]
	for k: String in icons:
		var suffix: String = String(ICON_SUFFIX[k])
		(il.get_node("%%ExplainContainer/LackLabelContainer/%%LackIcon%s" % suffix) as Control).visible = k == cycle_key
		(il.get_node("%%ExplainContainer/SpeedLabelContainer/%%SpeedIcon%s" % suffix) as Control).visible = k == cycle_key
	(il.get_node("%ExplainContainer/LackLabelContainer/%LackNumber") as Label).text = "x%d" % storage_amount
	var hour_suffix: String = _lstr(pd, LSTR_HOUR_KEY, HOUR_FALLBACK)
	if speed_amount - floorf(speed_amount) > 0.0:
		(il.get_node("%ExplainContainer/SpeedLabelContainer/%SpeedNumber") as Label).text = "x%.1f/%d%s" % [speed_amount, 1, hour_suffix]
	else:
		(il.get_node("%ExplainContainer/SpeedLabelContainer/%SpeedNumber") as Label).text = "x%d/%d%s" % [int(speed_amount), 1, hour_suffix]
	refresh_count_time(il, pd, d, owner)


# 倒计时行（源 refreshCountTime:230-316）：容器布局切换 + explain_bg 尺寸 + 文案分档。
static func refresh_count_time(il: Control, pd: PlayerData, d: Dictionary, owner: String) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var bw: float = EXPLAIN_BW_MINE if owner == ExcavateManager.OWNER_MINE else EXPLAIN_BW_OTHER
	var lack_ctn: Control = il.get_node("%ExplainContainer/LackLabelContainer") as Control
	var speed_ctn: Control = il.get_node("%ExplainContainer/SpeedLabelContainer") as Control
	var count_ctn: Control = il.get_node("%ExplainContainer/CountTimeContainer") as Control
	var count_label: Label = il.get_node("%ExplainContainer/CountTimeContainer/%CountTimeLabel") as Label
	var explain_bg: NinePatchRect = il.get_node("%ExplainBg") as NinePatchRect
	lack_ctn.visible = true
	speed_ctn.visible = true
	count_ctn.visible = false
	lack_ctn.position = LACK_POS
	speed_ctn.position = SPEED_POS
	var count_x: float = COUNT_POS_X_MINE if owner == ExcavateManager.OWNER_MINE else COUNT_POS_X_OTHER
	count_ctn.position = Vector2(count_x, COUNT_POS_Y)
	explain_bg.offset_left = explain_bg.offset_right - bw
	explain_bg.offset_top = explain_bg.offset_bottom - EXPLAIN_BH_SHORT
	if owner != ExcavateManager.OWNER_MINE:
		lack_ctn.visible = false
		speed_ctn.position = LACK_POS
		count_ctn.position = Vector2(count_x, SPEED_POS.y)
	var state: String = String(d["_state"])
	var end_ts: int = int(d.get("_state_end_ts", 0))
	var remain: float = float(end_ts - now)
	match state:
		ExcavateManager.STATE_PREPARE:
			speed_ctn.visible = false
			count_ctn.visible = true
			count_ctn.position = Vector2(count_x, SPEED_POS.y)
			count_label.text = _lstr(pd, LSTR_PREPARE_KEY, PREPARE_FALLBACK) % _hms(remain)
		ExcavateManager.STATE_OCCUPY:
			if owner == ExcavateManager.OWNER_MINE:
				count_ctn.visible = true
				explain_bg.offset_top = explain_bg.offset_bottom - EXPLAIN_BH_TALL
				count_label.text = _mine_finish_text(pd, d)
				if count_label.text.is_empty():
					count_ctn.visible = false
		ExcavateManager.STATE_PROTECT:
			if owner == ExcavateManager.OWNER_MINE:
				count_ctn.visible = true
				count_label.text = _lstr(pd, LSTR_SOON_KEY, SOON_FALLBACK)


# mine 开采完时间文案（源 :282-309：et=storage/speed 分钟，>1 分走时/分档否则即将完）。
static func _mine_finish_text(pd: PlayerData, d: Dictionary) -> String:
	var now: int = int(Time.get_unix_time_from_system())
	var speed: float = float(d["_produce_speed"])
	if speed <= 0.0:
		return ""
	var et: float = float(pd.excavate.storage_remaining(int(d["_id"]), now)) / speed
	if et <= 1.0:
		return _lstr(pd, LSTR_SOON_KEY, SOON_FALLBACK)
	var h: int = int(et * HOUR_PER_MINUTE)
	var m: int = int(et) % 60
	if m == 0:
		return _lstr(pd, LSTR_HOURS_KEY, HOURS_FALLBACK) % h
	return _lstr(pd, LSTR_HM_KEY, HM_FALLBACK) % [h, m]


static func _lstr(pd: PlayerData, key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# 秒 → 时:分:秒（源 ed.gethmsCString，prepare 倒计时文案）。
static func _hms(seconds: float) -> String:
	var s: int = maxi(int(seconds), 0)
	return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
