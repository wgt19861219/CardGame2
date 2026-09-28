extends GutTest
# 竞技场每日排名奖励（2026-09-17 经济单机优化）：PVPRankReward 死表接入 + 系统邮件发放
# + MailData _points 附件扩展。源为服务器每日结算邮件下发。

var cm: ConfigManager

const TS_DAY1_NOON: int = 1800000000
const TS_DAY2_NOON: int = TS_DAY1_NOON + 86400


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func make_player() -> PlayerData:
	var pd := PlayerData.new(cm)
	pd.apply_default_data()   # 含 2 封初始系统邮件
	return pd


# ---- 查表映射（Floor Rank 升序区段）----

func test_reward_row_top_rank() -> void:
	var row: Dictionary = LadderDailyReward.reward_row(1, cm)
	assert_eq(int(row.get("Floor Rank", 0)), 1, "rank 1 → 首档")
	assert_eq(int(row.get("Reward Amount 1", 0)), 550, "首档钻石 550（源表值）")


func test_reward_row_tail_rank() -> void:
	# 表 Floor Rank 35 档区段制（1-10 连续 + 20/30/…/100000 大区段）：取 <=rank 的最大档
	var rank: int = 1001   # RANK_INIT 新号排名
	var expected_floor: int = 0
	for key in cm.get_raw_table(&"PVPRankReward"):
		var floor: int = int(cm.get_raw_table(&"PVPRankReward")[key].get("Floor Rank", 0))
		if floor <= rank:
			expected_floor = maxi(expected_floor, floor)
	var row: Dictionary = LadderDailyReward.reward_row(rank, cm)
	assert_eq(int(row.get("Floor Rank", 0)), expected_floor, "rank 1001 → 落入 <=rank 最大档")
	var row_top: Dictionary = LadderDailyReward.reward_row(100000, cm)
	assert_eq(int(row_top.get("Floor Rank", 0)), 100000, "超末档 rank → 取末档行")


func test_reward_row_mid_rank_segment() -> void:
	# rank 2 落在 [Floor 2, Floor 3) 区段 → 行 2
	var row: Dictionary = LadderDailyReward.reward_row(2, cm)
	assert_eq(int(row.get("Floor Rank", 0)), 2, "rank 2 → Floor 2 档")


# ---- 邮件构造（附件槽分发）----

func test_build_mail_slots() -> void:
	var mail: Dictionary = LadderDailyReward.build_mail(1, 99, cm, TS_DAY1_NOON)
	assert_false(mail.is_empty(), "有表 → 邮件生成")
	assert_eq(int(mail["_diamonds"]), 550, "Diamond 槽 → _diamonds")
	assert_eq(int(mail["_money"]), 100000, "Gold 槽 → _money")
	assert_eq(int((mail["_points"] as Dictionary).get("arenapoint", 0)), 800, "ArenaPoint 槽 → _points")
	var item_ids: Array = []
	for item in mail["_items"]:
		item_ids.append(int(item["id"]))
	assert_has(item_ids, 290, "Item 槽 290 进 _items")
	assert_has(item_ids, 369, "Item 槽 369 进 _items")
	assert_eq(String(mail["_date"]), LadderDailyReward._date_str(TS_DAY1_NOON), "日期本地时区口径")


# ---- LadderManager 跨日发放（handle 路径）----

func test_handle_first_open_no_reward() -> void:
	var player := make_player()
	var lm := LadderManager.new()
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(1), TS_DAY1_NOON)
	assert_eq(player.mailbox.ordered_mails().size(), 2, "首次打开（last_reset_day=0）只重置不发奖（保留 2 封初始邮件）")


func test_handle_cross_day_issues_reward_mail_once() -> void:
	var player := make_player()
	var lm := LadderManager.new()
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(2), TS_DAY1_NOON)   # day1 落锚
	var mails_day1: int = player.mailbox.ordered_mails().size()
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(3), TS_DAY2_NOON)  # 跨日 → 发奖
	var mails_day2: int = player.mailbox.ordered_mails().size()
	assert_eq(mails_day2, mails_day1 + 1, "跨日发 1 封奖励邮件")
	var reward_mail: Dictionary = player.mailbox.get_mail(player.mailbox.next_mail_id() - 1)
	assert_eq(String(reward_mail["name"]), "竞技场每日奖励", "奖励邮件标题")
	assert_true(int(reward_mail["diamond"]) > 0, "附件含钻石")
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(4), TS_DAY2_NOON + 3600)   # 同日再开
	assert_eq(player.mailbox.ordered_mails().size(), mails_day2, "同日不重复发")


