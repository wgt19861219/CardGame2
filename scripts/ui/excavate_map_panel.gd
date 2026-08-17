class_name ExcavateMapPanel
extends PopWindow

## 藏宝地穴主地图（View 层）— 照源 ui/excavate/map.lua + uieditor/excavatemap.lua 声明表。
## 两件套（excavate 批 Task 7，2026-08-17）：静态结构 45 节点全在
## excavate_map_content.tscn（frame 双层/title/back/翻页钮/页签壳/信息面板/研究组/
## 雾/放大镜），本脚本只业务 + 信号 connect + fill。
## 矿点动态格子（ore_bg 名条 + cycle 图标热区，源 createMap:543 ore_points 常量）
## 与页签动态图标（源 refreshPageTag:1052）为业务层动态内容，保留本层。
## 单机受控裁剪：FCA 旗帜动画/复仇遮罩/多人防御点（源 :1249 createRevengeShade、
## :561-762 多点布防）→ 单卡片点开 ExcavateTeamPanel；翻页滑窗动画（源 :456-477）
## → 直切；fog fade 1s+icon 转圈 2s → 压缩并行 1.5s；attack/revenge 页签态（联机
## 并发）与矿上限 VIP Toast（数据层 VIP 接口缺失）不做；矿点 owner 文字标签与
## InfoLabel/PageLabel（迁移发明的文本化替代）删除，信息由照源产量行/页签承载。


const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_map_content.tscn")
const TEX_CS: float = 1.28125   # 纹理像素→点（无 TextureConfig 条目，÷CS 口径）
# 矿点热区与位置（源 map.lua:4-19 ore_points[1][1]=(510,275)、ore_bg_pos=(510,285)
# frame_container 局部；Godot y-down：480.47-cy）
const NODE_W: float = 200.0
const NODE_H: float = 200.0
const NODE_POS: Vector2 = Vector2(510.0, 205.47)
const ORE_BG_POS: Vector2 = Vector2(510.0, 195.47)
# 页签布局（源 refreshPageTag:1054-1065：最多 5 个、间距 50 居中）
const TAG_MAX: int = 5
const TAG_DX: float = 50.0
const TAG_CENTER_Y: float = 39.065   # page_tag_container 78.13 高的中心
# 搜索动画（源 showFog:25-70 getMoveCircleAction palstance=180/radius=20，压缩并行）
const SEARCH_ANIM_DEG_PER_SEC: float = 180.0
const SEARCH_ANIM_RADIUS: float = 20.0
const SEARCH_ANIM_DURATION: float = 1.5
# cycle/tag 贴图（源 page_tag_res:1035-1051 + createMap:567）
const CYCLE_TEX_BASE: String = "res://assets/ui/alpha/HVGA/excavate/excavate_cycle_"
const CYCLE_KEY_DIAMOND: String = "diamond"
const CYCLE_KEY_GOLD: String = "gold"
const CYCLE_KEY_POTION: String = "potion"
const TAG_SEARCH_MARK: String = "res://assets/ui/alpha/HVGA/excavate/excavate_cycle_search.png"
const TAG_MARK_OFFSET: Vector2 = Vector2(10.0, 0.0)
# title 9 图（源 refreshPageTitle:1193-1203 title_res[1..9]；main_title 仅搜索期
# initPageTitle 临时替换 :1188-1190）
const TITLE_MAIN: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_title.png"
const TITLE_RES: Dictionary = {
	1: "res://assets/ui/alpha/HVGA/excavate/excavate_name_diamond_1.png",
	2: "res://assets/ui/alpha/HVGA/excavate/excavate_name_diamond_2.png",
	3: "res://assets/ui/alpha/HVGA/excavate/excavate_name_diamond_3.png",
	4: "res://assets/ui/alpha/HVGA/excavate/excavate_name_gold_1.png",
	5: "res://assets/ui/alpha/HVGA/excavate/excavate_name_gold_2.png",
	6: "res://assets/ui/alpha/HVGA/excavate/excavate_name_gold_3.png",
	7: "res://assets/ui/alpha/HVGA/excavate/excavate_name_exp_1.png",
	8: "res://assets/ui/alpha/HVGA/excavate/excavate_name_exp_2.png",
	9: "res://assets/ui/alpha/HVGA/excavate/excavate_name_exp_3.png",
}
const NO_NODE_TEXT: String = "暂无矿点，点击「搜索」发现矿点"   # 单机空态护栏（源 checkWork 空数据即弹走无空态）
# LSTR keys + fallbacks（源 map.lua 各处 T(LSTR(...))）
const LSTR_EXPLAIN_KEY: String = "EXCAVATEMAP.RULES"
const EXPLAIN_FALLBACK: String = "规则"
const LSTR_HISTORY_KEY: String = "EXCAVATEHISTORY.DEFENSIVE_RECORD"
const HISTORY_FALLBACK: String = "防守记录"
const LSTR_DIAMOND_KEY: String = "RECHARGE.DIAMOND"
const NAME_DIAMOND_FALLBACK: String = "钻石"
const LSTR_GOLD_KEY: String = "TASK.GOLD"
const NAME_GOLD_FALLBACK: String = "金币"
const LSTR_ITEM_KEY: String = "EQUIP.EXPERIENCE_CREAMS"
const NAME_ITEM_FALLBACK: String = "经验药膏"
const LSTR_TOAST_MAX_KEY: String = "MAP.TODAY_THE_SEARCH_HAS_REACHED_THE_MAXIMUM_NUMBER_OF_TIMES_"
const TOAST_MAX_FALLBACK: String = "今日搜索次数已达上限"
const LSTR_TOAST_LACK_KEY: String = "ERRORINFO.INSUFFICIENT_COINS"
const TOAST_LACK_FALLBACK: String = "金币不足"
const SEARCH_FOUND_FMT: String = "搜到 %s（%s 人）！"   # 单机 Toast 兜底（照 search 面板同款）
const COLOR_COST_LOW: Color = Color(1.0, 0.0, 0.0)   # 源 refreshCostLabel:1216 ccc3(255,0,0)
const ExcavateTeamPanel = preload("res://scripts/ui/excavate_team_panel.gd")
const ExcavateExplainPanel = preload("res://scripts/ui/excavate_explain_panel.gd")
const ExcavateHistoryPanel = preload("res://scripts/ui/excavate_history_panel.gd")

