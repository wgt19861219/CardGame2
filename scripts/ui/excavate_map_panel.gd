class_name ExcavateMapPanel
extends PopWindow

## 藏宝地穴地图（View 层）— 照源 ui/excavate/map.lua createMap:543 + registerTouchHandler:108。
## 当前矿点展示（picture + owner + 产量/存储）+ 翻页 + 点矿点→ExcavateTeamPanel + 搜索/说明入口。
## 单机简化：源 FCA 旗帜动画/复仇遮罩/多人防御点/翻页标签 → 静态单卡片 + 翻页（单机同时矿点少）。
## back → remove_window 回主城。search 按钮 → 重新搜索（回 SearchPanel）。
## 重构（2026-07-17，hero_detail 范式）：panel 层静态节点（bg/frame/title/back/nav/info_label/
## page_label/explain/history）固化进 excavate_map_content.tscn；_node_button 动态挂 %NodeHost
## （Button + 运行时 cycle texture StyleBox）。Scale9 按钮用 .tscn 普通 Button + apply_with_label。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_map_content.tscn")
# 源 :256/283 explain/histroy_button Scale9 sell_number_button capInsets 15.63,15.63,18.75,18.75
const SCALE9_BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const SCALE9_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const SCALE9_BTN_CAP: Rect2 = Rect2(15.63, 15.63, 18.75, 18.75)
const BTN_LABEL_COLOR: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
const CYCLE_TEX_DIAMOND: String = "res://assets/ui/alpha/HVGA/excavate/excavate_cycle_diamond.png"
const CYCLE_TEX_GOLD: String = "res://assets/ui/alpha/HVGA/excavate/excavate_cycle_gold.png"
const CYCLE_TEX_POTION: String = "res://assets/ui/alpha/HVGA/excavate/excavate_cycle_potion.png"
const NODE_W: float = 200.0
const NODE_H: float = 200.0
# _node_button 全局坐标（原 frame 局部 (200,70) + frame offset (180,100)，保持当前行为）
const NODE_POS_X: float = 380.0
const NODE_POS_Y: float = 170.0
const OWNER_MINE_LABEL: String = "我方占领"   # 单机兜底（源 sprite 显示无 LSTR）
const OWNER_MONSTER_LABEL: String = "野外怪守（可攻击占领）"   # 单机兜底
const PRODUCE_LABEL_FMT: String = "产出：%s/%d"
const STORAGE_LABEL_FMT: String = "存储剩余：%d"
const NO_NODE_TEXT: String = "暂无矿点，点击「搜索」发现矿点"   # 单机空状态（源无空态文本）
const NODE_BTN_MINE: String = "驻防/换队"   # 单机矿点按钮文本（源 sprite 显示）
const NODE_BTN_MONSTER: String = "查看/出战"
const PAGE_FMT: String = "%d / %d"
# 源 map.lua:951-960 资源名 LSTR 映射（Gold/Diamond/Item）
const LSTR_DIAMOND_KEY: String = "RECHARGE.DIAMOND"
const NAME_DIAMOND_FALLBACK: String = "钻石"
const LSTR_GOLD_KEY: String = "TASK.GOLD"
const NAME_GOLD_FALLBACK: String = "金币"
const LSTR_ITEM_KEY: String = "EQUIP.EXPERIENCE_CREAMS"
const NAME_ITEM_FALLBACK: String = "经验药膏"
# 源 :464 EXCAVATEHISTORY.DEFENSIVE_RECORD = "防守记录"（histroy_button_label）
const LSTR_HISTORY_KEY: String = "EXCAVATEHISTORY.DEFENSIVE_RECORD"
const HISTORY_FALLBACK: String = "防守记录"
# 源 :488 EXCAVATEMAP.RULES = "规则"（explain_button_label）
const LSTR_EXPLAIN_KEY: String = "EXCAVATEMAP.RULES"
const EXPLAIN_FALLBACK: String = "规则"
const ExcavateTeamPanel = preload("res://scripts/ui/excavate_team_panel.gd")
const ExcavateSearchPanel = preload("res://scripts/ui/excavate_search_panel.gd")
const ExcavateExplainPanel = preload("res://scripts/ui/excavate_explain_panel.gd")
const ExcavateHistoryPanel = preload("res://scripts/ui/excavate_history_panel.gd")

var pd: PlayerData
var rng: BattleRng
var _index: int = 0
var _node_button: Button
var _info_label: Label
var _page_label: Label


func setup_panel(p_pd: PlayerData, p_rng: BattleRng) -> void:
	pd = p_pd
	rng = p_rng
	_index = 0
	setup()
	_build_ui()
	_refresh_node()


