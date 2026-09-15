class_name ExcavateTeamPanel
extends PopWindow

## 矿点驻防选队弹窗（View 层）— 照源 ui/popwindow/excavateteam.lua（554 行）
## + uieditor/excavateteam.lua（813 行声明表，excavate 批 Task 6 两件套改造）。
## mine 矿点：玩家名 + 驻防英雄 5 静态槽 + 换队/撤退 + 产量行（累计/速度）。
## monster 矿点：野怪名 + 敌英雄槽 + 出战（框体矮化，源 :528-531）。
## 单机受控裁剪（源无对应数据/流程，验收记录留档）：guild 组（联机公会）、
## vitality 组（单机战斗不扣体力）、go_battle disabled 分支（战败即 occupy 转
## mine，敌队恒满血）、head/level 徽章 fill（getTeamHead/getLevelIcon 基础设施
## 缺失，容器照源建位）、battleprepare 换队 View（单机 = 当前阵容一键驻防）。
## 英雄槽为源声明表静态 hero_container_1..5（非动态行），fill 塞 ReadheroIcon。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_team_content.tscn")

const OWNER_MINE: String = "mine"
const HERO_SLOT_COUNT: int = 5
# icon 缩放 = 源 enemy createIcon length 80 / ReadheroIcon 容器 104（mine/enemy 统一口径）
const ICON_SCALE: float = 0.77
# monster 框体矮化（源 :530-531 DG 前缀像素÷1.28125）：frame 高 265→206.87、容器下移 35→27.34
const FRAME_MONSTER_SIZE: Vector2 = Vector2(632.81, 206.87)
const FRAME_CONTAINER_MONSTER_DROP: float = 27.34
# 分钟→小时换算 + 速度行拼接口径（源 :467-476 unitTime=60、pstr "%d/%d"）
const MINUTES_PER_HOUR: float = 60.0
const SPEED_HOUR_SUFFIX_BASE: String = "/1"
# LSTR keys（fallback 单机兜底）
const LSTR_CHANGE_TEAM_KEY: String = "EXCAVATETEAM.ADJUST_FORMATION"
const CHANGE_TEAM_FALLBACK: String = "调整阵容"
const LSTR_GIVEUP_KEY: String = "excavateteam.1.10.1.002"
const GIVEUP_FALLBACK: String = "撤退"
const LSTR_LACK_TITLE_KEY: String = "EXCAVATETEAM.CUMULATIVE_PRODUCTION_RESOURCES_"
const LSTR_SPEED_TITLE_KEY: String = "EXCAVATEMAP.PRODUCTION_SPEED_"
const LSTR_HOUR_KEY: String = "TIME.HOUR"
const HOUR_FALLBACK: String = "小时"
const TEAM_SET_TEXT: String = "已用当前阵容驻防"   # 单机 Toast（无 LSTR）
const NO_DEFEND_TEXT: String = "尚未驻防，点击「调整阵容」派英雄驻守"   # 单机空态兜底（源无空态）
const NO_ENEMY_TEXT: String = "无敌人数据"   # 单机兜底（源 monster 必有队）
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const PRODUCE_KINDS: Array[String] = ["Gold", "Diamond", "Exp"]
const PRODUCE_ROW_PREFIXES: Array[String] = ["Lack", "Speed"]
# 表 Produce Type 值（首字母大写）→ icon 后缀（源 :441-457 exp 组={7,8,9}，
# 表值为 Item=经验药水产出，图标用 excavate_exp_icon）
const PRODUCE_TYPE_TO_KIND: Dictionary = {"Gold": "Gold", "Diamond": "Diamond", "Item": "Exp"}

var pd: PlayerData
var rng: BattleRng
var _excavate_id: int
var _on_closed: Callable


func setup_panel(p_pd: PlayerData, excavate_id: int, p_rng: BattleRng, on_closed: Callable) -> void:
	pd = p_pd
	rng = p_rng
	_excavate_id = excavate_id
	_on_closed = on_closed
	setup()
	_fill()


# fill：实例化静态 content + 按矿点 owner 分支填数据/切可见性/绑信号。
# 静态结构（框/槽/按钮/产量行）全在 excavate_team_content.tscn。
func _fill() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	var is_mine: bool = _owner() == OWNER_MINE
	_fill_name(content)
	_fill_buttons(content, is_mine)
	_fill_produce(content, is_mine)
	_fill_hero_slots(content)


# 玩家名 fill（源 :276-277 setLabelString(name, player._name)；mine=玩家名，
# monster=ExcavateWildEnemy 表 Player Name（LSTR key），源 :325-327）。
func _fill_name(content: Control) -> void:
	var label: Label = content.get_node("%NameLabel") as Label
	if _owner() == OWNER_MINE:
		label.text = pd.player_name
		return
	var wild: Dictionary = ExcavateData.get_wild_enemy(pd.cm, _wild_id())
	label.text = _lstr(String(wild.get("Player Name", "")), NO_ENEMY_TEXT)


