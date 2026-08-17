class_name ExcavateHistoryPanel
extends PopWindow

## 防守记录（View 层）— 照源 ui/popwindow/excavatehistory.lua（218 行）+ uieditor/
## excavatehistory.lua（窗口声明表）+ uieditor/itemexcavatehistory.lua（行条目表）。
## 两件套（excavate 批 Task 3，2026-08-17）：框/标题条/标题/关闭钮/滚动区静态进
## excavate_history_content.tscn（A 类债 #5：框归源 package_herolist_bg fix_wh
## 568.75x409.22，弃 excavate_main_frame 600x440 误用）；行=模板 excavate_history_item.tscn
## + ExcavateHistoryRowBuilder（fill 数据 + tag 互斥 + ed.right2 定位）。本文件只做
## 装配/信号/空态切换。
## 单机化（2026-07-18 既定口径，数据层 excavate_history.gd 为源）：源"被攻击记录"
## （联机 query）→ 单机"玩家自己战斗记录"（pd.excavate.history）；vit_button+red_tag
## （_vatility 恒 0 无防御体力奖励）与 enemy_svr_name（无服务器）不建；
## 空态文案"暂无战斗记录"为单机自创兜底（源无空态）。
## 引用范式（e0fba4b 定）：ExcavateBattleReportPanel 走全局 class_name 实例化，
## 消 ui→view/battle preload 路径依赖——勿改回 preload。
## fill 时序：行 fill 须在入树后（ed.right2 定位量文本宽依赖 theme 上下文），
## 故 chrome 在 setup_panel 建、行在 show_window（入树后）填。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_history_content.tscn")
const TITLE_KEY: String = "EXCAVATEHISTORY.DEFENSIVE_RECORD"
const TITLE_FALLBACK: String = "防守记录"
const EMPTY_TEXT: String = "暂无战斗记录"   # 单机自创兜底（源无空态）

var pd: PlayerData


func setup_panel(p_pd: PlayerData) -> void:
	pd = p_pd
	setup()
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	(content.get_node("%TitleLabel") as Label).text = _lstr(TITLE_KEY, TITLE_FALLBACK)


# 入树后填行（theme 上下文就绪，ActionLabel ed.right2 定位可量文本宽）。
func show_window(parent: Node) -> void:
	super.show_window(parent)
	if is_inside_tree():
		_fill_rows()


# 两件套 fill：空/非空分支 + 行列表（行内 fill 全在 ExcavateHistoryRowBuilder）。
func _fill_rows() -> void:
	var content: Control = container.get_node_or_null("ExcavateHistoryContent") as Control
	if content == null:
		return
	var records: Array = pd.excavate.history.get_all()
	var empty_label: Label = content.get_node("%EmptyLabel") as Label
	var scroll: Control = content.get_node("%HistoryScroll") as Control
	if records.is_empty():
		empty_label.text = EMPTY_TEXT
		empty_label.visible = true
		scroll.visible = false
		return
	empty_label.visible = false
	scroll.visible = true
	var list_host: VBoxContainer = content.get_node("%HistoryList") as VBoxContainer
	var items: Array = ExcavateHistoryRowBuilder.build_rows(list_host, records, pd.cm)
	for i in items:
		var item: Control = i as Control
		var check: BaseButton = item.get_node("%CheckBtn") as BaseButton
		check.pressed.connect(_on_check.bind(int(item.get_meta(&"record_id"))))


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# 查看战报（源 check_button clickHandler → excavatebattlereport.pop(id)）。
func _on_check(record_id: int) -> void:
	var panel := ExcavateBattleReportPanel.new("excavate_battle_report", {})
	panel.setup_panel(pd, record_id)
	panel.show_window(get_parent())
