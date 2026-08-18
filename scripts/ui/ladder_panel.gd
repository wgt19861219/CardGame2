class_name LadderPanel
extends PopWindow

## 天梯/PVP 面板（View 层）— 源 ui/pvp.lua（3294 行）6 panelLayer 本项目消费 3 层：
## mainPanelLayer(:1933-3050 → 挑战 tab + 防守阵容 tab) / rankPanelLayer(:1601 → 排行 tab)
## / recordPanelLayer(:1702 → 记录 tab)；heroInfoLayer(:753)/rewardPanelLayer(:472)/
## rewardInfoPanelLayer(:375) 未迁移（批5 长尾披露）。
## 两件套（批4 Task 9，2026-08-18）：静态树全量进 ladder_content.tscn（3 对手卡/主框架/
## 4 tab 行/两滚动层照源直译），本脚本只做业务 + 信号 connect + fill；按钮三态走 theme
## variation（tab/挑战复用 SB_crusade_action，换一批/购买走 ladder 系新 SB）。
## 后端 LadderManager 全命令就绪（_open_panel/_query_rankboard/_query_records/_set_lineup）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/ladder_content.tscn")
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
# L1727 PVP.COMBAT_RECORD(战斗记录) / L2969 PVP.ADJUSTMENT(防守阵容调整)。
const TAB_LSTR: Array[String] = ["PVP.ARMORY", "PVP.RANKING_", "PVP.COMBAT_RECORD", "PVP.ADJUSTMENT"]
# 排行行（源 initRankListData :1843-1848）：行高 70（1-10 名）/50（11+ 名），步进 +8 间距；
# 底图分档 rankFrameRecource :33-67（1st/2nd/3rd/high/low，setContentSize(475,h)）。
const RANK_ROW_W: float = 475.0
const RANK_ROW_H_HIGH: float = 70.0
const RANK_ROW_H_LOW: float = 50.0
const RANK_ROW_GAP: float = 8.0
const RANK_ROW_STEP_HIGH: float = 78.0
const RANK_ROW_STEP_LOW: float = 58.0
const RANK_ROW_FIRST_Y: float = 199.0
const RANK_ROW_TEX_1ST: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_1st.png"
const RANK_ROW_TEX_2ND: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_2nd.png"
const RANK_ROW_TEX_3RD: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_3rd.png"
const RANK_ROW_TEX_HIGH: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_high.png"
const RANK_ROW_TEX_LOW: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_low.png"
# 排行行内（相对 475xh 底图）：名次 x=10 / 名字 x=110（源 rank(-200,-11)/iconParent(-110)
# 名次在榜框左带、头像降级后名字占 iconParent 位，简化直译披露）。
const RANK_ROW_RANK_X: float = 10.0
const RANK_ROW_NAME_X: float = 110.0
const RANK_ROW_LBL_H: float = 24.0
# 记录行（源 initRecordData :1801）：行步进 78；highlight 底图无 scaleSize → 原尺寸
# 638x97px ÷CS = 498.1x75.7；行内子相对底图中心点值直译（resultEffect(-220,-15)/
# name(-25,-11)/time(-60,+16)/record(-180,+16)，:1270-1395）。
const REC_ROW_W: float = 498.1
const REC_ROW_H: float = 75.7
const REC_ROW_STEP: float = 78.0
const REC_ROW_FIRST_Y: float = 199.0
const REC_ROW_TEX: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_high.png"
const REC_WIN_TEX: String = "res://assets/ui/alpha/HVGA/pvp/pvp_win.png"
const REC_LOSE_TEX: String = "res://assets/ui/alpha/HVGA/pvp/pvp_lose.png"
const REC_ICON_W: float = 29.7
const REC_ICON_H: float = 49.2
const REC_RESULT_DX: float = -220.0
const REC_RESULT_DY: float = -15.0
const REC_NAME_DX: float = -25.0
const REC_NAME_DY: float = -11.0
const REC_TIME_DX: float = -60.0
const REC_TIME_DY: float = 16.0
const REC_RANK_DX: float = -180.0
const REC_LBL_H: float = 24.0
# 榜单/记录 host 内容宽（ScrollContainer 裁剪语义，host 只需撑内容高）。
const RANK_CLIP_W: float = 470.0
const REC_CLIP_W: float = 490.0
# 相对时间阈值（秒，源 :1445-1456 second2hms 分档）。
const SEC_PER_MINUTE: int = 60
const SEC_PER_HOUR: int = 3600
const SEC_PER_DAY: int = 86400

