extends GutTest
# 公会一期 Logic 单测（2026-09-19，照源 local_server.lua:2812-2966 guild NPC 模拟 +
# guildconfig.lua 尾部常量 + guild.lua 膜拜流程）。
# 覆盖：列表/查找/创建校验链/加入/退出/主页组装/膜拜三档（消耗/次数/日重置/等级门槛/
# VIP 锁）/挂起领取/活跃累计/公会币产出口径/serde 往返/旧档兼容/shop7 公会商店。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_pd(level: int = 80) -> PlayerData:
	# 等级 80：可膜拜 lv85/88/90 三名 NPC（等级门槛 worshipLevelDif=1），不可膜拜 lv72-82。
	var pd := PlayerData.new(cm)
	pd.team_level = level
	pd.hero_manager.gold = 100000
	pd.diamond = 10000
	return pd


func _now() -> int:
	return int(Time.get_unix_time_from_system())


# ── 列表 / 查找 ─────────────────────────────────────────────────────

func test_guild_list_five_npc() -> void:
	var mgr := GuildManager.new(cm)
	var guilds: Array = mgr.get_guild_list()
	assert_eq(guilds.size(), 5, "5 个 NPC 公会（源 guild_npc_guilds）")
	for g in guilds:
		assert_true(g.has("id") and g.has("name") and g.has("avatar") and g.has("slogan"), "字段齐全")
	assert_eq(int(guilds[0]["id"]), 10001, "首个 id=10001")
	assert_eq(String(guilds[0]["name"]), "英雄殿堂", "首个名=英雄殿堂")


func test_search_guild_hit_and_miss() -> void:
	var mgr := GuildManager.new(cm)
	assert_eq(String(mgr.search_guild(10003)["name"]), "龙骑联盟", "ID 查找命中")
	assert_true(mgr.search_guild(99999).is_empty(), "未命中返回空")


# ── 创建（校验链：在会→名字→钻石）───────────────────────────────────

func test_create_success_chairman_and_cost() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd()
	var r: Dictionary = mgr.create_guild(pd, "守卫公会", 3)
	assert_true(bool(r["ok"]), "创建成功")
	assert_eq(pd.diamond, 9500, "扣 500 钻（源 _create_cost）")
	assert_true(pd.guild_data.is_in_guild(), "入会态")
	assert_eq(pd.guild_data.guild_id, 10001, "自建会沿用 10001 基值（源 _create 同款）")
	assert_eq(pd.guild_data.guild_avatar, 3, "图标就位")
	assert_eq(pd.guild_data.vitality, 5000, "初始活跃=5000（源 makeGuildInfo 基值）")


func test_create_name_validation() -> void:
	var mgr := GuildManager.new(cm)
	assert_false(bool(mgr.create_guild(_make_pd(), "  ", 1)["ok"]), "空名拒绝")
	assert_false(bool(mgr.create_guild(_make_pd(), "名字超过十个字符的公会", 1)["ok"]), "超 10 字拒绝")


func test_create_insufficient_diamond() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd()
	pd.diamond = 499
	assert_false(bool(mgr.create_guild(pd, "没钱公会", 1)["ok"]), "钻石不足拒绝")
	assert_false(pd.guild_data.is_in_guild(), "失败不入会")


func test_create_while_in_guild_rejected() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd()
	pd.guild_data.setup_guild(10002, "暗影军团", 143, "s")
	assert_false(bool(mgr.create_guild(pd, "二会", 1)["ok"]), "已在会拒绝创建")


# ── 加入 / 退出 ─────────────────────────────────────────────────────

func test_join_npc_guild_instant() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd()
	# 单机化大幅简化：verify 型（10003）也即入（审批流裁剪，受控偏离）。
	var r: Dictionary = mgr.join_guild(pd, 10003)
	assert_true(bool(r["ok"]), "verify 型公会即入（受控偏离）")
	assert_eq(pd.guild_data.guild_name, "龙骑联盟", "公会名就位")
	assert_eq(pd.guild_data.guild_avatar, 147, "图标就位")
	assert_eq(pd.guild_data.slogan, "龙之力量", "宣言就位")


