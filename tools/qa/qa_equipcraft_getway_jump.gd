extends Node

## 一次性取证 v10：真实 HeroScene 场景（SceneManager 切换）完整链路截图——
## 跳选关 → 点关 27 进详情（战斗准备页 A）→ 点开战进布阵页（战斗准备页 B）。
## 用户报「战斗准备页面底下关卡的标题透过来了」——HeroScene 环境视觉取证。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")
const HeroDetailEquipSlots = preload("res://scripts/ui/hero_detail_equip_slots.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	await get_tree().create_timer(1.5).timeout
	var pd: Variant = GameData.player
	# 真切 HeroScene（还原用户入口拓扑）
	SceneManager.change_scene("res://scenes/hero/hero_scene.tscn")
	await get_tree().create_timer(1.2).timeout
	var hs: Node = get_tree().current_scene
	print("QAJ scene=", hs.name)
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		if int(hero.tid) == 2:
			break
	# hero_detail → ecp(119) → 点 103 → 板 27 → ss → 点关 27
	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.show_window(hs)
	await get_tree().process_frame
	var ecp: Node = load("res://scripts/ui/equip_craft_panel.gd").new("equipcraft", {})
	ecp.setup_panel(119, pd.cm, pd, hero, "heroDetail", 0)
	ecp.jump_to_stage.connect(func(sid: int) -> void: HeroDetailEquipSlots.on_equip_craft_jump(sid, dp))
	ecp.show_window(hs)
	await get_tree().process_frame
	ecp._open_craft_panel()
	await get_tree().process_frame
	var children: Array = ecp._tree_data.get("children", [])
	var nodeid: Array = ecp._craft_window_data.get("nodeid", [])
	await _real_click(children[nodeid.find(103)])
	await get_tree().create_timer(0.3).timeout
	await _real_click(ecp._get_way_buttons[0])
	await get_tree().create_timer(0.8).timeout
	var ss: StageSelectPanel = null
	for c in hs.get_children():
		if c is StageSelectPanel:
			ss = c
			break
	if ss == null:
		print("QAJ no ss, DONE")
		return
	print("QAJ ss z=", ss.z_index, " chapter=", ss._current_chapter)
	await _real_click(ss._stage_buttons[27])
	await get_tree().create_timer(1.0).timeout
	var detail: StageDetailPanel = null
	for c in hs.get_children():
		if c is StageDetailPanel:
			detail = c
			break
	print("QAJ detail=", detail != null, " z=", detail.z_index if detail != null else "-")
	await _shot("getway_hs_detail.png")
	# 点开战 → battle_prepare（布阵页）
	if detail != null:
		var go: BaseButton = detail._content.get_node_or_null("%GoButton") as BaseButton
		if go == null:
			for c in (detail._content as Control).get_children():
				if c is BaseButton:
					go = c
					break
		print("QAJ go_btn=", go != null)
		if go != null:
			await _real_click(go)
			await get_tree().create_timer(1.2).timeout
			for c in hs.get_children():
				if "battle_prepare" in str(c.name).to_lower() or c.get_class() == "Control":
					pass
			await _shot("getway_hs_bprepare.png")
	print("QAJ DONE")


func _shot(fname: String) -> void:
	var img: Image = await get_viewport().get_texture().get_image()
	img.save_png("user://qa_shots/" + fname)
	print("QAJ shot=", fname)


func _real_click(ctrl: Control) -> void:
	var win_pos: Vector2 = get_viewport().get_final_transform() * ctrl.get_global_rect().get_center()
	print("QAJ click canvas=", ctrl.get_global_rect().get_center())
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = win_pos
		ev.global_position = win_pos
		get_viewport().push_input(ev)
		await get_tree().process_frame
