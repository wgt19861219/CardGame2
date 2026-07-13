extends GutTest
# merchant_talk_data NPC 对话选词单测（照源 ui/market/market.lua:285-324 getTalkContent）。
# MerchantTalk 表（7 店 × 6 Event）+ 地精/黑市 refresh 态 Talk7-12 + 避重复。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# static _pre_talk_key/_pre_talk_id 跨测试隔离（避重复状态不污染下个测试）
func before_each() -> void:
	MerchantTalkData.reset_talk_state()


# 收集某 shop/event 的 Talk bi..ei 文案集合（验返回值在集合内，不硬编码文案）
func _collect_talks(shop_id: int, key: String, bi: int, ei: int) -> Array:
	var info: Dictionary = cm.get_raw_table(&"MerchantTalk").get(str(shop_id), {}).get(key, {})
	var out: Array = []
	for i in range(bi, ei + 1):
		var s: Variant = info.get("Talk " + str(i), null)
		if s != null:
			out.append(String(s))
	return out


# Shop1 Welcome Talk1-3，选词在集合内
func test_talk_shop1_welcome() -> void:
	var rng := BattleRng.new(12345)
	var text: String = MerchantTalkData.get_talk_content(1, "Welcome", "refresh", rng, cm)
	var valid: Array = _collect_talks(1, "Welcome", 1, 6)
	assert_eq(valid.size(), 3, "Shop1 Welcome 3 句")
	assert_true(text in valid, "选词在 Talk1-6 集合内: " + text)


# Shop1 Purchase 无 Talk → 返空（源收集空返 nil）
func test_talk_no_talk_returns_empty() -> void:
	var rng := BattleRng.new(1)
	assert_eq(MerchantTalkData.get_talk_content(1, "Purchase", "refresh", rng, cm), "", "Shop1 Purchase 无 Talk 返空")


# 地精(2) refresh 态 → Talk7-12（源 :288-290）
func test_talk_goblin_refresh_range() -> void:
	var rng := BattleRng.new(999)
	var text: String = MerchantTalkData.get_talk_content(2, "Welcome", "refresh", rng, cm)
	var valid7: Array = _collect_talks(2, "Welcome", 7, 12)
	assert_true(valid7.size() > 0, "Shop2 Welcome Talk7-12 非空")
	assert_true(text in valid7, "refresh 态选 Talk7-12 集合: " + text)


# 地精(2) 非 refresh 态 → Talk1-6
func test_talk_goblin_default_range() -> void:
	var rng := BattleRng.new(999)
	var text: String = MerchantTalkData.get_talk_content(2, "Welcome", "expire", rng, cm)
	var valid: Array = _collect_talks(2, "Welcome", 1, 6)
	assert_true(valid.size() > 0, "Shop2 Welcome Talk1-6 非空")
	assert_true(text in valid, "expire 态选 Talk1-6: " + text)


# 普通店(1) 即使 refresh 态也 Talk1-6（仅 id 2/3 特殊）
func test_talk_shop1_refresh_default_range() -> void:
	var rng := BattleRng.new(12345)
	var text: String = MerchantTalkData.get_talk_content(1, "Touch", "refresh", rng, cm)
	var valid: Array = _collect_talks(1, "Touch", 1, 6)
	assert_true(text in valid, "Shop1 refresh 态仍 Talk1-6（id 非 2/3）: " + text)


# 避重复：同 Event 连续两次选不同句（talks>1 时，源 :312-318）
func test_talk_no_repeat() -> void:
	var rng := BattleRng.new(12345)
	var t1: String = MerchantTalkData.get_talk_content(1, "Welcome", "refresh", rng, cm)
	var t2: String = MerchantTalkData.get_talk_content(1, "Welcome", "refresh", rng, cm)
	assert_true(t1 != "" and t2 != "", "两次都有台词")
	assert_ne(t1, t2, "同 Event 连续不重复（Shop1 Welcome 3 句 >1）")


# 黑市(3) refresh 态 → Talk7-12（与地精同分支）
func test_talk_blackmarket_refresh_range() -> void:
	var rng := BattleRng.new(7)
	var text: String = MerchantTalkData.get_talk_content(3, "Welcome", "refresh", rng, cm)
	var valid7: Array = _collect_talks(3, "Welcome", 7, 12)
	assert_true(text in valid7, "黑市 refresh 态 Talk7-12: " + text)
