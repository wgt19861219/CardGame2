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


func _make_panel(p_kind: String = "task") -> TaskPanel:
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	var tm := TaskManager.new()
	var panel := TaskPanel.new()
	add_child(panel)
	panel.setup_panel(pd, cm, tm, p_kind)
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


# 三轮拆分（2026-09-03）：源 task/dailyTask 两独立弹窗 → 双模式单列表，
# 每模式各装配 1 个滚动列表（不再合并双区）。
func test_setup_assembles_single_list_per_kind() -> void:
	var panel := _make_panel()
	assert_eq(_count_scroll_recursive(panel.container), 1, "task 模式单滚动列表")
	panel.free()
	var daily_panel := _make_panel("dailyTask")
	assert_eq(_count_scroll_recursive(daily_panel.container), 1, "dailyTask 模式单滚动列表")
	daily_panel.free()


# basetask.create @826 mainLayer=CCLayerColor:create(ccc4(0,0,0,200)) 半透明黑遮罩（popup 非场景）。
# 验证 setup_panel 后 shade alpha = 200/255（PopWindow 默认 150/255 被覆盖）。
func test_setup_uses_source_shade_alpha_200() -> void:
	var panel := _make_panel()
	assert_almost_eq(float(panel.shade_layer.color.a), 200.0 / 255.0, 0.001, "shade alpha=200/255（源 basetask@826）")
	panel.free()


# @832-835 标题按模式：task→TASK.TASK="任务"；dailyTask→TASK.DAILY_ACTIVITIES="每日活动"。
func test_title_lstr_per_kind() -> void:
	var panel := _make_panel()
	assert_true(_collect_label_texts(panel.container).has("任务"), "task 模式标题 = TASK.TASK")
	panel.free()
	var daily_panel := _make_panel("dailyTask")
	assert_true(_collect_label_texts(daily_panel.container).has("每日活动"),
		"dailyTask 模式标题 = TASK.DAILY_ACTIVITIES")
	daily_panel.free()


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


# 布局守卫（2026-09-03 一~三轮沉淀）：列表区收在面板框（Frame）内且不侵入顶部
# 货币栏/缎带区。界尺：源 draglist cliprect CCRectMake(0,45,800,348) 顶 y=45（cocos）
# → Godot y=87；三轮拆分后单列表 %ListScroll 顶 114（源 :407 首行紧贴缎带底 112）。
const SOURCE_CLIP_TOP_Y: float = 87.0

func test_sections_inside_panel_frame() -> void:
	var content: Control = (preload("res://scenes/ui/task_content.tscn").instantiate()) as Control
	add_child_autofree(content)
	await get_tree().process_frame
	var frame: Control = content.get_node("Frame") as Control
	var frame_bottom: float = frame.position.y + frame.size.y
	var scroll: Control = content.get_node("%ListScroll") as Control
	assert_gte(scroll.position.y, SOURCE_CLIP_TOP_Y - 0.5,
		"%ListScroll 顶 y≥源 clip 顶 87（不得侵入货币栏/缎带区）")
	assert_lte(scroll.position.y + scroll.size.y, frame_bottom + 0.5,
		"%ListScroll 底不得超出面板框下缘")
	# 行水平基准（2026-09-03 二轮）：源 task.lua:407 行 bg 中心 x=400（anchor(0.5,0.5)）；
	# 行 SHRINK_CENTER 于列表宽内居中 → 列表（Scroll）中心必须=400。
	var center_x: float = scroll.position.x + scroll.size.x * 0.5
	assert_almost_eq(center_x, 400.0, 0.5, "%ListScroll 中心 x=400（源行中心基准）")


# 空态提示挂 frame 正中（三轮拆分照源 :784 createEmptyPrompt 挂 ui.frame 中心
# ccp(269,189)=frame 546×378 正中 → Godot (400,262) 锚点定位，不再进列表顶部）。
# 空态构造：全链 task_finished（sync_current_tasks 后无任务可发现——2026-09-03
# 根修后新玩家自动发现无门槛链 40，不再天然空态）。
func test_empty_prompt_anchored_at_frame_center() -> void:
	var pd := PlayerData.new(cm)
	var tm := TaskManager.new()
	for chain_str in cm.get_raw_table("Task"):
		if str(chain_str) != "name":
			tm.task_finished.append(int(chain_str))
	var panel := TaskPanel.new()
	add_child(panel)
	panel.setup_panel(pd, cm, tm)
	var empty_text: String = cm.get_lstr("TASK.NO_CURRENT_TASK_CAN_BE_ACCESSED")
	var prompt: Label = null
	for lbl in panel._content.find_children("*", "Label", true, false):
		if (lbl as Label).text == empty_text:
			prompt = lbl as Label
			break
	assert_not_null(prompt, "主线空态提示存在")
	if prompt != null:
		assert_almost_eq(prompt.anchor_left, 0.5, 0.001, "提示锚点 x 居中（400）")
		assert_almost_eq(prompt.anchor_top, 262.0 / 480.0, 0.001, "提示锚点 y=262（源 frame 正中）")
	panel.free()


func _collect_scrollcontainers(node: Node) -> Array:
	var result: Array = []
	for c in node.get_children():
		if c is ScrollContainer:
			result.append(c)
		result.append_array(_collect_scrollcontainers(c))
	return result
