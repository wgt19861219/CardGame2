extends Node

## 一次性自动取证（结算页按钮跳转 2026-08-31）：
## 胜利页 Replay/失败页 Back → 回主界面弹关卡详情（源 doClickReplay/doClickBack→stagedetail）；
## 胜利页 Next → 回主界面弹选关（源 doClickNext→WinBackToSelect）。
## 验证纯函数目标 + pending 消费后主界面面板真实弹出（两轮切换）。


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	print("QA_AUTO: replay_target(1)=", StageSettlementCommon.replay_target(1))
	print("QA_AUTO: next_target(1)=", StageSettlementCommon.next_target(1))
	print("QA_AUTO: replay_target(50001)=", StageSettlementCommon.replay_target(50001), "（dungeon 空）")
	await get_tree().create_timer(3.0).timeout   # 等 loading→main 启动链稳定（autoload 早期切场景会被 loading 自动切换竞争刷掉面板）

	# 隔离排查②：不切场景直接调主场景消费函数（测消费函数本身）
	var main_now: Node = get_tree().current_scene
	print("QA_AUTO: current_scene=", main_now.name)
	GameData.pending_stage_result = StageSettlementCommon.replay_target(1)
	main_now._maybe_resume_stage_result()
	await get_tree().create_timer(1.0).timeout
	var consumed: Array = get_tree().root.find_children("*", "StageDetailPanel", true, false)
	print("QA_AUTO: consumed detail_panel=", consumed.size(), "（直接调消费函数应=1）")
	var sels: Array = get_tree().root.find_children("*", "StageSelectPanel", true, false)
	print("QA_AUTO: consumed select_panel=", sels.size(), "（>0=走了 else 分支，target 判定失败）")
	for c in consumed:
		c.queue_free()

	# 第一轮：重试 → 关卡详情
	GameData.pending_stage_result = StageSettlementCommon.replay_target(1)
	SceneManager.change_scene("res://scenes/main_menu/main_scene.tscn")
	await get_tree().create_timer(2.0).timeout
	var details: Array = get_tree().root.find_children("*", "StageDetailPanel", true, false)
	print("QA_AUTO: replay→detail_panel=", details.size(), "（应=1）")
	for d in details:
		print("QA_AUTO:   detail sid=", d.get("sid") if d.get("sid") != null else "?")
		d.queue_free()
	GameData.pending_stage_result.clear()

	# 第二轮：下一关 → 选关
	GameData.pending_stage_result = StageSettlementCommon.next_target(1)
	SceneManager.change_scene("res://scenes/main_menu/main_scene.tscn")
	await get_tree().create_timer(2.0).timeout
	var selects: Array = get_tree().root.find_children("*", "StageSelectPanel", true, false)
	print("QA_AUTO: next→select_panel=", selects.size(), "（应=1）")
	print("QA_AUTO: DONE")
