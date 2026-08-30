class_name RanklistPanel
extends PopWindow

## 排行榜面板（View 层）— 照源 ranklist.lua + uieditor/ranklistwindow.lua（批4 Task 8 两件套改造）。
## 窗口框架/tab 按钮/列表容器静态化进 ranklist_content.tscn（编辑器所见即所得）；
## 本文件只做业务、信号 connect、fill（% 取节点填动态数据），行渲染下沉 RanklistRows
## （走查批 C 2026-08-27：三分支布局 + 裸版徽章/贴图数字/TeamHeadIcon/LevelIcon 像素级补全）。
## tab 树照源 ranklisttree（:386-495）3 组 5 子：竞技场{每日排名, 实时}、战力{8,9,10}、
## 公会{活跃}。pvp_r 单机无实时数据 → 复用 pvp 榜假数据（manager default 参数公式同 pvp，
## 受控偏离披露）；guildliveness 假榜 manager 已就绪。浮窗显示条件照源 :1330（pvp 不叠）。
## self 行照源榜单语义：self_rank 榜内则替换该位 NPC（me_bg 高亮），榜外仅浮窗显示。

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
# 行板/行内布局/record 常量迁 RanklistRows（批 C 2026-08-27 行渲染下沉）。
# tab 布局（源 reCalculateRankBtnPos :1898-1925 精确直译：height=380 再 +5 起步、循环内先 -5
# 再放组按钮 → 组1 pos=380；步进 47；展开组尾再 -5（+下组开头 -5 = 组间 gap 10）；折叠组子
# 按钮只藏不占位；子按钮贴图=pc+(8,-5)（createRankBtn Ppoint :2050-2054）；
# TabHost 局部 = 场景 - TAB_CLIP_POS（clip tscn offset 960 口径 130,154 迁 800 口径 50,74）。
const TAB_X: float = 120.0
const TAB_TOP_H: float = 385.0
const TAB_STEP: float = 47.0
const TAB_GROUP_GAP: float = 5.0
const TAB_SUB_DX: float = 8.0
const TAB_SUB_DY: float = 5.0
const TAB_CLIP_POS: Vector2 = Vector2(50.0, 74.0)   # 与 ranklist_content.tscn TabClip（Task 4 迁后）同步 -80/-80
const TAB_W: float = 135.16
const TAB_H: float = 58.59
# P0 我的排名浮窗（源 ranklist.lua:1318-1571）→ RanklistMyselfOverlay 拆出。
# pageContainer 源 ccp(245,400) 在 ranklistwindow 编辑器容器局部（cocos 800×481.25 y-up 世界
# = 屏幕 to_godot(x,y)=(x,480-y)）→ 屏幕点 (245,80)。
# 2026-08-18 用户实跑修复：旧值 (245,80) 在 960×640 口径下双漏偏移（x 漏 +80、y 漏 560-480）；
# viewport 800×480 后容器满屏无偏移，(245,80) 即源直译正确位（数值回到源直译非回退）。
const OVERLAY_PAGE_GODOT_X: float = 245.0
const OVERLAY_PAGE_GODOT_Y: float = 80.0
# tab 树（%按钮名 ↔ 源 ranklisttree/ranklist_config；key 为 LSTR 键，fill 时 get_lstr）。
# tips_key = 行内 record 文案（源 :839-861 config table；pvp 榜无 record 行）。
const TAB_TREE: Array = [
	{
		"btn": "GroupArena", "title_key": "RANKLIST.ARENA", "children": [
			{"btn": "SubPvp", "mode": "pvp", "key": "RANKLIST.ARENADAY"},
			{"btn": "SubArenaRealtime", "mode": "pvp_r", "key": "RANKLIST.ARENAREALTIME"},
		],
	},
	{
		"btn": "GroupFightvalue", "title_key": "RANKLIST.FIGHTVALUE", "children": [
			{"btn": "SubFullHeroGs", "mode": "full_hero_gs", "key": "RANKLIST.ALLMEMBERFIGHTVALUE", "tips_key": "RANKLIST.ALLHEROFIGHTVALUE"},
			{"btn": "SubHeroTeamGs", "mode": "hero_team_gs", "key": "RANKLIST.LITTLETEAMFIGHTVALUE", "tips_key": "RANKLIST.TOPFIVEFIGHTVALUE"},
			{"btn": "SubHeroEvoStar", "mode": "hero_evo_star", "key": "RANKLIST.HEROSTAR", "tips_key": "RANKLIST.HEROALLSTAR", "star_icon": true},
		],
	},
	{
		"btn": "GroupGuild", "title_key": "RANKLIST.GUILD", "children": [
			{"btn": "SubGuildActive", "mode": "guildliveness", "key": "RANKLIST.GUILDACTIVE", "tips_key": "ranklist.1.10.1.003"},
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
	hud_identity = "ranklist"   # 2026-08-18 修复轮二 R2：主城直开——切子场景 StatusBar（无头像，excavate 判例），用户反馈主头像透到二级界面
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
	_scroll_layer = _tab("%ScrollLayer") as ScrollContainer
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
# 场景 y-up → Godot (x, 480-y) → TabHost 局部（TabClip 左上 (50,74)）再减半尺寸。
func _layout_tabs() -> void:
	var height: float = TAB_TOP_H
	for gi in TAB_TREE.size():
		var group: Dictionary = TAB_TREE[gi]
		var collapsed: bool = bool(_collapsed.get(gi, true))
		height -= TAB_GROUP_GAP
		var gbtn := _tab("%%%s" % group["btn"]) as TextureButton
		_set_tab_state(gbtn, true, not collapsed)
		gbtn.position = Vector2(
			TAB_X - TAB_CLIP_POS.x - TAB_W * 0.5,
			(480.0 - height) - TAB_CLIP_POS.y - TAB_H * 0.5)
		height -= TAB_STEP
		for child in group["children"]:
			var sbtn := _tab("%%%s" % child["btn"]) as TextureButton
			sbtn.visible = not collapsed
			_set_tab_state(sbtn, false, child["mode"] == _rank_type)
			if not collapsed:
				sbtn.position = Vector2(
					TAB_X + TAB_SUB_DX - TAB_CLIP_POS.x - TAB_W * 0.5,
					(480.0 - (height - TAB_SUB_DY)) - TAB_CLIP_POS.y - TAB_H * 0.5)
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
var _row_press: Variant = null   # 行点击位移判别（修复轮四：按下即弹吞拖动）
var _drag_state: Dictionary = {}   # DragScrollHelper 跨帧基准
var _scroll_layer: ScrollContainer = null

# 拖拽滚动（修复轮四：Godot 4 ScrollContainer 桌面无拖拽，源 draglist 手势补齐）。
func _input(event: InputEvent) -> void:
	if _scroll_layer != null:
		DragScrollHelper.handle_input(_scroll_layer, event, _drag_state)

# 行点击弹 RanklistSummary（照源 initpvpItemHandler:656 点击弹 userpvpsummary）。
# 修复轮四：press 记录 → release 位移 <8px 才触发（拖动滚动不触发弹窗）。
func _on_row_input(event: InputEvent, rank: int, row_name: String, level: int, param: int, avatar: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_row_press = mb.global_position
		elif DragScrollHelper.is_tap(_row_press, mb.global_position):
			_row_press = null
			var summary := RanklistSummary.new()
			summary.setup_panel(row_name, level, param, avatar, rank, _player.cm)
			summary.show_window(get_parent())
		else:
			_row_press = null


func _refresh_list() -> void:
	for c in _rows.get_children():
		c.queue_free()
	# P0 我的排名浮窗（源 :1318-1571）：旧 pageContainer 清理（浮在 scroll 上）。
	for c in container.get_children():
		if c.name == "PageContainer":
			c.queue_free()
	var r: Dictionary = _rm.generate_ranklist(_player, _rank_type)
	var is_guild: bool = _rank_type == "guildliveness"
	var tips_key: String = ""
	var with_star: bool = false
	for group in TAB_TREE:
		for child in group["children"]:
			if child["mode"] == _rank_type:
				tips_key = String(child.get("tips_key", ""))
				with_star = bool(child.get("star_icon", false))
	# 照源榜单语义：self_rank 榜内则替换该位 NPC（me_bg 高亮行），榜外仅浮窗显示
	# （旧版 rank0 "★" 顶部恒叠为迁移期行为，批 C 撤销）。
	var items: Array = (r["items"] as Array).duplicate()
	var self_rank: int = int(r["self_rank"])
	if self_rank >= 1 and self_rank <= items.size():
		items[self_rank - 1] = {
			"name": _player.player_name, "level": _player.team_level,
			"param": int(r["self_param"]), "avatar": int(r.get("self_avatar", 0)), "self": true,
		}
	# 2026-08-18 修复轮二 R1：浮窗让位照源——源 rankListMyselfOffsetY=80（:1336），浮窗显示
	# 时 draglist 下移 80（:1704/:1712），本项目等价 = Rows 顶部垫 80 spacer。
	# 浮窗显示条件照源 :1330（pvp 不叠），与 spacer 绑定。
	var show_overlay: bool = _rank_type != "pvp" and self_rank >= 0
	if show_overlay:
		var spacer := Control.new()
		spacer.name = "MyselfSpacer"
		spacer.custom_minimum_size = Vector2(0.0, RanklistMyselfOverlay.SCROLL_OFFSET_Y)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(spacer)
	for i in items.size():
		var item: Dictionary = items[i]
		var row := RanklistRows.make_row(_player.cm, _rank_type, tips_key, with_star,
			i + 1, String(item["name"]), int(item["level"]), int(item["param"]), int(item.get("avatar", 0)),
			bool(item.get("self", false)))
		if not is_guild:
			row.gui_input.connect(_on_row_input.bind(i + 1, String(item["name"]), int(item["level"]), int(item["param"]), int(item.get("avatar", 0))))
		_rows.add_child(row)
	# P0 我的排名浮窗（源 :1318-1571 createMyselfRankSummary）。
	if show_overlay:
		_build_myself_overlay(self_rank, int(r["self_param"]))


# 源 ranklist.lua:1318-1571 createMyselfRankSummary：mode==pvp 不叠（:1330 判 tab index）。
# 单机化 prev_index=0 → delta=self_rank（源 :1364-1365）。挂 container（ScrollLayer 之上）。
func _build_myself_overlay(self_rank: int, self_param: int) -> void:
	# pageContainer 源 ccp(245,400) 在 ranklist window 容器坐标系（cocos y-up 480 → Godot y-down）。
	var page: Control = RanklistMyselfOverlay.build(container, _player.cm, _rank_type,
		self_rank, self_param, _player.player_name, _player.team_level, _player.avatar)
	if page != null:
		page.position = Vector2(OVERLAY_PAGE_GODOT_X, OVERLAY_PAGE_GODOT_Y)
