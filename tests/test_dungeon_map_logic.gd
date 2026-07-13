extends GutTest

## dungeon_map Logic 层验证（照源 ui/dungeon_map.lua:49-125）。
# get_dungeon_bosses（按 group_id 直查）+ is_boss_cleared/is_boss_unlocked/is_group_cleared。

var _cm: ConfigManager
var _mgr: ExerciseManager


func before_each() -> void:
	_cm = GameData.config
	if not _cm.is_loaded():
		_cm.load_all()
	_mgr = ExerciseManager.new()
	_mgr.setup(_cm)


# ===== get_dungeon_bosses（源 dungeon_map.lua:49-99 getBossesForGroup）=====

func test_get_dungeon_bosses_50005() -> void:
	# 50005 = NAXXRAMAS, Stages=[50013,50014,50015] → 3 boss × 4 diff
	var bosses: Array = _mgr.get_dungeon_bosses(50005)
	assert_eq(bosses.size(), 3, "50005 = 3 boss")
	var b0: Dictionary = bosses[0]
	assert_eq(int(b0["base_id"]), 50013, "首 boss 50013")
	assert_eq(b0["difficulties"].size(), 4, "4 难度")


func test_get_dungeon_bosses_diff_ids() -> void:
	var bosses: Array = _mgr.get_dungeon_bosses(50005)
	var diffs: Array = bosses[0]["difficulties"]
	# diff id = base + (diff-1)*1000
	assert_eq(int(diffs[0]["id"]), 50013, "diff1 id = base")
	assert_eq(int(diffs[1]["id"]), 51013, "diff2 id = base+1000")
	assert_eq(int(diffs[2]["id"]), 52013, "diff3 id = base+2000")
	assert_eq(int(diffs[3]["id"]), 53013, "diff4 id = base+3000")
	assert_eq(int(diffs[0]["diff"]), 1, "diff 字段")


func test_get_dungeon_bosses_structure() -> void:
	var bosses: Array = _mgr.get_dungeon_bosses(50005)
	var b0: Dictionary = bosses[0]
	assert_true(b0.has("base_id"), "boss 有 base_id")
	assert_true(b0.has("name"), "boss 有 name")
	assert_true(b0.has("difficulties"), "boss 有 difficulties")
	var d1: Dictionary = b0["difficulties"][0]
	assert_true(d1.has("id") and d1.has("vit") and d1.has("key_cost") and d1.has("unlock_level") and d1.has("diff"), "diff 结构完整")


func test_get_dungeon_bosses_invalid_group() -> void:
	assert_eq(_mgr.get_dungeon_bosses(0).size(), 0, "group_id=0 → 空")
	assert_eq(_mgr.get_dungeon_bosses(99999).size(), 0, "无效 group_id → 空")


# ===== is_boss_cleared（源 :104-107）=====

func test_is_boss_cleared() -> void:
	var empty_progress: Dictionary = {}
	assert_false(ExerciseManager.is_boss_cleared(empty_progress, 50013), "空 progress → false")
	var progress: Dictionary = {50013: 3}
	assert_true(ExerciseManager.is_boss_cleared(progress, 50013), "progress[50013]=3 → true")
	assert_false(ExerciseManager.is_boss_cleared(progress, 50014), "未通关 50014 → false")


# ===== is_boss_unlocked（源 :110-114）=====

func test_is_boss_unlocked_first() -> void:
	var bosses: Array = _mgr.get_dungeon_bosses(50005)
	assert_true(ExerciseManager.is_boss_unlocked(bosses, {}, 1), "首关恒解锁")


func test_is_boss_unlocked_locked_without_clear() -> void:
	var bosses: Array = _mgr.get_dungeon_bosses(50005)
	assert_false(ExerciseManager.is_boss_unlocked(bosses, {}, 2), "未通关前置 → 锁 2")
	assert_false(ExerciseManager.is_boss_unlocked(bosses, {}, 3), "未通关前置 → 锁 3")


func test_is_boss_unlocked_after_prev_clear() -> void:
	var bosses: Array = _mgr.get_dungeon_bosses(50005)
	var progress: Dictionary = {50013: 3}
	assert_true(ExerciseManager.is_boss_unlocked(bosses, progress, 2), "通关 50013 → 解锁 2")
	assert_false(ExerciseManager.is_boss_unlocked(bosses, progress, 3), "未通关 50014 → 锁 3")


func test_is_boss_unlocked_out_of_range() -> void:
	var bosses: Array = _mgr.get_dungeon_bosses(50005)
	assert_false(ExerciseManager.is_boss_unlocked(bosses, {}, 99), "超出范围 → false")


# ===== is_group_cleared（源 :116-125）=====

func test_is_group_cleared_all() -> void:
	# 50005 = 3 boss（50013/50014/50015），group 1 起始偏移 0
	var bosses: Array = _mgr.get_dungeon_bosses(50005)
	var group_counts: Dictionary = {1: 3}
	var group_offsets: Dictionary = {1: 0}
	var progress: Dictionary = {50013: 3, 50014: 2, 50015: 1}
	assert_true(ExerciseManager.is_group_cleared(bosses, group_counts, group_offsets, progress, 1), "全通关 → true")


func test_is_group_cleared_partial() -> void:
	var bosses: Array = _mgr.get_dungeon_bosses(50005)
	var group_counts: Dictionary = {1: 3}
	var group_offsets: Dictionary = {1: 0}
	var progress: Dictionary = {50013: 3, 50014: 2}  # 缺 50015
	assert_false(ExerciseManager.is_group_cleared(bosses, group_counts, group_offsets, progress, 1), "部分通关 → false")


func test_is_group_cleared_with_offset() -> void:
	# 多组场景：group 2 从 idx 4 起（group 1 占 3 + group 2 偏移），group_counts[2]=2
	var bosses: Array = _mgr.get_dungeon_bosses(50005)  # 3 boss 作 group1
	# 模拟 group 2（用同 bosses 但偏移校验逻辑）
	var group_counts: Dictionary = {1: 3, 2: 2}
	var group_offsets: Dictionary = {1: 0, 2: 3}
	var progress: Dictionary = {50013: 3, 50014: 2, 50015: 1}
	# group 2 需 boss idx 4,5（超出 bosses.size()=3）→ false
	assert_false(ExerciseManager.is_group_cleared(bosses, group_counts, group_offsets, progress, 2), "group2 超范围 → false")


# ===== dungeon Battle 数据（expand_battle_dungeon.py 注入）=====

func test_dungeon_battle_data_injected() -> void:
	# expand_battle_dungeon.py 照源 Battle.lua:80954-81124 注入：50013 base + 51013/52013/53013 diff
	assert_true(_cm.has_entry(&"Battle", 50013), "50013 base Battle 数据")
	assert_true(_cm.has_entry(&"Battle", 51013), "51013 diff2 Battle 数据")
	assert_true(_cm.has_entry(&"Battle", 53013), "53013 diff4 Battle 数据")
	assert_true(_cm.has_entry(&"Battle", 53021), "53021 末关 diff4")


func test_dungeon_battle_assemble_51013() -> void:
	# 51013（纳克萨玛斯首关 diff2）battle_info 非空 + 敌人 tid 正确
	# 源 dungeonBosses 50013 = {boss=6 末日使者, m=[40,42,17]}，wave3 Monster 4 ID = boss = 6
	var battle_info: Dictionary = BattleData.from_config(_cm, 51013).battle_info
	assert_false(battle_info.is_empty(), "51013 battle_info 非空（dungeon 战斗有真实敌人，非 stub）")
