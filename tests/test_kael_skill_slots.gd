extends GutTest
# 召唤师（Kael）0 伤害回归（2026-10-07 玩家反馈根修）。
# 根因：源单机化 addHero 只填 _skill_levels 前 4 槽（原版网游服务器下发全槽），
# Kael/TitanHead/SilverDragon 等多槽英雄 slot 5+ 技能拿不到等级不装配——
# 玩家 Kael 只剩冰墙(P3)/冰冻(P2)两无伤控制技（CD=0 CostMP=0）被 AI 按优先级
# 无限循环施放，冲击波/普攻永远轮不到 → 战斗总伤害 0。
# 修法：HeroManager._init_skill_levels 按 SkillGroup 全槽初始化 + from_dict 旧档补齐。

var cm: ConfigManager
var lib: SkillLibrary


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)


# 新获得 Kael：skill_levels 按 SkillGroup 全槽初始化（13 元素），不再是 4 元素截断。
func test_add_hero_kael_full_slots() -> void:
	var hm := HeroManager.new(cm)
	var inst_id: int = hm.add_hero(53)
	var hero: HeroInstance = hm.get_hero(inst_id)
	assert_eq(hero.skill_levels.size(), 13, "Kael skill_levels 按全槽初始化（13 槽）")
	for i in hero.skill_levels.size():
		assert_eq(hero.skill_levels[i], 1, "Kael slot %d Init Level = 1" % (i + 1))


# 旧档兼容：4 元素 skill_levels 读档补齐到全槽，已有槽位值（含玩家升级）不动。
func test_from_dict_legacy_4slots_backfill() -> void:
	var legacy := {
		"gold": 0, "next_id": 2,
		"heroes": [{
			"inst_id": 1, "tid": 53, "rank": 1, "level": 30, "stars": 3, "exp": 0,
			"skill_levels": [5, 1, 1, 1],   # 玩家已把 slot1 升到 5
			"equip_slots": [0, 0, 0, 0, 0, 0], "equip_exp": [], "gs": 0, "awake": false,
		}],
	}
	var hm := HeroManager.from_dict(legacy, cm)
	var hero: HeroInstance = hm.get_hero(1)
	assert_eq(hero.skill_levels.size(), 13, "旧档补齐到 13 槽")
	assert_eq(hero.skill_levels[0], 5, "已有槽位等级保留（玩家升级不丢）")
	for i in range(4, hero.skill_levels.size()):
		assert_eq(hero.skill_levels[i], 1, "补齐槽位取 Init Level")


# 端到端：真实玩家条件的 Kael（HeroManager 组 proto，4+ 槽全装配）战斗伤害 > 0。
func test_kael_player_proto_deals_damage() -> void:
	var eng := _make_engine()
	var kael := _make_player_kael(eng)
	var dummy := _make_dummy(eng)
	eng.add_unit(kael)
	eng.add_unit(dummy)
	var assembled: Array = kael.skills.keys()
	assert_true(assembled.has(530) and assembled.has(537) and assembled.has(5301),
		"Kael 装配冲击波(530)/磁暴(537)/普攻(5301)——多槽球技能不再缺失")
	kael.auto_combat = true
	kael.ai_mode = true
	for i in range(6000):
		eng.update(0.033)
	assert_gt(kael.dmg_statistics, 0.0, "Kael 战斗总伤害 > 0（修复前 4 槽条件下实测为 0）")


func _make_engine() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(12345)
	return eng


func _make_player_kael(eng: BattleEngine) -> BattleUnit:
	var hm := HeroManager.new(cm)
	var inst_id: int = hm.add_hero(53)
	var hero: HeroInstance = hm.get_hero(inst_id)
	hero.level = 30
	hero.stars = 3
	return BattleUnit.new(hero.to_battle_proto(), BattleEngine.CAMP_PLAYER, {}, cm, eng, {}, lib)


func _make_dummy(eng: BattleEngine) -> BattleUnit:
	var dummy := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_ENEMY, {"estimate_rank": true}, cm, eng, {}, lib)
	dummy.position = Vector2(300, 0)
	dummy.previous_position = Vector2(300, 0)
	return dummy


# 球组合校验（2026-10-07"只会吹风"根修）：球不匹配时旋风 can_cast 被拒（AI 落到普攻），
# 凑齐组合放行——源 canCastSkill 死代码接回 canCastWithTarget hook。
func test_ballskill_can_cast_requires_ball_combo() -> void:
	var eng := _make_engine()
	var kael := _make_player_kael(eng)
	var dummy := _make_dummy(eng)
	eng.add_unit(kael)
	eng.add_unit(dummy)
	var tornado: Variant = kael.skills.get(539)   # 旋风 P10 最高球技能，组合 [1,0,2]=冰1火0雷2
	assert_not_null(tornado, "旋风 539 已装配")
	assert_false(bool(kael.ai_mode), "玩家侧卡尔 ai_mode=false")
	# 球空：组合不匹配 → 拒绝
	var r_empty: Dictionary = tornado.can_cast_with_target(dummy)
	assert_false(bool(r_empty.get("ok", true)), "空球时旋风被球组合校验拒绝（reason=%s）" % str(r_empty.get("reason", "")))
	# 塞齐冰1雷2 → 放行（球状态需 AVAILABLE，先过 BORN）
	kael.energy_ball_manager.add_energy_ball("ice", 1)
	kael.energy_ball_manager.add_energy_ball("lightning", 2)
	kael.energy_ball_manager.add_energy_ball("lightning", 3)
	kael.energy_ball_manager.update(1.0)   # BORN → AVAILABLE（BALL_CD=0 即刻成熟）
	var r_match: Dictionary = tornado.can_cast_with_target(dummy)
	assert_true(bool(r_match.get("ok", false)), "凑齐 冰1雷2 组合后旋风放行")


# 技能轮换分布：球组合校验接通后 AI 不再被单一高优先级球技能独占——普攻有出手
# （投球来源）、球技能有出手（组合技命中），且旋风不垄断球技能施放。
func test_kael_skill_rotation_not_tornado_monopoly() -> void:
	var eng := _make_engine()
	var kael := _make_player_kael(eng)
	var dummy := _make_dummy(eng)
	# 高血木桩：默认 611 血在大招+普攻下 ~200 帧即被秒，球还没攒齐战斗就结束测不出轮换
	dummy.attribs["HP"] = 9999999.0
	dummy.set_hp(9999999)
	eng.add_unit(kael)
	eng.add_unit(dummy)
	assert_true(bool(kael.auto_combat), "玩家侧卡尔自动拾球兜底生效（球条 UI 未实装期）")
	for i in range(6000):
		eng.update(0.033)
	var basic: Variant = kael.skills.get(5301)
	assert_gt(int(basic.attack_counter), 0, "普攻有出手（球不匹配时 AI fall through 到普攻投球）")
	var ball_casts: int = 0
	var tornado_casts: int = 0
	for sid in [530, 531, 532, 533, 534, 535, 536, 537, 538, 539]:
		var s: Variant = kael.skills.get(sid)
		if s != null and int(s.attack_counter) > 0:
			ball_casts += int(s.attack_counter)
			if sid == 539:
				tornado_casts = int(s.attack_counter)
	assert_gt(ball_casts, 0, "球技能有出手（组合命中释放）")
	assert_lt(tornado_casts, ball_casts, "旋风不再垄断球技能施放（修复前 P10+CD0 无限独占）")
	assert_gt(kael.dmg_statistics, 0.0, "总伤害 > 0")