var pd: PlayerData
var rng: BattleRng
var _index: int = 0
# 动态矿点格子（业务层：源 createMap 每次翻页重建，单机单卡片常驻换贴图）
var _ore_bg: TextureRect
var _node_button: Button
var _node_icon: TextureRect
# fill 引用（静态节点 % 取）
var _title: TextureRect
var _tag_host: Control
var _tag_shade_left: Control
var _tag_shade_right: Control
var _il: Control
var _empty_label: Label
var _cost_label: Label
var _search_label: Control
var _research_label: Control
var _left_arrow: TextureButton
var _right_arrow: TextureButton
var _search_icon: TextureRect
var _fog: TextureRect
# 搜索动画态（源 showFog/destroyFog）
var _searching: bool = false
var _search_angle: float = 0.0
var _search_center: Vector2 = Vector2.ZERO
var _search_duration: float = 0.0


func setup_panel(p_pd: PlayerData, p_rng: BattleRng) -> void:
	pd = p_pd
	rng = p_rng
	_index = 0
	setup()
	_build_content()
	_refresh_node()


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# 建 UI：instantiate + 信号 connect + 动态矿点格子挂 %NodeHost（源 clipNode z=2 层）。
# 按钮三态/字号/颜色全走 theme variation（ExcavateNavBtn/ExcavateSearchBtn/
# ExcavateNodeBtn/ExcavateCostLabel/ProduceTitle/ProduceValue），本层零运行时样式。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_title = content.get_node("%Title") as TextureRect
	_left_arrow = content.get_node("%LeftButton") as TextureButton
	_right_arrow = content.get_node("%RightButton") as TextureButton
	_left_arrow.pressed.connect(_on_prev)
	_right_arrow.pressed.connect(_on_next)
	(content.get_node("%BackButton") as BaseButton).pressed.connect(remove_window)
	# 信息面板引用（源 info_layer 子树；产量行 fill 下沉 ExcavateMapFills）
	var il: Control = content.get_node("%InfoLayer") as Control
	_il = il
	_empty_label = il.get_node("%EmptyLabel") as Label
	_cost_label = il.get_node("%ResearchFrame/ResearchContainer/%CostLabel") as Label
	_search_label = il.get_node("%ResearchFrame/ResearchContainer/%ResearchButton/SearchLabel") as Control
	_research_label = il.get_node("%ResearchFrame/ResearchContainer/%ResearchButton/ResearchLabel") as Control
	var research_btn: Button = il.get_node("%ResearchFrame/ResearchContainer/%ResearchButton") as Button
	research_btn.pressed.connect(_on_search_pressed)
	var explain_btn: Button = il.get_node("%ExplainButton") as Button
	explain_btn.text = _lstr(LSTR_EXPLAIN_KEY, EXPLAIN_FALLBACK)
	explain_btn.pressed.connect(_on_explain)
	var histroy_btn: Button = il.get_node("%HistroyButton") as Button   # 源节点名 histroy_button（源拼写如此）
	histroy_btn.text = _lstr(LSTR_HISTORY_KEY, HISTORY_FALLBACK)
	histroy_btn.pressed.connect(_on_history)
	# 页签与搜索动画元素
	_tag_host = content.get_node("%PageTagContainer/%TagHost") as Control
	_tag_shade_left = content.get_node("%PageTagContainer/%TagShadeLeft") as Control
	_tag_shade_right = content.get_node("%PageTagContainer/%TagShadeRight") as Control
	_search_icon = content.get_node("%SearchIcon") as TextureRect
	_fog = content.get_node("%SearchFog") as TextureRect
	# 动态矿点格子：ore_bg 名条 + 透明热区 Button + 等比 cycle 图标（源 createMap:543）
	var node_host: Control = content.get_node("%NodeHost") as Control
	_ore_bg = TextureRect.new()
	_ore_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ore_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node_host.add_child(_ore_bg)
	_node_button = Button.new()
	_node_button.theme_type_variation = &"ExcavateNodeBtn"
	_node_button.size = Vector2(NODE_W, NODE_H)
	_node_button.position = NODE_POS - Vector2(NODE_W, NODE_H) * 0.5
	_node_button.pressed.connect(_on_node_clicked)
	node_host.add_child(_node_button)
	_node_icon = TextureRect.new()
	_node_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_node_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_node_button.add_child(_node_icon)


