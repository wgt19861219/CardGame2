extends Node

## 修复复验（2026-08-30 二轮）：①购买键真实点击可达且执行（钻石梯度扣除+10 点）
## ②升级成功 refresh_content 重建不重播侧滑（止态 -200 保持）。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.5).timeout
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	pd.skill_points = 0
	pd.skill_cd_time = Time.get_unix_time_from_system()
	pd.diamond = 5000
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	hero.level = 10

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		if dp.perform_upgrade_skill(idx):
			dp.refresh_content())
	dp.show_window(get_tree().current_scene)
	HudOverlay.set_status_visible(false)
	await get_tree().create_timer(0.5).timeout
	dp._show_tab_content("skill", false)
	await get_tree().create_timer(0.3).timeout

	var sv: CanvasItem = dp._tab_views["skill"]
	var buy_btn: TextureButton = sv.get_node("%BuySkillPointBtn")
	print("QAV buy mf=", buy_btn.mouse_filter, "(0=STOP 可点) size=", buy_btn.size, " visible=", buy_btn.visible)

	# ① hover 探针：修复后应命中购买键本体
	var center: Vector2 = buy_btn.get_global_rect().get_center()
	_move_mouse(center)
	await get_tree().create_timer(0.2).timeout
	var hovered: Control = get_viewport().gui_get_hovered_control()
	print("QAV hovered=", hovered.get_path() if hovered != null else "null")
	var buy_hit: bool = hovered == buy_btn or (hovered != null and hovered.is_ancestor_of(buy_btn))
	print("QAV 购买键可达=", buy_hit)

	# ② 真实点击（push_input）购买 → 若分发不可信则 emit 兜底验证链路
	var dia_before: int = pd.diamond
	_click(center)
	await get_tree().create_timer(0.4).timeout
	if pd.diamond == dia_before:
		print("QAV push_input 未分发（判例），emit 兜底")
		buy_btn.pressed.emit()
		await get_tree().create_timer(0.4).timeout
	print("QAV 购买后 diamond=", pd.diamond, "(前", dia_before, "，梯度首档扣除) points=", pd.skill_points,
		"(期望 10) reset_times=", pd.skill_reset_times, "(期望 1)")
	var lbl: Label = sv.get_node("%SkillPointLabel")
	print("QAV 信息栏=", lbl.text, " buy_visible=", buy_btn.visible, "(期望 false 已隐藏)")
	_shot("qa_buy_verify.png")

	# ③ 升级成功 → 重建不重播侧滑
	var up_btn: TextureButton = (dp._tab_views["skill"] as CanvasItem).get_node("%Skill1Btn")
	up_btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	var sv3: CanvasItem = dp._tab_views["skill"]
	print("QAV 升级后 skill[0]=", hero.skill_levels[0], "(期望 3) offset=", sv3.offset_left,
		"(期望 -200 无重滑) current=", dp._current_tab)
	var jumped: bool = false
	for i in range(10):
		await get_tree().create_timer(0.05).timeout
		if sv3.is_inside_tree() and abs(sv3.offset_left - (-200.0)) > 1.0:
			jumped = true
	print("QAV 重滑检测=", jumped, "(期望 false)")
	print("QAV DONE")


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
	print("QAV shot saved: ", fname)
