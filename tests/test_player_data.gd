extends GutTest
# Step 2.4 玩家数据单测：入口 int 校验(治 float→int) + 钻石 + 体力恢复 + 等级上限 + 存档往返。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()

func test_apply_default_data_new_player() -> void:
	# 源 local_server.lua:44 DEFAULT_DATA：新玩家初始英雄/经济/物品。
	# new 后空（默认数据由 GameData._load_or_new_player 新玩家分支 apply_default_data 调，不在 _init）。
	var pd_empty := PlayerData.new(cm)
	assert_eq(pd_empty.diamond, 0)
	assert_eq(pd_empty.hero_manager.heroes.size(), 0)
	assert_eq(pd_empty.team.size(), 0)
	pd_empty.apply_default_data()
	assert_eq(pd_empty.diamond, 5000)            # 源 DEFAULT_DATA player.diamond
	assert_eq(pd_empty.hero_manager.gold, 100000)  # 源 player.gold
	assert_eq(pd_empty.hero_manager.heroes.size(), 5)  # 源 heroes tid 1-5
	assert_eq(pd_empty.team.size(), 5)            # 5 默认英雄入阵容
	assert_eq(int(pd_empty.items.get(101, 0)), 10)  # 源 items[101]=10
	assert_eq(int(pd_empty.items.get(106, 0)), 5)   # 源 items[106]=5
	# 2026-09-17 用户拍板受控偏离守卫：电魂(5) 换 小鹿(45)；新号全队 1 星
	# （源 DEFAULT_DATA stars=1 硬编码口径；旧版误走表 Initial Stars 致电魂 3 星）。
	var tids: Array[int] = []
	for inst_id in pd_empty.team:
		var h: HeroInstance = pd_empty.hero_manager.get_hero(int(inst_id))
		if h != null:
			tids.append(h.tid)
			assert_eq(h.stars, 1, "新号英雄 %d 应 1 星（源 DEFAULT_DATA 全 1 星口径）" % h.tid)
	assert_eq(tids, [1, 2, 3, 4, 45], "新号队伍=船长/DR/火女/宙斯/小鹿（电魂→小鹿受控偏离）")

func test_from_dict_no_default_residual() -> void:
	# 存档加载不残留默认数据（from_dict 不调 apply_default_data）
	var pd := PlayerData.from_dict({"diamond": 100, "team": [99], "items": {201: 3}}, cm)
	assert_eq(pd.diamond, 100)
	assert_eq(pd.team, [99])                      # 不残留默认 inst_id
	assert_eq(pd.hero_manager.heroes.size(), 0)   # 不残留默认英雄
	assert_eq(int(pd.items.get(101, 0)), 0)       # 不残留默认物品
	assert_eq(int(pd.items.get(201, 0)), 3)       # 仅存档物品

func test_int_normalization_on_load() -> void:
	# 治旧版 float→int：存档里数字可能 float，from_dict 强制 int
	var data := {
		"diamond": 5000.0, "vitality": 119.0, "team_level": 5.0,
		"team_exp": 50.5, "vitality_last_recover": 1000.0,
	}
	var pd := PlayerData.from_dict(data, cm)
	assert_eq(typeof(pd.diamond), TYPE_INT, "diamond 必须 int（治 float→int）")
	assert_eq(typeof(pd.team_level), TYPE_INT, "team_level 必须 int")
	assert_eq(pd.diamond, 5000)
	assert_eq(pd.team_level, 5)

func test_diamond_spend() -> void:
	var pd := PlayerData.new(cm)
	pd.add_diamond(1000)
	assert_true(pd.spend_diamond(300))
	assert_eq(pd.diamond, 700)
	assert_false(pd.spend_diamond(9999), "钻石不足应失败")
	assert_eq(pd.diamond, 700, "失败不扣")


# 源 playertools.lua:16-47 addPoint / :7-14 getPoint 统一货币接口（6 类型）
func test_add_point_get_point_unified() -> void:
	var pd := PlayerData.new(cm)
	pd.add_point("diamond", 1000)
	assert_eq(pd.get_point("diamond"), 1000, "add_point diamond")
	pd.add_point("diamond", -300)
	assert_eq(pd.get_point("diamond"), 700, "diamond 扣减走 spend_diamond")
	pd.add_point("crusadepoint", 500)
	assert_eq(pd.get_point("crusadepoint"), 500, "crusadepoint")
	pd.add_point("arenapoint", 300)
	assert_eq(pd.get_point("arenapoint"), 300, "arenapoint")
	pd.add_point("guildpoint", 200)
	assert_eq(pd.get_point("guildpoint"), 200, "guildpoint")
	pd.add_point("dungeonpoint", 100)
	assert_eq(pd.get_point("dungeonpoint"), 100, "dungeonpoint")
	pd.add_point("arenapoint", -50)
	assert_eq(pd.get_point("arenapoint"), 250, "arenapoint 扣减")
	assert_eq(pd.get_point("unknownpoint"), 0, "未知类型返 0")
	pd.add_point("gold", 1000)
	assert_eq(pd.get_point("gold"), 1000, "gold 走 hero_manager")


