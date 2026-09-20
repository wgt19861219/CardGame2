class_name BattlePreparePanel
extends Control

## 战前布阵面板（View 层）— 照源 battleprepare.lua 核心单机段翻译。
## 选英雄（按 position 分类 tab all/front/middle/back）+ 上阵/下阵 + maxRange 自动排序 +
## gs 显示 + 开始战斗。
## 归位（2026-09-15）：自 scripts/view/battle/ 迁入 scripts/ui/——五域共用（关卡/远征/
## 副本/竞技场攻守/挖矿换队进攻）属跨域通用组件，归位后 LAYER003 白名单 2 条清偿。
## 重构（2026-07-17）：UI 静态节点（bg/list_frame/team_bg/5 bucket/4 tab/go/gs label）
## 固化进 battle_prepare_content.tscn（位置/size 编辑器可视化调）。panel instantiate + fill
## 动态数据/样式 + 接业务信号。坐标源 cocos(800×480 左下) → Godot(800×480 左上) via (cx, 480-cy)。
##
## mode（源 battleprepare.lua:1746 self.mode = info.mode）：
##   "stage"（默认）= 普通关卡/副本（源 dungeon 同走 doGo+td_cm），_on_go_pressed 走
##     mgr.assemble_stage_battle 进 battle_scene + _persist_team 写回 player.team。
##   "crusade"（源 crusade.lua:431-441 start() 传 mode=crusade + heroLimit level=20）=
##     照源 doCrusade→gotoBattle enterCrusade+replaceScene：走 CrusadeBattle.assemble 进
##     battle_scene 观战（2026-09-14 改造，旧同步数值结算 _run_crusade_go 退役）；
##     战斗结束 battle_scene._finalize 加 crusade 分支 → 胜利回远征面板/失败切结算场景
##     （旧 crusade_battle_finished 同步信号链退役——跨场景后面板销毁，信号无人可收）。
##   其余模式（pvp_attack/pvp_defend/excavate_change/excavate_attack，2026-09-15 补全
##     源 requestBattle :569-586 五入口选人）：走 on_confirm 回调注入——调用方自带装配/
##     写防守逻辑（源 pvp attack 写 td_pp 独立记忆，本项目单字段下不写回防污染关卡阵容，
##     受控偏离；pvp defend/excavateChange 初始阵容由 initial_tids 传入当前防守阵）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/battle_prepare_content.tscn")
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const ReadheroIcon = preload("res://scripts/ui/readhero_icon.gd")
const TEAM_MAX: int = 5

const TAB_ALL: String = "all"
const TAB_FRONT: String = "front"
const TAB_MIDDLE: String = "middle"
const TAB_BACK: String = "back"

# StyleBoxTexture content_margin=0 让 Button 直接贴图（视觉等价纯 Sprite，源 doChangeListTouch :1216 切 visible）。
const TAB_N_RES: String = "res://assets/ui/alpha/HVGA/classbtn.png"
const TAB_A_RES: String = "res://assets/ui/alpha/HVGA/classbtnselected.png"
const GO_N_RES: String = "res://assets/ui/alpha/HVGA/prepare_go_battle.png"
const GO_P_RES: String = "res://assets/ui/alpha/HVGA/prepare_go_battle_press.png"
# 已选标记照源 readhero.lua:538-556 showSelectTag：黑罩 150/255 只盖 portrait 区（框/星不灰）
# + tick.png 右下角 z12（64×61px÷CS=49.95×47.61）。portrait 显示 78×78 贴 container 左下（区 [26,104]）。
# shade z=2：源罩挂 clippingNode 子树内而星挂 container z5 画在其上（星不被罩暗，双端截图对照），
# Godot 无 clippingNode 层级，用 z 序等效（portrait/frame z0 < shade z2 < stars z5 < tick z12）。
const TICK_RES: String = "res://assets/ui/alpha/HVGA/tick.png"
const SELECT_SHADE_ALPHA: float = 150.0 / 255.0
const PORTRAIT_RECT_POS: Vector2 = Vector2(0.0, 26.0)
const PORTRAIT_RECT_SIZE: Vector2 = Vector2(78.0, 78.0)
const TICK_DISPLAY_SIZE: Vector2 = Vector2(49.95, 47.61)
const TICK_Z: int = 12
const SHADE_Z: int = 2
const TAB_FONT_COLOR_SELECTED: Color = Color(0.902, 0.745, 0.298)
const TAB_FONT_COLOR_UNSELECTED: Color = Color(0.769, 0.733, 0.667)
const TAB_SHADOW_COLOR: Color = Color(0.165, 0.122, 0.086)
const TAB_SHADOW_OFFSET_Y: int = 2
const TAB_FONT_SIZE: int = 20
const TAB_LABEL_NODE_NAMES: Dictionary = {
	TAB_ALL: "%TabAllLabel",
	TAB_FRONT: "%TabFrontLabel",
	TAB_MIDDLE: "%TabMiddleLabel",
	TAB_BACK: "%TabBackLabel",
}

