extends Node

## 全保真取证②：购买键点击链 + 升级成功后 refresh_content 重建是否重跑侧滑（2026-08-30）。
## 与 qa_buy_skill_slide.gd 差异：①走 hero_package._on_hero_clicked 真实入口（含 set_bars_visible(false)）
## ②skill_cd_time=now 锁死 recover 保持购买键可见 ③真实点击开 tab ④宽谱监测（offset/新窗口/identity/shortcut）。

const HeroPackagePanel = preload("res://scripts/ui/hero_package_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.5).timeout
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	# 锁死 recover：cd_time=now → dt=0 不恢复，保证 skill tab 打开时购买键可见
	pd.skill_points = 0
	pd.skill_cd_time = Time.get_unix_time_from_system()
	var dia_before: int = pd.diamond
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break

	# 真实入口：hero_package 打开 detail（内部 set_bars_visible(false) + 信号接线全真）
	var pkg: Node = HeroPackagePanel.new("heropackage", {})
	var host: Node = get_tree().current_scene
	pkg.setup_panel(pd.hero_manager, pd.cm, pd)
	pkg.show_window(host)
	await get_tree().create_timer(0.3).timeout
	pkg._on_hero_clicked(hero)
	await get_tree().create_timer(0.4).timeout

	# 找 HeroDetailPanel（pkg 弹出的）
	var dp: Node = null
	for c in host.get_children():
		if c.get_script() == HeroPackagePanel and c != pkg:
			continue
	for c in host.get_children():
		if c.has_method("perform_upgrade_skill"):
			dp = c
	print("QAB2 detail panel=", dp != null, " bars_visible 前=", HudOverlay.get_node_or_null("@Panel@211") != null)
	if dp == null:
		print("QAB2 FAIL 未找到 detail")
		return
	HudOverlay.set_status_visible(false)   # 真实链路 pkg 已做，双保险（QA host 非 hero_scene 时补）

	# 真实点击 TabSkillBtn 开技能 tab
	var skill_btn: Button = dp._base_layer.get_node("%TabSkillBtn") as Button
	var sb_center: Vector2 = skill_btn.get_global_rect().get_center()
	print("QAB2 TabSkillBtn global=", skill_btn.get_global_rect(), " base_pos=", dp._base_layer.position)
	_click(sb_center)
	await get_tree().create_timer(0.8).timeout
	var sv: CanvasItem = dp._tab_views["skill"]
	var buy_btn: TextureButton = sv.get_node("%BuySkillPointBtn")
	print("QAB2 buy_btn rect=", buy_btn.get_global_rect(), " mf=", buy_btn.mouse_filter, " visible=", buy_btn.visible)
	print("QAB2 offset_left=", sv.offset_left, " current_tab=", dp._current_tab)
	_shot("qa_buy2_skill_tab.png")

	# ① hover 探针（状态条已藏）：真实接收者
	var center: Vector2 = buy_btn.get_global_rect().get_center()
	_move_mouse(center)
	await get_tree().create_timer(0.2).timeout
	var hovered: Control = get_viewport().gui_get_hovered_control()
	print("QAB2 hovered=", hovered.get_path() if hovered != null else "null",
		" mf=", hovered.mouse_filter if hovered != null else "-")

	# ② 真实点击购买键 + 宽谱监测 1.2s
	_click(center)
	await _watch_slide(dp, sv, "buy_click")
	print("QAB2 buy后 diamond=", pd.diamond, "(前", dia_before, ") points=", pd.skill_points,
		" current_tab=", dp._current_tab)
	_shot("qa_buy2_after_buy.png")

	# ③ 升级成功路径：注入 lv10 后真实点 Skill1Btn，验证 refresh_content 重建重跑侧滑
	hero.level = 10
	dp.refresh_content()
	await get_tree().create_timer(0.6).timeout
	var sv2: CanvasItem = dp._tab_views["skill"]
	var up_btn: TextureButton = sv2.get_node("%Skill1Btn")
	print("QAB2 升级前 offset_left=", sv2.offset_left, "（重建后应已 -200 止态）")
	_click(up_btn.get_global_rect().get_center())
	await _watch_slide(dp, sv2, "upgrade_click")
	print("QAB2 升级后 skill_levels[0]=", hero.skill_levels[0], " current_tab=", dp._current_tab)
	_shot("qa_buy2_after_upgrade.png")
	print("QAB2 DONE")


func _watch_slide(dp: Node, sv: CanvasItem, tag: String) -> void:
	## 1.2s 内轮询：offset 偏离 -200 = 二次侧滑；树内 PopWindow 数变化 = 新窗口弹出
	var windows_before: int = _count_windows()
	for i in range(24):
		await get_tree().create_timer(0.05).timeout
		if sv.is_inside_tree() and abs(sv.offset_left - (-200.0)) > 1.0:
			print("QAB2 *** [", tag, "] 二次侧滑！t+", (i + 1) * 0.05, "s offset=", sv.offset_left)
			while sv.is_inside_tree() and abs(sv.offset_left - (-200.0)) > 1.0:
				await get_tree().create_timer(0.05).timeout
			print("QAB2 [", tag, "] 侧滑止态 offset=", sv.offset_left)
			break
		if not sv.is_inside_tree():
			print("QAB2 [", tag, "] view 重建（旧实例出树）t+", (i + 1) * 0.05, "s")
			var nv: CanvasItem = dp._tab_views["skill"]
			if nv != null:
				print("QAB2 [", tag, "] 新 view offset=", nv.offset_left, "（400=重跑滑入动画）")
			sv = nv
	var windows_after: int = _count_windows()
	if windows_after != windows_before:
		print("QAB2 [", tag, "] 窗口数 ", windows_before, "→", windows_after, "（有新弹窗/关闭）")


func _count_windows() -> int:
	var n: int = 0
	for c in get_tree().root.get_children():
		if c is CanvasLayer or c.get_child_count() > 0:
			n += 1
	return get_tree().root.get_child_count()


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
	print("QAB2 shot saved: ", fname)
