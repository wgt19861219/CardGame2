extends GutTest
# Phase 2.4 skill 数据层（照源 skill.lua:getSkillInfo 重翻，2026-06-30）。
# SkillGroup.json：caster(英雄) -> slot -> {Skill Group ID, Growth Field/Value}。
# Skill.json：group -> level 0 基础字段。成长 = 基础 + (level-1) × Growth Value（skill/buff 字段分别 patch）。
# SkillLibrary.get_skill_info 照源 getSkillInfo 返回 info dict（含 buff_info + Growth + group 槽继承）。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()

# SkillGroupData 访问层：Coco(caster 1) slot 1 -> Skill Group ID 10
func test_skill_group_data_access() -> void:
	var sgd := SkillGroupData.new(cm)
	assert_true(sgd.has_slot(1, 1), "Coco(caster 1) 有 slot 1")
	assert_eq(sgd.get_skill_group_id(1, 1), 10, "Coco slot 1 -> Skill Group ID 10")
	var groups := sgd.get_all_groups(1)
	assert_true(groups.size() >= 4, "Coco 至少 4 个技能槽")

# 照源 getSkillInfo：SkillLibrary 按 group_id 取 info（Coco ult group 10）
func test_skill_info_data_driven() -> void:
	var lib := SkillLibrary.new(cm)
	assert_true(lib.has_skill(10), "Coco ult 技能组 10 存在")
	var info := lib.get_skill_info(10, 1)
	assert_eq(int(info.get("ID", 0)), 101, "实例 ID=101（group 10 level 0）")
	assert_eq(str(info.get("Damage Type", "")), "AP", "Damage Type=AP")
	assert_eq(int(info.get("Basic Num", 0)), 75, "1 级 Basic Num=75（基础）")

# Growth 等级成长：Coco ult 基础 75，Growth Basic Num +15/级 → 5 级 = 75+4×15 = 135
func test_skill_info_growth_scales() -> void:
	var lib := SkillLibrary.new(cm)
	var i1 := lib.get_skill_info(10, 1)
	var i5 := lib.get_skill_info(10, 5)
	assert_eq(int(i1.get("Basic Num", 0)), 75, "1 级基础值")
	assert_eq(int(i5.get("Basic Num", 0)), 135, "5 级成长值 135（75+4×15）")

# 英雄技能装配：Coco 按 skill_levels 取 info，至少 4 个
func test_hero_skill_loadout() -> void:
	var sgd := SkillGroupData.new(cm)
	var hero := HeroInstance.new(1, 1, 1)
	var skills := sgd.get_skills(1, hero.skill_levels, SkillLibrary.new(cm))
	assert_true(skills.size() >= 4, "Coco 至少 4 个技能 info 装配成功")

func test_skill_info_caches() -> void:
	var lib := SkillLibrary.new(cm)
	var a := lib.get_skill_info(10, 1)
	var b := lib.get_skill_info(10, 1)
	assert_same(a, b, "同 group+level 返回缓存 info")
	assert_true(lib.is_cached(10, 1))

# 批量验证：所有英雄的所有技能组都能加载 info（SkillGroup↔Skill 一致性）
func test_all_heroes_skills_load() -> void:
	var sgd := SkillGroupData.new(cm)
	var lib := SkillLibrary.new(cm)
	var raw: Dictionary = cm.get_raw_table(&"SkillGroup")
	var loaded: int = 0
	var missing: int = 0
	var bad_id: int = 0
	for caster_key in raw:
		var cid: int = int(caster_key)
		var groups: Dictionary = sgd.get_all_groups(cid)
		for slot_key in groups:
			var gid: int = int(groups[slot_key].get("Skill Group ID", 0))
			if gid <= 0:
				continue
			if not lib.has_skill(gid):
				missing += 1
				continue
			var info := lib.get_skill_info(gid, 1)
			if int(info.get("ID", 0)) <= 0:
				bad_id += 1
			loaded += 1
	assert_true(loaded >= 400, "加载 %d 个技能 info" % loaded)
	assert_eq(missing, 0, "SkillGroup 引用的技能组在 Skill 表全部存在（无悬空引用）")
	assert_eq(bad_id, 0, "无无效技能实例 ID")

# 星级重置 bug 回归：升星后技能等级保持（不重置）
func test_star_upgrade_keeps_skill_levels() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	hero.skill_levels = [2, 3, 1, 1]
	var original_levels := hero.skill_levels.duplicate()
	hero.stars = 2
	assert_eq(hero.skill_levels, original_levels, "升星不重置技能等级（治星级重置 bug）")

# Action(s) 字段（phase 时序数据源）：rebuild_phase_list 读 info["Action(s)"] 遍历动画名查 AnimAtkFrame。
# Skill 表 group -> level 0 内层 dict 含 Action(s)（{1:anim_name}），SkillLibrary 取 level 0 保留该字段。
func test_skill_info_has_actions() -> void:
	var lib := SkillLibrary.new(cm)
	var with_actions := 0
	var total := 0
	for gid_str in cm.get_raw_table(&"Skill").keys():
		var gid := int(gid_str)
		if not lib.has_skill(gid):
			continue
		total += 1
		if lib.get_skill_info(gid, 1).has("Action(s)"):
			with_actions += 1
	assert_eq(with_actions, total, "全部 skill info 含 Action(s)（phase 时序数据源）")

# 注：伤害数值/暴击公式在单位侧 take_damage（Phase 2.2续，源 unit.lua:1252），非 skill 数据层。
# 注：源 Luna/Axe 等 lua hook 在 Phase 2.7 heroes/*.lua 照源翻译（旧简化 HeroSkillOverrides 已退役）。