var _ladder: LadderManager
var _player: PlayerData
var _cm: ConfigManager
var _rng: BattleRng
var _current_tab: int = 0   # 0=挑战 1=排行 2=记录 3=阵容
var _tab_views: Dictionary = {}    # int → Control（.tscn %TabXxxView，visible 切换）
var _tab_buttons: Dictionary = {}  # int → Button（.tscn %TabBtnN，disabled 切换）
var _opponent_cards: Array = []    # 3 卡 Control（fill name/level/rank/gs/头像）
var _rankboard_host: Control = null  # .tscn %RankboardHost（榜单行 fill）
var _records_host: Control = null    # .tscn %RecordsHost（记录行 fill）
var _lineup_slots: Array = []      # 5 槽 Control（fill ReadheroIcon）
var _lineup_title: Label = null    # .tscn %LineupTitleLbl


func setup_panel(p_player: PlayerData, p_cm: ConfigManager, p_rng: BattleRng) -> void:
	hud_identity = "pvp"   # T4：原 apply/remove override 样板上收基类
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类
	_player = p_player
	_cm = p_cm
	_rng = p_rng
	_ladder = _player.ladder
	setup()
	# 本项目单机化 pushScene→PopWindow，故 shade 透明 + .tscn %FrameworkBg 补全屏 bg.jpg 还原源视觉。
	_build_content()
	_fill_tab(_current_tab)


# 建 UI：静态树从 .tscn instantiate（位置/size 编辑器可视化），此处只取节点 + 绑信号 + fill LSTR。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	for i in TAB_LSTR.size():
		var tab_btn: Button = content.get_node("%TabBtn" + str(i)) as Button
		(tab_btn.get_node("BtnLbl") as Label).text = _cm.get_lstr(TAB_LSTR[i])
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
	for i in 3:
		_opponent_cards.append(challenge_view.get_node("%EnemyCard" + str(i + 1)) as Control)
	_wire_btn(challenge_view.get_node("%RefreshBtn") as Button, "PVP.CHANGE_ANOTHER_LIST", _on_refresh)
	_wire_btn(challenge_view.get_node("%BuyBtn") as Button, "PVP.THE_NUMBER_OF_PURCHASES", _on_buy)
	_rankboard_host = (_tab_views[1] as Control).get_node("%RankboardHost") as Control
	_records_host = (_tab_views[2] as Control).get_node("%RecordsHost") as Control
	var lineup_view: Control = _tab_views[3] as Control
	_lineup_title = lineup_view.get_node("%LineupTitleLbl") as Label
	for i in 5:
		_lineup_slots.append(lineup_view.get_node("%HeroSlot" + str(i + 1)) as Control)
	_wire_btn(lineup_view.get_node("%SetLineupBtn") as Button, "PVP.ADJUSTMENT", _on_set_lineup)


# 静态 Button 的子 Label fill LSTR + 绑信号（按钮三态样式已在 theme variation，无运行时 stylebox）。
func _wire_btn(btn: Button, lstr_key: String, callback: Callable) -> void:
	(btn.get_node("BtnLbl") as Label).text = _cm.get_lstr(lstr_key)
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


# ── tab 0：挑战（rank/gs/剩余次数/竞技场币 + 3 对手卡 fill）── 源 initPanel :3138-3160
func _fill_challenge_tab() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var reply: Dictionary = _ladder.handle({"_open_panel": true}, _player, _cm, _rng, now)
	var info: Dictionary = reply["_open_panel"]
	var view: Control = _tab_views[0] as Control
	(view.get_node("%RankValue") as Label).text = str(int(info["rank"]))
	(view.get_node("%GpsValue") as Label).text = str(int(info["gs"]))
	(view.get_node("%ArenaValue") as Label).text = str(int(_player.arena_point))
	(view.get_node("%LeftTimeNum") as Label).text = "%d/%d" % [int(info["left_count"]), 5]
	var oppos: Array = info["oppos"] as Array
	for i in mini(3, oppos.size()):
		_fill_enemy_card(_opponent_cards[i] as Control, oppos[i] as Dictionary)
	# 源 initEnemyList :3081：无对手的卡隐藏。
	for i in range(oppos.size(), 3):
		(_opponent_cards[i] as CanvasItem).visible = false


