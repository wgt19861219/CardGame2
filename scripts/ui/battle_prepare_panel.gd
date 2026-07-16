class_name BattlePreparePanel
extends Control

## 战前布阵面板（View 层）— 照源 battleprepare.lua 核心单机段翻译。
## 选英雄（按 position 分类 tab all/front/middle/back）+ 上阵/下阵 + maxRange 自动排序 +
## gs 显示 + 开始战斗。单机化裁剪：雇佣兵/PVP 防守/公会倒计时/挖矿改阵。

const ReadheroIcon = preload("res://scripts/view/battle/readhero_icon.gd")
const TEAM_MAX: int = 5  # 源 :171 addTeamMember 上限校验

const TAB_ALL: String = "all"
const TAB_FRONT: String = "front"
const TAB_MIDDLE: String = "middle"
const TAB_BACK: String = "back"
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"

# ── 文本 LSTR key（源 battleprepare.lua:1870 BATTLEPREPARE.WHOLE / :1915 UNIT.FRONT_ROW /
# :1960 UNIT.MIDDLE_ROW / :2005 UNIT.REAR_ROW / :2256 BATTLEPREPARE.COMBAT 战斗力标题 /
# :2241 CHATCONFIG.CONFIRM 确认开战按钮）──
const LSTR_TAB_ALL: String = "BATTLEPREPARE.WHOLE"
const LSTR_TAB_FRONT: String = "UNIT.FRONT_ROW"
const LSTR_TAB_MIDDLE: String = "UNIT.MIDDLE_ROW"
const LSTR_TAB_BACK: String = "UNIT.REAR_ROW"
const LSTR_COMBAT: String = "BATTLEPREPARE.COMBAT"     # 源 gs_title「战斗力」标题
const LSTR_CONFIRM: String = "CHATCONFIG.CONFIRM"       # 源 conform 开始战斗按钮
const LSTR_NOTENOUGH: String = "BATTLEPREPARE.PLEASE_SELECT_BATTLE_HERO"  # 源 :279 toast
const LSTR_SAME_NAME: String = "BATTLEPREPARE.HEROES_OF_THE_SAME_NAME_CAN_NOT_BE_USED_IN_ONE_FIGHT"  # 源 :743

var stage_id: int = 0
var player: Variant = null
var mgr: Variant = null
var rng: Variant = null
var cm: Variant = null
var _heroes_all: Array = []      # 全部可选英雄 [{inst_id, tid, pos_type, max_range}]
var _heroes_filtered: Array = [] # 当前 tab 过滤后
var _team: Array = []            # 已上阵 [{inst_id, tid, max_range}]（按 maxRange 降序）
var _current_tab: String = TAB_ALL
var _list_grid: GridContainer = null
var _team_slots: Array[TextureRect] = []  # 5 个槽位底（源 herobucket.png）
var _gs_label: Label = null
var _go_button: Button = null


func setup(p_stage_id: int, p_player: Variant, p_mgr: Variant, p_rng: Variant, p_cm: Variant) -> void:
	stage_id = p_stage_id; player = p_player; mgr = p_mgr; rng = p_rng; cm = p_cm
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_hero_list()
	_build_ui()
	_load_default_team()


# 源 getInformation L1697-1721 — 读 player.heroes + Unit 表 Position Type + Skill 表 Max Range 分类。
func _load_hero_list() -> void:
	_heroes_all.clear()
	if player == null or player.hero_manager == null:
		return
	var unit_table: Dictionary = cm.get_raw_table(&"Unit")
	var skill_table: Dictionary = cm.get_raw_table(&"Skill")
	for inst_id in player.hero_manager.heroes:
		var hero = player.hero_manager.heroes[inst_id]
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