func test_join_unknown_guild_rejected() -> void:
	var mgr := GuildManager.new(cm)
	assert_false(bool(mgr.join_guild(_make_pd(), 99999)["ok"]), "未知公会拒绝")


func test_leave_clears_state() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd()
	pd.guild_data.setup_guild(10001, "英雄殿堂", 1, "s")
	pd.guild_data.self_vitality = 30
	var r: Dictionary = mgr.leave_guild(pd)
	assert_true(bool(r["ok"]), "退出成功")
	assert_false(pd.guild_data.is_in_guild(), "未入会态")
	assert_eq(pd.guild_data.self_vitality, 0, "贡献清零")


func test_leave_not_in_guild_rejected() -> void:
	var mgr := GuildManager.new(cm)
	assert_false(bool(mgr.leave_guild(_make_pd())["ok"]), "未入会拒绝退出")


# ── 主页信息组装 ────────────────────────────────────────────────────

func test_guild_info_nine_members() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd()
	pd.guild_data.setup_guild(10001, "英雄殿堂", 1, "s")
	var info: Dictionary = mgr.get_guild_info(pd, BattleRng.new(12345), _now())
	var members: Array = info["members"]
	assert_eq(members.size(), 9, "玩家 + 8 NPC（源 makeGuildInfo）")
	assert_eq(String(members[0]["job"]), GuildManager.JOB_CHAIRMAN, "玩家首位 chairman（源 makePlayerMember）")
	assert_eq(int(info["summary"]["member_cnt"]), 9, "member_cnt=9")
	var now: int = _now()
	for m in members:
		assert_true(int(m["active"]) >= 10 and int(m["active"]) <= 100, "active 10-100（源 random 区间）")
		# 玩家行 last_login=0 是源 makePlayerMember 特殊值（恒今日在线），窗口断言只对 NPC。
		if int(m["uid"]) == 1:
			continue
		var last_login: int = int(m["last_login"])
		assert_true(now - last_login <= 3600, "NPC last_login 在 1h 窗口（源 rand(0,3600)）")


# ── 膜拜（三档/门槛/次数/日重置/领取）───────────────────────────────

func test_worship_free_tier_pending_reward() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd(80)
	mgr.join_guild(pd, 10001)
	var r: Dictionary = mgr.worship(pd, 9001, 1, _now())
	assert_true(bool(r["ok"]), "免费档膜拜 lv90 成功（80+1<=90）")
	assert_eq(pd.guild_data.worship_use_times, 1, "次数 +1")
	assert_eq(pd.guild_data.worship_pending.size(), 1, "奖励挂起 1 条（源 _worship 二次领取）")
	var pending: Dictionary = pd.guild_data.worship_pending[0]
	assert_eq(int(pending["gold"]), 1000, "gold=1000（GuildWorship 表档 1）")
	assert_eq(int(pending["vitality"]), 15, "vitality=15")
	assert_eq(int(pending["guildpoint"]), 10, "guildpoint=10（单机化产出口径档 1）")
	assert_eq(pd.guild_data.self_vitality, 15, "贡献 +15")
	assert_eq(pd.guild_data.vitality, 5015, "公会活跃 5000+15")


func test_worship_level_gate() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd(90)
	mgr.join_guild(pd, 10001)
	# 玩家 90 级：NPC 最高 90，90 >= 90+1 不成立 → 无可膜拜对象（照源 :257 显隐口径）。
	assert_false(bool(mgr.worship(pd, 9001, 1, _now())["ok"]), "等级门槛拒绝（最高 NPC 平级）")
	# 80 级玩家膜拜 lv75 NPC：75 >= 81 不成立 → 拒绝。
	var pd2 := _make_pd(80)
	mgr.join_guild(pd2, 10001)
	assert_false(bool(mgr.worship(pd2, 9005, 1, _now())["ok"]), "低级 NPC 不可膜拜")


