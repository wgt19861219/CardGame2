class_name BattlePreparePanel
extends Control

## 战前布阵面板（View 层）— 照源 battleprepare.lua 核心单机段翻译。
## 选英雄（按 position 分类 tab all/front/middle/back）+ 上阵/下阵 + maxRange 自动排序 +
## gs 显示 + 开始战斗。单机化裁剪：雇佣兵/PVP 防守/公会倒计时/挖矿改阵。
## 重构（2026-07-17）：UI 静态节点（bg/list_frame/team_bg/5 bucket/4 tab/go/gs label）
## 固化进 battle_prepare_content.tscn（位置/size 编辑器可视化调）。panel instantiate + fill
## 动态数据/样式 + 接业务信号。坐标源 cocos(800×480 左下) → Godot(960×640 左上) via (cx+80, 560-cy)。
##
## mode（源 battleprepare.lua:1746 self.mode = info.mode）：
##   "stage"（默认）= 普通关卡，_on_go_pressed 走 mgr.assemble_stage_battle 进 battle_scene。
##   "crusade"（源 crusade.lua:434-438 start() 传 mode=crusade + heroLimit level=20）=
##     同步跑 mgr.run_crusade_battle + emit crusade_battle_finished（crusade_panel 接回刷新）。

signal crusade_battle_finished(won: bool, stage: int)

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/battle_prepare_content.tscn")
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
var _heroes_all: Array = []      # 全部可选英雄 [{inst_id, tid, pos_type, max_range}]
var _heroes_filtered: Array = [] # 当前 tab 过滤后
var _team: Array = []            # 已上阵 [{inst_id, tid, max_range}]（按 maxRange 降序）
var _current_tab: String = TAB_ALL
var _list_grid: GridContainer = null
var _team_slots: Array[TextureRect] = []  # 5 个槽位底（源 herobucket.png，.tscn %MemberBg1-5）
var _gs_label: Label = null
var _gs_title_label: Label = null  # 战斗力标题（源 gs_title，GsLabel 上方）
var _go_button: Button = null
var _tab_buttons: Dictionary = {}   # tab_key → Button（源 listButton/listButtonSelect 双态切换）
var _tab_labels: Dictionary = {}    # tab_key → Label（独立 Label 子节点，Button.text 内嵌 label 受 stylebox 干扰）
var _prev_identity: String = ""     # 进入前 HUD identity（tree_exited 恢复用）


# p_mode/p_min_level 可选（默认 "stage" + 0 = 不限等级），向后兼容 stage_detail_panel 5 参数调用。
func setup(p_stage_id: int, p_player: Variant, p_mgr: Variant, p_rng: Variant, p_cm: Variant, p_mode: String = "stage", p_min_level: int = 0) -> void:
	stage_id = p_stage_id; player = p_player; mgr = p_mgr; rng = p_rng; cm = p_cm
	mode = p_mode; min_level = p_min_level
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# BattlePreparePanel 是 Control 非 PopWindow，无 PopWindow 的 z_index=100 置顶。
	# 详情面板 _on_go_pressed 在 add_child 后 remove_window 关详情，若不置顶，BattlePreparePanel
	# 会被 z=100 的关卡选择面板盖住（详情是关卡选择的子弹窗），表现为"点 GoButton 回到关卡选择"。
	# z=210 进一步盖住关卡选择章节标题（FrameLayer procedural Label z=201 全局），战前界面应全屏遮底。
	z_index = 210
	z_as_relative = false
	# 战前编队界面源里无 HUD（货币栏/标题），切 battleprepare identity 整体隐藏 HUD；
	# tree_exited（queue_free）时恢复进入前 identity（stageselect/crusade 等）。
	_prev_identity = HudOverlay.get_identity()
	HudOverlay.apply_identity("battleprepare")
	tree_exited.connect(_restore_identity)
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
func _load_hero_list() -> void:
	_heroes_all.clear()
	if player == null or player.hero_manager == null:
		return
	var unit_table: Dictionary = cm.get_raw_table(&"Unit")
	var skill_table: Dictionary = cm.get_raw_table(&"Skill")
	for inst_id in player.hero_manager.heroes:
		var hero = player.hero_manager.heroes[inst_id]
		if mode == "crusade" and int(hero.level) < min_level:
			continue
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
		_heroes_all.append({inst_id = int(inst_id), tid = tid, pos_type = pos_type, max_range = max_range})


