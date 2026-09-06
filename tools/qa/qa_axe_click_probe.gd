extends Node

## 十一轮：点击装备槽「补刀斧」（槽5，已穿）后 detail 面板滑一下——tracer+hover+点击+offset 采样复现。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


class QADetail extends HeroDetailPanel:
	func _on_tab_pressed(key: String) -> void:
		print("QAB >>> _on_tab_pressed(", key, ") current=", _current_tab)
		super(key)
	func _show_tab_content(key: String, animate: bool = true) -> void:
		print("QAB >>> _show_tab_content(", key, ", animate=", animate, ")")
		super(key, animate)
	func _close_tab() -> void:
		print("QAB >>> _close_tab（tab 关闭！base 回位）")
		super()
	func refresh_content() -> void:
		print("QAB >>> refresh_content")
		super()


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.2).timeout
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	hero.level = 10
	hero.rank = 1
	# 槽 4（Equip5=108 补刀斧）穿上 → 点击已穿图标路径
	pd.hero_manager.wear_equip(hero.inst_id, 4)
	print("QAB 槽5(下标4) equip=", hero.equip_slots[4], "（108=补刀斧）")

	var dp: QADetail = QADetail.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.4).timeout
	dp._on_tab_pressed("detail")
	await get_tree().create_timer(0.5).timeout

	# 槽 5 图标定位（挂 %EquipSlot5 下 icon）
	var slot5: TextureRect = dp._base_layer.get_node("%EquipSlot5") as TextureRect
	var center: Vector2 = slot5.get_global_rect().get_center()
	print("QAB 槽5 rect=", slot5.get_global_rect(), " center=", center)
	var icon: Node = slot5.get_child(0) if slot5.get_child_count() > 0 else null
	if icon != null:
		print("QAB 槽5 icon=", icon.name, " mf=", (icon as Control).mouse_filter if icon is Control else "-")

	# hover 探针：真实命中的是谁
	_move_mouse(center)
	await get_tree().create_timer(0.2).timeout
	var hovered: Control = get_viewport().gui_get_hovered_control()
	print("QAB hovered=", hovered.get_path() if hovered != null else "null",
		" mf=", hovered.mouse_filter if hovered != null else "-")

	# 点击 → tracer 打点 + offset 采样
	_click(center)
	var samples: Array[float] = []
	for i in range(12):
		await get_tree().process_frame
		var dv: CanvasItem = dp._tab_views["detail"] as CanvasItem
		if dv != null and dv.is_inside_tree():
			samples.append(dv.offset_left)
	print("QAB detail offset 采样=", samples)
	print("QAB current_tab=", dp._current_tab, " base_x=", dp._base_layer.position.x)
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
