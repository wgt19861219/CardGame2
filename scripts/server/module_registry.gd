class_name ModuleRegistry
extends RefCounted

## 模块自注册中心（Logic 层）：收集各玩法 *_module.gd，按依赖拓扑排序后统一 register。
## 各玩法只改自己的 *_module.gd 并声明依赖，骨架（本类）不变，避免并行合并冲突。
## 模块约定：实现 get_dependencies() -> Array[StringName] 与 register(s, bus, data) -> void。
##
## ⚠️ 状态说明（P2-3，2026-07-09 审定）：本类是玩法模块化的 DI 基础设施，有完整单测
## （test_module_registry.gd 拓扑排序/循环检测 + test_instance.gd 集成），但当前各玩法
## handler 直接由对应 manager 实现，尚未串联进本 registry。保留作 DI 基础设施——
## 玩法模块化（*_module.gd 声明依赖 + 统一 register）落地时启用，非死代码。
## 删除需同步改 test_module_registry.gd + test_instance.gd，且丧失未来模块化基础，故保留。

signal module_registered(module_name: StringName)

const _DEPS_KEY := "deps"
const _MODULE_KEY := "module"

var _modules: Dictionary = {}
var _order: Array[StringName] = []
var _initialized: bool = false

## 注册模块。module 须实现 get_dependencies 与 register。
func add(module_name: StringName, module: Object) -> void:
	assert(not _initialized, "初始化后不可添加模块")
	assert(not _modules.has(module_name), "重复注册模块: " + str(module_name))
	assert(module.has_method(&"register"), "模块缺少 register(): " + str(module_name))
	assert(module.has_method(&"get_dependencies"), "模块缺少 get_dependencies(): " + str(module_name))
	_modules[module_name] = {
		_MODULE_KEY: module,
		_DEPS_KEY: module.get_dependencies(),
	}

## 校验依赖完整性 + 无循环，返回 "" 表示 OK，否则错误描述。
func validate() -> String:
	for name in _modules:
		for dep in _modules[name][_DEPS_KEY]:
			if not _modules.has(dep):
				return "模块 " + str(name) + " 依赖未注册的模块: " + str(dep)
	var sorted := _topological_sort()
	if sorted.size() != _modules.size():
		return "检测到模块循环依赖，无法完成拓扑排序"
	return ""

## 校验通过后按拓扑序对每个模块调用 register，返回注册顺序。
func initialize_all(server: Object, event_bus: EventBus, player_data: Object) -> Array[StringName]:
	var err := validate()
	assert(err.is_empty(), err)
	_order = _topological_sort()
	for name in _order:
		var entry: Dictionary = _modules[name]
		var module: Object = entry[_MODULE_KEY]
		module.register(server, event_bus, player_data)
		module_registered.emit(name)
	_initialized = true
	return _order

func get_order() -> Array[StringName]:
	return _order.duplicate()

## Kahn 算法拓扑排序；同入度按名字稳定排序；存在环时返回部分结果（size < 模块数）。
func _topological_sort() -> Array[StringName]:
	var in_degree := {}
	var dependents := {}
	for name in _modules:
		in_degree[name] = 0
		dependents[name] = []
	for name in _modules:
		for dep in _modules[name][_DEPS_KEY]:
			if _modules.has(dep):
				in_degree[name] = int(in_degree[name]) + 1
				(dependents[dep] as Array).append(name)
	var queue: Array[StringName] = []
	for name in in_degree:
		if int(in_degree[name]) == 0:
			queue.append(name)
	queue.sort()
	var sorted: Array[StringName] = []
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		sorted.append(current)
		var unlocked: Array[StringName] = []
		for dependent in dependents[current]:
			in_degree[dependent] = int(in_degree[dependent]) - 1
			if int(in_degree[dependent]) == 0:
				unlocked.append(dependent)
		unlocked.sort()
		queue.append_array(unlocked)
	return sorted
