extends GutTest
# GM 命令集单测 — 照源 local_server.lua:1912-2094 gm_cmd handler 12 类命令。
# 覆盖：set_money / set_vitality / set_player_level / set_player_exp / set_items（bits 解码）
# / set_hero_info / get_all_heroes / reset_device / _build_user 返回结构。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_player() -> PlayerData:
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	return pd


func test_set_money_gold() -> void:
	var pd := _make_player()
	GmManager.execute(pd, cm, {"_set_money": {"_type": "gold", "_amount": 999999}})
	assert_eq(pd.hero_manager.gold, 999999, "set_money gold 应更新 hero_manager.gold")


func test_set_money_diamond() -> void:
	var pd := _make_player()
	GmManager.execute(pd, cm, {"_set_money": {"_type": "diamond", "_amount": 8888}})
	assert_eq(pd.diamond, 8888, "set_money diamond 应更新 player.diamond")


func test_set_money_crusadepoint() -> void:
	var pd := _make_player()
	GmManager.execute(pd, cm, {"_set_money": {"_type": "crusadepoint", "_amount": 500}})
	assert_eq(pd.crusade_point, 500, "set_money crusadepoint 应更新 crusade_point")


func test_set_money_legacy_format() -> void:
	var pd := _make_player()
	GmManager.execute(pd, cm, {"_set_money": {"_money": 12345, "_rmb": 678}})
	assert_eq(pd.hero_manager.gold, 12345, "旧格式 _money 应映射到 gold")
	assert_eq(pd.diamond, 678, "旧格式 _rmb 应映射到 diamond")


func test_set_vitality() -> void:
	var pd := _make_player()
	GmManager.execute(pd, cm, {"_set_vitality": 240})
	assert_eq(pd.vitality, 240, "set_vitality 应更新体力")


func test_set_player_level() -> void:
	var pd := _make_player()
	GmManager.execute(pd, cm, {"_set_player_level": 60})
	assert_eq(pd.team_level, 60, "set_player_level 应更新战队等级")


func test_set_player_exp() -> void:
	var pd := _make_player()
	GmManager.execute(pd, cm, {"_set_player_exp": 5000})
	assert_eq(pd.team_exp, 5000, "set_player_exp 应更新战队经验")


func test_set_items_bits_decode() -> void:
	var pd := _make_player()
	# 源 ed.bits：id 占低 10 位，amount 占 11-21 位。
	# id=42, amount=99 → packed = 42 | (99 << 10) = 42 + 101376 = 101418
	var packed: int = 42 | (99 << 10)
	GmManager.execute(pd, cm, {"_set_items": [packed]})
	assert_eq(int(pd.items.get(42, 0)), 99, "set_items bits 解码：id=42 amount=99")


func test_set_hero_info() -> void:
	var pd := _make_player()
	# 默认英雄 tid=1 存在（apply_default_data 加 tid 1-5）
	GmManager.execute(pd, cm, {"_set_hero_info": [{"_tid": 1, "_rank": 3, "_level": 50, "_stars": 5}]})
	var hero: HeroInstance = GmManager._find_hero_by_tid(pd, 1)
	assert_not_null(hero, "tid=1 英雄应存在")
	assert_eq(hero.rank, 3, "set_hero_info rank 应更新")
	assert_eq(hero.level, 50, "set_hero_info level 应更新")
	assert_eq(hero.stars, 5, "set_hero_info stars 应更新")


func test_get_all_heroes() -> void:
	var pd := _make_player()
	var before: int = pd.hero_manager.heroes.size()
	GmManager.execute(pd, cm, {"_get_all_heroes": 1})
	var after: int = pd.hero_manager.heroes.size()
	assert_true(after > before, "get_all_heroes 后英雄数应增加（Unit 表 Hero 类型加入）")


func test_reset_device() -> void:
	var pd := _make_player()
	pd.diamond = 999
	pd.team_level = 50
	GmManager.execute(pd, cm, {"_reset_device": 1})
	# apply_default_data 重置：diamond 回到默认 5000，等级回 1
	assert_eq(pd.diamond, 5000, "reset_device 应重置 diamond 到默认")
	assert_eq(pd.team_level, 1, "reset_device 应重置等级到 1")


func test_build_user_return_structure() -> void:
	var pd := _make_player()
	var r: Dictionary = GmManager.execute(pd, cm, {"_set_player_level": 30})
	assert_true(r.has("_reset"), "返回应含 _reset")
	var reset: Dictionary = r["_reset"]
	assert_true(reset.has("_user"), "_reset 应含 _user")
	var user: Dictionary = reset["_user"]
	assert_eq(int(user["_level"]), 30, "_user._level 应反映 set_player_level")
	assert_eq(String(user["_name"]), "Player", "_user._name 应为玩家名")
	assert_true(user.has("_money"), "_user 应含 _money")
	assert_true(user.has("_rmb"), "_user 应含 _rmb")


func test_bits_helper() -> void:
	# 验证 bits 解码与源 tools.lua:66 一致
	assert_eq(GmManager._bits(0b1111111111, 0, 10), 1023, "低 10 位全 1 = 1023")
	assert_eq(GmManager._bits(0b111110000000000, 10, 11), 0b11111, "11-21 位 = 31")