# 按钮组 fill（源 initMineTeam:109-137 / initEnemyTeam:174-175）：
# mine → cg 组（换队/撤退）可见 + 出战隐藏；monster 反之 + 框体矮化（:528-531）。
func _fill_buttons(content: Control, is_mine: bool) -> void:
	(content.get_node("Frame/FrameContainer/CgButtonContainer") as Control).visible = is_mine
	var battle_btn: TextureButton = content.get_node("%BattleBtn") as TextureButton
	battle_btn.visible = not is_mine
	battle_btn.pressed.connect(_on_battle)
	var change_btn: Button = content.get_node("%ChangeBtn") as Button
	change_btn.text = _lstr(LSTR_CHANGE_TEAM_KEY, CHANGE_TEAM_FALLBACK)
	change_btn.pressed.connect(_on_change_team)
	var giveup_btn: Button = content.get_node("%GiveupBtn") as Button
	giveup_btn.text = _lstr(LSTR_GIVEUP_KEY, GIVEUP_FALLBACK)
	giveup_btn.pressed.connect(_on_giveup)
	if is_mine:
		return
	# monster：frame 保持中心改高 206.87 + frame_container 下移 27.34（源 :530-531）
	var frame: Control = content.get_node("Frame") as Control
	var center: Vector2 = frame.get_rect().get_center()
	frame.size = FRAME_MONSTER_SIZE
	frame.position = center - frame.size / 2.0
	var fc: Control = content.get_node("Frame/FrameContainer") as Control
	fc.position.y += FRAME_CONTAINER_MONSTER_DROP


# 产量行 fill（源 :504-508 mine 分支 + refreshBaseRecord:435-477）：
# 容器 mine 可见/monster 隐藏；icon 按 produce_type 三选一（源 :441-465
# type_id_group 等价映射）；数值 = 累计产出 produce_amount / 每小时产速。
func _fill_produce(content: Control, is_mine: bool) -> void:
	var explain: Control = content.get_node("%ExplainContainer") as Control
	explain.visible = is_mine
	if not is_mine:
		return
	var d: Dictionary = pd.excavate.get_data(_excavate_id)
	var active_kind: String = String(PRODUCE_TYPE_TO_KIND.get(ExcavateData.produce_type(pd.cm, int(d["_type_id"])), ""))
	for prefix: String in PRODUCE_ROW_PREFIXES:
		var ctn: Control = explain.get_node(prefix + "LabelContainer") as Control
		for kind: String in PRODUCE_KINDS:
			(ctn.get_node("%sIcon%s" % [prefix, kind]) as Control).visible = kind == active_kind
	var lack_ctn: Control = explain.get_node("LackLabelContainer") as Control
	(lack_ctn.get_node("%LackTitle") as Label).text = _lstr(LSTR_LACK_TITLE_KEY, LSTR_LACK_TITLE_KEY)
	var now: int = int(Time.get_unix_time_from_system())
	(lack_ctn.get_node("%LackNumber") as Label).text = "x%d" % pd.excavate.produce_amount(_excavate_id, now)
	var speed_ctn: Control = explain.get_node("SpeedLabelContainer") as Control
	(speed_ctn.get_node("%SpeedTitle") as Label).text = _lstr(LSTR_SPEED_TITLE_KEY, LSTR_SPEED_TITLE_KEY)
	# 源 :469-476：speed×60（每小时），整数档 "%d/1" 小数档 "%.1f/1" + TIME.HOUR
	var per_hour: float = float(d["_produce_speed"]) * MINUTES_PER_HOUR
	var num: String = ("%.1f" % per_hour) if fmod(per_hour, 1.0) > 0.0 else str(int(per_hour))
	(speed_ctn.get_node("%SpeedNumber") as Label).text = "x" + num + SPEED_HOUR_SUFFIX_BASE + _lstr(LSTR_HOUR_KEY, HOUR_FALLBACK)


