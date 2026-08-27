class_name LadderPanel
extends PopWindow

## 竞技场面板（View 层）— 源 ui/pvp.lua（3294 行）createMainLayer(:1933-3050) 单屏结构
## + rank/record 覆盖层。走查批 D（2026-08-27）照源重构，撤销旧 4-tab 发明结构：
## - 主屏常显：防守阵容区（标签/5 槽/调整钮/战斗力）+ 我的排名行 + 中排四钮
##   （规则说明/排行榜/对战记录/兑换奖励 + 竞技点小图标，源 :2072-2179）+ 今日剩余次数
##   + 3 对手卡 + 换一批；
## - 排行榜/对战记录钮 → 覆盖层（TabRankboardView/TabRecordsView visible 切换，
##   右上 close 源 :1671-1699 herodetail-detail-close @(650,420)）；
## - 「英雄榜」系排行榜覆盖层标题（源 :1654 PVP.ARMORY），旧版误作 tab 名；
## - 兑换奖励 → shop(5)（源 :1864-1866 pvpShop pushScene ed.ui.shop.create(5)，本项目
##   ShopManager shop_id=5 arenapoint 支付已就绪）；
## - 规则说明 → LadderRulesPopup（源 rewardInfoPanelLayer :375-461 本批迁移）；
## - D4：旧独立「购买次数」钮删除——源 changeEnemy 三态中购买/CD 态不可达（pvpCD 恒 0
##   :23 无赋值 + VIP 表 PVP Buy 全 0 → leftBuyTime=0），恒「换一批」态（:1911-1922）。
## 行渲染下沉 LadderRows（排行/记录行，口径不变）。LineupTitleLbl 文案源 :2980-2994
## 「防守阵容:」(100,344)。myRank 贴图数字照源 createNumbers big_pvp1 规则（tools.lua:358-365）：
## <4 名裸版徽章图 / 4-10 big_pvp / >=11 small_pvp（:3148 padding=-2 anchor(0,0.5) @(150,277)）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/ladder_content.tscn")
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
# myRank 数字分档（源 tools.lua createNumbers big_pvp1 :358-365）。
const RANK_BADGE_RES_1ST: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_1st.png"
const RANK_BADGE_RES_2ND: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_2nd.png"
const RANK_BADGE_RES_3RD: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_3rd.png"
const RANK_NUM_PADDING: float = -2.0
# myRank host 左中锚（源 anchor(0,0.5) @(150,277)cocos → Godot (150,203)；host tscn (150,180)
# 占位，fill 精排 y=203−h/2）。
const MY_RANK_ANCHOR: Vector2 = Vector2(150.0, 203.0)
const LEFT_COUNT_MAX: int = 5

var _ladder: LadderManager
var _player: PlayerData
var _cm: ConfigManager
var _rng: BattleRng
var _overlay: int = 0   # 0=主屏 1=排行榜覆盖层 2=对战记录覆盖层
var _opponent_cards: Array = []    # 3 卡 Control（fill name/level/rank/gs/头像）
var _rankboard_host: Control = null  # .tscn %RankboardHost（榜单行 fill）
var _records_host: Control = null    # .tscn %RecordsHost（记录行 fill）
var _lineup_slots: Array = []      # 5 槽 Control（fill ReadheroIcon）
var _rank_views: Dictionary = {}   # 0/1/2 → Control（主屏/两覆盖层 visible 切换）


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
	_fill_challenge_tab()


# 建 UI：静态树从 .tscn instantiate（位置/size 编辑器可视化），此处只取节点 + 绑信号 + fill LSTR。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	# 返回钮贴图照源换 backbtn 系（源 statusbar.lua:152 createBack 对所有非 main 场景统一挂
	# backbtn.png/backbtn-disabled.png；批 A G4 运行时赋值补正，位置沿用全项目导航惯例）。
	var close_tb := content.get_node("%CloseBtn") as TextureButton
	close_tb.texture_normal = load("res://assets/ui/alpha/HVGA/backbtn.png")
	close_tb.texture_pressed = load("res://assets/ui/alpha/HVGA/backbtn-disabled.png")
	_rank_views = {
		0: content.get_node("%TabChallengeView") as Control,
		1: content.get_node("%TabRankboardView") as Control,
		2: content.get_node("%TabRecordsView") as Control,
	}
	var view: Control = _rank_views[0] as Control
	for i in 3:
		_opponent_cards.append(view.get_node("%EnemyCard" + str(i + 1)) as Control)
	_wire_btn(view.get_node("%RefreshBtn") as Button, "PVP.CHANGE_ANOTHER_LIST", _on_refresh)
	# 中排四钮（源 :1984-2179 规则说明/排行榜/对战记录/兑换奖励）。
	_wire_btn(view.get_node("%RuleBtn") as Button, "PVP.RULE_DESCRIPTION", _on_show_rules)
	_wire_btn(view.get_node("%RankboardBtn") as Button, "PVP.RANKING_", _show_overlay.bind(1))
	_wire_btn(view.get_node("%RecordBtn") as Button, "PVP.COMBAT_RECORD", _show_overlay.bind(2))
	_wire_btn(view.get_node("%ShopBtn") as Button, "CRUSADECONFIG.REDEEM", _on_open_shop)
	# 覆盖层关闭（源 :1671-1699 closeRankInfo / 记录层同构）。
	(content.get_node("%CloseRankBtn") as BaseButton).pressed.connect(_show_overlay.bind(0))
	(content.get_node("%CloseRecBtn") as BaseButton).pressed.connect(_show_overlay.bind(0))
	_rankboard_host = (_rank_views[1] as Control).get_node("%RankboardHost") as Control
	_records_host = (_rank_views[2] as Control).get_node("%RecordsHost") as Control
	# 防守阵容区（源主屏常驻 :2980-3034，批 D 自旧 TabLineupView 并入主屏）。
	(view.get_node("%LineupTitleLbl") as Label).text = _cm.get_lstr("PVP.DEFENSIVE_TEAM_")
	for i in 5:
		_lineup_slots.append(view.get_node("%HeroSlot" + str(i + 1)) as Control)
	_wire_btn(view.get_node("%SetLineupBtn") as Button, "PVP.ADJUSTMENT", _on_set_lineup)


