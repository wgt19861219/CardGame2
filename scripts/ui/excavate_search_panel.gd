class_name ExcavateSearchPanel
extends PopWindow

## 藏宝地穴搜索场景（View 层）— 照源 ui/excavate/search.lua + uieditor/excavatesearch.lua。
## 两件套（excavate 批 Task 4，2026-08-17）：静态结构全在 excavate_search_content.tscn
## （bg/frame_container 子树/search_frame 子树/三按钮），本脚本只业务 + 信号 connect + fill。
## search_button → 检查次数/金币 → search_icon 圆周动画（源 registerSearchButton:28
## getMoveCircleAction palstance=180/radius=20/target=1）→ ExcavateManager.search → Toast。
## 单机化：源 ed.ui.excavate.search 联网 → 本地 mgr.search；金币不足源走 useMidas 补金
## 弹窗，单机直接 Toast 金币不足；搜索完跳 map。
## 受控裁剪：history_red_tag（源 refreshHistoryTag:92-101 依赖服务器已读标记
## checkUnreadExcavateHistory，数据层无对应状态恒不可见，节点不建，照 history 批
## vit_button 同口径）；源 :121-127 按钮文案超宽 scale 钳制（中文 88<100/44<50 恒不触发）省略。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_search_content.tscn")
const COLOR_COST_LOW: Color = Color(1.0, 0.0, 0.0)   # 源 refreshCostLabel:86 ccc3(255,0,0)
const SEARCH_ANIM_DEG_PER_SEC: float = 180.0         # 源 palstance=180
const SEARCH_ANIM_RADIUS: float = 20.0               # 源 radius=20
const SEARCH_ANIM_DURATION: float = 1.5              # 圆周动画时长（源 target=1 圈 + 缓冲）
const LSTR_DIAMOND_KEY: String = "MAP.DIAMOND_MINE"
const TYPE_DIAMOND_FALLBACK: String = "钻石矿"
const LSTR_GOLD_KEY: String = "MAP.GOLDMINE"
const TYPE_GOLD_FALLBACK: String = "金矿"
const LSTR_ITEM_KEY: String = "MAP.LABORATORY"
const TYPE_ITEM_FALLBACK: String = "实验室"
const LSTR_TOAST_MAX_KEY: String = "MAP.TODAY_THE_SEARCH_HAS_REACHED_THE_MAXIMUM_NUMBER_OF_TIMES_"
const TOAST_MAX_FALLBACK: String = "今日搜索次数已达上限"
const LSTR_TOAST_LACK_KEY: String = "ERRORINFO.INSUFFICIENT_COINS"
const TOAST_LACK_FALLBACK: String = "金币不足"
const TOAST_NO_CANDIDATE: String = "附近没有可搜索的矿点"   # 单机兜底（源无对应 LSTR）
const LSTR_HISTORY_KEY: String = "EXCAVATEHISTORY.DEFENSIVE_RECORD"
const HISTORY_FALLBACK: String = "防守记录"
const LSTR_EXPLAIN_KEY: String = "EXCAVATEMAP.RULES"
const EXPLAIN_FALLBACK: String = "规则"
const SEARCH_FOUND_FMT: String = "搜到 %s（%s 人）！"      # 单机 Toast 兜底
const ExcavateHistoryPanel = preload("res://scripts/ui/excavate_history_panel.gd")

var pd: PlayerData
var rng: BattleRng
var _search_icon: TextureRect
var _cost_label: Label
var _search_button: Button
var _searching: bool = false
var _search_angle: float = 0.0
var _search_center: Vector2 = Vector2.ZERO
var _search_duration: float = 0.0
var _pending_type_id: int = 0


