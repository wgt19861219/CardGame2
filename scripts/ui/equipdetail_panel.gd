class_name EquipdetailPanel
extends PopWindow

## 装备详情弹窗（View 层）— 照源 equipdetail.lua（435 行）。
## 功能：装备图标+拥有数量 + 3 段滚动（可合成装备/可装备英雄/获得途径）。
##
## 两件套范式（批 1 Task 7，2026-08-15）：静态框架与 3 段结构进
## equipdetail_content.tscn（无脚本），数据行走行模板 equipdetail_item_cell.tscn；
## 本文件只做业务、信号 connect、fill（零静态节点构造，icon 走工厂——
## ReadheroIcon.new() 是源 readhero.getIcon 的工厂构造，白名单唯一例外）。
## 静态色/字号走 theme variation（EquipDetail* 系列）；拥有数量绿/红是源
## 直设色语义 → fill font_color override（非乘法 modulate）。
## 坐标：源 cocos 800x480 左下原点 → Godot 800x480 左上（静态部分已在 tscn
## 换算）；3 段滚动照源垂直流式（gap=20 → VBox separation，行高 55 两列）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/equipdetail_content.tscn")
const ITEM_CELL_SCENE: PackedScene = preload("res://scenes/ui/equipdetail_item_cell.tscn")

# 源 icon 尺寸：装备段 readequip.createIcon(id, 40)（72 容器缩 40/72）、
# 英雄段 readhero.getIcon({id,rank,length=40})（104 容器缩 40/104）、
# 获取途径段 :259 setScale(60/w)（宽恒 60 等比）。
const SMALL_ICON_SIZE: float = 40.0
const EQUIP_ICON_BASE: float = 72.0
const HERO_ICON_BASE: float = 104.0
const GET_WAY_ICON_SIZE: float = 60.0
# 源 :171/213/264 name 内容宽 > 195 → 等比缩到 195
const NAME_MAX_WIDTH: float = 195.0

# LSTR key（源 LSTR 宏，cm.get_lstr 解析）
const LSTR_EQUIP_TITLE: String = "EQUIPDETAIL.EQUIPMENT_CAN_BE_SYNTHESIZED"
const LSTR_HERO_TITLE: String = "EQUIPDETAIL.HEROES_CAN_BE_EQUIPPED"
const LSTR_GET_TITLE: String = "EQUIPCRAFT.WAY_TO_GET"
const LSTR_ELITE: String = "EQUIPCRAFT.ELITE"

# 拥有数量直设色（源 :311-315 ccc3(0,200,0)/ccc3(255,0,0)）
const AMT_HAS_COLOR: Color = Color(0.0, 200.0 / 255.0, 0.0)
const AMT_NONE_COLOR: Color = Color(1.0, 0.0, 0.0)

var cm: Variant = null
var pd: PlayerData = null
var _equip_id: int = 0
var _content: Control = null
var _icon_host: Control = null
var _amount_label: Label = null
var _equip_section: Control = null
var _hero_section: Control = null
var _equip_grid: GridContainer = null
var _hero_grid: GridContainer = null
var _get_grid: GridContainer = null
var _how_label: Label = null
var _scroll_clip: ScrollContainer = null
var _drag_state: Dictionary = {}   # DragScrollHelper 跨帧基准（修复轮四）

# 拖拽滚动（修复轮四：Godot 4 ScrollContainer 桌面无拖拽，源 draglist 手势补齐；
# 格子无点击交互，仅拖动滚动）。
func _input(event: InputEvent) -> void:
	if _scroll_clip != null:
		DragScrollHelper.handle_input(_scroll_clip, event, _drag_state)


func setup_panel(equip_id: int, p_cm: Variant, p_pd: PlayerData) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	_equip_id = equip_id
	cm = p_cm
	pd = p_pd
	setup()
	_build_content()
	# 3 段行 fill 依赖文字实宽（name 超宽缩放），入树后 theme 上下文才准
	# （批 1 Task 2 沉淀），照源 create 时建 → 挂 on_enter 等价。
	register_on_enter(_fill_sections)
	# 源 EaseBackOut 0.2s：弹窗缩放入场（P2-10）。
	register_on_enter(play_scale_in)


# 绑定 .tscn 静态节点 + fill 标题文案/装备图标/拥有数量（不依赖文字实宽）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_scroll_clip = _content.get_node("%ScrollClip") as ScrollContainer
	_icon_host = _content.get_node("%IconHost") as Control
	_amount_label = _content.get_node("%AmountLabel") as Label
	_equip_section = _content.get_node("%EquipSection") as Control
	_hero_section = _content.get_node("%HeroSection") as Control
	_equip_grid = _content.get_node("%EquipGrid") as GridContainer
	_hero_grid = _content.get_node("%HeroGrid") as GridContainer
	_get_grid = _content.get_node("%GetGrid") as GridContainer
	_how_label = _content.get_node("%HowLabel") as Label
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close_pressed)
	(_content.get_node("%EquipTitleLabel") as Label).text = cm.get_lstr(LSTR_EQUIP_TITLE)
	(_content.get_node("%HeroTitleLabel") as Label).text = cm.get_lstr(LSTR_HERO_TITLE)
	(_content.get_node("%GetTitleLabel") as Label).text = cm.get_lstr(LSTR_GET_TITLE)
	_fill_icon()


