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
	# 单机化全放开（2026-08-29）：任何等级均已解锁（源运营门槛不迁移）；
	# 手动 close_module 的 notopen 语义保留。
	assert_true(fl.check_area_unlock(&"SkillUpgrade", 6), "6 级也解锁（单机化全放开）")
	assert_true(fl.check_area_unlock(&"PVP", 1), "1 级 PVP 可进")
	fl.close_module(&"SkillUpgrade")
	assert_false(fl.check_area_unlock(&"SkillUpgrade", 99), "close_module 手动关闭仍锁")
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


# 源 getAreaUnlockPrompt：未解锁返文案，已解锁返空。单机化全放开后恒返空（无灰显提示）。
func test_get_area_unlock_prompt_locked() -> void:
	var prompt: String = fl.get_area_unlock_prompt(&"SkillUpgrade", 6)
	assert_eq(prompt, "", "单机化全放开 → 恒空文案")


func test_get_area_unlock_prompt_unlocked_empty() -> void:
	assert_eq(fl.get_area_unlock_prompt(&"SkillUpgrade", 7), "", "已解锁 → 空文案")
	assert_eq(fl.get_area_unlock_prompt(&"Crusade", 1), "", "默认解锁 → 空文案")


# 源 getAreaUnlockvip（playerlimit.lua:88-98）`if vt[index][key] then` 真值判断：
# 找首个值为 true 的 VIP 等级（VIP.json VIP0 多键显式存 false，实测阈值）。
func test_get_area_unlock_vip_truthy() -> void:
	assert_eq(fl.get_area_unlock_vip(&"Raid One Function"), 0, "Raid One Function VIP0 即 true → 0")
	assert_eq(fl.get_area_unlock_vip(&"Multiple Midas"), 2, "Multiple Midas VIP0/1 false → 首真 VIP2")
	assert_eq(fl.get_area_unlock_vip(&"Skill Upgrade CD Reset"), 2, "Skill Upgrade CD Reset → VIP2")
	assert_eq(fl.get_area_unlock_vip(&"Raid Ten Function"), 4, "Raid Ten Function → VIP4")
	assert_eq(fl.get_area_unlock_vip(&"Item One-Click-Upgrade"), 7, "Item One-Click-Upgrade → VIP7")
	assert_eq(fl.get_area_unlock_vip(&"Magic Soul Box"), 11, "Magic Soul Box → VIP11")


# vip 门禁单机化同放开（check_area_unlock 恒 true）；查表口径由 unlock_require 保留。
func test_check_area_unlock_vip_threshold() -> void:
	assert_true(fl.check_area_unlock(&"Multiple Midas", 99, 0), "VIP0 也解锁（单机化全放开）")
	var req: Dictionary = fl.unlock_require(&"Multiple Midas", 99, 0)
	assert_eq(int(req["limit"]), 2, "查表口径保留：Multiple Midas 需 VIP2")


# 源 baselsr.lua:33-45 playerLevelup 11 功能表映射（Step 3 升级钩子用）。
func test_baselsr_unlock_map_has_11() -> void:
	assert_eq(FeatureLimit.BASELSR_UNLOCK_MAP.size(), 11, "baselsr 11 功能映射")
	assert_eq(FeatureLimit.BASELSR_UNLOCK_MAP[&"SkillUpgrade"], &"unlockSkillUpgrade", "SkillUpgrade→unlockSkillUpgrade")
	assert_eq(FeatureLimit.BASELSR_UNLOCK_MAP[&"Excavate"], &"unlockExcavate", "Excavate→unlockExcavate")
