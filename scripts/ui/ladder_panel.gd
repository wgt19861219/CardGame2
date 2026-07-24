class_name LadderPanel
extends PopWindow

## 天梯/PVP 面板（View 层）— 照源 ladder handler + ui/pvp.lua 3 panel layer。
## 4 tab：挑战（rank/gs/3 对手/购买/刷新）+ 排行榜（20 NPC）+ 战斗记录 + 防守阵容。
## 重构（2026-07-17）：base 层（bg.jpg/header/tab_bar + 4 tab view 容器 + 静态按钮）静态化进
## ladder_content.tscn（位置/size 编辑器可视化调）。tab view 常驻 visible 切换（不再 free+重建），
## 动态行/槽位 fill 到各 host。Scale9 按钮 .tscn 普通 Button 运行时套 StyleBox（九宫格图保视觉等价）。
## 后端 LadderManager 全命令就绪（_open_panel/_query_rankboard/_query_records/_set_lineup）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/ladder_content.tscn")
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
# 源 pvp.lua:1986/2503 tab/挑战按钮 tavern_button_normal_1 + cap(14,20,60,23) scaleSize 90×48。
const BTN_NORMAL_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_1.png"
const BTN_NORMAL_PRESS: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_2.png"
# 源 pvp.lua:2215 changeEnemy 换一批 tavern_button_1 + cap(50,20,66,23)。
const BTN_CHANGE_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_1.png"
const BTN_CHANGE_PRESS: String = "res://assets/ui/alpha/HVGA/tavern_button_2.png"
const CAP_NORMAL: Rect2 = Rect2(14.0, 20.0, 60.0, 23.0)   # 源 CCRectMake(14,20,60,23)
const CAP_CHANGE: Rect2 = Rect2(50.0, 20.0, 66.0, 23.0)   # 源 CCRectMake(50,20,66,23)
const CHALLENGE_BTN_SIZE: Vector2 = Vector2(90.0, 48.0)
const ROW_H: float = 40.0
const RANKBOARD_SELF_ROW: float = 22.0  # 源 self_rank 显示在第 22 行位置（20 NPC + 间隔）
# 源对手卡行布局：每行 60 高，第 0 行 y=40（CONTENT_POS.y + OPPONENT_OFFSET_Y）。
const OPPONENT_OFFSET_Y: float = 40.0
const OPPONENT_ROW_H: float = 60.0
const OPPONENT_ROW_SIZE: Vector2 = Vector2(700.0, 50.0)
const OPPONENT_LABEL_Y: float = 15.0
const OPPONENT_BTN_POS: Vector2 = Vector2(550.0, 10.0)
const LINEUP_ROW_OFFSET_Y: float = 40.0
const CONTENT_POS: Vector2 = Vector2(80.0, 90.0)
# 源 ccc3(234,225,205) tab/挑战 label / ccc3(251,206,16) 换一批 label。
const LABEL_COLOR_NORMAL: Color = Color(0.918, 0.882, 0.804)
const LABEL_COLOR_CHANGE: Color = Color(0.984, 0.808, 0.063)
# 源 pvp.lua:7 三 panel layer 可见性切换 → tab view visible 切换。
# 源 tab LSTR：L1654 PVP.ARMORY(英雄榜/挑战) / L2018 PVP.RANKING_(排行榜) /
# L1727 PVP.COMBAT_RECORD(战斗记录) / L2969 PVP.ADJUSTMENT(防守阵容调整)。
const TAB_LSTR: Array[String] = ["PVP.ARMORY", "PVP.RANKING_", "PVP.COMBAT_RECORD", "PVP.ADJUSTMENT"]

