class_name ExcavateMapPanel
extends PopWindow

## 藏宝地穴地图（View 层）— 照源 ui/excavate/map.lua createMap:543 + registerTouchHandler:108。
## 当前矿点展示（picture + owner + 产量/存储）+ 翻页 + 点矿点→ExcavateTeamPanel + 搜索/说明入口。
## 单机简化：源 FCA 旗帜动画/复仇遮罩/多人防御点/翻页标签 → 静态单卡片 + 翻页（单机同时矿点少）。
## back → remove_window 回主城。search 按钮 → 重新搜索（回 SearchPanel）。

const MAIN_BG_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_bg.png"
const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png"
const TITLE_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_title.png"
const CLOSE_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_P_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const CYCLE_TEX_DIAMOND: String = "res://assets/ui/alpha/HVGA/excavate/excavate_cycle_diamond.png"
const CYCLE_TEX_GOLD: String = "res://assets/ui/alpha/HVGA/excavate/excavate_cycle_gold.png"
const CYCLE_TEX_POTION: String = "res://assets/ui/alpha/HVGA/excavate/excavate_cycle_potion.png"
const FONT_TITLE: int = 20
const FONT_BODY: int = 16
const FRAME_W: float = 600.0
const FRAME_H: float = 440.0
const NODE_W: float = 200.0
const NODE_H: float = 200.0
const OWNER_MINE_LABEL: String = "我方占领"
const OWNER_MONSTER_LABEL: String = "野外怪守（可攻击占领）"
const PRODUCE_LABEL_FMT: String = "产出：%s/%d"
const STORAGE_LABEL_FMT: String = "存储剩余：%d"
const NO_NODE_TEXT: String = "暂无矿点，点击「搜索」发现矿点"
const SEARCH_TEXT: String = "搜索"
const EXPLAIN_TEXT: String = "说明"
const HISTORY_TEXT: String = "战报"
const PREV_TEXT: String = "◀"
const NEXT_TEXT: String = "▶"
const NODE_BTN_MINE: String = "驻防/换队"
const NODE_BTN_MONSTER: String = "查看/出战"
const PAGE_FMT: String = "%d / %d"
const PRODUCE_NAME_DIAMOND: String = "钻石"
const PRODUCE_NAME_GOLD: String = "金币"
const PRODUCE_NAME_ITEM: String = "经验药水"
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


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = load(MAIN_BG_TEX)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = Vector2(960, 640)
	bg.position = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	var frame := TextureRect.new()
	frame.texture = load(FRAME_TEX)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	frame.size = Vector2(FRAME_W, FRAME_H)
	frame.position = Vector2(960.0 * 0.5 - FRAME_W * 0.5, 640.0 * 0.5 - FRAME_H * 0.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(frame)
	_add_close(frame)
	_add_title(frame)
	_add_node(frame)
	_add_info(frame)
	_add_nav(frame)
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
	title.position = Vector2(frame.size.x * 0.5 - ts.x * 0.5, 12)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title)


func _add_node(frame: TextureRect) -> void:
	_node_button = Button.new()
	_node_button.size = Vector2(NODE_W, NODE_H)
	_node_button.position = Vector2(frame.size.x * 0.5 - NODE_W * 0.5, 70)
	_node_button.pressed.connect(_on_node_clicked)
	frame.add_child(_node_button)


func _add_info(frame: TextureRect) -> void:
	_info_label = Label.new()
	_info_label.position = Vector2(40, 285)
	_info_label.size = Vector2(frame.size.x - 80, 80)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font", FONT_BODY)
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_info_label)


func _add_nav(frame: TextureRect) -> void:
	var prev := Button.new()
	prev.text = PREV_TEXT
	prev.size = Vector2(40, 40)
	prev.position = Vector2(20, 160)
	prev.pressed.connect(_on_prev)
	frame.add_child(prev)
	var next := Button.new()
	next.text = NEXT_TEXT
	next.size = Vector2(40, 40)
	next.position = Vector2(frame.size.x - 60, 160)
	next.pressed.connect(_on_next)
	frame.add_child(next)
	_page_label = Label.new()
	_page_label.position = Vector2(0, 220)
	_page_label.size = Vector2(frame.size.x, 24)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font", FONT_BODY)
	_page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_page_label)


func _add_bottom_buttons(frame: TextureRect) -> void:
	var search := Button.new()
	search.text = SEARCH_TEXT
	search.size = Vector2(100, 36)
	search.position = Vector2(40, frame.size.y - 45)
	search.pressed.connect(_on_search)
	frame.add_child(search)
	var explain := Button.new()
	explain.text = EXPLAIN_TEXT
	explain.size = Vector2(100, 36)
	explain.position = Vector2(frame.size.x - 140, frame.size.y - 45)
	explain.pressed.connect(_on_explain)
	frame.add_child(explain)
	var history := Button.new()
	history.text = HISTORY_TEXT
	history.size = Vector2(100, 36)
	history.position = Vector2(frame.size.x * 0.5 - 50, frame.size.y - 45)
	history.pressed.connect(_on_history)
	frame.add_child(history)


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


func _produce_name(type_id: int) -> String:
	match ExcavateData.produce_type(pd.cm, type_id):
		ExcavateData.PRODUCE_DIAMOND:
			return PRODUCE_NAME_DIAMOND
		ExcavateData.PRODUCE_GOLD:
			return PRODUCE_NAME_GOLD
		ExcavateData.PRODUCE_ITEM:
			return PRODUCE_NAME_ITEM
	return PRODUCE_NAME_GOLD


# 矿点旗帜 texture 按产出类型选 cycle 图（源 excavate_cycle_{diamond/gold/potion}.png；
# 旧 NODE_TEX excavate_flag_available.png 源本无 → 笔误引用 ResourceLoader 找不到 warning）。
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
