class_name EquipdetailPanel
extends PopWindow

## 装备详情弹窗（View 层）— 照源 equipdetail.lua（435 行）翻译。
## frame equip_detail_bg + 装备图标+持有量 + close + ScrollContainer 3 段（可合成装备/可装备英雄/获取途径）。
## 接 EquipboardPanel.check（prop 右按钮「详情」，第 26 段接 use/check 按钮的 check）。
## 坐标 frame 内相对估算（源 layer 绝对坐标 ccp(440+offsetX,...) offsetX=-40；Phase 4 视觉校准）。

const FRAME_POS: Vector2 = Vector2(400.0, 240.0)    # 源 bg ccp(440-40, 240)，中心对称
const FRAME_SIZE: Vector2 = Vector2(640.0, 400.0)   # equip_detail_bg 估算（Phase 4 校准）
const ICON_POS: Vector2 = Vector2(20.0, 20.0)       # frame 内左侧（源 createIcon :303）
const AMOUNT_POS: Vector2 = Vector2(20.0, 100.0)    # 源 amountLabel :310
const SCROLL_POS: Vector2 = Vector2(150.0, 20.0)    # 源 draglist rect (170+offsetX,47,540,387)
const SCROLL_SIZE: Vector2 = Vector2(480.0, 360.0)
const CLOSE_POS: Vector2 = Vector2(590.0, 10.0)     # 源 close ccp(700,420) → frame 内
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"  # equipdetail.lua:366
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"  # equipdetail.lua:377
const SMALL_ICON_SIZE: float = 40.0                 # 源 createIcon(id, 40)
const CELL_MIN_SIZE: Vector2 = Vector2(230.0, 50.0)
const TITLE_COLOR: Color = Color(250.0 / 255.0, 205.0 / 255.0, 16.0 / 255.0)   # 源 ccc3(250,205,16)
const TEXT_COLOR: Color = Color(60.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0)      # 源 ccc3(60,60,60)
const AMT_HAS_COLOR: Color = Color(0.0, 200.0 / 255.0, 0.0)                    # 源 :312 ccc3(0,200,0)
const AMT_NONE_COLOR: Color = Color(1.0, 0.0, 0.0)                             # 源 :314 ccc3(255,0,0)

const FRAME_PATH: String = "res://assets/ui/alpha/HVGA/equip_detail_bg.png"
const TITLE_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_detail_title_bg.png"
# P1-12：照源 equip_detail_panel_bg Scale9（资源存在，替原 Panel 降级）
const PANEL_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_detail_panel_bg.png"
const PANEL_PATCH_LEFT: int = 10    # 源 :152 CCRectMake(10,30,400,65) 左边距
const PANEL_PATCH_TOP: int = 30     # 源 上边距
const GET_WAY_ICON_SIZE: float = 60.0   # 源 createDetail :259 setScale(60/width)
const HOW_COLOR: Color = Color(238.0 / 255.0, 204.0 / 255.0, 119.0 / 255.0)   # 源 :280 ccc3(238,204,119)

# 源 LSTR key（equipdetail.lua:146/182/223）— 运行时 cm.get_lstr 解析。
const LSTR_EQUIP_TITLE: String = "EQUIPDETAIL.EQUIPMENT_CAN_BE_SYNTHESIZED"
const LSTR_HERO_TITLE: String = "EQUIPDETAIL.HEROES_CAN_BE_EQUIPPED"
const LSTR_GET_TITLE: String = "EQUIPCRAFT.WAY_TO_GET"

var cm: Variant = null
var pd: PlayerData = null
var _equip_id: int = 0


# 源 create(id) :337-394。equip_id = 装备 id。
func setup_panel(equip_id: int, p_cm: Variant, p_pd: PlayerData) -> void:
	_equip_id = equip_id
	cm = p_cm
	pd = p_pd
	setup()
	_build_ui()
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


func _build_ui() -> void:
	var frame := Control.new()
	# 源 bg ccp(400,240) 是 800×480 屏幕中心（cocos），须 to_godot 转 960×640 屏幕中心。
	frame.position = BattleViewCoords.to_godot(FRAME_POS.x, FRAME_POS.y) - FRAME_SIZE / 2.0
	frame.size = FRAME_SIZE
	container.add_child(frame)
	_add_bg(frame)
	_add_icon(frame)
	_add_close(frame)
	_add_sections(frame)