# 对手卡 fill（源 initEnemyList :3086-3108：name/level/rank/gs + avatar 进 iconFrame）。
# 挑战按钮重绑（bind 的 user_id 随对手刷新变化，先断旧连接再连新）。
func _fill_enemy_card(card: Control, oppo: Dictionary) -> void:
	card.visible = true
	(card.get_node("NameLbl") as Label).text = String(oppo["name"])
	(card.get_node("LevelLbl") as Label).text = str(int(oppo["level"]))
	(card.get_node("RankVal") as Label).text = str(int(oppo["rank"]))
	(card.get_node("GpsVal") as Label).text = str(int(oppo["gs"]))
	var btn: BaseButton = card.get_node("ChallengeBtn") as BaseButton
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn["callable"])
	btn.pressed.connect(_on_challenge.bind(int(oppo["user_id"])))
	_fill_head(card.get_node("HeadHost") as Control, int(oppo["avatar"]))


# 头像 fill：源 getHeroIconByID(param.avatar) 组件缺 → Avatar.Picture 直显（ranklist 先例降级）。
func _fill_head(host: Control, avatar: int) -> void:
	_clear_host(host)
	var pic: String = String(_cm.get_raw_table(&"Avatar").get(str(avatar), {}).get("Picture", ""))
	if pic.is_empty():
		return
	var head_path: String = "res://assets/ui/" + pic.substr(3)
	if not ResourceLoader.exists(head_path):
		return
	var head := TextureRect.new()
	head.texture = load(head_path) as Texture2D
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.size = host.size
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(head)


# ── tab 1：排行榜（20 NPC 假榜 + self 行）── 源 initRankListData :1833-1850 + createRankInfo
func _fill_rankboard_tab() -> void:
	_clear_host(_rankboard_host)
	var reply: Dictionary = _ladder.handle({"_query_rankboard": true}, _player, _cm, _rng, 0)
	var data: Dictionary = reply["_query_rankboard"]
	var rank_list: Array = data["rank_list"]
	for i in rank_list.size():
		var entry: Dictionary = rank_list[i]
		var row := _make_rank_row(i + 1, "%s Lv%d" % [String(entry["name"]), int(entry["level"])])
		row.position.y = _rank_row_y(i + 1)
		_rankboard_host.add_child(row)
	# 自己的排名（源 L1957 PVP.MY_RANK_(我的排名:)；20 假榜后附行，现状行为保留）。
	var sr: Dictionary = data["self_rank"]
	var self_row := _make_rank_row(rank_list.size() + 1, "★ %s%d %s Lv%d" % [_cm.get_lstr("PVP.MY_RANK_"), int(data["pos"]), String(sr["name"]), int(sr["level"])])
	self_row.position.y = _rank_row_y(rank_list.size() + 1)
	_rankboard_host.add_child(self_row)
	var count: int = rank_list.size() + 1
	var total_h: float = RANK_ROW_STEP_HIGH * float(mini(10, count)) + RANK_ROW_STEP_LOW * float(maxi(0, count - 10)) + RANK_ROW_GAP
	_rankboard_host.custom_minimum_size = Vector2(RANK_CLIP_W, total_h)


# 行 y（源 initRankListData :1846 公式直译）：第 i 行底图中心 = 199 - 78*(min(10,i)-1)
# - 58*max(0,i-10) - 8*(i>10)（199 = 560-(290+71) 源 bg(250,290)+rankBg 局部(150,71)）。
func _rank_row_y(i: int) -> float:
	var step: float = RANK_ROW_STEP_HIGH * float(mini(10, i) - 1) + RANK_ROW_STEP_LOW * float(maxi(0, i - 10))
	if i > 10:
		step += RANK_ROW_GAP
	return RANK_ROW_FIRST_Y - step - _rank_row_h(i) * 0.5