var _ladder: LadderManager
var _player: PlayerData
var _cm: ConfigManager
var _rng: BattleRng
var _current_tab: int = 0   # 0=挑战 1=排行 2=记录 3=阵容
var _tab_views: Dictionary = {}    # int → Control（.tscn %TabXxxView，visible 切换）
var _tab_buttons: Dictionary = {}  # int → Button（.tscn %TabBtnN，disabled 切换）
var _info_label: Label = null       # .tscn %InfoLabel（挑战 tab rank/gs/count/arena_point）
var _opponent_host: Control = null  # .tscn %OpponentHost（对手行动态挂）
var _rankboard_host: Control = null # .tscn %RankboardHost（排行榜行+self 动态挂）
var _records_host: Control = null   # .tscn %RecordsHost（战斗记录行动态挂）
var _lineup_title_label: Label = null  # .tscn %LineupTitleLabel
var _lineup_host: Control = null    # .tscn %LineupHost（阵容槽位动态挂）


func setup_panel(p_player: PlayerData, p_cm: ConfigManager, p_rng: BattleRng) -> void:
	_player = p_player
	_cm = p_cm
	_rng = p_rng
	_ladder = _player.ladder
	setup()
	# 源 pvp.lua:3214/3250 pushScene 独立场景（framework.lua:749 自动建全屏 bg.jpg），
	# 本项目单机化 pushScene→PopWindow，故 shade 透明 + .tscn %FrameworkBg 补全屏 bg.jpg 还原源视觉。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	_fill_tab(_current_tab)


# 建 UI 内容。base 层 + 4 tab view 从 .tscn instantiate（位置/size 可视化）+ 套 Scale9 StyleBox + 绑信号。
# 4 tab view 常驻 .tscn，visible 切换（不再 free+重建）；动态行/槽位 fill 到各 host。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	var header: Control = content.get_node("%HeaderLayer") as Control
	(header.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	# TitleLabel 静态 text 已固化 .tscn（源 pvp.lua 是 scene push，panel 自带背景图无文字标题；
	# 本项目 PopWindow 适配加标题，降级字面量）。
	for i in TAB_LSTR.size():
		var tab_btn: Button = content.get_node("%TabBtn%d" % i) as Button
		UiScale9Button.apply_with_label(tab_btn, BTN_NORMAL_RES, BTN_NORMAL_PRESS, CAP_NORMAL, _cm.get_lstr(TAB_LSTR[i]), LABEL_COLOR_NORMAL)
		tab_btn.disabled = i == _current_tab
		tab_btn.pressed.connect(_switch_tab.bind(i))
		_tab_buttons[i] = tab_btn
	_tab_views = {
		0: content.get_node("%TabChallengeView") as Control,
		1: content.get_node("%TabRankboardView") as Control,
		2: content.get_node("%TabRecordsView") as Control,
		3: content.get_node("%TabLineupView") as Control,
	}
	var challenge_view: Control = _tab_views[0] as Control
	_info_label = challenge_view.get_node("%InfoLabel") as Label
	_opponent_host = challenge_view.get_node("%OpponentHost") as Control
	_wire_action_btn(challenge_view, "%BuyBtn", BTN_NORMAL_RES, BTN_NORMAL_PRESS, CAP_NORMAL, "PVP.THE_NUMBER_OF_PURCHASES", LABEL_COLOR_NORMAL, _on_buy)
	_wire_action_btn(challenge_view, "%RefreshBtn", BTN_CHANGE_RES, BTN_CHANGE_PRESS, CAP_CHANGE, "PVP.CHANGE_ANOTHER_LIST", LABEL_COLOR_CHANGE, _on_refresh)
	_rankboard_host = (_tab_views[1] as Control).get_node("%RankboardHost") as Control
	_records_host = (_tab_views[2] as Control).get_node("%RecordsHost") as Control
	var lineup_view: Control = _tab_views[3] as Control
	_lineup_title_label = lineup_view.get_node("%LineupTitleLabel") as Label
	_lineup_host = lineup_view.get_node("%LineupHost") as Control
	_wire_action_btn(lineup_view, "%SetLineupBtn", BTN_NORMAL_RES, BTN_NORMAL_PRESS, CAP_NORMAL, "PVP.ADJUSTMENT", LABEL_COLOR_NORMAL, _on_set_lineup)


# .tscn 静态 Button 运行时套 Scale9 StyleBox + Label + 绑信号（.tscn 普通 Button 无九宫格图，运行时补）。
func _wire_action_btn(host: Control, node_path: String, normal_res: String, pressed_res: String, cap: Rect2, lstr_key: String, color: Color, callback: Callable) -> void:
	var btn: Button = host.get_node(node_path) as Button
	UiScale9Button.apply_with_label(btn, normal_res, pressed_res, cap, _cm.get_lstr(lstr_key), color)
	btn.pressed.connect(callback)


func _switch_tab(idx: int) -> void:
	_current_tab = idx
	_show_tab(idx)
	_fill_tab(idx)


func _show_tab(idx: int) -> void:
	for k in _tab_views:
		(_tab_views[k] as CanvasItem).visible = (k == idx)
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).disabled = (k == idx)


