extends Node

## 一次性取证：竞技场防守阵容头像相对槽/底框位置（readhero 83 波及验证；免 bridge）。

const LadderPanel = preload("res://scripts/ui/ladder_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	# 保底阵容（无队伍时前 5 英雄）
	if pd.team.is_empty():
		for inst_id in pd.hero_manager.heroes.keys():
			pd.team.append(inst_id)
			if pd.team.size() >= 5:
				break
	await get_tree().create_timer(1.5).timeout
	var panel = LadderPanel.new("ladder", {})
	panel.setup_panel(pd, pd.cm, BattleRng.new(7))
	panel.show_window(get_tree().current_scene)
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	img.save_png("user://qa_shots/ladder_r1.png")
	print("QA_LADDER shot ok")
	# dump 防守阵容槽与头像 rect
	for i in range(5):
		var slot: Control = null
		for view in panel._rank_views.values():
			var s: Control = view.get_node_or_null("%HeroSlot" + str(i + 1)) as Control
			if s != null and s.is_visible_in_tree():
				slot = s
				break
		if slot == null:
			continue
		var head: Node = slot.get_child(0) if slot.get_child_count() > 0 else null
		var ri: Node = head.get_child(0) if head != null and head.get_child_count() > 0 else null
		var line: String = "QA_LADDER slot%d global=%s size=%s" % [i + 1, slot.global_position, slot.size]
		if ri != null and ri.get("frame") != null:
			var fr: Node2D = ri.get("frame")
			var oi: Node2D = ri.get("ori_icon")
			line += " | head_origin=%s frame.g=%s disp=%s portrait.g=%s" % [
				head.global_position if head is Node2D else "-",
				fr.global_position, fr.texture.get_size() * fr.scale.x if fr.texture != null else "-",
				oi.global_position if oi != null else "-"]
		print(line)
	print("QA_LADDER DONE")
	get_tree().quit()
