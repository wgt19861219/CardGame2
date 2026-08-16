extends GutTest
# Phase 6 shortcut 快捷栏抽屉测试（2026-07-05 第 25 段）。
# 照源 shortcut.lua + framework.lua 抽屉机制（收起/展开/切换/路由/shade 点外收起）。

const BUTTON_KEYS: Array[String] = ["heroPackage", "package", "fragment", "task", "todoList"]


func _make_panel() -> ShortcutPanel:
	var panel := ShortcutPanel.new()
	panel.setup_panel()
	add_child(panel)
	return panel


# ── 初始收起态（源 isShortcutOpen = identity=="main"；独立面板默认收起）──

func test_initial_closed() -> void:
	var panel := _make_panel()
	assert_false(panel._is_open, "初始收起")
	assert_false(panel._shade.visible, "shade 隐藏")
	assert_true(panel._toggle_down.visible, "down 切换钮可见")
	assert_false(panel._toggle_up.visible, "up 切换钮隐藏")
	assert_eq(panel._board.size.y, 65.0, "板高 min（收起；批 2 Task 8 受控偏离：NinePatch min=top40+bottom25=65>源 40）")
	assert_eq(panel._buttons.size(), 5, "5 按钮（heroPackage/package/fragment/task/todoList）")
	for key in BUTTON_KEYS:
		var btn: TextureButton = panel._buttons[key]
		assert_eq(btn.modulate.a, 0.0, "%s 按钮透明" % key)
		assert_eq(btn.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s 收起不可点" % key)
	panel.queue_free()


# ── toggle 切换（源 doShortcut :42-65）──

func test_toggle_open() -> void:
	var panel := _make_panel()
	panel._toggle_open()
	assert_true(panel._is_open, "toggle 后展开")
	assert_true(panel._shade.visible, "shade 显示")
	assert_false(panel._toggle_down.visible, "down 隐藏")
	assert_true(panel._toggle_up.visible, "up 显示")
	for key in BUTTON_KEYS:
		var btn: TextureButton = panel._buttons[key]
		assert_eq(btn.mouse_filter, Control.MOUSE_FILTER_STOP, "%s 展开可点" % key)
	panel.queue_free()


func test_toggle_close() -> void:
	var panel := _make_panel()
	panel._toggle_open()
	panel._toggle_open()
	assert_false(panel._is_open, "双 toggle 收起")
	panel.queue_free()


# ── 按钮路由（源 getSCButtonTouchHandler :556-658 → emit open_requested）──

func test_button_emits_open_requested() -> void:
	var panel := _make_panel()
	panel._toggle_open()
	var keys: Array = []
	panel.open_requested.connect(func(k: String) -> void: keys.append(k))
	panel._buttons["package"].pressed.emit()   # 模拟点 package 按钮
	assert_eq(keys, ["package"], "package 按钮 emit open_requested('package')")
	panel.queue_free()


# 点按钮后抽屉收起（_on_button_pressed → _close，源跳场景后抽屉消失）。
func test_button_press_closes_drawer() -> void:
	var panel := _make_panel()
	panel._toggle_open()
	panel._buttons["fragment"].pressed.emit()
	assert_false(panel._is_open, "点按钮后抽屉收起")
	panel.queue_free()


# ── shade 点 board 外收起（源 createShadeLayer out_board clickHandler :96-124）──

func test_shade_click_closes() -> void:
	var panel := _make_panel()
	panel._toggle_open()
	var evt := InputEventMouseButton.new()
	evt.button_index = MOUSE_BUTTON_LEFT
	evt.pressed = true
	panel._on_shade_gui_input(evt)
	assert_false(panel._is_open, "shade 点击收起")
	panel.queue_free()


# ── 切换钮 toggle 信号链（down/up 都连 _toggle_open）──

func test_toggle_down_button_triggers_open() -> void:
	var panel := _make_panel()
	panel._toggle_down.pressed.emit()   # 点 down 切换钮
	assert_true(panel._is_open, "down 切换钮触发展开")
	panel.queue_free()


# ── Board NinePatch 守卫（批 2 Task 8：源 shortcut.lua:273 Scale9Sprite capInsets CCRectMake(0,25,62,26)）──
# 贴图 main_shortcut_board 106×91 → left=0/top=91-25-26=40/right=106-62=44/bottom=25（批 1 fde903b 公式）。
# 双态（收起 82×40 / 展开 82×460）走 size 切换，NinePatchRect 与 TextureRect 同为 Control.size 不破坏。

func test_board_is_ninepatch_with_source_margins() -> void:
	var panel := _make_panel()
	var board: NinePatchRect = panel._board as NinePatchRect
	assert_not_null(board, "Board 节点为 NinePatchRect（源 Scale9Sprite 九宫格）")
	assert_eq(board.patch_margin_left, 0, "patch_margin_left=0（源 cap x=0）")
	assert_eq(board.patch_margin_top, 40, "patch_margin_top=40（H-y-h=91-25-26）")
	assert_eq(board.patch_margin_right, 44, "patch_margin_right=44（W-x-w=106-0-62）")
	assert_eq(board.patch_margin_bottom, 25, "patch_margin_bottom=25（源 cap y=25）")
	assert_eq(board.size, Vector2(82.0, 65.0), "收起态 82×65（受控偏离：NinePatch min size=margin 和 65>源 40）")
	panel.queue_free()