func test_worship_times_limit_and_daily_reset() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd(80)
	mgr.join_guild(pd, 10001)
	var now: int = _now()
	assert_true(bool(mgr.worship(pd, 9001, 1, now)["ok"]), "首次膜拜")
	# VIP0 Worship Times=1（VIP.json）→ 第二次拒绝。
	var r2: Dictionary = mgr.worship(pd, 9001, 1, now)
	assert_false(bool(r2["ok"]), "VIP0 每日 1 次上限")
	assert_eq(String(r2["err"]), "今日膜拜次数已用完", "上限文案（源 LSTR）")
	# 跨日惰性重置（本地日 key，照 stage_limit 范式）：次日 times 清零。
	var info_next_day: Dictionary = mgr.get_worship_times_info(pd, now + 86400)
	assert_eq(int(info_next_day["left"]), 1, "跨日恢复次数")


func test_worship_gold_tier_cost() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd(80)
	mgr.join_guild(pd, 10001)
	pd.hero_manager.gold = 29999
	assert_false(bool(mgr.worship(pd, 9001, 2, _now())["ok"]), "金币不足拒绝（档 2 需 3 万）")
	pd.hero_manager.gold = 50000
	assert_true(bool(mgr.worship(pd, 9001, 2, _now())["ok"]), "金币档成功")
	assert_eq(pd.hero_manager.gold, 20000, "扣 3 万金（GuildWorship 档 2）")


func test_worship_diamond_tier_vip_locked() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd(80)
	mgr.join_guild(pd, 10001)
	# 源 rmbWorship :1538-1542：钻石档需 VIP "Diamond Worship" 门槛；VIP0 锁定（照源行为）。
	var r: Dictionary = mgr.worship(pd, 9001, 3, _now())
	assert_false(bool(r["ok"]), "VIP0 钻石档锁定")
	assert_true(String(r["err"]).contains("VIP"), "锁定文案含 VIP 门槛")
	var options: Array = mgr.get_worship_options(pd)
	assert_true(bool(options[2]["locked"]), "options 档 3 locked=true")


func test_worship_withdraw_grants_all() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd(80)
	mgr.join_guild(pd, 10001)
	mgr.worship(pd, 9001, 1, _now())
	var gold_before: int = pd.hero_manager.gold
	var vit_before: int = pd.vitality
	var r: Dictionary = mgr.worship_withdraw(pd)
	assert_true(bool(r["ok"]), "领取成功")
	var rewards: Dictionary = r["rewards"]
	assert_eq(int(rewards["gold"]), 1000, "汇总 gold=1000")
	assert_eq(pd.hero_manager.gold, gold_before + 1000, "金币到账")
	assert_eq(pd.guildpoint, 10, "公会币到账（10，单机化产出口径）")
	assert_eq(pd.vitality, min(vit_before + 15, pd.vitality_max), "体力到账 clamp 上限")
	assert_true(pd.guild_data.worship_pending.is_empty(), "挂起清空")
	assert_false(bool(mgr.worship_withdraw(pd)["ok"]), "空挂起再领拒绝")


# ── serde（存档往返 + 旧档兼容）─────────────────────────────────────

func test_serde_roundtrip_keeps_guild_state() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd(80)
	mgr.join_guild(pd, 10002)
	mgr.worship(pd, 9001, 1, _now())
	var dict: Dictionary = PlayerDataSerde.to_dict(pd)
	var restored: PlayerData = PlayerDataSerde.from_dict(dict, cm)
	assert_eq(restored.guild_data.guild_id, 10002, "往返 guild_id 保持")
	assert_eq(restored.guild_data.guild_name, "暗影军团", "往返公会名保持")
	assert_eq(restored.guild_data.self_vitality, 15, "往返贡献保持")
	assert_eq(restored.guild_data.worship_use_times, 1, "往返膜拜次数保持")
	assert_eq(restored.guild_data.worship_pending.size(), 1, "往返挂起奖励保持")