func _rank_row_h(rank_num: int) -> float:
	return RANK_ROW_H_HIGH if rank_num <= 10 else RANK_ROW_H_LOW


# 排行行（源 createRankInfo :1165-1256）：rankBg 分档底图 475xh + 名次白 20 + 名字白 20
# （源 getWholeHeadIcon 头像组件缺 → "名字 LvN" Label 降级，ranklist 先例披露；
# 1st/2nd/3rd 名次图 HC 有存量但 ranklist 面板同降级，一致性不拷）。
func _make_rank_row(rank_num: int, label_text: String) -> Control:
	var h: float = _rank_row_h(rank_num)
	var tex_path: String = RANK_ROW_TEX_HIGH
	if rank_num == 1:
		tex_path = RANK_ROW_TEX_1ST
	elif rank_num == 2:
		tex_path = RANK_ROW_TEX_2ND
	elif rank_num == 3:
		tex_path = RANK_ROW_TEX_3RD
	elif rank_num > 10:
		tex_path = RANK_ROW_TEX_LOW
	var row := Control.new()
	row.size = Vector2(RANK_ROW_W, h)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TextureRect.new()
	bg.name = "RankBg"
	bg.texture = load(tex_path) as Texture2D
	bg.size = Vector2(RANK_ROW_W, h)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank_num
	rank_lbl.theme_type_variation = "LadderWhiteLabel20"
	rank_lbl.position = Vector2(RANK_ROW_RANK_X, h * 0.5 - RANK_ROW_LBL_H * 0.5)
	rank_lbl.size = Vector2(60.0, RANK_ROW_LBL_H)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(rank_lbl)
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.theme_type_variation = "LadderWhiteLabel20"
	name_lbl.position = Vector2(RANK_ROW_NAME_X, h * 0.5 - RANK_ROW_LBL_H * 0.5)
	name_lbl.size = Vector2(320.0, RANK_ROW_LBL_H)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(name_lbl)
	return row


# ── tab 2：战斗记录 ── 源 initRecordData :1790-1803 + createRecordInfo :1257-1468
func _fill_records_tab() -> void:
	_clear_host(_records_host)
	var reply: Dictionary = _ladder.handle({"_query_records": true}, _player, _cm, _rng, 0)
	var records: Array = reply["_query_records"]["records"] as Array
	if records.is_empty():
		var empty := Label.new()
		empty.text = "暂无战斗记录"
		empty.theme_type_variation = "LadderDarkLabel20"
		empty.position = Vector2(100.0, RANK_ROW_FIRST_Y)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_records_host.add_child(empty)
		_records_host.custom_minimum_size = Vector2(REC_CLIP_W, 0.0)
		return
	for i in records.size():
		_records_host.add_child(_make_record_row(records[i] as Dictionary, i))
	_records_host.custom_minimum_size = Vector2(REC_CLIP_W, REC_ROW_FIRST_Y + REC_ROW_STEP * float(records.size()))


