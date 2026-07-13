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


# setup 装配两段列表（源 ed.ui.task 主线 + ed.ui.dailyTask 日常，各一 ScrollContainer）
func test_setup_assembles_two_sections() -> void:
	var panel := _make_panel()
	var scroll_count: int = 0
	for c in panel.container.get_children():
		if c is ScrollContainer:
			scroll_count += 1
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