# 装备图标 + 拥有数量（源 createIcon :298-318：readequip.createIcon(id) at
# (80,360) + "x"+amount 直设绿/红 + 黑影(0,1)——影走 variation）。
func _fill_icon() -> void:
	var icon: Control = ReadequipIcon.create_icon(_equip_id, 0, cm)
	var scale_factor: float = SMALL_ICON_SIZE / EQUIP_ICON_BASE
	icon.scale = Vector2(scale_factor, scale_factor)
	icon.custom_minimum_size = Vector2(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_host.add_child(icon)
	var amount: int = int(pd.items.get(_equip_id, 0))
	_amount_label.text = "x" + str(amount)
	_amount_label.add_theme_color_override("font_color", AMT_HAS_COLOR if amount > 0 else AMT_NONE_COLOR)


# 3 段 fill（源 createDetail :135-296）：段 1/2 条件显示（#equipList/#heroList>0），
# 段 3 恒显；行走行模板，How To Get 文本条件显示。
func _fill_sections() -> void:
	var data: Dictionary = EquipdetailQuery.query(_equip_id, cm, pd)
	var equip_list: Array = data["equip_list"]
	var hero_list: Array = data["hero_list"]
	_equip_section.visible = not equip_list.is_empty()
	_hero_section.visible = not hero_list.is_empty()
	for item in equip_list:
		_add_item_cell(_equip_grid, item as Dictionary, false)
	for item in hero_list:
		_add_item_cell(_hero_grid, item as Dictionary, true)
	_fill_get_way_cells(data["get_way"])
	var how: String = cm.get_lstr(String(data["how_to_get"]))
	_how_label.text = how
	_how_label.visible = how != ""


# 装备/英雄段行（源 :161-175 / :196-217）：行模板 instantiate + icon 工厂
# （装备 readequip.createIcon(id,40) / 英雄 readhero.getIcon({id,rank,length=40}，
# 旧版误用装备工厂，本批照源归位 rank 框）+ name fill + 超宽等比缩。
func _add_item_cell(grid: GridContainer, item: Dictionary, is_hero: bool) -> void:
	var cell: Control = ITEM_CELL_SCENE.instantiate() as Control
	grid.add_child(cell)
	var host: Control = cell.get_node("%IconHost") as Control
	var icon_scale: float = SMALL_ICON_SIZE / (HERO_ICON_BASE if is_hero else EQUIP_ICON_BASE)
	if is_hero:
		var hero_icon := ReadheroIcon.new()
		hero_icon.setup({"id": int(item["id"]), "rank": int(item.get("rank", 1))}, cm)
		hero_icon.scale = Vector2(icon_scale, icon_scale)
		hero_icon.position = Vector2(-SMALL_ICON_SIZE, -SMALL_ICON_SIZE) * 0.5
		host.add_child(hero_icon)
	else:
		var icon: Control = ReadequipIcon.create_icon(int(item["id"]), 0, cm)
		icon.scale = Vector2(icon_scale, icon_scale)
		icon.position = -Vector2(EQUIP_ICON_BASE, EQUIP_ICON_BASE) * icon_scale * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(icon)
	var name_lbl: Label = cell.get_node("%NameLabel") as Label
	name_lbl.text = cm.get_lstr(String(item["name"]))   # name 是 LSTR key（装备/英雄名）
	_shrink_name_if_wide(name_lbl)


# 获取途径行（源 :254-267）：行模板 + 关卡图标进 %WayIcon（宽恒 60 等比，
# 源 setScale(60/w)）+ name（elite 前缀 + 超宽缩放）。
func _fill_get_way_cells(get_way: Array) -> void:
	for way in get_way:
		var w: Dictionary = way as Dictionary
		var cell: Control = ITEM_CELL_SCENE.instantiate() as Control
		_get_grid.add_child(cell)
		var icon: TextureRect = cell.get_node("%WayIcon") as TextureRect
		var res_path: String = String(w.get("res", ""))
		if ResourceLoader.exists(res_path):
			icon.texture = load(res_path) as Texture2D
			var tex_w: float = icon.texture.get_size().x
			var disp: Vector2 = icon.texture.get_size() * (GET_WAY_ICON_SIZE / tex_w)
			icon.offset_left = -disp.x * 0.5
			icon.offset_right = disp.x * 0.5
			icon.offset_top = -disp.y * 0.5
			icon.offset_bottom = disp.y * 0.5
			icon.visible = true
		var name_lbl: Label = cell.get_node("%NameLabel") as Label
		var disp_name: String = cm.get_lstr(String(w["name"]))
		if bool(w.get("elite", false)):
			disp_name = cm.get_lstr(LSTR_ELITE) + " " + disp_name
		name_lbl.text = disp_name
		_shrink_name_if_wide(name_lbl)


# name 内容宽 > 195 → 等比缩到 195（源 :171-173/213-215/264-266）。
func _shrink_name_if_wide(name_lbl: Label) -> void:
	var name_w: float = name_lbl.get_combined_minimum_size().x
	if name_w > NAME_MAX_WIDTH:
		var sc: float = NAME_MAX_WIDTH / name_w
		name_lbl.scale = Vector2(sc, sc)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()
