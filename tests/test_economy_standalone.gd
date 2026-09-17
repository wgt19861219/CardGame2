extends GutTest
# 经济单机优化专项（2026-09-17）：体力恢复链路/买体力跨日清零/体力上限等级成长/
# 免费金抽 CD 24h/serde 老档兜底。断链修复背景见验收记录-经济系统单机优化。

var cm: ConfigManager

const TS_DAY1_NOON: int = 1800000000   # 2027-01-15（本地 12 点上下，任意整 24h 差必跨本地日）
const TS_DAY2_NOON: int = TS_DAY1_NOON + 86400


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ---- A1 体力时间恢复（VitalityManager.recover，源 360s/点；2026-09-17 接线后 GameData 60s tick 驱动）----

func test_recover_two_points_keeps_remainder() -> void:
	var pd := PlayerData.new(cm)
	pd.vitality = 0
	pd.vitality_max = 120
	pd.vitality_last_recover = TS_DAY1_NOON
	var recovered: int = VitalityManager.recover(pd, TS_DAY1_NOON + 720)   # 2 个恢复周期
	assert_eq(recovered, 2, "恢复 2 点")
	assert_eq(pd.vitality, 2, "体力 0+2")
	assert_eq(pd.vitality_last_recover, TS_DAY1_NOON + 720, "整周期消耗，余数 0 保留")


func test_recover_full_refreshes_timestamp() -> void:
	var pd := PlayerData.new(cm)
	pd.vitality = pd.vitality_max
	pd.vitality_last_recover = TS_DAY1_NOON
	var recovered: int = VitalityManager.recover(pd, TS_DAY1_NOON + 7200)
	assert_eq(recovered, 0, "满体力返 0")
	assert_eq(pd.vitality_last_recover, TS_DAY1_NOON + 7200, "满体力刷新时间戳")


func test_recover_clamps_to_max() -> void:
	var pd := PlayerData.new(cm)
	pd.vitality = 119
	pd.vitality_max = 120
	pd.vitality_last_recover = TS_DAY1_NOON
	VitalityManager.recover(pd, TS_DAY1_NOON + 86400)   # 挂机一天只回 1 点到满
	assert_eq(pd.vitality, 120, "恢复受 vitality_max 钳制")


# ---- A1 serde 老档兜底：恢复接线前 last_recover 恒 0，from_dict 补当前时间防一次性回满 ----

func test_serde_legacy_recover_ts_backfilled() -> void:
	var pd := PlayerData.new(cm)
	pd.vitality = 10
	var d: Dictionary = pd.to_dict()
	d.erase("vitality_last_recover")   # 模拟老档无此字段
	var restored := PlayerData.from_dict(d, cm)
	assert_gt(restored.vitality_last_recover, 0, "缺时间戳补当前时间")
	assert_eq(restored.vitality, 10, "体力不被一次性回满")


# ---- A2 买体力跨日清零（源服务器日重置 todaybuy 的单机化；此前只增不清=16 次终身上限）----

func test_buy_vitality_daily_reset_across_day() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 100
	var limit: int = int(VipData.get_vip_field(pd.privilege_vip_level(), "Buy Vit Max", cm))
	VitalityManager.can_buy(pd, TS_DAY1_NOON)   # 落日锚 day1
	pd.vitality_today_buy = limit   # 模拟 day1 当天买满
	assert_false(VitalityManager.can_buy(pd, TS_DAY1_NOON), "同日达上限 → 不可买")
	assert_true(VitalityManager.can_buy(pd, TS_DAY2_NOON), "跨日清零 → 可买")
	assert_eq(pd.vitality_today_buy, 0, "跨日清零生效")
	assert_true(VitalityManager.buy(pd, TS_DAY2_NOON), "跨日后购买成功")
	assert_eq(pd.vitality_today_buy, 1, "跨日后重计次数")


