class_name HandbookPanel
extends PopWindow

## 图鉴面板(View 层)— 照源 ui/handbook.lua(719 行)重建装备图鉴。
## 源核心:12 属性 tag(ALL/STR/AGI/INT/HP/AD/AP/ARM/CRIT/HPS/MPS/HEAL)分类装备 +
## 左右双列网格 12 格/页 + 装备图标(已解锁/锁定态)+ 翻页箭头 + book 背景三层。
## 数据源 EquipmentClassifier.classify_equip(照源 readequip.classifyEquip :481-537)。
## 重构(2026-07-17):静态节点(背景三层/12 tag 按钮+label/箭头/back/pageLabel)进 handbook_content.tscn
## (preload instantiate + get_node("%..")),panel 只管状态 + 切 tag + 翻页 + 装备网格动态挂。
## 源 tag 用触摸区 + 单精灵切换,Godot 适配为 12 TextureButton(引擎适配)。
## 坐标转换在 HandbookBuilder.to_godot(cocos 800×480 → Godot 960×640)。
## 残留:点装备图标弹 EquipDetailPanel(源 doEquipTouch :111-142)待接,本轮占位信号。

# base + 静态元素子场景(位置/size 在 .tscn 可视化,编辑器拖 offset 调)。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/handbook_content.tscn")
# tag 按钮 index(1-12) → list key。1=ALL(源 tagTextIndex :26-39)。
const TAG_KEYS: Array[String] = ["ALL", "STR", "AGI", "INT", "HP", "AD", "AP", "ARM", "CRIT", "HPS", "MPS", "HEAL"]
const PER_PAGE: int = 12   # 源 createList :455 ceil(eAmount/12)

var _player: PlayerData
var _cm: Variant = null
var _tabs_data: Dictionary = {}      # classify_equip 结果 {key: [{id,name,lr}]}
var _tag_ui: Dictionary = {}         # {index(1-12): {button, label}}
var _current_tag: int = 1            # 默认 ALL(源 create :714 createPage("ALL",1))
var _page: int = 1
var _page_amount: int = 1
var _grid_layer: Control = null      # .tscn %EquipGridHost(装备网格容器,翻页/tag 切换时清子节点重建)
var _page_label: Label = null


func setup_panel(p_player: PlayerData) -> void:
	_player = p_player
	_cm = p_player.cm
	setup()
	# handbook 照源是全屏场景(源 handbook.lua:618 base=basescene 手动加 bg.jpg,.tscn FrameworkBg 已固化),
	# shade 透明不遮背景(同 HeroPackagePanel)。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabs_data = EquipmentClassifier.classify_equip(_cm, _player.MAX_TEAM_LEVEL)
	_build_content()


# 建 UI 内容。静态元素(背景三层/12 tag/箭头/back/pageLabel)从 .tscn instantiate + fill 动态数据/信号;
# 装备网格动态挂 %EquipGridHost(翻页/tag 切换时清子节点重建)。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%BackBtn") as TextureButton).pressed.connect(remove_window)
	_tag_ui = HandbookBuilder.collect_tags(content)
	HandbookBuilder.fill_tag_labels(_tag_ui, _cm)
	(content.get_node("%ArrowLeftBtn") as TextureButton).pressed.connect(_on_prev_page)
	(content.get_node("%ArrowRightBtn") as TextureButton).pressed.connect(_on_next_page)
	_page_label = content.get_node("%PageLabel") as Label
	_grid_layer = content.get_node("%EquipGridHost") as Control
	for i in range(1, 13):
		(_tag_ui[i]["button"] as TextureButton).pressed.connect(_switch_tag.bind(i))
	_update_tag_visual()
	_refresh_grid()


# 源 doSelectTag :78-104:切 tag → 选中态切换 + 回第 1 页 + 重建网格。
func _switch_tag(index: int) -> void:
	if index == _current_tag:
		return
	AudioPlayer.play_sfx("common_click_feedback")
	_current_tag = index
	_page = 1
	_update_tag_visual()
	_refresh_grid()


# 源 doSelectTag :90-100:选中 tag 切 select 纹理 + label 白色;未选中 normal 纹理 + 灰色。
func _update_tag_visual() -> void:
	for i in range(1, 13):
		var btn: TextureButton = _tag_ui[i]["button"]
		var lbl: Label = _tag_ui[i]["label"]
		var is_right: bool = i > 6
		var selected: bool = i == _current_tag
		var sel: String = HandbookBuilder.TAG_RIGHT_SEL if is_right else HandbookBuilder.TAG_LEFT_SEL
		var norm: String = HandbookBuilder.TAG_RIGHT if is_right else HandbookBuilder.TAG_LEFT
		btn.texture_normal = load(sel if selected else norm) as Texture2D
		btn.z_index = 9 if selected else 4   # 源 :393 选中 z=9
		lbl.add_theme_color_override("font_color", HandbookBuilder.TAG_SELECT_COLOR if selected else HandbookBuilder.TAG_NORMAL_COLOR)
		lbl.z_index = 9 if selected else 4


# 源 setPage :538-553 + createPage :555-598。翻页/切 tag 时清 _grid_layer 子节点重建 + 更新页码。
# _grid_layer 是 .tscn %EquipGridHost(常驻),仅 free 其子节点(装备 cell),不 free _grid_layer 自己。
func _refresh_grid() -> void:
	for c in _grid_layer.get_children():
		c.queue_free()
	var list: Array = _tabs_data.get(TAG_KEYS[_current_tag - 1], [])
	_page_amount = maxi(ceili(float(list.size()) / float(PER_PAGE)), 1)
	var start: int = PER_PAGE * (_page - 1)
	var end: int = min(start + PER_PAGE, list.size())
	for i in range(start, end):
		var info: Dictionary = list[i]
		var slot: int = i - start + 1   # 源 :460 getIconPosition(i - 12*(page-1))
		var cell: Control = HandbookBuilder.create_equip_cell(info, _player.team_level, _cm)
		cell.position = HandbookBuilder.icon_position(slot) - cell.custom_minimum_size * 0.5   # anchor(0.5,0.5) 近似
		cell.gui_input.connect(_on_equip_input.bind(int(info["id"]), bool(cell.get_meta(&"is_open", false))))
		_grid_layer.add_child(cell)
	_page_label.text = "· %d / %d ·" % [_page, _page_amount]   # 源 :547


func _on_prev_page() -> void:
	if _page <= 1:
		return
	AudioPlayer.play_sfx("common_click_feedback")
	_page -= 1
	_refresh_grid()


func _on_next_page() -> void:
	if _page >= _page_amount:
		return
	AudioPlayer.play_sfx("common_click_feedback")
	_page += 1
	_refresh_grid()


# 源 doEquipTouch :111-142:点已解锁装备弹详情(EquipDetailPanel),锁定不响应。本轮占位 Toast。
func _on_equip_input(event: InputEvent, _eid: int, is_open: bool) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	if not is_open:
		return
	AudioPlayer.play_sfx("common_click_feedback")
	# 残留:照源 doEquipTouch :111-142 接 EquipDetailPanel(装备详情弹窗),当前轮占位不弹。