# 记录行：底图 highlight（源 :1271-1280）+ 胜负图（:1425-1432 pvp_win/lose）+ 名字/时间/
# 排名（行内相对底图中心直译）。源 _deta_rank/review/share 依赖 _replay_id 与对手 summary
# 数据（本项目 records 仅 {result,time,rank}）→ 显当前排名、胜负字降级、review/share 不建（披露）。
func _make_record_row(rec: Dictionary, idx: int) -> Control:
	var row := Control.new()
	row.size = Vector2(REC_ROW_W, REC_ROW_H)
	row.position.y = REC_ROW_FIRST_Y + REC_ROW_STEP * float(idx) - REC_ROW_H * 0.5
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TextureRect.new()
	bg.name = "RecBg"
	bg.texture = load(REC_ROW_TEX) as Texture2D
	bg.size = row.size
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	var cx: float = REC_ROW_W * 0.5
	var cy: float = REC_ROW_H * 0.5
	var victory: bool = str(rec.get("result", "")) == "victory"
	var result_icon := TextureRect.new()
	result_icon.name = "ResultIcon"
	result_icon.texture = load(REC_WIN_TEX if victory else REC_LOSE_TEX) as Texture2D
	result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_icon.size = Vector2(REC_ICON_W, REC_ICON_H)
	result_icon.position = Vector2(cx + REC_RESULT_DX - REC_ICON_W * 0.5, cy + REC_RESULT_DY - REC_ICON_H * 0.5)
	result_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(result_icon)
	var name_lbl := Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.text = "胜利" if victory else "失败"
	name_lbl.theme_type_variation = "LadderWhiteShadowLabel20"
	name_lbl.position = Vector2(cx + REC_NAME_DX, cy + REC_NAME_DY - REC_LBL_H * 0.5)
	name_lbl.size = Vector2(140.0, REC_LBL_H)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(name_lbl)
	var time_lbl := Label.new()
	time_lbl.name = "TimeLbl"
	time_lbl.text = _relative_time(int(rec.get("time", 0)))
	time_lbl.theme_type_variation = "LadderTimeLabel20"
	time_lbl.position = Vector2(cx + REC_TIME_DX, cy + REC_TIME_DY - REC_LBL_H * 0.5)
	time_lbl.size = Vector2(200.0, REC_LBL_H)
	time_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(time_lbl)
	var rank_lbl := Label.new()
	rank_lbl.text = "%s%d" % [_cm.get_lstr("PVP.RANK_"), int(rec.get("rank", 0))]
	rank_lbl.theme_type_variation = "LadderOrangeLabel20"
	rank_lbl.position = Vector2(cx + REC_RANK_DX, cy + REC_TIME_DY - REC_LBL_H * 0.5)
	rank_lbl.size = Vector2(120.0, REC_LBL_H)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(rank_lbl)
	return row


# 相对时间（源 :1445-1456 second2hms：>=24h 1天前 / >=1h N小时前 / >=1m N分钟前 / N秒前）。
func _relative_time(unix_time: int) -> String:
	var elapsed: int = maxi(0, int(Time.get_unix_time_from_system()) - unix_time)
	if elapsed >= SEC_PER_DAY:
		return _cm.get_lstr("PVP.1_DAY_AGO")
	if elapsed >= SEC_PER_HOUR:
		return _cm.get_lstr("PVP._D_HOURS_AGO") % [elapsed / SEC_PER_HOUR]
	if elapsed >= SEC_PER_MINUTE:
		return _cm.get_lstr("PVP._D_MINUTES_AGO") % [elapsed / SEC_PER_MINUTE]
	return _cm.get_lstr("PVP._D_SECONDS_AGO") % [elapsed]


# ── tab 3：防守阵容 ── 源 initDefandHeroList :3051-3065 + _open_panel lineup
func _fill_lineup_tab() -> void:
	for slot in _lineup_slots:
		_clear_host(slot as Control)
	var now: int = int(Time.get_unix_time_from_system())
	var reply: Dictionary = _ladder.handle({"_open_panel": true}, _player, _cm, _rng, now)
	var lineup: Array = reply["_open_panel"]["lineup"] as Array
	_lineup_title.text = "%s（%d 英雄）" % [_cm.get_lstr("PVP.DEFENSIVE_TEAM_"), lineup.size()]
	for i in mini(5, lineup.size()):
		# 源 readhero.createIconByID(id)（完整英雄头像含框）→ ReadheroIcon 等价
		#（lineup 无 rank/stars/level 数据，用默认 1/0/不显）。
		var icon := ReadheroIcon.new()
		icon.setup({"id": int(lineup[i]), "rank": 1, "stars": 0}, _cm)
		(_lineup_slots[i] as Control).add_child(icon)


func _on_set_lineup() -> void:
	var team_tids: Array = []
	for inst_id in _player.team:
		var hero: HeroInstance = _player.hero_manager.get_hero(inst_id)
		if hero != null:
			team_tids.append(hero.tid)
	_ladder.handle({"_set_lineup": {"lineup": team_tids}}, _player, _cm, _rng, int(Time.get_unix_time_from_system()))
	Toast.show_message("防守阵容已更新")
	_fill_tab(_current_tab)


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
		GameData.mark_save_dirty()
		_fill_tab(_current_tab)
	else:
		Toast.show_message("钻石不足")


func _on_refresh() -> void:
	_ladder.handle({"_apply_opponent": true}, _player, _cm, _rng, int(Time.get_unix_time_from_system()))
	_fill_tab(_current_tab)