# 主 fill（源 refresh:389-421）：矿点格子贴图 + title + 产量行 + 页签 + 消耗 + 箭头。
func _refresh_node() -> void:
	var list: Array = pd.excavate.get_data_list()
	_empty_label.visible = list.is_empty()
	_node_button.visible = not list.is_empty()
	_ore_bg.visible = not list.is_empty()
	if list.is_empty():
		_empty_label.text = NO_NODE_TEXT
		_tag_host.get_parent().visible = false   # page_tag_container
		_show_arrows()
		return
	_index = clampi(_index, 0, list.size() - 1)
	var d: Dictionary = list[_index]
	var type_id: int = int(d["_type_id"])
	_refresh_title(type_id)
	_refresh_node_cell(d, type_id)
	ExcavateMapFills.refresh_records(_il, pd, d, type_id, _cycle_key(type_id))
	_refresh_page_tag()
	_refresh_cost()
	_refresh_search_label()
	_show_arrows()


# title 贴图（源 refreshPageTitle:1192-1207 title_res[typeid]；typeid 越界回退 gold_1）。
func _refresh_title(type_id: int) -> void:
	var path: String = String(TITLE_RES.get(type_id, TITLE_RES[4]))
	_title.texture = _load_tex(path)


# 矿点格子（源 createMap:543-580 ore_bg=getRow().Picture + defense_point 图标；
# 单机 cycle 图标受控裁剪，picture_res 缺 Picture 降级 name 图）。图标÷CS 等比居中。
func _refresh_node_cell(d: Dictionary, type_id: int) -> void:
	var ore_tex: Texture2D = _load_tex(ExcavateData.picture_res(pd.cm, type_id))
	_ore_bg.texture = ore_tex
	if ore_tex != null:
		_ore_bg.size = Vector2(ore_tex.get_width(), ore_tex.get_height()) / TEX_CS
		_ore_bg.position = ORE_BG_POS - _ore_bg.size * 0.5
	var icon_tex: Texture2D = _load_tex(_cycle_texture(type_id))
	_node_icon.texture = icon_tex
	if icon_tex != null:
		_node_icon.size = Vector2(icon_tex.get_width(), icon_tex.get_height()) / TEX_CS
		_node_icon.position = (Vector2(NODE_W, NODE_H) - _node_icon.size) * 0.5


# 产量行 fill 下沉 ExcavateMapFills（源 refreshBaseRecord:318 + refreshCountTime:230）。

