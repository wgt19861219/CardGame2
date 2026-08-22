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
	assert_eq(board.patch_margin_left, 8, "patch_margin_left=8（受控偏离 2026-08-22：源 cap 0/44 在窄板下九宫格挤压渲染异常，对称 8/12 修）")
	assert_eq(board.patch_margin_top, 12, "patch_margin_top=12（受控偏离，同上）")
	assert_eq(board.patch_margin_right, 8, "patch_margin_right=8（受控偏离，同上）")
	assert_eq(board.patch_margin_bottom, 12, "patch_margin_bottom=12（受控偏离，同上）")
	assert_eq(board.size, Vector2(92.0, 65.0), "收起态 92×65（板 2026-08-22 加宽 92 镶框裹按钮，受控偏离）")
	panel.queue_free()


# ── Task 4 两件套改造：tag 红点静态节点（源 createBoard 主 tag :310-321 +
#    createButtons 各按钮 _tag :223-231，refreshTags :126-144 控 visible）──

# tag 显示尺寸 = 纹理 21×22 ÷ CS(1.28125)（无 TextureConfig 条目，批4 口径）= 16.39×17.17。
const TAG_SIZE: Vector2 = Vector2(16.39, 17.17)
const FAKE_TASK_ID: int = 987654   # 注入用假任务 id（远超真实 id 域，避污染）


