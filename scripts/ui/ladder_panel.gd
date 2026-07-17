class_name LadderPanel
extends PopWindow

## 天梯/PVP 面板（View 层）— 照源 ladder handler + ui/pvp.lua 3 panel layer。
## 4 tab：挑战（rank/gs/3 对手/购买/刷新）+ 排行榜（20 NPC）+ 战斗记录 + 防守阵容。
## 后端 LadderManager 全命令就绪（_open_panel/_query_rankboard/_query_records/_set_lineup）。

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const CLOSE_POS: Vector2 = Vector2(880.0, 20.0)
const TITLE_POS: Vector2 = Vector2(350.0, 20.0)
const TAB_POS: Vector2 = Vector2(80.0, 50.0)
const TAB_W: float = 120.0
const CONTENT_POS: Vector2 = Vector2(80.0, 90.0)
const ROW_H: float = 40.0
const BUY_OFFSET: Vector2 = Vector2(200.0, 0.0)
# 源 pvp.lua:436 closeRewardInfo（各子 layer close）herodetail-detail-close 第一类形态（X）。
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
# 源 pvp.lua:1986/2503 tab/挑战按钮 tavern_button_normal_1 + cap(14,20,60,23) scaleSize 90×48。
const BTN_NORMAL_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_1.png"
const BTN_NORMAL_PRESS: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_2.png"
# 源 pvp.lua:2215 changeEnemy 换一批 tavern_button_1 + cap(50,20,66,23)。
const BTN_CHANGE_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_1.png"
const BTN_CHANGE_PRESS: String = "res://assets/ui/alpha/HVGA/tavern_button_2.png"
const CAP_NORMAL: Rect2 = Rect2(14.0, 20.0, 60.0, 23.0)   # 源 CCRectMake(14,20,60,23)
const CAP_CHANGE: Rect2 = Rect2(50.0, 20.0, 66.0, 23.0)   # 源 CCRectMake(50,20,66,23)
const TAB_BTN_SIZE: Vector2 = Vector2(90.0, 48.0)         # 源 scaleSize 90×48
const CHALLENGE_BTN_SIZE: Vector2 = Vector2(90.0, 48.0)
const ACTION_BTN_SIZE: Vector2 = Vector2(120.0, 48.0)
# 源 ccc3(234,225,205) tab/挑战 label / ccc3(251,206,16) 换一批 label。
const LABEL_COLOR_NORMAL: Color = Color(0.918, 0.882, 0.804)
const LABEL_COLOR_CHANGE: Color = Color(0.984, 0.808, 0.063)
# 源 framework.lua:749 pushScene 场景自动加全屏 bg.jpg（pvp.lua:3214/3250 是 pushScene 独立场景）。
const FRAMEWORK_BG: String = "res://assets/ui/alpha/HVGA/bg.jpg"

var _ladder: LadderManager
var _player: PlayerData
var _cm: ConfigManager
var _rng: BattleRng
var _current_tab: int = 0   # 0=挑战 1=排行 2=记录 3=阵容


func setup_panel(p_player: PlayerData, p_cm: ConfigManager, p_rng: BattleRng) -> void:
	_player = p_player
	_cm = p_cm
	_rng = p_rng
	_ladder = _player.ladder
	setup()
	# 源 pvp.lua:3214/3250 pushScene 独立场景（framework.lua:749 自动建全屏 bg.jpg），
	# 本项目单机化 pushScene→PopWindow，故 shade 透明 + 补全屏 bg.jpg 还原源视觉（同 PackagePanel 范式）。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_view()


# 源 framework.lua:749-751 pushScene 场景全屏 bg.jpg（pvp 源是独立场景）。
# _refresh_view 每次切 tab 会 queue_free 全部子节点，故 bg 需随每次重建补回（保持最底层）。
func _create_fullscreen_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = load(FRAMEWORK_BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = Vector2.ZERO
	bg.size = Vector2(960.0, 640.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)


func _refresh_view() -> void:
	for c in container.get_children():
		c.queue_free()
	_create_fullscreen_bg()
	_add_header()
	_add_tabs()
	# tab 内容区
	match _current_tab:
		0: _render_challenge_tab()
		1: _render_rankboard_tab()
		2: _render_records_tab()
		3: _render_lineup_tab()


func _add_header() -> void:
	var close: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_POS)
	close.pressed.connect(remove_window)
	container.add_child(close)
	var title := Label.new()
	# 源 pvp.lua 是 scene push（无文字标题，panel 自带背景图），本项目适配为 PopWindow 弹窗加标题（降级字面量）。
	title.text = "天梯竞技场"
	title.position = TITLE_POS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(title)


