extends Node
## qa_hpkg_click：卡面名字单行复验（2026-09-10 五轮 A 终验）。停住供 bridge 截图。

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file.call_deferred("res://scenes/hero/hero_scene.tscn")
	await get_tree().create_timer(2.0).timeout
	var panel := _find_panel(get_tree().root)
	if panel == null:
		print("QA FAIL panel not found")
		return
	await get_tree().create_timer(0.3).timeout
	if panel._hero_mgr.heroes.is_empty():
		print("QA FAIL no owned hero")
		return
	var tid: int = (panel._hero_mgr.heroes.values()[0] as HeroInstance).tid
	panel._show_summon_card(tid)
	await get_tree().create_timer(1.2).timeout
	print("QA card shown (名字单行终验停住供截图)")


func _find_panel(node: Node) -> HeroPackagePanel:
	if node is HeroPackagePanel:
		return node
	for c in node.get_children():
		var found: HeroPackagePanel = _find_panel(c)
		if found != null:
			return found
	return null
