extends Node

## 一次性取证：装备进阶列表（TAB_EQUIP 侧滑）。
## ① EquipAdvanceBtn 存在+rect ② 点击→TabEquipView 滑出（visible/-200/行数/base 右移 140）
## ③ 行结构（S9 行根 + 1 label + 6 icon） ④ 再点同按钮关闭（toggle） ⑤ 截图存 user://qa_shots/。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.5).timeout
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.5).timeout

	# ① 按钮存在 + rect
	var btn: BaseButton = dp._base_layer.get_node("%EquipAdvanceBtn") as BaseButton
	print("QEV btn rect=", btn.get_global_rect(), " visible=", btn.visible)

	# ② 点击 → equip tab 滑出（0.2s tween 后止态 -200；base 右移 140）
	btn.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	var view: Control = dp._tab_views["equip"] as Control
	var row_box: VBoxContainer = view.get_node("%RowContainer") as VBoxContainer
	print("QEV open visible=", view.visible, " offset_left=", view.offset_left,
		" rows=", row_box.get_child_count(), " base_x=", dp._base_layer.position.x)

	# ③ 行结构：S9 行根 + 7 子（1 rank Label + 6 icon）
	var first: Node = row_box.get_child(0)
	print("QEV row0 class=", first.get_class(), " children=", first.get_child_count())

	# ⑤ 截图（滑出态）
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://qa_shots/qa_evolve_equip_open.png")

	# ④ 再点同按钮 → 关（toggle；base 回 0）
	btn.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	print("QEV close visible=", view.visible, " base_x=", dp._base_layer.position.x)
	print("QEV DONE")
	get_tree().quit()
