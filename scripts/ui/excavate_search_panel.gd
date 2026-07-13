class_name ExcavateSearchPanel
extends PopWindow

## 藏宝地穴搜索场景（View 层）— 照源 ui/excavate/search.lua。
## search_button → 检查次数/金币 → search_icon 圆周动画 → ExcavateManager.search → 结果反馈。
## 单机化：源 ed.ui.excavate.search 联机 → 本地 mgr.search（roll+扣金+加 monster 矿点）。
## 阶段 1：搜索成功 Toast 结果（map 展示阶段 2 接）；history 按钮接 ExcavateHistoryPanel。

const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png"
const TITLE_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_title.png"
const SEARCH_BUTTON_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_word_search.png"
const MAGNIFIER_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_magnifier.png"
const CLOSE_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_P_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const GOLD_ICON_TEX: String = "res://assets/ui/alpha/HVGA/goldicon_small.png"
const COLOR_COST_OK: Color = Color(1.0, 174.0 / 255.0, 53.0 / 255.0)   # 源 search.lua:88 ccc3(255,174,53)
const COLOR_COST_LOW: Color = Color(1.0, 0.0, 0.0)                       # 源 :86 ccc3(255,0,0)
const FRAME_W: float = 520.0
const FRAME_H: float = 400.0
const TITLE_Y: float = 18.0
const ICON_SIZE: float = 48.0
const BTN_SIZE: Vector2 = Vector2(160.0, 50.0)
const SMALL_FONT: int = 18
const SEARCH_ANIM_DEG_PER_SEC: float = 180.0   # 源 search.lua:29 palstance=180
const SEARCH_ANIM_RADIUS: float = 20.0          # 源 :30 radius=20
const SEARCH_ANIM_DURATION: float = 1.5         # 圆周动画时长（≈1 圈 + 缓冲）
const TYPE_NAME_DIAMOND: String = "钻石矿"
const TYPE_NAME_GOLD: String = "金币矿"
const TYPE_NAME_ITEM: String = "经验实验室"
const TOAST_MAX_TIME: String = "今日搜索次数已达上限"
const TOAST_LACK_MONEY: String = "金币不足，无法搜索"
const TOAST_NO_CANDIDATE: String = "附近没有可搜索的矿点"
const EXPLAIN_TEXT: String = "说明"
const HISTORY_TEXT: String = "历史"
const COST_LABEL_TEXT: String = "消耗："
const HISTORY_TODO: String = "「战史」待实现（阶段 3）"  # P2-3 已修：history 按钮接 ExcavateHistoryPanel
const SEARCH_FOUND_TEXT: String = "搜到 %s（%s 人）！"
const ExcavateHistoryPanel = preload("res://scripts/ui/excavate_history_panel.gd")

var pd: PlayerData
var rng: BattleRng
var _search_icon: TextureRect
var _cost_label: Label
var _search_button: TextureButton
var _searching: bool = false
var _search_angle: float = 0.0
var _search_center: Vector2 = Vector2.ZERO
var _search_duration: float = 0.0
var _pending_type_id: int = 0


func setup_panel(p_pd: PlayerData, p_rng: BattleRng) -> void:
	pd = p_pd
	rng = p_rng
	setup()
	_build_ui()
	_refresh_cost()


func _build_ui() -> void:
	var frame := TextureRect.new()
	frame.texture = load(FRAME_TEX)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	frame.size = Vector2(FRAME_W, FRAME_H)
	frame.position = Vector2(960.0 * 0.5 - FRAME_W * 0.5, 640.0 * 0.5 - FRAME_H * 0.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	_add_close(frame)
	_add_title(frame)
	_add_search_icon(frame)
	_add_search_button(frame)
	_add_bottom_buttons(frame)


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
	title.position = Vector2(frame.size.x * 0.5 - ts.x * 0.5, TITLE_Y)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title)


