class_name ExcavateSearchPanel
extends PopWindow

## 藏宝地穴搜索场景（View 层）— 照源 ui/excavate/search.lua。
## search_button → 检查次数/金币 → search_icon 圆周动画 → ExcavateManager.search → 结果反馈。
## 单机化：源 ed.ui.excavate.search 联机 → 本地 mgr.search（roll+扣金+加 monster 矿点）。
## 阶段 1：搜索成功 Toast 结果（map 展示阶段 2 接）；history 按钮接 ExcavateHistoryPanel。
## P1（2026-07-16）：bg.jpg + frame_bg excavate_empty.jpg + backbtn + Scale9 按钮 + search 按钮纹理
## （tavern_button_1 + excavate_icon_search_1）+ LSTR MAP.TODAY/ERRORINFO.INSUFFICIENT/MAP.DIAMOND_MINE。

const BG_TEX: String = "res://assets/ui/alpha/HVGA/bg.jpg"   # 源 uieditor excavatesearch:12 bg.jpg
const FRAME_BG_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_empty.jpg"   # 源 :118 frame_bg
const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png"
const TITLE_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_title.png"
const MAGNIFIER_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_magnifier.png"
# 源 :177-184 back_button（backbtn.png，场景级返回）
const BACK_TEX: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const BACK_P_TEX: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
# 源 :307-321 search_button（tavern_button_1 Scale9 capInsets 21.88,19.53,73.44,20.31 + icon_search_1 标签）
const SEARCH_BTN_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_1.png"
const SEARCH_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_2.png"
const SEARCH_BTN_CAP: Rect2 = Rect2(21.88, 19.53, 73.44, 20.31)
const SEARCH_LABEL_RES: String = "res://assets/ui/alpha/HVGA/excavate/excavate_icon_search_1.png"
const SEARCH_LABEL_PRESS_RES: String = "res://assets/ui/alpha/HVGA/excavate/excavate_icon_search_2.png"
# 源 :68-101 explain/histroy_button（Scale9 sell_number_button）
const SCALE9_BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const SCALE9_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const SCALE9_BTN_CAP: Rect2 = Rect2(15.63, 15.63, 18.75, 18.75)
const BTN_LABEL_COLOR: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
const GOLD_ICON_TEX: String = "res://assets/ui/alpha/HVGA/goldicon_small.png"
const COLOR_COST_OK: Color = Color(1.0, 174.0 / 255.0, 53.0 / 255.0)   # 源 search.lua:88 ccc3(255,174,53)
const COLOR_COST_LOW: Color = Color(1.0, 0.0, 0.0)                       # 源 search.lua:86 ccc3(255,0,0)
const FRAME_W: float = 520.0
const FRAME_H: float = 400.0
const TITLE_Y: float = 18.0
const ICON_SIZE: float = 48.0
const BTN_SIZE: Vector2 = Vector2(160.0, 50.0)
const SMALL_FONT: int = 18
const SEARCH_ANIM_DEG_PER_SEC: float = 180.0   # 源 search.lua:29 palstance=180
const SEARCH_ANIM_RADIUS: float = 20.0          # 源 :30 radius=20
const SEARCH_ANIM_DURATION: float = 1.5         # 圆周动画时长（≈1 圈 + 缓冲）
# 源 map.lua:951-955 TYPE_NAME LSTR 映射（搜索结果反馈用）
const LSTR_DIAMOND_KEY: String = "MAP.DIAMOND_MINE"
const TYPE_DIAMOND_FALLBACK: String = "钻石矿"
const LSTR_GOLD_KEY: String = "MAP.GOLDMINE"
const TYPE_GOLD_FALLBACK: String = "金矿"
const LSTR_ITEM_KEY: String = "MAP.LABORATORY"
const TYPE_ITEM_FALLBACK: String = "实验室"
# 源 map.lua:158-159 搜索上限 toast
const LSTR_TOAST_MAX_KEY: String = "MAP.TODAY_THE_SEARCH_HAS_REACHED_THE_MAXIMUM_NUMBER_OF_TIMES_"
const TOAST_MAX_FALLBACK: String = "今日搜索次数已达上限"
# 源 excavate.lua:300 lack_money → ERRORINFO.INSUFFICIENT_COINS
const LSTR_TOAST_LACK_KEY: String = "ERRORINFO.INSUFFICIENT_COINS"
const TOAST_LACK_FALLBACK: String = "金币不足"
const TOAST_NO_CANDIDATE: String = "附近没有可搜索的矿点"   # 单机兜底（源无对应 LSTR）
# 源 :464 EXCAVATEHISTORY.DEFENSIVE_RECORD = "防守记录"
const LSTR_HISTORY_KEY: String = "EXCAVATEHISTORY.DEFENSIVE_RECORD"
const HISTORY_FALLBACK: String = "防守记录"
# 源 :488 EXCAVATEMAP.RULES = "规则"
const LSTR_EXPLAIN_KEY: String = "EXCAVATEMAP.RULES"
const EXPLAIN_FALLBACK: String = "规则"
# 源 search.lua:84 cost_label 直接显示数字（无前缀文本）
const SEARCH_FOUND_FMT: String = "搜到 %s（%s 人）！"   # 单机 Toast 兜底
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
	pd = p_pd
	rng = p_rng
	setup()
	_build_ui()
	_refresh_cost()


