extends Node

var _plugin: EditorPlugin
var _undo_manager: Node

func setup(plugin: EditorPlugin, undo_manager: Node = null) -> void:
	_plugin = plugin
	_undo_manager = undo_manager


func cleanup() -> void:
	# 阶段5(:649): 统一 cleanup 接口(与 incomplete-cleanup-command-nodes fix 一致)。本模块无信号/定时器,释放引用助 GC。
	_plugin = null
	_undo_manager = null



# P0-3 helpers: 统一 property undo 收集模式(4 setter 共用)
func _record_prop(do_ops: Array, undo_ops: Array, target: Object, prop: String, new_val) -> void:
	undo_ops.append({"type": "property", "target": target, "property": prop, "value": target.get(prop)})
	do_ops.append({"type": "property", "target": target, "property": prop, "value": new_val})


func _ensure_mat(node: Object, mat, do_ops: Array, undo_ops: Array):
	if mat != null:
		return mat
	var new_mat = ParticleProcessMaterial.new()
	undo_ops.append({"type": "property", "target": node, "property": "process_material", "value": null})
	do_ops.append({"type": "property", "target": node, "property": "process_material", "value": new_mat})
	return new_mat


func _apply_ops_direct(ops: Array) -> void:
	for op in ops:
		op.target.set(op.property, op.value)


func handle_particles_create(params: Dictionary, request_id: int) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_type: String = params.get("node_type", "GPUParticles3D")
	if node_type != "GPUParticles2D" and node_type != "GPUParticles3D":
		return {"error": {"code": -32004, "message": "Invalid node_type: " + node_type}}

	var node_name: String = params.get("name", "Particles")
	var parent_path: String = params.get("parent", "")
	var parent_node: Node = CommandHelpers.find_node(root, parent_path) if parent_path != "" else root
	if parent_node == null:
		return {"error": {"code": -32002, "message": "Parent not found: " + parent_path}}

	var cls = ClassDB.instantiate(node_type)
	if cls == null:
		return {"error": {"code": -32000, "message": "Cannot instantiate: " + node_type}}
	cls.name = node_name

	var pos = params.get("position")
	if pos != null and pos is Dictionary:
		if node_type == "GPUParticles3D":
			cls.position = Vector3(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)), float(pos.get("z", 0.0)))
		else:
			cls.position = Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))

	if _undo_manager != null:
		_undo_manager.create_action_mixed("Create Particles (req:%d)" % request_id,
			[
				{"type": "method", "target": parent_node, "method": "add_child", "args": [cls]},
				{"type": "method", "target": cls, "method": "set_owner", "args": [root]},
				{"type": "reference", "value": cls}
			],
			[
				{"type": "method", "target": parent_node, "method": "remove_child", "args": [cls]}
			]
		)
	else:
		parent_node.add_child(cls)
		cls.owner = root

	return {"result": {"node_path": str(cls.get_path()), "type": node_type, "status": "created"}}

