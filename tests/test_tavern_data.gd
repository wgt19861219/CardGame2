extends GutTest
# Phase 5.3 tavern_data 抽卡查询 + 产出测试（2026-07-02）。
# TavernType 多级查表 + roll_tavern_loot 产出（照源 local_server.lua:1673 tavern_draw）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# MagicSoul/十连/非免费/count=0 → Cost=400 Diamond。
func test_get_tavern_cost() -> void:
	var cost: int = TavernData.get_tavern_cost("MagicSoul", true, false, 0, cm)
	assert_eq(cost, 400, "MagicSoul is_ten=true is_free=false count=0 → Cost=400")


func test_get_tavern_chest_group() -> void:
	var cg: int = TavernData.get_tavern_chest_group("MagicSoul", true, false, 0, cm)
	assert_eq(cg, 23, "MagicSoul → Chest Group ID=23")


func test_get_tavern_info_missing() -> void:
	var row: Dictionary = TavernData.get_tavern_info("NonExist", true, false, 0, cm)
	assert_eq(row.size(), 0, "不存在 type → 空 row")


func test_get_tavern_box() -> void:
	var box: Dictionary = TavernData.get_tavern_box(1, 0, cm)
	assert_eq(int(box.get("Box Type", 0)), 1, "TavernBoxType 1/0 Box Type=1")


# 单抽产出 ≥1 equip（源 :1721-1758 drawCount=1，equip 数量固定 1）。
func test_roll_loot_single() -> void:
	var rng := BattleRng.new(12345)
	var loots: Array = TavernData.roll_tavern_loot(0, 0, rng, cm)
	assert_true(loots.size() >= 1, "单抽至少产出 1 物品")
	var loot: Dictionary = loots[0]
	assert_gt(int(loot["id"]), 0, "产出 id > 0")
	assert_eq(int(loot["amount"]), 1, "equip 数量固定 1")


# 十连产出 ≥10 equip（源 :1723 drawCount=10）。
func test_roll_loot_combo() -> void:
	var rng := BattleRng.new(12345)
	var loots: Array = TavernData.roll_tavern_loot(1, 0, rng, cm)
	assert_true(loots.size() >= 10, "十连至少产出 10 equip")


# stone 分支产出 3 个 equip，数量 1-3（源 :1681-1715 stone_green→品质[1,2,3]）。
func test_roll_loot_stone() -> void:
	var rng := BattleRng.new(12345)
	var loots: Array = TavernData.roll_tavern_loot("stone", "stone_green", rng, cm)
	assert_eq(loots.size(), 3, "灵魂石分支产出 3 个 equip")
	for loot in loots:
		assert_true(int(loot["amount"]) >= 1, "数量 >=1")
		assert_true(int(loot["amount"]) <= 3, "数量 <=3")


# 产出处均在有效池（equip 有 Icon / hero Portrait+Hero，源 :1729-1745）。
func test_roll_loot_ids_in_pool() -> void:
	var rng := BattleRng.new(999)
	var loots: Array = TavernData.roll_tavern_loot(1, 0, rng, cm)
	var equip_pool: Array[int] = TavernData._collect_valid_equip_ids(cm)
	var hero_pool: Array[int] = TavernData._collect_valid_hero_ids(cm)
	for loot in loots:
		var lid: int = int(loot["id"])
		assert_true(equip_pool.has(lid) or hero_pool.has(lid), "产出 id 必在 equip 或 hero 池")


# ---- 抽卡池非数字 key 过滤（源 local_server.lua:1731 type(k)=="number"，2026-09-07 空白图标根修）----
# Equip 表混有 359 个 "equip.2.0.0.xxx" 非数字 key 行（策划模板行）；源 Lua type(k)=="number"
# 天然滤除，GDScript 迁移丢失该过滤致 int("equip.2.0.0.011")=0 进池（49.7% 抽到 id=0，
# 查表无行 → readequip_icon 内容图为空 → 只剩边框衬底 = 空白图标，用户高频反馈）。

