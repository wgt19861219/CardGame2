extends Node

## 复验：Toast 1s 停留+1s 淡出 + 连点替换（2026-08-30 四轮，用户反馈上限 toast 太久）。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.2).timeout
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		if (pd.hero_manager.heroes[inst_id] as HeroInstance).level == 1:
			hero = pd.hero_manager.heroes[inst_id]   # 1 级英雄 → 达上限分支
			break
	if hero == null:
		print("QAQ 无 1 级英雄，直接连发 Toast 验证")
	else:
		print("QAQ hero level=", hero.level, " skill[0]=", hero.skill_levels[0])
	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:   # 照 hero_package 接线（判例：直连须补）
		dp.perform_upgrade_skill(idx))
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.3).timeout

	# 连点 5 次上限升级（旧实现=5 条排队 10s；新=只显示 1 条共 2s）
	var t0: float = Time.get_ticks_msec() / 1000.0
	for i in 5:
		dp._on_skill_upgrade_clicked(0)
		await get_tree().create_timer(0.1).timeout
	print("QAQ 连点5次后 pending=", Toast.pending_count(), "（期望 1，替换语义）")

	# 采样 2.6s：alpha 时间轴（1s 满、1~2s 渐隐、2s 后无）
	var timeline: Array[String] = []
	for i in 26:
		var a: float = Toast._current_board.modulate.a if Toast._current_board != null else -1.0
		timeline.append(str(snappedi(a * 100.0, 10)))
		await get_tree().create_timer(0.1).timeout
	print("QAQ alpha时间轴(%)=", " ".join(timeline))
	var total: float = Time.get_ticks_msec() / 1000.0 - t0
	print("QAQ 总耗时=", snappedf(total, 0.1), "s（期望 ~2s 含 0.5s 连点期，非 10s 排队）")
	print("QAQ DONE")
