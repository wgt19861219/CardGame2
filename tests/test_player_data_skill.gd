extends GutTest
# PlayerData 技能点 + VIP 上限 + 技能升级测试（照源 player.lua:704 Max Skill Points，Task #20）。
# 新增：技能点初始值5（A7）+ 按时间恢复（A7）+ 跨日重置（A7）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 local_server.lua:85 DEFAULT_DATA.skill.chance=5（新玩家初始技能点）
func test_skill_points_default_value() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(pd.skill_points, PlayerData.SKILL_DEFAULT_POINTS, "新玩家初始技能点 = 5（源 DEFAULT_DATA.skill.chance）")
	assert_eq(PlayerData.SKILL_DEFAULT_POINTS, 5, "常量值锁定源 local_server:85")


func test_add_skill_point() -> void:
	var pd := PlayerData.new(cm)
	pd.skill_points = 0  # 重置初始值以独立验证 add 语义
	SkillPointManager.add(pd, 3)
	assert_eq(pd.skill_points, 3, "技能点 +3")


func test_add_skill_point_vip_limit() -> void:
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	pd.vip_level = 0
	var limit: int = int(VipData.get_vip_field(0, "Max Skill Points", cm))
	SkillPointManager.add(pd, 1000)
	if limit > 0:
		assert_eq(pd.skill_points, limit, "受 VIP Max Skill Points 上限")
	else:
		assert_eq(pd.skill_points, 1000, "无上限（VIP 表缺字段）")


func test_upgrade_hero_skill() -> void:
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	SkillPointManager.add(pd, 5)
	pd.hero_manager.gold = 10000   # SkillLevels[1].Price=100
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 5   # 源 :155 技能等级不可超英雄等级（默认 level=1 会挡）
	var old_lvl: int = hero.skill_levels[0]
	assert_true(SkillPointManager.upgrade_hero_skill(pd, inst_id, 0), "升级技能")
	assert_eq(hero.skill_levels[0], old_lvl + 1, "skill_levels+1")
	assert_eq(pd.skill_points, 4, "消耗 1 技能点")


func test_upgrade_hero_skill_gold_cost() -> void:
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	SkillPointManager.add(pd, 5)
	pd.hero_manager.gold = 10000
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 5
	assert_true(SkillPointManager.upgrade_hero_skill(pd, inst_id, 0), "升级成功")
	assert_eq(pd.hero_manager.gold, 9900, "扣金币 SkillLevels[1].Price=100（源 :167）")


func test_upgrade_hero_skill_level_cap() -> void:
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	SkillPointManager.add(pd, 5)
	pd.hero_manager.gold = 10000
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	# hero.level=1, skill_levels[0]=1 → 1>=1 等级上限拒绝（源 :155 skl>=hlv）
	assert_false(SkillPointManager.upgrade_hero_skill(pd, inst_id, 0), "技能等级>=英雄等级 → 拒绝")
	assert_eq(hero.skill_levels[0], 1, "等级不变")
	assert_eq(pd.skill_points, 5, "技能点不扣（原子性）")


func test_upgrade_hero_skill_no_gold() -> void:
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	SkillPointManager.add(pd, 5)
	pd.hero_manager.gold = 50   # < SkillLevels[1].Price=100
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 5
	assert_false(SkillPointManager.upgrade_hero_skill(pd, inst_id, 0), "金币不足 → 拒绝（源 :157）")
	assert_eq(hero.skill_levels[0], 1, "等级不变")
	assert_eq(pd.skill_points, 5, "技能点不扣（原子性）")


func test_upgrade_hero_skill_insufficient() -> void:
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	var inst_id: int = pd.hero_manager.add_hero(1)
	assert_false(SkillPointManager.upgrade_hero_skill(pd, inst_id, 0), "技能点不足 → 失败")


func test_upgrade_hero_skill_gs_increment() -> void:
	# 源 local_server.lua:1343 hero._gs += totalUpgrades*10（每升 1 级技能 +10 战力）
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	SkillPointManager.add(pd, 5)
	pd.hero_manager.gold = 10000
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.level = 5
	var old_gs: int = hero.gs
	assert_true(SkillPointManager.upgrade_hero_skill(pd, inst_id, 0), "升级技能")
	assert_eq(hero.gs, old_gs + 10, "技能升级 +10 战力（源 :1343 totalUpgrades*10）")


# ── buy_skill_stren_point（源 local_server:2184-2193 + skillstren.lua:463-468）──

