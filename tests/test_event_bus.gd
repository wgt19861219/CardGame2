extends GutTest
# EventBus 单测：RefCounted 信号总线，零 Node 依赖。
# data_changed 信号已随死链拆除（notify_changed 生产零调用 + 唯一监听者从未收到，
# 见 审查报告-架构评估与重构方案-2026-08-14.md T1）。

func test_emit_triggers_tutorial_step() -> void:
	var bus := EventBus.new()
	watch_signals(bus)
	bus.emit_tutorial_step(&"EE_hero_detail")
	assert_signal_emitted(bus, "tutorial_step", "emit 应触发 tutorial_step")
	assert_signal_emitted_with_parameters(bus, "tutorial_step", [&"EE_hero_detail"])

func test_no_dependencies_on_node() -> void:
	# 纯 RefCounted 可在无场景树环境下 new + 使用
	var bus := EventBus.new()
	assert_not_null(bus, "EventBus 可独立实例化")
	bus.emit_feature_unlocked(&"wallet")  # 不应崩溃
	pass_test("EventBus 无 Node 依赖")
