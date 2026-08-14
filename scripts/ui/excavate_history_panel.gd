class_name ExcavateHistoryPanel
extends PopWindow

## 战斗历史（View 层）— 照源 ui/popwindow/excavatehistory.lua layout + getInitHandler:45。
## 列表展示玩家 excavate 战斗记录：胜/败 tag + 敌人名 + 矿点名 + 相对时间 + 查看战报按钮。
## 单机化：源"被攻击记录"（联机 query）→ 单机"玩家自己战斗记录"（mgr.history）；
## vit_button 裁（源防御体力联机，单机无防御战）；enemy_svr_name 裁（单机无服务器）。
##
## 重构（2026-07-18，hero_detail 范式）：chrome（frame/close/title/empty_label/scroll/list）静态化进
## scenes/ui/excavate_history_content.tscn；行（tag+info+check）数量随记录变，保留 procedural 挂
## %HistoryList。坐标照 procedural 硬编码值翻译（frame 600×440 居中保持现有行为，非源 fix_wh
## 568.75×409.22；close/title/list 均相对 frame 局部 +frame origin 180,100 合成全局 offset）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_history_content.tscn")
const FONT_TITLE: int = 20
const FONT_BODY: int = 14
const COLOR_WIN: Color = Color(0.2, 0.8, 0.2)
const COLOR_LOSE: Color = Color(0.9, 0.2, 0.2)
const COLOR_BODY: Color = Color(65.0 / 255.0, 57.0 / 255.0, 54.0 / 255.0)
const WIN_TEXT: String = "胜"
const LOSE_TEXT: String = "败"
const CHECK_TEXT: String = "战报"
const LSTR_ATTACK_KEY: String = "EXCAVATEHISTORY.ATTACK_YOUR__S"
const ATTACK_FALLBACK_FMT: String = "偷袭了你的%s"
const EMPTY_TEXT: String = "暂无战斗记录"   # 源空状态无文本（自创中文兜底）
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

var pd: PlayerData


func setup_panel(p_pd: PlayerData) -> void:
	pd = p_pd
	setup()
	_build_content()


# 建 UI：preload .tscn instantiate + fill 动态列表 + 绑关闭信号。
# 位置/size 静态节点（frame/close/title/empty_label/scroll/list）已在 .tscn 固化。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	_fill_list(content)


# 填列表（照原 _add_list）：空状态切 EmptyLabel，非空往 %HistoryList 加行。
func _fill_list(content: Control) -> void:
	var records: Array = pd.excavate.history.get_all()
	var empty_label: Label = content.get_node("%EmptyLabel") as Label
	var scroll: ScrollContainer = content.get_node("%HistoryScroll") as ScrollContainer
	if records.is_empty():
		empty_label.text = EMPTY_TEXT
		empty_label.visible = true
		scroll.visible = false
		return
	empty_label.visible = false
	scroll.visible = true
	var vbox: VBoxContainer = content.get_node("%HistoryList") as VBoxContainer
	for r in records:
		vbox.add_child(_build_item(r))


func _build_item(record: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var won: bool = String(record.get("result", "")) == ExcavateHistory.RESULT_WIN
	var tag := Label.new()
	tag.text = WIN_TEXT if won else LOSE_TEXT
	tag.add_theme_font_size_override("font", FONT_TITLE)
	tag.add_theme_color_override("font_color", COLOR_WIN if won else COLOR_LOSE)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tag)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	var type_id: int = int(record.get("excavate_id", 0))
	var name_lbl := Label.new()
	name_lbl.text = String(record.get("enemy_name", ""))
	name_lbl.add_theme_font_size_override("font", FONT_BODY)
	name_lbl.add_theme_color_override("font_color", COLOR_BODY)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_lbl)
	var mine_lbl := Label.new()
	var dis_name: String = ExcavateData.display_name(pd.cm, type_id)
	mine_lbl.text = _lstr(LSTR_ATTACK_KEY, ATTACK_FALLBACK_FMT) % dis_name
	mine_lbl.add_theme_font_size_override("font", FONT_BODY)
	mine_lbl.add_theme_color_override("font_color", COLOR_BODY)
	mine_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(mine_lbl)
	var time_lbl := Label.new()
	time_lbl.text = _relative_time(int(record.get("_time", 0)))
	time_lbl.add_theme_font_size_override("font", FONT_BODY)
	time_lbl.add_theme_color_override("font_color", COLOR_BODY)
	time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(time_lbl)
	row.add_child(info)
	var check := Button.new()
	check.text = CHECK_TEXT
	check.custom_minimum_size = Vector2(60, 36)
	check.pressed.connect(_on_check.bind(int(record.get("_id", 0))))
	row.add_child(check)
	return row


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


## 相对时间显示（照源 :73-85 dd/dh/dm/dt 分档，4 个 LSTR key）。
func _relative_time(time_point: int) -> String:
	var now: int = int(Time.get_unix_time_from_system())
	var dt: int = now - time_point
	if dt < 0:
		dt = 0
	if dt >= SECONDS_PER_DAY:
		return _lstr(LSTR_DAY_KEY, DAY_FALLBACK_FMT) % (dt / SECONDS_PER_DAY)
	if dt >= SECONDS_PER_HOUR:
		return _lstr(LSTR_HOUR_KEY, HOUR_FALLBACK_FMT) % (dt / SECONDS_PER_HOUR)
	if dt >= SECONDS_PER_MINUTE:
		return _lstr(LSTR_MIN_KEY, MIN_FALLBACK_FMT) % (dt / SECONDS_PER_MINUTE)
	return _lstr(LSTR_SEC_KEY, SEC_FALLBACK_FMT) % dt


func _on_check(record_id: int) -> void:
	var panel := ExcavateBattleReportPanel.new("excavate_battle_report", {})
	panel.setup_panel(pd, record_id)
	panel.show_window(get_parent())
