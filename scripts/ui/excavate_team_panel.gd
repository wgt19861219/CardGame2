class_name ExcavateTeamPanel
extends PopWindow

const UiScale9Button := preload("res://scripts/ui/ui_scale9_button.gd")

## 挖掘队伍面板（View 层）— 照源 ui/popwindow/excavateteam.lua。
## mine 矿点：显示驻防英雄 + 换队（玩家阵容）+ 放弃（ExcavateGiveupPanel）。
## monster 矿点：显示敌人英雄 + 出战（ExcavateBattle.run_excavate_battle headless）。
## 单机简化：源 battleprepare/excavateChange/Attack View 战斗 → headless；雇佣兵/联机验证/others 裁剪。
## 英雄头像 ReadheroIcon 接入留视觉完善（阶段 2b），当前 Label 显示 tid/level。
##
## 重构（2026-07-18，hero_detail 范式）：panel 层静态节点（frame/close/title/hero_box/
## change/giveup/battle button）固化进 excavate_team_content.tscn；运行时按 owner 切按钮 visible
## （源 :504-535 按 owner 切 cg_button_container/go_battle_button 可见性）。英雄列表（ReadheroIcon）
## 保留 procedural 挂 %HeroBox（数量动态）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_team_content.tscn")
const TITLE_MINE: String = "驻防队伍"
const TITLE_MONSTER: String = "敌方守卫"
const LSTR_CHANGE_TEAM_KEY: String = "EXCAVATETEAM.ADJUST_FORMATION"
const CHANGE_TEAM_FALLBACK: String = "调整阵容"
const GIVEUP_TEXT: String = "撤退"
const BATTLE_TEXT: String = "出战"
# ── Scale9 button 样式（.tscn 普通 Button 套 StyleBoxTexture）──
const CHANGE_BTN_RES: String = "res://assets/ui/alpha/HVGA/task_button.png"
const CHANGE_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/task_button_press.png"
const CHANGE_BTN_CAP: Rect2 = Rect2(15.63, 15.63, 19.53, 15.63)
const GIVEUP_BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const GIVEUP_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const GIVEUP_BTN_CAP: Rect2 = Rect2(15.63, 15.63, 19.53, 15.63)
const NO_DEFEND_TEXT: String = "尚未驻防，点击「换队」派英雄驻守"   # 单机兜底
const NO_ENEMY_TEXT: String = "无敌人数据"   # 单机兜底
const FONT_BODY: int = 16
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const TEAM_SET_TEXT: String = "已用当前阵容驻防"   # 单机 Toast（无 LSTR）
const OWNER_MINE: String = "mine"
const ICON_SCALE: float = 0.77

var pd: PlayerData
var rng: BattleRng
var _excavate_id: int
var _on_closed: Callable
var _hero_box: HBoxContainer
var _change_btn: Button
var _giveup_btn: Button
var _battle_btn: TextureButton


func setup_panel(p_pd: PlayerData, excavate_id: int, p_rng: BattleRng, on_closed: Callable) -> void:
	pd = p_pd
	rng = p_rng
	_excavate_id = excavate_id
	_on_closed = on_closed
	setup()
	_build_ui()


# 建 UI：preload .tscn instantiate + fill 动态数据 + 按 owner 切按钮 visible + 绑信号。
# 位置/size 静态节点（frame/close/title/hero_box/change/giveup/battle）已在 .tscn 固化。
func _build_ui() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	var owner: String = String(pd.excavate.get_data(_excavate_id).get("_owner", ""))
	# 标题 fill 一次（源 :376 setLabelString(name, player._name)，单机用 mine/monster 兜底）
	var title_node: Label = content.get_node("%Title") as Label
	title_node.text = TITLE_MINE if owner == OWNER_MINE else TITLE_MONSTER
	_hero_box = content.get_node("%HeroBox") as HBoxContainer
	# 三按钮（.tscn ChangeBtn/GiveupBtn Button + 独立 Label，BattleBtn TextureButton 整图无文本）
	_change_btn = content.get_node("%ChangeBtn") as Button
	_giveup_btn = content.get_node("%GiveupBtn") as Button
	_battle_btn = content.get_node("%BattleBtn") as TextureButton
	# ChangeBtn/GiveupBtn 套 Scale9 stylebox（视觉等价源 DGButton task_button/sell_number_button）。
	_apply_change_btn_style(_change_btn)
	_apply_giveup_btn_style(_giveup_btn)
	# fill 独立 Label（Button.text 内嵌 label 受 stylebox content_margin 干扰字偏左上，范式同 hero_detail）
	_change_btn.text = ""
	_giveup_btn.text = ""
	(content.get_node("%ChangeLabel") as Label).text = _lstr(LSTR_CHANGE_TEAM_KEY, CHANGE_TEAM_FALLBACK)
	(content.get_node("%GiveupLabel") as Label).text = GIVEUP_TEXT
	_change_btn.pressed.connect(_on_change_team)
	_giveup_btn.pressed.connect(_on_giveup)
	_battle_btn.pressed.connect(_on_battle)
	# 按 owner 切按钮可见（源 :504-535 data._owner=="mine" 时 explain/cg_button shown，
	# go_battle hidden；非 mine 反过来。单机裁 vitality/guild/explain，保留 change/giveup vs battle 切换）
	var is_mine: bool = owner == OWNER_MINE
	_change_btn.visible = is_mine
	_giveup_btn.visible = is_mine
	_battle_btn.visible = not is_mine
	_refresh_hero_list()


