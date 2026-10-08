extends GutTest
# BB 背击免疫 takeDamage hook 运行时错守卫（2026-10-08 用户实机报「卡死」附错误栈）。
# 根因：hero_bb.gd _take_damage 旧译 `source != null and source != ""`——source 是
# 伤害来源单位（Object），Object 与 String 比较在 GDScript 运行时爆 Invalid operands
# （源 BB.lua:54 直取 source.direction 无判空；本项目全部调用方 source 均传单位对象）。
# 触发链：DP 怨灵 buff 每 0.375s tick 伤害 → 受击 BB 大招期 ultBuff 置位 → 进背击
# 判定分支 → 爆错，免伤判定中断失效且每次受击刷一条 ERROR。auto 持久化让技能链更
# 活跃后首次踩中（此前 BB 大招难与「受怨灵伤害窗口」重叠）。
# 守卫：①带单位 source 的伤害走背击分支零错且 PIMU/MIMU 结算后还原（含源 quirk：
# MIMU 还原用 PIMU 原值 temp，源 BB.lua:61 原文如此，照译不动）；②异向非背击不进
# 分支（MIMU 保持原值）。不测 null source：引擎 take_damage :58 无条件取
# source.attribs（源同款不防御），null 在引擎层必爆，真实调用链不存在该形态。
# 注：BB 技能装配受槽 Unlock/rank 门槛（battle_unit_skill.gd:46），本守卫不依赖
# 技能在装——ultBuff 置位模拟大招期（_ult_create_buff 行为），只测 hook 判定路径。

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


func _make_hero(eng: BattleEngine, tid: int) -> BattleUnit:
	var hm := HeroManager.new(cm)
	var inst_id: int = hm.add_hero(tid)
	var hero: HeroInstance = hm.get_hero(inst_id)
	hero.level = 30
	hero.stars = 3
	return BattleUnit.new(hero.to_battle_proto(), BattleEngine.CAMP_ENEMY, {}, cm, eng, {}, lib)


func _prep_bb_target(bb: BattleUnit) -> void:
	bb.attribs["HP"] = 9999999.0
	bb.set_hp(9999999)
	bb.custom_data["ultBuff"] = 10.0   # 模拟 _ult_create_buff 置位（大招期背击免伤值）
	bb.attribs["PIMU"] = 20.0
	bb.attribs["MIMU"] = 30.0   # < IMMUNITY_FULL(100) 防触发全免 return 0


# 数据前提：BB（tid 49）takeDamage hook 注册（BattleHeroScripts.apply 链）。
func test_bb_takedamage_hook_registered() -> void:
	var eng := _make_engine()
	var bb := _make_hero(eng, 49)
	assert_true(bb.hero_hooks.has("takeDamage"), "BB takeDamage hook 已注册")


# 核心回归：大招期 BB 受带单位 source 的伤害——旧版此处爆 Invalid operands（GUT 计败），
# 修复后背击分支正常结算且 PIMU/MIMU 结算后还原。
func test_bb_ultbuff_damage_from_unit_source_no_error() -> void:
	var eng := _make_engine()
	var bb := _make_hero(eng, 49)
	var dp := _make_hero(eng, 40)
	eng.add_unit(bb)
	eng.add_unit(dp)
	_prep_bb_target(bb)
	bb.direction = 1
	dp.direction = 1   # 同向 = 背击（源 :55 direct == self.direction）
	var dmg: float = bb.take_damage({"amount": 1000.0, "damage_type": "AP", "field": "hp", "source": dp})
	assert_gt(dmg, 0.0, "背击路径伤害正常结算返回（旧版 Object!=String 爆错中断）")
	assert_almost_eq(float(bb.attribs.get("PIMU", 0.0)), 20.0, 0.01, "PIMU 结算后还原原值")
	assert_almost_eq(float(bb.attribs.get("MIMU", 0.0)), 20.0, 0.01, "MIMU 还原为 PIMU 原值（源 :61 quirk 照译，非 typo）")


# 异向（非背击）不进分支：MIMU 全程保持原值（未被背击分支的 PIMU 原值覆盖）。
func test_bb_ultbuff_frontal_damage_skips_backstab_branch() -> void:
	var eng := _make_engine()
	var bb := _make_hero(eng, 49)
	var dp := _make_hero(eng, 40)
	eng.add_unit(bb)
	eng.add_unit(dp)
	_prep_bb_target(bb)
	bb.direction = 1
	dp.direction = 0   # 异向 = 正面
	var dmg: float = bb.take_damage({"amount": 1000.0, "damage_type": "AP", "field": "hp", "source": dp})
	assert_gt(dmg, 0.0, "正面路径伤害正常结算")
	assert_almost_eq(float(bb.attribs.get("MIMU", 0.0)), 30.0, 0.01, "正面不走分支，MIMU 保持原值")