func test_buy_skill_stren_point() -> void:
	# 源 :2185 chance+=10 + reset_times++，扣钻 GradientPrice[1]["Skill Upgrade Reset"]=10
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	pd.diamond = 1000
	var old_diamond: int = pd.diamond
	assert_true(SkillPointManager.buy_stren_point(pd), "购买成功")
	assert_eq(pd.skill_points, 10, "chance+=10（源 :2185）")
	assert_eq(pd.skill_reset_times, 1, "reset_times++（源 :2186）")
	var idx: int = min(pd.skill_reset_times + 1, SkillPointManager.BUY_MAX_TIMES)  # 下一笔价（原 _get_skill_buy_cost 逻辑，T3 迁 SkillPointManager）
	var cost: int = int(cm.get_raw_table(&"GradientPrice").get(str(idx), {}).get(&"Skill Upgrade Reset", 0))
	# 第一笔价 = GradientPrice[1]["Skill Upgrade Reset"]
	var first_cost: int = int(cm.get_raw_table(&"GradientPrice").get("1", {}).get(&"Skill Upgrade Reset", 0))
	assert_eq(pd.diamond, old_diamond - first_cost, "扣 GradientPrice[1] 钻石")


func test_buy_skill_stren_point_gradient() -> void:
	# 源 skillstren.lua:467 梯度计费 min(reset_times+1, 30)
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	pd.diamond = 100000
	pd.vip_level = 15  # 高 VIP 提高上限，避 Max Skill Points 封顶干扰梯度测试
	# 连续买 3 次，确认每次扣费递增
	var costs: Array[int] = []
	for i in 3:
		var before: int = pd.diamond
		assert_true(SkillPointManager.buy_stren_point(pd), "第 %d 次购买" % (i + 1))
		costs.append(before - pd.diamond)
	assert_eq(pd.skill_reset_times, 3, "3 次 reset_times")
	# 梯度：GradientPrice[1] <= [2] <= [3]
	if costs[0] > 0 and costs[1] > 0:
		assert_true(costs[1] >= costs[0], "第2笔>=第1笔（梯度递增）")


func test_buy_skill_stren_point_no_diamond() -> void:
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	pd.diamond = 0
	assert_false(SkillPointManager.buy_stren_point(pd), "钻石不足 → 失败")
	assert_eq(pd.skill_points, 0, "技能点不变")
	assert_eq(pd.skill_reset_times, 0, "reset_times 不变")


# ── A7: 按时间自动恢复技能点（源 player.lua:658-686 getSkillLvupChance）──
# CD 间隔 300s（源 parameter.skill_level_up_chance_cd），上限 VIP["Max Skill Points"]（VIP0 = 10）

func test_recover_skill_point_by_time() -> void:
	# 源 :668-674 addChance = dt/cd，dt = now - cd_time
	var pd := PlayerData.new(cm)
	pd.vip_level = 0  # VIP0 Max Skill Points = 10
	pd.skill_points = 0
	pd.skill_cd_time = 1000   # 起点时间戳
	# 经过 650s（>2 倍 CD 600s，<3 倍 CD 900s）→ addChance = 2
	var recovered: int = SkillPointManager.recover(pd, 1000 + 650)
	assert_eq(pd.skill_points, 2, "650s/300s=2 次恢复，+2 技能点")
	assert_eq(recovered, 2, "返回值 = 恢复量")
	# cd_time 更新为 now - dt%cd = 1650 - 50 = 1600（保留 50s 零头）
	assert_eq(pd.skill_cd_time, 1600, "cd_time = now - dt%cd（源 :682 保留零头）")


func test_recover_skill_point_clamped_by_max() -> void:
	# 源 :672 chance = min(chance + addChance, max)，恢复受 VIP 上限钳制
	var pd := PlayerData.new(cm)
	pd.vip_level = 0  # VIP0 max=10
	pd.skill_points = 9   # 差 1 点满
	pd.skill_cd_time = 1000
	# 经过 900s → addChance = 3，但 9+3=12 被 max=10 钳到 10
	SkillPointManager.recover(pd, 1000 + 900)
	assert_eq(pd.skill_points, 10, "受 VIP0 上限 10 钳制")
	# 源 :676-678 满后 cd_time = now（停止累积）
	assert_eq(pd.skill_cd_time, 1900, "满后 cd_time = now（源 :676）")