func setup_panel(p_pd: PlayerData, p_rng: BattleRng) -> void:
	hud_identity = "excavate"   # 子场景精简 StatusBar（仅货币条，避头像区压返回钮；实跑反馈修复 2026-08-17）
	pd = p_pd
	rng = p_rng
	setup()
	_build_content()
	_refresh_cost()


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# 建 UI：preload .tscn instantiate + 绑信号 + LSTR 文案 fill。
# 按钮三态/字号/颜色全走 theme variation（ExcavateNavBtn/ExcavateSearchBtn/
# ExcavateCostLabel），本层零运行时样式。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%BackButton") as BaseButton).pressed.connect(remove_window)
	_search_icon = content.get_node("%SearchIcon") as TextureRect
	_search_button = content.get_node("%SearchButton") as Button
	_search_button.pressed.connect(_on_search_pressed)
	_cost_label = content.get_node("%CostLabel") as Label
	var explain: Button = content.get_node("%ExplainButton") as Button
	explain.text = _lstr(LSTR_EXPLAIN_KEY, EXPLAIN_FALLBACK)
	explain.pressed.connect(_on_explain_pressed)
	var history: Button = content.get_node("%HistroyButton") as Button   # 源节点名 histroy_button（源拼写如此）
	history.text = _lstr(LSTR_HISTORY_KEY, HISTORY_FALLBACK)
	history.pressed.connect(_on_history_pressed)


# 刷新消耗标签（照源 refreshCostLabel:80-90）：数值 + 颜色随金币够否。
# 二态走 fill modulate（theme 基色橙 ccc3(255,174,53)，红态 (1,0,0) 清 G/B 通道）。
func _refresh_cost() -> void:
	var cost: int = ExcavateData.get_search_cost(pd.cm, pd.excavate.search_times)
	_cost_label.text = str(cost)
	if cost > int(pd.hero_manager.gold):
		_cost_label.modulate = COLOR_COST_LOW
	else:
		_cost_label.modulate = Color.WHITE


# 搜索（照源 registerSearchButton:10-44 clickHandler + doSearchExcavateReply:291）。
func _on_search_pressed() -> void:
	if _searching:
		return
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = pd.excavate.search(pd, rng, now)
	if bool(r["ok"]):
		_pending_type_id = int(r["type_id"])
		_search_button.disabled = true
		_start_search_anim()
		return
	match String(r["reason"]):
		ExcavateManager.REASON_MAX_TIME:
			Toast.show_message(_lstr(LSTR_TOAST_MAX_KEY, TOAST_MAX_FALLBACK))
		ExcavateManager.REASON_LACK_MONEY:
			Toast.show_message(_lstr(LSTR_TOAST_LACK_KEY, TOAST_LACK_FALLBACK))
		ExcavateManager.REASON_NO_CANDIDATE:
			Toast.show_message(TOAST_NO_CANDIDATE)


func _start_search_anim() -> void:
	_searching = true
	_search_angle = 0.0
	_search_center = _search_icon.position
	_search_duration = SEARCH_ANIM_DURATION


func _process(delta: float) -> void:
	if not _searching:
		return
	_search_angle += deg_to_rad(SEARCH_ANIM_DEG_PER_SEC) * delta
	_search_icon.position = _search_center + Vector2(cos(_search_angle), sin(_search_angle)) * SEARCH_ANIM_RADIUS
	_search_duration -= delta
	if _search_duration <= 0.0:
		_finish_search()


func _finish_search() -> void:
	_searching = false
	_search_icon.position = _search_center
	_search_button.disabled = false
	Toast.show_message(SEARCH_FOUND_FMT % [_type_name(_pending_type_id), str(ExcavateData.max_player(pd.cm, _pending_type_id))])
	remove_window()
	var mp := ExcavateMapPanel.new("excavate_map", {})
	mp.setup_panel(pd, rng)
	mp.show_window(get_parent())


func _type_name(type_id: int) -> String:
	match ExcavateData.produce_type(pd.cm, type_id):
		ExcavateData.PRODUCE_DIAMOND:
			return _lstr(LSTR_DIAMOND_KEY, TYPE_DIAMOND_FALLBACK)
		ExcavateData.PRODUCE_GOLD:
			return _lstr(LSTR_GOLD_KEY, TYPE_GOLD_FALLBACK)
		ExcavateData.PRODUCE_ITEM:
			return _lstr(LSTR_ITEM_KEY, TYPE_ITEM_FALLBACK)
	return _lstr(LSTR_GOLD_KEY, TYPE_GOLD_FALLBACK)


func _on_explain_pressed() -> void:
	var panel := ExcavateExplainPanel.new("excavate_explain", {})
	panel.setup_panel()
	panel.show_window(get_parent())


func _on_history_pressed() -> void:
	var panel := ExcavateHistoryPanel.new("excavate_history", {})
	panel.setup_panel(pd)
	panel.show_window(get_parent())
