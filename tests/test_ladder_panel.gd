extends GutTest
## ladder_panel 两件套改造守卫（批4 Task 9，2026-08-18）。
## 源诊断（pvp.lua 3294 行实为 6 panelLayer，本项目消费 3 层）：
##   mainPanelLayer(:1933-3050 挑战+防守阵容两 tab 的源) / rankPanelLayer(:1601 排行弹层)
##   / recordPanelLayer(:1702 记录弹层)；heroInfoLayer/rewardPanelLayer/rewardInfoPanelLayer
##   未迁移（批5 长尾披露）。
## 坐标照源直译：to_godot(x,y)=(x+80,560-y)；贴图显示尺寸=像素÷1.28125（pvp 系无
## TextureConfig 条目）；卡内/行内子坐标点值直译 y'=H-y。

const CONTENT_PATH: String = "res://scenes/ui/ladder_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/ladder_panel.gd"
const THEME_PATH: String = "res://resources/themes/default_theme.tres"

var _cm: ConfigManager
var _player: PlayerData


func before_all() -> void:
	_cm = ConfigManager.new()
	_cm.load_all()
	_player = PlayerData.new(_cm)
	_player.apply_default_data()


func _content() -> Control:
	var scene: PackedScene = load(CONTENT_PATH) as PackedScene
	var c: Control = scene.instantiate() as Control
	add_child_autofree(c)
	return c


# ── 静态树：主框架（源 createMainLayer mainUIRes 直译）──

func test_content_static_tree() -> void:
	var c := _content()
	for node_name in ["PvpFrame", "CloseBtn", "TabBtn0", "TabBtn1", "TabBtn2", "TabBtn3",
			"TabChallengeView", "TabRankboardView", "TabRecordsView", "TabLineupView",
			"EnemyCard1", "EnemyCard2", "EnemyCard3", "RefreshBtn", "BuyBtn",
			"RankScroll", "RecScroll", "HeroSlot1", "HeroSlot5", "SetLineupBtn"]:
		assert_not_null(c.get_node_or_null(NodePath("%" + node_name)), "%s 存在" % node_name)


func test_pvp_frame_rect() -> void:
	# 源 pvpBg pvp_frame.png anchor(0.5,0.5) pos(400,210) → Godot 中心 (480,350)；
	# 936×506px ÷1.28125 = 730.2×394.9。
	var c := _content()
	var frame: Control = c.get_node("%PvpFrame") as Control
	assert_almost_eq(frame.position.x + frame.size.x / 2.0, 480.0, 0.5, "pvp_frame 中心 x=480")
	assert_almost_eq(frame.position.y + frame.size.y / 2.0, 350.0, 0.5, "pvp_frame 中心 y=350")
	assert_almost_eq(frame.size.x, 730.2, 0.5, "pvp_frame 宽 936/CS")
	assert_almost_eq(frame.size.y, 394.9, 0.5, "pvp_frame 高 506/CS")


func test_enemy_cards_rect() -> void:
	# 源 enemy1-3Bg pvp_enemy_bg.png pos(290/475/660,130)（默认中心锚）→ 中心
	# (370/555/740,430)；216×268px ÷CS = 168.6×209.3。
	var c := _content()
	var xs: Array[float] = [370.0, 555.0, 740.0]
	for i in 3:
		var card: Control = c.get_node("%EnemyCard" + str(i + 1)) as Control
		assert_almost_eq(card.position.x + card.size.x / 2.0, xs[i], 0.5, "卡%d 中心 x" % (i + 1))
		assert_almost_eq(card.position.y + card.size.y / 2.0, 430.0, 0.5, "卡%d 中心 y" % (i + 1))
		assert_almost_eq(card.size.x, 168.6, 0.5, "卡%d 宽 216/CS" % (i + 1))
		assert_almost_eq(card.size.y, 209.3, 0.5, "卡%d 高 268/CS" % (i + 1))


func test_enemy_card_children() -> void:
	# 源卡内结构：icon(84,162)/iconFrame/icon level bg(60,138)/Id(84,111)/Rank(51,86)
	# /RankValue(120,86)/Gps(56,63)/GpsValue(120,63)/challengeEnemy(84,26 90×48)。
	var c := _content()
	var card: Control = c.get_node("%EnemyCard1") as Control
	# 卡内子节点为重复结构（3 卡同名）不开 unique_name，按相对名查。
	for child_name in ["EnemyBg", "HeadBg", "HeadHost", "LevelBg", "LevelLbl", "NameLbl",
			"RankLbl", "RankVal", "GpsLbl", "GpsVal", "ChallengeBtn"]:
		assert_not_null(card.get_node_or_null(child_name), "卡内 %s 存在" % child_name)
	var btn: Control = card.get_node("ChallengeBtn") as Control
	assert_almost_eq(btn.position.x + btn.size.x / 2.0, 84.0, 0.5, "挑战按钮卡内中心 x=84（源 :2513）")
	assert_almost_eq(btn.position.y + btn.size.y / 2.0, 209.3 - 26.0, 0.5, "挑战按钮卡内中心 y=209.3-26")
	assert_almost_eq(btn.size.x, 90.0, 0.5, "挑战按钮 90×48（源 scaleSize）")


