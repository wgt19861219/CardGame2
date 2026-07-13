extends Node

var _plugin: EditorPlugin

func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func create_action(request_id: int, do_methods: Array, undo_methods: Array) -> void:
	var undo_redo = _plugin.get_undo_redo()
	undo_redo.create_action("MCP: op_%d" % request_id)
	for m in do_methods:
		_add_method_call(undo_redo, "do", m)
	for m in undo_methods:
		_add_method_call(undo_redo, "undo", m)
	undo_redo.commit_action()


## 创建带 property 操作的 undo action
func create_action_with_props(request_id: int, do_props: Array, undo_props: Array) -> void:
	var undo_redo = _plugin.get_undo_redo()
	undo_redo.create_action("MCP: op_%d" % request_id)
	for p in do_props:
		undo_redo.add_do_property(p.target, p.property, p.value)
	for p in undo_props:
		undo_redo.add_undo_property(p.target, p.property, p.value)
	undo_redo.commit_action()


## 创建混合 action（methods + properties + references）
## do_ops/undo_ops 中每个元素是 Dictionary，格式:
## {"type": "method", "target": Object, "method": String, "args": Array}
## {"type": "property", "target": Object, "property": String, "value": Variant}
## {"type": "reference", "value": Node}  # Issue 1: add_do_reference 仅限 Node
func create_action_mixed(action_name: String, do_ops: Array, undo_ops: Array) -> void:
	var undo_redo = _plugin.get_undo_redo()
	var label: String = "MCP: %s" % action_name
	undo_redo.create_action(label)
	for op in do_ops:
		_apply_op(undo_redo, "do", op)
	for op in undo_ops:
		_apply_op(undo_redo, "undo", op)
	undo_redo.commit_action()


func _add_method(undo_redo: UndoRedo, mode: String, target: Object, method: String, args: Array) -> void:
	if target == null:
		push_warning("undo_manager: null target for method '%s'" % method)
		return
	var cb := Callable(target, method)
	if args.size() > 0:
		cb = cb.bindv(args)
	if mode == "do":
		undo_redo.add_do_method(cb)
	else:
		undo_redo.add_undo_method(cb)


func _add_method_call(undo_redo: UndoRedo, mode: String, m: Dictionary) -> void:
	var args: Array = m.get("args", [])
	var target: Object = m.target
	var method: String = m.method
	_add_method(undo_redo, mode, target, method, args)


func _apply_op(undo_redo: UndoRedo, mode: String, op: Dictionary) -> void:
	var op_type: String = op.get("type", "method")
	match op_type:
		"method":
			_add_method_call(undo_redo, mode, op)
		"property":
			var target: Object = op.target
			if target == null:
				push_warning("undo_manager: null target for property '%s'" % str(op.get("property", "")))
				return
			var prop: String = str(op.get("property", ""))
			if prop.is_empty():
				push_warning("undo_manager: empty property name, skipping")
				return
			var val = op.value
			if mode == "do":
				undo_redo.add_do_property(target, prop, val)
			else:
				undo_redo.add_undo_property(target, prop, val)
		"reference":
			# Issue 1: add_do_reference/add_undo_reference 仅限 Node，不接受 Resource
			var val = op.value
			if val is Node:
				if mode == "do":
					undo_redo.add_do_reference(val)
				else:
					undo_redo.add_undo_reference(val)
			else:
				push_warning("undo_manager: reference skipped — value is %s, not Node" % ("" if val == null else val.get_class()))
		_:
			push_warning("undo_manager: unknown op type '%s', skipping" % op_type)
