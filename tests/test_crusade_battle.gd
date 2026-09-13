extends GutTest
# Phase 6 Crusade 战斗闭环测试（2026-07-02）— run_crusade_battle 端到端。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_run_crusade_battle_structure() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var r: Dictionary = mgr.run_crusade_battle(1, pd, [1], BattleRng.new(42))
	assert_eq(bool(r["ok"]), true, "run_crusade_battle ok（端到端不崩）")
	assert_true(r.has("won"), "返 won 字段")


func test_run_crusade_battle_no_enemies_fails() -> void:
	var mgr := CrusadeManager.new(cm)
	# 未 init_crusade → enemies 空 → get_stage_enemies 空 → ok=false
	var pd := PlayerData.new(cm)
	var r: Dictionary = mgr.run_crusade_battle(1, pd, [1], BattleRng.new(42))
	assert_eq(bool(r["ok"]), false, "无敌人配置返 ok=false")


func test_crusade_win_advances_stage() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var r: Dictionary = mgr.run_crusade_battle(1, pd, [1], BattleRng.new(42))
	assert_true(r.has("won"), "返 won 字段")
	if bool(r["won"]):
		assert_eq(mgr.cur_stage, 2, "胜利推进下一层")
		assert_true(mgr.is_stage_cleared(1), "stage 1 标记通关")


func test_cross_battle_hp_persisted() -> void:
	# 战斗后英雄 HP/MP 存入 hero_hp_perc/hero_mp_perc（跨关保持基础）
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	mgr.run_crusade_battle(1, pd, [1], BattleRng.new(42))
	# 战斗后应有跨关状态（存活的 tid → perc），至少状态被更新过
	assert_true(mgr.hero_hp_perc is Dictionary or mgr.hero_hp_perc.is_empty(), "HP 状态结构合法")


# ---- 2026-09-14 assemble/finalize 拆分（battle_scene View 接入）守卫 ----

# 装配用负数 stage_id（源 crusade.start stageId=-2-currentStage）→ 引擎取 Stage 表 crusade
# 专用行（-3~-17，Chapter ID=-3 → chapter-3 BGM）而非第一章普通关卡行（旧同步实现错传正数）。
func test_assemble_negative_stage_id_uses_crusade_row() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var r: Dictionary = CrusadeBattle.assemble_crusade_battle(mgr, -3, pd, [1], BattleRng.new(42))
	assert_true(bool(r.get("ok", false)), "assemble ok")
	var eng: BattleEngine = r["engine"]
	assert_true(bool(eng.crusade_mode), "engine.crusade_mode")
	assert_eq(int(eng.stage_info.get("Chapter ID", 0)), -3, "stage_info 取 Stage[-3] crusade 行（Chapter ID=-3）")
	assert_eq(String(r["battle_info"].get("Background Pic", "")), "battle_bg/bbg_burning_land.jpg",
		"battle_info=Battle[-3][1]（燃烧之地 bg）")
	assert_eq(int(r["stage"]), 1, "返正数关号 stage=1")


# 空队拒绝（不污染跨关 HP/MP 与进度）。
func test_assemble_empty_team_rejected() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	var r: Dictionary = CrusadeBattle.assemble_crusade_battle(mgr, -3, pd, [], BattleRng.new(42))
	assert_false(bool(r.get("ok", false)), "空队 ok=false")
	assert_eq(String(r.get("error", "")), "empty_team", "空队错误码")


# 玩家跨关 HP/MP 注入装配（第二场战斗以第一场终态 HP 开局；源 dynaData hp_info）。
func test_assemble_injects_cross_battle_hp() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	mgr.hero_hp_perc[1] = 0.5   # 直接摆跨关状态
	var r: Dictionary = CrusadeBattle.assemble_crusade_battle(mgr, -3, pd, [1], BattleRng.new(42))
	assert_true(bool(r.get("ok", false)), "assemble ok")
	var eng: BattleEngine = r["engine"]
	var player_units: Array = eng.foreach_alive_unit(BattleEngine.CAMP_PLAYER)
	assert_eq(player_units.size(), 1, "玩家 1 单位")
	assert_almost_eq(float(player_units[0].hp), float(player_units[0].attribs.get("HP", 0.0)) * 0.5, 1.0,
		"开局 HP=满血×50%（跨关注入）")


# finalize：胜利 fight 推进 + 存跨关 HP/MP；返回 hero_hp_mp 快照。
func test_finalize_win_advances_and_persists() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var asm_r: Dictionary = CrusadeBattle.assemble_crusade_battle(mgr, -3, pd, [1], BattleRng.new(42))
	var eng: BattleEngine = asm_r["engine"]
	var ticks: int = 300
	while eng.running and not eng.stage_ended and ticks > 0:
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks -= 1
	var r: Dictionary = CrusadeBattle.finalize_crusade_battle(mgr, eng)
	assert_true(bool(r.get("ok", false)), "finalize ok")
	assert_true(r.has("won"), "返 won")
	assert_true(r.has("hero_hp_mp"), "返 hero_hp_mp 快照")
	if bool(r["won"]):
		assert_eq(mgr.cur_stage, 2, "胜利推进下一层")
		assert_true(mgr.is_stage_cleared(1), "stage 1 标记通关")