# 池内 id 必须能查回 Equip 行（id=0 无行 → 图标空白根因）。
func test_equip_pool_ids_resolve_to_rows() -> void:
	var pool: Array[int] = TavernData._collect_valid_equip_ids(cm)
	assert_false(pool.has(0), "equip 池不含 id=0（非数字 key int 截断值）")
	assert_gt(pool.size(), 0, "equip 池非空")
	var raw: Dictionary = cm.get_raw_table("Equip")
	for eid in pool:
		assert_true(raw.has(str(eid)), "池 id=%d 必能查回 Equip 行" % eid)


# hero 池同守卫（Unit 表当前全数字 key，防御性对齐源过滤）。
func test_hero_pool_ids_resolve_to_rows() -> void:
	var pool: Array[int] = TavernData._collect_valid_hero_ids(cm)
	assert_false(pool.has(0), "hero 池不含 id=0")
	var raw: Dictionary = cm.get_raw_table("Unit")
	for hid in pool:
		assert_true(raw.has(str(hid)), "池 id=%d 必能查回 Unit 行" % hid)


# 十连产出 id 全部 > 0（修前 49.7% 概率出 0，固定 seed 确定性复现）。
func test_roll_loot_ids_positive() -> void:
	var rng := BattleRng.new(4242)
	var loots: Array = TavernData.roll_tavern_loot(1, 0, rng, cm)
	for loot in loots:
		assert_gt(int(loot["id"]), 0, "产出 id > 0（0=非数字 key 截断产物）")


# stone 分支产出 id 全部 > 0（同根因第三处 :158）。
func test_roll_stone_ids_positive() -> void:
	var rng := BattleRng.new(4242)
	var loots: Array = TavernData.roll_tavern_loot("stone", "stone_purple", rng, cm)
	for loot in loots:
		assert_gt(int(loot["id"]), 0, "stone 产出 id > 0")


# ---- 免费抽卡 Logic（照源 tavern.lua isShowFree/getCountdown + player.lua getTavernLeftTimes/useFreeTavern，2026-07-08）----

# 源 getTavernLeftTimes：新档（last_get_time=0）跨日返满额（Bronze 5 / Gold 1）。
func test_left_times_initial() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(TavernData.get_left_times(pd, "Bronze", 1000000), 5, "新档 Bronze 跨日返满额 5")
	assert_eq(TavernData.get_left_times(pd, "Gold", 1000000), 1, "新档 Gold 满额 1")


# 源 useFreeTavern：免费抽后 left_cnt-1（同日）。
func test_left_times_decrement() -> void:
	var pd := PlayerData.new(cm)
	var now: int = 1000000
	TavernData.use_free_tavern(pd, "Bronze", now)
	assert_eq(TavernData.get_left_times(pd, "Bronze", now + 1), 4, "同日用 1 次 5→4")


# 源 getTavernLeftTimes 跨日重置：次日返满额（checkTwoDateod true）。
func test_left_times_cross_day() -> void:
	var pd := PlayerData.new(cm)
	var now: int = 1000000
	TavernData.use_free_tavern(pd, "Bronze", now)
	assert_eq(TavernData.get_left_times(pd, "Bronze", now + 86400), 5, "次日跨日重置返满额 5")


# 源 getCountdown：免费抽后进 CD（Bronze 600s），过 CD 归 0。
func test_countdown_after_use() -> void:
	var pd := PlayerData.new(cm)
	var now: int = 1000000
	TavernData.use_free_tavern(pd, "Bronze", now)
	assert_eq(TavernData.get_countdown(pd, "Bronze", now + 10), 590, "CD 中剩 590s")
	assert_eq(TavernData.get_countdown(pd, "Bronze", now + 600), 0, "过 CD 归 0")


# 源 isShowFree：新档有额度无 CD → true；CD 中 → false。
func test_is_show_free() -> void:
	var pd := PlayerData.new(cm)
	var now: int = 1000000
	assert_eq(TavernData.is_show_free(pd, "Bronze", now), true, "新档 Bronze 有额度无 CD → free")
	TavernData.use_free_tavern(pd, "Bronze", now)
	assert_eq(TavernData.is_show_free(pd, "Bronze", now + 10), false, "CD 中 → 非 free")


