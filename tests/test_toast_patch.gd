extends GutTest
## Toast board 九宫格守卫（批 2 Task 8）。
## 源 announce/toast.lua:36 createScale9Sprite toast_bg.png capInsets CCRectMake(20,20,194,20)，
## 贴图 306×87 PIL 实测 → left=20 / bottom=20 / right=306-20-194=92 / top=87-20-20=47（批 1 fde903b 公式）。
## 旧值四边全 20 是 capInsets 直抄错值（批 1 同族 top/bottom 互换 + right 未按贴图宽换算）。


func test_toast_board_patch_margins() -> void:
	Toast.show_message("patch-margin-guard")
	# process_frame 信号先于 node._process 发出，单帧不够；轮询至多 10 帧（headless _process 仍驱动）。
	for i in 10:
		if Toast._current_board != null:
			break
		await get_tree().process_frame
	var board: NinePatchRect = Toast._current_board
	if board == null:
		# 无 board 时也须排空队列（防残留消息污染后续测试的 Toast 状态）。
		while Toast.pending_count() > 0:
			Toast.consume()
		fail_test("10 帧内 board 未建（Toast._process 未消费队列）")
		return
	assert_eq(board.patch_margin_left, 16, "patch_margin_left=20（源 cap x=20）")
	assert_eq(board.patch_margin_top, 37, "patch_margin_top=47（H-y-h=87-20-20）")
	assert_eq(board.patch_margin_right, 72, "patch_margin_right=92（W-x-w=306-20-194）")
	assert_eq(board.patch_margin_bottom, 16, "patch_margin_bottom=20（源 cap y=20）")
	# 清理：销毁当前 board/label + 排空队列（防污染其它 Toast 测试）
	board.queue_free()
	Toast._current_board = null
	if Toast._current_label != null:
		Toast._current_label.queue_free()
		Toast._current_label = null
	while Toast.pending_count() > 0:
		Toast.consume()


# ── 时长+替换语义守卫（2026-08-30，用户反馈「达到上限 toast 持续太久」）──
# 源 toast.lua:60-78：新 showToast removeFromParentAndCleanup 替换正在显示的（无队列串行）；
# 时长 = CCDelayTime(1) 停留 + CCFadeOut(1) 淡出。旧实现 2s 硬停+连点 N 条排队 N×2s。
func test_toast_replaces_instead_of_queueing() -> void:
	Toast._queue.clear()
	Toast._free_current()
	Toast.show_message("第一条")
	Toast.show_message("第二条")   # 替换语义：顶掉第一条（未显示）而非排队
	assert_eq(Toast.pending_count(), 1, "连发两条只留最后一条（替换语义）")
	assert_eq(Toast.consume(), "第二条", "留下的是最新消息")
	Toast._queue.clear()

func test_toast_replaces_showing_message() -> void:
	Toast._queue.clear()
	Toast._free_current()
	Toast.show_message("旧消息")
	for i in 10:
		if Toast._current_board != null:
			break
		await get_tree().process_frame
	assert_not_null(Toast._current_board, "旧消息已显示")
	var old_board: NinePatchRect = Toast._current_board
	Toast.show_message("新消息")   # 顶掉正在显示的（源 removeFromParentAndCleanup）
	assert_ne(Toast._current_board, old_board, "显示中的 board 被替换")
	assert_eq(Toast.pending_count(), 1, "新消息入队待显示")
	# 清理
	Toast._queue.clear()
	if Toast._current_board != null:
		Toast._current_board.queue_free()
		Toast._current_board = null
		Toast._current_label = null

func test_toast_hold_then_fade_timing() -> void:
	Toast._queue.clear()
	Toast._free_current()
	Toast.show_message("计时守卫")
	for i in 10:
		if Toast._current_board != null:
			break
		await get_tree().process_frame
	var board: NinePatchRect = Toast._current_board
	if board == null:
		fail_test("board 未建")
		return
	assert_almost_eq(board.modulate.a, 1.0, 0.05, "显示初 alpha=1")
	await get_tree().create_timer(1.2).timeout   # 过 HOLD(1.0) 进入淡出 0.2s
	assert_lt(board.modulate.a, 0.9, "1.2s 时已开始淡出（HOLD=1s）")
	assert_gt(board.modulate.a, 0.5, "淡出早期未过半（FADE=1s 渐变非硬切）")
	await get_tree().create_timer(1.1).timeout   # 过 HOLD+FADE 全程
	var alive: bool = is_instance_valid(board) and board.is_inside_tree()
	assert_true((not alive) or board.modulate.a <= 0.05,
		"2.1s 后已淡出完毕/回收（总时长 2s 含淡出）")
	# 清理（防污染后续测试）
	Toast._queue.clear()
	Toast._free_current()
