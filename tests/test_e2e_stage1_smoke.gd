extends GutTest
## 端到端冒烟：验证 stage 1 战斗全流程（assemble → engine 跑 → finalize → build_result_param → BattleScene._process）
## 不是单元测试 — 是流程闭环验证。
## 运行：godot --headless -s res://addons/gut/gut_cmdln.gd -gselect=test_e2e_stage1_smoke -gexit

var cm: ConfigManager
var lib: SkillLibrary


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)


func _make_player() -> PlayerData:
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	# 给玩家加几个英雄（tid 1-5）
	for tid in [1, 2, 3, 4, 5]:
		pd.hero_manager.add_hero(tid)
	return pd


# 主线：stage 1 全流程：选 5 人阵容 → assemble → engine 跑到自然结束 → finalize → build_result_param。
# 验证战斗流程闭环可用，不出现死循环 / 不分胜负 / 数据装配缺字段。
func test_stage1_full_battle_flow() -> void:
	var player := _make_player()
	var rng := BattleRng.new(12345)
	var mgr := StageManager.new(cm)

	var tids: Array[int] = [1, 2, 3, 4, 5]

	# --- 1. assemble ---
	var asm := mgr.assemble_stage_battle(1, player, tids, rng)
	assert_true(bool(asm.get("ok", false)), "assemble_stage_battle 应成功，error=" + String(asm.get("error", "")))
	assert_not_null(asm.get("engine"), "engine 应装配")
	assert_not_null(asm.get("battle_info"), "battle_info 应装配")
	var eng: BattleEngine = asm["engine"]
	var enemy_count := eng.foreach_alive_unit(BattleEngine.CAMP_ENEMY).size()
	var player_count := eng.foreach_alive_unit(BattleEngine.CAMP_PLAYER).size()
	assert_eq(player_count, tids.size(), "玩家单位数 = 阵容数")
	assert_gt(enemy_count, 0, "敌人单位 > 0")
	gut.p("装配完成：玩家=%d 敌人=%d" % [player_count, enemy_count])

	# --- 2. engine 跑（最多 5000 tick/波，3 波）---
	# wave_clear 时（本波清完）自动 next_battle 切波继续，模拟玩家点"下一波"。
	var ticks_left := 5000
	while ticks_left > 0:
		if eng.stage_ended:
			break
		if not eng.running:
			if eng.wave_clear:
				BattleEngineWaves.next_battle(eng, cm)   # 自动切波（测试模拟玩家点下一波）
				eng.wave_clear = false
				eng.running = true   # 切波后恢复战斗（同 advance_wave）
				ticks_left = 5000   # 重置（新波次）
				continue
			break   # 真正结束（非 wave_clear）
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks_left -= 1
	assert_true(eng.stage_ended, "战斗应自然结束（3 波全清）")
	assert_false(eng.running or not eng.stage_ended, "战斗应自然结束")
	gut.p("战斗结束：ticks_left=%d stage_ended=%s" % [ticks_left, eng.stage_ended])

	# --- 3. finalize ---
	var loots: Array[Dictionary] = []
	loots.assign(asm["loots"])
	var r := mgr.finalize_stage_battle(eng, 1, player, tids, loots)
	assert_true(bool(r.get("ok", false)), "finalize 应成功")
	var won := bool(r.get("won", false))
	var stars := int(r.get("stars", 0))
	gut.p("结算：won=%s stars=%d exp=%d" % [won, stars, r.get("exp", 0)])
	assert_true(won, "stage1 应胜利")
	assert_eq(stars, 3, "stage1 应满星")

	# --- 4. build_result_param ---
	var result_param := {
		"stage_id": 1, "victory": won, "heroes": tids,
		"stars": stars, "loots": loots, "excavate_mode": false, "isPveMode": true,
		"hero_hp_mp": r.get("hero_hp_mp", {}),
	}
	var built := StageAccount.build_result_param(result_param, cm, player, player.hero_manager)
	assert_eq(int(built.get("stage_id", -1)), 1, "stage_id 一致")
	assert_eq(bool(built.get("victory", false)), true, "victory=true")
	var heroes_arr := built.get("heroes", []) as Array
	var loot_dict := built.get("loot_list", {}) as Dictionary
	var player_info := built.get("player_info", {}) as Dictionary
	gut.p("build_result_param：heroes=%d loot_list=%d player_level=%d" % [
		heroes_arr.size(), loot_dict.size(), int(player_info.get("ori_level", -1)),
	])
	assert_eq(heroes_arr.size(), tids.size(), "heroes 数 = 阵容")


