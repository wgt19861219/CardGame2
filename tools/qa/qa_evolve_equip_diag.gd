extends Node

## 复验 v5：最小化复现——fill 后第一个 push 事件即 press 到 icon1 中心。
## 排除 v2/v3 场景序列的 mouse grab 状态污染干扰。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.5).timeout
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.5).timeout
	var btn: BaseButton = dp._base_layer.get_node("%EquipAdvanceBtn") as BaseButton
	btn.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	var view: Control = dp._tab_views["equip"] as Control
	var scroll: ScrollContainer = view.get_node("%EquipScroll") as ScrollContainer
	var row_box: VBoxContainer = view.get_node("%RowContainer") as VBoxContainer
	var first: Control = row_box.get_child(0) as Control
	var icon: Control = null
	for ch in first.get_children():
		if not (ch is Label):
			icon = ch as Control
			break
	var host: Node = scroll.get_node_or_null("__DragHost")
	var ic: Vector2 = icon.get_global_rect().get_center()
	print("QD5 setup icon_rect=", icon.get_global_rect(), " ic=", ic,
		" mf=", icon.mouse_filter, " conns=", icon.gui_input.get_connections().size(),
		" host=", host != null)

	# ① 首事件即 press 到 icon1（无前置污染）
	var evp := InputEventMouseButton.new()
	evp.button_index = MOUSE_BUTTON_LEFT
	evp.pressed = true
	evp.position = ic
	evp.global_position = ic
	get_viewport().push_input(evp)
	await get_tree().process_frame
	await get_tree().process_frame
	print("QD5 after_press meta=", icon.get_meta(&"press_pos", "<无>"), "（期望 Vector2）",
		" host_state=", host.get("state") if host != null else null)

	# ② release 同点 → is_tap → 面板应弹
	var evr := InputEventMouseButton.new()
	evr.button_index = MOUSE_BUTTON_LEFT
	evr.pressed = false
	evr.position = ic
	evr.global_position = ic
	get_viewport().push_input(evr)
	await get_tree().create_timer(0.6).timeout
	var p: Node = _find_panel(get_tree().current_scene)
	print("QD5 tap panel_found=", p != null, "（期望 true）")

	# ③ 拖拽滚动（空白区 press → motion → release）
	var c: Vector2 = scroll.get_global_rect().get_center()
	print("QD5 drag_before sv=", scroll.scroll_vertical)
	var d1 := InputEventMouseButton.new()
	d1.button_index = MOUSE_BUTTON_LEFT
	d1.pressed = true
	d1.position = Vector2(c.x, c.y - 60.0)
	d1.global_position = d1.position
	get_viewport().push_input(d1)
	for i in range(1, 11):
		var m := InputEventMouseMotion.new()
		m.position = Vector2(c.x, c.y - 60.0 + 12.0 * i)
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(m)
		await get_tree().process_frame
	var d2 := InputEventMouseButton.new()
	d2.button_index = MOUSE_BUTTON_LEFT
	d2.pressed = false
	d2.position = Vector2(c.x, c.y + 60.0)
	d2.global_position = d2.position
	get_viewport().push_input(d2)
	await get_tree().create_timer(0.3).timeout
	print("QD5 drag_after sv=", scroll.scroll_vertical, "（期望 >0）",
		" host_state=", host.get("state") if host != null else null)
	print("QD5 DONE")
	get_tree().quit()


func _find_panel(n: Node) -> Node:
	if n is EquipCraftPanel:
		return n
	for ch in n.get_children():
		var r: Node = _find_panel(ch)
		if r != null:
			return r
	return null