func test_recover_skill_point_at_max_no_accumulate() -> void:
	# 源 :661-664 chance >= max → isOverfull=true，cd_time = now（满时不计恢复）
	var pd := PlayerData.new(cm)
	pd.vip_level = 0
	pd.skill_points = 10   # 已满 VIP0 上限
	pd.skill_cd_time = 1000
	var recovered: int = SkillPointManager.recover(pd, 1000 + 99999)
	assert_eq(recovered, 0, "满后不恢复")
	assert_eq(pd.skill_points, 10, "维持上限")
	assert_eq(pd.skill_cd_time, 100999, "cd_time 刷新为 now")


func test_recover_skill_point_cd_time_zero_fallback_now() -> void:
	# 源 buildSkillLevelUp:185 cd_time=0 fallback os.time()（旧档/新档 cd_time=0）
	var pd := PlayerData.new(cm)
	pd.vip_level = 0
	pd.skill_points = 0
	pd.skill_cd_time = 0   # 新档默认
	var recovered: int = SkillPointManager.recover(pd, 5000)
	assert_eq(recovered, 0, "cd_time=0 时 fallback now=5000，dt=0 不恢复")
	assert_eq(pd.skill_cd_time, 5000, "cd_time 被初始化为 now")


func test_recover_skill_point_below_cd_no_recover() -> void:
	# dt < cd 时 addChance=0 不恢复
	var pd := PlayerData.new(cm)
	pd.vip_level = 0
	pd.skill_points = 0
	pd.skill_cd_time = 1000
	var recovered: int = SkillPointManager.recover(pd, 1000 + 299)   # < CD 300
	assert_eq(recovered, 0, "不足 1 个 CD 不恢复")
	assert_eq(pd.skill_points, 0, "技能点不变")


# ── A7: 跨日重置 skill_reset_times（源 player.lua:718-731 resetSkillData）──
# 机制：checkTwoDateod(last_reset_date, now) → reset_times = 0（梯度计费回退第 1 档）

func test_buy_skill_stren_point_cross_day_resets_reset_times() -> void:
	# 源 player.lua:727 getSkillResetTimes 内部调 resetSkillData→:718-731
	# 场景：昨天买了 3 次（reset_times=3，第 4 次价），今天跨日买应回退第 1 档价
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	pd.vip_level = 15  # 高 VIP 避 Max Skill Points 上限干扰
	pd.diamond = 100000
	pd.skill_reset_times = 3   # 昨天已买 3 次
	# 模拟昨天（构造 last_reset_date 为 2 天前的 00:00 UTC，确保跨日）
	var now: int = int(Time.get_unix_time_from_system())
	pd.skill_last_reset_date = now - 2 * 86400   # 2 天前
	# 第一笔价 = GradientPrice[1]（reset_times 跨日归 0 后 +1 = 1）
	var first_cost: int = int(cm.get_raw_table(&"GradientPrice").get("1", {}).get(&"Skill Upgrade Reset", 0))
	var before: int = pd.diamond
	assert_true(SkillPointManager.buy_stren_point(pd), "跨日首次购买成功")
	# 源 :719-720 跨日 reset_times=0，购买后 +1 = 1
	assert_eq(pd.skill_reset_times, 1, "跨日重置后 reset_times 从 1 计起（源 :720）")
	assert_eq(pd.diamond, before - first_cost, "跨日后按 GradientPrice[1] 第 1 档价扣钻（梯度回退）")


func test_buy_skill_stren_point_same_day_no_reset() -> void:
	# 同日购买不重置，reset_times 继续累加
	var pd := PlayerData.new(cm)
	pd.skill_points = 0
	pd.vip_level = 15
	pd.diamond = 100000
	pd.skill_reset_times = 3
	var now: int = int(Time.get_unix_time_from_system())
	pd.skill_last_reset_date = now   # 同日（刚设）
	var before: int = pd.diamond
	# 第 4 笔价 = GradientPrice[4]（reset_times=3+1=4）
	var fourth_cost: int = int(cm.get_raw_table(&"GradientPrice").get("4", {}).get(&"Skill Upgrade Reset", 0))
	assert_true(SkillPointManager.buy_stren_point(pd), "同日购买成功")
	assert_eq(pd.skill_reset_times, 4, "同日不重置，reset_times 继续累加")
	assert_eq(pd.diamond, before - fourth_cost, "同日按 GradientPrice[4] 第 4 档价扣钻")
