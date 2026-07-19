# asset_placer.gd
# 放置层：单件/路径/批量放置 MeshInstance3D + batch 原子 undo 聚合。
# v5 fence 端柱由 place_path 构造 item 时注入 seg_params（start_post/end_post），
# create_mesh 直接消费，无需放置层二次重建（原 _inject_fence_posts 已删，命中缓存返同一 mesh 冗余）。
# 移植自 asset-forge scene_placer.gd（删 class_name、_vec3 副本、_save_as_tscn/undo_last；
# undo 改走 _undo_manager.create_action_mixed；_vec3 复用 CommandHelpers.parse_vec3）。
@tool
extends RefCounted

# 同目录 preload（原 asset-forge 的 AssetFactory / PathGenerator）
const AssetFactory = preload("asset_factory.gd")
const PathGenerator = preload("path_generator.gd")
# 上级目录共享工具（向量解析 + 路径遍历检查）
const CommandHelpers = preload("../command_helpers.gd")

# batch 上限（与 asset-forge BATCH_LIMIT 对齐；超限 invalid_params）
const BATCH_LIMIT := 64


# place_one：单件放置 + 一次 create_action_mixed（= 一次 Ctrl+Z）
# 返回 {result:{node_path}} 或 {error:{code,message}}
static func place_one(
	root: Node, undo_mgr: Node, shape: String, params: Dictionary,
	material: Variant, node_name: String, parent_path: String, request_id: int
) -> Dictionary:
	if root == null:
		return {"error": {"code": "INVALID_PARAMS", "message": "root 为 null（无活动场景）"}}
	var parent := resolve_parent(root, parent_path)
	if parent == null:
		return {"error": {"code": "PARENT_NOT_FOUND", "message": "parent: %s" % parent_path}}
	var mesh := AssetFactory.create_mesh(shape, params)
	if mesh == null:
		return {"error": {"code": "UNSUPPORTED_SHAPE", "message": shape}}
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.name = unique_name(parent, node_name if node_name != "" else shape)
	node.material_override = AssetFactory.create_material(material)
	_apply_transform(node, params)
	var do_ops := [
		{"type": "method", "target": parent, "method": "add_child", "args": [node]},
		{"type": "method", "target": node, "method": "set_owner", "args": [root]},
		{"type": "reference", "value": node},
	]
	var undo_ops := [{"type": "method", "target": parent, "method": "remove_child", "args": [node]}]
	undo_mgr.create_action_mixed("asset_create_%d" % request_id, do_ops, undo_ops)
	return {"result": {"node_path": str(node.get_path())}}


# place_batch：预校验原子（任一失败零节点落地）+ 全过累积 do_ops/undo_ops + 一次 create_action_mixed
# 返回 {result:{node_paths:[]}} 或 {error:{code,message}}
static func place_batch(root: Node, undo_mgr: Node, items: Array, request_id: int) -> Dictionary:
	if root == null:
		return {"error": {"code": "INVALID_PARAMS", "message": "root 为 null（无活动场景）"}}
	if items.size() > BATCH_LIMIT:
		return {"error": {"code": "BATCH_LIMIT_EXCEEDED", "message": "batch > %d: %d" % [BATCH_LIMIT, items.size()]}}
	# 预校验原子：任一 item 失败立即返错（零节点落地，不入 undo 栈）
	# 透传 _validate_item 返回的 code（未知 shape → UNSUPPORTED_SHAPE，其余 → INVALID_PARAMS）
	for item in items:
		var verr := _validate_item(root, item)
		if not verr.is_empty():
			return {"error": {"code": verr["code"], "message": verr["message"]}}
	# 全过才执行：累积所有 ops 进一次 create_action_mixed（batch 原子 undo = 一次 Ctrl+Z 全撤）
	var do_ops: Array = []
	var undo_ops: Array = []
	var nodes: Array = []  # 暂存 node，commit 后回填 path（add_child 后 get_path 才有效）
	for item in items:
		var parent := resolve_parent(root, String(item.get("parent", "")))
		var mesh := AssetFactory.create_mesh(String(item["shape"]), item.get("params", {}))
		# mesh 已在 _validate_item 预校验非 null，此处必非 null
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.name = unique_name(parent, String(item.get("name", String(item["shape"]))))
		node.material_override = AssetFactory.create_material(item.get("material", null))
		_apply_transform(node, item)
		# v5 端柱：place_path 构造 item 时已把 seg_params.start_post/end_post 设进 params，
		# 上方 create_mesh 已用这些参数生成正确 fence mesh（_post_xs 控制）。
		# 单件 fence（place_one）不走 place_batch，params 无此二键 → make_fence 默认两端 true 零回归。
		do_ops.append_array([
			{"type": "method", "target": parent, "method": "add_child", "args": [node]},
			{"type": "method", "target": node, "method": "set_owner", "args": [root]},
			{"type": "reference", "value": node},
		])
		undo_ops.append({"type": "method", "target": parent, "method": "remove_child", "args": [node]})
		nodes.append(node)
	undo_mgr.create_action_mixed("asset_batch_%d" % request_id, do_ops, undo_ops)
	# create_action_mixed 已 commit（do_ops 中 add_child 已执行），node 已挂载 → get_path() 有效
	var node_paths: Array = []
	for node in nodes:
		node_paths.append(str(node.get_path()))
	return {"result": {"node_paths": node_paths}}


