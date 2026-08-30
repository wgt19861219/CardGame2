extends Node

## 一次性取证：英雄详情技能升级四修（2026-08-30）。
## ① 技能 tab 视觉四项（底板 9 宫格/图标框尺寸/标签对齐/灰按钮）
## ② 1 级英雄点升级 → Toast「已达到当前等级上限」+ 数据不变
## ③ 注入 level 10 → 重建 → 升级成功路径（等级+1、点数-1、金币扣）

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
	print("QAS hero tid=", hero.tid, " level=", hero.level, " skill_levels=", hero.skill_levels,
		" skill_points=", pd.skill_points, " gold=", pd.hero_manager.gold)

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	# 照 hero_package_panel._on_hero_clicked 同款接线（真实链路消费者在包裹面板）。
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		if dp.perform_upgrade_skill(idx):
			dp.refresh_content())
	dp.show_window(get_tree().current_scene)
	dp._show_tab_content("skill")
	await get_tree().create_timer(0.8).timeout

	# ① 静态视觉证据：board patch / icon frame size / 标签对齐 / 按钮灰态
	var sv: CanvasItem = dp._tab_views["skill"]
	var board: NinePatchRect = sv.get_node("%Skill1Board")
	var icon: TextureButton = sv.get_node("%Skill1Icon")
	var frame: TextureRect = sv.get_node("%Skill1Frame")
	var btn: TextureButton = sv.get_node("%Skill1Btn")
	var cost: Label = sv.get_node("%Skill1Cost")
	print("QAS board patch L/T/R/B=", board.patch_margin_left, board.patch_margin_top,
		board.patch_margin_right, board.patch_margin_bottom, " size=", board.size)
	print("QAS icon size=", icon.size, " frame size=", frame.size, " frame z=", frame.z_index)
	print("QAS btn modulate=", btn.modulate, "(期望灰 100,100,100,180)")
	print("QAS cost align=", cost.horizontal_alignment, "(1=居中) font=", cost.get_theme_font_size(&"font_size"))
	_shot("qa_skill_tab_1lv.png")

	# ② 1 级点升级 → Toast 上限提示 + 数据不变
	Toast._queue.clear()
	btn.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	var toast_text: String = Toast._queue[0] if Toast.pending_count() > 0 else \
		(Toast._current_label.text if Toast._current_label != null else "N/A")
	print("QAS after_cap_click skill_levels[0]=", hero.skill_levels[0], "(期望 1 不变)",
		" points=", pd.skill_points, "(期望不变)",
		" toast=", toast_text, "(期望 已达到当前等级上限)")
	_shot("qa_skill_toast_cap.png")

	# ③ 注入 level 10 重建 → 成功路径
	hero.level = 10
	dp.refresh_content()
	await get_tree().create_timer(0.6).timeout
	var sv2: CanvasItem = dp._tab_views["skill"]
	var btn2: TextureButton = sv2.get_node("%Skill1Btn")
	var gold_before: int = pd.hero_manager.gold
	var pts_before: int = pd.skill_points
	print("QAS lv10 btn modulate=", btn2.modulate, "(期望白 1,1,1,1)")
	btn2.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	print("QAS after_upgrade skill_levels[0]=", hero.skill_levels[0], "(期望 2)",
		" points=", pd.skill_points, "(期望 -1 → ", pts_before - 1, ")",
		" gold=", pd.hero_manager.gold, "(期望 < ", gold_before, ")")
	# 升级成功 → 接线触发 refresh_content 重建，_tab_views 已换新实例（旧引用悬空），重取。
	var sv3: CanvasItem = dp._tab_views["skill"]
	var lvl_lbl: Label = sv3.get_node("%Skill1Lvl")
	print("QAS lvl label=", lvl_lbl.text, "(期望 lv.2)")
	_shot("qa_skill_after_upgrade.png")
	print("QAS DONE")


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev)


func _shot(fname: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://qa_shots/" + fname)
	print("QAS shot saved: ", fname)