# 源 pvp.lua:7 三 panel layer 可见性切换 → 本项目 tab 按钮切换 _current_tab。
# 源 tab = tavern_button_normal_1 Scale9 + cap(14,20,60,23) + Label（reqRankData/reqRecordBoard 等）。
# 源 tab 名：L1654 PVP.ARMORY(英雄榜/挑战主面板) / L2018 PVP.RANKING_(排行榜) /
# L1727 PVP.COMBAT_RECORD(战斗记录) / L2969 PVP.ADJUSTMENT(防守阵容调整)。
func _add_tabs() -> void:
	var tab_lstr: Array[String] = ["PVP.ARMORY", "PVP.RANKING_", "PVP.COMBAT_RECORD", "PVP.ADJUSTMENT"]
	for i in tab_lstr.size():
		var tab: Button = UiScale9Button.make(BTN_NORMAL_RES, BTN_NORMAL_PRESS, TAB_POS + Vector2(i * TAB_W, 0), TAB_BTN_SIZE, CAP_NORMAL, _cm.get_lstr(tab_lstr[i]), LABEL_COLOR_NORMAL)
		tab.disabled = i == _current_tab
		tab.pressed.connect(_switch_tab.bind(i))
		container.add_child(tab)


func _switch_tab(idx: int) -> void:
	_current_tab = idx
	_refresh_view()


# ── tab 0：挑战（rank/gs/3 对手/购买/刷新）── 源 _open_panel reply 渲染
func _render_challenge_tab() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var reply: Dictionary = _ladder.handle({"_open_panel": true}, _player, _cm, _rng, now)
	var info: Dictionary = reply["_open_panel"]
	var info_lbl := Label.new()
	# 源 mainPanelLayer：L880 PVP.RANK_(排名:)/L912 PVP.TOTAL_POWER_(总战力:) 独立 Label。
	# 挑战次数/竞技场币源为图+数字字段（无单 LSTR），此处保留降级字面量。
	info_lbl.text = "%s%d  %s%d  挑战次数 %d  竞技场币 %d" % [_cm.get_lstr("PVP.RANK_"), int(info["rank"]), _cm.get_lstr("PVP.TOTAL_POWER_"), int(info["gs"]), int(info["left_count"]), _player.arena_point]
	info_lbl.position = CONTENT_POS
	info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(info_lbl)
	for i in (info["oppos"] as Array).size():
		container.add_child(_make_opponent_row((info["oppos"] as Array)[i], i))
	# 源 pvp.lua:1920 购买次数按钮 tavern_button_normal_1 + PVP.THE_NUMBER_OF_PURCHASES。
	var buy: Button = UiScale9Button.make(BTN_NORMAL_RES, BTN_NORMAL_PRESS, CONTENT_POS + Vector2(0, 250), ACTION_BTN_SIZE, CAP_NORMAL, _cm.get_lstr("PVP.THE_NUMBER_OF_PURCHASES"), LABEL_COLOR_NORMAL)
	buy.pressed.connect(_on_buy)
	container.add_child(buy)
	# 源 pvp.lua:2242 changeEnemy 换一批（tavern_button_1 + PVP.CHANGE_ANOTHER_LIST Label ccc3(251,206,16)）。
	var refresh: Button = UiScale9Button.make(BTN_CHANGE_RES, BTN_CHANGE_PRESS, CONTENT_POS + Vector2(0, 250) + BUY_OFFSET, ACTION_BTN_SIZE, CAP_CHANGE, _cm.get_lstr("PVP.CHANGE_ANOTHER_LIST"), LABEL_COLOR_CHANGE)
	refresh.pressed.connect(_on_refresh)
	container.add_child(refresh)


func _make_opponent_row(oppo: Dictionary, idx: int) -> Control:
	var row := Control.new()
	row.position = CONTENT_POS + Vector2(0, 40 + idx * 60)
	row.custom_minimum_size = Vector2(700, 50)
	var lbl := Label.new()
	# 源对手卡：图+数字字段（无文字 label），此处降级聚合文字。排名/战力照源 PVP.RANK_/PVP.TOTAL_POWER_。
	lbl.text = "%s  Lv%d  %s%d  %s%d" % [String(oppo["name"]), int(oppo["level"]), _cm.get_lstr("PVP.RANK_"), int(oppo["rank"]), _cm.get_lstr("PVP.TOTAL_POWER_"), int(oppo["gs"])]
	lbl.position = Vector2(0, 15)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	# 源 pvp.lua:2541 challengeEnemy1/2/3 tavern_button_normal_1 + cap(14,20,60,23) + PVP.CHALLENGE Label。
	var btn: Button = UiScale9Button.make(BTN_NORMAL_RES, BTN_NORMAL_PRESS, Vector2(550, 10), CHALLENGE_BTN_SIZE, CAP_NORMAL, _cm.get_lstr("PVP.CHALLENGE"), LABEL_COLOR_NORMAL)
	btn.pressed.connect(_on_challenge.bind(int(oppo["user_id"])))
	row.add_child(btn)
	return row