# 页签（源 refreshPageTag:1052-1186：≤5 全显居中间距 50；当前页 selected 态 +
# search 点加角标；attack/revenge 态与滑窗动画单机受控裁剪；>5 窗口两端 shade 提示）。
func _refresh_page_tag() -> void:
	var list: Array = pd.excavate.get_data_list()
	var ptc: Control = _tag_host.get_parent() as Control
	for child: Node in _tag_host.get_children():
		_tag_host.remove_child(child)
		child.queue_free()
	if list.size() < TAG_MAX:
		_tag_shade_left.visible = false
		_tag_shade_right.visible = false
	if list.size() < 2:
		ptc.visible = false
		return
	ptc.visible = true
	var n: int = mini(list.size(), TAG_MAX)
	var ci: float = float(n + 1) * 0.5
	var bi: int = 1
	if list.size() > TAG_MAX:
		bi = clampi(_index + 1 - (TAG_MAX + 1) / 2 + 1, 1, list.size() - TAG_MAX + 1)
		_tag_shade_left.visible = bi > 1
		_tag_shade_right.visible = bi + TAG_MAX - 1 < list.size()
	for i: int in range(n):
		var data_index: int = bi + i - 1
		var d: Dictionary = list[data_index]
		var selected: bool = data_index == _index
		var tex: Texture2D = _load_tex(_tag_texture(int(d["_type_id"]), selected))
		var icon: TextureRect = TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = tex
		if tex != null:
			icon.size = Vector2(tex.get_width(), tex.get_height()) / TEX_CS
			icon.position = Vector2((float(i + 1) - ci) * TAG_DX, TAG_CENTER_Y) - icon.size * 0.5
		_tag_host.add_child(icon)
		if int(d["_id"]) == pd.excavate.search_id and not pd.excavate.get_searched().is_empty():
			var mark: TextureRect = TextureRect.new()
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.texture = _load_tex(TAG_SEARCH_MARK)
			if mark.texture != null:
				mark.size = Vector2(mark.texture.get_width(), mark.texture.get_height()) / TEX_CS
				mark.position = icon.size * 0.5 + TAG_MARK_OFFSET - mark.size * 0.5
			icon.add_child(mark)


# 消耗标签（源 refreshCostLabel:1209-1220：数值 + 颜色随金币够否，红态清 G/B 通道）。
func _refresh_cost() -> void:
	var cost: int = ExcavateData.get_search_cost(pd.cm, pd.excavate.search_times)
	_cost_label.text = str(cost)
	if cost > int(pd.hero_manager.gold):
		_cost_label.modulate = COLOR_COST_LOW
	else:
		_cost_label.modulate = Color.WHITE


# 搜索/再探索图标二态（源 refresh:407-413 checkSearching：有进行中搜索点 → another）。
func _refresh_search_label() -> void:
	var searched: Dictionary = pd.excavate.get_searched()
	var searching: bool = not searched.is_empty() and String(searched.get("_owner", "")) != ExcavateManager.OWNER_MINE
	_search_label.visible = not searching
	_research_label.visible = searching


# 箭头显隐（源 showArrow:513-530：单点双隐；首页隐左/末页隐右）。
func _show_arrows() -> void:
	var size: int = pd.excavate.get_data_list().size()
	_left_arrow.visible = size > 1 and _index > 0
	_right_arrow.visible = size > 1 and _index < size - 1


# map 内搜索（照源 registerSearchButton:137-204 clickHandler → showFog 链，单机化：
# 检查 max_time/lack_money → fog 淡入 + icon 圆周动画（并行压缩 1.5s）→ 完成后
# ExcavateManager.search → focus 新点；矿上限 VIP Toast 受控裁剪）。
func _on_search_pressed() -> void:
	if _searching:
		return
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = pd.excavate.can_search(pd, now)
	if not bool(r["ok"]):
		match String(r["reason"]):
			ExcavateManager.REASON_MAX_TIME:
				Toast.show_message(_lstr(LSTR_TOAST_MAX_KEY, TOAST_MAX_FALLBACK))
			ExcavateManager.REASON_LACK_MONEY:
				Toast.show_message(_lstr(LSTR_TOAST_LACK_KEY, TOAST_LACK_FALLBACK))
		return
	_searching = true
	_search_angle = 0.0
	_search_center = _search_icon.position
	_search_duration = SEARCH_ANIM_DURATION
	_search_icon.visible = true
	_title.texture = _load_tex(TITLE_MAIN)
	var tween: Tween = create_tween()
	tween.tween_property(_fog, "modulate:a", 1.0, SEARCH_ANIM_DURATION)


func _process(delta: float) -> void:
	if not _searching:
		return
	_search_angle += deg_to_rad(SEARCH_ANIM_DEG_PER_SEC) * delta
	_search_icon.position = _search_center + Vector2(cos(_search_angle), sin(_search_angle)) * SEARCH_ANIM_RADIUS
	_search_duration -= delta
	if _search_duration <= 0.0:
		_finish_search()


