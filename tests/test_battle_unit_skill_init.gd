extends GutTest
# 回归守卫（2026-09-05 投射物落点根修）：init_skill 必须照源 unit.lua:390-391 把 active
# 技能写入 u.skills 双键（Skill Group ID / Skill Name）。曾漏译致 skills 恒空 →
# hero.skills.get 恒 null → 全部英雄 hook 静默失效；DR（小黑）大招走默认投射物
# （恒速 Tile XY Speed=300 + 抛物线 ~1s 落地，只飞 ~300 逻辑像素），后排到目标 300+，
# 箭半路落地——用户观察"大招投射物明显没有落在目标头上"。
# 用真实 ConfigManager/SkillLibrary 构建单位（mock 测试测不出本根因，hook 测试曾全绿）。

var cm: ConfigManager
var lib: SkillLibrary


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)


func _make_eng() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(777)
	return eng


func _make_dr(eng: BattleEngine) -> BattleUnit:
	# tid=2=DR（小黑）；槽 1（DR_ult）技能等级 1；estimate_rank 按等级估 rank（大招 Unlock=1）
	return BattleUnit.new(
		{"_tid": 2, "_level": 1, "_stars": 1, "_skill_levels": {"1": 1}},
		BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, lib
	)


# Sniper（tid=10）普攻射程 440：放 420 处在射程内站桩不动（近战敌人会迎面走，
# 箭为预判弹道会落空——那是源机制，本测试锚定落点需要静止目标）。
func _make_stationary_enemy(eng: BattleEngine, pos: Vector2) -> BattleUnit:
	var u := BattleUnit.new(
		{"_tid": 10, "_level": 1, "_stars": 1},
		BattleEngine.CAMP_ENEMY, {"estimate_rank": true}, cm, eng, {}, lib
	)
	u.position = pos
	u.previous_position = pos
	return u


# 源 unit.lua:390-391：active 技能同时写 skills[Skill Group ID] 与 skills[Skill Name]
func test_init_skill_fills_skills_dict_dual_keys() -> void:
	var eng := _make_eng()
	var dr := _make_dr(eng)
	assert_true(dr.skills.has(20), "skills 按 Skill Group ID 填充（20=DR_ult）")
	assert_true(dr.skills.has("DR_ult"), "skills 按 Skill Name 填充（DR_ult）")
	assert_true(dr.skills.has(21), "普攻 group 也填充（21=DR_atk，reset_skill_list 波次切换依赖 int 键）")
	assert_same(dr.skills.get("DR_ult"), dr.skills.get(20), "双键指向同一 skill 实例")


# 英雄 hook 挂载依赖 skills 字典：hero_dr.apply 读 hero.skills.get("DR_ult")
func test_hero_hook_attached_via_skills_dict() -> void:
	var eng := _make_eng()
	var dr := _make_dr(eng)
	var sk: Variant = dr.skills.get("DR_ult")
	assert_not_null(sk, "DR_ult 技能经 skills 字典可取")
	if sk == null:
		return
	assert_true(sk.hero_hooks.has("createProjectile"), "DR createProjectile hook 已注册")
	assert_true(sk.hero_hooks.get("createProjectile", Callable()).is_valid(), "hook Callable 有效")


# 端到端：DR 大招箭（hook 版 velocity=位移/落地时间）必须落到 420px 外的目标头上。
# 目标用 Sniper（tid=10，普攻射程 440≥420 → 站桩不动），箭 t 秒后 x≈发射时目标 x（±半径+tick 量化）。
# 修复前走默认投射物（恒速 300），~1s 落地只飞 ~300px，落点差 100+。
func test_dr_ult_arrow_reaches_distant_target() -> void:
	var eng := _make_eng()
	var dr := _make_dr(eng)
	dr.position = Vector2(0, 0)
	dr.previous_position = dr.position
	var enemy := _make_stationary_enemy(eng, Vector2(420, 0))
	eng.add_unit(dr)
	eng.add_unit(enemy)
	var sk: Variant = dr.skills.get("DR_ult")
	if sk == null:
		fail_test("DR_ult 不在 skills 字典（根因未修）")
		return
	sk.target = enemy
	sk._on_attack_frame_default()  # 出手帧：Target Type=random 会重选目标（敌方唯一必中 enemy）
	var arrow: Variant = null
	for p in eng.projectile_list:
		if not bool(p.terminated):
			arrow = p  # 本测试唯一手动触发的投射物（AI 普攻尚未起手）
			break
	assert_not_null(arrow, "大招投射物已发射")
	if arrow == null:
		return
	for i in range(150):  # hook 版 t≈0.9s（h0=6.75 抛物线），4.95s 预算足够
		if bool(arrow.terminated):
			break
		eng.update(0.033)
	assert_true(bool(arrow.terminated), "箭已落地/命中终止")
	assert_almost_eq(float(arrow.position.x), 420.0, 20.0,
		"箭落在目标头上（落点 x=%.1f，目标 420±20；修复前 ~300 处提前落地）" % float(arrow.position.x))
