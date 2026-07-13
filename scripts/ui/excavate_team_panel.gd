class_name ExcavateTeamPanel
extends PopWindow

## 挖掘队伍面板（View 层）— 照源 ui/popwindow/excavateteam.lua。
## mine 矿点：显示驻防英雄 + 换队（玩家阵容）+ 放弃（ExcavateGiveupPanel）。
## monster 矿点：显示敌人英雄 + 出战（ExcavateBattle.run_excavate_battle headless）。
## 单机简化：源 battleprepare/excavateChange/Attack View 战斗 → headless；雇佣兵/联机验证/others 裁剪。
## 英雄头像 ReadheroIcon 接入留视觉完善（阶段 2b），当前 Label 显示 tid/level。

const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png"
const CLOSE_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_P_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const FRAME_W: float = 560.0
const FRAME_H: float = 360.0
const FONT_TITLE: int = 22
const FONT_BODY: int = 16
const TITLE_MINE: String = "驻防队伍"
const TITLE_MONSTER: String = "敌方守卫"
const CHANGE_TEAM_TEXT: String = "换队（用当前阵容）"
const GIVEUP_TEXT: String = "放弃矿点"
const BATTLE_TEXT: String = "出战"
const NO_DEFEND_TEXT: String = "尚未驻防，点击「换队」派英雄驻守"
const NO_ENEMY_TEXT: String = "无敌人数据"
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const TEAM_SET_TEXT: String = "已用当前阵容驻防"
const OWNER_MINE: String = "mine"
const ICON_SCALE: float = 0.77   # 源 length=80 / CONTAINER_SIZE 104 ≈ 0.77（excavateteam:165 createIcon length=80）

var pd: PlayerData
var rng: BattleRng
var _excavate_id: int
var _on_closed: Callable
var _hero_box: HBoxContainer


func setup_panel(p_pd: PlayerData, excavate_id: int, p_rng: BattleRng, on_closed: Callable) -> void:
	pd = p_pd
	rng = p_rng
	_excavate_id = excavate_id
	_on_closed = on_closed
	setup()
	_build_ui()


func _build_ui() -> void:
	var frame := TextureRect.new()
	frame.texture = load(FRAME_TEX)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	frame.size = Vector2(FRAME_W, FRAME_H)
	frame.position = Vector2(960.0 * 0.5 - FRAME_W * 0.5, 640.0 * 0.5 - FRAME_H * 0.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	_add_close(frame)
	_add_title(frame)
	_add_hero_list(frame)
	_add_action_buttons(frame)


func _add_close(frame: TextureRect) -> void:
	var close := TextureButton.new()
	close.texture_normal = load(CLOSE_TEX)
	close.texture_pressed = load(CLOSE_P_TEX)
	close.ignore_texture_size = true
	close.size = Vector2(40, 40)
	close.position = Vector2(frame.size.x - 50, 12)
	close.pressed.connect(remove_window)
	frame.add_child(close)


func _add_title(frame: TextureRect) -> void:
	var owner: String = String(pd.excavate.get_data(_excavate_id).get("_owner", ""))
	var title := Label.new()
	title.text = TITLE_MINE if owner == OWNER_MINE else TITLE_MONSTER
	title.position = Vector2(0, 15)
	title.size = Vector2(frame.size.x, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font", FONT_TITLE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title)


func _add_hero_list(frame: TextureRect) -> void:
	_hero_box = HBoxContainer.new()
	_hero_box.position = Vector2(40, 75)
	_hero_box.size = Vector2(frame.size.x - 80, 120)
	_hero_box.add_theme_constant_override("separation", 6)
	frame.add_child(_hero_box)
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


func _add_action_buttons(frame: TextureRect) -> void:
	var owner: String = String(pd.excavate.get_data(_excavate_id).get("_owner", ""))
	if owner == OWNER_MINE:
		var change := Button.new()
		change.text = CHANGE_TEAM_TEXT
		change.size = Vector2(180, 40)
		change.position = Vector2(60, frame.size.y - 55)
		change.pressed.connect(_on_change_team)
		frame.add_child(change)
		var giveup := Button.new()
		giveup.text = GIVEUP_TEXT
		giveup.size = Vector2(140, 40)
		giveup.position = Vector2(frame.size.x - 200, frame.size.y - 55)
		giveup.pressed.connect(_on_giveup)
		frame.add_child(giveup)
	else:
		var battle := Button.new()
		battle.text = BATTLE_TEXT
		battle.size = Vector2(200, 44)
		battle.position = Vector2(frame.size.x * 0.5 - 100, frame.size.y - 60)
		battle.pressed.connect(_on_battle)
		frame.add_child(battle)


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
