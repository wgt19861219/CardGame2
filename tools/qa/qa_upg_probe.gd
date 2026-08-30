extends Node

## 迷你探针：升级按钮 emit 后链路为何未 +1（qa_buy_verify 遗留疑点）。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.2).timeout
	pd.skill_points = 10
	pd.skill_cd_time = Time.get_unix_time_from_system()
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	hero.level = 10
	print("QAP start skill=", hero.skill_levels[0], " pts=", pd.skill_points, " gold=", pd.hero_manager.gold)

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	var got_signal: Array = [-9]
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		got_signal[0] = idx
		print("QAP signal received idx=", idx)
		var ok: bool = dp.perform_upgrade_skill(idx)
		print("QAP perform ok=", ok)
		if ok:
			dp.refresh_content())
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.4).timeout
	dp._show_tab_content("skill", false)
	await get_tree().create_timer(0.3).timeout

	var sv: CanvasItem = dp._tab_views["skill"]
	var up_btn: TextureButton = sv.get_node("%Skill1Btn")
	print("QAP up_btn visible=", up_btn.visible, " modulate=", up_btn.modulate,
		" conns=", up_btn.pressed.get_connections().size())
	Toast._queue.clear()
	up_btn.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	print("QAP after emit: signal_idx=", got_signal[0], " skill=", hero.skill_levels[0],
		" pts=", pd.skill_points, " gold=", pd.hero_manager.gold,
		" toast=", Toast._queue[0] if Toast.pending_count() > 0 else \
		(Toast._current_label.text if Toast._current_label != null else "无"))
	print("QAP DONE")
