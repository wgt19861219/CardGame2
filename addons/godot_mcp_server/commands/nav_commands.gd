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

func handle_nav_create_region(params: Dictionary, request_id: int) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_name: String = params.get("name", "NavRegion")
	var parent_path: String = params.get("parent", "")
	var parent_node: Node = CommandHelpers.find_node(root, parent_path) if parent_path != "" else root
	if parent_node == null:
		return {"error": {"code": -32002, "message": "Parent not found: " + parent_path}}

	var nav = NavigationRegion3D.new()
	nav.name = node_name

	var pos = params.get("position")
	if pos != null and pos is Dictionary:
		nav.position = Vector3(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)), float(pos.get("z", 0.0)))

	# P0-2 修复: mesh 在入栈前初始化(附着 nav, 随 reference 保护, undo/redo 不丢)
	var mesh = NavigationMesh.new()
	mesh.geometry_parsed_collision_mask = 0xFFFFFFFF
	nav.navigation_mesh = mesh

	var want_bake: bool = params.get("bake", false)
	var bake_result: bool = false
	if _undo_manager != null:
		var do_ops: Array = [
			{"type": "method", "target": parent_node, "method": "add_child", "args": [nav]},
			{"type": "method", "target": nav, "method": "set_owner", "args": [root]},
			{"type": "reference", "value": nav}
		]
		if want_bake:
			# P1 修复: bake 作为 do_method 入 undo 栈(commit 时执行, redo 重 bake),
			# 取代原 action 外单独 bake —— 避免 Ctrl+Z 撤 add_node 后 bake 残留、redo
			# 不重 bake 的游离态。undo 无清空 method, 但 nav 被 reference 保护且 redo
			# 总是 fresh bake, undo→redo 周期内 mesh 状态一致。
			do_ops.append({"type": "method", "target": nav, "method": "bake_navigation_mesh", "args": []})
		_undo_manager.create_action_mixed("Create Nav Region (req:%d)" % request_id, do_ops,
			[
				{"type": "method", "target": parent_node, "method": "remove_child", "args": [nav]}
			])
		# commit_action 已执行 do_methods(含 bake), 读结果
		bake_result = want_bake and nav.navigation_mesh != null
	else:
		parent_node.add_child(nav)
		nav.owner = root
		if want_bake:
			nav.bake_navigation_mesh()
			bake_result = nav.navigation_mesh != null

	return {"result": {"node_path": str(nav.get_path()), "type": "NavigationRegion3D", "baked": bake_result}}

func handle_nav_bake_mesh(params: Dictionary) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var node = CommandHelpers.find_node(root, node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + node_path}}
	if not (node is NavigationRegion3D):
		return {"error": {"code": -32004, "message": "Node is not a NavigationRegion3D: " + node_path}}

	node.bake_navigation_mesh()
	var success = node.navigation_mesh != null
	return {"result": {"node": node_path, "success": success, "status": "bake_completed"}}

func handle_nav_create_agent(params: Dictionary, request_id: int) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_name: String = params.get("name", "NavAgent")
	var parent_path: String = params.get("parent", "")
	var parent_node: Node = CommandHelpers.find_node(root, parent_path) if parent_path != "" else root
	if parent_node == null:
		return {"error": {"code": -32002, "message": "Parent not found: " + parent_path}}

	var agent = NavigationAgent3D.new()
	agent.name = node_name

	var target_pos = params.get("target_position")
	if target_pos != null and target_pos is Dictionary:
		agent.target_position = Vector3(float(target_pos.get("x", 0.0)), float(target_pos.get("y", 0.0)), float(target_pos.get("z", 0.0)))

	agent.path_desired_distance = float(params.get("path_desired_distance", 0.5))
	agent.target_desired_distance = float(params.get("target_desired_distance", 1.0))
	agent.avoidance_enabled = params.get("avoidance_enabled", false)

	if _undo_manager != null:
		_undo_manager.create_action_mixed("Create Nav Agent (req:%d)" % request_id,
			[
				{"type": "method", "target": parent_node, "method": "add_child", "args": [agent]},
				{"type": "method", "target": agent, "method": "set_owner", "args": [root]},
				{"type": "reference", "value": agent}
			],
			[
				{"type": "method", "target": parent_node, "method": "remove_child", "args": [agent]}
			]
		)
	else:
		parent_node.add_child(agent)
		agent.owner = root

	return {"result": {"node_path": str(agent.get_path()), "type": "NavigationAgent3D"}}