func test_tab_bar_rect() -> void:
	# 源顶部按钮行 y=267（reqRankData 461/showRewardInfo 361/reqRecordBoard 558/
	# pvpShop 675）→ 4 tab 同行中心 y=293，96×48。
	var c := _content()
	var xs: Array[float] = [441.0, 541.0, 638.0, 755.0]
	for i in 4:
		var btn: Control = c.get_node("%TabBtn" + str(i)) as Control
		assert_almost_eq(btn.position.x + btn.size.x / 2.0, xs[i], 0.5, "TabBtn%d 中心 x" % i)
		assert_almost_eq(btn.position.y + btn.size.y / 2.0, 293.0, 0.5, "TabBtn%d 中心 y=293" % i)
		assert_almost_eq(btn.size.y, 48.0, 0.5, "TabBtn%d 高 48" % i)


func test_scroll_clip_rect() -> void:
	# 源 rank draglist cliprect(165,40,470,360) → (245,160,715,520)；
	# record cliprect(160,40,490,360) → (240,160,730,520)。
	var c := _content()
	var rs: Control = c.get_node("%RankScroll") as Control
	assert_almost_eq(rs.position.x, 245.0, 0.5, "rank clip x=165+80")
	assert_almost_eq(rs.position.y, 160.0, 0.5, "rank clip top=560-(40+360)")
	assert_almost_eq(rs.size.x, 470.0, 0.5, "rank clip 宽 470")
	assert_almost_eq(rs.size.y, 360.0, 0.5, "rank clip 高 360")
	var rec: Control = c.get_node("%RecScroll") as Control
	assert_almost_eq(rec.position.x, 240.0, 0.5, "record clip x=160+80")
	assert_almost_eq(rec.size.x, 490.0, 0.5, "record clip 宽 490")


func test_lineup_static_layout() -> void:
	# 源 hero1-5 槽 (199/290/381/473/565,346) → 中心 y=214；adjustHero (675,327) → (755,233)。
	var c := _content()
	var xs: Array[float] = [279.0, 370.0, 461.0, 553.0, 645.0]
	for i in 5:
		var slot: Control = c.get_node("%HeroSlot" + str(i + 1)) as Control
		assert_almost_eq(slot.position.x + slot.size.x / 2.0, xs[i], 0.5, "HeroSlot%d 中心 x" % (i + 1))
		assert_almost_eq(slot.position.y + slot.size.y / 2.0, 214.0, 0.5, "HeroSlot%d 中心 y=214" % (i + 1))
	var btn: Control = c.get_node("%SetLineupBtn") as Control
	assert_almost_eq(btn.position.x + btn.size.x / 2.0, 755.0, 0.5, "调整按钮中心 x=755（源 :2947）")
	assert_almost_eq(btn.position.y + btn.size.y / 2.0, 233.0, 0.5, "调整按钮中心 y=233（源 :2947）")


# ── 范式守卫：UiScale9Button 退役 + variation 注册 ──

func test_panel_no_runtime_scale9() -> void:
	var script_text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(script_text.count("UiScale9Button"), 0, "ladder_panel 不再运行时套 Scale9 StyleBox（两件套范式）")


func test_theme_ladder_variations_registered() -> void:
	# GUT 下 get_theme 不解析 variation（批4 约束）→ 读 tres 文本表项。
	var theme_text: String = FileAccess.get_file_as_string(THEME_PATH)
	for v in ["LadderTabButton", "LadderChangeButton", "LadderWideButton",
			"LadderDarkLabel20", "LadderOrangeLabel20", "LadderTitleLabel24",
			"LadderBtnLabel17", "LadderChangeBtnLabel17", "LadderWhiteShadowLabel20"]:
		assert_true(theme_text.contains(v + "/base_type"), "%s variation 已注册" % v)


# ── fill 语义（panel 业务数据绑定）──

func _panel() -> LadderPanel:
	var panel: LadderPanel = LadderPanel.new("ladder", {})
	panel.setup_panel(_player, _cm, BattleRng.new(9))
	add_child_autofree(panel)
	return panel


# % 唯一名 owner 是 content 场景（panel.container.get_child(0)），从 content 解析。
func _panel_content(panel: LadderPanel) -> Control:
	return panel.container.get_child(0) as Control


func test_fill_challenge_tab_smoke() -> void:
	var panel := _panel()
	var view: Control = _panel_content(panel).get_node("%TabChallengeView") as Control
	var name_lbl: Label = (view.get_node("%EnemyCard1") as Control).get_node("NameLbl") as Label
	assert_true(name_lbl.text.length() > 0, "对手 1 名字已 fill")
	var rank_val: Label = view.get_node("%RankValue") as Label
	assert_true(rank_val.text.is_valid_int(), "我的排名数字已 fill")
	var left_num: Label = view.get_node("%LeftTimeNum") as Label
	assert_true(left_num.text.contains("/"), "剩余次数 x/5 已 fill（源 :3153 %d/%d 格式）")