# place_path：调 PathGenerator.sample 构造 items → place_batch
# continuous + shape=ramp 返 UNSUPPORTED_SHAPE（v6 ramp 高度衔接阻塞，方案 A）
# 返回 {result:{node_paths:[]}} 或 {error:{code,message}}
static func place_path(
	root: Node, undo_mgr: Node, shape: String, params: Dictionary, material: Variant,
	points: Array, mode: String, spacing: float, count: int, align: String,
	align_vertices: bool, request_id: int
) -> Dictionary:
	if mode == "continuous" and shape == "ramp":
		return {"error": {"code": "UNSUPPORTED_SHAPE", "message": "continuous ramp 阻塞（方案 A：上游 make_ramp CRITICAL 未修）"}}
	if root == null:
		return {"error": {"code": "INVALID_PARAMS", "message": "root 为 null（无活动场景）"}}
	var segments := PathGenerator.sample(points, mode, spacing, count, align, align_vertices)
	if segments.is_empty():
		return {"error": {"code": "INVALID_PARAMS", "message": "path 采样空（points<2 / 总长 0 / 参数非法）"}}
	# 构造 items（每段注入 position/rotation/length）
	var items: Array = []
	var seg_count: int = segments.size()
	for i in seg_count:
		var seg: Dictionary = segments[i]
		var seg_params: Dictionary = params.duplicate()
		seg_params["length"] = float(seg["length"])
		# v5 fence 端柱共享：所有段保首柱（=接缝柱），仅末段保末柱（=终点柱），
		# 其他段去末柱（避免与下段首柱重叠 z-fighting）。单件 fence 不走此分支，默认两端 true 零回归。
		if shape == "fence" and mode == "continuous":
			seg_params["start_post"] = true
			seg_params["end_post"] = i == seg_count - 1
		var item := {
			"shape": shape,
			"params": seg_params,
			"material": material,
			"name": shape,  # place_batch 内 unique_name 自动去重 _001/_002...
			"position": seg["position"],
			"rotation": seg["rotation"],  # PathGenerator 产出角度制（rad_to_deg），_apply_transform 用 rotation_degrees
			"parent": "",
		}
		items.append(item)
	return place_batch(root, undo_mgr, items, request_id)


# --- 辅助 ---

# unique_name：base sanitize（非 [A-Za-z0-9_-] → _，含 asset-forge _sanitize_name 允许的 -）+ 碰撞自增 _001
static func unique_name(parent: Node, base: String) -> String:
	var nm := _sanitize_name(base)
	if parent.get_node_or_null(NodePath(nm)) == null:
		return nm
	var i := 1
	while i <= 1000:
		var cand := "%s_%03d" % [nm, i]
		if parent.get_node_or_null(NodePath(cand)) == null:
			return cand
		i += 1
	return "%s_%d" % [nm, Time.get_ticks_msec()]


