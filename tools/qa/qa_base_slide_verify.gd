extends Node

## 终验（十一轮）：穿戴后 base 层立即 140（无 0→140 右挫动画）+ 升级路径仍保留滑入反馈。

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
			dp.refresh_content(true))
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.4).timeout
	dp._on_tab_pressed("card")   # 用户视频同款：图鉴 tab
	await get_tree().create_timer(0.5).timeout
	print("QAV2 穿戴前 base_x=", dp._base_layer.position.x)

	# 穿戴链（card tab 态）
	var host: Node = get_tree().current_scene
	HeroDetailEquipSlots.open_equip_craft(0, hero, pd.cm, pd, host,
		dp.refresh_content,
		func(stage_id: int) -> void: pass)
	await get_tree().create_timer(0.3).timeout
	var craft: Node = null
	for c in host.get_children():
		if c is EquipCraftPanel:
			craft = c
	pd.hero_manager.wear_equip(hero.inst_id, 0)
	craft.equipped_changed.emit()
	craft.remove_window()

	# 逐帧采 base.x：应恒 140（旧实现 0→140 tween）
	var xs: Array[float] = []
	for i in range(12):
		await get_tree().process_frame
		if dp._base_layer != null and dp._base_layer.is_inside_tree():
			xs.append(dp._base_layer.position.x)
	print("QAV2 穿戴后 base.x 采样=", xs)
	print("QAV2 无右挫=", xs.size() > 0 and xs.all(func(x: float) -> bool: return abs(x - 140.0) < 0.5))

	# 对照：升级路径 base 也止态（新 base 重建直设）
	(dp._tab_views["skill"] as CanvasItem)
	dp._current_tab = "skill"
	dp.refresh_content(true)
	await get_tree().create_timer(0.3).timeout
	print("QAV2 升级重建后 base_x=", dp._base_layer.position.x, "（期望 140）")
	print("QAV2 DONE")
