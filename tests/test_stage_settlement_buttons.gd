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
func test_replay_target_dungeon_stage() -> void:
	assert_true(StageSettlementCommon.replay_target(50001).is_empty(), "dungeon 关重试空目标")


# 下一关 → 选关（源 doClickNext → popScene + WinBackToSelect）。
func test_next_target() -> void:
	assert_eq(StageSettlementCommon.next_target(1).get("target", ""), "stageselect", "下一关目标 = stageselect")
	assert_true(StageSettlementCommon.next_target(50001).is_empty(), "dungeon 关下一关空目标")


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


# 失败页 Back 接 helper（Menu 保持回主界面=源 doClickMenu popScene 回地图，不改）。
func test_failed_scene_back_wired() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/view/battle/stage_failed_scene.gd")
	var s1: int = src.find("func _on_back_pressed()")
	var e1: int = src.find("\nfunc ", s1 + 10)
	var b1: String = src.substr(s1, (e1 if e1 > 0 else src.length()) - s1)
	assert_true(b1.contains("replay_stage("), "Back 应调 replay_stage（源 doClickBack→stagedetail）")


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
