extends Node

## 一次性取证：英雄详情翻页箭头缺失（用户 2026-09-09 反馈）。
## 读默认打开态（card tab）下 BaseLayer 位移与左右箭头 visible/局部/全局位置，
## 判定缺失形式：visible=false（数据链）vs 出屏（坐标链）。

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
	await get_tree().create_timer(1.0).timeout
	print("QAA hero_count=", dp._hero_ids.size(), " current_tab=", dp._current_tab)
	var base: CanvasItem = dp._base_layer as CanvasItem
	print("QAA BaseLayer pos=", base.position, " (tab 态期望 x=140)")
	for arrow_name in ["%LeftArrow", "%RightArrow"]:
		var arrow: CanvasItem = base.get_node(arrow_name) as CanvasItem
		print("QAA ", arrow_name,
			" visible=", arrow.visible,
			" local_pos=", arrow.position,
			" global_pos=", arrow.global_position,
			" global_rect=", arrow.get_global_rect())
	# 各 tab 面板 global rect（右箭头 tab 态落点依据：面板右缘外、屏内）。
	# % 唯一名查找从 content 根（= BaseLayer.get_parent()）出发
	var content_root: Node = base.get_parent()
	var panels: Dictionary = {
		"card": "%TabCardView/CardFrame",
		"detail": "%TabDetailView/PopupBg",
		"skill": "%TabSkillView/PopupBg",
		"equip": "%TabEquipView/PanelBg",
	}
	for tab_key in panels:
		var panel: CanvasItem = content_root.get_node(str(panels[tab_key])) as CanvasItem
		print("QAA panel[", tab_key, "] visible=", panel.visible,
			" global_rect=", panel.get_global_rect())
	print("QAA 屏宽 800，global_rect 越界即出屏")
	# 点击链路取证：mouse_filter=2(IGNORE) 的按钮收不到输入 → pressed 永不发 → 翻页无反应。
	var l: TextureButton = base.get_node("%LeftArrow") as TextureButton
	var r: TextureButton = base.get_node("%RightArrow") as TextureButton
	var before_id: int = int(dp.hero.inst_id)
	print("QAA arrow mouse_filter l=", l.mouse_filter, " r=", r.mouse_filter, " (0=STOP 可点, 2=IGNORE 穿透)")
	print("QAA pressed connections l=", l.pressed.get_connections().size(), " (≥1=已连翻页回调)")
	var got_gui_input: Array[String] = []
	l.gui_input.connect(func(ev: InputEvent) -> void:
		got_gui_input.append(str(ev)))
	# push_input 直推 viewport 不走窗口管线（坐标原样消费）——与真实输入不同源。
	_click(l.get_global_rect().get_center())
	await get_tree().create_timer(0.4).timeout
	print("QAA after_push_input_click gui_input_events=", got_gui_input.size(),
		" hero_id ", before_id, " -> ", int(dp.hero.inst_id))
	if int(dp.hero.inst_id) == before_id:
		print("QAA push_input 未生效，手动 emit pressed 隔离信号链")
		l.pressed.emit()
		await get_tree().create_timer(0.4).timeout
		print("QAA after_manual_emit hero_id ", before_id, " -> ", int(dp.hero.inst_id),
			" (变化=信号链通)")
	# 真实输入管线注入（parse_input_event 走窗口→stretch→gui 分发；
	# 判例：坐标=窗口物理像素=视口逻辑×2）。emit 翻页触发 _rebuild_content 重建，
	# 旧箭头引用已 free，须重取。
	var win := get_window()
	var r_now: TextureButton = (dp._base_layer as CanvasItem).get_node("%RightArrow") as TextureButton
	var phys: Vector2 = r_now.get_global_rect().get_center() * Vector2(win.size) / Vector2(win.content_scale_size)
	var id_before_real: int = int(dp.hero.inst_id)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = phys
		Input.parse_input_event(ev)
	await get_tree().create_timer(0.5).timeout
	print("QAA after_real_pipeline_click(right) hero_id ", id_before_real, " -> ",
		int(dp.hero.inst_id), " (变化=真实输入管线翻页生效)")
	print("QAA DONE")


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev)
