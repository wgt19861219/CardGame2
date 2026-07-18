extends GutTest

## ShopRefreshConfirm 单测 — 照源 shop.lua:302-313 doClickRefresh showConfirmDialog。
## GDScript lambda 捕获局部变量 by value，用数组 [bool] 引用语义跨 lambda 传递。


func test_set_message_updates_label() -> void:
	var popup := ShopRefreshConfirm.new()
	add_child(popup)
	popup.set_message("花费 50 钻石刷新？")
	assert_eq(popup._msg_label.text, "花费 50 钻石刷新？", "set_message 更新 Label 文本")
	popup.queue_free()


func test_ok_emits_confirmed() -> void:
	var popup := ShopRefreshConfirm.new()
	add_child(popup)
	var emitted := [false]
	popup.confirmed.connect(func() -> void: emitted[0] = true)
	popup._on_ok()
	assert_true(emitted[0], "_on_ok emit confirmed（源 :309 rightHandler）")
	popup.queue_free()


func test_cancel_does_not_emit() -> void:
	var popup := ShopRefreshConfirm.new()
	add_child(popup)
	var emitted := [false]
	popup.confirmed.connect(func() -> void: emitted[0] = true)
	# 重构后子场景 content 挂 panel（child 0）；%CancelBtn unique_name 在 content 子场景内。
	var content: Node = popup.get_child(0)
	var cancel: Button = content.get_node("%CancelBtn")
	cancel.pressed.emit()
	assert_false(emitted[0], "取消不 emit confirmed")
	popup.queue_free()
