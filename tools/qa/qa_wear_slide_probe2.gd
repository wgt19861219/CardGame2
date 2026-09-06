extends Node

## 九轮复现：detail（属性页装备槽入口）真实穿戴宽谱采样（四 view offset + base 层 + craft 面板）。

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

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		if dp.perform_upgrade_skill(idx):
			dp.refresh_content())
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.4).timeout

	# 用户入口：detail（属性）tab → 装备槽
	dp._on_tab_pressed("detail")
	await get_tree().create_timer(0.5).timeout
	var host: Node = get_tree().current_scene
	HeroDetailEquipSlots.open_equip_craft(0, hero, pd.cm, pd, host,
		dp.refresh_content,
		func(stage_id: int) -> void: pass)
	await get_tree().create_timer(0.3).timeout
	var craft: Node = null
	for c in host.get_children():
		if c is EquipCraftPanel:
			craft = c
	print("QAY craft=", craft != null, " detail offset=", (dp._tab_views["detail"] as CanvasItem).offset_left)

	pd.hero_manager.wear_equip(hero.inst_id, 0)
	craft.equipped_changed.emit()
	craft.remove_window()

	# 宽谱采样 0.7s：四 view offset 峰值 + base position + 新弹节点
	var peaks: Dictionary = {}
	for k in ["card", "detail", "skill", "equip"]:
		peaks[k] = -999.0
	var base_peak: float = -999.0
	for i in range(35):
		await get_tree().create_timer(0.02).timeout
		for k in peaks:
			var sv: CanvasItem = dp._tab_views.get(k, null) as CanvasItem
			if sv != null and sv.is_inside_tree():
				peaks[k] = max(peaks[k], sv.offset_left)
		if dp._base_layer != null and dp._base_layer.is_inside_tree():
			base_peak = max(base_peak, dp._base_layer.position.x)
	print("QAY 各view offset峰值=", peaks, "（>-150=该 view 重播了滑入）")
	print("QAY base层 x峰值=", base_peak, "（应为 140 不再右移）")
	print("QAY current_tab=", dp._current_tab)
	print("QAY DONE")