# 源 LSTR 走 pd.cm（已加载）；未初始化 fallback 中文兜底。
func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# 建 UI：preload .tscn instantiate + fill 动态数据/样式 + 绑信号。
# 位置/size 静态节点（bg/frame/title/back/nav/info_label/page_label）已在 .tscn 固化。
func _build_ui() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%BackBtn") as TextureButton).pressed.connect(remove_window)
	(content.get_node("%PrevArrow") as TextureButton).pressed.connect(_on_prev)
	(content.get_node("%NextArrow") as TextureButton).pressed.connect(_on_next)
	# _node_button 动态建（Button + 运行时 cycle texture）挂 %NodeHost（保留 procedural 子组件）
	var node_host: Control = content.get_node("%NodeHost") as Control
	_node_button = Button.new()
	_node_button.size = Vector2(NODE_W, NODE_H)
	_node_button.position = Vector2(NODE_POS_X, NODE_POS_Y)
	_node_button.pressed.connect(_on_node_clicked)
	node_host.add_child(_node_button)
	# 静态 label 引用（font_size .tscn 已设，autowrap 运行时设）
	_info_label = content.get_node("%InfoLabel") as Label
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_label = content.get_node("%PageLabel") as Label
	# Scale9 按钮（.tscn 普通 Button 套九宫格 stylebox + LSTR 文字，视觉等价原 UiScale9Button.make）
	var explain: Button = content.get_node("%ExplainBtn") as Button
	UiScale9Button.apply_with_label(explain, SCALE9_BTN_RES, SCALE9_BTN_PRESS_RES, SCALE9_BTN_CAP, _lstr(LSTR_EXPLAIN_KEY, EXPLAIN_FALLBACK), BTN_LABEL_COLOR)
	explain.pressed.connect(_on_explain)
	var history: Button = content.get_node("%HistoryBtn") as Button
	UiScale9Button.apply_with_label(history, SCALE9_BTN_RES, SCALE9_BTN_PRESS_RES, SCALE9_BTN_CAP, _lstr(LSTR_HISTORY_KEY, HISTORY_FALLBACK), BTN_LABEL_COLOR)
	history.pressed.connect(_on_history)


func _refresh_node() -> void:
	var list: Array = pd.excavate.get_data_list()
	if list.is_empty():
		_node_button.visible = false
		_info_label.text = NO_NODE_TEXT
		_page_label.text = ""
		return
	_index = clampi(_index, 0, list.size() - 1)
	_node_button.visible = true
	var d: Dictionary = list[_index]
	var owner: String = String(d["_owner"])
	var type_id: int = int(d["_type_id"])
	var now: int = int(Time.get_unix_time_from_system())
	var owner_label: String = OWNER_MINE_LABEL if owner == "mine" else OWNER_MONSTER_LABEL
	var produce_str: String = ""
	if owner == "mine":
		produce_str = PRODUCE_LABEL_FMT % [_produce_name(type_id), pd.excavate.produce_amount(int(d["_id"]), now)]
		produce_str += "\n" + STORAGE_LABEL_FMT % pd.excavate.storage_remaining(int(d["_id"]), now)
		_node_button.text = NODE_BTN_MINE
	else:
		_node_button.text = NODE_BTN_MONSTER
	_apply_cycle_texture(type_id)
	_info_label.text = owner_label + "\n" + produce_str
	_page_label.text = PAGE_FMT % [_index + 1, list.size()]


func _on_prev() -> void:
	_index -= 1
	_refresh_node()


func _on_next() -> void:
	_index += 1
	_refresh_node()


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


func _on_search() -> void:
	# 单机入口保留（当前未直接挂按钮；源 search 走 research_button 在 map.lua:137-204）
	remove_window()
	var panel := ExcavateSearchPanel.new("excavate", {})
	panel.setup_panel(pd, rng)
	panel.show_window(get_parent())


func _on_explain() -> void:
	var panel := ExcavateExplainPanel.new("excavate_explain", {})
	panel.setup_panel()
	panel.show_window(get_parent())


## 战报入口（照源 map.lua:126 ed.ui.excavatehistory.pop()）。
func _on_history() -> void:
	var panel := ExcavateHistoryPanel.new("excavate_history", {})
	panel.setup_panel(pd)
	panel.show_window(get_parent())


# 源 map.lua:951-960 epn 映射（资源名 LSTR）
func _produce_name(type_id: int) -> String:
	match ExcavateData.produce_type(pd.cm, type_id):
		ExcavateData.PRODUCE_DIAMOND:
			return _lstr(LSTR_DIAMOND_KEY, NAME_DIAMOND_FALLBACK)
		ExcavateData.PRODUCE_GOLD:
			return _lstr(LSTR_GOLD_KEY, NAME_GOLD_FALLBACK)
		ExcavateData.PRODUCE_ITEM:
			return _lstr(LSTR_ITEM_KEY, NAME_ITEM_FALLBACK)
	return _lstr(LSTR_GOLD_KEY, NAME_GOLD_FALLBACK)


# 矿点旗帜 texture 按产出类型选 cycle 图（源 excavate_cycle_{diamond/gold/potion}.png）。
func _apply_cycle_texture(type_id: int) -> void:
	var tex_path: String = _cycle_texture(type_id)
	if not ResourceLoader.exists(tex_path):
		return
	var tex: Texture2D = load(tex_path) as Texture2D
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	_node_button.add_theme_stylebox_override("normal", sb)
	_node_button.add_theme_stylebox_override("hover", sb)
	_node_button.add_theme_stylebox_override("pressed", sb)


func _cycle_texture(type_id: int) -> String:
	match ExcavateData.produce_type(pd.cm, type_id):
		ExcavateData.PRODUCE_DIAMOND:
			return CYCLE_TEX_DIAMOND
		ExcavateData.PRODUCE_GOLD:
			return CYCLE_TEX_GOLD
		ExcavateData.PRODUCE_ITEM:
			return CYCLE_TEX_POTION
	return CYCLE_TEX_GOLD


## 聚焦指定 excavate_id 矿点（翻到该页）。excavate 战斗结束重弹时调，定位刚打的矿点。
func focus_excavate(excavate_id: int) -> void:
	var list: Array = pd.excavate.get_data_list()
	for i in range(list.size()):
		if int(list[i]["_id"]) == excavate_id:
			_index = i
			_refresh_node()
			return
