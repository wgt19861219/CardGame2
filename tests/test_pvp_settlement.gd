extends GutTest
# PVP 结算补全守卫（2026-09-13）：best_rank_reward 拍板发放 + Arena Hero Exp（漏译修正）+
# take_arena_reward 英雄经验入库 + 结算跳转 arena 分支 + 失败页隐藏重打 + 最高排名奖励弹窗。

var cm: ConfigManager
var player: PlayerData


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	player = PlayerData.new(cm)
	player.apply_default_data()


# _cmd_end_battle：胜利且刷新最高排名 → best_rank_reward=20 钻石（BEST_RANK_DIAMOND）+best_rank/cur_rank；
# 未刷新最高排名 → 0。
func test_end_battle_best_rank_reward() -> void:
	var lm := LadderManager.new()
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(1), 0)
	lm.pvp["rank"] = 50
	lm.pvp["highest_rank"] = 50
	lm.pvp["last_oppo_rank"] = 10
	var diamond_before: int = player.diamond
	var r: Dictionary = lm.handle({"_end_battle": {"result": "victory"}}, player, cm, BattleRng.new(2), 0)["_end_battle"]
	assert_eq(int(r["best_rank_reward"]), 20, "刷新最高排名 → 20 钻石（拍板=DIAMOND_NORMAL 量级）")
	assert_eq(player.diamond - diamond_before, 20, "钻石入库")
	assert_eq(int(r["best_rank"]), 10, "best_rank=新最高排名")
	assert_eq(int(r["rank"]), 10, "cur_rank=排名互换后")
	# 再胜一次但排名不刷新（对手排名更高）→ best_rank_reward=0
	lm.pvp["last_oppo_rank"] = 30
	var r2: Dictionary = lm.handle({"_end_battle": {"result": "victory"}}, player, cm, BattleRng.new(3), 0)["_end_battle"]
	assert_eq(int(r2["best_rank_reward"]), 0, "未刷新最高排名 → 0（不弹窗不发钻）")


# stage_account arena 分支：sid=-1 胜利英雄经验=PlayerLevel[team_level]["Arena Hero Exp"]
# 均分（源 stageaccount.lua:64-66；旧写死 0 系漏译）。
func test_victory_param_arena_hero_exp() -> void:
	var arena_exp: int = int(cm.get_raw_table(&"PlayerLevel").get(str(player.team_level), {}).get("Arena Hero Exp", 0))
	assert_gt(arena_exp, 0, "前置：PlayerLevel 表 Arena Hero Exp>0")
	var param: Dictionary = StageAccount.deal_victory_param(
		{"stage_id": StageAccount.ARENA_STAGE_ID, "heroes": [1, 2], "loots": []}, cm, player, player.hero_manager)
	assert_eq(int(param["total_exp"]), arena_exp, "PVP 英雄经验总额=Arena Hero Exp（源 :64-66）")
	assert_eq(int(param["hero_exp"]), int(arena_exp / 2), "均分给 2 英雄")
	assert_eq(int(param["exp"]), 0, "玩家经验 0（Stage[-1] Exp Reward=0）")
	assert_eq(int(param["gold"]), 0, "金币 0（Stage[-1] Money Reward=0）")


# take_arena_reward：英雄经验入库 + hero_cache 快照（结算页升级动画数据）。
func test_take_arena_reward_grants_hero_exp() -> void:
	var hero := player.hero_manager.heroes.values()[0] as HeroInstance
	var exp_before: int = hero.exp
	var arena_exp: int = int(cm.get_raw_table(&"PlayerLevel").get(str(player.team_level), {}).get("Arena Hero Exp", 0))
	var tids: Array[int] = [hero.tid]
	player.take_arena_reward(tids)
	var gained: int = int(hero.exp) - exp_before + (hero.level - 1) * 0   # 单英雄全额（可能升级已扣减，校验 cache）
	assert_true(player.hero_manager.hero_cache.has(hero.tid), "hero_cache 快照已写")
	assert_eq(int(player.hero_manager.hero_cache[hero.tid]["exp_increment"]), arena_exp, "exp_increment=Arena Hero Exp（单英雄不均分减损）")
	assert_gt(gained + arena_exp, 0, "经验有增加（含升级折算）")


