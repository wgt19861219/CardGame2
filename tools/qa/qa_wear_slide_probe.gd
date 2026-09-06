extends Node

## 复现探针（八轮）：真实穿戴全链（open_equip_craft→wear→equipped_changed→remove_window）
## 在 card/skill/equip 三 tab 态下采样 hero_detail tab view offset，验穿装备是否仍触发侧滑。

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

	# 三 tab 态逐一测真实穿戴链
	for tab_key in ["card", "skill", "equip"]:
		dp._on_tab_pressed(tab_key)
		await get_tree().create_timer(0.5).timeout
		var sv_before: CanvasItem = dp._tab_views[tab_key]
		var host: Node = get_tree().current_scene
		# 真实开 craft 面板（detail 装备槽同款）
		HeroDetailEquipSlots.open_equip_craft(0, hero, pd.cm, pd, host,
			dp.refresh_content,
			func(stage_id: int) -> void: pass)
		await get_tree().create_timer(0.3).timeout
		# 找到刚弹的 craft 面板，模拟穿戴成功链（wear+emit+remove 与 info_btn:112-115 同序）
		var craft: Node = null
		for c in host.get_children():
			if c is EquipCraftPanel:
				craft = c
		if craft == null:
			var names: Array[String] = []
			for c in host.get_children():
				names.append(String(c.name))
			print("QAW host children=", names)
		print("QAW [", tab_key, "] craft=", craft != null)
		if craft != null:
			pd.hero_manager.wear_equip(hero.inst_id, 0)
			craft.equipped_changed.emit()
			craft.remove_window()
		# 采样 0.5s（滑入 tween 0.2s，若重播必捕获）
		var s: Array[float] = []
		for i in range(25):
			await get_tree().create_timer(0.02).timeout
			var sv: CanvasItem = dp._tab_views.get(tab_key, null) as CanvasItem
			if sv != null and sv.is_inside_tree():
				s.append(sv.offset_left)
		var max_off: float = s.max() if s.size() > 0 else -999.0
		print("QAW [", tab_key, "] 采样 max=", max_off, "（>-150=有滑入）恒-200=", max_off < -199.0)
		dp._close_tab()
		await get_tree().create_timer(0.3).timeout
	print("QAW DONE")
