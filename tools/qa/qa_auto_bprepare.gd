extends Node

## 一次性自动取证（战前布阵三修验证 2026-08-30：列表竖滚/tab 不被列表盖/头像进框）。
## install_override 装载 → 启动自动：注入 12 英雄 → 直接构造 BattlePreparePanel 挂 root →
## 等 fill → 截图 + dump ListScroll 滚动范围/tab rect/MemberBg+头像 rect → 竖滚一屏再取证。

const GmManager = preload("res://scripts/systems/gm_manager.gd")
const BattlePreparePanelScript = preload("res://scripts/view/battle/battle_prepare_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	if pd == null:
		push_error("QA_AUTO: player null")
		return
	pd.tutorial_manager.skip_all()
	pd.team_level = 99
	_fill_heroes(pd)
	await get_tree().create_timer(1.0).timeout
	var rng := BattleRng.new(12345)
	var panel: Control = BattlePreparePanelScript.new()
	panel.setup(1, pd, pd.stage_manager, rng, pd.cm)
	get_tree().root.add_child(panel)
	await get_tree().create_timer(2.5).timeout   # 等 fill + deferred
	_shot_and_dump(panel, "auto_bprepare_r1")
	# 竖滚一屏再取证（验证纵向滚动生效）
	var scroll: ScrollContainer = panel.get_node_or_null("BattlePrepareContent/ListScroll") as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 150
		await get_tree().create_timer(0.5).timeout
	_shot_and_dump(panel, "auto_bprepare_r2")
	print("QA_AUTO: DONE")


func _fill_heroes(pd: Variant) -> void:
	var cm: Variant = pd.cm
	GmManager.execute(pd, cm, {"_get_all_heroes": 1})
	var hero_list: Array = []
	var tids: Array = cm.get_raw_table("Unit").keys()
	var given_rank: Array = [3, 4, 5]
	var n_set: int = 0
	for tid_str in tids:
		var row: Dictionary = cm.get_raw_table("Unit")[tid_str]
		if String(row.get("Unit Type", "")) == "Hero" and row.has("Portrait"):
			hero_list.append({
				"_tid": int(tid_str),
				"_rank": int(given_rank[n_set % given_rank.size()]),
				"_level": 37,
				"_stars": 3,
			})
			n_set += 1
			if n_set >= 12:
				break
	if not hero_list.is_empty():
		GmManager.execute(pd, cm, {"_set_hero_info": hero_list})


func _shot_and_dump(panel: Control, tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null:
		DirAccess.make_dir_recursive_absolute("user://qa_shots/")
		var err := img.save_png("user://qa_shots/" + tag + ".png")
		print("QA_AUTO shot ", tag, " err=", err)
	var scroll: ScrollContainer = panel.get_node_or_null("BattlePrepareContent/ListScroll") as ScrollContainer
	if scroll == null:
		print("QA_AUTO: no ListScroll")
		return
	# 1) 滚动方向：横向 range 恒 0（禁用），纵向可滚（12 英雄 3 行 > 视口 295）
	print("QA_AUTO scroll.global=", scroll.global_position, " size=", scroll.size,
		" scrollX=", scroll.scroll_horizontal, " scrollY=", scroll.scroll_vertical,
		" h_mode=", scroll.horizontal_scroll_mode,
		" maxScrollY=", scroll.get_v_scroll_bar().max_value)
	# 2) tab 按钮 rect（应不被列表盖：视口右缘 640 < tab 左缘 655.7）
	var tab_keys: Array = ["TabAllBtn", "TabFrontBtn", "TabMiddleBtn", "TabBackBtn"]
	for tk in tab_keys:
		var tb: Control = panel.get_node_or_null("BattlePrepareContent/" + tk) as Control
		if tb != null:
			var tbtn := tb as TextureButton
			var st := tbtn.stretch_mode
			var its := tbtn.ignore_texture_size
			var tn: Texture2D = tbtn.texture_normal
			print("QA_AUTO ", tk, " global=", tb.global_position, " size=", tb.size,
				" z=", tb.z_index, " visible=", tb.is_visible_in_tree(),
				" stretch_mode=", st, " ignore_tex_size=", its,
				" tex_px=", tn.get_size() if tn != null else Vector2.ZERO)
	var bb: TextureButton = panel.get_node_or_null("BattlePrepareContent/BackBtn") as TextureButton
	if bb != null:
		var btn2: Texture2D = bb.texture_normal
		print("QA_AUTO BackBtn global=", bb.global_position, " size=", bb.size,
			" stretch_mode=", bb.stretch_mode, " ignore_tex_size=", bb.ignore_texture_size,
			" tex_px=", btn2.get_size() if btn2 != null else Vector2.ZERO)
	# 3) 头像框 + 头像 rect（MemberBg 与其内 ReadheroIcon 的视觉关系）
	for i in range(5):
		var slot: Control = panel.get_node_or_null("BattlePrepareContent/MemberBg" + str(i + 1)) as Control
		if slot == null:
			continue
		var icon_node: Node2D = null
		for c in slot.get_children():
			# slot 下 Node2D 仅 ReadheroIcon（Halo 是 TextureRect/Control，is Node2D=false）
			if c is Node2D:
				icon_node = c as Node2D
				break
		var slot_g: Vector2 = slot.global_position
		var line := "QA_AUTO slot" + str(i + 1) + " global=(" + str(slot_g.x) + "," + str(slot_g.y) + ") size=" + str(slot.size)
		if icon_node == null:
			line += " icon=NULL"
		else:
			var portrait: Node2D = icon_node.get("ori_icon")
			var p_disp: Vector2 = portrait.texture.get_size() / 1.28125 if portrait != null and portrait is Sprite2D and (portrait as Sprite2D).texture != null else Vector2.ZERO
			var p_center_g: Vector2 = icon_node.global_position + Vector2(39.0, 65.0)
			var slot_center_g: Vector2 = slot_g + slot.size * 0.5
			line += " icon.pos=" + str(icon_node.position) + " portrait_center=(" + str(p_center_g.x) + "," + str(p_center_g.y) + ")" \
				+ " slot_center=(" + str(slot_center_g.x) + "," + str(slot_center_g.y) + ")" \
				+ " delta=(" + str(p_center_g.x - slot_center_g.x) + "," + str(p_center_g.y - slot_center_g.y) + ")" \
				+ " p_disp=" + str(p_disp)
		print(line)
