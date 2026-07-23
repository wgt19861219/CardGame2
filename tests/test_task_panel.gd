extends GutTest
## TaskPanel 测试（P1-3：照源 task.lua basetask.createTask@417-598 完整翻译）。
## 覆盖坐标转换 / 两段装配 / reward 解析 / 完成态 completeTag / 日常未完成 fastButton / reward 横排 / icon 装配。
## 避领奖/跳场景副作用（Logic 在 test_task_manager 覆盖），专注 View 装配。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 createTask bg 坐标（cocos 左下原点 y 向上）→ Godot（左上原点）：_bg_pos(cx, 123-cy)
func test_bg_pos_transform() -> void:
	assert_eq(TaskPanel._bg_pos(Vector2(95.0, 71.0)), Vector2(95.0, 52.0), "name cocos(95,71)→Godot(95,52)")
	assert_eq(TaskPanel._bg_pos(Vector2(450.0, 30.0)), Vector2(450.0, 93.0), "fast cocos(450,30)→Godot(450,93)")
	assert_eq(TaskPanel._bg_pos(Vector2(50.0, 47.0)), Vector2(50.0, 76.0), "iconBg cocos(50,47)→Godot(50,76)")


func _make_panel() -> TaskPanel:
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	var tm := TaskManager.new()
	var panel := TaskPanel.new()
	add_child(panel)
	panel.setup_panel(pd, cm, tm)
	return panel


# 递归统计 panel.container 子树中 ScrollContainer 数（.tscn 重构后 ScrollContainer 在
# content 下，非 container 直接子，需递归扫；照 hero_detail 测试 _count_meta_recursive 范式）。
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


# _parse_rewards 主线单槽（源 initTaskData@1100 Task Reward Type/ID/Amount）
func test_parse_rewards_main_single_slot() -> void:
	var panel := _make_panel()
	var row := {"Task Reward Type": "Coin", "Task Reward ID": 1, "Task Reward Amount": 100}
	var r: Array = panel._parse_rewards(row, false)
	assert_eq(r.size(), 1, "主线单槽 1 reward")
	assert_eq(String((r[0] as Dictionary).get("type")), "Coin", "type=Coin")
	assert_eq(int((r[0] as Dictionary).get("amount")), 100, "amount=100")
	panel.free()


# _parse_rewards 日常双槽（源 initTaskData@1525 for 1..2 Task Reward 1/2）
func test_parse_rewards_daily_doubles() -> void:
	var panel := _make_panel()
	var row := {
		"Task Reward 1 Type": "Coin", "Task Reward 1 ID": 1, "Task Reward 1 Amount": 50,
		"Task Reward 2 Type": "Diamond", "Task Reward 2 ID": 1, "Task Reward 2 Amount": 10,
	}
	var r: Array = panel._parse_rewards(row, true)
	assert_eq(r.size(), 2, "日常双槽 2 reward")
	assert_eq(String((r[1] as Dictionary).get("type")), "Diamond", "槽 2 type=Diamond")
	panel.free()


