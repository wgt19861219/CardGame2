extends GutTest
# EventBus 单测：RefCounted 信号总线，零 Node 依赖。

func test_emit_triggers_data_changed() -> void:
	var bus := EventBus.new()
	watch_signals(bus)
	bus.emit_data_changed(&"hero")
	assert_signal_emitted(bus, "data_changed", "emit 应触发 data_changed")
	assert_signal_emitted_with_parameters(bus, "data_changed", [&"hero"])

func test_no_dependencies_on_node() -> void:
	# 纯 RefCounted 可在无场景树环境下 new + 使用
	var bus := EventBus.new()
	assert_not_null(bus, "EventBus 可独立实例化")
	bus.emit_data_changed(&"wallet")  # 不应崩溃
	pass_test("EventBus 无 Node 依赖")
