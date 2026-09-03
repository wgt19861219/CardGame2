extends GutTest
## TaskRowBuilder 渲染 helper 单测。

func test_make_task_row_structure() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "测试任务", "detail": "详情", "target": 5,
		"progress": 3, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	assert_not_null(row)
	assert_eq(row.name, "TaskRow")
	assert_true(row.get_child_count() > 0)
	row.free()

func test_make_task_row_completed_shows_complete_button() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 5,
		"progress": 5, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	var has_btn: bool = false
	for c in row.get_children():
		if c is TextureButton:
			has_btn = true
	assert_true(has_btn, "完成态显示领奖按钮")
	row.free()

func test_make_task_row_daily_wires_on_fast() -> void:
	# 日常任务"前往"按钮应调用 on_fast 回调（非 Callable() 空回调）。
	# 回归守护：Task 2 make_task_row 漏接 on_fast 致日常前往按钮变 Callable() 失效。
	var fast_called: Array[bool] = [false]
	var task: Dictionary = {
		"kind": "dailyjob", "name": "T", "detail": "", "target": 5,
		"progress": 0, "isFinished": false, "icon": "", "reward": [],
	}
	var on_fast: Callable = func() -> void: fast_called[0] = true
	var row: Control = TaskRowBuilder.make_task_row(task, Callable(), "", "前往", on_fast)
	# 找日常按钮（非完成态，TextureButton）并模拟点击
	for c in row.get_children():
		if c is TextureButton:
			(c as TextureButton).emit_signal("pressed")
	assert_true(fast_called[0], "日常前往按钮触发 on_fast 回调")
	row.free()


func test_make_empty_prompt() -> void:
	var lbl: Label = TaskRowBuilder.make_empty_prompt("task")
	assert_not_null(lbl)
	assert_true(lbl.text.length() > 0)
	lbl.free()

func test_row_builder_no_translation_comments() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_row_builder.gd")
	assert_eq(script_text.count("# 源 "), 0, "无翻译注释")

func test_row_builder_no_add_theme_override() -> void:
	# spec Q5 路径1：彻底归零
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_row_builder.gd")
	assert_eq(script_text.count("add_theme_"), 0, "无 add_theme override（全走 Theme variation）")

func test_row_builder_uses_theme_variation() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_row_builder.gd")
	assert_true(script_text.find("theme_type_variation") != -1, "Label 用 theme_type_variation")
	assert_true(script_text.find("TaskProgressDoneLabel") != -1, "progress done variation")
	assert_true(script_text.find("TaskProgressTodoLabel") != -1, "progress todo variation")


# P0-3：源 task.lua:324 doPressInList bg setScale(0.98)。ROW_PRESS_SCALE 常量 0.98 + bg pivot 居中。
func test_row_press_scale_constant() -> void:
	assert_almost_eq(TaskRowBuilder.ROW_PRESS_SCALE.x, 0.98, 0.001, "row press scale x=0.98 照源")
	assert_almost_eq(TaskRowBuilder.ROW_PRESS_SCALE.y, 0.98, 0.001, "row press scale y=0.98 照源")


# bg 显示尺寸口径守卫（2026-08-22 溢出修复）：task_board.png 纹理 638×123px，源 createSprite
# 显示 = 纹理÷CS = 498.05×96.0 点（[[content-scale-factor]]）；旧值 638/123 为纹理 px 直用，
# 行偏大 1.28× 致行背景超滚动区。BG_H 同时是 bg_pos 行内 y 换算基准。
func test_row_bg_display_size_divided_by_cs() -> void:
	assert_almost_eq(TaskRowBuilder.BG_W, 638.0 / 1.28125, 0.01, "BG_W = task_board 纹理 638px ÷CS")
	assert_almost_eq(TaskRowBuilder.BG_H, 123.0 / 1.28125, 0.01, "BG_H = task_board 纹理 123px ÷CS = 96.0")
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 5,
		"progress": 0, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	var bg: TextureRect = row as TextureRect
	assert_almost_eq(bg.custom_minimum_size.x, 638.0 / 1.28125, 0.1, "bg custom_minimum_size.x = 显示宽")
	assert_almost_eq(bg.custom_minimum_size.y, 96.0, 0.1, "bg custom_minimum_size.y = 显示高 96.0")
	row.free()


# bg pivot 居中（Control scale 绕中心，源 anchor 0.5,0.5 等价）。
func test_row_bg_pivot_centered() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 5,
		"progress": 5, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	var bg: TextureRect = row as TextureRect
	assert_almost_eq(bg.pivot_offset.x, float(TaskRowBuilder.BG_W) * 0.5, 0.5, "bg pivot x 居中")
	assert_almost_eq(bg.pivot_offset.y, float(TaskRowBuilder.BG_H) * 0.5, 0.5, "bg pivot y 居中")
	row.free()


# 防拉伸守卫（2026-09-03 实测回归）：行在宽于 min size 的 VBox（tscn 列表 531.7 宽）内
# 被 size_flags 默认 FILL 横向拉至 531.7（÷CS 显示宽 498 → 变形 +6.7%，贴图横拉）。
# 源 createSprite 显示恒等比 498×96；修 = SHRINK_CENTER 保 min size 居中。
func test_row_bg_not_stretched_by_container() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 5,
		"progress": 0, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	var bg: TextureRect = row as TextureRect
	assert_eq(bg.size_flags_horizontal, Control.SIZE_SHRINK_CENTER,
		"行 size_flags_horizontal=SHRINK_CENTER（VBox 内保等比宽，禁 FILL 拉伸）")
	# 容器内实测：放入 531.7 宽的 VBox（模拟 tscn 列表），行宽应保持 498 不被拉。
	var host := VBoxContainer.new()
	host.custom_minimum_size = Vector2(531.7, 0)
	host.add_child(bg)
	var panel := PanelContainer.new()
	panel.add_child(host)
	add_child(panel)
	await get_tree().process_frame
	assert_almost_eq(bg.size.x, float(TaskRowBuilder.BG_W), 0.5,
		"行在 531.7 宽容器内实际 size.x = 498（等比，未被 FILL 拉伸至 531.7）")
	panel.free()


