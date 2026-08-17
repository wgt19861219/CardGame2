class_name ExcavateBattleReportPanel
extends PopWindow

## 挖矿战报（View 层 battle 域）— 照源 ui/popwindow/excavatebattlereport.lua（187 行）
## + uieditor/excavatebattlereport.lua（窗口表 95 行）+ uieditor/itemexcavatebattlereport.lua
## （条目表 127 行）+ uieditor/itemexcavatebattleplayer.lua（玩家行表 216 行）。
## 两件套（excavate 批 Task 5，2026-08-17）：窗口框（A 类债 #4 归源 main_vit_tips
## scaleSize 703.13x434.38，弃 excavate_main_frame 600x440 误用）/两侧标题/第 N 战
## 标题/vs/两侧容器静态进 excavate_battle_report_content.tscn；玩家行=模板
## excavate_battle_player_item.tscn + ExcavateBattlePlayerRowBuilder（本目录，
## fill 数据 + tag 互斥 + ReadheroIcon）。本文件只做装配/信号/文本 fill。
## 单机化受控裁剪：源多波 scrollview 列表（联机 data 数组逐条 push）→ 单机单条
## 静态（恒第 1 战）；replay_button（联机 query_replay 回放）不建；玩家行 avatar/
## 等级徽章容器照源建位不填（无 getTeamHead/getLevelIcon 基础设施，见 row_builder）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_battle_report_content.tscn")
const LSTR_THE_KEY: String = "EXCAVATEBATTLEREPORT.THE"
const THE_FALLBACK: String = "第"
const LSTR_BATTLE_KEY: String = "EXCAVATEBATTLEREPORT.BATTLE"
const BATTLE_FALLBACK: String = "战"
const LSTR_OFFENCE_KEY: String = "EXCAVATEBATTLEREPORT.OFFENCE"
const OFFENCE_FALLBACK: String = "进攻方"
const LSTR_DEFENDER_KEY: String = "EXCAVATEBATTLEREPORT.DEFENDER"
const DEFENDER_FALLBACK: String = "防守方"
# 单机单条记录即第 1 战（源多波列表联机，单机裁）
const BATTLE_INDEX: int = 1

var pd: PlayerData


func setup_panel(p_pd: PlayerData, record_id: int) -> void:
	pd = p_pd
	setup()
	var record: Dictionary = pd.excavate.history.get_record(record_id)
	var won: bool = String(record.get("result", "")) == ExcavateHistory.RESULT_WIN
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	(content.get_node("%TitleLabel") as Label).text = _lstr(LSTR_THE_KEY, THE_FALLBACK) \
		+ str(BATTLE_INDEX) + _lstr(LSTR_BATTLE_KEY, BATTLE_FALLBACK)
	(content.get_node("%EnemyTitle") as Label).text = _lstr(LSTR_OFFENCE_KEY, OFFENCE_FALLBACK)
	(content.get_node("%SelfTitle") as Label).text = _lstr(LSTR_DEFENDER_KEY, DEFENDER_FALLBACK)
	ExcavateBattlePlayerRowBuilder.fill_side(content.get_node("%EnemyContainer") as Control,
		record.get("oppo_team", {}), String(record.get("enemy_name", "")), not won, pd.cm)
	ExcavateBattlePlayerRowBuilder.fill_side(content.get_node("%SelfContainer") as Control,
		record.get("self_team", {}), pd.player_name, won, pd.cm)


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback
