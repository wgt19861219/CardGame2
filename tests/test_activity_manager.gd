extends GutTest
# ActivityManager 运营活动单测 — 照源 local_server.lua:4607-4703（周常生成/进度跟踪/
# 领取校验）+ activitiesList.lua:149-160（红点）。
# 2026-10-13 用户拍板玩法活动临时下线：ActivitiesConfig.json 只留 announce 纯展示公告；
# 玩法档位（claim/红点/组装）用注入表测试（管线保留，恢复活动只需换回 JSON）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


## 注入玩法活动表（照源 buildDiamondConsumeActivity/buildTavernBonusActivity 数值）。
func _cm_with_activities() -> ConfigManager:
	var c := ConfigManager.new()
	c.load_all()
	c._tables[&"ActivitiesConfig"] = {
		"diamond_consume": {
			"type": "diamond_consume", "title": "钻石消费返利", "desc": "d", "rules": "r",
			"rewards": [
				{"job": "act_dia_200", "threshold": 200, "reward": {"type": "money", "id": 0, "amount": 50000}},
				{"job": "act_dia_500", "threshold": 500, "reward": {"type": "item", "id": 14001, "amount": 3}},
				{"job": "act_dia_1000", "threshold": 1000, "reward": {"type": "item", "id": 14002, "amount": 2}},
				{"job": "act_dia_2000", "threshold": 2000, "reward": {"type": "rmb", "id": 0, "amount": 200}},
			],
		},
		"combo_br_tavern": {
			"type": "tavern_ten", "title": "青铜十连优惠", "desc": "d", "rules": "r",
			"rewards": [
				{"job": "act_combo_br_tavern", "threshold": 1, "reward": {"type": "money", "id": 0, "amount": 10000}},
			],
		},
	}
	return c


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _make_player(p_cm: ConfigManager) -> PlayerData:
	var pd := PlayerData.new(p_cm)
	pd.apply_default_data()
	return pd


# ── 周锚（源 getActivityPeriod local_server.lua:4607：本地时区周一 0 点）──

func test_week_start_lands_on_monday_zero() -> void:
	var now: int = _now()
	var ws: int = ActivityManager.week_start(now)
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(ws + off_min * 60)
	assert_eq(int(d.get("weekday", -1)), 1, "周锚应落在周一")
	assert_eq(int(d.get("hour", -1)) * 3600 + int(d.get("minute", -1)) * 60 + int(d.get("second", -1)), 0, "周锚应为本地 0 点")
	assert_true(now - ws >= 0 and now - ws < ActivityManager.SECS_PER_WEEK, "now 落在锚后一周内")


func test_week_reset_clears_progress_and_claims() -> void:
	var mgr := ActivityManager.new()
	var now: int = _now()
	mgr.week_key = ActivityManager.week_start(now - ActivityManager.SECS_PER_WEEK)
	mgr.diamond_spent = 900
	mgr.tavern_once_draws = 2
	mgr.tavern_ten_draws = 1
	mgr.claimed = {"act_dia_200": true}
	mgr.on_diamond_spent(100, now)
	assert_eq(mgr.week_key, ActivityManager.week_start(now), "跨周后周锚更新")
	assert_eq(mgr.diamond_spent, 100, "跨周清零后重新累计")
	assert_eq(mgr.tavern_once_draws, 0, "跨周清零单抽计数")
	assert_eq(mgr.tavern_ten_draws, 0, "跨周清零十连计数")
	assert_true(mgr.claimed.is_empty(), "跨周清空已领（源缺陷②修正）")


# ── 进度累计（源 trackDiamondSpent :4698 / buildTavernBonusActivity 只计青铜）──

func test_diamond_spent_accumulates() -> void:
	var mgr := ActivityManager.new()
	var now: int = _now()
	mgr.on_diamond_spent(50, now)
	mgr.on_diamond_spent(30, now)
	assert_eq(mgr.diamond_spent, 80, "钻石消费累计")
	mgr.on_diamond_spent(0, now)
	mgr.on_diamond_spent(-5, now)
	assert_eq(mgr.diamond_spent, 80, "非正数消费忽略")


func test_tavern_draw_counts_and_bronze_filter() -> void:
	var mgr := ActivityManager.new()
	var now: int = _now()
	mgr.on_tavern_draw("Bronze", false, now)
	mgr.on_tavern_draw("Bronze", false, now)
	mgr.on_tavern_draw("Bronze", true, now)
	mgr.on_tavern_draw("MagicSoul", true, now)
	assert_eq(mgr.tavern_once_draws, 2, "青铜单抽按操作计次")
	assert_eq(mgr.tavern_ten_draws, 1, "青铜十连按操作计次（不折 10 次单抽）")
	assert_eq(mgr.get_progress("tavern_once"), 2, "tavern_once 进度读数")


# ── 领取校验（源 job_rewards act_ 分支 :4512-4563；注入表）──

func test_claim_not_ready_rejected() -> void:
	var cm2 := _cm_with_activities()
	var mgr := ActivityManager.new()
	var pd := _make_player(cm2)
	var r: Dictionary = mgr.claim(pd, cm2, "act_dia_200", _now())
	assert_false(bool(r["ok"]), "未达标拒领")
	assert_eq(String(r["reason"]), "not_ready", "拒因 not_ready")


