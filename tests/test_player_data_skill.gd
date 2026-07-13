extends GutTest
# PlayerData 技能点 + VIP 上限 + 技能升级测试（照源 player.lua:704 Max Skill Points，Task #20）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_add_skill_point() -> void:
	var pd := PlayerData.new(cm)
	pd.add_skill_point(3)
	assert_eq(pd.skill_points, 3, "技能点 +3")


func test_add_skill_point_vip_limit() -> void:
	var pd := PlayerData.new(cm)
	pd.vip_level = 0
	var limit: int = int(VipData.get_vip_field(0, "Max Skill Points", cm))
	pd.add_skill_point(1000)
	if limit > 0:
		assert_eq(pd.skill_points, limit, "受 VIP Max Skill Points 上限")
	else:
		assert_eq(pd.skill_points, 1000, "无上限（VIP 表缺字段）")


func test_upgrade_hero_skill() -> void:
	var pd := PlayerData.new(cm)
	pd.add_skill_point(5)
	pd.hero_manager.gold = 10000   # SkillLevels[1].Price=100
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 5   # 源 :155 技能等级不可超英雄等级（默认 level=1 会挡）
	var old_lvl: int = hero.skill_levels[0]
	assert_true(pd.upgrade_hero_skill(inst_id, 0), "升级技能")
	assert_eq(hero.skill_levels[0], old_lvl + 1, "skill_levels+1")
	assert_eq(pd.skill_points, 4, "消耗 1 技能点")


func test_upgrade_hero_skill_gold_cost() -> void:
	var pd := PlayerData.new(cm)
	pd.add_skill_point(5)
	pd.hero_manager.gold = 10000
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 5
	assert_true(pd.upgrade_hero_skill(inst_id, 0), "升级成功")
	assert_eq(pd.hero_manager.gold, 9900, "扣金币 SkillLevels[1].Price=100（源 :167）")


func test_upgrade_hero_skill_level_cap() -> void:
	var pd := PlayerData.new(cm)
	pd.add_skill_point(5)
	pd.hero_manager.gold = 10000
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	# hero.level=1, skill_levels[0]=1 → 1>=1 等级上限拒绝（源 :155 skl>=hlv）
	assert_false(pd.upgrade_hero_skill(inst_id, 0), "技能等级>=英雄等级 → 拒绝")
	assert_eq(hero.skill_levels[0], 1, "等级不变")
	assert_eq(pd.skill_points, 5, "技能点不扣（原子性）")


func test_upgrade_hero_skill_no_gold() -> void:
	var pd := PlayerData.new(cm)
	pd.add_skill_point(5)
	pd.hero_manager.gold = 50   # < SkillLevels[1].Price=100
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 5
	assert_false(pd.upgrade_hero_skill(inst_id, 0), "金币不足 → 拒绝（源 :157）")
	assert_eq(hero.skill_levels[0], 1, "等级不变")
	assert_eq(pd.skill_points, 5, "技能点不扣（原子性）")


func test_upgrade_hero_skill_insufficient() -> void:
	var pd := PlayerData.new(cm)
	var inst_id: int = pd.hero_manager.add_hero(1)
	assert_false(pd.upgrade_hero_skill(inst_id, 0), "技能点不足 → 失败")


func test_upgrade_hero_skill_gs_increment() -> void:
	# 源 local_server.lua:1343 hero._gs += totalUpgrades*10（每升 1 级技能 +10 战力）
	var pd := PlayerData.new(cm)
	pd.add_skill_point(5)
	pd.hero_manager.gold = 10000
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 5
	var old_gs: int = hero.gs
	assert_true(pd.upgrade_hero_skill(inst_id, 0), "升级技能")
	assert_eq(hero.gs, old_gs + 10, "技能升级 +10 战力（源 :1343 totalUpgrades*10）")


# ── buy_skill_stren_point（源 local_server:2184-2193 + skillstren.lua:463-468）──

func test_buy_skill_stren_point() -> void:
	# 源 :2185 chance+=10 + reset_times++，扣钻 GradientPrice[1]["Skill Upgrade Reset"]=10
	var pd := PlayerData.new(cm)
	pd.diamond = 1000
	var old_diamond: int = pd.diamond
	assert_true(pd.buy_skill_stren_point(), "购买成功")
	assert_eq(pd.skill_points, 10, "chance+=10（源 :2185）")
	assert_eq(pd.skill_reset_times, 1, "reset_times++（源 :2186）")
	var cost: int = pd._get_skill_buy_cost()  # 注意：reset_times 已+1，下一笔价
	# 第一笔价 = GradientPrice[1]["Skill Upgrade Reset"]
	var first_cost: int = int(cm.get_raw_table(&"GradientPrice").get("1", {}).get(&"Skill Upgrade Reset", 0))
	assert_eq(pd.diamond, old_diamond - first_cost, "扣 GradientPrice[1] 钻石")


func test_buy_skill_stren_point_gradient() -> void:
	# 源 skillstren.lua:467 梯度计费 min(reset_times+1, 30)
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	pd.vip_level = 15  # 高 VIP 提高上限，避 Max Skill Points 封顶干扰梯度测试
	# 连续买 3 次，确认每次扣费递增
	var costs: Array[int] = []
	for i in 3:
		var before: int = pd.diamond
		assert_true(pd.buy_skill_stren_point(), "第 %d 次购买" % (i + 1))
		costs.append(before - pd.diamond)
	assert_eq(pd.skill_reset_times, 3, "3 次 reset_times")
	# 梯度：GradientPrice[1] <= [2] <= [3]
	if costs[0] > 0 and costs[1] > 0:
		assert_true(costs[1] >= costs[0], "第2笔>=第1笔（梯度递增）")


func test_buy_skill_stren_point_no_diamond() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 0
	assert_false(pd.buy_skill_stren_point(), "钻石不足 → 失败")
	assert_eq(pd.skill_points, 0, "技能点不变")
	assert_eq(pd.skill_reset_times, 0, "reset_times 不变")
