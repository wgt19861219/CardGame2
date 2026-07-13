extends GutTest
# ModuleRegistry 单测：依赖拓扑排序 + 循环/缺失依赖检测 + register 调用。

class FakeModule:
	extends RefCounted
	var deps: Array = []
	var calls: int = 0
	func register(_server: Object, _event_bus: EventBus, _player_data: Object) -> void:
		calls += 1
	func get_dependencies() -> Array:
		return deps

func _make(deps: Array) -> FakeModule:
	var module := FakeModule.new()
	module.deps = deps
	return module

func test_validate_ok_with_no_deps() -> void:
	var reg := ModuleRegistry.new()
	reg.add(&"A", _make([]))
	reg.add(&"B", _make([]))
	assert_eq(reg.validate(), "", "无依赖应验证通过")

func test_missing_dependency_reported() -> void:
	var reg := ModuleRegistry.new()
	reg.add(&"A", _make([&"X"]))  # X 未注册
	assert_false(reg.validate().is_empty(), "缺失依赖应报错")

func test_dependency_ordering() -> void:
	var reg := ModuleRegistry.new()
	var b := _make([])
	var a := _make([&"B"])
	reg.add(&"A", a)
	reg.add(&"B", b)
	var order := reg.initialize_all(null, EventBus.new(), null)
	assert_lt(order.find(&"B"), order.find(&"A"), "被依赖的 B 应先于 A 注册")

func test_chain_ordering() -> void:
	var reg := ModuleRegistry.new()
	reg.add(&"A", _make([&"B"]))
	reg.add(&"B", _make([&"C"]))
	reg.add(&"C", _make([]))
	var order := reg.initialize_all(null, EventBus.new(), null)
	assert_eq(order.size(), 3, "三个模块全部入序")
	assert_eq(str(order[0]), "C", "链式依赖顺序应为 C→B→A")
	assert_eq(str(order[1]), "B")
	assert_eq(str(order[2]), "A")

func test_circular_dependency_detected() -> void:
	var reg := ModuleRegistry.new()
	reg.add(&"A", _make([&"B"]))
	reg.add(&"B", _make([&"A"]))
	assert_false(reg.validate().is_empty(), "循环依赖应被检测")

func test_register_called_once_per_module() -> void:
	var reg := ModuleRegistry.new()
	var a := _make([])
	var b := _make([&"A"])
	reg.add(&"A", a)
	reg.add(&"B", b)
	reg.initialize_all(null, EventBus.new(), null)
	assert_eq(a.calls, 1, "A 的 register 调一次")
	assert_eq(b.calls, 1, "B 的 register 调一次")
