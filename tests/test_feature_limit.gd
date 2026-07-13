extends GutTest
# Step 1 FeatureLimit 功能解锁查询测试（照源 playerlimit.lua）。
# 真实 ConfigManager.load_all 加载 PlayerLevel.json，等级阈值从 JSON Unlock 字段读（非硬编码）。

var cm: ConfigManager
var fl: FeatureLimit


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# before_each 新建 fl 保证测试隔离（close_module 的 _module_switch 状态不跨测试泄露）。
func before_each() -> void:
	fl = FeatureLimit.new(cm)


# 源 getAreaUnlockLevel：遍历 PlayerLevel[i].Unlock 找 key。真实等级（PlayerLevel.json Unlock 字段）。
func test_get_area_unlock_level_real_thresholds() -> void:
	assert_eq(fl.get_area_unlock_level(&"SkillUpgrade"), 7, "SkillUpgrade 7 级解锁")
	assert_eq(fl.get_area_unlock_level(&"PVP"), 10, "PVP 10 级")
	assert_eq(fl.get_area_unlock_level(&"Elite"), 11, "Elite 11 级")
	assert_eq(fl.get_area_unlock_level(&"Midas"), 12, "Midas 12 级")
	assert_eq(fl.get_area_unlock_level(&"COT"), 14, "COT 14 级")
	assert_eq(fl.get_area_unlock_level(&"Enhance"), 20, "Enhance 20 级")
	assert_eq(fl.get_area_unlock_level(&"WorldChannel"), 24, "WorldChannel 24 级")
	assert_eq(fl.get_area_unlock_level(&"Exercise"), 25, "Exercise 25 级")
	assert_eq(fl.get_area_unlock_level(&"sshop"), 30, "sshop 30 级")
	assert_eq(fl.get_area_unlock_level(&"Guild"), 32, "Guild 32 级")
	assert_eq(fl.get_area_unlock_level(&"ssshop"), 40, "ssshop 40 级")
	assert_eq(fl.get_area_unlock_level(&"Awake"), 90, "Awake 90 级")


# 源 getAreaUnlockLevel 找不到返 0（playerlimit.lua:74 print 警告）：Crusade/Excavate/shop/StarShop 不在表。
func test_get_area_unlock_level_missing_returns_zero() -> void:
	assert_eq(fl.get_area_unlock_level(&"Crusade"), 0, "Crusade 不在 PlayerLevel.Unlock → 0")
	assert_eq(fl.get_area_unlock_level(&"Excavate"), 0, "Excavate 不在表 → 0")
	assert_eq(fl.get_area_unlock_level(&"shop"), 0, "shop 不在表 → 0")


# 源 checkAreaUnlock：limit <= current。Crusade 返 0 → 0<=任意 playerlevel → 永远 true（默认已解锁）。
func test_check_area_unlock_threshold() -> void:
	assert_true(fl.check_area_unlock(&"SkillUpgrade", 7), "7 级 = 阈值 → 已解锁")
	assert_false(fl.check_area_unlock(&"SkillUpgrade", 6), "6 级 < 阈值 7 → 未解锁")
	assert_true(fl.check_area_unlock(&"PVP", 10), "10 级 PVP 解锁")


func test_check_area_unlock_default_unlocked() -> void:
	# Crusade 不在表 → get_area_unlock_level 返 0 → 0<=1 → true（源设计：默认已解锁）
	assert_true(fl.check_area_unlock(&"Crusade", 1), "Crusade 返 0 → 1 级即已解锁")
	assert_true(fl.check_area_unlock(&"Excavate", 1), "Excavate 默认已解锁")


# 源 closeModule（module_switch）：关闭后 check_area_unlock 返 false（notopen 分支）。
func test_close_module_blocks_unlock() -> void:
	assert_true(fl.check_area_unlock(&"SkillUpgrade", 7), "关闭前已解锁")
	fl.close_module(&"SkillUpgrade")
	assert_false(fl.check_area_unlock(&"SkillUpgrade", 7), "close_module 后 notopen → false")
	assert_false(fl.check_area_unlock(&"SkillUpgrade", 99), "close_module 后即使满级也 false")


# 源 unlockRequire 返回结构 {limit,type,current}。
func test_unlock_require_structure() -> void:
	var req: Dictionary = fl.unlock_require(&"SkillUpgrade", 6)
	assert_eq(int(req["limit"]), 7, "limit=解锁等级 7")
	assert_eq(req["type"], &"playerlevel", "type=playerlevel")
	assert_eq(int(req["current"]), 6, "current=当前等级 6")


func test_unlock_require_notopen() -> void:
	fl.close_module(&"PVP")
	var req: Dictionary = fl.unlock_require(&"PVP", 99)
	assert_eq(req["type"], &"notopen", "close_module → type=notopen")


# 源 getAreaUnlockPrompt：未解锁返文案，已解锁返空。
func test_get_area_unlock_prompt_locked() -> void:
	var prompt: String = fl.get_area_unlock_prompt(&"SkillUpgrade", 6)
	assert_true(prompt.find("7") >= 0, "6 级未解锁 SkillUpgrade 提示含等级 7：'%s'" % prompt)


func test_get_area_unlock_prompt_unlocked_empty() -> void:
	assert_eq(fl.get_area_unlock_prompt(&"SkillUpgrade", 7), "", "已解锁 → 空文案")
	assert_eq(fl.get_area_unlock_prompt(&"Crusade", 1), "", "默认解锁 → 空文案")


# 源 baselsr.lua:33-45 playerLevelup 11 功能表映射（Step 3 升级钩子用）。
func test_baselsr_unlock_map_has_11() -> void:
	assert_eq(FeatureLimit.BASELSR_UNLOCK_MAP.size(), 11, "baselsr 11 功能映射")
	assert_eq(FeatureLimit.BASELSR_UNLOCK_MAP[&"SkillUpgrade"], &"unlockSkillUpgrade", "SkillUpgrade→unlockSkillUpgrade")
	assert_eq(FeatureLimit.BASELSR_UNLOCK_MAP[&"Excavate"], &"unlockExcavate", "Excavate→unlockExcavate")