# 静态 Button 的子 Label fill LSTR + 绑信号（按钮三态样式已在 theme variation，无运行时 stylebox）。
func _wire_btn(btn: Button, lstr_key: String, callback: Callable) -> void:
	(btn.get_node("BtnLbl") as Label).text = _cm.get_lstr(lstr_key)
	btn.pressed.connect(callback)


# 覆盖层切换（源 rankPanelLayer/recordPanelLayer setVisible 语义；0=回主屏）。
func _show_overlay(idx: int) -> void:
	_overlay = idx
	for k in _rank_views:
		(_rank_views[k] as CanvasItem).visible = (k == idx)
	match idx:
		1: _fill_rankboard_tab()
		2: _fill_records_tab()


func _clear_host(host: Control) -> void:
	for c in host.get_children():
		c.free()


# ── 主屏：rank/gs/剩余次数/我的排名贴图数字 + 3 对手卡 + 防守阵容 ── 源 initPanel :3138-3160
func _fill_challenge_tab() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var reply: Dictionary = _ladder.handle({"_open_panel": true}, _player, _cm, _rng, now)
	var info: Dictionary = reply["_open_panel"]
	var view: Control = _rank_views[0] as Control
	(view.get_node("%GpsValue") as Label).text = str(int(info["gs"]))
	(view.get_node("%LeftTimeNum") as Label).text = "%d/%d" % [int(info["left_count"]), LEFT_COUNT_MAX]
	_fill_my_rank(int(info["rank"]))
	var oppos: Array = info["oppos"] as Array
	for i in mini(3, oppos.size()):
		_fill_enemy_card(_opponent_cards[i] as Control, oppos[i] as Dictionary)
	# 源 initEnemyList :3081：无对手的卡隐藏。
	for i in range(oppos.size(), 3):
		(_opponent_cards[i] as CanvasItem).visible = false
	_fill_lineup(info["lineup"] as Array)


# 我的排名贴图数字（源 :3148 createNumbers big_pvp1：<4 徽章图 / 4-10 big_pvp / >=11 small_pvp）。
# host 左缘锚定 x=150、垂直中心 203（源 anchor(0,0.5) @(150,277)cocos）。
func _fill_my_rank(rank: int) -> void:
	var host: Control = (_rank_views[0] as Control).get_node("%RankValue") as Control
	for c in host.get_children():
		c.free()
	var node: Control
	if rank >= 1 and rank <= 3:
		var res: String = RANK_BADGE_RES_1ST
		if rank == 2:
			res = RANK_BADGE_RES_2ND
		elif rank == 3:
			res = RANK_BADGE_RES_3RD
		var icon := TextureRect.new()
		icon.texture = load(res) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = icon.texture.get_size() / NumberNode.CONTENT_SCALE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node = icon
	else:
		node = NumberNode.build(str(rank), "big_pvp" if rank < 11 else "small_pvp")
	host.add_child(node)
	host.position = Vector2(MY_RANK_ANCHOR.x, MY_RANK_ANCHOR.y - node.size.y * 0.5)


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


# ── 防守阵容（源 initDefandHeroList :3051-3065 主屏常驻）──
func _fill_lineup(lineup: Array) -> void:
	for slot in _lineup_slots:
		_clear_host(slot as Control)
	for i in mini(5, lineup.size()):
		# 源 pvp.lua initDefandHeroList readhero.createIconByID(id) 按玩家英雄实例取
		# rank/stars → 框档随实际品质（2026-08-22 巡检订正：旧恒 rank=1/stars=0 档显错；
		# lineup 存 tid，反查实例，无实例（已分解等）降级默认）。
		var hero: HeroInstance = _player.hero_manager.find_hero_by_tid(int(lineup[i]))
		if hero != null:
			(_lineup_slots[i] as Control).add_child(ReadheroIcon.create_icon_by_hero(hero, _cm))
		else:
			var fallback := ReadheroIcon.new()
			fallback.setup({"id": int(lineup[i]), "rank": 1, "stars": 0}, _cm)
			(_lineup_slots[i] as Control).add_child(fallback)