# 源 LSTR 走 pd.cm（已加载）；未初始化 fallback 中文兜底。
func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


func _build_ui() -> void:
	# 源 :12 bg.jpg 整体背景（满屏）
	var bg := TextureRect.new()
	bg.texture = load(BG_TEX)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = Vector2(960, 640)
	bg.position = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	# 源 :118 frame_bg（excavate_empty.jpg，frame_container 内层背景）
	var frame_bg := TextureRect.new()
	frame_bg.texture = load(FRAME_BG_TEX)
	frame_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_bg.size = Vector2(FRAME_W - 20.0, FRAME_H - 20.0)
	frame_bg.position = Vector2(960.0 * 0.5 - (FRAME_W - 20.0) * 0.5, 640.0 * 0.5 - (FRAME_H - 20.0) * 0.5)
	frame_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(frame_bg)
	var frame := TextureRect.new()
	frame.texture = load(FRAME_TEX)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	frame.size = Vector2(FRAME_W, FRAME_H)
	frame.position = Vector2(960.0 * 0.5 - FRAME_W * 0.5, 640.0 * 0.5 - FRAME_H * 0.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(frame)
	_add_back(frame)
	_add_title(frame)
	_add_search_icon(frame)
	_add_search_button(frame)
	_add_bottom_buttons(frame)


# 源 :177-184 back_button（backbtn.png）
func _add_back(frame: TextureRect) -> void:
	var back := TextureButton.new()
	back.texture_normal = load(BACK_TEX)
	back.texture_pressed = load(BACK_P_TEX)
	back.ignore_texture_size = true
	back.size = Vector2(50, 50)
	back.position = Vector2(12, 12)
	back.pressed.connect(remove_window)
	frame.add_child(back)


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


# 源 :307-321 search_button（tavern_button_1 Scale9 + icon_search_1 标签覆盖）
func _add_search_button(frame: TextureRect) -> void:
	_search_button = UiScale9Button.make(SEARCH_BTN_RES, SEARCH_BTN_PRESS_RES, Vector2(frame.size.x * 0.5 - BTN_SIZE.x * 0.5, 220.0), BTN_SIZE, SEARCH_BTN_CAP)
	_search_button.pressed.connect(_on_search_pressed)
	frame.add_child(_search_button)
	# 源 :377-388 search_label（excavate_icon_search_1.png 覆盖在 search_button 上）
	var search_label := TextureButton.new()
	search_label.texture_normal = load(SEARCH_LABEL_RES)
	search_label.texture_pressed = load(SEARCH_LABEL_PRESS_RES)
	search_label.ignore_texture_size = true
	search_label.size = Vector2(141, 53)
	search_label.position = Vector2(frame.size.x * 0.5 - 70.5, 218.0)
	search_label.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 装饰图标，点击穿透到 _search_button
	search_label.disabled = true   # 防 TextureButton 自带点击反馈
	_search_button.add_child(search_label)
	# 消耗标签 + gold icon（源 :329 gold_icon + :351 cost_label）
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


# 源 :68-101 explain/histroy_button（Scale9 sell_number_button + LSTR 标签）
func _add_bottom_buttons(frame: TextureRect) -> void:
	var explain: Button = UiScale9Button.make(SCALE9_BTN_RES, SCALE9_BTN_PRESS_RES, Vector2(40, frame.size.y - 45), Vector2(110, 40), SCALE9_BTN_CAP, _lstr(LSTR_EXPLAIN_KEY, EXPLAIN_FALLBACK), BTN_LABEL_COLOR)
	explain.pressed.connect(_on_explain_pressed)
	frame.add_child(explain)
	var history: Button = UiScale9Button.make(SCALE9_BTN_RES, SCALE9_BTN_PRESS_RES, Vector2(frame.size.x - 150, frame.size.y - 45), Vector2(110, 40), SCALE9_BTN_CAP, _lstr(LSTR_HISTORY_KEY, HISTORY_FALLBACK), BTN_LABEL_COLOR)
	history.pressed.connect(_on_history_pressed)
	frame.add_child(history)


# 刷新消耗标签（照 refreshCostLabel:80）：颜色随金币够否。
func _refresh_cost() -> void:
	var cost: int = ExcavateData.get_search_cost(pd.cm, pd.excavate.search_times)
	_cost_label.text = str(cost)   # 源 :84 setString(label, tostring(cost)) 无前缀
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


# 源 map.lua:951-955 en 映射（Gold/Diamond/Item 矿点名）
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
	# 照源接 ExcavateHistoryPanel（同 excavate_map_panel:233）
	var panel := ExcavateHistoryPanel.new("excavate_history", {})
	panel.setup_panel(pd)
	panel.show_window(get_parent())