# 源 Bronze 每日 5 次：用 5 次后额度耗尽，CD 结束也非 free（getLeftTimes 返 0）。
func test_use_until_exhausted() -> void:
	var pd := PlayerData.new(cm)
	var now: int = 1000000
	for i in range(5):
		TavernData.use_free_tavern(pd, "Bronze", now + i)
	assert_eq(TavernData.get_left_times(pd, "Bronze", now + 100), 0, "5 次免费后额度耗尽")
	# now+700：dt=696>600 验 CD 结束归 0，且 12min 内不跨日（避时区敏感）→ 额度 0 仍非 free
	assert_eq(TavernData.is_show_free(pd, "Bronze", now + 700), false, "额度耗尽 CD 结束仍非 free")


# ---- 免费 CD 倒计时文字（照源 getCountdownText + gethmsNString，2026-07-08）----

# 源 getCountdownText：bronze CD 结束有次数 → "剩余免费次数 D/D"。
func test_countdown_text_bronze_free() -> void:
	var pd := PlayerData.new(cm)
	var r: Dictionary = TavernData.get_countdown_text(pd, "Bronze", 1000000)
	assert_eq(bool(r["is_counting"]), false, "新档 CD 结束非倒计时")
	assert_eq(String(r["text"]), "剩余免费次数 5/5", "bronze 新档剩余 5/5")


# bronze 次数用完 → "今日免费次数已用完"。
func test_countdown_text_bronze_exhausted() -> void:
	var pd := PlayerData.new(cm)
	var now: int = 1000000
	for i in range(5):
		TavernData.use_free_tavern(pd, "Bronze", now + i)
	var r: Dictionary = TavernData.get_countdown_text(pd, "Bronze", now + 700)  # dt696>600 CD 结束 + 额度0
	assert_eq(String(r["text"]), "今日免费次数已用完", "bronze 额度耗尽")


# CD 中 → is_counting true + "HH:MM:SS"（源 gethmsNString）。
func test_countdown_text_in_cd() -> void:
	var pd := PlayerData.new(cm)
	var now: int = 1000000
	TavernData.use_free_tavern(pd, "Bronze", now)
	var r: Dictionary = TavernData.get_countdown_text(pd, "Bronze", now + 10)
	assert_eq(bool(r["is_counting"]), true, "CD 中 is_counting")
	assert_eq(String(r["text"]), "00:09:50", "600-10=590s = 00:09:50")


# gold CD 结束 → text 空（源 box_chance gold 无值，不显示次数）。
func test_countdown_text_gold_empty() -> void:
	var pd := PlayerData.new(cm)
	var r: Dictionary = TavernData.get_countdown_text(pd, "Gold", 1000000)
	assert_eq(bool(r["is_counting"]), false, "gold 新档 CD 结束")
	assert_eq(String(r["text"]), "", "gold CD 结束无次数文字")


# ---- 首抽保底标记（照源 tavern.lua:285 isFirstDraw + player.lua:1730 refreshFirstTavern，2026-07-08）----

# 源 isFirstDraw：新档 has_first_draw=0 → {once, ten} 均 true（未首抽）。
func test_first_draw_initial() -> void:
	var pd := PlayerData.new(cm)
	var ifd: Dictionary = TavernData.is_first_draw(pd, "Bronze")
	assert_eq(bool(ifd["once"]), true, "新档单抽未首抽")
	assert_eq(bool(ifd["ten"]), true, "新档十连未首抽")
	assert_eq(TavernData.is_first_one_draw(pd, "Bronze"), true, "is_first_one_draw 新档 true")
	assert_eq(TavernData.is_first_ten_draw(pd, "Bronze"), true, "is_first_ten_draw 新档 true")