func _add_bg(parent: Control) -> void:
	if not ResourceLoader.exists(FRAME_PATH):
		return
	var bg := TextureRect.new()
	bg.texture = load(FRAME_PATH)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.custom_minimum_size = Vector2.ZERO
	bg.size = FRAME_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


# 源 createIcon :298-318：装备图标 + 持有数量（绿>0 / 红=0）。
func _add_icon(parent: Control) -> void:
	var icon: Control = ReadequipIcon.create_icon(_equip_id, 0, cm)
	var scale_factor: float = SMALL_ICON_SIZE / ReadequipIcon.ICON_SIZE
	icon.scale = Vector2(scale_factor, scale_factor)
	icon.custom_minimum_size = Vector2(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
	icon.position = ICON_POS
	parent.add_child(icon)
	var amount: int = int(pd.items.get(_equip_id, 0))
	var amt_lbl := Label.new()
	amt_lbl.text = "x" + str(amount)
	amt_lbl.position = AMOUNT_POS
	amt_lbl.modulate = AMT_HAS_COLOR if amount > 0 else AMT_NONE_COLOR
	parent.add_child(amt_lbl)


func _add_close(parent: Control) -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_POS)
	btn.pressed.connect(_on_close_pressed)
	parent.add_child(btn)


# 源 createList + createDetail :321-296：draglist 滚动 3 段。本项目 ScrollContainer+VBoxContainer 等价。
func _add_sections(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = SCROLL_POS
	scroll.size = SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2(SCROLL_SIZE.x, 0.0)
	scroll.add_child(vbox)
	var data: Dictionary = EquipdetailQuery.query(_equip_id, cm, pd)
	if (data["equip_list"] as Array).size() > 0:
		_add_item_section(vbox, cm.get_lstr(LSTR_EQUIP_TITLE), data["equip_list"], false)
	if (data["hero_list"] as Array).size() > 0:
		_add_item_section(vbox, cm.get_lstr(LSTR_HERO_TITLE), data["hero_list"], true)
	_add_get_way_section(vbox, data)


# 源 createDetail 段（装备 :142-177 / 英雄 :178-219）：title_bg + 标题 + panel_bg + 图标网格（2 列）。
# P1-12：照源 :152 equip_detail_panel_bg Scale9 贴图（原降级 Panel → NinePatchRect）
func _add_item_section(parent: VBoxContainer, title: String, items: Array, is_hero: bool) -> void:
	parent.add_child(_make_title(title))
	var panel: NinePatchRect = _make_panel_bg()
	parent.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2   # 源 (i-1)%2 两列
	panel.add_child(grid)
	for item in items:
		grid.add_child(_make_item_cell(item as Dictionary, is_hero))


# 源 createDetail 获取途径段 :220-294：title + getDetailBg panel_bg + Drop 1-3 关卡图标 + How To Get。
# P1-12：照源 :228 getDetailBg panel_bg 包裹 + :256 createSprite(way.res) 关卡图标（替纯 Label）
func _add_get_way_section(parent: VBoxContainer, data: Dictionary) -> void:
	parent.add_child(_make_title(cm.get_lstr(LSTR_GET_TITLE)))
	var panel: NinePatchRect = _make_panel_bg()   # 源 :228 getDetailBg
	parent.add_child(panel)
	var get_way: Array = data["get_way"]
	var grid := GridContainer.new()
	grid.columns = 2
	panel.add_child(grid)
	for way in get_way:
		grid.add_child(_make_get_way_cell(way as Dictionary))
	var how: String = cm.get_lstr(String(data["how_to_get"]))   # 源 :270 row["How To Get"]（LSTR key）
	if how != "":
		var how_lbl := Label.new()
		how_lbl.text = how
		how_lbl.modulate = HOW_COLOR   # 源 :280 ccc3(238,204,119)
		how_lbl.custom_minimum_size = Vector2(SCROLL_SIZE.x - 20.0, 0.0)
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
	p.custom_minimum_size = Vector2(SCROLL_SIZE.x, 0.0)
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
	# 源 :240/243 Stage Name（LSTR key 或直接文本，get_lstr 统一解析）+ 精英前缀 T(LSTR("EQUIPCRAFT.ELITE")).." "
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
		bg.custom_minimum_size = Vector2.ZERO
		bg.custom_minimum_size = Vector2(SCROLL_SIZE.x, 30.0)
		box.add_child(bg)
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = TITLE_COLOR
	box.add_child(lbl)
	return box


# 源 createDetail item 行：createIcon(id, 40) + name 标签（scale 适配宽度 195）。
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