# ── 文本 LSTR key（源 battleprepare.lua:1870 BATTLEPREPARE.WHOLE / :1915 UNIT.FRONT_ROW /
# :1960 UNIT.MIDDLE_ROW / :2005 UNIT.REAR_ROW / :2256 BATTLEPREPARE.COMBAT 战斗力标题 /
# :2241 CHATCONFIG.CONFIRM 确认开战按钮）──
const LSTR_TAB_ALL: String = "BATTLEPREPARE.WHOLE"
const LSTR_TAB_FRONT: String = "UNIT.FRONT_ROW"
const LSTR_TAB_MIDDLE: String = "UNIT.MIDDLE_ROW"
const LSTR_TAB_BACK: String = "UNIT.REAR_ROW"
const LSTR_COMBAT: String = "BATTLEPREPARE.COMBAT"
const LSTR_CONFIRM: String = "CHATCONFIG.CONFIRM"
const LSTR_NOTENOUGH: String = "BATTLEPREPARE.PLEASE_SELECT_BATTLE_HERO"
const LSTR_SAME_NAME: String = "BATTLEPREPARE.HEROES_OF_THE_SAME_NAME_CAN_NOT_BE_USED_IN_ONE_FIGHT"

var stage_id: int = 0
var player: Variant = null
var mgr: Variant = null
var rng: Variant = null
var cm: Variant = null
var mode: String = "stage"
var min_level: int = 0
var hero_limit: Dictionary = {}   # 源 heroLimit {type,detail}（Gender=20005 女性英雄组限制）
var _heroes_all: Array = []      # 全部可选英雄 [{inst_id, tid, pos_type, max_range}]
var _heroes_filtered: Array = [] # 当前 tab 过滤后
var _team: Array = []            # 已上阵 [{inst_id, tid, max_range}]（按 maxRange 降序）
var _current_tab: String = TAB_ALL
var _initial_tids: Array[int] = []   # 外部初始阵容 tid（pvp defend/excavateChange 当前防守阵）
var _on_confirm_cb: Callable = Callable()   # 确认回调（attack/防守系注入，替代面板内装配）
var _list_grid: GridContainer = null
var _team_slots: Array[TextureRect] = []  # 5 个槽位底（源 herobucket.png，.tscn %MemberBg1-5）
var _gs_label: Label = null
var _gs_title_label: Label = null  # 战斗力标题（源 gs_title，GsLabel 上方）
var _go_button: Button = null
var _tab_buttons: Dictionary = {}   # tab_key → Button（源 listButton/listButtonSelect 双态切换）
var _tab_labels: Dictionary = {}    # tab_key → Label（独立 Label 子节点，Button.text 内嵌 label 受 stylebox 干扰）
var _prev_identity: String = ""     # 进入前 HUD identity（tree_exited 恢复用）


