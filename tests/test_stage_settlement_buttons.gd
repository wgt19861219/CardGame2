extends GutTest
# 结算页按钮跳转守卫（2026-08-31 三轮）：胜利页 Replay/Next 与失败页 Back 此前都只回主界面
# （源 doClickReplay/doClickBack → replaceScene(stagedetail)、doClickNext → WinBackToSelect 选关）。
# 守卫：replay/next 目标纯函数（普通关→详情/选关、dungeon 分流空目标）+ 三页接线 grep 断言防回退。


# 普通关重试 → 关卡详情（源 stagedone.lua:93 / stagefailed.lua:42 → stagedetail）。
func test_replay_target_normal_stage() -> void:
	var t: Dictionary = StageSettlementCommon.replay_target(1)
	assert_eq(t.get("target", ""), "stagedetail", "重试目标 = stagedetail")
	assert_eq(int(t.get("stage_id", 0)), 1, "携带 stage_id")


# dungeon 关（mode 走 stage 结算）无独立详情面板 → 空目标保持回主界面（受控简化）。
# ch203 lich 段（50022-50030）除外——回 LichMapPanel 定位该关（2026-10-10 接通，
# 用户反馈"结算点继续直回主城两眼一黑"）。
func test_replay_target_dungeon_stage() -> void:
	assert_true(StageSettlementCommon.replay_target(50001).is_empty(), "非 lich dungeon 关重试空目标")


# lich 段重试/下一关都回 LichMapPanel（面板即副本入口，可再开战/换难度/换 Boss）。
func test_replay_next_target_lich_stage() -> void:
	for sid in [50022, 50026, 50030]:
		var tr: Dictionary = StageSettlementCommon.replay_target(sid)
		assert_eq(String(tr.get("target", "")), "lichmap", "关 %d 重试目标 = lichmap" % sid)
		assert_eq(int(tr.get("stage_id", 0)), sid, "重试携带 stage_id 定位关")
		var tn: Dictionary = StageSettlementCommon.next_target(sid)
		assert_eq(String(tn.get("target", "")), "lichmap", "关 %d 下一关目标 = lichmap" % sid)
		assert_eq(int(tn.get("stage_id", 0)), sid, "下一关携带 stage_id 定位关")


# 下一关 → 选关（源 doClickNext → popScene + WinBackToSelect）；PVP → ladder
# （源 popScene 回 pvp 发起面板，2026-10-09 修正「战斗完大退主界面」）。
func test_next_target() -> void:
	assert_eq(StageSettlementCommon.next_target(1).get("target", ""), "stageselect", "下一关目标 = stageselect")
	assert_true(StageSettlementCommon.next_target(50001).is_empty(), "非 lich dungeon 关下一关空目标")
	assert_eq(StageSettlementCommon.next_target(-1).get("target", ""), "ladder", "PVP 下一关目标 = ladder（源 popScene 回 pvp）")


# 胜利页两按钮接 helper（防回退成裸 goto_main_scene）。
func test_done_scene_buttons_wired() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/view/battle/stage_done_scene.gd")
	var s1: int = src.find("func _on_replay_pressed()")
	var e1: int = src.find("\nfunc ", s1 + 10)
	var b1: String = src.substr(s1, (e1 if e1 > 0 else src.length()) - s1)
	assert_true(b1.contains("replay_stage("), "Replay 应调 replay_stage（源 doClickReplay→stagedetail）")
	var s2: int = src.find("func _on_next_pressed()")
	var e2: int = src.find("\nfunc ", s2 + 10)
	var b2: String = src.substr(s2, (e2 if e2 > 0 else src.length()) - s2)
	assert_true(b2.contains("next_stage("), "Next 应调 next_stage（源 doClickNext→选关）")


# 失败页 Back 接 helper；Menu 普通关回主界面，PVP（sid=-1）走 pvp_menu_back 重弹 ladder
# （源 doClickMenu popScene 回发起场景=pvp 面板，2026-10-09 补）。
func test_failed_scene_back_wired() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/view/battle/stage_failed_scene.gd")
	var s1: int = src.find("func _on_back_pressed()")
	var e1: int = src.find("\nfunc ", s1 + 10)
	var b1: String = src.substr(s1, (e1 if e1 > 0 else src.length()) - s1)
	assert_true(b1.contains("replay_stage("), "Back 应调 replay_stage（源 doClickBack→stagedetail）")
	var s2: int = src.find("func _on_menu_pressed()")
	var e2: int = src.find("
func ", s2 + 10)
	var b2: String = src.substr(s2, (e2 if e2 > 0 else src.length()) - s2)
	assert_true(b2.contains("ARENA_STAGE_ID") and b2.contains("pvp_menu_back"), "PVP 失败 Menu 走 pvp_menu_back（回 ladder）")


# main_scene 消费 pending_stage_result（跨场景重弹面板链闭合）。
# duplicate 守卫：GDScript Dictionary 引用型，先拷贝再 clear（否则 pr 同步清空读值恒默认走错分支；
# 实机五轮取证实锤 select_panel=1 误弹，excavate 存量同病一并修）。pvp 消费 2026-09-13 退役
# （PVP 结算补全改切 stageDone/stageFailed 场景，回主菜单 Toast+重开面板方案删除）。
func test_main_scene_consumes_pending() -> void:
	var src: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	assert_true(src.contains("func _maybe_resume_stage_result()"), "存在消费函数")
	assert_true(src.contains("_maybe_resume_stage_result()\n") or src.contains("_maybe_resume_stage_result()"), "_ready 调用消费")
	assert_true(src.contains("pending_stage_result"), "读 pending_stage_result")
	assert_eq(src.count(".duplicate()   #"), 2, "两处 pending 消费均先 duplicate 再 clear（excavate/stage_result）")
	assert_true(src.contains('"ladder"'), "ladder 分支存在（PVP 结算返回重弹竞技场，2026-10-09）")
	assert_true(src.contains('"lichmap"') and src.contains("open_lich_map"),
		"lichmap target 分支接 open_lich_map（ch203 副本结算回面板，2026-10-10）")
