extends Node

## 复验（六轮）：①描述浮层位置随槽（点 slot4 浮层在 slot4 行旁非首行）②成长行中文。

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
	hero.rank = 7

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.4).timeout
	dp._on_tab_pressed("skill")
	await get_tree().create_timer(0.4).timeout

	var sv: CanvasItem = dp._tab_views["skill"]
	# 点 slot 4（力量强化，首行最下）→ 浮层应在 slot4 行旁（y≈363）非首行（y≈93）
	(sv.get_node("%Skill4Icon") as TextureButton).pressed.emit()
	await get_tree().create_timer(0.3).timeout
	var board: Control = dp._desc_label
	print("QAE slot4 浮层 position=", board.position, "（期望 x=525, y=93+90×3=363）")
	var lbl: Label = null
	for c in board.get_children():
		if c is Label:
			lbl = c as Label
	print("QAE slot4 文本=", lbl.text.replace(char(10), " / "))
	print("QAE 位置随槽=", abs(board.position.x - 525.0) < 1.0 and abs(board.position.y - 363.0) < 1.0)
	print("QAE 成长行中文=", lbl.text.find("被动：增加") >= 0)
	_shot("qa_desc_pos_slot4.png")

	# 对照：点 slot 1（幽灵船）→ 浮层回 y=93 且是幽灵船内容
	dp._toggle_skill_desc(3)   # 先关
	await get_tree().create_timer(0.2).timeout
	(sv.get_node("%Skill1Icon") as TextureButton).pressed.emit()
	await get_tree().create_timer(0.3).timeout
	var board1: Control = dp._desc_label
	var lbl1: Label = null
	for c in board1.get_children():
		if c is Label:
			lbl1 = c as Label
	print("QAE slot1 浮层 position=", board1.position, "（期望 x=525, y=93）")
	print("QAE slot1 文本含幽灵船相关=", lbl1.text.find("幽灵船") >= 0 or lbl1.text.find("鬼船") >= 0 or lbl1.text.find("船长") >= 0)
	_shot("qa_desc_pos_slot1.png")
	print("QAE DONE")


func _shot(fname: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://qa_shots/" + fname)
	print("QAE shot saved: ", fname)