# p_mode/p_min_level 可选（默认 "stage" + 0 = 不限等级），向后兼容 stage_detail_panel 5 参数调用。
# p_initial_tids 可选（tid 列表）：外部初始阵容（pvp defend=当前防守阵/excavateChange=当前驻防队，
# 源 getLastTeam :1428-1430/:1436-1437 用 create 传入阵容做默认队）；空则照旧 player.team/前 5。
# p_on_confirm 可选：确认回调（签名 (tids: Array[int])），副本/竞技场攻守/挖矿系 View 调用方
# 注入装配/写防守逻辑（源 requestBattle :569-586 各模式分发；本项目单机化=回调注入解耦，
# 面板不耦合 ladder/excavate）。回调模式不走 stage 装配与 _persist_team 写回。
# p_hero_limit 可选（源 info.heroLimit :1737，资源试炼 Gender=女 2026-09-19 照源回归补）：
# {type,detail} 过滤可选英雄（源 getAllListWithLimit :867-883 Unit[tid][type]==detail），
# 过滤作用于 _heroes_all → 列表/初始阵容（player.team 记忆含违规英雄自然装不上）双保险。
func setup(p_stage_id: int, p_player: Variant, p_mgr: Variant, p_rng: Variant, p_cm: Variant, p_mode: String = "stage", p_min_level: int = 0, p_initial_tids: Array[int] = [], p_on_confirm: Callable = Callable(), p_hero_limit: Dictionary = {}) -> void:
	stage_id = p_stage_id; player = p_player; mgr = p_mgr; rng = p_rng; cm = p_cm
	mode = p_mode; min_level = p_min_level
	hero_limit = p_hero_limit
	_initial_tids = p_initial_tids; _on_confirm_cb = p_on_confirm
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# BattlePreparePanel 是 Control 非 PopWindow，经 PopWindow.push_external 入动态 z 栈
	# 拿最高位+1，恒压栈内全部弹窗（详情 _on_go_pressed 在 add_child 后 remove_window 关详情，
	# 若不入栈会被关卡选择面板盖住，表现为"点 GoButton 回到关卡选择"）。
	# 旧实现写死 z=210：HeroScene 链（hero_package 占栈位使选关面板 z=200）下选关章节标题
	# effective 200+22=222 穿透布阵页（用户 2026-09-07 报「底下关卡的标题透过来了」）。
	PopWindow.push_external(self)
	# 战前编队界面源里无 HUD（货币栏/标题），切 battleprepare identity 整体隐藏 HUD；
	# tree_exited（queue_free）时恢复进入前 identity（stageselect/crusade 等）+ 出 z 栈
	#（非本类无 PREDELETE 兜底，退出出栈在此配对）。
	_prev_identity = HudOverlay.get_identity()
	HudOverlay.apply_identity("battleprepare")
	tree_exited.connect(_restore_identity)
	tree_exited.connect(func() -> void: PopWindow.pop_external(self))
	_load_hero_list()
	_build_content()
	_load_default_team()


func _restore_identity() -> void:
	HudOverlay.apply_identity(_prev_identity)


