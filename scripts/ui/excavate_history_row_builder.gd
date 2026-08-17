class_name ExcavateHistoryRowBuilder
extends RefCounted

## 防守记录行动态构建（两件套范式，excavate 批 Task 3，2026-08-17）：
## 静态结构在 excavate_history_item.tscn 模板（照源 uieditor/itemexcavatehistory.lua 直译），
## 本类只实例化行 + 填动态数据 + 胜/败 tag 互斥切换（源 excavatehistory.lua getInitHandler:45-107）。
## check 按钮信号不在此接（panel 从返回行 meta record_id 接业务）。
## 单机受控裁剪（数据层 excavate_history.gd 恒 _vatility=0/无服务器）：
## vit_button/red_tag 领奖与 enemy_svr_name 服务器名不建。

const ITEM_SCENE: PackedScene = preload("res://scenes/ui/excavate_history_item.tscn")
# 源 excavatehistory.lua:96/107 ed.right2(label, ref, 10)：目标 label 定位在 ref 右侧 gap 10。
const RIGHT_GAP: float = 10.0
const SECONDS_PER_DAY: int = 86400
const SECONDS_PER_HOUR: int = 3600
const SECONDS_PER_MINUTE: int = 60
const LSTR_DAY_KEY: String = "EXCAVATEHISTORY._D_DAYS_AGO"
const DAY_FALLBACK_FMT: String = "%d天前"
const LSTR_HOUR_KEY: String = "PVP._D_HOURS_AGO"
const HOUR_FALLBACK_FMT: String = "%d小时前"
const LSTR_MIN_KEY: String = "PVP._D_MINUTES_AGO"
const MIN_FALLBACK_FMT: String = "%d分钟前"
const LSTR_SEC_KEY: String = "PVP._D_SECONDS_AGO"
const SEC_FALLBACK_FMT: String = "%d秒前"
const LSTR_ATTACK_KEY: String = "EXCAVATEHISTORY.ATTACK_YOUR__S"
const ATTACK_FALLBACK_FMT: String = "偷袭了你的%s"


## 建行列表（记录已按 _time 倒序传入）。返行 Control 列表（含 record_id meta）。
static func build_rows(list_host: VBoxContainer, records: Array, p_cm: Variant) -> Array:
	var items: Array = []
	for r in records:
		var record: Dictionary = r
		var item: Control = ITEM_SCENE.instantiate() as Control
		list_host.add_child(item)
		# 先入树再 fill：ed.right2 定位需 get_combined_minimum_size() 量文本宽，
		# 无树时 Label 无 theme 上下文量不出（实测 min size x=1）
		_fill_row(item, record, p_cm)
		items.append(item)
	return items


static func _fill_row(item: Control, record: Dictionary, p_cm: Variant) -> void:
	var won: bool = String(record.get("result", "")) == ExcavateHistory.RESULT_WIN
	(item.get_node("%TagWin") as CanvasItem).visible = won
	(item.get_node("%TagLose") as CanvasItem).visible = not won
	(item.get_node("%EnemyNameLabel") as Label).text = String(record.get("enemy_name", ""))
	var time_label: Label = item.get_node("%TimeLabel") as Label
	time_label.text = relative_time(int(record.get("_time", 0)), p_cm)
	# 行动文案（源 :97-107 ATTACK_YOUR__S % 矿点名 Display Name）+ ed.right2(time,10) 定位
	var action: Label = item.get_node("%ActionLabel") as Label
	var dis_name: String = ExcavateData.display_name(p_cm, int(record.get("excavate_id", 0)))
	action.text = _lstr(p_cm, LSTR_ATTACK_KEY, ATTACK_FALLBACK_FMT) % dis_name
	action.position = Vector2(time_label.position.x + time_label.get_combined_minimum_size().x + RIGHT_GAP, time_label.position.y)
	action.size = action.get_combined_minimum_size()
	item.set_meta(&"record_id", int(record.get("_id", 0)))


## 相对时间显示（照源 :73-85 dd/dh/dm/dt 分档，4 个 LSTR key；未来时间钳 0）。
static func relative_time(time_point: int, p_cm: Variant) -> String:
	var dt: int = int(Time.get_unix_time_from_system()) - time_point
	if dt < 0:
		dt = 0
	if dt >= SECONDS_PER_DAY:
		return _lstr(p_cm, LSTR_DAY_KEY, DAY_FALLBACK_FMT) % (dt / SECONDS_PER_DAY)
	if dt >= SECONDS_PER_HOUR:
		return _lstr(p_cm, LSTR_HOUR_KEY, HOUR_FALLBACK_FMT) % (dt / SECONDS_PER_HOUR)
	if dt >= SECONDS_PER_MINUTE:
		return _lstr(p_cm, LSTR_MIN_KEY, MIN_FALLBACK_FMT) % (dt / SECONDS_PER_MINUTE)
	return _lstr(p_cm, LSTR_SEC_KEY, SEC_FALLBACK_FMT) % dt


static func _lstr(p_cm: Variant, key: String, fallback: String) -> String:
	if p_cm != null:
		return (p_cm as ConfigManager).get_lstr(key)
	return fallback