# resolve_parent：绝对路径剥首段（若=root.name）+ 相对路径都吃；无效返 null
# 复用 CommandHelpers.has_path_traversal（对齐 node_commands.gd:52 防御深度）
static func resolve_parent(root: Node, parent_path: String) -> Node:
	if parent_path.is_empty():
		return root
	if CommandHelpers.has_path_traversal(parent_path):
		return null
	if parent_path.begins_with("/"):
		# 绝对路径 /Root/Xxx：剥首段（若=root.name）后相对解析，兼容编辑器与 headless
		var parts := parent_path.substr(1).split("/", false)
		if parts.size() == 0:
			return root
		if String(parts[0]) == root.name:
			parts.remove_at(0)
		if parts.size() == 0:
			return root
		return root.get_node_or_null(NodePath("/".join(parts)))
	return root.get_node_or_null(NodePath(parent_path))


# _apply_transform：从 params/item 读 position/rotation/scale 设节点 transform
# IMPORTANT: rotation 是角度制（PathGenerator rad_to_deg 产出 + params.rotation 约定角度）
# 必须用 node.rotation_degrees，禁止 node.rotation（弧度，会错 57.3 倍）
static func _apply_transform(node: Node3D, d: Variant) -> void:
	if not (d is Dictionary):
		return
	var dict: Dictionary = d
	if dict.has("position"):
		node.position = CommandHelpers.parse_vec3(dict["position"])
	if dict.has("rotation"):
		# 角度制：PathGenerator.sample rotation 字段 + 直传 params.rotation 均为角度
		node.rotation_degrees = CommandHelpers.parse_vec3(dict["rotation"])
	if dict.has("scale"):
		node.scale = CommandHelpers.parse_vec3(dict["scale"])


# _validate_item：预校验单 item（shape/params/material/parent），返结构化错误（空 Dictionary=合法）
# 区分错误码：未知 shape → UNSUPPORTED_SHAPE（与单件 place_one 对齐 spec §5）；其余校验失败 → INVALID_PARAMS
# batch 原子保证：任一失败零节点落地
static func _validate_item(root: Node, item: Variant) -> Dictionary:
	if not (item is Dictionary):
		return {"code": "INVALID_PARAMS", "message": "item 非 Dictionary"}
	var d: Dictionary = item
	if not d.has("shape"):
		return {"code": "INVALID_PARAMS", "message": "item 缺 shape 字段"}
	var shape := String(d["shape"])
	var params: Dictionary = d.get("params", {})
	# shape 校验：create_mesh 返 null = 未知 shape（10 种以外）→ UNSUPPORTED_SHAPE
	var mesh := AssetFactory.create_mesh(shape, params)
	if mesh == null:
		return {"code": "UNSUPPORTED_SHAPE", "message": "未知 shape: %s" % shape}
	# parent 校验（若提供）
	var parent_path := String(d.get("parent", ""))
	if parent_path != "":
		if CommandHelpers.has_path_traversal(parent_path):
			return {"code": "INVALID_PARAMS", "message": "parent 路径含遍历（..）: %s" % parent_path}
		if resolve_parent(root, parent_path) == null:
			return {"code": "INVALID_PARAMS", "message": "parent 未找到: %s" % parent_path}
	# material 不强校验（create_material 三态 + null 都吃，非法回退 default）
	return {}


# _sanitize_name：节点名 sanitize（留 [A-Za-z0-9_-]，其余替 _；空回 "asset"）
# 与 asset-forge scene_placer._sanitize_name 一致（含允许的 -）
static func _sanitize_name(nm: String) -> String:
	var sanitized := ""
	for ch in nm:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			sanitized += ch
		else:
			sanitized += "_"
	if sanitized.is_empty():
		sanitized = "asset"
	return sanitized