# _make_task_row 完成态（progress>=target）：finished bg + completeTag 按钮（源 :583）
func test_make_row_complete_shows_finish_button() -> void:
	var panel := _make_panel()
	var task := {
		"kind": "task", "name": "T", "detail": "D", "target": 1, "progress": 1,
		"isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = panel._make_task_row(task, Callable())
	assert_true(row is TextureRect, "行根是 TextureRect bg")
	var has_btn: bool = false
	for c in row.get_children():
		if c is TextureButton:
			has_btn = true
	assert_true(has_btn, "完成态显示 completeTag 按钮")
	row.free()
	panel.free()


# _make_task_row 日常未完成：fastButton 前往（源 :587 createFastButton）
func test_make_row_daily_unfinished_shows_fast_button() -> void:
	var panel := _make_panel()
	var task := {
		"kind": "dailyjob", "name": "T", "detail": "D", "target": 5, "progress": 1,
		"isFinished": false, "icon": "", "reward": [{"type": "Coin", "id": 1, "amount": 10}],
	}
	var row: Control = panel._make_task_row(task, Callable())
	var has_btn: bool = false
	for c in row.get_children():
		if c is TextureButton:
			has_btn = true
	assert_true(has_btn, "日常未完成显示 fastButton 前往")
	row.free()
	panel.free()


# _make_task_row reward icons 横排（源 :556-581，2 reward → 2 icon + 2 amt）
func test_make_row_reward_icons_horizontal() -> void:
	var panel := _make_panel()
	var task := {
		"kind": "task", "name": "T", "detail": "D", "target": 1, "progress": 0,
		"isFinished": false, "icon": "",
		"reward": [{"type": "Coin", "id": 1, "amount": 50}, {"type": "Diamond", "id": 1, "amount": 10}],
	}
	var row: Control = panel._make_task_row(task, Callable())
	var amt_count: int = 0
	for c in row.get_children():
		if c is Label and String(c.text).begins_with("x"):
			amt_count += 1
	assert_eq(amt_count, 2, "2 reward → 2 金额 Label 横排")
	row.free()
	panel.free()


# _make_task_row icon 装配（源 :512-549）：icon 空时按 reward[0].type 取 TYPE_ICON_RES + iconBg
func test_make_row_icon_assembly() -> void:
	var panel := _make_panel()
	var task := {
		"kind": "dailyjob", "name": "T", "detail": "", "target": 5, "progress": 0,
		"isFinished": false, "icon": "",
		"reward": [{"type": "Vitality", "id": 1, "amount": 10}],
	}
	var row: Control = panel._make_task_row(task, Callable())
	var has_icon_bg: bool = false
	for c in row.get_children():
		if c is TextureRect and (c as TextureRect).texture:
			var p: String = (c as TextureRect).texture.resource_path
			if p.contains("task_icon_bg"):
				has_icon_bg = true
	assert_true(has_icon_bg, "iconBg 装配（源 task_icon_bg.png）")
	row.free()
	panel.free()


# 源 basetask.create @826 mainLayer=CCLayerColor:create(ccc4(0,0,0,200)) 半透明黑遮罩（popup 非场景）。
# 验证 setup_panel 后 shade alpha = 200/255（PopWindow 默认 150/255 被覆盖）。
func test_setup_uses_source_shade_alpha_200() -> void:
	var panel := _make_panel()
	assert_almost_eq(float(panel.shade_layer.color.a), 200.0 / 255.0, 0.001, "shade alpha=200/255（源 basetask@826）")
	panel.free()


# 源 @832-835 段标题：task→TASK.TASK="任务"；dailyTask→TASK.DAILY_ACTIVITIES="每日活动"。
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


# 源 createEmptyPrompt @788-790：task→TASK.NO_CURRENT_TASK_CAN_BE_ACCESSED；dailyjob→TASK.YOU_HAVE_DONE_TODAYS_TASKS。
func test_empty_prompt_uses_source_lstr() -> void:
	var panel := _make_panel()
	var task_prompt: Label = panel._make_empty_prompt("task")
	assert_eq(String(task_prompt.text), "当前没有可接的任务", "task empty = TASK.NO_CURRENT_TASK_CAN_BE_ACCESSED")
	var daily_prompt: Label = panel._make_empty_prompt("dailyjob")
	assert_eq(String(daily_prompt.text), "今日任务已全部完成", "dailyjob empty = TASK.YOU_HAVE_DONE_TODAYS_TASKS")
	task_prompt.free()
	daily_prompt.free()
	panel.free()


# 源 :583 completeTag 用 task_get_reward_button.png（assets 缺 → 降级 task_button.png）。
# 验证完成态按钮纹理非空（降级 fallback 生效）。
func test_complete_button_falls_back_when_asset_missing() -> void:
	var panel := _make_panel()
	var task := {
		"kind": "task", "name": "T", "detail": "D", "target": 1, "progress": 1,
		"isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = panel._make_task_row(task, Callable())
	var btn_tex_nonempty: bool = false
	for c in row.get_children():
		if c is TextureButton:
			if (c as TextureButton).texture_normal != null:
				btn_tex_nonempty = true
	assert_true(btn_tex_nonempty, "completeTag 降级后 texture_normal 非空（task_get_reward_button.png 缺 → task_button.png）")
	row.free()
	panel.free()


# 源 createFastButton fast_handler（task.lua:651-738）13 type 路由分派。
# 9 个已移植 type → {"action":"call","method":main_scene._open_*}。
func test_resolve_fast_target_supported_types() -> void:
	var expected: Dictionary = {
		"FarmPVEStage": "_open_stage_select",
		"FarmElitePVEStage": "_open_stage_select",
		"FarmChapter": "_open_exercise_panel",
		"PVPBattle": "_open_ladder",
		"PVPWin": "_open_ladder",
		"SkillUpgradeSuccess": "_open_hero",
		"MidasUse": "_open_midas",
		"TavernGroupUse": "_open_tavern",
		"CompleteCrusadeStage": "_open_crusade",
	}
	for ttype in expected:
		var r: Dictionary = TaskPanel.resolve_fast_target(ttype)
		assert_eq(String(r.get("action", "")), "call", "%s → action=call" % ttype)
		assert_eq(String(r.get("method", "")), String(expected[ttype]), "%s → method=%s" % [ttype, expected[ttype]])


# 4 个未移植 type → {"action":"toast","msg":非空}（源 handler 目标场景未实现，降级 Toast）。
func test_resolve_fast_target_unsupported_types() -> void:
	for ttype in ["EnhanceLevelUp", "MonthlyCardPeriod", "SendMercenary", "EnterRaid"]:
		var r: Dictionary = TaskPanel.resolve_fast_target(ttype)
		assert_eq(String(r.get("action", "")), "toast", "%s → action=toast（未移植）" % ttype)
		assert_false(String(r.get("msg", "")).is_empty(), "%s → msg 非空" % ttype)


# 未知 type → Toast 默认文案（fallback）。
func test_resolve_fast_target_unknown_type_fallback() -> void:
	var r: Dictionary = TaskPanel.resolve_fast_target("SomeUnknownType")
	assert_eq(String(r.get("action", "")), "toast", "未知 type → action=toast")
	assert_eq(String(r.get("msg", "")), "前往任务目标", "未知 type → 默认 Toast 文案")
