extends Node

## 一次性取证（2026-08-30）：详细属性 tab 分节标题装饰条叠放修复验证。
## 断言：标题行单行 CenterContainer，mark 与 label 中心重合（旧结构装饰在标题顶上）。
## 用法：install_override 注入后 Bash 直启游戏，看 stdout QAAT 输出 + qa_shots 截图。

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
	dp._on_tab_pressed("detail")
	await get_tree().create_timer(1.0).timeout
	var detail: Control = dp._tab_views["detail"] as Control
	var vbox: VBoxContainer = detail.get_node("%AttribVBox") as VBoxContainer
	# 稳定布局：连续等帧直到尺寸不变
	var prev_size: Vector2 = vbox.size
	for i in 10:
		await get_tree().process_frame
		if vbox.size == prev_size:
			break
		prev_size = vbox.size
	await get_tree().process_frame
	print("QAAT vbox_global=", vbox.get_global_rect(), " size=", vbox.size)
	var idx: int = 0
	for row in vbox.get_children():
		var mark: TextureRect = null
		var lbl: Label = null
		for c in row.get_children():
			if c is TextureRect and (c as TextureRect).texture != null \
					and (c as TextureRect).texture.resource_path.contains("title-mark"):
				mark = c as TextureRect
			elif c is Label and (c as Label).text in ["英雄介绍", "英雄简介", "英雄属性"]:
				lbl = c as Label
		if mark != null and lbl != null:
			# 同帧打印全局 rect（viewport 800x480 逻辑坐标）
			var mgr: Rect2 = mark.get_global_rect()
			var lgr: Rect2 = lbl.get_global_rect()
			print("QAAT row", idx, " lbl=", lbl.text,
				" mark_gr=", mgr, " mark_center=", mgr.get_center(),
				" lbl_gr=", lgr, " lbl_center=", lgr.get_center(),
				" center_d=", mgr.get_center() - lgr.get_center())
		idx += 1
	# 同帧截图（不再等 0.3s）
	get_viewport().get_texture().get_image().save_png("user://qa_shots/qa_attribs_title.png")
	print("QAAT shot=user://qa_shots/qa_attribs_title.png")
	get_tree().quit()