func _refresh_list() -> void:
	for c in _list_grid.get_children(): c.queue_free()
	_heroes_filtered = _heroes_all if _current_tab == TAB_ALL else _heroes_all.filter(func(h): return h.pos_type == _current_tab)
	for h in _heroes_filtered:
		var hero = player.hero_manager.heroes[h.inst_id]
		var icon := ReadheroIcon.create_icon_by_hero(hero, cm)
		# 源 gap_x/gap_y=100（hero icon 100×100 排列，battleprepare.lua:1548-1551）。icon 容器 104，
		# 按背景框内部可用区放大 icon 到 112（scale 1.08），填满 ListScroll 宽度。
		icon.scale = Vector2(1.08, 1.08)
		var btn := Button.new(); btn.add_child(icon); btn.custom_minimum_size = Vector2(112, 112)
		btn.set_meta("inst_id", h.inst_id)
		var selected: bool = _team.any(func(t): return t.inst_id == h.inst_id)
		if selected: btn.modulate = Color(0.5, 0.5, 0.5)
		btn.pressed.connect(_on_hero_clicked.bind(h.inst_id))
		_list_grid.add_child(btn)


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
	for i in range(TEAM_MAX):
		var slot: TextureRect = _team_slots[i]
		var halo: CanvasItem = slot.get_node_or_null("Halo") as CanvasItem
		for c in slot.get_children():
			if c is ReadheroIcon:
				c.queue_free()
		var occupied: bool = i < _team.size()
		if occupied:
			var hero = player.hero_manager.heroes[_team[i].inst_id]
			var icon := ReadheroIcon.create_icon_by_hero(hero, cm)
			# ReadheroIcon 是 Node2D，内部子节点从中心 (52,52) 绘制（CONTAINER_SIZE=104）。
			# 居中：icon.position = slot 中心 - icon 视觉中心偏移（52,52），按 slot 实际 size 动态算。
			var slot_center: Vector2 = slot.size * 0.5
			icon.position = slot_center - Vector2(ReadheroIcon.CONTAINER_SIZE.x, ReadheroIcon.CONTAINER_SIZE.y) * 0.5
			slot.add_child(icon)
		if halo != null:
			halo.visible = occupied


func _refresh_gs() -> void:
	var total: int = 0
	for t in _team:
		var hero = player.hero_manager.heroes[t.inst_id]
		total += int(player.hero_manager.calc_gs(hero))
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


# 同步跑（不进 battle_scene，照 crusade_panel 既有实现），emit crusade_battle_finished 给 crusade_panel。
func _on_go_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if _team.size() < TEAM_MAX:
		pass  # 照源允许不足 5 人开战（确认框降级跳过）
	var tids: Array[int] = []
	for t in _team:
		tids.append(int(t.tid))
	if tids.is_empty():
		Toast.show_message(cm.get_lstr(LSTR_NOTENOUGH))
		return
	if mode == "crusade":
		_run_crusade_go(tids)
		return
	var asm_r: Dictionary = mgr.assemble_stage_battle(stage_id, player, tids, rng)
	if not bool(asm_r.get("ok", false)):
		return
	GameData.battle_context = {
		"engine": asm_r["engine"], "battle_info": asm_r["battle_info"],
		"loots": asm_r["loots"], "stage_id": stage_id, "player_tids": tids, "mgr": mgr,
	}
	queue_free()
	SceneManager.change_scene("res://scenes/battle/battle_scene.tscn")


# stage_id 负值，run_crusade_battle 需还原 stage 号（1-15）= -stage_id - 2。同步跑 + emit + queue_free。
func _run_crusade_go(tids: Array[int]) -> void:
	var stage: int = -stage_id - 2
	var r: Dictionary = mgr.run_crusade_battle(stage, player, tids, rng)
	var won: bool = bool(r.get("won", false))
	queue_free()
	crusade_battle_finished.emit(won, stage)