# 源 refreshFirstTavern times=one：单抽后 of=1，单抽标记→false，十连仍 true。
func test_refresh_first_once() -> void:
	var pd := PlayerData.new(cm)
	TavernData.refresh_first_tavern(pd, "Bronze", false)
	assert_eq(TavernData.is_first_one_draw(pd, "Bronze"), false, "单抽后单抽标记置1")
	assert_eq(TavernData.is_first_ten_draw(pd, "Bronze"), true, "单抽不影响十连标记")


# 源 refreshFirstTavern times=ten：十连后 tf=1，十连标记→false。
func test_refresh_first_ten() -> void:
	var pd := PlayerData.new(cm)
	TavernData.refresh_first_tavern(pd, "Gold", true)
	assert_eq(TavernData.is_first_ten_draw(pd, "Gold"), false, "十连后十连标记置1")
	assert_eq(TavernData.is_first_one_draw(pd, "Gold"), true, "十连不影响单抽标记")


# 源 makebits 编码：单抽+十连都置后两标记独立（高16/低16位不串扰）。
func test_refresh_first_both() -> void:
	var pd := PlayerData.new(cm)
	TavernData.refresh_first_tavern(pd, "Bronze", false)
	TavernData.refresh_first_tavern(pd, "Bronze", true)
	assert_eq(TavernData.is_first_one_draw(pd, "Bronze"), false, "单抽标记保留")
	assert_eq(TavernData.is_first_ten_draw(pd, "Bronze"), false, "十连标记保留")


# 持久化：to_dict/from_dict 后 has_first_draw 位标记保留。
func test_first_draw_persist() -> void:
	var pd := PlayerData.new(cm)
	TavernData.refresh_first_tavern(pd, "Bronze", false)
	TavernData.refresh_first_tavern(pd, "Gold", true)
	var saved: Dictionary = pd.to_dict()
	var pd2 := PlayerData.from_dict(saved, cm)
	assert_eq(TavernData.is_first_one_draw(pd2, "Bronze"), false, "存档后单抽标记保留")
	assert_eq(TavernData.is_first_ten_draw(pd2, "Gold"), false, "存档后十连标记保留")


# ---- 品质展示阈值（照源 tavern.lua:233-237 getExRank，2026-07-08）----

# 源 getExRank：TavernType[ex_rank_key[box]]['true']['false'][0]["Exhibition Rank"]（固定十连付费层）。
# bronze Exhibition Rank=3（playBurst 阈值：equip 品质>=3 显示旋转光效）。
func test_get_ex_rank_bronze() -> void:
	assert_eq(TavernData.get_ex_rank("bronze", cm), 3, "bronze 十连付费 Exhibition Rank=3")


# gold/MagicSoul Exhibition Rank=4（钻石卡池阈值更高，源 Gold/MagicSoul ['true']['false']['0']=4）。
func test_get_ex_rank_gold_magic() -> void:
	assert_eq(TavernData.get_ex_rank("gold", cm), 4, "gold Exhibition Rank=4")
	assert_eq(TavernData.get_ex_rank("magic", cm), 4, "MagicSoul Exhibition Rank=4")


# 未知 box（EX_RANK_KEY_MAP 无映射）→ 0。
func test_get_ex_rank_missing() -> void:
	assert_eq(TavernData.get_ex_rank("nonexist", cm), 0, "未知 box → 0")


# 源 local_server.lua:1660-1669 ask_magicsoul：6 个随机英雄 ID（首个每日特别 1-15，余 1-30）。
func test_ask_magicsoul_returns_six_ids() -> void:
	var ids: Array[int] = TavernData.ask_magicsoul(BattleRng.new(42))
	assert_eq(ids.size(), 6, "ask_magicsoul 返回 6 个英雄 ID")


func test_ask_magicsoul_id_range_and_special_first() -> void:
	var ids: Array[int] = TavernData.ask_magicsoul(BattleRng.new(7))
	assert_true(ids[0] >= 1 and ids[0] <= 15, "首个每日特别英雄 ID 在 1-15（=%d）" % ids[0])
	for i in range(1, ids.size()):
		assert_true(ids[i] >= 1 and ids[i] <= 30, "其余 ID 在 1-30（idx%d=%d）" % [i, ids[i]])


