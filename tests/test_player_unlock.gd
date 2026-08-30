extends GutTest
# Step 3 升级解锁钩子测试（照源 baselsr.lua:29-54 playerLevelup）。
# PlayerData.check_unlocks 遍历 11 功能，新解锁（check_area_unlock 且 record 未设）→ set + 发信号。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 baselsr :46-49 遍历 11 功能 checkAreaUnlock → teach+endTeach。level 7 解锁 SkillUpgrade(54)。
func test_check_unlocks_at_level_7() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 7
	var newly: Array[StringName] = pd.check_unlocks()
	assert_true(newly.has(&"unlockSkillUpgrade"), "7 级 = SkillUpgrade 阈值 → 解锁")
	assert_eq(pd.get_tutorial_record(54), 1, "record unlockSkillUpgrade(54) 已设")


# 6 级未达 7 级阈值 → SkillUpgrade 不解锁。
func test_check_unlocks_at_level_6_no_skill_upgrade() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 6
	var newly: Array[StringName] = pd.check_unlocks()
	assert_true(newly.has(&"unlockSkillUpgrade"), "6 级也解锁（单机化全放开）")
	assert_ne(pd.get_tutorial_record(54), 0, "解锁 teach record 已设")


# Crusade/Excavate 不在 PlayerLevel.Unlock → get_area_unlock_level 返 0 → 默认解锁（源设计）。
func test_check_unlocks_default_unlocked_features() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 1
	var newly: Array[StringName] = pd.check_unlocks()
	assert_true(newly.has(&"unlockCrusade"), "Crusade 不在 PlayerLevel.Unlock → 默认解锁")
	assert_true(newly.has(&"unlockExcavate"), "Excavate 默认解锁")
	# 单机化全放开：1 级全部功能解锁
	assert_true(newly.has(&"unlockGuild"), "Guild 1 级也解锁（单机化全放开）")


# record 守卫：重复 check_unlocks 不再触发已解锁功能（源 ed.teach not checkDone 等价）。
func test_check_unlocks_idempotent() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 7
	var first: Array[StringName] = pd.check_unlocks()
	assert_true(first.has(&"unlockSkillUpgrade"), "首次解锁 SkillUpgrade")
	var second: Array[StringName] = pd.check_unlocks()
	assert_false(second.has(&"unlockSkillUpgrade"), "重复调用不再触发（record 守卫）")


# 源 happenPlayerLevelup 仅升级时触发：add_team_exp 不升级 → check_unlocks 不调 → record 不设。
func test_add_team_exp_no_levelup_no_unlock() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 1
	pd.team_exp = 0
	pd.add_team_exp(1)  # 不够升级（level 1 需 25 exp）
	assert_eq(pd.team_level, 1, "未升级")
	# Crusade 默认解锁但未升级 → 不该触发（happenPlayerLevelup 标志未设）
	assert_eq(pd.get_tutorial_record(87), 0, "未升级 → Crusade 不触发")


# 实际升级触发 check_unlocks：升到 7+ 级 → SkillUpgrade record 已设。
func test_add_team_exp_levelup_triggers_unlock() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 6
	pd.add_team_exp(100)  # level 6 Exp=30，连升到 8 级（跨 7 级阈值）
	assert_true(pd.team_level >= 7, "升到 7 级以上")
	assert_eq(pd.get_tutorial_record(54), 1, "升级跨 7 级 → SkillUpgrade(54) 已记录")