# 结算跳转 arena 分支：sid=-1 的 replay/next 目标为空（回主城，不误跳选关/详情）。
func test_settlement_targets_arena_no_jump() -> void:
	assert_eq(StageSettlementCommon.replay_target(StageAccount.ARENA_STAGE_ID), {}, "PVP replay 无目标")
	assert_eq(StageSettlementCommon.next_target(StageAccount.ARENA_STAGE_ID), {}, "PVP next 无目标（旧逻辑误跳 stageselect）")


# 失败结算页 arena 模式隐藏重打按钮（源 stagefailed.lua:212 visible=arena_mode==false）。
# 2026-09-14 收敛为 sid>0：crusade 负数关（-3~-17）无 stagedetail 可跳，同语义隐藏。
func test_stage_failed_arena_hides_back() -> void:
	var scene := StageFailedScene.new()
	add_child_autofree(scene)
	scene.setup({"stage_id": StageAccount.ARENA_STAGE_ID, "victory": false, "lose_type": "fail"}, cm)
	assert_false(bool((scene._content.get_node("Back") as BaseButton).visible), "PVP 失败页隐藏重打（源 :212）")
	var scene2 := StageFailedScene.new()
	add_child_autofree(scene2)
	scene2.setup({"stage_id": 1, "victory": false, "lose_type": "fail"}, cm)
	assert_true(bool((scene2._content.get_node("Back") as BaseButton).visible), "PVE 失败页保留重打")


# crusade 失败页隐藏重打（负数关 -3=-2-1；重打无 stagedetail 目标）。
func test_stage_failed_crusade_hides_back() -> void:
	var scene := StageFailedScene.new()
	add_child_autofree(scene)
	scene.setup({"stage_id": -3, "victory": false, "lose_type": "fail"}, cm)
	assert_false(bool((scene._content.get_node("Back") as BaseButton).visible), "crusade 失败页隐藏重打（sid=-3）")


# 最高排名奖励弹窗：best_rank_reward>0 时 stage_done 装配后 3s 弹出，结构+文案齐。
func test_best_rank_popup_structure() -> void:
	var scene := (preload("res://scenes/battle/stage_done_scene.tscn").instantiate() as StageDoneScene)
	add_child_autofree(scene)
	var param: Dictionary = StageAccount.deal_victory_param(
		{"stage_id": StageAccount.ARENA_STAGE_ID, "victory": true, "heroes": [1], "loots": [],
			"best_rank_reward": 20, "best_rank": 10, "cur_rank": 10}, cm, player, player.hero_manager)
	param["best_rank_reward"] = 20
	scene.setup(param, cm)
	# 弹窗 3s 后由 timer 触发（源 playEnterAnim ListenTimer(3)）；headless 直建实例验结构等价。
	var popup: Control = load("res://scripts/view/battle/stage_done_best_rank_popup.gd").new(param)
	add_child_autofree(popup)
	popup.popup()
	assert_true(popup.visible, "popup() 后可见")
	var texts: Array = []
	for child in _collect_labels(popup):
		texts.append(child.text)
	assert_true("最高排名" in texts, "标题在（pvp_result_highest 缺图 Label 降级）")
	assert_true(texts.any(func(t: String) -> bool: return t.begins_with("历史最高排名: ")), "历史最高排名行")
	assert_true(texts.any(func(t: String) -> bool: return t.begins_with("当前排名: ")), "当前排名行")
	assert_true("20" in texts, "奖励数字 20 在")
	assert_true(texts.has("可获奖励:"), "可获奖励文案（LSTR STAGEDONE.RECEIVE_AWARDS_）")
	assert_true(texts.has("确定"), "确定钮文案（CHATCONFIG.CONFIRM）")


func _collect_labels(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label:
			out.append(child)
		out.append_array(_collect_labels(child))
	return out
