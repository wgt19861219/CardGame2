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