func _fill_tab(idx: int) -> void:
	match idx:
		0: _fill_challenge_tab()
		1: _fill_rankboard_tab()
		2: _fill_records_tab()
		3: _fill_lineup_tab()


# 清空 host 老子节点（切 tab/刷新数据时；源 _refresh_view free 全部 container 子节点的等价子集）。
func _clear_host(host: Control) -> void:
	for c in host.get_children():
		c.free()


# ── tab 0：挑战（rank/gs/3 对手/购买/刷新）── 源 _open_panel reply 渲染
func _fill_challenge_tab() -> void:
	_clear_host(_opponent_host)
	var now: int = int(Time.get_unix_time_from_system())
	var reply: Dictionary = _ladder.handle({"_open_panel": true}, _player, _cm, _rng, now)
	var info: Dictionary = reply["_open_panel"]
	# 源 mainPanelLayer：L880 PVP.RANK_(排名:)/L912 PVP.TOTAL_POWER_(总战力:) 独立 Label。
	# 挑战次数/竞技场币源为图+数字字段（无单 LSTR），此处保留降级字面量。
	_info_label.text = "%s%d  %s%d  挑战次数 %d  竞技场币 %d" % [_cm.get_lstr("PVP.RANK_"), int(info["rank"]), _cm.get_lstr("PVP.TOTAL_POWER_"), int(info["gs"]), int(info["left_count"]), _player.arena_point]
	for i in (info["oppos"] as Array).size():
		_opponent_host.add_child(_make_opponent_row((info["oppos"] as Array)[i], i))


func _make_opponent_row(oppo: Dictionary, idx: int) -> Control:
	var row := Control.new()
	row.position = Vector2(0, OPPONENT_OFFSET_Y + idx * OPPONENT_ROW_H)
	row.custom_minimum_size = OPPONENT_ROW_SIZE
	var lbl := Label.new()
	# 源对手卡：图+数字字段（无文字 label），此处降级聚合文字。排名/战力照源 PVP.RANK_/PVP.TOTAL_POWER_。
	lbl.text = "%s  Lv%d  %s%d  %s%d" % [String(oppo["name"]), int(oppo["level"]), _cm.get_lstr("PVP.RANK_"), int(oppo["rank"]), _cm.get_lstr("PVP.TOTAL_POWER_"), int(oppo["gs"])]
	lbl.position = Vector2(0, OPPONENT_LABEL_Y)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	# 源 pvp.lua:2541 challengeEnemy1/2/3 tavern_button_normal_1 + cap(14,20,60,23) + PVP.CHALLENGE Label。
	var btn: Button = UiScale9Button.make(BTN_NORMAL_RES, BTN_NORMAL_PRESS, OPPONENT_BTN_POS, CHALLENGE_BTN_SIZE, CAP_NORMAL, _cm.get_lstr("PVP.CHALLENGE"), LABEL_COLOR_NORMAL)
	btn.pressed.connect(_on_challenge.bind(int(oppo["user_id"])))
	row.add_child(btn)
	return row