# 建 UI 内容（Phase 重构：从 battle_prepare_content.tscn instantiate + fill 动态数据/样式）。
# battle_prepare 是 Control 非 PopWindow，无 container → content 直接挂自身（保持原挂载语义）。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	add_child(content)
	_list_grid = content.get_node("%ListGrid") as GridContainer
	# 层级（照 hero_package:90-91）：ListFrame z=2 挡未选 tab 重叠区，ListScroll z=10 英雄列表置顶不被挡。
	(content.get_node("ListFrame") as CanvasItem).z_index = 2
	(content.get_node("ListScroll") as CanvasItem).z_index = 10
	_tab_buttons = {
		TAB_ALL: content.get_node("%TabAllBtn") as TextureButton,
		TAB_FRONT: content.get_node("%TabFrontBtn") as TextureButton,
		TAB_MIDDLE: content.get_node("%TabMiddleBtn") as TextureButton,
		TAB_BACK: content.get_node("%TabBackBtn") as TextureButton,
	}
	for key in _tab_buttons:
		var btn: TextureButton = _tab_buttons[key] as TextureButton
		# Label 独立节点（.tscn %TabXxxLabel，与 hero_package 范式一致），fill text。
		var lbl: Label = content.get_node(TAB_LABEL_NODE_NAMES[key]) as Label
		lbl.text = _tab_label(key)
		_tab_labels[key] = lbl
		btn.pressed.connect(_on_tab_pressed.bind(key))
	_update_tab_visual()
	_team_slots.clear()
	for i in range(TEAM_MAX):
		_team_slots.append(content.get_node("%MemberBg" + str(i + 1)) as TextureRect)
	_gs_label = content.get_node("%GsLabel") as Label
	_gs_title_label = content.get_node("%GsTitleLabel") as Label
	_go_button = content.get_node("%GoBtn") as Button
	# 照源 battleprepare.lua:1788-1791：GoBtn conform Label 仅 isSpecialgb（pvp defend/excavateChange）时 visible。
	# 本项目单机化已裁剪这两模式（grep 零匹配 isSpecialgb/defend/excavateChange）→ conform text 始终隐藏，
	# 由 prepare_go_battle 贴图自身表达"出战"语义（源 Sprite 贴图常显，conform text 是叠加层）。
	_go_button.text = ""
	_apply_go_style(_go_button)
	_go_button.pressed.connect(_on_go_pressed)
	var back_btn: TextureButton = content.get_node("%BackBtn") as TextureButton
	back_btn.pressed.connect(_on_back_pressed)
	# 源 battleprepare.lua:1091-1114 listTitle 黄字提示（顶部居中 Label，LSTR 化）。
	var list_title: Label = content.get_node_or_null("%ListTitleLabel") as Label
	if list_title != null:
		list_title.text = String(cm.get_lstr(LSTR_NOTENOUGH))
	_refresh_list()
	_refresh_team_display()
	_refresh_gs()


# Button 套 StyleBoxTexture（classbtn/classbtnselected 整图，content_margin=0 视觉等价纯贴图）。
# Tab 选中态：照 hero_package _update_tab_visual——texture_normal 切 classbtn/classbtnselected
# + Label 字色金黄/浅灰棕（源 :1200-1229 ccc3(230,190,76)/(196,187,170)）。
func _update_tab_visual() -> void:
	for key in _tab_buttons:
		var btn: TextureButton = _tab_buttons[key] as TextureButton
		var selected: bool = key == _current_tab
		btn.texture_normal = load(TAB_A_RES if selected else TAB_N_RES)
		# 照源：未选 classbtn(134px) 中心 x=708、选中 classbtnselected(145px) 中心 x=705（:1849/:1862）。
		# 两贴图显示宽不同（104.58/113.2=px÷CS），STRETCH_SCALE 下 rect 须随贴图切换等比宽度
		# （2026-08-30 四轮前选中被 104.58 rect 压扁 8%）。
		if selected:
			btn.size.x = 113.2
			btn.position.x = 705.0 - 113.2 * 0.5
		else:
			btn.size.x = 104.58
			btn.position.x = 708.0 - 104.58 * 0.5
		# 照 hero_package：未选 z=1 被 ListFrame(z=2) 挡重叠区，选中 z=3 凸出。
		btn.z_index = 3 if selected else 1
		var lbl: Label = _tab_labels.get(key) as Label
		if lbl != null:
			lbl.z_index = 4
			var color: Color = TAB_FONT_COLOR_SELECTED if selected else TAB_FONT_COLOR_UNSELECTED
			lbl.add_theme_color_override("font_color", color)
			lbl.add_theme_color_override("font_shadow_color", TAB_SHADOW_COLOR)
			lbl.add_theme_constant_override("shadow_offset_y", TAB_SHADOW_OFFSET_Y)
			lbl.add_theme_font_size_override("font_size", TAB_FONT_SIZE)


# GoBtn 双态：normal/hover=prepare_go_battle，pressed=prepare_go_battle_press（源 :1786-1787）。
func _apply_go_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_stylebox(GO_N_RES))
	btn.add_theme_stylebox_override("hover", _make_stylebox(GO_N_RES))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(GO_P_RES))