func _refresh_hero_list() -> void:
	for c in _hero_box.get_children():
		c.free()
	var owner: String = String(pd.excavate.get_data(_excavate_id).get("_owner", ""))
	if owner == OWNER_MINE:
		var team: Array = pd.excavate.get_defend_team(_excavate_id)
		if team.is_empty():
			_add_hint_label(NO_DEFEND_TEXT)
		else:
			for tid in team:
				_add_hero_icon(_hero_info(int(tid)))
	else:
		var enemies: Array = pd.excavate.get_enemy_heroes(_excavate_id)
		if enemies.is_empty():
			_add_hint_label(NO_ENEMY_TEXT)
			return
		for e in enemies:
			var base: Dictionary = e["base"]
			_add_hero_icon({
				"id": int(base.get("_tid", 0)),
				"rank": int(base.get("_rank", 1)),
				"stars": int(base.get("_stars", 0)),
				"level": int(base.get("_level", 1)),
			})


func _add_hint_label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font", FONT_BODY)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_box.add_child(l)


# 英雄头像（源 excavateteam:159 readhero.createIcon，HBox 内 Control 包装 + ReadheroIcon scale）。
func _add_hero_icon(info: Dictionary) -> void:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(ReadheroIcon.CONTAINER_SIZE.x * ICON_SCALE, ReadheroIcon.CONTAINER_SIZE.y * ICON_SCALE)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ReadheroIcon.new()
	icon.setup(info, pd.cm)
	icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
	wrapper.add_child(icon)
	_hero_box.add_child(wrapper)


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# ChangeBtn 双态：normal/hover=task_button，pressed=task_button_press（源 :733-760）。
func _apply_change_btn_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", UiScale9Button._make_sb(CHANGE_BTN_RES, CHANGE_BTN_CAP))
	btn.add_theme_stylebox_override("hover", UiScale9Button._make_sb(CHANGE_BTN_RES, CHANGE_BTN_CAP))
	btn.add_theme_stylebox_override("pressed", UiScale9Button._make_sb(CHANGE_BTN_PRESS_RES, CHANGE_BTN_CAP))


# GiveupBtn 双态：normal/hover=sell_number_button，pressed=sell_number_button_down（源 :761-788）。
func _apply_giveup_btn_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", UiScale9Button._make_sb(GIVEUP_BTN_RES, GIVEUP_BTN_CAP))
	btn.add_theme_stylebox_override("hover", UiScale9Button._make_sb(GIVEUP_BTN_RES, GIVEUP_BTN_CAP))
	btn.add_theme_stylebox_override("pressed", UiScale9Button._make_sb(GIVEUP_BTN_PRESS_RES, GIVEUP_BTN_CAP))


func _on_change_team() -> void:
	var tids: Array[int] = []
	for inst_id in pd.team:
		var hero = pd.hero_manager.heroes.get(inst_id)
		if hero != null:
			tids.append(int(hero.tid))
	var now: int = int(Time.get_unix_time_from_system())
	pd.excavate.set_defend_team(_excavate_id, tids, now)
	Toast.show_message(TEAM_SET_TEXT)
	_refresh_hero_list()


func _on_giveup() -> void:
	var panel := ExcavateGiveupPanel.new("excavate_giveup", {})
	panel.setup_panel(pd, _excavate_id, _on_giveup_confirmed)
	panel.show_window(get_parent())


func _on_giveup_confirmed(_amount: int) -> void:
	if _on_closed.is_valid():
		_on_closed.call()
	remove_window()


func _on_battle() -> void:
	# 阶段 2b View 接入：装配 engine（不跑循环）→ 存 battle_context mode=excavate → 切 battle_scene
	# （照 stage_select_panel._on_stage_n 范式）。战斗结束 battle_scene._finalize 加 excavate 分支
	# → 回 main_scene 重弹 ExcavateMapPanel + Toast 胜负（替代旧 headless 同步 Toast）。
	var asm_r: Dictionary = ExcavateBattle.assemble_excavate_battle(pd.excavate, _excavate_id, pd, rng)
	if not bool(asm_r.get("ok", false)):
		return
	GameData.battle_context = {
		"mode": "excavate", "engine": asm_r["engine"], "battle_info": asm_r["battle_info"],
		"excavate_id": _excavate_id, "hero_list": asm_r["hero_list"], "enemy_list": asm_r["enemy_list"],
		"mgr": pd.excavate,
	}
	remove_window()
	SceneManager.change_scene(BATTLE_SCENE_PATH)


# tid → 头像 info（rank/stars/level 从 HeroInstance 查；无则默认 1，照 readhero.createIcon info 结构）。
func _hero_info(tid: int) -> Dictionary:
	for inst_id in pd.hero_manager.heroes:
		var h = pd.hero_manager.heroes[inst_id]
		if int(h.tid) == tid:
			return {"id": int(h.tid), "rank": int(h.rank), "stars": int(h.stars), "level": int(h.level)}
	return {"id": tid, "rank": 1, "stars": 1, "level": 1}