func test_fill_rankboard_rows() -> void:
	var panel := _panel()
	panel._fill_tab(1)
	var host: Control = _panel_content(panel).get_node("%RankboardHost") as Control
	# 20 NPC 行 + self 行（现状行为保留，用例数不缩水）
	assert_eq(host.get_child_count(), 21, "20 榜行 + 1 self 行")
	var row0: Control = host.get_child(0) as Control
	assert_not_null(row0.get_node_or_null(^"RankBg"), "行内底图节点存在（源 rankBg 分档底图）")
	# 源行步进 78（rankFrameHeight70+8，initRankListData :1846）；源 cocos y 向上 i 增 y 减=行向下
	# → Godot y 向下直接 +78（2026-08-18 审查 Critical：旧断言 row0-row1==78 把倒序固化进守卫）。
	var row1: Control = host.get_child(1) as Control
	assert_almost_eq(row1.position.y - row0.position.y, 78.0, 0.5, "行步进 70+8（下行 y 更大）")
	assert_lt(row0.position.y, row1.position.y, "第 1 名在最上（源 i 增 y 减=向下直译）")
	for c in host.get_children():
		assert_gt(c.position.y, -0.01, "全部行 y>=0（ScrollContainer 滚不到负 y，旧实现 18 行永不可见）")


func test_rankboard_row_y_formula_and_total_height() -> void:
	# 源 initRankListData :1843-1848 直译守卫：行中心 = 39 + 78*(min(10,i)-1) + 58*max(0,i-10)
	# + (i>10 ? 8 : 0)（39 = clip 顶 cocos 400 − 首行底图中心 361，host 局部空间）。
	var panel := _panel()
	panel._fill_tab(1)
	var host: Control = _panel_content(panel).get_node("%RankboardHost") as Control
	var prev_y: float = -1.0
	for i in host.get_child_count():
		var row: Control = host.get_child(i) as Control
		assert_almost_eq(row.position.y, panel._rank_row_y(i + 1), 0.01, "行 %d y 与源公式一致" % (i + 1))
		if i > 0:
			assert_gt(row.position.y, prev_y, "行 %d 在上一行下方（y 单调递增）" % (i + 1))
		prev_y = row.position.y
	# 关键样本：#1 顶=39-35=4 / #3 顶=39+156-35=160 / #21 中心=39+702+638+8=1387
	assert_almost_eq((host.get_child(0) as Control).position.y, 4.0, 0.5, "row#1 y=4")
	assert_almost_eq((host.get_child(2) as Control).position.y, 160.0, 0.5, "row#3 y=160")
	assert_almost_eq((host.get_child(20) as Control).position.y, 1387.0 - 25.0, 0.5, "row#21 y=1362")
	# 源 totalHeight = 78*10 + 58*11 = 1418（:1848 无 adjust 项）
	assert_almost_eq(host.custom_minimum_size.y, 1418.0, 0.5, "rank host 内容高 1418 照源")


func test_record_row_scale_size_and_content_height() -> void:
	# 源 createRecordInfo highlightbg scaleSize=CCSizeMake(485,70)（:1271-1280 点值直译）；
	# initListHeight = 78n+20（:1802）。
	var panel := _panel()
	panel._ladder.pvp["records"] = [{"result": "victory", "time": 100, "rank": 50}]
	panel._fill_tab(2)
	var host: Control = _panel_content(panel).get_node("%RecordsHost") as Control
	var row: Control = host.get_child(0) as Control
	assert_almost_eq(row.size.x, 485.0, 0.5, "记录行宽 485（源 scaleSize）")
	assert_almost_eq(row.size.y, 70.0, 0.5, "记录行高 70（源 scaleSize）")
	assert_almost_eq(row.position.y, 39.0 - 35.0, 0.5, "记录行首行顶 y=39-35=4（基准 39）")
	assert_almost_eq(host.custom_minimum_size.y, 78.0 + 20.0, 0.5, "记录 host 内容高 78*1+20")


func test_fill_records_relative_time() -> void:
	# 源 createRecordInfo :1445-1456 相对时间（N秒/分钟/小时前/1天前）。
	var panel := _panel()
	panel._ladder.pvp["records"] = [{"result": "victory", "time": 100, "rank": 50}]
	panel._fill_tab(2)
	var host: Control = _panel_content(panel).get_node("%RecordsHost") as Control
	assert_eq(host.get_child_count(), 1, "1 记录行")
	var row: Control = host.get_child(0) as Control
	var time_lbl: Label = row.get_node(^"RecBg/TimeLbl") as Label
	assert_true(time_lbl.text.ends_with("前"), "相对时间文案（源 second2hms 逻辑）")