static func _make_stylebox(res_path: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(res_path) as Texture2D
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	return sb


# 过滤掉 <20 级英雄（:7 min_crusade_level + :962 上阵校验双保险，列表源 :1154 getAllListWithLimit）。
# 列表序照源 battleprepare.lua:1700-1704 classify → readhero getAllListForPrepare →
# ed.orderHeroes()（tools.lua:819-857）：等级→星级→rank 降序，classifyByPos 分组保序
#（_refresh_list 的 tab filter 同样保序）。旧实现遍历 heroes 字典（获得序）未排序，
# 2026-09-15 用户报出击列表排序问题——前期英雄练度高致获得序观感"像按练度"但非源规则。
func _load_hero_list() -> void:
	_heroes_all.clear()
	if player == null or player.hero_manager == null:
		return
	var owned: Array = []
	# heroLimit 过滤（源 readhero.getAllListWithLimit :867-883：Unit[tid][type]==detail，
	# type=level 时 detail<=等级走 min_level 通道不在此处）；crusade 等级限制同列表源 :1154。
	var limit_type: String = String(hero_limit.get("type", ""))
	var limit_detail: String = String(hero_limit.get("detail", ""))
	var unit_table: Dictionary = cm.get_raw_table(&"Unit")
	for inst_id in player.hero_manager.heroes:
		var hero = player.hero_manager.heroes[inst_id]
		if mode == "crusade" and int(hero.level) < min_level:
			continue
		if limit_type != "" and String(unit_table.get(str(int(hero.tid)), {}).get(limit_type, "")) != limit_detail:
			continue
		owned.append(hero)
	owned = ReadheroHandbook.order_heroes(owned)
	var skill_table: Dictionary = cm.get_raw_table(&"Skill")
	for hero in owned:
		var tid: int = int(hero.tid)
		var unit: Dictionary = unit_table.get(str(tid), {})
		var pos_raw: String = String(unit.get("Position Type", ""))
		var pos_type: String = "back"
		if pos_raw.find("FRONT") >= 0: pos_type = "front"
		elif pos_raw.find("MIDDLE") >= 0: pos_type = "middle"
		var basic_skill: int = int(unit.get("Basic Skill", 0))
		var max_range: int = 0
		if basic_skill > 0:
			max_range = int(skill_table.get(str(basic_skill), {}).get("0", {}).get("Max Range", 0))
		_heroes_all.append({inst_id = int(hero.inst_id), tid = tid, pos_type = pos_type, max_range = max_range})


func _refresh_list() -> void:
	for c in _list_grid.get_children(): c.queue_free()
	_heroes_filtered = _heroes_all if _current_tab == TAB_ALL else _heroes_all.filter(func(h): return h.pos_type == _current_tab)
	for h in _heroes_filtered:
		var hero = player.hero_manager.heroes[h.inst_id]
		var icon := ReadheroIcon.create_icon_by_hero(hero, cm)
		# 源 gap_x/gap_y=100、5 列、行高 100（battleprepare.lua:1548-1560）→ btn 84×84 +
		# GridContainer sep 16 = 中心距/行距恰 100，网格宽 5×84+4×16=484 ≤ 视口 495 无横滚。
		# btn 84 ≈ frame 显示 83：icon.position 令 portrait 视觉中心 (39,65) 对 btn 中心 (42,42)
		# → hover 高亮框与头像零错位（2026-08-30 四轮用户反馈修）；首列/首行 portrait 中心
		# = (189,80) 照源（hero_icon_ori 189/400，battleprepare.lua:1548-1549）。
		icon.position = Vector2(3.0, -23.0)
		var btn := Button.new(); btn.add_child(icon); btn.custom_minimum_size = Vector2(84, 84)
		btn.set_meta("inst_id", h.inst_id)
		var selected: bool = _team.any(func(t): return t.inst_id == h.inst_id)
		if selected: _apply_select_state(icon)
		btn.pressed.connect(_on_hero_clicked.bind(h.inst_id))
		_list_grid.add_child(btn)


# 已选状态照源 readhero showSelectTag（:538-556）：黑罩盖 portrait（框/星/对勾不受罩影响）
# + tick.png 右下角。旧实现 btn.modulate 整格灰化系偏离（连框带星一起灰且无对勾），照源订正。
func _apply_select_state(icon: ReadheroIcon) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, SELECT_SHADE_ALPHA)
	shade.position = PORTRAIT_RECT_POS
	shade.size = PORTRAIT_RECT_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.z_index = SHADE_Z
	icon.icon.add_child(shade)
	var tag := Sprite2D.new()
	tag.texture = load(TICK_RES) as Texture2D
	tag.scale = Vector2.ONE / ReadheroIcon.CONTENT_SCALE
	tag.position = Vector2(ReadheroIcon.CONTAINER_SIZE.x, ReadheroIcon.CONTAINER_SIZE.y) - TICK_DISPLAY_SIZE * 0.5
	tag.z_index = TICK_Z
	icon.icon.add_child(tag)