func test_reward_mail_reflects_rank() -> void:
	var player := make_player()
	var lm := LadderManager.new()
	lm.ensure_pvp()
	lm.pvp["last_reset_day"] = 0
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(5), TS_DAY1_NOON)
	lm.pvp["rank"] = 1   # 打到第 1 名
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(6), TS_DAY2_NOON)
	var mail: Dictionary = player.mailbox.get_mail(player.mailbox.next_mail_id() - 1)
	assert_eq(int(mail["diamond"]), 550, "rank 1 → 550 钻（表首档）")


# ---- MailData _points 附件（format 展示 + claim 入账）----

func test_format_mail_point_attach_common() -> void:
	var md := MailData.new()
	md.add_system_mail({
		"_id": 50, "_status": "unread", "_date": "2027-01-15",
		"_content": {"_plain_mail": {"_from": "竞技场", "_title": "t", "_content": "c"}},
		"_money": 0, "_diamonds": 0, "_skill_point": 0,
		"_points": {"arenapoint": 800}, "_items": [],
	})
	var shown: Dictionary = md.format_mail(md._find_raw(50))
	assert_true(bool(shown["attached"]), "points 附件计入 attached")
	var types: Array = []
	for entry in shown["attach_common"]:
		types.append(String(entry["type"]))
	assert_has(types, "PvpMoney", "arenapoint → View 7 货币口径 PvpMoney（源 content.lua 图标映射）")


func test_claim_attach_points_credit_arena_point() -> void:
	var player := make_player()
	var md := MailData.new()
	md.add_system_mail({
		"_id": 51, "_status": "unread", "_date": "2027-01-15",
		"_content": {"_plain_mail": {"_from": "竞技场", "_title": "t", "_content": "c"}},
		"_money": 100, "_diamonds": 10, "_skill_point": 0,
		"_points": {"arenapoint": 800}, "_items": [],
	})
	var arena_before: int = player.arena_point
	var diamond_before: int = player.diamond
	md.claim_attach(51, player)
	assert_eq(player.arena_point, arena_before + 800, "arenapoint 入账（add_point 通道）")
	assert_eq(player.diamond, diamond_before + 10, "钻石附件照常入账")


func test_mail_id_generation() -> void:
	var md := MailData.new()
	var first: int = md.next_mail_id()
	assert_gt(first, 0, "初始邮件存在 → id > 0")
	md.add_system_mail({"_id": first, "_status": "unread", "_date": "d",
		"_content": {"_plain_mail": {"_from": "f", "_title": "t", "_content": "c"}},
		"_money": 0, "_diamonds": 0, "_skill_point": 0, "_points": {}, "_items": []})
	assert_eq(md.next_mail_id(), first + 1, "追加后 id 递增")


# P2-2（2026-09-28 审查）：系统时间回拨不重发奖励——重置/发奖只进不退（today < last_day 直接忽略）。
func test_handle_clock_rollback_no_reward() -> void:
	var player := make_player()
	var lm := LadderManager.new()
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(7), TS_DAY2_NOON)   # day2 落锚
	var mails_before: int = player.mailbox.ordered_mails().size()
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(8), TS_DAY1_NOON)  # 回拨到 day1
	assert_eq(player.mailbox.ordered_mails().size(), mails_before, "回拨日不重置不重发")
	var left_before: int = int(lm.pvp.get("left_count", 0))
	var buys_before: int = int(lm.pvp.get("buy_times", 0))
	lm.pvp["left_count"] = 0
	lm.pvp["buy_times"] = 3
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(9), TS_DAY1_NOON)  # 再次回拨
	assert_eq(int(lm.pvp["left_count"]), 0, "回拨也不回满挑战次数（防回拨刷重置）")
	assert_eq(int(lm.pvp["buy_times"]), 3, "购买次数同样不重置")
	lm.pvp["left_count"] = left_before
	lm.pvp["buy_times"] = buys_before
