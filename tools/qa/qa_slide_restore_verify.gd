extends Node

## 复验：升级成功 → 重建重播滑入（2026-08-30 三轮，用户要刷新反馈）。

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

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		if dp.perform_upgrade_skill(idx):
			dp.refresh_content())
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.4).timeout
	dp._on_tab_pressed("skill")
	await get_tree().create_timer(0.4).timeout
	print("QAS3 升级前 offset=", (dp._tab_views["skill"] as CanvasItem).offset_left, " skill[0]=", hero.skill_levels[0])

	(dp._tab_views["skill"] as CanvasItem).get_node("%Skill1Btn").pressed.emit()
	var samples: Array[float] = []
	for i in range(14):
		await get_tree().process_frame
		var sv: CanvasItem = dp._tab_views["skill"]
		if sv != null and sv.is_inside_tree():
			samples.append(sv.offset_left)
	print("QAS3 升级重建采样=", samples)
	print("QAS3 skill[0]=", hero.skill_levels[0], "(+1=升级成功)")
	var replayed: bool = samples.size() > 1 and samples[0] > -199.0
	print("QAS3 升级后滑入重播=", replayed, "（用户要的效果 ✓）")
	print("QAS3 DONE")
