extends Node

## 精英关扫荡修复实机验证 override（2026-10-07，一次性）：
## 直接创建 StageDetailPanel(10001)（真实产品代码链路）→ 记录初始 CountTitle →
## _do_sweep(1)（真实扫荡：扣券/体力/计次）→ 记录扫后 CountTitle + stage_limit。
## 用完 uninstall_override 清注册。

func _ready() -> void:
	var pd: Variant = GameData.player
	if pd == null:
		print("[ELITE_QA] FAIL: GameData not ready")
		return
	var scene: Variant = get_tree().current_scene
	var mgr: Variant = pd.stage_manager
	var rng := BattleRng.new(42)
	var panel := StageDetailPanel.new("stagedetail", {})
	panel.setup_panel(10001, mgr, pd, rng)
	panel.show_window(scene)
	await get_tree().process_frame
	print("[ELITE_QA] before: ", panel._count_title.text, " | limit=", panel._daily_limit(), " used=", panel._used_times())
	print("[ELITE_QA] some_btn label: ", (panel._some_btn.get_node("SweepSomeLabel") as Label).text)
	panel._do_sweep(1)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[ELITE_QA] after:  ", panel._count_title.text, " | used=", panel._used_times())
	print("[ELITE_QA] stage_limit[10001]=", int(pd.stage_limit.get(10001, 0)), " tickets=", pd.get_sweep_times())
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://elite_sweep_after.png")
	print("[ELITE_QA] shot saved user://elite_sweep_after.png")