# BattleScene View 接入：装配后 _process 驱动 engine + sync actors 不崩 + 战斗能跑完。
func test_battle_scene_view_integration() -> void:
	var player := _make_player()
	var rng := BattleRng.new(999)
	var mgr := StageManager.new(cm)
	var tids: Array[int] = [1, 2, 3, 4, 5]

	var asm := mgr.assemble_stage_battle(1, player, tids, rng)
	assert_true(bool(asm.get("ok", false)))
	var eng: BattleEngine = asm["engine"]
	var battle_info: Dictionary = asm["battle_info"]

	var scene := BattleScene.new()
	add_child(scene)   # scene 入树（actor/puppet 的 create_timer 才能正常工作）
	scene.setup(eng, cm, battle_info)
	gut.p("scene setup OK，actor_list=%d" % scene.actor_list.size())

	# 跑 60 帧（约 1 秒）— engine 自然结束前看 actor 同步
	for i in 60:
		scene._process(0.033)
	gut.p("60 帧后 actor_list=%d ticks=%d running=%s" % [scene.actor_list.size(), eng.ticks, eng.running])
	assert_gt(scene.actor_list.size(), 0, "应至少装配 actor")

	# 跑到战斗结束（最多 5000 帧）
	var frames_left := 5000
	while eng.running and not eng.stage_ended and frames_left > 0:
		scene._process(0.033)
		frames_left -= 1
	assert_true(frames_left > 0, "战斗不应死循环（frames_left=%d）" % frames_left)
	gut.p("战斗结束：actor_list=%d frames_left=%d stage_ended=%s" % [scene.actor_list.size(), frames_left, eng.stage_ended])
	scene.queue_free()


# stage_failed_scene 装配冒烟（victory=false 走失败结算分支）。
func test_stage_failed_scene_assemble() -> void:
	# 模拟 stage_done_finalizer 的失败分支：build_result_param(isPveMode=true, victory=false)
	var player := _make_player()
	var result_param := {
		"stage_id": 1, "victory": false, "heroes": [1, 2, 3, 4, 5] as Array[int],
		"stars": 0, "loots": [] as Array[Dictionary], "excavate_mode": false, "isPveMode": true,
		"hero_hp_mp": {},
		"lose_type": "fail",
	}
	var built := StageAccount.build_result_param(result_param, cm, player, player.hero_manager)
	# StageFailedScene.setup 不崩
	var scene := StageFailedScene.new()
	add_child(scene)
	scene.setup(built, cm)
	assert_eq(scene.stage_id, 1, "stage_id 一致")
	assert_eq(scene.lose_type, "fail", "lose_type=fail")
	gut.p("StageFailedScene setup OK, stage_id=%d lose_type=%s" % [scene.stage_id, scene.lose_type])
	scene.queue_free()


# lose_type 透传：源 doFailed.loseType={timeout,fail}，engine.last_result=RESULT_TIMEOUT 时应产 timeout。
func test_finalize_stage_battle_passes_lose_type() -> void:
	var player := _make_player()
	var mgr := StageManager.new(cm)
	var tids: Array[int] = [1, 2, 3, 4, 5]
	var asm := mgr.assemble_stage_battle(1, player, tids, BattleRng.new(7))
	var eng: BattleEngine = asm["engine"]
	var loots: Array[Dictionary] = []
	# 不跑战斗 — 手动触发 timeout 退出
	eng.exit_stage(BattleEngine.RESULT_TIMEOUT)
	var r := mgr.finalize_stage_battle(eng, 1, player, tids, loots)
	assert_false(bool(r["won"]), "timeout 失败")
	assert_eq(String(r["lose_type"]), "timeout", "RESULT_TIMEOUT → lose_type=timeout")
	# 验证 build_result_param 透传
	var built := StageAccount.build_result_param({
		"stage_id": 1, "victory": false, "heroes": tids, "stars": 0,
		"loots": loots, "excavate_mode": false, "isPveMode": true,
		"hero_hp_mp": {}, "lose_type": String(r["lose_type"]),
	}, cm, player, player.hero_manager)
	assert_eq(String(built.get("lose_type", "")), "timeout", "build_result_param 透传 lose_type")


# stage_done_scene 结算装配：built → setup 不崩。
func test_stage_done_scene_assemble() -> void:
	var player := _make_player()
	var rng := BattleRng.new(7)
	var mgr := StageManager.new(cm)
	var tids: Array[int] = [1, 2, 3, 4, 5]

	# 跑完一场真战斗
	var asm := mgr.assemble_stage_battle(1, player, tids, rng)
	var eng: BattleEngine = asm["engine"]
	var ticks_left := 5000
	while eng.running and not eng.stage_ended and ticks_left > 0:
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks_left -= 1
	var loots: Array[Dictionary] = []
	loots.assign(asm["loots"])
	var r := mgr.finalize_stage_battle(eng, 1, player, tids, loots)
	assert_true(bool(r.get("won", false)), "应胜利")

	# build_result_param
	var result_param := {
		"stage_id": 1, "victory": true, "heroes": tids,
		"stars": 3, "loots": loots, "excavate_mode": false, "isPveMode": true,
		"hero_hp_mp": r.get("hero_hp_mp", {}),
	}
	var built := StageAccount.build_result_param(result_param, cm, player, player.hero_manager)

	# StageDoneScene.setup 不崩（2026-08-05 合并后：静态节点固化进 .tscn，必须 instantiate）。
	var scene: StageDoneScene = load("res://scenes/battle/stage_done_scene.tscn").instantiate() as StageDoneScene
	add_child(scene)
	scene.setup(built, cm)
	gut.p("StageDoneScene setup OK，star_nodes=%d hero_icons=%d loot_icons=%d" % [
		scene._star_nodes.size(), scene._hero_icon_nodes.size(), scene._loot_icon_nodes.size(),
	])
	assert_eq(scene._star_nodes.size(), 3, "3 颗星节点")
	assert_eq(scene._hero_icon_nodes.size(), tids.size(), "5 个英雄 icon")
	scene.queue_free()
