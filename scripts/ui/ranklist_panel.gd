class_name RanklistPanel
extends PopWindow

## 排行榜面板（View 层）— 照源 ranklist.lua ranklisttree + initXxxItemHandler + uieditor/ranklistwindow.lua。
## 窗口框架（ranklist_bg 主框 + backbtn close 左上）+ 分组折叠树 tab（ranklist_button 分组标题 + ranklist_subbutton 子项，
## 单机化裁 pvp_r 实时联机 + guildliveness 公会未接 → 2 分组 4 子项）+ Scale9 列表行 + scrollView。
## 数据层 RanklistManager.generate_ranklist（4 档假榜已就绪）。
## 残留：头像是等级图标（getTeamHead/getLevelIcon，NPC avatar 数据缺）+ 1st/2nd/3rd 排名图标（资源缺）+ 5 summary 弹窗 + 折叠展开/收起动画 → 下轮。
## 坐标源 cocos 800×480 → 目标 _to_godot(cx+80,560-cy)。

const RANKLIST_BG_TEX: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_bg.png"
const RANKLIST_BG_SIZE: Vector2 = Vector2(722.0, 400.0)  # 源 window :79 scaleSize
const RANKLIST_BG_POS: Vector2 = Vector2(119.0, 144.0)  # 源 ccp(400,216) → 中心(480,344) → 左上
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
const CLOSE_POS: Vector2 = Vector2(114.0, 92.0)  # 源 back_button ccp(63,439) → 中心(143,121) → 左上
const TITLE_POS: Vector2 = Vector2(420.0, 100.0)  # 主框上方居中
const TAB_X: float = 125.0
const TAB_Y: float = 155.0
const TAB_W: float = 130.0
const TAB_H: float = 32.0
const GROUPBTN_NORMAL: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_button_normal_1.png"
const GROUPBTN_CURRENT: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_button_current_1.png"
const SUBBTN_NORMAL: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_subbutton_normal_1.png"
const SUBBTN_CURRENT: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_subbutton_current_1.png"
const ME_BG_RES: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_me_bg.png"  # 源 :583/:938 自己行 board
const OTHER_BG_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_high.png"  # 源 :583/:938 他人行 board
const SCROLL_POS: Vector2 = Vector2(290.0, 155.0)
const SCROLL_SIZE: Vector2 = Vector2(420.0, 360.0)
const ROW_W: float = 400.0  # 源 board scaleSize 650×95 → 目标行宽（Scale9 视觉近似）
const ROW_H: float = 56.0
const SELF_COLOR: Color = Color(1.0, 1.0, 0.0)
# 单机化裁剪：源 ranklisttree 3 分组（ARENA/FIGHTVALUE/GUILD），裁 pvp_r 实时联机 + guildliveness 公会未接 → 2 分组 4 子项。
const TAB_GROUPS: Array = [
	{"title": "竞技", "modes": ["pvp"], "labels": ["竞技场"]},
	{"title": "战力", "modes": ["full_hero_gs", "hero_team_gs", "hero_evo_star"], "labels": ["全员战力", "小队战力", "英雄星级"]},
]

var _rm: RanklistManager
var _player: PlayerData
var _rank_type: String
var _tab_layer: Control
var _list_layer: ScrollContainer
var _collapsed: Dictionary  # 源 ranklisttree collapsed：分组展开/收起状态（true=折叠）


func setup_panel(p_player: PlayerData, p_rm: RanklistManager, rank_type: String) -> void:
	_player = p_player
	_rm = p_rm
	_rank_type = rank_type
	setup()
	_build_ui()


func _build_ui() -> void:
	# 源 ranklisttree collapsed：[1]ARENA collapsed=false 展开 / [2]FIGHTVALUE collapsed=true 折叠。
	_collapsed = {"竞技": false, "战力": true}
	var bg := TextureRect.new()
	bg.texture = load(RANKLIST_BG_TEX)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # [[texture-rect-expand-ignore-size]]
	bg.size = RANKLIST_BG_SIZE
	bg.position = RANKLIST_BG_POS
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	var close: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_POS)
	close.pressed.connect(remove_window)
	container.add_child(close)
	var title := Label.new()
	title.text = "排行榜"
	title.position = TITLE_POS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(title)
	_tab_layer = Control.new()
	_tab_layer.position = Vector2(TAB_X, TAB_Y)
	container.add_child(_tab_layer)
	_build_tabs()
	_list_layer = ScrollContainer.new()
	_list_layer.position = SCROLL_POS
	_list_layer.size = SCROLL_SIZE
	_list_layer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(_list_layer)
	_refresh_list()


# 源 ranklisttree 折叠树：分组标题（ranklist_button）点击切 collapsed + 子项（ranklist_subbutton）按 collapsed 显示/隐藏。
func _build_tabs() -> void:
	for c in _tab_layer.get_children():
		c.queue_free()
	var y: float = 0.0
	for group in TAB_GROUPS:
		var gtitle: String = String(group["title"])
		var collapsed: bool = bool(_collapsed.get(gtitle, true))
		var gbtn: TextureButton = _make_grouptab(gtitle, Vector2(0.0, y), not collapsed)
		gbtn.pressed.connect(_on_group_pressed.bind(gtitle))
		_tab_layer.add_child(gbtn)
		y += TAB_H
		if not collapsed:
			var modes: Array = group["modes"]
			var labels: Array = group["labels"]
			for i in modes.size():
				var mode: String = modes[i]
				var tab: TextureButton = _make_subtab(String(labels[i]), Vector2(0.0, y), mode == _rank_type)
				tab.pressed.connect(_on_tab_pressed.bind(mode))
				_tab_layer.add_child(tab)
				y += TAB_H
		y += 8.0