func test_tag_nodes_present_and_sized() -> void:
	var panel := _make_panel()
	# tscn 静态初值（源 :310-321 主 tag config.visible=false；按钮 tag 建后即被 refreshTags 接管，
	# :253 createButtons 末刷新——面板侧初始可见性由数据决定，不在此断言）。
	var raw: Control = ShortcutPanel.CONTENT_SCENE.instantiate() as Control
	var raw_main: TextureRect = raw.get_node("%Tag") as TextureRect
	assert_false(raw_main.visible, "主 tag tscn 静态初值隐藏")
	for key in BUTTON_KEYS:
		var raw_tag: TextureRect = raw.get_node("%" + String(ShortcutPanel.TAG_NODE_NAMES[key])) as TextureRect
		assert_false(raw_tag.visible, "%s tag tscn 静态初值隐藏" % key)
	raw.free()
	# 面板侧：节点存在 + 贴图 + 尺寸 + 鼠标穿透
	assert_not_null(panel._main_tag, "主 Tag 节点存在（源 createBoard tag，收起态聚合提示）")
	assert_eq(panel._tags.size(), 5, "5 按钮各带红点 tag（源 createButtons _tag）")
	for key in BUTTON_KEYS:
		var tag: TextureRect = panel._tags[key]
		assert_not_null(tag, "%s tag 节点存在" % key)
		assert_eq(tag.texture.resource_path, "res://assets/ui/alpha/HVGA/main_deal_tag.png", "%s tag 贴图 main_deal_tag（源共用 tag 资源）" % key)
		assert_almost_eq(tag.size.x, TAG_SIZE.x, 0.02, "%s tag 宽=21/CS=16.39" % key)
		assert_almost_eq(tag.size.y, TAG_SIZE.y, 0.02, "%s tag 高=22/CS=17.17" % key)
		assert_eq(tag.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s tag 装饰不吞点击" % key)
	var main_tag: TextureRect = panel._main_tag
	assert_eq(main_tag.texture.resource_path, "res://assets/ui/alpha/HVGA/main_deal_tag.png", "主 tag 贴图 main_deal_tag")
	assert_eq(main_tag.mouse_filter, Control.MOUSE_FILTER_IGNORE, "主 tag 装饰不吞点击")
	panel.queue_free()


# 语义化防 parenting：按钮 tag 必须挂在按钮内右上区（源 tagPos 子坐标：距左 68~75、距底 60~65）。
# 2026-08-22 BUTTON_SCALE ×0.8 后 tag 随按钮缩放，断言用视觉 rect（size×scale）。
func test_button_tags_in_button_upper_right() -> void:
	var panel := _make_panel()
	for key in BUTTON_KEYS:
		var btn: TextureButton = panel._buttons[key]
		var tag: TextureRect = panel._tags[key]
		var tag_center: Vector2 = tag.global_position + tag.size * tag.scale / 2.0
		var btn_rect: Rect2 = Rect2(btn.global_position, btn.size * btn.scale)
		assert_true(btn_rect.has_point(tag_center), "%s tag 中心在按钮 rect 内" % key)
		assert_gt(tag_center.x, btn_rect.position.x + btn_rect.size.x / 2.0, "%s tag 中心在按钮右半" % key)
		assert_lt(tag_center.y, btn_rect.position.y + btn_rect.size.y / 2.0, "%s tag 中心在按钮上半" % key)
	panel.queue_free()


# 主 tag 偏移照源 :318 ccp(shortcut_pos_x+28, shortcut_pos_y+22)（y 翻转）——防 parenting 语义断言。
# toggle 中心用视觉口径（position + size×scale/2；×0.8 后 toggle 视觉中心仍 (740,40)）。
func test_main_tag_beside_toggle_upper_right() -> void:
	var panel := _make_panel()
	var toggle_center: Vector2 = panel._toggle_down.global_position + panel._toggle_down.size * panel._toggle_down.scale / 2.0
	var tag_center: Vector2 = panel._main_tag.global_position + panel._main_tag.size / 2.0
	var offset: Vector2 = tag_center - toggle_center
	assert_almost_eq(offset.x, 28.0, 0.02, "主 tag 中心在 toggle 右 +28（源 pos_x+28）")
	assert_almost_eq(offset.y, -22.0, 0.02, "主 tag 中心在 toggle 上 -22（源 pos_y+22 y 翻转）")
	panel.queue_free()


# 源 refreshTags :126-144：任务完成未领 → task tag 亮 + 收起态主 tag 亮；package/fragment 恒 false（源 :685-699）。
func test_refresh_tags_task_unclaimed_shows_tags() -> void:
	var panel := _make_panel()
	var tm: TaskManager = GameData.player.task_manager
	tm.completed[FAKE_TASK_ID] = true
	tm.claimed.erase(FAKE_TASK_ID)
	panel.refresh_tags()
	assert_true(panel._tags["task"].visible, "完成未领任务 → task tag 亮")
	assert_false(panel._tags["package"].visible, "package tag 恒灭（源 checkPackageTag 死代码恒 false）")
	assert_false(panel._tags["fragment"].visible, "fragment tag 恒灭（源 checkFragmentPackageTag 恒 false）")
	assert_true(panel._main_tag.visible, "收起态任一 tag 亮 → 主 tag 亮（源 :139-143）")
	tm.completed.erase(FAKE_TASK_ID)
	panel.queue_free()


# 源 refreshTags :139-143：展开态主 tag 恒隐藏（按钮 tag 仍按数据显）。
func test_refresh_tags_open_hides_main_tag() -> void:
	var panel := _make_panel()
	var tm: TaskManager = GameData.player.task_manager
	tm.completed[FAKE_TASK_ID] = true
	panel._toggle_open()
	assert_false(panel._main_tag.visible, "展开态主 tag 恒隐藏")
	assert_true(panel._tags["task"].visible, "展开态 task tag 仍按数据亮")
	tm.completed.erase(FAKE_TASK_ID)
	panel.queue_free()


# 已领取任务不亮 tag（源 isTaskCompleted 语义：completed 且未 claimed）。
func test_refresh_tags_claimed_task_hides() -> void:
	var panel := _make_panel()
	var tm: TaskManager = GameData.player.task_manager
	tm.completed[FAKE_TASK_ID] = true
	tm.claimed[FAKE_TASK_ID] = true
	panel.refresh_tags()
	assert_false(panel._tags["task"].visible, "已领取任务不亮 tag")
	tm.completed.erase(FAKE_TASK_ID)
	tm.claimed.erase(FAKE_TASK_ID)
	panel.queue_free()


# 全 key 分发健壮性：真实档数据（hero/碎片/日常）下全 key 查询不崩、返回 bool。
func test_check_button_tag_all_keys_return_bool() -> void:
	var panel := _make_panel()
	for key in BUTTON_KEYS:
		var v: bool = panel._check_button_tag(key)
		assert_true(v == true or v == false, "%s 分发返回 bool 不崩" % key)
	panel.queue_free()


# ── 按钮列 y 回源守卫（2026-08-22 溢出修复二轮：作废旧坐标时代等距 90 历史调整）──
# 源 uires.lua:26-31 shortcutBoardButtonPosY={382,307,237,162,83} + :18 s_b_offset_y=-20 + :37-38
# 运行时循环叠加 → {362,287,217,142,63}（framework.lua popBoardWithoutAnim:427 setPosition 直用）；
# Godot y=480-PosY → {118,193,263,338,417}，间距不等距 75/70/75/79。首钮与 toggle（y=40）
# 垂直间距 78（源同），旧等距值首钮 57 与 toggle 40 叠死。

func test_button_center_y_source_direct() -> void:
	var panel := _make_panel()
	panel._apply_open_instant()
	const EXPECTED_Y: Array[float] = [118.0, 193.0, 263.0, 338.0, 417.0]
	for i in BUTTON_KEYS.size():
		var btn: TextureButton = panel._buttons[BUTTON_KEYS[i]]
		# 中心=视觉口径（position + size×scale/2；×0.8 缩放不改 size 但改视觉 rect）
		var center_y: float = btn.position.y + btn.size.y * btn.scale.y / 2.0
		assert_almost_eq(center_y, EXPECTED_Y[i], 0.5, "%s 按钮中心 y=%d（源 PosY %d 直译 480-y）" % [BUTTON_KEYS[i], EXPECTED_Y[i], [362, 287, 217, 142, 63][i]])
	panel.queue_free()


# 首按钮与 toggle 不叠（源 toggle ccp(740,440)→y=40 恒定；首钮 118 与其相距 78）。
# 中心均用视觉口径（size×scale/2）。
func test_first_button_not_overlapping_toggle() -> void:
	var panel := _make_panel()
	panel._apply_open_instant()
	var first: TextureButton = panel._buttons[BUTTON_KEYS[0]]
	var first_center_y: float = first.position.y + first.size.y * first.scale.y / 2.0
	var toggle_center_y: float = panel._toggle_down.position.y + panel._toggle_down.size.y * panel._toggle_down.scale.y / 2.0
	assert_almost_eq(toggle_center_y, 40.0, 0.5, "toggle 中心 y=40（源 shortcut_pos_y 440 直译）")
	assert_gt(first_center_y - toggle_center_y, 60.0, "首钮(118)与 toggle(40) 垂直间距 ≥60（实际 78，源同；旧等距 90 时仅 17 叠死）")
	panel.queue_free()


# ── 按钮/toggle ×0.8 受控偏离守卫（2026-08-22 用户决策：源设计按钮 102 宽压板 82 观感不佳，
#    统一缩小收入板内；中心位置不动）──

# 展开态按钮视觉 rect 全部收入板 [704,796]（板 x=750±46，2026-08-22 加宽 92 镶框裹按钮），且彼此垂直不叠（源间距 75/70/75/79）。
func test_buttons_scaled_visual_rect_inside_board() -> void:
	var panel := _make_panel()
	panel._apply_open_instant()
	for i in BUTTON_KEYS.size():
		var btn: TextureButton = panel._buttons[BUTTON_KEYS[i]]
		assert_almost_eq(btn.scale.x, ShortcutPanel.BUTTON_SCALE, 0.001, "%s 按钮统一 ×0.8（受控偏离：用户决策 2026-08-22 源设计按钮压板观感不佳）" % BUTTON_KEYS[i])
		var visual_w: float = btn.size.x * btn.scale.x
		assert_lte(visual_w, 88.0, "%s 按钮视觉宽 %.2f ≤ 板宽 92-2x2 边（旧 102.24 压板出框 20px；板 2026-08-22 加宽 92 镶框）" % [BUTTON_KEYS[i], visual_w])
		var left: float = btn.position.x
		var right: float = btn.position.x + visual_w
		assert_gte(left, 704.0, "%s 视觉左缘 %.2f ≥ 板左 704" % [BUTTON_KEYS[i], left])
		assert_lte(right, 796.0, "%s 视觉右缘 %.2f ≤ 板右 796" % [BUTTON_KEYS[i], right])
	# 相邻按钮视觉 rect 垂直不叠（中心距 75/70/75/79 vs 半高和 ≤63）
	for i in range(BUTTON_KEYS.size() - 1):
		var a: TextureButton = panel._buttons[BUTTON_KEYS[i]]
		var b: TextureButton = panel._buttons[BUTTON_KEYS[i + 1]]
		var a_bottom: float = a.position.y + a.size.y * a.scale.y
		assert_lt(a_bottom, b.position.y, "%s 底缘 %.2f < %s 顶缘（间距宽松不叠）" % [BUTTON_KEYS[i], a_bottom, BUTTON_KEYS[i + 1]])
	panel.queue_free()


# toggle ×0.8 后视觉宽 ≤ 板宽（旧 88.98 比板宽 82 大 7px，"黑色边框宽度不够"根源）。
func test_toggle_scaled_fits_board_width() -> void:
	var panel := _make_panel()
	for toggle in [panel._toggle_down, panel._toggle_up]:
		var t: TextureButton = toggle as TextureButton
		assert_almost_eq(t.scale.x, ShortcutPanel.BUTTON_SCALE, 0.001, "toggle 统一 ×0.8")
		var visual_w: float = t.size.x * t.scale.x
		assert_lte(visual_w, 82.0, "toggle 视觉宽 %.2f ≤ 板宽 82（旧 88.98 出框 7px）" % visual_w)
		var center_x: float = t.position.x + visual_w / 2.0
		assert_almost_eq(center_x, 750.0, 0.5, "toggle 视觉中心 x=750（受控偏离：随板整体右移 10，用户 2026-08-22 指示）")
	panel.queue_free()
