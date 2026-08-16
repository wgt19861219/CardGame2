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
	assert_eq(board.patch_margin_left, 20, "patch_margin_left=20（源 cap x=20）")
	assert_eq(board.patch_margin_top, 47, "patch_margin_top=47（H-y-h=87-20-20）")
	assert_eq(board.patch_margin_right, 92, "patch_margin_right=92（W-x-w=306-20-194）")
	assert_eq(board.patch_margin_bottom, 20, "patch_margin_bottom=20（源 cap y=20）")
	# 清理：销毁当前 board/label + 排空队列（防污染其它 Toast 测试）
	board.queue_free()
	Toast._current_board = null
	if Toast._current_label != null:
		Toast._current_label.queue_free()
		Toast._current_label = null
	while Toast.pending_count() > 0:
		Toast.consume()
