extends Node

## 复验：技能描述浮层翻译（2026-08-30 五轮，用户截图 slot4 显示英文 key）。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.2).timeout
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	hero.rank = 7   # slot 4 解锁

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.4).timeout
	dp._on_tab_pressed("skill")
	await get_tree().create_timer(0.4).timeout

	# 点 slot 4 图标 → 描述浮层（用户截图同款）
	var sv: CanvasItem = dp._tab_views["skill"]
	(sv.get_node("%Skill4Icon") as TextureButton).pressed.emit()
	await get_tree().create_timer(0.3).timeout
	var desc_label: Label = null
	if dp._desc_label != null:
		for c in dp._desc_label.get_children():
			if c is Label:
				desc_label = c as Label
	print("QAD desc_label text=", desc_label.text if desc_label != null else "N/A")
	var has_key: bool = desc_label != null and (desc_label.text.find("SKILL.") >= 0 or desc_label.text.find("SKILLGROUP.") >= 0)
	print("QAD 仍显示英文key=", has_key, "（期望 false）")
	print("QAD 含中文船长=", desc_label != null and desc_label.text.find("船长") >= 0, "（期望 true）")
	_shot("qa_skill_desc_lstr.png")
	print("QAD DONE")


func _shot(fname: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://qa_shots/" + fname)
	print("QAD shot saved: ", fname)