func test_ask_magicsoul_deterministic_same_seed() -> void:
	# BattleRng 确定性契约：同 seed 同序列（源 math_random 非确定，单机化用 BattleRng 支持回放）
	var a: Array[int] = TavernData.ask_magicsoul(BattleRng.new(99))
	var b: Array[int] = TavernData.ask_magicsoul(BattleRng.new(99))
	assert_eq(a, b, "同 seed 返回相同 ID 序列")


# ---- 品质分池(原版服务器掉落组的单机化重建,2026-09-07)----
# 原版客户端证据:TavernType 表每行带 Chest Group ID 且首抽/累计抽数切换组号(掉落组
# 服务器私有);Gold 十连文案"十连抽必得英雄";协议 _new_heroes/_smash_idx(新英雄/
# 重复碎魂);MagicSoul DrawTimes 26 切组。数值不可考,按品质重建。

func _roll_many_ids(tavern_type: String, is_ten: bool, is_first: bool, magic_combo: int, rounds: int) -> Array:
	var ids: Array = []
	for i in range(rounds):
		var rng := BattleRng.new(1000 + i)
		var loots: Array = TavernData.roll_tavern_loot(1 if is_ten else 0, 0, rng, cm, tavern_type, is_first, magic_combo)
		for loot in loots:
			ids.append(int(loot["id"]))
	return ids


func _quality_of(eid: int) -> int:
	return int(cm.get_raw_table("Equip").get(str(eid), {}).get("Quality", 0))


# 各箱品质池:Bronze 1-2 / Gold 3-4 / MagicSoul 4-6(实测池 76/190/152 非空)。
func test_pool_quality_ranges() -> void:
	for entry in [["Bronze", 1, 2], ["Gold", 3, 4], ["MagicSoul", 4, 6]]:
		var ids: Array = _roll_many_ids(entry[0], false, false, 0, 40)
		assert_gt(ids.size(), 0, "%s 产出非空" % entry[0])
		for eid in ids:
			if eid < 100:
				continue
			var q: int = _quality_of(eid)
			assert_true(q >= entry[1] and q <= entry[2],
				"%s equip 品质 %d 应在 [%d,%d]" % [entry[0], q, entry[1], entry[2]])


# 首抽高一档(源首抽独立 Chest Group:Bronze 2-3 / Gold 4-5 / MagicSoul 5-6)。
func test_first_draw_quality_boost() -> void:
	for entry in [["Bronze", 2, 3], ["Gold", 4, 5], ["MagicSoul", 5, 6]]:
		var ids: Array = _roll_many_ids(entry[0], false, true, 0, 40)
		for eid in ids:
			if eid < 100:
				continue
			var q: int = _quality_of(eid)
			assert_true(q >= entry[1] and q <= entry[2],
				"%s 首抽品质 %d 应在 [%d,%d]" % [entry[0], q, entry[1], entry[2]])


# Gold 十连必得英雄位(源 gold TAVERNRES.HERO_IS "十连抽必得英雄")。
func test_gold_ten_hero_guarantee() -> void:
	for i in range(10):
		var rng := BattleRng.new(2000 + i)
		var loots: Array = TavernData.roll_tavern_loot(1, 0, rng, cm, "Gold", false, 0)
		var has_hero: bool = false
		for loot in loots:
			if int(loot["id"]) < 100:
				has_hero = true
		assert_true(has_hero, "gold 十连必含英雄位(seed %d)" % i)


# MagicSoul 第 26 次十连起品质池升 5-6(源 DrawTimes 26 组 23→24)。
func test_magic_26_combo_pool() -> void:
	var ids: Array = _roll_many_ids("MagicSoul", true, false, 26, 20)
	for eid in ids:
		if eid < 100:
			continue
		var q: int = _quality_of(eid)
		assert_true(q >= 5 and q <= 6, "magic 26 次后品质 %d 应在 [5,6]" % q)