func test_buy_vitality_same_day_no_reset() -> void:
	var pd := PlayerData.new(cm)
	VitalityManager.can_buy(pd, TS_DAY1_NOON)
	pd.vitality_today_buy = 2
	VitalityManager.can_buy(pd, TS_DAY1_NOON + 3600)   # 同日 1 小时后
	assert_eq(pd.vitality_today_buy, 2, "同日不清零")


# ---- A4 体力上限等级成长（源 playerlimit：PlayerLevel["Max Vitality"] + VIP["User Vitality Max"]；
# ---- 此前恒 120，表 60→160 的成长未接线）

func test_vitality_max_formula_by_level() -> void:
	var pd := PlayerData.new(cm)
	var vip_bonus: int = int(VipData.get_vip_field(pd.privilege_vip_level(), "User Vitality Max", cm))
	pd.team_level = 1
	pd.recalc_vitality_max()
	assert_eq(pd.vitality_max, int(cm.get_raw_table("PlayerLevel")["1"]["Max Vitality"]) + vip_bonus, "Lv1 上限 = 表值 + VIP 满档加成")
	pd.team_level = 99
	pd.recalc_vitality_max()
	assert_eq(pd.vitality_max, int(cm.get_raw_table("PlayerLevel")["99"]["Max Vitality"]) + vip_bonus, "Lv99 上限随表成长")


func test_add_team_exp_updates_vitality_max() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 1
	pd.recalc_vitality_max()
	var max_at_lv1: int = pd.vitality_max
	var exp_to_lv2: int = PlayerLevelData.get_level_exp(1, cm)
	pd.add_team_exp(exp_to_lv2)   # 恰好升 1 级
	assert_eq(pd.team_level, 2, "前置：升到 Lv2")
	var expected: int = int(cm.get_raw_table("PlayerLevel")["2"]["Max Vitality"]) \
			+ int(VipData.get_vip_field(pd.privilege_vip_level(), "User Vitality Max", cm))
	assert_eq(pd.vitality_max, expected, "升级后上限按新等级重算")
	assert_ne(expected, max_at_lv1, "前置：Lv2 与 Lv1 上限确有差（表成长非平坦）")


func test_serde_recalc_vitality_max_on_load() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 50
	var d: Dictionary = pd.to_dict()
	d["vitality_max"] = 120   # 模拟老档存量失真值
	var restored := PlayerData.from_dict(d, cm)
	var expected: int = int(cm.get_raw_table("PlayerLevel")["50"]["Max Vitality"]) \
			+ int(VipData.get_vip_field(pd.privilege_vip_level(), "User Vitality Max", cm))
	assert_eq(restored.vitality_max, expected, "读档按等级重算上限（存量 120 失真矫正）")


# ---- B2 免费金抽 CD 46h→24h（2026-09-17 适度爽快拍板："每日 1 次"名义与 CD 一致化）----

func test_gold_free_cd_24h() -> void:
	assert_eq(int(TavernData.BOX_CD["Gold"]), 86400, "金抽免费 CD 24h（源 165600s/46h 已调）")
	var pd := PlayerData.new(cm)
	pd.tavern_record["Gold"] = {"left_cnt": 1, "last_get_time": TS_DAY1_NOON, "has_first_draw": 0}
	assert_eq(TavernData.get_countdown(pd, "Gold", TS_DAY1_NOON + 86399), 1, "24h 内倒数")
	assert_eq(TavernData.get_countdown(pd, "Gold", TS_DAY1_NOON + 86400), 0, "满 24h CD 结束")


func test_serde_new_day_anchor_roundtrip() -> void:
	var pd := PlayerData.new(cm)
	pd.vitality_buy_day = 20270115
	pd.stage_limit_day = 20270115
	var restored := PlayerData.from_dict(pd.to_dict(), cm)
	assert_eq(restored.vitality_buy_day, 20270115, "买体力日锚持久化")
	assert_eq(restored.stage_limit_day, 20270115, "精英关日锚持久化")
