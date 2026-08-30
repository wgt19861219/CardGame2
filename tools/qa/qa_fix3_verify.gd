extends Node

## 一次性三页复验（ladder 头像居中/crusade 敌方弹窗/estren HUD 隐藏；免 bridge 自动截图+dump）。

const LadderPanel = preload("res://scripts/ui/ladder_panel.gd")
const MainSceneEntryRouter = preload("res://scripts/ui/main_scene_entry_router.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	if pd.team.is_empty():
		for inst_id in pd.hero_manager.heroes.keys():
			pd.team.append(inst_id)
			if pd.team.size() >= 5:
				break
	await get_tree().create_timer(1.5).timeout
	var scene: Node = get_tree().current_scene
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	# 1) ladder
	var lp = LadderPanel.new("ladder", {})
	lp.setup_panel(pd, pd.cm, BattleRng.new(7))
	lp.show_window(scene)
	await get_tree().create_timer(0.8).timeout
	var slot: Control = null
	for v in lp._rank_views.values():
		var s: Control = (v as Control).get_node_or_null("%HeroSlot1") as Control
		if s != null and s.is_visible_in_tree():
			slot = s
			break
	if slot != null and slot.get_child_count() > 0:
		var head: Node2D = slot.get_child(0) as Node2D
		var fr: Node2D = head.get("frame") as Node2D
		print("QA3 ladder slot=", slot.global_position, " head_pos=", head.position,
			" frame_center_local=", fr.global_position - slot.global_position,
			" slot_center=", slot.size * 0.5)
	get_viewport().get_texture().get_image().save_png("user://qa_shots/fix3_ladder.png")
	lp.remove_window()
	await get_tree().create_timer(0.3).timeout
	HudOverlay.apply_identity("main")
	# 2) crusade 弹窗
	var cp = load("res://scripts/ui/crusade_panel.gd").new("crusade", {})
	cp.setup_panel(pd, BattleRng.new(7))
	cp.show_window(scene)
	await get_tree().create_timer(0.8).timeout
	cp._on_stage_n(1)
	await get_tree().create_timer(0.5).timeout
	print("QA3 crusade battle_layer.visible=", cp.battle_layer.visible,
		" name=", cp._bl_name_lbl.text, " cur=", cp._bl_cur_lbl.text,
		" start_visible=", cp._bl_start.visible)
	get_viewport().get_texture().get_image().save_png("user://qa_shots/fix3_crusade.png")
	cp.remove_window()
	await get_tree().create_timer(0.3).timeout
	HudOverlay.apply_identity("main")
	# 3) estren HUD 隐藏
	MainSceneEntryRouter.open_equip_strengthen(scene)
	await get_tree().create_timer(0.8).timeout
	var hud_panel: Node = HudOverlay.get_node_or_null("Panel")
	# HudOverlay 内部容器可见性（identity 隐藏后 main 版应不可见）
	var hud_vis: bool = false
	for c in HudOverlay.get_children():
		if c is Control and (c as Control).visible:
			hud_vis = true
	print("QA3 estren hud_any_visible=", hud_vis, "（期望 false）")
	get_viewport().get_texture().get_image().save_png("user://qa_shots/fix3_estren.png")
	print("QA3 DONE")
