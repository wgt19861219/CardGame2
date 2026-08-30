extends Node

## 十轮：真实「直接穿戴」全链逐帧录制 + 帧差分析，定位用户看到的侧滑动画区域。
## 链路 = 装备槽点开（背包有件）→ _on_info_pressed puton 分支（wear+save+emit+remove）。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.2).timeout
	DirAccess.make_dir_recursive_absolute("user://qa_shots/qa_wear_frames/")
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	# 背包注入配方件 102（hero1 rank1 槽0 目标）→ 走 puton 直接穿戴分支
	hero.level = 10   # 满足装备等级需求（1 级会被 judge 拦截 Toast 不穿戴）
	pd.add_item(102, 1)

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		if dp.perform_upgrade_skill(idx):
			dp.refresh_content(true))
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.4).timeout
	dp._on_tab_pressed("detail")
	await get_tree().create_timer(0.5).timeout
	var host: Node = get_tree().current_scene

	# 真实开 craft（装备槽同款）
	HeroDetailEquipSlots.open_equip_craft(0, hero, pd.cm, pd, host,
		dp.refresh_content,
		func(stage_id: int) -> void: pass)
	await get_tree().create_timer(0.3).timeout
	var craft: Node = null
	for c in host.get_children():
		if c is EquipCraftPanel:
			craft = c
	print("QAZ craft=", craft != null, " amount102=", pd.items.get(102, 0))

	# 触发与真实 info 按钮完全同款分支（amount>0 未穿 → puton）
	EquipCraftInfoBtn._on_info_pressed(craft)

	# 逐帧录制 0.8s（帧间 0.02s）
	for i in range(40):
		await get_tree().create_timer(0.02).timeout
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("user://qa_shots/qa_wear_frames/f%02d.png" % i)
	print("QAZ 录制完成 40 帧 → user://qa_shots/qa_wear_frames/")
	print("QAZ 穿戴后 equip_slots[0]=", hero.equip_slots[0], " amount102=", pd.items.get(102, 0))
	print("QAZ DONE")