func _on_hero_clicked(inst_id: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if _team.any(func(t): return t.inst_id == inst_id):
		_remove_team_member(inst_id)
	else:
		_add_team_member(inst_id)


func _add_team_member(inst_id: int) -> void:
	if _team.size() >= TEAM_MAX:
		return
	var h: Dictionary = _heroes_all.filter(func(x): return x.inst_id == inst_id)[0]
	if _team.any(func(t): return t.tid == h.tid):
		Toast.show_message(cm.get_lstr(LSTR_SAME_NAME))   # extends Control 非 PopWindow，直调（T4 注）
		return  # 同名英雄禁用
	_order_team(h)  # 按 maxRange 插入正确位置
	_refresh_list(); _refresh_team_display(); _refresh_gs()


func _order_team(h: Dictionary) -> void:
	var entry := {inst_id = h.inst_id, tid = h.tid, max_range = h.max_range}
	if _team.size() == 0 or h.max_range > _team[-1].max_range:
		_team.append(entry); return
	if h.max_range <= _team[0].max_range:
		_team.insert(0, entry); return
	for i in range(_team.size() - 1):
		if h.max_range > _team[i].max_range and h.max_range <= _team[i + 1].max_range:
			_team.insert(i + 1, entry); return
	_team.append(entry)  # fallback


func _remove_team_member(inst_id: int) -> void:
	for i in range(_team.size()):
		if _team[i].inst_id == inst_id:
			_team.remove_at(i); break
	_refresh_list(); _refresh_team_display(); _refresh_gs()


func _refresh_team_display() -> void:
	for j in range(TEAM_MAX):
		# 源 getTeamMemberPos（battleprepare.lua:100-104）：index1 中心 x=593（cocos 左下
		# 原点 → Godot 最右，tscn MemberBg5 中心 x=592 即源 index1 位），每 +1 左移 100 →
		# 槽位序从右往左数。_team[j]（maxRange 升序第 j 小，源 index=j+1）挂
		# MemberBg{TEAM_MAX-j}：视觉左→右 = maxRange 大→小，空位在左端（源 setMemberIndex
		# 从 1 起往左扩）。旧实现 j→MemberBg{j+1} 从左填，视觉序与源左右颠倒（2026-09-15
		# 用户报出击阵容排列顺序问题）。
		var slot: TextureRect = _team_slots[TEAM_MAX - 1 - j]
		var halo: CanvasItem = slot.get_node_or_null("Halo") as CanvasItem
		for c in slot.get_children():
			if c is ReadheroIcon or (c is Button and c.has_meta("inst_id")):
				c.queue_free()
		var occupied: bool = j < _team.size()
		if occupied:
			var hero = player.hero_manager.heroes[_team[j].inst_id]
			var icon := ReadheroIcon.create_icon_by_hero(hero, cm)
			# ReadheroIcon 是 Node2D，position = container(104×104) 左上角。
			# 头像在桶内视觉居中（2026-08-30 用户观感裁决：源 getTeamMemberPos 锚点偏左下
			# ~12px 观感差，受控偏离不照源——同 2026-08-29 ladder 防守阵容「框中心对槽中心」
			# 判例）。portrait 显示恒 78×78（全 Unit.Portrait 实测 100px÷CS），其视觉中心 =
			# container 左上 + (39, 104−39)，对齐 slot 中心即可。
			var slot_center: Vector2 = slot.size * 0.5
			icon.position = slot_center - Vector2(39.0, 65.0)
			slot.add_child(icon)
			_attach_slot_click(slot, icon, int(_team[j].inst_id))
		if halo != null:
			halo.visible = occupied


# 底部已上阵头像点击下阵（源 doTeamTouch battleprepare.lua:843-878）：began 命中 icon 缩放
# 0.95、ended 仍命中则 destroyTeamMember。Godot 用 GhostButton 透明点击层承接（铺满槽，源
# containsPoint=icon 包围盒，桶边缘几像素差异受控偏离）：button_down 按压缩放 / button_up
# 回弹 / pressed 下阵（_remove_team_member 三刷新含列表对勾同步）。旧实现无任何点击处理
# （2026-09-15 用户报「点击事件也没有做」，漏译补全）。
func _attach_slot_click(slot: TextureRect, icon: ReadheroIcon, inst_id: int) -> void:
	var btn := Button.new()
	btn.theme_type_variation = &"GhostButton"
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.set_meta("inst_id", inst_id)
	btn.button_down.connect(func() -> void: icon.scale = Vector2(0.95, 0.95))
	btn.button_up.connect(func() -> void: icon.scale = Vector2.ONE)
	btn.pressed.connect(_on_team_slot_clicked.bind(inst_id))
	slot.add_child(btn)


func _on_team_slot_clicked(inst_id: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_remove_team_member(inst_id)


func _refresh_gs() -> void:
	var total: int = 0
	for t in _team:
		var hero = player.hero_manager.heroes[t.inst_id]
		total += int(hero.gs)   # 单一来源：养成入口已重算（recalc_hero_gs）
	# 源 gs_title（COMBAT 标题）+ gs（数值）两行（battleprepare.lua:2252-2279），拆成两个 Label。
	if _gs_title_label != null:
		_gs_title_label.text = String(cm.get_lstr(LSTR_COMBAT))
	_gs_label.text = str(total)


func _tab_label(tab: String) -> String:
	match tab:
		TAB_FRONT: return cm.get_lstr(LSTR_TAB_FRONT)
		TAB_MIDDLE: return cm.get_lstr(LSTR_TAB_MIDDLE)
		TAB_BACK: return cm.get_lstr(LSTR_TAB_BACK)
		_: return cm.get_lstr(LSTR_TAB_ALL)


func _on_tab_pressed(tab: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_current_tab = tab
	_update_tab_visual()
	_refresh_list()


func _load_default_team() -> void:
	var loaded: Array[int] = []
	if not _initial_tids.is_empty():
		# 外部初始阵容（源 getLastTeam：defend/excavateChange 用 create 传入阵容反查加载）
		for tid in _initial_tids:
			var hero: HeroInstance = player.hero_manager.find_hero_by_tid(int(tid))
			if hero != null:
				loaded.append(int(hero.inst_id))
	else:
		for inst_id in player.team:
			if player.hero_manager.heroes.has(int(inst_id)):
				loaded.append(int(inst_id))
		if loaded.is_empty():
			var count := 0
			for inst_id in player.hero_manager.heroes:
				loaded.append(int(inst_id)); count += 1
				if count >= TEAM_MAX: break
	for inst_id in loaded:
		if _team.size() < TEAM_MAX:
			var h_dict = _heroes_all.filter(func(x): return x.inst_id == inst_id)
			if h_dict.size() > 0:
				_order_team(h_dict[0])
	_refresh_list(); _refresh_team_display(); _refresh_gs()


func _on_back_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	queue_free()


# 确认开战：crusade 走 CrusadeBattle.assemble 装配 engine → battle_context(mode=crusade) →
# 切 battle_scene 观战（源 doCrusade→gotoBattle enterCrusade+replaceScene）；stage 分支照旧。
func _on_go_pressed() -> void:
	AudioPlayer.play_sfx("battle_begin")
	if _team.size() < TEAM_MAX:
		pass  # 照源允许不足 5 人开战（确认框降级跳过）
	var tids: Array[int] = []
	for t in _team:
		tids.append(int(t.tid))
	if tids.is_empty():
		Toast.show_message(cm.get_lstr(LSTR_NOTENOUGH))
		return
	if mode == "crusade":
		_go_crusade_battle(tids)
		return
	if _on_confirm_cb.is_valid():
		# 确认回调模式（源 requestBattle :569-586 各模式分发；pvp defend→set_lineup /
		# excavateChange→set_excavate_team / attack 系→发战斗）：View 调用方自带装配与写防守，
		# 面板只关自己（源 popScene）。不写回 player.team（源写回集合=stage/dungeon→td_cm +
		# pvp attack→td_pp；本项目单字段下 attack 不写回防污染关卡阵容，受控偏离记录于验收）。
		var cb := _on_confirm_cb
		queue_free()
		cb.call(tids)
		return
	_persist_team()
	var asm_r: Dictionary = mgr.assemble_stage_battle(stage_id, player, tids, rng)
	if not bool(asm_r.get("ok", false)):
		Toast.show_message(_assemble_error_text(String(asm_r.get("error", ""))))
		return
	GameData.battle_context = {
		"engine": asm_r["engine"], "battle_info": asm_r["battle_info"],
		"loots": asm_r["loots"], "stage_id": stage_id, "player_tids": tids, "mgr": mgr,
	}
	queue_free()
	SceneManager.change_scene(BATTLE_SCENE_PATH)


# 装配失败分码文案（自 dungeon_map_panel._enter_error_text 收编：dungeon 出击改走本面板
# stage 分支装配后，错误反馈责任随装配点归面板，stage 路径静默失败同步获得反馈）。
func _assemble_error_text(err: String) -> String:
	match err:
		"no_attempts":
			return "今日次数已用完"
		"not_enough_keys":
			return "钥匙不足"
		"not_enough_coins":
			return "龙鳞硬币不足，无法购买次数"
		"heroic_prereq":
			return "需先通关对应普通副本"
		"level_lock":
			return "等级不足"
		"no_vitality":
			return "体力不足"
	return "装配失败"


# 确认开战时写回阵容记忆。源 battleprepare.lua doGo :336-344 setTeamData(teamData) →
# readconfig.lua CCUserDefault 按 stageType 分 key（td_cm 等）持久化，下次进布阵 getTeamData
# 默认加载。本项目单机化收敛为 player.team 单字段（读点：_load_default_team/stage_detail/
# dungeon_map/ladder/excavate/存档快照），跨会话随结算 GameData.save() 落盘。
# 漏译后果：换人只改面板 _team，下一关 _load_default_team 再读 player.team 旧值 → 阵容回退
# （2026-09-15 用户报「下了宙斯换小鹿，选下一关小鹿变回宙斯」）。crusade 分支照源 doGoCrusade
# （:394-404 无 setTeamData）不写回——远征限 20 级阵容不污染关卡阵容记忆。
func _persist_team() -> void:
	player.team.clear()
	for t in _team:
		player.team.append(int(t.inst_id))


# 装配远征战斗切场景（照源 crusade.start 负数 stage_id 直传；空队/装配失败仅 Toast 反馈不切场景）。
func _go_crusade_battle(tids: Array[int]) -> void:
	var asm_c: Dictionary = CrusadeBattle.assemble_crusade_battle(mgr, stage_id, player, tids, rng)
	if not bool(asm_c.get("ok", false)):
		Toast.show_message(cm.get_lstr(LSTR_NOTENOUGH))
		return
	GameData.battle_context = {
		"mode": "crusade", "engine": asm_c["engine"], "battle_info": asm_c["battle_info"],
		"stage_id": stage_id, "player_tids": tids, "mgr": mgr,
	}
	queue_free()
	SceneManager.change_scene(BATTLE_SCENE_PATH)