func _build_ui() -> void:
	# 背景（源 battleprepare.lua:1797 bg.jpg）
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/alpha/HVGA/bg.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	# 返回按钮
	var back: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, Vector2(20.0, 15.0))  # 左上角留小边（用户偏好更靠左上角）
	back.pressed.connect(_on_back_pressed); add_child(back)
	# 分类 tab（源 :1870-2005 竖排 classbtn，本项目横排简化；标签照源 LSTR）
	var tab_box := HBoxContainer.new(); tab_box.position = Vector2(10, 50); tab_box.size = Vector2(400, 30)
	for tab in [TAB_ALL, TAB_FRONT, TAB_MIDDLE, TAB_BACK]:
		var btn := Button.new(); btn.text = _tab_label(tab); btn.set_meta("tab", tab)
		btn.pressed.connect(_on_tab_pressed.bind(tab))
		tab_box.add_child(btn)
	add_child(tab_box)
	# 英雄列表（ScrollContainer + GridContainer）
	var scroll := ScrollContainer.new(); scroll.position = Vector2(10, 90); scroll.size = Vector2(400, 300)
	_list_grid = GridContainer.new(); _list_grid.columns = 5
	scroll.add_child(_list_grid); add_child(scroll)
	# 队伍底框（源 :2080 heroselected.png）+ 5 槽位（源 :2091 herobucket.png）
	var team_bg := TextureRect.new()
	team_bg.texture = load("res://assets/ui/alpha/HVGA/heroselected.png")
	team_bg.position = Vector2(150, 400); team_bg.size = Vector2(400, 80); add_child(team_bg)
	var bucket_tex := load("res://assets/ui/alpha/HVGA/herobucket.png")
	for i in range(TEAM_MAX):
		var slot := TextureRect.new(); slot.texture = bucket_tex
		slot.position = Vector2(160 + i * 75, 410); slot.size = Vector2(70, 70)
		slot.set_meta("slot_index", i)
		_team_slots.append(slot); add_child(slot)
	# gs Label（源 :2256-2270 gs_title=战斗力 + gs 数字，本项目合并单标签）
	_gs_label = Label.new(); _gs_label.text = "%s: 0" % cm.get_lstr(LSTR_COMBAT); _gs_label.position = Vector2(10, 480); add_child(_gs_label)
	# 开始战斗按钮（源 :2241 conform=确定）
	_go_button = Button.new(); _go_button.text = cm.get_lstr(LSTR_CONFIRM); _go_button.position = Vector2(600, 410); _go_button.size = Vector2(100, 50)
	_go_button.pressed.connect(_on_go_pressed); add_child(_go_button)
	_refresh_list()
	_refresh_team_display()
	_refresh_gs()


func _refresh_list() -> void:
	for c in _list_grid.get_children(): c.queue_free()
	_heroes_filtered = _heroes_all if _current_tab == TAB_ALL else _heroes_all.filter(func(h): return h.pos_type == _current_tab)
	for h in _heroes_filtered:
		var hero = player.hero_manager.heroes[h.inst_id]
		var icon := ReadheroIcon.create_icon_by_hero(hero, cm)
		var btn := Button.new(); btn.add_child(icon); btn.custom_minimum_size = Vector2(64, 64)
		btn.set_meta("inst_id", h.inst_id)
		var selected: bool = _team.any(func(t): return t.inst_id == h.inst_id)
		if selected: btn.modulate = Color(0.5, 0.5, 0.5)
		btn.pressed.connect(_on_hero_clicked.bind(h.inst_id))
		_list_grid.add_child(btn)


