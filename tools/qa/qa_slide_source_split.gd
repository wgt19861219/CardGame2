extends Node

## 复验（七轮）：装备等默认刷新不滑（offset 恒 -200）+ 升级路径滑入（起跳→-200）。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.2).timeout
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	hero.level = 10

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		if dp.perform_upgrade_skill(idx):
			dp.refresh_content(true))   # 照 hero_package 七轮接线
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.4).timeout
	dp._on_tab_pressed("skill")
	await get_tree().create_timer(0.4).timeout

	# ① 装备穿戴等默认刷新 → 不滑
	dp.refresh_content()
	var s1: Array[float] = []
	for i in range(8):
		await get_tree().process_frame
		var sv: CanvasItem = dp._tab_views["skill"]
		if sv != null and sv.is_inside_tree():
			s1.append(sv.offset_left)
	print("QAF 装备刷新采样=", s1, "（期望恒 -200）")
	print("QAF 装备刷新不滑=", s1.size() > 0 and s1.all(func(x: float) -> bool: return abs(x + 200.0) < 1.0))

	# ② 升级路径 → 滑入
	(dp._tab_views["skill"] as CanvasItem).get_node("%Skill1Btn").pressed.emit()
	var s2: Array[float] = []
	for i in range(10):
		await get_tree().process_frame
		var sv2: CanvasItem = dp._tab_views["skill"]
		if sv2 != null and sv2.is_inside_tree():
			s2.append(sv2.offset_left)
	print("QAF 升级刷新采样=", s2, "（期望起跳 >300 渐落）")
	print("QAF 升级滑入重播=", s2.size() > 1 and s2[0] > 300.0)
	print("QAF DONE")
