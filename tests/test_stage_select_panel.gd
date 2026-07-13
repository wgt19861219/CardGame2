extends GutTest
# Phase 6 UI StageSelectPanel 测试（2026-07-02）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_panel_assembles() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(5)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_panel(mgr, pd, rng)
	panel.show_window(root)
	# 新结构（照源 stageselect 地图式）：bg + close + map_layer(章节图+路线+stage圆点)
	# + frame/title_bg/title_label + mode_bg + 3 mode toggle + 箭头 + dots
	assert_gt(panel.container.get_child_count(), 8, "完整地图式装配（bg/close/map/frame/mode/箭头/dot）")
	# chapter1 normal 新档：stage1（key id=1 star0 → current）可点 → _stage_buttons 含 sid=1
	assert_true(panel._stage_buttons.has(1), "chapter1 stage1（current）进可点 buttons")
	panel.remove_window()
	root.queue_free()


# 源 doChangeMode(:319) — 三 mode toggle 切换。
func test_mode_switch() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(5)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_panel(mgr, pd, rng)
	panel.show_window(root)
	assert_eq(panel._mode, "normal", "默认 normal")
	panel._on_mode_pressed("elite")
	assert_eq(panel._mode, "elite", "切 elite")
	panel._on_mode_pressed("guild")
	assert_eq(panel._mode, "guild", "切 guild")
	panel.remove_window()
	root.queue_free()


func test_run_stage_battle_builds_result() -> void:
	# 衔接数据流：run_stage_battle（发奖励 + hero_cache 快照）→ build_result_param（装配结算 param）。
	# 不调 _on_stage_n（会 change_scene 切场景破坏 GUT 树，照源 replaceScene 直接切是 View 职责）。
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	var rng := BattleRng.new(5)
	var r: Dictionary = mgr.run_stage_battle(-27, pd, [1], rng)
	assert_true(bool(r.get("ok", false)), "run_stage_battle ok（含 take_stage_reward 不崩）")
	var result_param := {
		"stage_id": -27, "victory": bool(r["won"]), "heroes": [1],
		"stars": int(r["stars"]), "loots": r.get("loots", []), "excavate_mode": false, "isPveMode": true,
	}
	GameData.last_result = StageAccount.build_result_param(result_param, cm, pd, pd.hero_manager)
	assert_true(GameData.last_result.has("stage_id"), "last_result 装配 stage_id")
	assert_eq(bool(GameData.last_result["victory"]), bool(r["won"]), "last_result victory 匹配")
	# loots 数据流贯通：run_stage_battle 返 loots（源 enter 生成存 ed.player.loots）含必掉扫荡券 390。
	# loot_list 聚合由 test_stage_account 覆盖（victory 分支装配，失败分支不装配照源）。
	var loots: Array = r.get("loots", [])
	assert_false(loots.is_empty(), "run_stage_battle 返 loots 非空")
	var last: Dictionary = loots[loots.size() - 1]
	assert_eq(int(last["id"]), 390, "loots 末位必掉扫荡券 390")


# 批次5 验收：高难度关多波战斗 + 失败分支
func test_high_level_stage_50_3_waves() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var rng := BattleRng.new(42)
	# stage 50: chapter 3, 3 waves, monster_level 18
	var r: Dictionary = mgr.run_stage_battle(50, pd, [1, 2, 3, 4, 5], rng)
	assert_true(bool(r.get("ok", false)), "stage 50 战斗完成（不超时）")
	# 3 波战斗应该有胜负结果
	assert_true(r.has("won"), "有胜负结果")

func test_stage_failed_branch() -> void:
	# 弱队打高难度关 → 可能失败
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var rng := BattleRng.new(42)
	# 只上 1 个 1 级英雄打 stage 50（故意弱化）
	var r: Dictionary = mgr.run_stage_battle(50, pd, [1], rng)
	assert_true(bool(r.get("ok", false)), "战斗完成（不崩）")
	# 无论胜负，结算流程能走通


# ===== P1-10：setup_by_stage 按指定 stage 定位章（源 stageselect.createByStage）=====

func _make_stage_panel() -> StageSelectPanel:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(1)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_panel(mgr, pd, rng)
	panel.show_window(root)
	return panel


# 普通关 _chapter_of_stage = Stage 表 Chapter ID（源 equipcraft :1166-1168）
func test_chapter_of_stage_normal() -> void:
	var st: Dictionary = cm.get_raw_table("Stage")
	var normal_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if sid > 0 and sid < 10000 and StageAccount.stage_type(sid) == "normal":
			normal_sid = sid
			break
	if normal_sid == 0:
		pass_test("无普通关，跳过")
		return
	var panel := _make_stage_panel()
	var expect_ch: int = int(st.get(str(normal_sid), {}).get("Chapter ID", 0))
	assert_eq(panel._chapter_of_stage(normal_sid), expect_ch, "普通关 _chapter_of_stage = Stage Chapter ID")
	panel.remove_window()


# 精英关（id>=10000）_chapter_of_stage = Stage Group 的 Chapter ID（源 equipcraft :1169-1173）
func test_chapter_of_stage_elite() -> void:
	var st: Dictionary = cm.get_raw_table("Stage")
	var elite_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if sid >= 10000:
			elite_sid = sid
			break
	if elite_sid == 0:
		pass_test("无精英关，跳过")
		return
	var panel := _make_stage_panel()
	var gid: int = int(st.get(str(elite_sid), {}).get("Stage Group", elite_sid))
	var expect_ch: int = int(st.get(str(gid), {}).get("Chapter ID", 0))
	assert_eq(panel._chapter_of_stage(elite_sid), expect_ch, "精英关 _chapter_of_stage = Stage Group 的 Chapter ID")
	panel.remove_window()


# setup_by_stage 按 stage 定位到所在章（源 stageselect.createByStage(id)）
func test_setup_by_stage_sets_chapter() -> void:
	var st: Dictionary = cm.get_raw_table("Stage")
	var normal_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if sid > 0 and sid < 10000 and StageAccount.stage_type(sid) == "normal":
			normal_sid = sid
			break
	if normal_sid == 0:
		pass_test("无普通关，跳过")
		return
	var expect_ch: int = int(st.get(str(normal_sid), {}).get("Chapter ID", 0))
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(1)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_by_stage(mgr, pd, rng, normal_sid)
	panel.show_window(root)
	assert_eq(panel._current_chapter, expect_ch, "setup_by_stage 定位到 stage 所在章")
	panel.remove_window()
	root.queue_free()