func _add_search_icon(frame: TextureRect) -> void:
	_search_icon = TextureRect.new()
	_search_icon.texture = load(MAGNIFIER_TEX)
	_search_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_search_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	_search_icon.position = Vector2(frame.size.x * 0.5 - ICON_SIZE * 0.5, 110.0)
	_search_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_search_icon)


func _add_search_button(frame: TextureRect) -> void:
	_search_button = TextureButton.new()
	_search_button.texture_normal = load(SEARCH_BUTTON_TEX)
	_search_button.ignore_texture_size = true
	_search_button.size = BTN_SIZE
	_search_button.position = Vector2(frame.size.x * 0.5 - BTN_SIZE.x * 0.5, 220.0)
	_search_button.pressed.connect(_on_search_pressed)
	frame.add_child(_search_button)
	# 消耗标签 + gold icon
	var gold_icon := TextureRect.new()
	gold_icon.texture = load(GOLD_ICON_TEX)
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.size = Vector2(24, 24)
	gold_icon.position = Vector2(frame.size.x * 0.5 - 60, 285.0)
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(gold_icon)
	_cost_label = Label.new()
	_cost_label.size = Vector2(120, 24)
	_cost_label.position = Vector2(frame.size.x * 0.5 - 30, 285.0)
	_cost_label.add_theme_font_size_override("font", SMALL_FONT)
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_cost_label)


func _add_bottom_buttons(frame: TextureRect) -> void:
	var explain := Button.new()
	explain.text = EXPLAIN_TEXT
	explain.size = Vector2(80, 32)
	explain.position = Vector2(40, frame.size.y - 45)
	explain.pressed.connect(_on_explain_pressed)
	frame.add_child(explain)
	var history := Button.new()
	history.text = HISTORY_TEXT
	history.size = Vector2(80, 32)
	history.position = Vector2(frame.size.x - 120, frame.size.y - 45)
	history.pressed.connect(_on_history_pressed)
	frame.add_child(history)


# 刷新消耗标签（照 refreshCostLabel:80）：颜色随金币够否。
func _refresh_cost() -> void:
	var cost: int = ExcavateData.get_search_cost(pd.cm, pd.excavate.search_times)
	_cost_label.text = COST_LABEL_TEXT + str(cost)
	if cost > int(pd.hero_manager.gold):
		_cost_label.add_theme_color_override("font_color", COLOR_COST_LOW)
	else:
		_cost_label.add_theme_color_override("font_color", COLOR_COST_OK)


# 搜索（照 registerSearchButton:4 clickHandler + doSearchExcavateReply:291）。
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
			Toast.show_message(TOAST_MAX_TIME)
		ExcavateManager.REASON_LACK_MONEY:
			Toast.show_message(TOAST_LACK_MONEY)
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
	Toast.show_message(SEARCH_FOUND_TEXT % [_type_name(_pending_type_id), str(ExcavateData.max_player(pd.cm, _pending_type_id))])
	remove_window()
	var mp := ExcavateMapPanel.new("excavate_map", {})
	mp.setup_panel(pd, rng)
	mp.show_window(get_parent())


func _type_name(type_id: int) -> String:
	match ExcavateData.produce_type(pd.cm, type_id):
		ExcavateData.PRODUCE_DIAMOND:
			return TYPE_NAME_DIAMOND
		ExcavateData.PRODUCE_GOLD:
			return TYPE_NAME_GOLD
		ExcavateData.PRODUCE_ITEM:
			return TYPE_NAME_ITEM
	return TYPE_NAME_GOLD


func _on_explain_pressed() -> void:
	var panel := ExcavateExplainPanel.new("excavate_explain", {})
	panel.setup_panel()
	panel.show_window(get_parent())


func _on_history_pressed() -> void:
	# P2-3 修复：照源接 ExcavateHistoryPanel（同 excavate_map_panel:233）
	var panel := ExcavateHistoryPanel.new("excavate_history", {})
	panel.setup_panel(pd)
	panel.show_window(get_parent())