# ── tab 1：排行榜（20 NPC 假榜）── 源 _query_rankboard :3118-3155
func _fill_rankboard_tab() -> void:
	_clear_host(_rankboard_host)
	var reply: Dictionary = _ladder.handle({"_query_rankboard": true}, _player, _cm, _rng, 0)
	var data: Dictionary = reply["_query_rankboard"]
	var rank_list: Array = data["rank_list"]
	for i in rank_list.size():
		var entry: Dictionary = rank_list[i]
		var lbl := Label.new()
		lbl.text = "%d. %s  Lv%d" % [i + 1, String(entry["name"]), int(entry["level"])]
		lbl.position = CONTENT_POS + Vector2(0, i * ROW_H)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rankboard_host.add_child(lbl)
	# 自己的排名（源 L1957 PVP.MY_RANK_(我的排名:)）
	var self_lbl := Label.new()
	var sr: Dictionary = data["self_rank"]
	self_lbl.text = "%s%d  %s  Lv%d" % [_cm.get_lstr("PVP.MY_RANK_"), int(data["pos"]), String(sr["name"]), int(sr["level"])]
	self_lbl.position = CONTENT_POS + Vector2(0, RANKBOARD_SELF_ROW * ROW_H)
	self_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rankboard_host.add_child(self_lbl)


# ── tab 2：战斗记录 ── 源 _query_records :3375-3379
func _fill_records_tab() -> void:
	_clear_host(_records_host)
	var reply: Dictionary = _ladder.handle({"_query_records": true}, _player, _cm, _rng, 0)
	var records: Array = reply["_query_records"]["records"]
	if records.is_empty():
		var empty := Label.new()
		empty.text = "暂无战斗记录"
		empty.position = CONTENT_POS
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_records_host.add_child(empty)
		return
	for i in records.size():
		var rec: Dictionary = records[i]
		var lbl := Label.new()
		lbl.text = "%s  排名 %d→%d  %s" % [String(rec.get("result", "")), int(rec.get("rank_before", 0)), int(rec.get("rank_after", 0)), String(rec.get("time", ""))]
		lbl.position = CONTENT_POS + Vector2(0, i * ROW_H)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_records_host.add_child(lbl)


# ── tab 3：防守阵容 ── 源 _open_panel lineup + _set_lineup :3417-3424
func _fill_lineup_tab() -> void:
	_clear_host(_lineup_host)
	var now: int = int(Time.get_unix_time_from_system())
	var reply: Dictionary = _ladder.handle({"_open_panel": true}, _player, _cm, _rng, now)
	var lineup: Array = reply["_open_panel"]["lineup"]
	# 源 L2984 PVP.DEFENSIVE_TEAM_(防守阵容:)。括号补充英雄数为降级（源为图标阵容非文字）。
	_lineup_title_label.text = "%s（%d 英雄）" % [_cm.get_lstr("PVP.DEFENSIVE_TEAM_"), lineup.size()]
	for i in lineup.size():
		var tid: int = int(lineup[i])
		var lbl := Label.new()
		lbl.text = "槽 %d: 英雄 %d" % [i + 1, tid]
		lbl.position = CONTENT_POS + Vector2(0, LINEUP_ROW_OFFSET_Y + i * ROW_H)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lineup_host.add_child(lbl)


func _on_set_lineup() -> void:
	var team_tids: Array = []
	for inst_id in _player.team:
		var hero: HeroInstance = _player.hero_manager.get_hero(inst_id)
		if hero != null:
			team_tids.append(hero.tid)
	_ladder.handle({"_set_lineup": {"lineup": team_tids}}, _player, _cm, _rng, int(Time.get_unix_time_from_system()))
	Toast.show_message("防守阵容已更新")
	_fill_tab(_current_tab)


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
		GameData.mark_save_dirty()   # 照源 local_server:3371 PVP 买次数脏标（扣钻石，60s/退出刷）
		_fill_tab(_current_tab)
	else:
		Toast.show_message("钻石不足")


func _on_refresh() -> void:
	_ladder.handle({"_apply_opponent": true}, _player, _cm, _rng, int(Time.get_unix_time_from_system()))
	_fill_tab(_current_tab)