func test_serde_legacy_save_without_guild() -> void:
	# 旧档无 guild_data 键 → 默认未入会（升级兼容）。
	var data: Dictionary = {"diamond": 100}
	var pd: PlayerData = PlayerDataSerde.from_dict(data, cm)
	assert_false(pd.guild_data.is_in_guild(), "旧档默认未入会")
	assert_eq(pd.guild_data.vitality, 0, "旧档活跃 0")


# ── shop7 公会商店 ──────────────────────────────────────────────────

func test_shop7_market_config_guildpoint() -> void:
	var cfg: Dictionary = MarketConfig.get_type_config(MarketConfig.SHOP_GUILD_ID)
	# 商品 payType=gold（源 generateShopGoods(7) payTypeMap[7] or "gold"）；公会币只用于刷新。
	assert_eq(String(cfg["payType"]), "gold", "shop7 商品 payType=gold（照源残留映射语义）")
	assert_eq(String(cfg["titleText"]), "公会商店", "标题降级文本")


func test_shop7_goods_paytype_gold() -> void:
	var sm := ShopManager.new(cm)
	var goods: Array = sm.generate_shop_goods(MarketConfig.SHOP_GUILD_ID, BattleRng.new(12345), cm)
	assert_eq(goods.size(), 6, "6 件商品（源 GOODS_COUNT）")
	assert_eq(String(goods[0]["type"]), "gold", "商品 payType=gold（源 payTypeMap[7] 缺省 gold）")


func test_shop7_refresh_spends_guildpoint_not_diamond() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	pd.guildpoint = 0
	assert_false(sm.refresh(MarketConfig.SHOP_GUILD_ID, pd, BattleRng.new(1), cm), "无公会币刷新失败")
	pd.guildpoint = 10000
	var diamond_before: int = pd.diamond
	assert_true(sm.refresh(MarketConfig.SHOP_GUILD_ID, pd, BattleRng.new(1), cm), "公会币刷新成功")
	assert_eq(pd.diamond, diamond_before, "不扣钻石")
	assert_true(pd.guildpoint < 10000, "扣公会币（GradientPrice 梯度）")


# P0-3（2026-09-28 审查）：退会不清膜拜次数/日锚/挂起——原清零可被
# 「入会→免费膜拜→退会」循环重置次数无限刷金/体力/公会币。
func test_leave_keeps_worship_state() -> void:
	var mgr := GuildManager.new(cm)
	var pd := _make_pd(80)
	mgr.join_guild(pd, 10001)
	var now: int = _now()
	assert_true(bool(mgr.worship(pd, 9001, 1, now)["ok"]), "免费档膜拜成功（挂起 pending）")
	var used_before: int = pd.guild_data.worship_use_times
	var pending_before: int = pd.guild_data.worship_pending.size()
	assert_true(used_before >= 1 and pending_before >= 1, "次数与挂起已产生")
	assert_true(bool(mgr.leave_guild(pd)["ok"]), "退会成功")
	assert_eq(pd.guild_data.worship_use_times, used_before, "退会保留今日已膜拜次数")
	assert_eq(pd.guild_data.worship_pending.size(), pending_before, "退会不吞挂起未领奖励")
	assert_eq(pd.guild_data.worship_day, _day_key(now), "退会保留日锚（跨日才清）")
	# 退会→再入会循环不能重置次数：VIP0 每日 1 次仍然生效。
	mgr.join_guild(pd, 10002)
	assert_false(bool(mgr.worship(pd, 9001, 1, now)["ok"]), "再入会后次数上限仍拦截")


func _day_key(ts: int) -> int:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts + bias * SECONDS_PER_MINUTE)
	return int(dt["year"]) * 10000 + int(dt["month"]) * 100 + int(dt["day"])


const SECONDS_PER_MINUTE: int = 60