# 搜索完成（源 destroyFog:72-96：search 回调 → 刷新 + 雾散 + 搜索结果 Toast）。
func _finish_search() -> void:
	_searching = false
	_search_icon.visible = false
	_search_icon.position = _search_center
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = pd.excavate.search(pd, rng, now)
	if not bool(r["ok"]):
		match String(r["reason"]):
			ExcavateManager.REASON_MAX_TIME:
				Toast.show_message(_lstr(LSTR_TOAST_MAX_KEY, TOAST_MAX_FALLBACK))
			ExcavateManager.REASON_LACK_MONEY:
				Toast.show_message(_lstr(LSTR_TOAST_LACK_KEY, TOAST_LACK_FALLBACK))
		_fade_out_fog()
		return
	var type_id: int = int(r["type_id"])
	Toast.show_message(SEARCH_FOUND_FMT % [_produce_name(type_id), str(ExcavateData.max_player(pd.cm, type_id))])
	_index = pd.excavate.get_data_list().size() - 1   # focus 新搜到的点（源 initMap(getSearchedID)）
	_refresh_node()
	_fade_out_fog()


func _fade_out_fog() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fog, "modulate:a", 0.0, SEARCH_ANIM_DURATION)


# 翻页（源 turnPage/doTurnPage:427-504：边界不翻，翻后刷新联动）。
func _on_prev() -> void:
	if _index <= 0:
		return
	_index -= 1
	_refresh_node()


func _on_next() -> void:
	if _index >= pd.excavate.get_data_list().size() - 1:
		return
	_index += 1
	_refresh_node()


# 点矿点 → ExcavateTeamPanel（源 :736-753 defense_point clickHandler）。
func _on_node_clicked() -> void:
	var list: Array = pd.excavate.get_data_list()
	if list.is_empty() or _index >= list.size():
		return
	var excavate_id: int = int(list[_index]["_id"])
	var panel := ExcavateTeamPanel.new("excavate_team", {})
	panel.setup_panel(pd, excavate_id, rng, _on_team_closed)
	panel.show_window(get_parent())


func _on_team_closed() -> void:
	_refresh_node()


func _on_explain() -> void:
	var panel := ExcavateExplainPanel.new("excavate_explain", {})
	panel.setup_panel()
	panel.show_window(get_parent())


## 战报入口（照源 map.lua:126 ed.ui.excavatehistory.pop()）。
func _on_history() -> void:
	var panel := ExcavateHistoryPanel.new("excavate_history", {})
	panel.setup_panel(pd)
	panel.show_window(get_parent())


## 聚焦指定 excavate_id 矿点（翻到该页）。excavate 战斗结束重弹时调，定位刚打的矿点。
func focus_excavate(excavate_id: int) -> void:
	var list: Array = pd.excavate.get_data_list()
	for i in range(list.size()):
		if int(list[i]["_id"]) == excavate_id:
			_index = i
			_refresh_node()
			return


# ── 内部工具 ──

func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# 产类 → cycle 键（源 createMap:553-559 reward_type 反查 + page_tag_res 键）。
func _cycle_key(type_id: int) -> String:
	match ExcavateData.produce_type(pd.cm, type_id):
		ExcavateData.PRODUCE_DIAMOND:
			return CYCLE_KEY_DIAMOND
		ExcavateData.PRODUCE_GOLD:
			return CYCLE_KEY_GOLD
		ExcavateData.PRODUCE_ITEM:
			return CYCLE_KEY_POTION
	return CYCLE_KEY_GOLD


func _cycle_texture(type_id: int) -> String:
	return CYCLE_TEX_BASE + _cycle_key(type_id) + ".png"


func _tag_texture(type_id: int, selected: bool) -> String:
	var suffix: String = "_current" if selected else ""
	return CYCLE_TEX_BASE + _cycle_key(type_id) + suffix + ".png"


# 产类中文名（源 map.lua:951-960 epn 映射，搜索 Toast 用）。
func _produce_name(type_id: int) -> String:
	match ExcavateData.produce_type(pd.cm, type_id):
		ExcavateData.PRODUCE_DIAMOND:
			return _lstr(LSTR_DIAMOND_KEY, NAME_DIAMOND_FALLBACK)
		ExcavateData.PRODUCE_GOLD:
			return _lstr(LSTR_GOLD_KEY, NAME_GOLD_FALLBACK)
		ExcavateData.PRODUCE_ITEM:
			return _lstr(LSTR_ITEM_KEY, NAME_ITEM_FALLBACK)
	return _lstr(LSTR_GOLD_KEY, NAME_GOLD_FALLBACK)
