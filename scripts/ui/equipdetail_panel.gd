class_name EquipdetailPanel
extends PopWindow

## 装备详情弹窗（View 层）— 照源 equipdetail.lua（435 行）翻译。
## Phase 5 tscn 重构（2026-07-17）：frame/bg/close/icon/scroll 静态化进 equipdetail_content.tscn
## （instantiate + fill），位置/size 编辑器可视化调。3 段（合成/英雄/获取途径）procedural 挂 VBox。
## 接 EquipboardPanel.check（prop 右按钮「详情」，第 26 段接 use/check 按钮的 check）。
## 坐标源 800×480 左下→960×640 左上 to_godot(cx,cy)=Vector2(cx+80,560-cy)，CS=1.28125。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/equipdetail_content.tscn")

const SMALL_ICON_SIZE: float = 40.0
const CELL_MIN_SIZE: Vector2 = Vector2(230.0, 50.0)
const TITLE_COLOR: Color = Color(250.0 / 255.0, 205.0 / 255.0, 16.0 / 255.0)
const TEXT_COLOR: Color = Color(60.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0)
const AMT_HAS_COLOR: Color = Color(0.0, 200.0 / 255.0, 0.0)
const AMT_NONE_COLOR: Color = Color(1.0, 0.0, 0.0)

const TITLE_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_detail_title_bg.png"
# P1-12：照源 equip_detail_panel_bg Scale9（资源存在，替原 Panel 降级）
const PANEL_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_detail_panel_bg.png"
const PANEL_PATCH_LEFT: int = 10
const PANEL_PATCH_TOP: int = 30
const GET_WAY_ICON_SIZE: float = 60.0
const HOW_COLOR: Color = Color(238.0 / 255.0, 204.0 / 255.0, 119.0 / 255.0)
const SCROLL_WIDTH: float = 540.0

const LSTR_EQUIP_TITLE: String = "EQUIPDETAIL.EQUIPMENT_CAN_BE_SYNTHESIZED"
const LSTR_HERO_TITLE: String = "EQUIPDETAIL.HEROES_CAN_BE_EQUIPPED"
const LSTR_GET_TITLE: String = "EQUIPCRAFT.WAY_TO_GET"

var cm: Variant = null
var pd: PlayerData = null
var _equip_id: int = 0
var _icon_host: Control = null
var _amount_label: Label = null
var _scroll_vbox: VBoxContainer = null


func setup_panel(equip_id: int, p_cm: Variant, p_pd: PlayerData) -> void:
	_equip_id = equip_id
	cm = p_cm
	pd = p_pd
	setup()
	_build_content()
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


# 建 UI 内容：从 equipdetail_content.tscn instantiate，fill 动态装备数据 + 连信号 + 滚动 3 段。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_icon_host = content.get_node("%IconHost") as Control
	_amount_label = content.get_node("%AmountLabel") as Label
	_scroll_vbox = content.get_node("%ScrollVBox") as VBoxContainer
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close_pressed)
	_fill_icon()
	_fill_sections()


