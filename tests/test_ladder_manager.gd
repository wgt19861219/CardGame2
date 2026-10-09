extends GutTest
# LadderManager 单测（2026-07-09 P0-9 阶段 1）。验 AI 生成 + handle 子命令 + pvp 状态。
# before_all 真实 ConfigManager.load_all（PVPEmeny/Unit/GradientPrice 表）+ PlayerData 默认。

var cm: ConfigManager
var player: PlayerData


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	player = PlayerData.new(cm)
	player.apply_default_data()


func test_generate_ai_player_structure() -> void:
	var a: Dictionary = LadderManager.generate_ai_player(100, 50, cm, BattleRng.new(1))
	assert_eq(int(a["user_id"]), 10100, "user_id = 10000+rank")
	assert_eq(int(a["rank"]), 100, "rank 保留")
	assert_true((a["heroes"] as Array).size() >= 3, "fallback Unit 至少 3 英雄（PVPEmeny 无 Hero 字段）")
	assert_true(int(a["gs"]) > 0, "gs > 0")
	assert_eq(int(a["is_robot"]), 1, "is_robot 标记")


func test_generate_ai_opponents_sorted() -> void:
	var opps: Array = LadderManager.generate_ai_opponents(1000, 50, 3, cm, BattleRng.new(2))
	assert_eq(opps.size(), 3, "3 对手")
	for i in range(1, opps.size()):
		assert_true(int(opps[i - 1]["rank"]) <= int(opps[i]["rank"]), "rank 升序（targetRank = rank-50*i）")


func test_handle_open_panel() -> void:
	var lm := LadderManager.new()
	var reply: Dictionary = lm.handle({"_open_panel": true}, player, cm, BattleRng.new(3), 0)
	assert_true(reply.has("_open_panel"), "返 _open_panel")
	assert_eq(int(reply["_open_panel"]["left_count"]), 10, "left_count=10（基础次数，2026-10-09 拍板 5→10）")
	assert_eq((reply["_open_panel"]["oppos"] as Array).size(), 3, "3 opponents")


func test_handle_end_battle_victory_rank_swap() -> void:
	var lm := LadderManager.new()
	lm.ensure_pvp()
	lm.pvp["rank"] = 1001
	lm.pvp["last_oppo_rank"] = 500  # 模拟 start_battle 设的对手 rank
	var reply: Dictionary = lm.handle({"_end_battle": {"result": "victory"}}, player, cm, BattleRng.new(4), 0)
	assert_eq(str(reply["_end_battle"]["result"]), "victory", "victory 结果")
	assert_eq(int(reply["_end_battle"]["rank"]), 500, "排名互换到 oppo_rank（500<1001）")
	assert_eq(int(reply["_end_battle"]["prev_rank"]), 1001, "prev_rank = 旧 rank")
	assert_true(int(reply["_end_battle"]["reward"]) > 0, "奖励 > 0")
	assert_true(player.arena_point > 0, "arenapoint 累加（addPvpMoney→pd.add_point）")
	assert_eq(int(lm.pvp["highest_rank"]), 500, "highest_rank 更新")


func test_handle_end_battle_defeat_no_swap() -> void:
	var lm := LadderManager.new()
	lm.ensure_pvp()
	lm.pvp["rank"] = 1001
	var reply: Dictionary = lm.handle({"_end_battle": {"result": "defeat"}}, player, cm, BattleRng.new(6), 0)
	assert_eq(str(reply["_end_battle"]["result"]), "defeat", "defeat 结果")
	assert_eq(int(reply["_end_battle"]["rank"]), 1001, "排名不变")
	assert_eq(int(reply["_end_battle"]["reward"]), 0, "无奖励")


func test_handle_buy_battle_chance() -> void:
	# 2026-10-09 用户拍板照源 UI 语义：购买后回满 5 次（buyPvpTimesRsp leftTime=5 +
	# 文案「增加5次挑战机会」；local_server +1 系源内部矛盾不仿）。
	var lm := LadderManager.new()
	lm.ensure_pvp()
	lm.handle({"_query_records": true}, player, cm, BattleRng.new(5), 0)  # 消化首开每日重置
	lm.pvp["left_count"] = 0   # 源购买入口仅 0 次可达（:3129），从打空态买
	var diamond_before: int = player.diamond
	var reply: Dictionary = lm.handle({"_buy_battle_chance": true}, player, cm, BattleRng.new(5), 0)
	assert_eq(str(reply["_buy_battle_chance"]["result"]), "success", "购买成功")
	assert_eq(player.diamond, diamond_before - 50, "扣 50 钻（GradientPrice PVP Buy row1）")
	assert_eq(int(reply["_buy_battle_chance"]["left_count"]), 10, "left_count 回满 10（基础次数改 10 后回满口径）")
	assert_eq(int(lm.pvp["buy_times"]), 1, "buy_times 0→1")


func test_handle_query_rankboard_npc() -> void:
	var lm := LadderManager.new()
	lm.ensure_pvp()
	var reply: Dictionary = lm.handle({"_query_rankboard": true}, player, cm, BattleRng.new(7), 0)
	assert_eq((reply["_query_rankboard"]["rank_list"] as Array).size(), 20, "20 NPC 假榜")
	assert_eq(int(reply["_query_rankboard"]["pos"]), 1001, "pos = 玩家 rank")


func test_get_pvp_gs() -> void:
	var gs: int = LadderManager.get_pvp_gs(player)
	assert_true(gs >= 0, "gs 非负（英雄 gs 和）")


func test_to_from_dict_roundtrip() -> void:
	var lm := LadderManager.new()
	lm.ensure_pvp()
	lm.pvp["rank"] = 800
	var d: Dictionary = lm.to_dict()
	assert_false(d.has("arenapoint"), "arenapoint 不再归 ladder（统一 PlayerData）")
	var lm2 := LadderManager.new()
	lm2.from_dict(d)
	assert_eq(int(lm2.pvp["rank"]), 800, "rank 持久化往返")


