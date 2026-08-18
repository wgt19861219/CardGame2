class_name RanklistPanel
extends PopWindow

## 排行榜面板（View 层）— 照源 ranklist.lua + uieditor/ranklistwindow.lua（批4 Task 8 两件套改造）。
## 窗口框架/tab 按钮/列表容器静态化进 ranklist_content.tscn（编辑器所见即所得）；
## 本文件只做业务、信号 connect、fill（% 取节点填动态数据）+ 行渲染（动态行 procedural）。
## 单机化裁剪：源 3 分组裁 pvp_r 实时联机 + guildliveness 公会 → 2 分组 4 子项（勿回加）。
## 残留披露（维持不修，下轮补图）：1st/2nd/3rd 行内排名徽章缺图——本项目资产区无裸版
## pvp_rank_1st/2nd/3rd.png（仅 _star/_light 变体；源 :596-800/:1350-1356 行内+overlay 均用裸版；
## HC multilanguage 四语言区有裸版三图可补，2026-08-18 审查更正"HC 亦无"系查证错误）
## → Label "#N" 降级；getTeamHead 头像组件（图+金框+mask）→ Avatar.Picture 直显 40x40；
## getLevelIcon 等级徽章缺 → 名字合并 "LvN" 文本；self 行（rank0 "★" 顶部恒叠）与
## overlay 仅 rank>2 叠为迁移期行为（源 :1330 判 tab index 非排名，pvp 榜不显自己），行为债滚清单。
## 数据层 RanklistManager.generate_ranklist（4 档假榜已就绪）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/ranklist_content.tscn")
# tab 贴图（源 createRankBtn :2020-2041 resTbl；nromal 拼写照源资产名保留）。
const GROUP_SEL_NORMAL: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_button_current_1.png"
const GROUP_SEL_PRESS: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_button_current_2.png"
const GROUP_UNSEL_NORMAL: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_button_normal_1.png"
const GROUP_UNSEL_PRESS: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_button_nromal_2.png"
const SUB_SEL_NORMAL: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_subbutton_current_1.png"
const SUB_SEL_PRESS: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_subbutton_current_2.png"
const SUB_UNSEL_NORMAL: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_subbutton_normal_1.png"
const SUB_UNSEL_PRESS: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_subbutton_normal_2.png"
# 行板（源 initCommonItemHandler :780-793：自己 ranklist_me_bg / 他人 pvp_rank_bg_high）。
const ROW_BOARD_SELF: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_me_bg.png"
const ROW_BOARD_OTHER: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_high.png"
# 行板九宫格（源 capInsets DGRectMake(65,25,545,25) × 贴图 638x97px：
# left=65 / top=97-25-25=47 / right=638-65-545=28 / bottom=25）。
const BOARD_PATCH_L: int = 65
const BOARD_PATCH_T: int = 47
const BOARD_PATCH_R: int = 28
const BOARD_PATCH_B: int = 25
# 源 scaleSize DGSizeMake(650,95) = (507.81,74.22) 点。
const BOARD_SIZE: Vector2 = Vector2(507.81, 74.22)
# 行内布局（源 board 局部 DGccp ×0.78125 + y-up→y-down 翻转，board 高 74.22）：
# ranking 中心 DGccp(60,50)=(46.88,39.06) → Godot (46.88,35.16)；head DGccp(175,50) → (136.72,35.16)；
# pvp 布局 nameBg/name DGccp(250/280,52)（initpvpItemHandler :612-638）；
# common 布局 DGccp(250/280,67)（initCommonItemHandler :812-838）+ record DGccp(240,26)=(187.5,20.31)。
const RANKING_CENTER: Vector2 = Vector2(46.88, 35.16)
const HEAD_CENTER: Vector2 = Vector2(136.72, 35.16)
const HEAD_SIZE: Vector2 = Vector2(40.0, 40.0)
const NAMEBG_PVP_Y: float = 33.59
const NAMEBG_COMMON_Y: float = 21.88
const NAME_BG_RES: String = "res://assets/ui/alpha/HVGA/task_name_bg.png"
# nameBg 纹理 422x34px ÷CS = 329.37x26.54 点。
const NAME_BG_SIZE: Vector2 = Vector2(329.37, 26.54)
const NAME_X: float = 218.75
const RECORD_POS: Vector2 = Vector2(187.5, 41.91)
# hero_evo_star 的星图标（源 :879-891 detail_star scale 0.5：70x71px ÷CS×0.5 = 27.31x27.71）。
const STAR_ICON_RES: String = "res://assets/ui/alpha/HVGA/detail_star.png"
const STAR_ICON_SIZE: Vector2 = Vector2(27.31, 27.71)
# tab 布局（源 reCalculateRankBtnPos :1898-1925 精确直译：height=380 再 +5 起步、循环内先 -5
# 再放组按钮 → 组1 pos=380；步进 47；展开组尾再 -5（+下组开头 -5 = 组间 gap 10）；折叠组子
# 按钮只藏不占位；子按钮贴图=pc+(8,-5)（createRankBtn Ppoint :2050-2054）；
# TabHost 局部 = 场景 - (130,154)）。
const TAB_X: float = 120.0
const TAB_TOP_H: float = 385.0
const TAB_STEP: float = 47.0
const TAB_GROUP_GAP: float = 5.0
const TAB_SUB_DX: float = 8.0
const TAB_SUB_DY: float = 5.0
const TAB_CLIP_POS: Vector2 = Vector2(130.0, 154.0)
const TAB_W: float = 135.16
const TAB_H: float = 58.59
# P0 我的排名浮窗（源 ranklist.lua:1318-1571）→ RanklistMyselfOverlay 拆出。
# pageContainer 源 ccp(245,400) 在 ranklistwindow 编辑器容器局部（cocos 800×481.25 y-up 世界
# = 屏幕 to_godot(x,y)=(x+80,560-y)）→ 屏幕点 (325,160)。
# 2026-08-18 用户实跑修复：旧值 (245,80) 双漏偏移（x 漏 +80 平移、y 漏 560-480 边距）
# → 浮窗遮在 window 边框上，应在列表顶部区。
const OVERLAY_PAGE_GODOT_X: float = 325.0
const OVERLAY_PAGE_GODOT_Y: float = 160.0
# tab 树（%按钮名 ↔ 源 ranklisttree/ranklist_config；key 为 LSTR 键，fill 时 get_lstr）。
# tips_key = 行内 record 文案（源 :839-861 config table；pvp 榜无 record 行）。
const TAB_TREE: Array = [
	{
		"btn": "GroupArena", "title_key": "RANKLIST.ARENA", "children": [
			{"btn": "SubPvp", "mode": "pvp", "key": "RANKLIST.ARENADAY"},
		],
	},
	{
		"btn": "GroupFightvalue", "title_key": "RANKLIST.FIGHTVALUE", "children": [
			{"btn": "SubFullHeroGs", "mode": "full_hero_gs", "key": "RANKLIST.ALLMEMBERFIGHTVALUE", "tips_key": "RANKLIST.ALLHEROFIGHTVALUE"},
			{"btn": "SubHeroTeamGs", "mode": "hero_team_gs", "key": "RANKLIST.LITTLETEAMFIGHTVALUE", "tips_key": "RANKLIST.TOPFIVEFIGHTVALUE"},
			{"btn": "SubHeroEvoStar", "mode": "hero_evo_star", "key": "RANKLIST.HEROSTAR", "tips_key": "RANKLIST.HEROALLSTAR", "star_icon": true},
		],
	},
]

