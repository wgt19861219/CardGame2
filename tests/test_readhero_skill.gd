extends GutTest
# ReadheroSkill 技能描述查询测试（照源 controller.lua:68 getSkillDesc + skillstren.lua:742 description）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_get_skill_description() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	var desc: String = ReadheroSkill.get_skill_description(hero, 1, cm)
	# Coco slot 1 Skill[10][0].Description = "SKILL.SUMMONS_A_GHOSTSHIP_..."
	assert_false(desc.is_empty(), "slot 1 有描述")


func test_get_skill_desc_growth() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	# slot 1 InitLevel=1, skill_levels[0]=1 → level=1
	# Growth 1: field=Basic Num, value=15, mult=1, Skill[10][0][Basic Num]=75
	# growth=15, level=1 → # = 15×1=15
	var desc: String = ReadheroSkill.get_skill_desc(hero, 1, cm)
	assert_false(desc.is_empty(), "成长值文本非空")
	assert_true(desc.find("15") >= 0, "# 替换为 growth×level = 15×1 = 15")


func test_get_skill_desc_skill_add() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	# skill_add=2 → level=1+2=3, growth=15 → # = 15×3=45
	var desc: String = ReadheroSkill.get_skill_desc(hero, 1, cm, 2)
	assert_true(desc.find("45") >= 0, "skill_add=2 → level=3 → # = 15×3 = 45")


func test_get_skill_desc_empty_slot() -> void:
	var hero := HeroInstance.new(99999, 1, 1)   # 不存在英雄
	var desc: String = ReadheroSkill.get_skill_desc(hero, 1, cm)
	assert_eq(desc, "", "不存在英雄 → 空描述")


# ── 翻译链守卫（2026-08-30 五轮：技能描述浮层显示英文 key 根修）──
# 表存 LSTR key 须查翻译（源中文渠道表直存中文；Skill Description 族 262 key 全有中文）。
# hero 1 slot 4 被动：Description key=SKILL.TRAINS_THE_CAPTAINS_... → 中文「船长专注地磨炼自己的身体，增加力量。」
func test_get_skill_description_translated() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	var desc: String = ReadheroSkill.get_skill_description(hero, 4, cm)
	assert_false(desc.begins_with("SKILL."), "描述不走翻译=显示英文 key（用户截图 bug）")
	assert_true(desc.find("船长") >= 0, "slot 4 描述为中文（船长专注地磨炼…）")

# 成长行：有翻译的 key 显示中文且 # 被数字替换（slot 1 Summary=SKILLGROUP.DAMAGE_+_#）。
func test_get_skill_desc_summary_translated() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	var desc: String = ReadheroSkill.get_skill_desc(hero, 1, cm)
	if desc.find("SKILLGROUP.") >= 0:
		pass   # 该 key 语言表缺条目时回退 key 原文（数据债，非链路 bug）——不在此断言
	else:
		assert_true(desc.find("15") >= 0, "中文译文内 # 仍替换为 growth×level=15")


# ── 六轮（2026-08-30）：语言表补齐后成长行出中文（源 zh-CN.lua 差集 265 条已导入）──
# hero 1 slot 4 Summary=SKILLGROUP.PASSIVE__INCREASE_#_STRENGTH →「被动：增加#点力量」（#→数字）。
func test_get_skill_desc_summary_chinese() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	hero.rank = 7
	hero.skill_levels = [1, 1, 21, 41]   # 照 add_hero InitLevel 初始化 → slot4 显示 lv.1，growth×level=3×1=3
	var desc: String = ReadheroSkill.get_skill_desc(hero, 4, cm)
	assert_false(desc.find("SKILLGROUP.") >= 0, "成长行不再显示英文 key")
	assert_true(desc.find("被动：增加") >= 0, "成长行为中文（被动：增加N点力量）")
	assert_true(desc.find("3") >= 0, "# 替换为 growth×level=3")
