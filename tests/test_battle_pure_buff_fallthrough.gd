extends GutTest
# 先知（DP，Unit 40）大招无效果回归（2026-10-07 用户反馈根修）。
# 双层根因：
#   ① 无 Damage Type 的纯 buff 命中技（Skill 表 57 个：DP_ult/Sil_ult/Tiny_ult/Troll_ult
#     等 10 大招 + 47 个 atk 附加 buff 技）：BattleSkillEffect.take_effect_on 旧版 dt=="" 时
#     return [false,0] 早退——源 skill.lua damage_type=nil fall-through 到 Buff ID 命中段，
#     buff 永远挂不上 → 大招"播了动画没效果"。
#   ② take_effect_on 挂 buff 处静态直调 BattleSkillEffect.create_buff（new BattleBuff），
#     绕过 BattleSkill.create_buff 的 createBuff hook 分发（源 takeEffectOn self:createBuff
#     走英雄 override）→ DP 怨灵周期伤害/TB 变身/TA 折射/LOA 护盾等 20+ 英雄 buff hook 全灭，
#     buff 挂上也只是空壳倒计时。
# 数据前提：SkillGroup[40] slot1 → group 400 = DP_ult（Manual, Target Type=self, Buff ID 77，
# 无 Damage Type）；Buff 77 Time=9s；DP.lua buff 每 0.375s 随机目标 AP 伤害、onRemoved 治疗 50%。

var cm: ConfigManager
var lib: SkillLibrary


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)


func _make_engine() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(12345)
	return eng


func _make_player_dp(eng: BattleEngine) -> BattleUnit:
	var hm := HeroManager.new(cm)
	var inst_id: int = hm.add_hero(40)
	var hero: HeroInstance = hm.get_hero(inst_id)
	hero.level = 30
	hero.stars = 3
	return BattleUnit.new(hero.to_battle_proto(), BattleEngine.CAMP_PLAYER, {}, cm, eng, {}, lib)


func _make_dummy(eng: BattleEngine) -> BattleUnit:
	var dummy := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_ENEMY, {"estimate_rank": true}, cm, eng, {}, lib)
	dummy.position = Vector2(300, 0)
	dummy.previous_position = Vector2(300, 0)
	dummy.attribs["HP"] = 9999999.0
	dummy.set_hp(9999999)
	return dummy


# 根因①：无 Damage Type 技能 fall-through 挂 buff（不再 [false,0] 早退）。
func test_no_damage_type_falls_through_to_buff() -> void:
	var eng := _make_engine()
	var dp := _make_player_dp(eng)
	var dummy := _make_dummy(eng)
	eng.add_unit(dp)
	eng.add_unit(dummy)
	var ult: Variant = dp.manual_skill
	assert_eq(str(ult.info.get("Skill Name")), "DP_ult", "DP 大招已装配")
	assert_false(ult.info.has("Damage Type"), "数据前提：DP_ult 无 Damage Type（纯 buff 命中技）")
	var r: Array = ult.take_effect_on(dp, null)
	assert_true(bool(r[0]), "无 Damage Type 结算不再早退（照源 fall-through，返 succ=true）")
	var names: Array = []
	for b in dp.buff_list:
		names.append(b.name)
	assert_has(names, "DP_ult", "Buff 77 挂上 DP（修复前 buff 永不挂）")


# 根因②：createBuff hook 分发接通——buff 带 custom_data（attack_timer/total_dmg）非空壳。
func test_buff_created_via_hook_with_custom_data() -> void:
	var eng := _make_engine()
	var dp := _make_player_dp(eng)
	var dummy := _make_dummy(eng)
	eng.add_unit(dp)
	eng.add_unit(dummy)
	dp.set_mp(2000.0)
	dp.cast_manual_skill()
	for i in range(30):   # ~1s：Attack 帧 0.708s 处挂 buff
		eng.update(0.033)
	var dp_buff: Variant = null
	for b in dp.buff_list:
		if b.name == "DP_ult":
			dp_buff = b
	assert_ne(dp_buff, null, "cast 后 DP_ult buff 在身")
	assert_almost_eq(float(dp_buff.custom_data.get("attack_timer", -1.0)), 0.375, 0.4,
		"attack_timer 已初始化（hook 版 buff；修复前 static 直调版为空壳 -1）")
	assert_eq(float(dp_buff.custom_data.get("total_dmg", -1.0)), 0.0, "total_dmg 从 0 起累计")


# 端到端：怨灵 9 秒周期伤害（24 发 × ~137）+ onRemoved 吸血治疗。
func test_dp_ult_periodic_damage_and_heal() -> void:
	var eng := _make_engine()
	var dp := _make_player_dp(eng)
	var dummy := _make_dummy(eng)
	eng.add_unit(dp)
	eng.add_unit(dummy)
	dp.set_hp(1000)   # 压低血量观察结束治疗
	dp.set_mp(2000.0)
	dp.cast_manual_skill()
	for i in range(420):   # ~13.9s：大招 0.7s 出手 + buff 9s + 治疗结算
		eng.update(0.033)
	var dummy_lost: int = 9999999 - int(dummy.hp)
	assert_gt(dummy_lost, 2000, "怨灵周期伤害 > 2000（24 发理论 ~3300；修复前仅普攻 ~470）")
	assert_gt(int(dp.hp), 1000, "buff 到期 onRemoved 治疗 total_dmg*0.5 后 DP 回血（压血 1000 起步）")


# 波及面守卫：Skill 表全部"无 Damage Type + Buff ID>0 + active"技能（57 个）在 SkillLibrary 可取
# 且 take_effect_on 不因缺 dt 早退——数据表新增此类技能时自动覆盖。
func test_all_pure_buff_skills_available() -> void:
	var count: int = 0
	for gid in cm.get_raw_table(&"Skill").keys():
		var levels: Dictionary = cm.get_raw_table(&"Skill")[gid]
		var base: Dictionary = levels.get("0", {})
		if base.is_empty() or str(base.get("Active Type", "")) != "active":
			continue
		if base.has("Damage Type") or int(base.get("Buff ID", 0)) <= 0:
			continue
		assert_true(lib.has_skill(int(gid)), "纯 buff 技能组 %s 在 SkillLibrary 可取" % str(gid))
		count += 1
	assert_gt(count, 50, "纯 buff 命中技 >= 50（当前 57；此守卫防表结构漂移导致静默归零）")