var _rm: RanklistManager
var _player: PlayerData
var _rank_type: String
var _content: Control
var _tab_host: Control
var _rows: VBoxContainer
var _collapsed: Dictionary


func setup_panel(p_player: PlayerData, p_rm: RanklistManager, rank_type: String) -> void:
	_player = p_player
	_rm = p_rm
	_rank_type = rank_type
	# 源为 pushScene 全屏场景（bg.jpg 铺满）→ shade 透明不吞点击（crusade 先例）。
	transparent_shade = true
	setup()
	_build_content()


# 建 UI：静态树从 .tscn instantiate + 绑定信号 + fill 文本/tab 状态/列表行。
func _build_content() -> void:
	_collapsed = {0: false, 1: true}
	_content = CONTENT_SCENE.instantiate()
	container.add_child(_content)
	(_tab("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	(_tab("%Title") as Label).text = _player.cm.get_lstr("RANKLIST.RANKLISTTITLE")
	_tab_host = _tab("%TabHost") as Control
	_rows = _tab("%Rows") as VBoxContainer
	_bind_tabs()
	_refresh_list()


func _tab(path: String) -> Node:
	return _content.get_node(path)


# tab 信号绑定 + LSTR 文本（源 ranklisttree 展开/折叠初始：组1 展开其余折叠）。
func _bind_tabs() -> void:
	for gi in TAB_TREE.size():
		var group: Dictionary = TAB_TREE[gi]
		var gbtn := _tab("%%%s" % group["btn"]) as TextureButton
		gbtn.pressed.connect(_on_group_pressed.bind(gi))
		(gbtn.get_child(0) as Label).text = _player.cm.get_lstr(group["title_key"])
		for child in group["children"]:
			var sbtn := _tab("%%%s" % child["btn"]) as TextureButton
			sbtn.pressed.connect(_on_tab_pressed.bind(child["mode"]))
			(sbtn.get_child(0) as Label).text = _player.cm.get_lstr(child["key"])
	_layout_tabs()


# 重排静态 tab 按钮（源 reCalculateRankBtnPos :1898-1925 精确直译）：
# height 385(=380+5) 起步；每组先 -5 再放组按钮（组1 pos=380，非 385）；组后 -47；
# 展开组逐子 -47 且尾再 -5（下组开头又 -5 → 展开后组间 gap=10）；折叠组子按钮只藏不占位。
# 场景 y-up → Godot (x+80, 560-y) → TabHost 局部（TabClip 左上 (130,154)）再减半尺寸。
func _layout_tabs() -> void:
	var height: float = TAB_TOP_H
	for gi in TAB_TREE.size():
		var group: Dictionary = TAB_TREE[gi]
		var collapsed: bool = bool(_collapsed.get(gi, true))
		height -= TAB_GROUP_GAP
		var gbtn := _tab("%%%s" % group["btn"]) as TextureButton
		_set_tab_state(gbtn, true, not collapsed)
		gbtn.position = Vector2(
			TAB_X + 80.0 - TAB_CLIP_POS.x - TAB_W * 0.5,
			(560.0 - height) - TAB_CLIP_POS.y - TAB_H * 0.5)
		height -= TAB_STEP
		for child in group["children"]:
			var sbtn := _tab("%%%s" % child["btn"]) as TextureButton
			sbtn.visible = not collapsed
			_set_tab_state(sbtn, false, child["mode"] == _rank_type)
			if not collapsed:
				sbtn.position = Vector2(
					TAB_X + TAB_SUB_DX + 80.0 - TAB_CLIP_POS.x - TAB_W * 0.5,
					(560.0 - (height - TAB_SUB_DY)) - TAB_CLIP_POS.y - TAB_H * 0.5)
				height -= TAB_STEP
		if not collapsed:
			height -= TAB_GROUP_GAP


# tab 贴图/文字 variation 选中态切换（源 resTbl sel/notsel + btncolortree :2042-2046）。
func _set_tab_state(btn: TextureButton, is_group: bool, is_sel: bool) -> void:
	if is_group:
		btn.texture_normal = load(GROUP_SEL_NORMAL if is_sel else GROUP_UNSEL_NORMAL)
		btn.texture_pressed = load(GROUP_SEL_PRESS if is_sel else GROUP_UNSEL_PRESS)
		(btn.get_child(0) as Label).theme_type_variation = "RanklistGroupTabSelLabel" if is_sel else "RanklistGroupTabLabel"
	else:
		btn.texture_normal = load(SUB_SEL_NORMAL if is_sel else SUB_UNSEL_NORMAL)
		btn.texture_pressed = load(SUB_SEL_PRESS if is_sel else SUB_UNSEL_PRESS)
		(btn.get_child(0) as Label).theme_type_variation = "RanklistSubTabSelLabel" if is_sel else "RanklistSubTabLabel"


func _on_group_pressed(gi: int) -> void:
	_collapsed[gi] = not bool(_collapsed.get(gi, true))
	_layout_tabs()


func _on_tab_pressed(mode: String) -> void:
	_rank_type = mode
	_layout_tabs()
	_refresh_list()


# 行点击弹 RanklistSummary（照源 initpvpItemHandler:656 点击弹 userpvpsummary）。
func _on_row_input(event: InputEvent, rank: int, row_name: String, level: int, param: int, avatar: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var summary := RanklistSummary.new()
		summary.setup_panel(row_name, level, param, avatar, rank, _player.cm)
		summary.show_window(get_parent())


func _refresh_list() -> void:
	for c in _rows.get_children():
		c.queue_free()
	# P0 我的排名浮窗（源 :1318-1571）：旧 pageContainer 清理（浮在 scroll 上）。
	for c in container.get_children():
		if c.name == "PageContainer":
			c.queue_free()
	var r: Dictionary = _rm.generate_ranklist(_player, _rank_type)
	_rows.add_child(_make_row(0, _player.player_name, _player.team_level, int(r["self_param"]), int(r.get("self_avatar", 0)), true))
	for i in r["items"].size():
		var item: Dictionary = r["items"][i]
		_rows.add_child(_make_row(i + 1, String(item["name"]), int(item["level"]), int(item["param"]), int(item.get("avatar", 0))))
	# P0 我的排名浮窗：self_rank>2 时在 ScrollLayer 之上叠 pageContainer（前 2 已列表内显）。
	_build_myself_overlay(int(r["self_rank"]), int(r.get("self_avatar", 0)))


# 源 ranklist.lua:1318-1571 createMyselfRankSummary：self_rank<=2 不叠（前 2 已列表显）。
# 单机化 prev_index=0 → delta=self_rank（源 :1364-1365）。挂 container（ScrollLayer 之上）。
func _build_myself_overlay(self_rank: int, avatar: int) -> void:
	if self_rank <= RanklistMyselfOverlay.RANK_TOP_VISIBLE_MAX:
		return
	var avatar_pic: String = ""
	if _player != null and _player.cm != null:
		avatar_pic = String(_player.cm.get_raw_table(&"Avatar").get(str(avatar), {}).get("Picture", ""))
		if not avatar_pic.is_empty():
			avatar_pic = "res://assets/ui/" + avatar_pic.substr(3)
	# pageContainer 源 ccp(245,400) 在 ranklist window 容器坐标系（cocos y-up 480 → Godot y-down）。
	var page: Control = RanklistMyselfOverlay.build(container, self_rank, _player.player_name, _player.team_level, avatar_pic)
	if page != null:
		page.position = Vector2(OVERLAY_PAGE_GODOT_X, OVERLAY_PAGE_GODOT_Y)


# 行渲染（源 initpvpItemHandler :574-673 / initCommonItemHandler :775-928）：
# board Scale9 + ranking + head + nameBg + name(+LvN) +（战力系）record tips + value。
func _make_row(rank: int, row_name: String, level: int, param: int, avatar: int, is_self: bool = false) -> Control:
	var is_pvp: bool = _rank_type == "pvp"
	var row := Control.new()
	row.custom_minimum_size = BOARD_SIZE
	row.gui_input.connect(_on_row_input.bind(rank, row_name, level, param, avatar))
	var board := NinePatchRect.new()
	board.texture = load(ROW_BOARD_SELF if is_self else ROW_BOARD_OTHER) as Texture2D
	board.patch_margin_left = BOARD_PATCH_L
	board.patch_margin_top = BOARD_PATCH_T
	board.patch_margin_right = BOARD_PATCH_R
	board.patch_margin_bottom = BOARD_PATCH_B
	board.size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(board)
	# ranking：1st/2nd/3rd 徽章缺图（披露）→ 全档 Label "#N" 降级；self 行 "★"（迁移期行为）。
	var rank_lbl := Label.new()
	rank_lbl.text = "★" if rank == 0 else "#%d" % rank
	rank_lbl.theme_type_variation = "RanklistWhiteLabel18"
	rank_lbl.position = RANKING_CENTER - Vector2(30.0, 12.0)
	rank_lbl.size = Vector2(60.0, 24.0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(rank_lbl)
	# head：源 getTeamHead 组件（图+金框+mask）缺 → Avatar.Picture 直显（披露）。
	if _player != null and _player.cm != null:
		var pic: String = String(_player.cm.get_raw_table(&"Avatar").get(str(avatar), {}).get("Picture", ""))
		if not pic.is_empty():
			var head_path: String = "res://assets/ui/" + pic.substr(3)
			if ResourceLoader.exists(head_path):
				var head := TextureRect.new()
				head.texture = load(head_path)
				head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				head.size = HEAD_SIZE
				head.position = HEAD_CENTER - HEAD_SIZE * 0.5
				head.mouse_filter = Control.MOUSE_FILTER_IGNORE
				board.add_child(head)
	# nameBg（源 task_name_bg.png 名字底板）+ name（源 18 号白；等级徽章缺 → 合并 "LvN"，披露）。
	var name_bg_y: float = NAMEBG_PVP_Y if is_pvp else NAMEBG_COMMON_Y
	var name_bg := TextureRect.new()
	name_bg.texture = load(NAME_BG_RES) as Texture2D
	name_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	name_bg.size = NAME_BG_SIZE
	name_bg.position = Vector2(195.31, name_bg_y - NAME_BG_SIZE.y * 0.5)
	name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(name_bg)
	var name_lbl := Label.new()
	name_lbl.text = "%s Lv%d" % [row_name, level]
	name_lbl.theme_type_variation = "RanklistWhiteLabel18"
	name_lbl.position = Vector2(NAME_X, name_bg_y - 12.0)
	name_lbl.size = Vector2(240.0, 24.0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(name_lbl)
	if not is_pvp:
		_add_record_row(row, board, param)
	return row


# 战力系 record 行（源 :839-905）：tipsText 18 号 ccc3(128,54,23) + value（千分位，源
# formatNumWithComma → 复用 BattleStatisticsCalc.format_comma）；hero_evo_star 加星图标。
# value/star 在 record 右侧（源 getRightSidePos）：record 宽离树测不准（variation 18 号
# 未挂树不解析）→ row.ready 后精排（_place_record_tail）。
func _add_record_row(row: Control, board: Control, param: int) -> void:
	var tips_key: String = ""
	var with_star: bool = false
	for group in TAB_TREE:
		for child in group["children"]:
			if child["mode"] == _rank_type:
				tips_key = String(child.get("tips_key", ""))
				with_star = bool(child.get("star_icon", false))
	if tips_key.is_empty():
		return
	var record := Label.new()
	record.text = _player.cm.get_lstr(tips_key)
	record.theme_type_variation = "RanklistRowRecordLabel"
	record.position = RECORD_POS
	record.size = Vector2(240.0, 24.0)
	record.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(record)
	var value := Label.new()
	value.text = BattleStatisticsCalc.format_comma(param)
	value.theme_type_variation = "RanklistRowRecordLabel"
	value.position = RECORD_POS
	value.size = Vector2(240.0, 24.0)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(value)
	var star: TextureRect = null
	if with_star:
		star = TextureRect.new()
		star.texture = load(STAR_ICON_RES) as Texture2D
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.size = STAR_ICON_SIZE
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(star)
	row.ready.connect(_place_record_tail.bind(record, star, value))


# record 右侧精排（源 getRightSidePos(record) + icon anchor(0,0.4)）：
# record 已入树 → get_minimum_size() 解析 variation 18 号字体宽度。
func _place_record_tail(record: Label, star: TextureRect, value: Label) -> void:
	var value_x: float = RECORD_POS.x + record.get_minimum_size().x
	if star != null:
		# 源 anchor ccp(0,0.4)：顶=中心线 y(53.91) - 高x0.4。
		star.position = Vector2(value_x, 53.91 - STAR_ICON_SIZE.y * 0.4)
		value_x += STAR_ICON_SIZE.x
	value.position = Vector2(value_x, RECORD_POS.y)