func _make_grouptab(text: String, pos: Vector2, is_expanded: bool) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(GROUPBTN_CURRENT if is_expanded else GROUPBTN_NORMAL)
	btn.texture_pressed = load(GROUPBTN_CURRENT)
	btn.ignore_texture_size = true
	btn.size = Vector2(TAB_W, TAB_H)
	btn.position = pos
	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	return btn


func _make_subtab(text: String, pos: Vector2, is_current: bool) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(SUBBTN_CURRENT if is_current else SUBBTN_NORMAL)
	btn.texture_pressed = load(SUBBTN_CURRENT)
	btn.ignore_texture_size = true
	btn.size = Vector2(TAB_W, TAB_H)
	btn.position = pos
	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	return btn


func _on_group_pressed(title: String) -> void:
	_collapsed[title] = not bool(_collapsed.get(title, true))
	_build_tabs()


func _on_tab_pressed(mode: String) -> void:
	_rank_type = mode
	_build_tabs()
	_refresh_list()


# 行点击弹 RanklistSummary（照源 initpvpItemHandler:656 点击 NPC 弹 userpvpsummary）。
func _on_row_input(event: InputEvent, rank: int, row_name: String, level: int, param: int, avatar: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var summary := RanklistSummary.new()
		summary.setup_panel(row_name, level, param, avatar, rank, _player.cm)
		summary.show_window(get_parent())


func _refresh_list() -> void:
	for c in _list_layer.get_children():
		c.queue_free()
	var r: Dictionary = _rm.generate_ranklist(_player, _rank_type)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.custom_minimum_size = Vector2(ROW_W, 0.0)
	_list_layer.add_child(vbox)
	vbox.add_child(_make_row(0, _player.player_name, _player.team_level, int(r["self_param"]), int(r.get("self_avatar", 0)), true))
	for i in r["items"].size():
		var item: Dictionary = r["items"][i]
		vbox.add_child(_make_row(i + 1, String(item["name"]), int(item["level"]), int(item["param"]), int(item.get("avatar", 0))))


# 源 initpvpItemHandler/initCommonItemHandler Scale9 行（board 650×95 + 排名/头像/等级/名）。
# 目标简化：board TextureRect（ranklist_me_bg 自己/pvp_rank_bg_high 他人）+ 排名数字（1st/2nd/3rd 图标缺降级）+ name + param。
# 残留：头像/等级图标（NPC avatar 数据缺 + getTeamHead/getLevelIcon）+ 点击弹 summary → 下轮。
func _make_row(rank: int, row_name: String, level: int, param: int, avatar: int, is_self: bool = false) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(ROW_W, ROW_H)
	row.gui_input.connect(_on_row_input.bind(rank, row_name, level, param, avatar))
	var board := TextureRect.new()
	board.texture = load(ME_BG_RES if is_self else OTHER_BG_RES)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.size = Vector2(ROW_W, ROW_H)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(board)
	# 头像（源 initpvpItemHandler:606 getTeamHead，目标查 Avatar.json[avatar].Picture → res://assets/ui/HERO/X.jpg）。
	if _player != null and _player.cm != null:
		var pic: String = String(_player.cm.get_raw_table(&"Avatar").get(str(avatar), {}).get("Picture", ""))
		if not pic.is_empty():
			var head := TextureRect.new()
			var head_path: String = "res://assets/ui/" + pic.substr(3)   # UI/HERO/X.jpg → assets/ui/HERO/X.jpg
			if ResourceLoader.exists(head_path):
				head.texture = load(head_path)
				head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				head.size = Vector2(40.0, 40.0)
				head.position = Vector2(60.0, 8.0)
				head.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(head)
	var rank_lbl := Label.new()
	rank_lbl.text = "★" if rank == 0 else "#%d" % rank
	rank_lbl.position = Vector2(15.0, 16.0)
	rank_lbl.size = Vector2(60.0, 24.0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_lbl.add_theme_color_override("font_color", SELF_COLOR if is_self else Color.WHITE)
	row.add_child(rank_lbl)
	var name_lbl := Label.new()
	name_lbl.text = "%s Lv%d" % [row_name, level]
	name_lbl.position = Vector2(85.0, 16.0)
	name_lbl.size = Vector2(220.0, 24.0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_self:
		name_lbl.add_theme_color_override("font_color", SELF_COLOR)
	row.add_child(name_lbl)
	var param_lbl := Label.new()
	param_lbl.text = "%d" % param
	param_lbl.position = Vector2(320.0, 16.0)
	param_lbl.size = Vector2(70.0, 24.0)
	param_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	param_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(param_lbl)
	return row