func handle_particles_set_emission(params: Dictionary, request_id: int = 0) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}
	var node_path: String = params.get("node_path", "")
	var node = CommandHelpers.find_node(root, node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + node_path}}
	if not (node is GPUParticles2D or node is GPUParticles3D):
		return {"error": {"code": -32004, "message": "Node is not a GPUParticles type: " + node.get_class()}}
	var mat = node.process_material
	var do_ops: Array = []
	var undo_ops: Array = []
	var amount = params.get("amount")
	if amount != null:
		_record_prop(do_ops, undo_ops, node, "amount", int(amount))
	var emission_shape: String = params.get("emission_shape", "")
	if emission_shape != "":
		var shape_map = {"point": ParticleProcessMaterial.EMISSION_SHAPE_POINT, "sphere": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "box": ParticleProcessMaterial.EMISSION_SHAPE_BOX, "ring": ParticleProcessMaterial.EMISSION_SHAPE_RING}
		if not shape_map.has(emission_shape):
			return {"error": {"code": -32004, "message": "Invalid emission_shape: " + emission_shape + ". Supported: point, sphere, box, ring"}}
		mat = _ensure_mat(node, mat, do_ops, undo_ops)
		_record_prop(do_ops, undo_ops, mat, "emission_shape", shape_map[emission_shape])
		var radius = params.get("emission_sphere_radius")
		if radius != null:
			_record_prop(do_ops, undo_ops, mat, "emission_sphere_radius", float(radius))
		var extents = params.get("emission_box_extents")
		if extents != null and extents is Dictionary:
			_record_prop(do_ops, undo_ops, mat, "emission_box_extents", Vector3(float(extents.get("x", 1.0)), float(extents.get("y", 1.0)), float(extents.get("z", 1.0))))
	var direction = params.get("direction")
	if direction != null and direction is Dictionary:
		mat = _ensure_mat(node, mat, do_ops, undo_ops)
		_record_prop(do_ops, undo_ops, mat, "direction", Vector3(float(direction.get("x", 0.0)), float(direction.get("y", -1.0)), float(direction.get("z", 0.0))))
	var spread = params.get("spread")
	if spread != null:
		mat = _ensure_mat(node, mat, do_ops, undo_ops)
		_record_prop(do_ops, undo_ops, mat, "spread", float(spread))
	if _undo_manager != null and do_ops.size() > 0:
		_undo_manager.create_action_mixed("Set Particles Emission (req:%d)" % request_id, do_ops, undo_ops)
	elif _undo_manager == null and do_ops.size() > 0:
		_apply_ops_direct(do_ops)
	return {"result": {"node": node_path, "status": "emission_set"}}

func handle_particles_set_process(params: Dictionary, request_id: int = 0) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}
	var node_path: String = params.get("node_path", "")
	var node = CommandHelpers.find_node(root, node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + node_path}}
	if not (node is GPUParticles2D or node is GPUParticles3D):
		return {"error": {"code": -32004, "message": "Node is not a GPUParticles type: " + node.get_class()}}
	var mat = node.process_material
	var do_ops: Array = []
	var undo_ops: Array = []
	var gravity = params.get("gravity")
	if gravity != null and gravity is Dictionary:
		mat = _ensure_mat(node, mat, do_ops, undo_ops)
		_record_prop(do_ops, undo_ops, mat, "gravity", Vector3(float(gravity.get("x", 0.0)), float(gravity.get("y", -9.8)), float(gravity.get("z", 0.0))))
	var speed_scale = params.get("speed_scale")
	if speed_scale != null:
		_record_prop(do_ops, undo_ops, node, "speed_scale", float(speed_scale))
	var explosiveness = params.get("explosiveness")
	if explosiveness != null:
		_record_prop(do_ops, undo_ops, node, "explosiveness", float(explosiveness))
	var randomness = params.get("randomness")
	if randomness != null:
		_record_prop(do_ops, undo_ops, node, "randomness", float(randomness))
	var lifetime = params.get("lifetime")
	if lifetime != null:
		_record_prop(do_ops, undo_ops, node, "lifetime", float(lifetime))
	var damping = params.get("damping")
	if damping != null:
		mat = _ensure_mat(node, mat, do_ops, undo_ops)
		_record_prop(do_ops, undo_ops, mat, "damping", float(damping))
	if _undo_manager != null and do_ops.size() > 0:
		_undo_manager.create_action_mixed("Set Particles Process (req:%d)" % request_id, do_ops, undo_ops)
	elif _undo_manager == null and do_ops.size() > 0:
		_apply_ops_direct(do_ops)
	return {"result": {"node": node_path, "status": "process_set"}}

