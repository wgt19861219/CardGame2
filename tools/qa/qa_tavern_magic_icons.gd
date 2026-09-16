extends Node

## 一次性取证：魂匣热点 heroIcons 锚点根修后几何落点实测（2026-09-16）。
## 打开 tavern → 切 MagicSoul 填充热点图标 → dump wrap/ReadheroIcon 两层变换
## + DropBg 框 rect 对照；另存截图到 user://qa_shots/。免 bridge 逐层探索。

const CONTAINER_CENTER := Vector2(52.0, 52.0)   # ReadheroIcon 104 容器中心（cocos 对称点翻转不变）


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.0).timeout
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, BattleRng.new(7))
	panel.show_window(get_tree().current_scene)
	# 切 MagicSoul 填充热点图标（_select_pool 不触发滑动；几何为 Scroll 局部，与展开态一致）
	panel._select_pool("MagicSoul")
	await get_tree().create_timer(0.5).timeout
	var magic: Dictionary = panel._boards.get("MagicSoul", {})
	var scroll: Control = magic.get("scroll_board", null) as Control
	if scroll == null:
		print("QA_TAVERN no scroll")
		return
	for bg_name in ["DropBgMonth", "DropBgDay"]:
		var bg: Control = scroll.get_node(bg_name) as Control
		print("QA_TAVERN %s rect=[%.1f,%.1f]-[%.1f,%.1f]" % [bg_name,
			bg.offset_left, bg.offset_top, bg.offset_right, bg.offset_bottom])
	var n := 0
	for c in scroll.get_children():
		if not c.has_meta("magic_icon"):
			continue
		n += 1
		var wrap := c as Control
		var ri := wrap.get_child(0) as ReadheroIcon
		var inner: Node2D = ri.icon
		var s: float = inner.scale.x
		var disp: Vector2 = ri._portrait_disp
		var portrait_center_local := Vector2(disp.x * 0.5, ReadheroIcon.CONTAINER_SIZE.y - disp.y * 0.5)
		var center_in_wrap: Vector2 = CONTAINER_CENTER * s + inner.position
		var portrait_center_in_wrap: Vector2 = portrait_center_local * s + inner.position
		var portrait_half: float = disp.x * 0.5 * s
		print("QA_TAVERN icon%d wrap_pos=(%.2f,%.2f) s=%.4f inner_pos=(%.2f,%.2f) "
			% [n, wrap.position.x, wrap.position.y, s, inner.position.x, inner.position.y]
			+ "container_center@scroll=(%.2f,%.2f) portrait_center@scroll=(%.2f,%.2f) portrait_half=%.2f"
			% [(center_in_wrap + wrap.position).x, (center_in_wrap + wrap.position).y,
				(portrait_center_in_wrap + wrap.position).x, (portrait_center_in_wrap + wrap.position).y,
				portrait_half])
	print("QA_TAVERN total=", n)
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	img.save_png("user://qa_shots/tavern_magic_r1.png")
	print("QA_TAVERN shot ok")
