class_name ExcavateHistoryPanel
extends PopWindow

## 战斗历史（View 层）— 照源 ui/popwindow/excavatehistory.lua layout + getInitHandler:45。
## 列表展示玩家 excavate 战斗记录：胜/败 tag + 敌人名 + 矿点名 + 相对时间 + 查看战报按钮。
## 单机化：源"被攻击记录"（联机 query）→ 单机"玩家自己战斗记录"（mgr.history）；
## vit_button 裁（源防御体力联机，单机无防御战）；enemy_svr_name 裁（单机无服务器）。

const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png"
const TITLE_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_title.png"
const CLOSE_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_P_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const FONT_TITLE: int = 20
const FONT_BODY: int = 14
const FRAME_W: float = 600.0
const FRAME_H: float = 440.0
const LIST_X: float = 40.0
const LIST_Y: float = 80.0
const LIST_W: float = 520.0
const LIST_H: float = 320.0
const COLOR_WIN: Color = Color(0.2, 0.8, 0.2)
const COLOR_LOSE: Color = Color(0.9, 0.2, 0.2)
const COLOR_BODY: Color = Color(65.0 / 255.0, 57.0 / 255.0, 54.0 / 255.0)
# 源 excavatehistory.lua:65-69 tag_win/tag_lose（图，无 LSTR 文本）；单机用文字 "胜/败" 兜底
const WIN_TEXT: String = "胜"
const LOSE_TEXT: String = "败"
const CHECK_TEXT: String = "战报"   # 源 check_button 图标（无 LSTR）
# 源 excavatehistory.lua:100 EXCAVATEHISTORY.ATTACK_YOUR__S（"偷袭了你的%s"）
const LSTR_ATTACK_KEY: String = "EXCAVATEHISTORY.ATTACK_YOUR__S"
const ATTACK_FALLBACK_FMT: String = "偷袭了你的%s"
const EMPTY_TEXT: String = "暂无战斗记录"   # 源空状态无文本（自创中文兜底）
const SECONDS_PER_DAY: int = 86400
const SECONDS_PER_HOUR: int = 3600
const SECONDS_PER_MINUTE: int = 60
# 源 :78-84 时间相对格式（4 个 LSTR key，dd/dh/dm/dt 分档）
const LSTR_DAY_KEY: String = "EXCAVATEHISTORY._D_DAYS_AGO"
const DAY_FALLBACK_FMT: String = "%d天前"
const LSTR_HOUR_KEY: String = "PVP._D_HOURS_AGO"
const HOUR_FALLBACK_FMT: String = "%d小时前"
const LSTR_MIN_KEY: String = "PVP._D_MINUTES_AGO"
const MIN_FALLBACK_FMT: String = "%d分钟前"
const LSTR_SEC_KEY: String = "PVP._D_SECONDS_AGO"
const SEC_FALLBACK_FMT: String = "%d秒前"
const ExcavateBattleReportPanel = preload("res://scripts/ui/excavate_battle_report_panel.gd")

var pd: PlayerData


func setup_panel(p_pd: PlayerData) -> void:
	pd = p_pd
	setup()
	_build_ui()


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = load(FRAME_TEX)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	bg.size = Vector2(FRAME_W, FRAME_H)
	bg.position = Vector2(960.0 * 0.5 - FRAME_W * 0.5, 640.0 * 0.5 - FRAME_H * 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	_add_close(bg)
	_add_title(bg)
	_add_list(bg)


func _add_close(frame: TextureRect) -> void:
	var close := TextureButton.new()
	close.texture_normal = load(CLOSE_TEX)
	close.texture_pressed = load(CLOSE_P_TEX)
	close.ignore_texture_size = true
	close.size = Vector2(40, 40)
	close.position = Vector2(frame.size.x - 50, 12)
	close.pressed.connect(remove_window)
	frame.add_child(close)


func _add_title(frame: TextureRect) -> void:
	var title := TextureRect.new()
	title.texture = load(TITLE_TEX)
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var ts: Vector2 = load(TITLE_TEX).get_size()
	title.size = ts
	title.position = Vector2(frame.size.x * 0.5 - ts.x * 0.5, 12)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title)


func _add_list(frame: TextureRect) -> void:
	var records: Array = pd.excavate.history.get_all()
	if records.is_empty():
		var empty := Label.new()
		empty.text = EMPTY_TEXT
		empty.position = Vector2(LIST_X, LIST_Y)
		empty.size = Vector2(LIST_W, LIST_H)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font", FONT_BODY)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(empty)
		return
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(LIST_X, LIST_Y)
	scroll.size = Vector2(LIST_W, LIST_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)
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
	# 源 excavatehistory.lua:100 ATTACK_YOUR__S = "偷袭了你的%s"（disName = ExcavateTreasure Display Name）
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


# 源 LSTR 走 pd.cm（已加载）；未初始化 fallback 中文兜底。
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