# ── tab 1：排行榜（20 NPC 假榜）── 源 _query_rankboard :3118-3155
func _render_rankboard_tab() -> void:
	var reply: Dictionary = _ladder.handle({"_query_rankboard": true}, _player, _cm, _rng, 0)
	var data: Dictionary = reply["_query_rankboard"]
	var rank_list: Array = data["rank_list"]
	for i in rank_list.size():
		var entry: Dictionary = rank_list[i]
		var lbl := Label.new()
		lbl.text = "%d. %s  Lv%d" % [i + 1, String(entry["name"]), int(entry["level"])]
		lbl.position = CONTENT_POS + Vector2(0, i * ROW_H)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)
	# 自己的排名（源 L1957 PVP.MY_RANK_(我的排名:)）
	var self_lbl := Label.new()
	var sr: Dictionary = data["self_rank"]
	self_lbl.text = "%s%d  %s  Lv%d" % [_cm.get_lstr("PVP.MY_RANK_"), int(data["pos"]), String(sr["name"]), int(sr["level"])]
	self_lbl.position = CONTENT_POS + Vector2(0, 22 * ROW_H)
	self_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(self_lbl)


# ── tab 2：战斗记录 ── 源 _query_records :3375-3379
func _render_records_tab() -> void:
	var reply: Dictionary = _ladder.handle({"_query_records": true}, _player, _cm, _rng, 0)
	var records: Array = reply["_query_records"]["records"]
	if records.is_empty():
		var empty := Label.new()
		empty.text = "暂无战斗记录"
		empty.position = CONTENT_POS
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(empty)
		return
	for i in records.size():
		var rec: Dictionary = records[i]
		var lbl := Label.new()
		lbl.text = "%s  排名 %d→%d  %s" % [String(rec.get("result", "")), int(rec.get("rank_before", 0)), int(rec.get("rank_after", 0)), String(rec.get("time", ""))]
		lbl.position = CONTENT_POS + Vector2(0, i * ROW_H)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)


# ── tab 3：防守阵容 ── 源 _open_panel lineup + _set_lineup :3417-3424
func _render_lineup_tab() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var reply: Dictionary = _ladder.handle({"_open_panel": true}, _player, _cm, _rng, now)
	var lineup: Array = reply["_open_panel"]["lineup"]
	var title := Label.new()
	# 源 L2984 PVP.DEFENSIVE_TEAM_(防守阵容:)。括号补充英雄数为降级（源为图标阵容非文字）。
	title.text = "%s（%d 英雄）" % [_cm.get_lstr("PVP.DEFENSIVE_TEAM_"), lineup.size()]
	title.position = CONTENT_POS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(title)
	for i in lineup.size():
		var tid: int = int(lineup[i])
		var lbl := Label.new()
		lbl.text = "槽 %d: 英雄 %d" % [i + 1, tid]
		lbl.position = CONTENT_POS + Vector2(0, 40 + i * ROW_H)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)
	# 源 L2940 adjustHero 按钮 tavern_button_normal_1 cap(50,20,66,23) + PVP.ADJUSTMENT(调整)。
	var set_btn: Button = UiScale9Button.make(BTN_NORMAL_RES, BTN_NORMAL_PRESS, CONTENT_POS + Vector2(0, 280), ACTION_BTN_SIZE, CAP_NORMAL, _cm.get_lstr("PVP.ADJUSTMENT"), LABEL_COLOR_NORMAL)
	set_btn.pressed.connect(_on_set_lineup)
	container.add_child(set_btn)


func _on_set_lineup() -> void:
	var team_tids: Array = []
	for inst_id in _player.team:
		var hero: HeroInstance = _player.hero_manager.get_hero(inst_id)
		if hero != null:
			team_tids.append(hero.tid)
	_ladder.handle({"_set_lineup": {"lineup": team_tids}}, _player, _cm, _rng, int(Time.get_unix_time_from_system()))
	Toast.show_message("防守阵容已更新")
	_refresh_view()


# 源 _start_battle：检查 left_count → LadderBattle.assemble（AI 敌方）→ battle_context mode=pvp → battle_scene。
func _on_challenge(oppo_user_id: int) -> void:
	if int(_ladder.pvp["left_count"]) <= 0:
		Toast.show_message("挑战次数不足，请购买")
		return
	var now: int = int(Time.get_unix_time_from_system())
	var asm: Dictionary = LadderBattle.assemble_pvp_battle(_ladder, oppo_user_id, _player, _cm, _rng, now)
	if not bool(asm.get("ok", false)):
		Toast.show_message("挑战失败（阵容为空或对手无效）")
		return
	GameData.battle_context = {"engine": asm["engine"], "mode": "pvp", "mgr": _ladder, "battle_info": asm["battle_info"]}
	remove_window()
	SceneManager.change_scene(BATTLE_SCENE_PATH)


func _on_buy() -> void:
	var reply: Dictionary = _ladder.handle({"_buy_battle_chance": true}, _player, _cm, _rng, int(Time.get_unix_time_from_system()))
	if str(reply["_buy_battle_chance"]["result"]) == "success":
		_refresh_view()
	else:
		Toast.show_message("钻石不足")


func _on_refresh() -> void:
	_ladder.handle({"_apply_opponent": true}, _player, _cm, _rng, int(Time.get_unix_time_from_system()))
	_refresh_view()
