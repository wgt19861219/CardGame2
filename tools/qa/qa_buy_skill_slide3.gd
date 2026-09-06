extends Node

## 全保真取证③：子类 tracer 抓 tab 调用序列 + 识别悬停落点控件（2026-08-30）。
## QADetail 覆写 _on_tab_pressed/_show_tab_content/_close_tab/refresh_content/_rebuild_content 打点。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


class QADetail extends HeroDetailPanel:
	func _on_tab_pressed(key: String) -> void:
		print("QAT >>> _on_tab_pressed(", key, ") current=", _current_tab)
		super(key)
	func _show_tab_content(key: String, animate: bool = true) -> void:
		print("QAT >>> _show_tab_content(", key, ")")
		super(key)
	func _close_tab() -> void:
		print("QAT >>> _close_tab current=", _current_tab)
		super()
	func refresh_content() -> void:
		print("QAT >>> refresh_content")
		super()
	func _rebuild_content() -> void:
		print("QAT >>> _rebuild_content")
		super()
	func _on_buy_skill_point() -> void:
		print("QAT >>> _on_buy_skill_point CALLED")
		super()


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.5).timeout
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	pd.skill_points = 0
	pd.skill_cd_time = Time.get_unix_time_from_system()
	var dia_before: int = pd.diamond
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break

	# 手动复刻 hero_package._on_hero_clicked 全部接线（pkg 内部 new 的是原类，无法注入子类）
	var host: Node = get_tree().current_scene
	var dp: QADetail = QADetail.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.shade_close_on_click = false
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		if dp.perform_upgrade_skill(idx):
			dp.refresh_content())
	dp.show_window(host)
	HudOverlay.set_status_visible(false)   # 真实链路等效（pkg→hero_scene.set_bars_visible）
	await get_tree().create_timer(0.6).timeout

	# ① MainScene 子节点序 + 谁是 @Control@426
	print("QAT host children:")
	for c in host.get_children():
		print("QAT   ", c.name, " z=", c.z_index if c is CanvasItem else "-",
			" script=", c.get_script().resource_path if c.get_script() != null else "-")

	# ② 真实点击 TabSkillBtn
	var skill_btn: Button = dp._base_layer.get_node("%TabSkillBtn") as Button
	_click(skill_btn.get_global_rect().get_center())
	await get_tree().create_timer(1.0).timeout
	var sv: CanvasItem = dp._tab_views["skill"]
	var buy_btn: TextureButton = sv.get_node("%BuySkillPointBtn")
	print("QAT state: offset=", sv.offset_left, " current=", dp._current_tab,
		" buy_visible=", buy_btn.visible)

	# ③ 悬停探针（带 rect + 祖先链）
	var center: Vector2 = buy_btn.get_global_rect().get_center()
	_move_mouse(center)
	await get_tree().create_timer(0.2).timeout
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered != null:
		print("QAT hovered=", hovered.get_path(), " rect=", hovered.get_global_rect(), " mf=", hovered.mouse_filter)
		var anc: Node = hovered
		while anc != null and anc != get_tree().root:
			if anc.get_script() != null or not anc.name.begins_with("@"):
				print("QAT   祖先=", anc.name, " script=", anc.get_script() if anc.get_script() != null else "-")
			anc = anc.get_parent()
	else:
		print("QAT hovered=null")

	# ④ 真实点击购买键
	_click(center)
	await get_tree().create_timer(0.6).timeout
	print("QAT buy后 diamond=", pd.diamond, "(前", dia_before, ") points=", pd.skill_points,
		" current=", dp._current_tab, " offset=", sv.offset_left)
	_shot("qa_buy3_after.png")
	print("QAT DONE")


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
	print("QAT shot saved: ", fname)