func _fill_icon() -> void:
	var icon: Control = ReadequipIcon.create_icon(_equip_id, 0, cm)
	var scale_factor: float = SMALL_ICON_SIZE / ReadequipIcon.ICON_SIZE
	icon.scale = Vector2(scale_factor, scale_factor)
	icon.custom_minimum_size = Vector2(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
	_icon_host.add_child(icon)
	var amount: int = int(pd.items.get(_equip_id, 0))
	_amount_label.text = "x" + str(amount)
	_amount_label.modulate = AMT_HAS_COLOR if amount > 0 else AMT_NONE_COLOR


func _fill_sections() -> void:
	var data: Dictionary = EquipdetailQuery.query(_equip_id, cm, pd)
	if (data["equip_list"] as Array).size() > 0:
		_add_item_section(_scroll_vbox, cm.get_lstr(LSTR_EQUIP_TITLE), data["equip_list"], false)
	if (data["hero_list"] as Array).size() > 0:
		_add_item_section(_scroll_vbox, cm.get_lstr(LSTR_HERO_TITLE), data["hero_list"], true)
	_add_get_way_section(_scroll_vbox, data)


# P1-12：照源 :152 equip_detail_panel_bg Scale9 贴图（原降级 Panel → NinePatchRect）
func _add_item_section(parent: VBoxContainer, title: String, items: Array, is_hero: bool) -> void:
	parent.add_child(_make_title(title))
	var panel: NinePatchRect = _make_panel_bg()
	parent.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	panel.add_child(grid)
	for item in items:
		grid.add_child(_make_item_cell(item as Dictionary, is_hero))


# P1-12：照源 :228 getDetailBg panel_bg 包裹 + :256 createSprite(way.res) 关卡图标（替纯 Label）
func _add_get_way_section(parent: VBoxContainer, data: Dictionary) -> void:
	parent.add_child(_make_title(cm.get_lstr(LSTR_GET_TITLE)))
	var panel: NinePatchRect = _make_panel_bg()
	parent.add_child(panel)
	var get_way: Array = data["get_way"]
	var grid := GridContainer.new()
	grid.columns = 2
	panel.add_child(grid)
	for way in get_way:
		grid.add_child(_make_get_way_cell(way as Dictionary))
	var how: String = cm.get_lstr(String(data["how_to_get"]))
	if how != "":
		var how_lbl := Label.new()
		how_lbl.text = how
		how_lbl.modulate = HOW_COLOR
		how_lbl.custom_minimum_size = Vector2(SCROLL_WIDTH - 20.0, 0.0)
		how_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(how_lbl)


# P1-12：源 :152/188/228 equip_detail_panel_bg Scale9（CCRectMake(10,30,400,65)）。
func _make_panel_bg() -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = load(PANEL_BG_PATH)
	p.patch_margin_left = PANEL_PATCH_LEFT
	p.patch_margin_top = PANEL_PATCH_TOP
	p.patch_margin_right = PANEL_PATCH_LEFT
	p.patch_margin_bottom = PANEL_PATCH_TOP
	p.custom_minimum_size = Vector2(SCROLL_WIDTH, 0.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# P1-12：源 :254-267 获取途径项：createSprite(way.res) 关卡图标（60px）+ name。
func _make_get_way_cell(way: Dictionary) -> Control:
	var cell := HBoxContainer.new()
	cell.custom_minimum_size = CELL_MIN_SIZE
	var res_path: String = String(way.get("res", ""))
	if ResourceLoader.exists(res_path):
		var icon := TextureRect.new()
		icon.texture = load(res_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(GET_WAY_ICON_SIZE, GET_WAY_ICON_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
	var name_lbl := Label.new()
	var disp_name: String = cm.get_lstr(String(way["name"]))
	if bool(way.get("elite", false)):
		disp_name = cm.get_lstr("EQUIPCRAFT.ELITE") + " " + disp_name
	name_lbl.text = disp_name
	name_lbl.modulate = TEXT_COLOR
	name_lbl.custom_minimum_size = Vector2(CELL_MIN_SIZE.x - GET_WAY_ICON_SIZE, 0.0)
	cell.add_child(name_lbl)
	return cell


func _make_title(text: String) -> Control:
	var box := HBoxContainer.new()
	if ResourceLoader.exists(TITLE_BG_PATH):
		var bg := TextureRect.new()
		bg.texture = load(TITLE_BG_PATH)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.custom_minimum_size = Vector2(SCROLL_WIDTH, 30.0)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bg)
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = TITLE_COLOR
	box.add_child(lbl)
	return box


func _make_item_cell(item: Dictionary, is_hero: bool) -> Control:
	var cell := HBoxContainer.new()
	cell.custom_minimum_size = CELL_MIN_SIZE
	var icon: Control = ReadequipIcon.create_icon(int(item["id"]), 0, cm)
	var scale_factor: float = SMALL_ICON_SIZE / ReadequipIcon.ICON_SIZE
	icon.scale = Vector2(scale_factor, scale_factor)
	icon.custom_minimum_size = Vector2(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
	cell.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = cm.get_lstr(String(item["name"]))   # item.name 是 LSTR key（装备/英雄/关卡名），View 显示时解析（照源 createDetail 标签）
	name_lbl.modulate = TEXT_COLOR
	name_lbl.custom_minimum_size = Vector2(CELL_MIN_SIZE.x - SMALL_ICON_SIZE, 0.0)
	cell.add_child(name_lbl)
	return cell


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()