# 英雄槽 fill（源 initMineTeam:83-108 / initEnemyTeam:141-169：清槽 → 逐个
# createIcon 塞 hero_container_i）。空态走单机自创 EmptyHint（源空队直接进
# 换队流程 :405-408，单机换队不跳场景）。
func _fill_hero_slots(content: Control) -> void:
	var infos: Array = []
	if _owner() == OWNER_MINE:
		for tid: Variant in pd.excavate.get_defend_team(_excavate_id):
			infos.append(_hero_info(int(tid)))
	else:
		for e: Variant in pd.excavate.get_enemy_heroes(_excavate_id):
			var base: Dictionary = e["base"]
			infos.append({
				"id": int(base.get("_tid", 0)),
				"rank": int(base.get("_rank", 1)),
				"stars": int(base.get("_stars", 0)),
				"level": int(base.get("_level", 1)),
			})
	var hint: Label = content.get_node("%EmptyHint") as Label
	hint.visible = infos.is_empty()
	if infos.is_empty():
		hint.text = NO_DEFEND_TEXT if _owner() == OWNER_MINE else NO_ENEMY_TEXT
	var count: int = mini(infos.size(), HERO_SLOT_COUNT)
	var i: int = 0
	while i < HERO_SLOT_COUNT:
		var slot: Control = content.get_node("Frame/FrameContainer/HeroSlot%d" % (i + 1)) as Control
		for c in slot.get_children():
			c.free()
		if i < count:
			var icon := ReadheroIcon.new()
			icon.setup(infos[i], pd.cm)
			icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
			slot.add_child(icon)
		i += 1


func _owner() -> String:
	return String(pd.excavate.get_data(_excavate_id).get("_owner", ""))


func _wild_id() -> int:
	return int(pd.excavate.get_data(_excavate_id).get("_wild_id", 0))


func _lstr(key: String, fallback: String) -> String:
	if pd.cm != null:
		return pd.cm.get_lstr(key)
	return fallback


# 换队（照源 :113-122 change_team → enterExcavateChange（excavateteam.lua:10-45）→ battleprepare
# mode=excavateChange 弹布阵：初始队=当前驻防队，确认 set_excavate_team+excavateCallback+popScene）。
# 旧「一键 player.team 驻防」系单机化裁剪（注释自述），2026-09-15 照源补全选人。
func _on_change_team() -> void:
	var current: Array[int] = []
	for tid in pd.excavate.get_defend_team(_excavate_id):
		current.append(int(tid))
	var panel := BattlePreparePanel.new()
	panel.setup(0, pd, null, rng, pd.cm, "excavate_change", 0, current,
		func(tids: Array[int]) -> void:
			var now: int = int(Time.get_unix_time_from_system())
			pd.excavate.set_defend_team(_excavate_id, tids, now)
			Toast.show_message(TEAM_SET_TEXT)
			var content: Control = container.get_node("ExcavateTeamContent") as Control
			if content != null:
				_fill_hero_slots(content)
	)
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(panel)


func _on_giveup() -> void:
	var panel := ExcavateGiveupPanel.new("excavate_giveup", {})
	panel.setup_panel(pd, _excavate_id, _on_giveup_confirmed)
	panel.show_window(get_parent())


func _on_giveup_confirmed(_amount: int) -> void:
	if _on_closed.is_valid():
		_on_closed.call()
	remove_window()


# 开战打怪（照源 :212-229 go_battle → battleprepare mode=excavateAttack 弹布阵确认后
# doExcavateAttack 发 excavate_start_battle；旧直接 player.team 开战系选人界面裁剪，照源补全。
# 源 excavateTeam 会话记忆本项目 player.team 单字段下不写回，受控偏离同 pvp attack）。
func _on_battle() -> void:
	# View 接入：装配 engine（不跑循环）→ 存 battle_context mode=excavate → 切 battle_scene
	# （照 stage_select_panel._on_stage_n 范式）。战斗结束 battle_scene._finalize 加 excavate 分支
	# → 回 main_scene 重弹 ExcavateMapPanel + Toast 胜负。
	var panel := BattlePreparePanel.new()
	panel.setup(0, pd, null, rng, pd.cm, "excavate_attack", 0, [],
		func(tids: Array[int]) -> void:
			var asm_r: Dictionary = ExcavateBattle.assemble_excavate_battle(pd.excavate, _excavate_id, pd, rng, tids)
			if not bool(asm_r.get("ok", false)):
				return
			GameData.battle_context = {
				"mode": "excavate", "engine": asm_r["engine"], "battle_info": asm_r["battle_info"],
				"excavate_id": _excavate_id, "hero_list": asm_r["hero_list"], "enemy_list": asm_r["enemy_list"],
				"mgr": pd.excavate,
			}
			remove_window()
			SceneManager.change_scene(BATTLE_SCENE_PATH)
	)
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(panel)


# tid → 头像 info（rank/stars/level 从 HeroInstance 查；无则默认，照 readhero.createIcon info 结构）。
func _hero_info(tid: int) -> Dictionary:
	for inst_id in pd.hero_manager.heroes:
		var h: Variant = pd.hero_manager.heroes[inst_id]
		if int(h.tid) == tid:
			return {"id": int(h.tid), "rank": int(h.rank), "stars": int(h.stars), "level": int(h.level)}
	return {"id": tid, "rank": 1, "stars": 1, "level": 1}