func _on_set_lineup() -> void:
	var team_tids: Array = []
	for inst_id in _player.team:
		var hero: HeroInstance = _player.hero_manager.get_hero(inst_id)
		if hero != null:
			team_tids.append(hero.tid)
	_ladder.handle({"_set_lineup": {"lineup": team_tids}}, _player, _cm, _rng, int(Time.get_unix_time_from_system()))
	Toast.show_message("防守阵容已更新")
	_fill_challenge_tab()


# ── 覆盖层 1：排行榜（20 NPC 假榜 + self 行）── 源 initRankListData :1833-1850 + createRankInfo
func _fill_rankboard_tab() -> void:
	_clear_host(_rankboard_host)
	var reply: Dictionary = _ladder.handle({"_query_rankboard": true}, _player, _cm, _rng, 0)
	var data: Dictionary = reply["_query_rankboard"]
	var rank_list: Array = data["rank_list"]
	for i in rank_list.size():
		var entry: Dictionary = rank_list[i]
		var row := LadderRows.make_rank_row(i + 1, "%s Lv%d" % [String(entry["name"]), int(entry["level"])])
		row.position.y = LadderRows.rank_row_y(i + 1)
		_rankboard_host.add_child(row)
	# 自己的排名（源 L1957 PVP.MY_RANK_(我的排名:)；20 假榜后附行，现状行为保留）。
	var sr: Dictionary = data["self_rank"]
	var self_row := LadderRows.make_rank_row(rank_list.size() + 1, "★ %s%d %s Lv%d" % [_cm.get_lstr("PVP.MY_RANK_"), int(data["pos"]), String(sr["name"]), int(sr["level"])])
	self_row.position.y = LadderRows.rank_row_y(rank_list.size() + 1)
	_rankboard_host.add_child(self_row)
	var count: int = rank_list.size() + 1
	_rankboard_host.custom_minimum_size = Vector2(LadderRows.RANK_CLIP_W, LadderRows.rank_total_height(count))


# ── 覆盖层 2：战斗记录 ── 源 initRecordData :1790-1803 + createRecordInfo :1257-1468
func _fill_records_tab() -> void:
	_clear_host(_records_host)
	var reply: Dictionary = _ladder.handle({"_query_records": true}, _player, _cm, _rng, 0)
	var records: Array = reply["_query_records"]["records"] as Array
	if records.is_empty():
		var empty := Label.new()
		empty.text = "暂无战斗记录"
		empty.theme_type_variation = "LadderDarkLabel20"
		empty.position = Vector2(100.0, LadderRows.REC_ROW_FIRST_Y)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_records_host.add_child(empty)
		_records_host.custom_minimum_size = Vector2(LadderRows.REC_CLIP_W, 0.0)
		return
	for i in records.size():
		_records_host.add_child(LadderRows.make_record_row(records[i] as Dictionary, i, _cm))
	# 源 initListHeight = 78n + 20（:1802，2026-08-18 审查 Important：旧 199+78n 混入场景空间基准）。
	_records_host.custom_minimum_size = Vector2(LadderRows.REC_CLIP_W, LadderRows.REC_ROW_STEP * float(records.size()) + LadderRows.REC_ROW_TAIL)


func _on_challenge(oppo_user_id: int) -> void:
	if int(_ladder.pvp["left_count"]) <= 0:
		Toast.show_message("挑战次数不足")
		return
	var now: int = int(Time.get_unix_time_from_system())
	var asm: Dictionary = LadderBattle.assemble_pvp_battle(_ladder, oppo_user_id, _player, _cm, _rng, now)
	if not bool(asm.get("ok", false)):
		Toast.show_message("挑战失败（阵容为空或对手无效）")
		return
	GameData.battle_context = {"engine": asm["engine"], "mode": "pvp", "mgr": _ladder, "battle_info": asm["battle_info"]}
	remove_window()
	SceneManager.change_scene(BATTLE_SCENE_PATH)


# 兑换奖励（源 :1864-1866 pvpShop → ed.ui.shop.create(5)）。
func _on_open_shop() -> void:
	MainSceneEntryRouter.open_shop(get_parent(), 5)


# 规则说明（源 :1826-1832 showRewardInfo → rewardInfoPanelLayer）。
func _on_show_rules() -> void:
	var popup := LadderRulesPopup.new()
	popup.setup_panel(_cm, int(_ladder.pvp["rank"]))
	popup.show_window(get_parent())


func _on_refresh() -> void:
	_ladder.handle({"_apply_opponent": true}, _player, _cm, _rng, int(Time.get_unix_time_from_system()))
	_fill_challenge_tab()