func handle_nav_set_params(params: Dictionary) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var node = CommandHelpers.find_node(root, node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + node_path}}
	if not (node is NavigationAgent3D):
		return {"error": {"code": -32004, "message": "Node is not a NavigationAgent3D: " + node_path}}

	var raw_params = params.get("params", {})
	if raw_params == null or not (raw_params is Dictionary):
		return {"error": {"code": -32004, "message": "params must be a dictionary"}}

	var agent: NavigationAgent3D = node
	var updated = []

	if raw_params.has("path_desired_distance"):
		agent.path_desired_distance = float(raw_params["path_desired_distance"])
		updated.append("path_desired_distance")
	if raw_params.has("target_desired_distance"):
		agent.target_desired_distance = float(raw_params["target_desired_distance"])
		updated.append("target_desired_distance")
	if raw_params.has("radius"):
		agent.radius = float(raw_params["radius"])
		updated.append("radius")
	if raw_params.has("height"):
		agent.height = float(raw_params["height"])
		updated.append("height")
	if raw_params.has("max_speed"):
		agent.max_speed = float(raw_params["max_speed"])
		updated.append("max_speed")
	if raw_params.has("avoidance_enabled"):
		agent.avoidance_enabled = raw_params["avoidance_enabled"]
		updated.append("avoidance_enabled")
	if raw_params.has("neighbor_distance"):
		agent.neighbor_distance = float(raw_params["neighbor_distance"])
		updated.append("neighbor_distance")
	if raw_params.has("max_neighbors"):
		agent.max_neighbors = int(raw_params["max_neighbors"])
		updated.append("max_neighbors")
	if raw_params.has("time_horizon_agents"):
		agent.time_horizon_agents = float(raw_params["time_horizon_agents"])
		updated.append("time_horizon_agents")
	if raw_params.has("time_horizon_obstacles"):
		agent.time_horizon_obstacles = float(raw_params["time_horizon_obstacles"])
		updated.append("time_horizon_obstacles")

	return {"result": {"node": node_path, "updated": updated, "status": "params_set"}}

func handle_nav_create_link(params: Dictionary, request_id: int) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_name: String = params.get("name", "NavLink")
	var parent_path: String = params.get("parent", "")
	var parent_node: Node = CommandHelpers.find_node(root, parent_path) if parent_path != "" else root
	if parent_node == null:
		return {"error": {"code": -32002, "message": "Parent not found: " + parent_path}}

	var link = NavigationLink3D.new()
	link.name = node_name

	var start_pos = params.get("start_position")
	if start_pos != null and start_pos is Dictionary:
		link.start_position = Vector3(float(start_pos.get("x", 0.0)), float(start_pos.get("y", 0.0)), float(start_pos.get("z", 0.0)))

	var end_pos = params.get("end_position")
	if end_pos != null and end_pos is Dictionary:
		link.end_position = Vector3(float(end_pos.get("x", 0.0)), float(end_pos.get("y", 0.0)), float(end_pos.get("z", 0.0)))

	link.bidirectional = params.get("bidirectional", true)

	if _undo_manager != null:
		_undo_manager.create_action_mixed("Create Nav Link (req:%d)" % request_id,
			[
				{"type": "method", "target": parent_node, "method": "add_child", "args": [link]},
				{"type": "method", "target": link, "method": "set_owner", "args": [root]},
				{"type": "reference", "value": link}
			],
			[
				{"type": "method", "target": parent_node, "method": "remove_child", "args": [link]}
			]
		)
	else:
		parent_node.add_child(link)
		link.owner = root

	return {"result": {"node_path": str(link.get_path()), "type": "NavigationLink3D", "bidirectional": link.bidirectional}}
