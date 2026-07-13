class_name InstanceModule
extends RefCounted

## 副本模块自注册（Step 3.2，蓝图 M3 玩法挂载骨架）。
## 符合 ModuleRegistry 约定（get_dependencies + register）。各玩法只改自己的 *_module.gd。

func get_dependencies() -> Array[StringName]:
	return []

func register(_server: Object, _event_bus: EventBus, _player_data: Object) -> void:
	# M3 骨架：注册副本 handler（enter_instance/exit_instance）到 server
	pass
