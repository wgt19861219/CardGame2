extends GutTest
# PlayerDataSerde 存档往返（高危：to_dict/from_dict 字段丢失致玩家进度清零）。
# 测顶层标量 + items + team 往返全字段保留（子 manager 各自有单测，此处验委托链不断）。
# 入口统一 int 校验（存档/外部数据可能含 float，强制 int）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 to_dict/from_dict：顶层标量字段往返不丢
func test_roundtrip_preserves_scalar_fields() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 999
	pd.vitality = 200
	pd.team_level = 30
	pd.team_exp = 1500
	pd.skill_points = 50
	pd.player_name = "TestHero"
	var d: Dictionary = PlayerDataSerde.to_dict(pd)
	var pd2 := PlayerDataSerde.from_dict(d, cm)
	assert_eq(pd2.diamond, 999, "diamond 往返")
	assert_eq(pd2.vitality, 200, "vitality 往返")
	assert_eq(pd2.team_level, 30, "team_level 往返")
	assert_eq(pd2.team_exp, 1500, "team_exp 往返")
	assert_eq(pd2.skill_points, 50, "skill_points 往返")
	assert_eq(str(pd2.player_name), "TestHero", "player_name 往返")


# 源 from_dict items 重建 int key/value（存档 float 强制 int）+ team Array[int]
func test_roundtrip_preserves_items_and_team() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(100, 5)
	pd.add_item(200, 10)
	pd.team = [101, 102, 103]
	var d: Dictionary = PlayerDataSerde.to_dict(pd)
	var pd2 := PlayerDataSerde.from_dict(d, cm)
	assert_eq(int(pd2.items.get(100, 0)), 5, "item 100 往返")
	assert_eq(int(pd2.items.get(200, 0)), 10, "item 200 往返")
	assert_eq(pd2.team, [101, 102, 103], "team 往返")


# 源 from_dict int 校验：存档 float 值强制 int（防 JSON float→int 静默丢精度）
func test_from_dict_coerces_float_to_int() -> void:
	var d: Dictionary = {
		"diamond": 99.9, "vitality": 50.5, "team_level": 20.0,
		"items": {}, "team": [],
	}
	var pd := PlayerDataSerde.from_dict(d, cm)
	assert_eq(pd.diamond, 99, "diamond float→int 截断")
	assert_eq(pd.vitality, 50, "vitality float→int 截断")
	assert_eq(pd.team_level, 20, "team_level float→int")


# arena_point 统一归 PlayerData（源 player.arenapoint）顶层持久化
func test_roundtrip_preserves_arena_point() -> void:
	var pd := PlayerData.new(cm)
	pd.arena_point = 777
	pd.crusade_point = 555
	var d: Dictionary = PlayerDataSerde.to_dict(pd)
	assert_eq(int(d["arena_point"]), 777, "to_dict 含 arena_point")
	var pd2 := PlayerDataSerde.from_dict(d, cm)
	assert_eq(pd2.arena_point, 777, "arena_point 往返")
	assert_eq(pd2.crusade_point, 555, "crusade_point 往返")


# 旧存档迁移：arena_point 字段缺失时从 ladder.arenapoint fallback（ladder 删字段后兼容）
func test_from_dict_old_save_ladder_arenapoint_fallback() -> void:
	var d: Dictionary = {"ladder": {"pvp": {}, "arenapoint": 123}}
	var pd := PlayerDataSerde.from_dict(d, cm)
	assert_eq(pd.arena_point, 123, "旧存档 ladder.arenapoint 迁移到 pd.arena_point")


# P2-2026-07-10：损坏存档守卫（ladder 非 Dictionary 时 as Dictionary 返 null → .get 崩溃）
func test_from_dict_corrupted_ladder_does_not_crash() -> void:
	var d: Dictionary = {"ladder": "corrupted_string_not_dict"}
	var pd := PlayerDataSerde.from_dict(d, cm)
	assert_eq(pd.arena_point, 0, "损坏 ladder 非崩溃，arena_point 默认 0")


# P2-2026-07-10：损坏存档守卫（tavern_record 值非 Dictionary 时不崩溃）
func test_from_dict_corrupted_tavern_record_does_not_crash() -> void:
	var d: Dictionary = {"tavern_record": {"bad_key": "not_a_dict"}}
	var pd := PlayerDataSerde.from_dict(d, cm)
	assert_true(pd.tavern_record.is_empty(), "损坏 tavern_record 值被跳过，不崩溃")



# C1 stage_reset_times 持久化往返（P1-C1 修复：精英关 reset 计费次数持久化）
func test_roundtrip_preserves_stage_reset_times() -> void:
	var pd := PlayerData.new(cm)
	pd.stage_reset_times[5] = 3
	pd.stage_reset_times[12] = 7
	var d: Dictionary = PlayerDataSerde.to_dict(pd)
	assert_eq(int(d["stage_reset_times"][5]), 3, "to_dict 含 stage_reset_times")
	var pd2 := PlayerDataSerde.from_dict(d, cm)
	assert_eq(int(pd2.stage_reset_times.get(5, 0)), 3, "stage_reset_times 往返 key=5")
	assert_eq(int(pd2.stage_reset_times.get(12, 0)), 7, "stage_reset_times 往返 key=12")