func test_claim_money_tier_adds_gold() -> void:
	var cm2 := _cm_with_activities()
	var mgr := ActivityManager.new()
	var pd := _make_player(cm2)
	var now: int = _now()
	mgr.on_tavern_draw("Bronze", true, now)
	var gold_before: int = pd.hero_manager.gold
	var r: Dictionary = mgr.claim(pd, cm2, "act_combo_br_tavern", now)
	assert_true(bool(r["ok"]), "十连达标可领")
	assert_eq(pd.hero_manager.gold, gold_before + 10000, "money 档入账金币 10000")
	assert_true(bool(mgr.claimed.get("act_combo_br_tavern", false)), "领取后标记已领")


func test_claim_already_claimed_rejected() -> void:
	var cm2 := _cm_with_activities()
	var mgr := ActivityManager.new()
	var pd := _make_player(cm2)
	var now: int = _now()
	mgr.on_tavern_draw("Bronze", true, now)
	assert_true(bool(mgr.claim(pd, cm2, "act_combo_br_tavern", now)["ok"]), "首次领取成功")
	var gold_before: int = pd.hero_manager.gold
	var r: Dictionary = mgr.claim(pd, cm2, "act_combo_br_tavern", now)
	assert_false(bool(r["ok"]), "重复领取拒绝")
	assert_eq(String(r["reason"]), "claimed", "拒因 claimed")
	assert_eq(pd.hero_manager.gold, gold_before, "重复领取不再入账")


func test_claim_unknown_job_rejected() -> void:
	var mgr := ActivityManager.new()
	var pd := _make_player(cm)
	var r: Dictionary = mgr.claim(pd, cm, "act_nonexistent", _now())
	assert_false(bool(r["ok"]), "公告态（表内无档位）任意 job 拒绝")
	assert_eq(String(r["reason"]), "no_job", "拒因 no_job")


# ── 活动组装 + 公告形态（当前 JSON = 1 条 announce 纯展示公告）──

func test_announce_only_config() -> void:
	var mgr := ActivityManager.new()
	var acts: Array = mgr.get_activities(_now(), cm)
	assert_eq(acts.size(), 1, "当前配置仅一条公告")
	var first: Dictionary = acts[0]
	assert_eq(String(first["key"]), "announcement", "公告 key")
	assert_eq(String(first["type"]), "announce", "公告类型")
	assert_eq(String(first["title"]), "公告", "公告标题")
	assert_eq((first["tiers"] as Array).size(), 0, "公告无档位（纯展示）")
	assert_false(mgr.has_red_dot(_now(), cm), "公告无档位 → 无红点")


func test_get_activities_structure_with_injected_table() -> void:
	var cm2 := _cm_with_activities()
	var mgr := ActivityManager.new()
	var now: int = _now()
	mgr.on_diamond_spent(600, now)
	var acts: Array = mgr.get_activities(now, cm2)
	assert_eq(acts.size(), 2, "注入表两条玩法活动")
	var first: Dictionary = acts[0]
	assert_eq(String(first["title"]), "钻石消费返利", "标题照源")
	assert_eq(int(first["progress"]), 600, "进度 600")
	assert_eq((first["tiers"] as Array).size(), 4, "钻石返利 4 档")
	var tiers: Array = first["tiers"]
	assert_true(bool(tiers[0]["ready"]), "200 档达标")
	assert_false(bool(tiers[0]["claimed"]), "未领取")
	assert_false(bool(tiers[2]["ready"]), "1000 档未达标")
	assert_eq(int(first["end"]) - int(first["start"]), ActivityManager.SECS_PER_WEEK, "周期一周")


func test_red_dot_with_injected_table() -> void:
	var cm2 := _cm_with_activities()
	var mgr := ActivityManager.new()
	var now: int = _now()
	assert_true(mgr.has_red_dot(now, cm2), "存在未领档位亮红点")
	mgr.claimed = {
		"act_dia_200": true, "act_dia_500": true, "act_dia_1000": true, "act_dia_2000": true,
		"act_combo_br_tavern": true,
	}
	mgr.week_key = ActivityManager.week_start(now)   # 预置周锚防 _ensure_week 清掉手工 claimed
	assert_false(mgr.has_red_dot(now, cm2), "全档已领熄红点")


# ── serde 往返 ──

func test_serde_roundtrip() -> void:
	var mgr := ActivityManager.new()
	var now: int = _now()
	mgr.on_diamond_spent(300, now)
	mgr.on_tavern_draw("Bronze", true, now)
	mgr.claimed = {"act_dia_200": true}
	var restored: ActivityManager = ActivityManager.from_dict(mgr.to_dict())
	assert_eq(restored.week_key, mgr.week_key, "week_key 往返")
	assert_eq(restored.diamond_spent, 300, "diamond_spent 往返")
	assert_eq(restored.tavern_ten_draws, 1, "tavern_ten_draws 往返")
	assert_true(bool(restored.claimed.get("act_dia_200", false)), "claimed 往返")
