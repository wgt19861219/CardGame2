class_name ExcavateBattleReportPanel
extends PopWindow

## 战斗战报（View 层）— 照源 ui/popwindow/excavatebattlereport.lua layout + getInitHandler:76。
## 单条战斗明细：第 N 战 + 双方阵容（left=敌方, right=我方）+ 胜/败 tag。
## 单机化：源 replay_button 联机 query_replay 回放 → 单机裁（无回放数据）；
## 源 readhero.createIcon 英雄头像 → 简化 Label（tid/Lv/rank/stars），ReadheroIcon 接入留视觉完善；
## 源 playerData 头像/等级/名 → 单机裁（单机玩家信息独立系统）。

const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png"
const CLOSE_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_P_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const FONT_TITLE: int = 20
const FONT_BODY: int = 14
const FONT_SMALL: int = 12
const FRAME_W: float = 600.0
const FRAME_H: float = 440.0
const SIDE_W: float = 260.0
const SIDE_H: float = 300.0
const SIDE_Y: float = 110.0
const COLOR_WIN: Color = Color(0.2, 0.8, 0.2)
const COLOR_LOSE: Color = Color(0.9, 0.2, 0.2)
const COLOR_BODY: Color = Color(65.0 / 255.0, 57.0 / 255.0, 54.0 / 255.0)
const WIN_TEXT: String = "胜"   # 源 tag_win.png 图标（无 LSTR）
const LOSE_TEXT: String = "败"   # 源 tag_lose.png 图标（无 LSTR）
# 源 excavateteam.lua 无 fixed self/enemy 标签；playerData._name 直接显示，单机用 "我方/敌方" 兜底
const SELF_LABEL: String = "我方"
const ENEMY_LABEL: String = "敌方"
# 源 excavatebattlereport.lua:84 "第" + index + "战"（THE+BATTLE 两 LSTR key 拼接）
const LSTR_THE_KEY: String = "EXCAVATEBATTLEREPORT.THE"
const THE_FALLBACK: String = "第"
const LSTR_BATTLE_KEY: String = "EXCAVATEBATTLEREPORT.BATTLE"
const BATTLE_FALLBACK: String = "战"
const HERO_FMT: String = "英雄 tid %d  Lv%d  R%d  ★%d"   # 源 readhero.createIcon 头像（无 LSTR 文本）
const EMPTY_HERO_TEXT: String = "（无英雄数据）"   # 单机兜底
const MAX_HEROES: int = 5   # 照源 :127 for j=1,5

var pd: PlayerData


func setup_panel(p_pd: PlayerData, record_id: int) -> void:
	pd = p_pd
	setup()
	_build_ui(record_id)


func _build_ui(record_id: int) -> void:
	var record: Dictionary = pd.excavate.history.get_record(record_id)
	var won: bool = String(record.get("result", "")) == ExcavateHistory.RESULT_WIN
	var bg := TextureRect.new()
	bg.texture = load(FRAME_TEX)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	bg.size = Vector2(FRAME_W, FRAME_H)
	bg.position = Vector2(960.0 * 0.5 - FRAME_W * 0.5, 640.0 * 0.5 - FRAME_H * 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	_add_close(bg)
	_add_title(bg, 1)   # 单机单条记录即第 1 战（源多波列表联机，单机裁）
	_add_side(bg, ENEMY_LABEL, record.get("oppo_team", {}), not won, 40.0)
	_add_side(bg, SELF_LABEL, record.get("self_team", {}), won, 300.0)


func _add_close(frame: TextureRect) -> void:
	var close := TextureButton.new()
	close.texture_normal = load(CLOSE_TEX)
	close.texture_pressed = load(CLOSE_P_TEX)
	close.ignore_texture_size = true
	close.size = Vector2(40, 40)
	close.position = Vector2(frame.size.x - 50, 12)
	close.pressed.connect(remove_window)
	frame.add_child(close)


func _add_title(frame: TextureRect, index: int) -> void:
	var title := Label.new()
	# 源 :84 setLabelString(THE) .. index .. setLabelString(BATTLE) = "第" + 1 + "战"
	title.text = _lstr(LSTR_THE_KEY, THE_FALLBACK) + str(index) + _lstr(LSTR_BATTLE_KEY, BATTLE_FALLBACK)
	title.position = Vector2(0, 60)
	title.size = Vector2(frame.size.x, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font", FONT_TITLE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title)


# 源 LSTR 走 pd.cm（已加载）；未初始化 fallback 中文兜底。
func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


## 单侧阵容（照源 keys[i] left=oppo/right=self + tag_win/lose + hicon_container 渲染英雄）。
func _add_side(frame: TextureRect, label_text: String, team_data: Dictionary, side_won: bool, x: float) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(x, SIDE_Y)
	panel.custom_minimum_size = Vector2(SIDE_W, SIDE_H)
	frame.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_font_size_override("font", FONT_BODY)
	name_lbl.add_theme_color_override("font_color", COLOR_BODY)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(name_lbl)
	var tag := Label.new()
	tag.text = WIN_TEXT if side_won else LOSE_TEXT
	tag.add_theme_font_size_override("font", FONT_BODY)
	tag.add_theme_color_override("font_color", COLOR_WIN if side_won else COLOR_LOSE)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tag)
	vbox.add_child(head)
	var heroes: Array = team_data.get("_hero", [])
	if heroes.is_empty():
		var empty := Label.new()
		empty.text = EMPTY_HERO_TEXT
		empty.add_theme_font_size_override("font", FONT_SMALL)
		empty.add_theme_color_override("font_color", COLOR_BODY)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(empty)
		return
	var count: int = mini(heroes.size(), MAX_HEROES)
	for i in range(count):
		var hero: Dictionary = heroes[i]
		var base: Dictionary = hero.get("_base", {})   # _base 照源（history 记录 {"_base":{...}}）
		var hl := Label.new()
		hl.text = HERO_FMT % [int(base.get("_tid", 0)), int(base.get("_level", 0)), int(base.get("_rank", 0)), int(base.get("_stars", 0))]
		hl.add_theme_font_size_override("font", FONT_SMALL)
		hl.add_theme_color_override("font_color", COLOR_BODY)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(hl)