func handle_particles_load_preset(params: Dictionary, request_id: int = 0) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}
	var node_path: String = params.get("node_path", "")
	var node = CommandHelpers.find_node(root, node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + node_path}}
	if not (node is GPUParticles2D or node is GPUParticles3D):
		return {"error": {"code": -32004, "message": "Node is not a GPUParticles type: " + node.get_class()}}
	var preset: String = params.get("preset", "")
	var presets = {
		"fire": {"amount": 40, "lifetime": 1.5, "gravity": Vector3(0, -5, 0), "spread": 30.0, "explosiveness": 0.3, "damping": 2.0},
		"smoke": {"amount": 20, "lifetime": 3.0, "gravity": Vector3(0, -1, 0), "spread": 10.0, "explosiveness": 0.1, "damping": 3.0},
		"rain": {"amount": 200, "lifetime": 1.0, "gravity": Vector3(0, -20, 0), "spread": 5.0, "direction": Vector3(0, -1, 0)},
		"snow": {"amount": 60, "lifetime": 4.0, "gravity": Vector3(0, -2, 0), "spread": 180.0, "randomness": 0.8},
		"sparkle": {"amount": 30, "lifetime": 0.5, "gravity": Vector3(0, 0, 0), "spread": 180.0, "explosiveness": 0.8},
		"explosion": {"amount": 80, "lifetime": 1.0, "gravity": Vector3(0, -3, 0), "spread": 180.0, "explosiveness": 1.0, "one_shot": true},
	}
	if not presets.has(preset):
		return {"error": {"code": -32004, "message": "Unknown preset: " + preset + ". Available: fire, smoke, rain, snow, sparkle, explosion"}}
	var cfg = presets[preset]
	var mat = node.process_material
	var do_ops: Array = []
	var undo_ops: Array = []
	_record_prop(do_ops, undo_ops, node, "amount", int(cfg.get("amount", 10)))
	_record_prop(do_ops, undo_ops, node, "lifetime", float(cfg.get("lifetime", 1.0)))
	_record_prop(do_ops, undo_ops, node, "explosiveness", float(cfg.get("explosiveness", 0.0)))
	_record_prop(do_ops, undo_ops, node, "randomness", float(cfg.get("randomness", 0.0)))
	if cfg.has("one_shot") and cfg["one_shot"]:
		_record_prop(do_ops, undo_ops, node, "one_shot", true)
	if cfg.has("gravity") or cfg.has("spread") or cfg.has("damping") or cfg.has("direction"):
		mat = _ensure_mat(node, mat, do_ops, undo_ops)
		if cfg.has("gravity"):
			_record_prop(do_ops, undo_ops, mat, "gravity", cfg["gravity"])
		if cfg.has("spread"):
			_record_prop(do_ops, undo_ops, mat, "spread", cfg["spread"])
		if cfg.has("damping"):
			_record_prop(do_ops, undo_ops, mat, "damping", cfg["damping"])
		if cfg.has("direction"):
			_record_prop(do_ops, undo_ops, mat, "direction", cfg["direction"])
	if _undo_manager != null and do_ops.size() > 0:
		_undo_manager.create_action_mixed("Load Particles Preset %s (req:%d)" % [preset, request_id], do_ops, undo_ops)
	elif _undo_manager == null and do_ops.size() > 0:
		_apply_ops_direct(do_ops)
	return {"result": {"node": node_path, "preset": preset, "status": "preset_loaded"}}

func handle_particles_set_material(params: Dictionary, request_id: int = 0) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}
	var node_path: String = params.get("node_path", "")
	var node = CommandHelpers.find_node(root, node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + node_path}}
	if not (node is GPUParticles2D or node is GPUParticles3D):
		return {"error": {"code": -32004, "message": "Node is not a GPUParticles type: " + node.get_class()}}
	# P0-3: 捕获旧材质引用(防 new 覆盖丢失), do 设新/undo 恢复旧
	var old_mat = node.process_material
	var mat = ParticleProcessMaterial.new()
	if _undo_manager != null:
		_undo_manager.create_action_mixed("Set Particles Material (req:%d)" % request_id, [
			{"type": "property", "target": node, "property": "process_material", "value": mat},
		], [
			{"type": "property", "target": node, "property": "process_material", "value": old_mat},
		])
	else:
		node.process_material = mat
	return {"result": {"node": node_path, "material_type": "ParticleProcessMaterial", "status": "material_set"}}
