extends Node

## 一次性取证：点击「购买技能点」后 tab 重新侧滑（2026-08-30 用户反馈）。
## 疑点：BuySkillPointBtn tscn mouse_filter=2（IGNORE）真实点击打不到按钮本体 → 穿透下方。
## 取证：gui_get_hovered_control 抓真实接收者 + 轮询 TabSkillView.offset_left 捕捉二次侧滑。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.5).timeout
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	pd.skill_points = 0    # 强制购买键可见（用户实况）
	var dia_before: int = pd.diamond
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		if dp.perform_upgrade_skill(idx):
			dp.refresh_content())
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.5).timeout
	dp._show_tab_content("skill")
	await get_tree().create_timer(0.8).timeout

	var sv: CanvasItem = dp._tab_views["skill"]
	var buy_btn: TextureButton = sv.get_node("%BuySkillPointBtn")
	print("QAB buy_btn rect=", buy_btn.get_global_rect(), " mouse_filter=", buy_btn.mouse_filter,
		" visible=", buy_btn.visible)
	print("QAB skill view offset_left=", sv.offset_left, " (期望 -200 已滑入)")
	var view_ref: WeakRef = weakref(sv)

	# ① hover 探针：鼠标移到购买键中心，gui_get_hovered_control 报真实接收者
	var center: Vector2 = buy_btn.get_global_rect().get_center()
	_move_mouse(center)
	await get_tree().create_timer(0.2).timeout
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered != null:
		print("QAB hovered=", hovered.get_path(), " mf=", hovered.mouse_filter,
			" rect=", hovered.get_global_rect())
		if not hovered.is_ancestor_of(buy_btn) and hovered != buy_btn:
			print("QAB *** 购买键不是接收者！穿透到: ", hovered.get_path())
	else:
		print("QAB hovered=null（无控件接收）")

	# ② 真实点击购买键（press+release push_input）+ 0.8s 内轮询 offset 捕捉二次侧滑
	_click(center)
	var slid_again: bool = false
	for i in range(16):
		await get_tree().create_timer(0.05).timeout
		if sv.is_inside_tree() and not slid_again:
			if abs(sv.offset_left - (-200.0)) > 1.0:
				slid_again = true
				print("QAB *** 检测到二次侧滑！offset_left=", sv.offset_left, " t+", (i + 1) * 0.05, "s")
		elif not sv.is_inside_tree():
			print("QAB *** skill view 已被移出树（重建/关闭）t+", (i + 1) * 0.05, "s")
			break
	print("QAB after_click slid_again=", slid_again,
		" view_alive=", view_ref.get_ref() != null and (view_ref.get_ref() as Node).is_inside_tree(),
		" current_tab=", dp._current_tab)
	print("QAB diamond=", pd.diamond, "(前 ", dia_before, "，不变=购买没执行)", " skill_points=", pd.skill_points)
	_shot("qa_buy_slide_after.png")
	print("QAB DONE")


func _move_mouse(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev)


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
	print("QAB shot saved: ", fname)