# ── 写命令标脏（2026-09-17 清偿经济优化遗留「_cmd_end_battle 资产未标脏」）──
# T2 依赖倒置：save_hook 注入 spy 计数，断言写命令（发奖/扣次数/花钻/每日重置）
# 均内聚标脏——调用方漏存时至少有 60s 自动存盘兜底（同 midas/vitality 模式）。

func _spy_ladder() -> Array:
	var counter := [0]
	var lm := LadderManager.new()
	lm.save_hook = func() -> void: counter[0] += 1
	return [counter, lm]


func test_end_battle_victory_marks_dirty() -> void:
	var spy: Array = _spy_ladder()
	var lm: LadderManager = spy[1]
	lm.ensure_pvp()
	lm.pvp["rank"] = 1001
	lm.pvp["last_oppo_rank"] = 500
	lm.handle({"_end_battle": {"result": "victory"}}, player, cm, BattleRng.new(10), 0)
	assert_gt((spy[0] as Array)[0], 0, "victory 发奖（arenapoint/diamond）后标脏")


func test_end_battle_defeat_marks_dirty() -> void:
	var spy: Array = _spy_ladder()
	var lm: LadderManager = spy[1]
	lm.ensure_pvp()
	lm.pvp["rank"] = 1001
	lm.handle({"_end_battle": {"result": "defeat"}}, player, cm, BattleRng.new(11), 0)
	assert_gt((spy[0] as Array)[0], 0, "defeat 后（records 变更）标脏")


func test_start_battle_marks_dirty() -> void:
	var spy: Array = _spy_ladder()
	var lm: LadderManager = spy[1]
	lm.ensure_pvp()
	(lm.pvp["enemies"] as Array).append(LadderManager.generate_ai_player(900, 10, cm, BattleRng.new(12)))
	var reply: Dictionary = lm.handle({"_start_battle": {"oppo_user_id": 10000 + 900}}, player, cm, BattleRng.new(12), 0)
	assert_false((reply["_start_battle"] as Dictionary).is_empty(), "start_battle 成功")
	assert_gt((spy[0] as Array)[0], 0, "扣 left_count 后标脏")


func test_buy_and_clear_cd_mark_dirty() -> void:
	var spy: Array = _spy_ladder()
	var lm: LadderManager = spy[1]
	lm.ensure_pvp()
	player.add_diamond(1000)
	assert_eq(str(lm.handle({"_buy_battle_chance": true}, player, cm, BattleRng.new(13), 0)["_buy_battle_chance"]["result"]), "success", "购买成功前置")
	assert_gt((spy[0] as Array)[0], 0, "buy_battle_chance 花钻成功后标脏")
	(spy[0] as Array)[0] = 0
	lm.handle({"_clear_battle_cd": true}, player, cm, BattleRng.new(13), 0)
	assert_gt((spy[0] as Array)[0], 0, "clear_battle_cd 花钻成功后标脏")


func test_daily_reset_first_marks_dirty() -> void:
	var spy: Array = _spy_ladder()
	var lm: LadderManager = spy[1]
	lm.ensure_pvp()
	assert_eq(int(lm.pvp["last_reset_day"]), 0, "新号 last_reset_day=0")
	# handle 首行 _check_daily_reset：today≠0 触发重置（last_day<=0 不发邮件但重置 left_count）
	lm.handle({"_query_records": true}, player, cm, BattleRng.new(14), 1800000000)
	assert_gt((spy[0] as Array)[0], 0, "首次每日重置（无邮件路径）也标脏")


# ── 购买次数：价格梯度 + 单机特权 VIP 上限（2026-10-09 接通购买态）──

func test_buy_cost_gradient() -> void:
	# 源 pvp.lua:1869 GradientPrice[buyTime+1]["PVP Buy"]：50/100/200 递增。
	var lm := LadderManager.new()
	lm.ensure_pvp()
	assert_eq(lm.buy_cost(player), 50, "第 1 次购买 50 钻（GradientPrice[1]）")
	lm.pvp["buy_times"] = 1
	assert_eq(lm.buy_cost(player), 100, "第 2 次 100 钻（GradientPrice[2]）")
	lm.pvp["buy_times"] = 2
	assert_eq(lm.buy_cost(player), 200, "第 3 次 200 钻（GradientPrice[3]）")


func test_buy_battle_chance_vip_cap() -> void:
	# 单机特权 VIP 满档（VIP15 PVP Buy=13，player_data.privilege_vip_level 口径）：
	# buy_times 达上限后 fail 且不扣钻不加次（2026-10-09 Logic 内聚上限校验）。
	var lm := LadderManager.new()
	lm.ensure_pvp()
	# 先消化首开每日重置（now=0 → last_reset_day=19700101），防后续 handle 洗掉 buy_times。
	lm.handle({"_query_records": true}, player, cm, BattleRng.new(15), 0)
	lm.pvp["buy_times"] = 12
	assert_true(lm.can_buy_more(player), "12 次时仍可买（上限 13）")
	lm.pvp["buy_times"] = 13
	assert_false(lm.can_buy_more(player), "13 次=单机特权档上限")
	var diamond_before: int = player.diamond
	var reply: Dictionary = lm.handle({"_buy_battle_chance": true}, player, cm, BattleRng.new(15), 0)
	assert_eq(str(reply["_buy_battle_chance"]["result"]), "fail", "超上限拒绝")
	assert_eq(player.diamond, diamond_before, "不扣钻")
	assert_eq(int(lm.pvp["left_count"]), 10, "不加次数")
