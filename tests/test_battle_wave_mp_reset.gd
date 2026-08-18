extends GutTest
# 切波能量保留守卫（2026-08-18 用户实跑"切波能量条清零"根因修复）：
# 源 unit.lua:54-57 initHpMpInfo 的 hpmpInited 守卫漏译——reset_unit_list 切波
# reset 把玩家 mp 重置初始值。守卫补回后：同对象 reset 不清 hp/mp；新 unit 首次 init 正常。


func test_wave_reset_preserves_player_mp() -> void:
	var cm := ConfigManager.new()
	cm.load_all()
	var mgr := StageManager.new(cm)
	mgr.skill_lib = GameData.skills   # 注入（战斗缠绕同款教训：裸建 mgr 无 lib 单位无技能）
	var r: Dictionary = mgr.assemble_stage_battle(1, GameData.player, [1, 2, 3, 4, 5], BattleRng.new(7))
	if not bool(r.get("ok", false)):
		fail_test("stage1 装配失败: %s" % str(r.get("error", "")))
		return
	var eng: BattleEngine = r["engine"]
	var hero: Variant = null
	for u in eng.foreach_alive_unit(BattleEngine.CAMP_PLAYER):
		hero = u
		break
	if hero == null:
		fail_test("无玩家单位")
		return
	var mp_max: int = int(hero.attribs.get("MP", 1))
	hero.set_mp(int(mp_max * 0.6))
	var before: int = int(hero.mp)
	var hp_before: int = int(hero.hp)
	# 模拟 View 切波链的 Logic 侧（battle_wave_advancer.advance_wave → next_battle）
	BattleEngineWaves.next_battle(eng, cm)
	assert_eq(int(hero.mp), before, "切波后玩家 mp 保留（源 hpmpInited 守卫语义）")
	assert_eq(int(hero.hp), hp_before, "切波后玩家 hp 同样保留")


func test_new_unit_first_init_still_runs() -> void:
	# 新 unit（跨关新战斗/每波新怪）首次 init 不受守卫拦截
	var cm := ConfigManager.new()
	cm.load_all()
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(1)
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	assert_true(u.hpmp_inited, "首次 init 后守卫置位")
	assert_eq(int(u.mp), 0, "新英雄 dyna 空 → 初始 mp=0（首关能量从零开始）")
	assert_gt(int(u.hp), 0, "新英雄 hp 按 attribs 正常初始化")
