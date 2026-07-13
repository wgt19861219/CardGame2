extends GutTest
# BaseUI 单测：自动订阅/退订 EventBus.data_changed，治信号泄漏。

class CountingUI:
	extends BaseUI
	var count: int = 0
	func _on_data_changed(_scope: StringName) -> void:
		count += 1

func test_setup_subscribes_to_data_changed() -> void:
	var bus := EventBus.new()
	var ui := CountingUI.new()
	add_child_autofree(ui)
	ui.setup(bus)
	bus.emit_data_changed(&"hero")
	assert_eq(ui.count, 1, "setup 后应收到一次变更")

func test_exit_tree_unsubscribes() -> void:
	var bus := EventBus.new()
	var ui := CountingUI.new()
	add_child_autofree(ui)
	ui.setup(bus)
	bus.emit_data_changed(&"hero")
	assert_eq(ui.count, 1)
	remove_child(ui)  # 触发 _exit_tree 退订，autofree 负责回收
	bus.emit_data_changed(&"hero")
	assert_eq(ui.count, 1, "退出树后不应再收到（已退订）")

func test_distinct_instances_independent() -> void:
	var bus := EventBus.new()
	var ui_a := CountingUI.new()
	var ui_b := CountingUI.new()
	add_child_autofree(ui_a)
	add_child_autofree(ui_b)
	ui_a.setup(bus)
	ui_b.setup(bus)
	bus.emit_data_changed(&"hero")
	assert_eq(ui_a.count, 1, "实例 A 各收一次")
	assert_eq(ui_b.count, 1, "实例 B 各收一次")
