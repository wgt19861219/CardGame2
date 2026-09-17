extends GutTest

# ConfirmDialog 状态机单射语义守卫（2026-09-17 错误码31 根修配测）：
# confirm() 恰好触发一次回调，CLOSED 后再 confirm/cancel 为 no-op——
# 面板侧依赖此语义保证确认动作唯一执行（防重入双执行）。

func test_confirm_fires_callback_exactly_once() -> void:
	var cd := ConfirmDialog.new()
	add_child_autofree(cd)
	var calls: Array[int] = [0]
	cd.open(func() -> void: calls[0] += 1)
	assert_true(cd.is_open(), "open 后状态 OPEN")
	cd.confirm()
	assert_eq(calls[0], 1, "confirm 恰好触发回调一次")
	assert_false(cd.is_open(), "confirm 后状态 CLOSED")
	cd.confirm()
	cd.cancel()
	assert_eq(calls[0], 1, "CLOSED 后 confirm/cancel 不再触发（单射）")

func test_cancel_fires_cancel_callback_once() -> void:
	var cd := ConfirmDialog.new()
	add_child_autofree(cd)
	var cancels: Array[int] = [0]
	cd.open(Callable(), func() -> void: cancels[0] += 1)
	cd.cancel()
	assert_eq(cancels[0], 1, "cancel 恰好触发取消回调一次")
	assert_false(cd.is_open(), "cancel 后状态 CLOSED")

func test_confirm_without_open_is_noop() -> void:
	var cd := ConfirmDialog.new()
	add_child_autofree(cd)
	var calls: Array[int] = [0]
	cd._on_confirm = func() -> void: calls[0] += 1
	cd.confirm()   # 未 open（state=CLOSED）→ 直接返回不回调
	assert_eq(calls[0], 0, "未 open 时 confirm 不触发回调")