# action button 连 button_down/up 信号驱动 bg scale（源 doPressInList 通过整 layer 拦截，
# 项目 bg mouse_filter=IGNORE，借子按钮信号驱动等价视觉反馈）。
func test_row_action_button_wires_press_signals() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 5,
		"progress": 5, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	var btn: TextureButton = null
	for c in row.get_children():
		if c is TextureButton:
			btn = c as TextureButton
			break
	assert_not_null(btn, "行含 action button")
	assert_true(btn.button_down.is_connected(TaskRowBuilder._tween_row_scale), "button_down 连 _tween_row_scale")
	assert_true(btn.button_up.is_connected(TaskRowBuilder._tween_row_scale), "button_up 连 _tween_row_scale")
	row.free()


# ── 2026-08-28 数值照源守卫（完成钮/progress 中心锚/Item 奖励/动态步进）──

# 源 task.lua:583-585 completeTag 原尺寸（126×89px÷CS=98.34×69.46）中心锚 (420,45)；
# 旧实现误与"前往"钮共用 (450,30)+60×45 拉伸（位置/尺寸双错）。
func test_complete_tag_source_size_and_center() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 5,
		"progress": 5, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	for c in row.get_children():
		if c is TextureButton:
			var btn: TextureButton = c as TextureButton
			assert_almost_eq(btn.size.x, 126.0 / 1.28125, 0.2, "completeTag 宽=126px÷CS=98.34")
			assert_almost_eq(btn.size.y, 89.0 / 1.28125, 0.2, "completeTag 高=89px÷CS=69.46")
			var cx: float = btn.position.x + btn.size.x * 0.5
			var cy: float = btn.position.y + btn.size.y * 0.5
			assert_almost_eq(cx, 420.0, 0.3, "completeTag 中心 x=420（源 :584）")
			assert_almost_eq(cy, TaskRowBuilder.BG_H - 45.0, 0.3, "completeTag 中心 y=45（源翻 y）")
			break
	row.free()


# 源 readNode progress 无 anchor 声明=默认(0.5,0.5) 中心锚（其余 Label 显式左中）。
# 旧实现全按左中摆 → progress 文字整体偏左半宽；挂树 relayout 后中心应落在 450。
func test_progress_label_centered_after_relayout() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 30,
		"progress": 12, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	add_child_autofree(row)
	var progress_lbl: Label = null
	for c in row.get_children():
		if c is Label and (c as Label).text == "12/30":
			progress_lbl = c as Label
			break
	assert_not_null(progress_lbl, "progress label 应存在")
	if progress_lbl != null:
		var cx: float = progress_lbl.position.x + progress_lbl.get_minimum_size().x * 0.5
		assert_almost_eq(cx, 450.0, 1.5, "progress 中心 x=450（源中心锚，挂树 relayout 后）")


# Item 类奖励走 ReadequipIcon（源 readequip.createIcon(id, mh=20)；Task 表 76 条 Item 奖励实测在用）。
func test_item_reward_icon_rendered() -> void:
	var cm := ConfigManager.new()
	cm.load_all()
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 5,
		"progress": 0, "isFinished": false, "icon": "",
		"reward": [{"type": "Item", "id": 102, "amount": 2}],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable(), "奖励:", "前往", Callable(), cm)
	add_child_autofree(row)
	var found: bool = false
	for c in row.get_children():
		if c is Control and not (c is TextureRect) and not (c is TextureButton) and not (c is Label):
			if absf(c.scale.y - 20.0 / 72.0) < 0.01:
				found = true
	assert_true(found, "Item 奖励产物 scale=20/72（源 mh=20 缩 ReadequipIcon 产物）")


# name 超宽压缩（源 :555-557 board.name 宽>300 → setScale(300/w)）。
func test_name_overwide_compressed() -> void:
	var long_name: String = "这是一个非常非常非常非常长的任务名称用于触发超宽压缩阈值检查逻辑"
	var task: Dictionary = {
		"kind": "task", "name": long_name, "detail": "", "target": 5,
		"progress": 0, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	add_child_autofree(row)
	for c in row.get_children():
		if c is Label and (c as Label).text == long_name:
			assert_lt((c as Label).scale.x, 1.0, "超宽 name 被压缩 scale<1（源 300 阈值）")
			break


# Todolist.Icon 是 cocos 路径（"UI/alpha/HVGA/task_vit_icon.png"，Todolist id=1 实测），
# 须 CLIP 转换（"UI/"→"res://assets/ui/"，hero_package_item 判例）后 load——
# 漏转换 load_tex 失败致行图标空缺（2026-09-03 根修）。
func test_row_icon_cocos_path_converted() -> void:
	var task: Dictionary = {
		"kind": "dailyjob", "name": "T", "detail": "", "target": 1,
		"progress": 0, "isFinished": false,
		"icon": "UI/alpha/HVGA/task_vit_icon.png", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	add_child_autofree(row)
	var found: bool = false
	for c in row.get_children():
		var tr := c as TextureRect
		if tr != null and tr.texture != null \
				and str(tr.texture.resource_path).contains("task_vit_icon"):
			found = true
	assert_true(found, "cocos 路径 Icon 经转换后成功加载渲染（图标不空缺）")
