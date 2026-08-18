extends GutTest
## TaskPanel 集成测试（task_panel 拆分 3/3 后重定向，2026-07-24）。
## 函数级单元测试（_bg_pos/_pid_values/resolve_fast_target/parse_rewards/make_task_row/
## get_count/get_main_progress/make_empty_prompt）已随函数外迁进 TaskQuery/TaskRowBuilder，
## 由 test_task_query.gd / test_task_row_builder.gd 覆盖，本文件只留 panel 协调层集成测试：
## setup 两段装配 / shade alpha / 段标题 LSTR / 完成按钮纹理降级。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel() -> TaskPanel:
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	var tm := TaskManager.new()
	var panel := TaskPanel.new()
	add_child(panel)
	panel.setup_panel(pd, cm, tm)
	return panel


# 递归统计 panel.container 子树中 ScrollContainer 数（.tscn 重构后 ScrollContainer 在
# content 下，非 container 直接子，需递归扫）。
func _count_scroll_recursive(node: Node) -> int:
	var count: int = 0
	for c in node.get_children():
		if c is ScrollContainer:
			count += 1
		count += _count_scroll_recursive(c)
	return count


# setup 装配两段列表（源 ed.ui.task 主线 + ed.ui.dailyTask 日常，各一 ScrollContainer）
func test_setup_assembles_two_sections() -> void:
	var panel := _make_panel()
	var scroll_count: int = _count_scroll_recursive(panel.container)
	assert_eq(scroll_count, 2, "主线+日常两段滚动列表")
	panel.free()


# basetask.create @826 mainLayer=CCLayerColor:create(ccc4(0,0,0,200)) 半透明黑遮罩（popup 非场景）。
# 验证 setup_panel 后 shade alpha = 200/255（PopWindow 默认 150/255 被覆盖）。
func test_setup_uses_source_shade_alpha_200() -> void:
	var panel := _make_panel()
	assert_almost_eq(float(panel.shade_layer.color.a), 200.0 / 255.0, 0.001, "shade alpha=200/255（源 basetask@826）")
	panel.free()


# @832-835 段标题：task→TASK.TASK="任务"；dailyTask→TASK.DAILY_ACTIVITIES="每日活动"。
func test_section_titles_use_source_lstr() -> void:
	var panel := _make_panel()
	var titles: Array = _collect_label_texts(panel.container)
	assert_true(titles.has("任务"), "主线段标题 = TASK.TASK")
	assert_true(titles.has("每日活动"), "日常段标题 = TASK.DAILY_ACTIVITIES")
	panel.free()


# 递归收集 container 子树中所有 Label 的非空 text（.tscn 重构后段标题在 content 下需递归）。
func _collect_label_texts(node: Node) -> Array:
	var texts: Array = []
	for c in node.get_children():
		if c is Label and not (c as Label).text.is_empty():
			texts.append(String((c as Label).text))
		texts.append_array(_collect_label_texts(c))
	return texts


# completeTag 用 task_get_reward_button.png（assets 缺 → 降级 task_button.png）。
# 验证完成态按钮纹理非空（降级 fallback 生效，经 TaskRowBuilder.make_task_row 集成）。
func test_complete_button_falls_back_when_asset_missing() -> void:
	var task := {
		"kind": "task", "name": "T", "detail": "D", "target": 1, "progress": 1,
		"isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	var btn_tex_nonempty: bool = false
	for c in row.get_children():
		if c is TextureButton:
			if (c as TextureButton).texture_normal != null:
				btn_tex_nonempty = true
	assert_true(btn_tex_nonempty, "completeTag 降级后 texture_normal 非空（task_get_reward_button.png 缺 → task_button.png）")
	row.free()


# 源 draglist bar（task.lua:387-390 bar={bglen=320,bgpos=ccp(145,218)}，draglist.lua:13-14
# 贴图 scroll_bar_bg/scroll_bar）→ ScrollContainer 滚动条贴图化（avatar 批4 先例，
# add_theme_stylebox_override 属滚动条引擎缺口例外）。
func test_panel_styles_scrollbars_with_source_textures() -> void:
	var panel := _make_panel()
	for scroll in _collect_scrollcontainers(panel.container):
		var vs: VScrollBar = (scroll as ScrollContainer).get_v_scroll_bar()
		assert_true(vs.has_theme_stylebox_override("scroll"),
			"%s 垂直滚动条轨道贴图化（源 scroll_bar_bg）" % (scroll as ScrollContainer).name)
		assert_true(vs.has_theme_stylebox_override("grabber"),
			"%s 垂直滚动条滑块贴图化（源 scroll_bar）" % (scroll as ScrollContainer).name)
	panel.free()


func _collect_scrollcontainers(node: Node) -> Array:
	var result: Array = []
	for c in node.get_children():
		if c is ScrollContainer:
			result.append(c)
		result.append_array(_collect_scrollcontainers(c))
	return result
