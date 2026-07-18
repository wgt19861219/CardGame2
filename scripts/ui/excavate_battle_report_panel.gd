class_name ExcavateBattleReportPanel
extends PopWindow

## 战斗战报（View 层）— 照源 ui/popwindow/excavatebattlereport.lua layout + getInitHandler:76。
## 单条战斗明细：第 N 战 + 双方阵容（left=敌方, right=我方）+ 胜/败 tag。
## 单机化：源 replay_button 联机 query_replay 回放 → 单机裁（无回放数据）；
## 源 readhero.createIcon 英雄头像 → 简化 Label（tid/Lv/rank/stars），ReadheroIcon 接入留视觉完善；
## 源 playerData 头像/等级/名 → 单机裁（单机玩家信息独立系统）。
##
## 重构（2026-07-18，hero_detail 范式）：chrome（frame/close/title/两侧 PanelContainer 框架 + head
## label）静态化进 scenes/ui/excavate_battle_report_content.tscn；fill 动态文本（title/name/tag color）
## + 英雄行 procedural 挂 %EnemyHeroes/%SelfHeroes。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_battle_report_content.tscn")
const FONT_SMALL: int = 12
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


# 建 UI：preload .tscn instantiate + fill 动态数据 + 绑信号。
# 位置/size 静态节点（frame/close/title/两侧 panel + head label）已在 .tscn 固化。
func _build_ui(record_id: int) -> void:
	var record: Dictionary = pd.excavate.history.get_record(record_id)
	var won: bool = String(record.get("result", "")) == ExcavateHistory.RESULT_WIN
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	# 源 :84 setLabelString(THE) .. index .. setLabelString(BATTLE) = "第" + 1 + "战"
	# 单机单条记录即第 1 战（源多波列表联机，单机裁）
	var title_text: String = _lstr(LSTR_THE_KEY, THE_FALLBACK) + "1" + _lstr(LSTR_BATTLE_KEY, BATTLE_FALLBACK)
	(content.get_node("%Title") as Label).text = title_text
	# 源 keys[i] left=oppo/right=self + tag_win/lose + hicon_container 渲染英雄
	_fill_side(content, ENEMY_LABEL, record.get("oppo_team", {}), not won, "%EnemyName", "%EnemyTag", "%EnemyHeroes")
	_fill_side(content, SELF_LABEL, record.get("self_team", {}), won, "%SelfName", "%SelfTag", "%SelfHeroes")


# 源 LSTR 走 pd.cm（已加载）；未初始化 fallback 中文兜底。
func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# 单侧 fill：name/tag 文本+颜色，英雄行 procedural 挂 %XxxHeroes。
func _fill_side(content: Control, label_text: String, team_data: Dictionary, side_won: bool,
		name_path: String, tag_path: String, heroes_path: String) -> void:
	(content.get_node(name_path) as Label).text = label_text
	var tag: Label = content.get_node(tag_path) as Label
	tag.text = WIN_TEXT if side_won else LOSE_TEXT
	tag.add_theme_color_override("font_color", COLOR_WIN if side_won else COLOR_LOSE)
	var heroes_host: VBoxContainer = content.get_node(heroes_path) as VBoxContainer
	for c in heroes_host.get_children():
		c.queue_free()
	var heroes: Array = team_data.get("_hero", [])
	if heroes.is_empty():
		heroes_host.add_child(_make_hero_label(EMPTY_HERO_TEXT))
		return
	var count: int = mini(heroes.size(), MAX_HEROES)
	for i in range(count):
		var hero: Dictionary = heroes[i]
		var base: Dictionary = hero.get("_base", {})   # _base 照源（history 记录 {"_base":{...}}）
		var text: String = HERO_FMT % [int(base.get("_tid", 0)), int(base.get("_level", 0)), int(base.get("_rank", 0)), int(base.get("_stars", 0))]
		heroes_host.add_child(_make_hero_label(text))


func _make_hero_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font", FONT_SMALL)
	lbl.add_theme_color_override("font_color", COLOR_BODY)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