# gold 非负保护（源 player.lua:434 addMoney math.max(_money+money, 0)）
func test_add_point_gold_non_negative() -> void:
	var pd := PlayerData.new(cm)
	pd.add_point("gold", 100)
	pd.add_point("gold", -500)  # 扣超
	assert_eq(pd.get_point("gold"), 0, "gold max(0) 保护（源 addMoney）")

func test_vitality_recover_by_time() -> void:
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	pd.vitality_max = 120
	pd.vitality_last_recover = 0
	# 720s = 2 个恢复周期(360s) → 恢复 2 点
	var recovered := VitalityManager.recover(pd, 720)
	assert_eq(recovered, 2)
	assert_eq(pd.vitality, 102)

func test_vitality_capped() -> void:
	var pd := PlayerData.new(cm)
	pd.vitality = 119
	pd.vitality_max = 120
	pd.vitality_last_recover = 0
	VitalityManager.recover(pd, 99999)
	assert_eq(pd.vitality, 120, "体力不超上限")

func test_team_level_caps_at_99() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 98
	pd.add_team_exp(99999999)  # 巨量经验
	assert_eq(pd.team_level, 99, "战队等级上限 99")


func test_take_stage_reward_diamond_normal() -> void:
	# 照源 takeStageReward :1334-1338 addrmb：普通关（< ELITE_THRESHOLD 10000）钻石 20
	var pd := PlayerData.new(cm)
	pd.take_stage_reward(-27, 3, [1])   # -27 PVP 占位当普通关（< 10000）
	assert_eq(pd.diamond, 20, "普通关钻石 +20")
	# 金币/战队经验依赖 StageData 配置（-27 PVP 占位可能 0），断言不减（发奖励 ≥0）
	assert_gte(pd.hero_manager.gold, 0, "金币不减")
	assert_gte(pd.team_exp, 0, "战队经验不减")


func test_take_stage_reward_diamond_elite() -> void:
	# 精英关（stage_type elite，10001-19998）钻石 50（源 :1335）
	var pd := PlayerData.new(cm)
	pd.take_stage_reward(10001, 3, [])   # heroes 空 → 英雄经验跳过
	assert_eq(pd.diamond, 50, "精英关钻石 +50")


func test_take_stage_reward_diamond_act() -> void:
	# 活动关（stage_type act，20001-29999）钻石 100（源 :1336）
	var pd := PlayerData.new(cm)
	pd.take_stage_reward(20001, 3, [])
	assert_eq(pd.diamond, 100, "活动关钻石 +100")


func test_take_stage_reward_loots_equip() -> void:
	# 照源 :1353 type=="equip" → addEquip（本项目进 items 通用背包）
	var pd := PlayerData.new(cm)
	var loots: Array = [{"id": 390, "type": "equip"}, {"id": 390, "type": "equip"}]
	pd.take_stage_reward(-27, 3, [], loots)
	assert_eq(int(pd.items.get(390, 0)), 2, "equip 掉落 ×2 进 items")


func test_take_stage_reward_loots_hero() -> void:
	# 照源 :1351 type=="hero" → addHero（hero_manager.heroes）
	var pd := PlayerData.new(cm)
	var before: int = pd.hero_manager.heroes.size()
	pd.take_stage_reward(-27, 3, [], [{"id": 1, "type": "hero"}])
	assert_eq(pd.hero_manager.heroes.size(), before + 1, "hero 掉落进 heroes")


func test_get_sweep_times() -> void:
	# 照源 getSweepTimes：持有扫荡券 390 数量
	var pd := PlayerData.new(cm)
	assert_eq(pd.get_sweep_times(), 0, "初始无扫荡券")
	pd.add_item(390, 5)
	assert_eq(pd.get_sweep_times(), 5, "持有 5 张扫荡券")


func test_use_sweep_times() -> void:
	# 照源 useSweepTimes → consumeEquip 消耗
	var pd := PlayerData.new(cm)
	pd.add_item(390, 5)
	assert_true(pd.use_sweep_times(3), "消耗 3 张成功")
	assert_eq(pd.get_sweep_times(), 2, "剩 2 张")
	assert_false(pd.use_sweep_times(10), "不足返 false")
	assert_eq(pd.get_sweep_times(), 2, "不足不扣")