# 源 doClickInList L999 — 点击列表英雄→上阵/下阵切换。
func _on_hero_clicked(inst_id: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if _team.any(func(t): return t.inst_id == inst_id):
		_remove_team_member(inst_id)
	else:
		_add_team_member(inst_id)


# 源 addTeamMember L731 — 上阵（校验 ≤5 + 同名禁用）。
func _add_team_member(inst_id: int) -> void:
	if _team.size() >= TEAM_MAX:
		return
	var h: Dictionary = _heroes_all.filter(func(x): return x.inst_id == inst_id)[0]
	if _team.any(func(t): return t.tid == h.tid):
		_show_toast(cm.get_lstr(LSTR_SAME_NAME))   # 源 :743 同名禁用 toast
		return  # 同名英雄禁用
	_order_team(h)  # 按 maxRange 插入正确位置
	_refresh_list(); _refresh_team_display(); _refresh_gs()


# 源 orderTeam L667-729 — 按 maxRange 降序插入（maxRange 大的排后面）。
func _order_team(h: Dictionary) -> void:
	var entry := {inst_id = h.inst_id, tid = h.tid, max_range = h.max_range}
	# 源：maxRange > 队尾→append；maxRange <= 队首→insert(0)；否则找到位置插入
	if _team.size() == 0 or h.max_range > _team[-1].max_range:
		_team.append(entry); return
	if h.max_range <= _team[0].max_range:
		_team.insert(0, entry); return
	for i in range(_team.size() - 1):
		if h.max_range > _team[i].max_range and h.max_range <= _team[i + 1].max_range:
			_team.insert(i + 1, entry); return
	_team.append(entry)  # fallback


# 源 destroyTeamMember L800 — 下阵。
func _remove_team_member(inst_id: int) -> void:
	for i in range(_team.size()):
		if _team[i].inst_id == inst_id:
			_team.remove_at(i); break
	_refresh_list(); _refresh_team_display(); _refresh_gs()


func _refresh_team_display() -> void:
	for i in range(TEAM_MAX):
		var slot: TextureRect = _team_slots[i]
		for c in slot.get_children(): c.queue_free()
		if i < _team.size():
			var hero = player.hero_manager.heroes[_team[i].inst_id]
			var icon := ReadheroIcon.create_icon_by_hero(hero, cm)
			icon.position = Vector2(5, 5)
			slot.add_child(icon)


# 源 refreshgs L154 — 总战斗力。
func _refresh_gs() -> void:
	var total: int = 0
	for t in _team:
		var hero = player.hero_manager.heroes[t.inst_id]
		total += int(player.hero_manager.calc_gs(hero))
	_gs_label.text = "%s: %d" % [cm.get_lstr(LSTR_COMBAT), total]


# 源 tab 标签照源 LSTR（:1870 全部 / :1915 前排 / :1960 中排 / :2005 后排）。
func _tab_label(tab: String) -> String:
	match tab:
		TAB_FRONT: return cm.get_lstr(LSTR_TAB_FRONT)
		TAB_MIDDLE: return cm.get_lstr(LSTR_TAB_MIDDLE)
		TAB_BACK: return cm.get_lstr(LSTR_TAB_BACK)
		_: return cm.get_lstr(LSTR_TAB_ALL)


func _on_tab_pressed(tab: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_current_tab = tab; _refresh_list()


# 源 loadTeam L1467 — 读上次阵容自动上阵。
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


# 源 doClickBack L1239 — 返回。
func _on_back_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	queue_free()


# 源 doGo → requestBattle → doGo L306 — 读阵容→assemble_stage_battle→进 battle_scene。
func _on_go_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if _team.size() < TEAM_MAX:
		# 源 lackHeroConfirm L444 — 不足 5 人确认（降级 OS.confirm 非阻塞式，单机直接继续）
		pass  # 照源允许不足 5 人开战（确认框降级跳过）
	var tids: Array[int] = []
	for t in _team:
		tids.append(int(t.tid))
	if tids.is_empty():
		_show_toast(cm.get_lstr(LSTR_NOTENOUGH))   # 源 :279 请选择出战英雄
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


func _show_toast(text: String) -> void:
	if Engine.is_editor_hint():
		return
	var toast_node: Node = Engine.get_main_loop().root.get_node_or_null("/root/Toast")
	if toast_node != null and toast_node.has_method("show_text"):
		toast_node.show_text(text)