func test_save_roundtrip_preserves_state() -> void:
	var pd := PlayerData.new(cm)
	pd.add_diamond(1234)
	pd.vitality = 88
	pd.team_level = 10
	pd.hero_manager.gold = 555
	var text := var_to_str(pd.to_dict())
	var restored := PlayerData.from_dict(str_to_var(text), cm)
	assert_eq(restored.diamond, 1234)
	assert_eq(restored.vitality, 88)
	assert_eq(restored.team_level, 10)
	assert_eq(restored.hero_manager.gold, 555, "英雄管理器金币往返保真")


func test_set_avatar_updates_field() -> void:
	# 照源 local_server.lua:1837-1845 set_avatar：设 avatar 字段（本项目存档由 SaveManager 管）
	var pd := PlayerData.new(cm)
	pd.set_avatar(5)
	assert_eq(pd.avatar, 5, "set_avatar 设 avatar 字段")


func test_set_avatar_persists_roundtrip() -> void:
	# avatar 在 to_dict/from_dict 往返保真（player_data 行 372/401）
	var pd := PlayerData.new(cm)
	pd.set_avatar(42)
	var restored := PlayerData.from_dict(pd.to_dict(), cm)
	assert_eq(restored.avatar, 42, "avatar 往返保真")


func test_set_player_name_updates_field() -> void:
	# 照源 local_server.lua:1819-1833 set_name：非空名 → 设 player_name
	var pd := PlayerData.new(cm)
	pd.set_player_name("英雄")
	assert_eq(pd.player_name, "英雄", "set_player_name 设名称")


func test_set_player_name_ignores_empty() -> void:
	# 照源 :1821 空名不设（客户端已校验）
	var pd := PlayerData.new(cm)
	pd.set_player_name("原名")
	pd.set_player_name("")
	assert_eq(pd.player_name, "原名", "空名不覆盖")


func test_set_player_name_persists_roundtrip() -> void:
	var pd := PlayerData.new(cm)
	pd.set_player_name("测试名")
	var restored := PlayerData.from_dict(pd.to_dict(), cm)
	assert_eq(restored.player_name, "测试名", "名称往返保真")


# 批次1：6 manager 持久化往返测试
func test_persist_task_manager() -> void:
	var pd := PlayerData.new(cm)
	pd.task_manager.record_dailyjob_progress(4, 5)
	var d := pd.to_dict()
	var pd2 := PlayerData.from_dict(d, cm)
	assert_eq(pd2.task_manager.get_dailyjob_count(4), 5, "task_manager 存档往返保留进度")

func test_persist_daily_login() -> void:
	var pd := PlayerData.new(cm)
	pd.daily_login.frequency = 3
	pd.daily_login.status = "all"
	var d := pd.to_dict()
	var pd2 := PlayerData.from_dict(d, cm)
	assert_eq(pd2.daily_login.frequency, 3, "daily_login 存档往返保留 frequency")
	assert_eq(pd2.daily_login.status, "all", "daily_login 存档往返保留 status")

func test_persist_midas_times() -> void:
	var pd := PlayerData.new(cm)
	pd.midas.midas_times = 7
	var d := pd.to_dict()
	var pd2 := PlayerData.from_dict(d, cm)
	assert_eq(pd2.midas.midas_times, 7, "midas 存档往返保留 midas_times")

func test_persist_stage_progress() -> void:
	var pd := PlayerData.new(cm)
	pd.stage_manager.progress[1] = 3
	pd.stage_manager.max_normal = 5
	var d := pd.to_dict()
	var pd2 := PlayerData.from_dict(d, cm)
	assert_eq(int(pd2.stage_manager.progress.get(1, 0)), 3, "stage_manager 存档往返保留 progress")
	assert_eq(pd2.stage_manager.max_normal, 5, "stage_manager 存档往返保留 max_normal")

func test_persist_handbook() -> void:
	var pd := PlayerData.new(cm)
	pd.handbook.record_hero(42)
	pd.handbook.record_equip(101)
	var d := pd.to_dict()
	var pd2 := PlayerData.from_dict(d, cm)
	assert_true(pd2.handbook.has_hero(42), "handbook 存档往返保留英雄收集")
	assert_true(pd2.handbook.has_equip(101), "handbook 存档往返保留装备收集")

func test_persist_mailbox() -> void:
	var pd := PlayerData.new(cm)
	var before: int = pd.mailbox.ordered_mails().size()
	pd.mailbox.claim_attach(1, pd)  # 领第一封（源 read_mail:2755-2760 领取后从列表移除）
	var d := pd.to_dict()
	var pd2 := PlayerData.from_dict(d, cm)
	assert_eq(pd2.mailbox.ordered_mails().size(), before - 1, "已领邮件移除后存档往返仍移除")
