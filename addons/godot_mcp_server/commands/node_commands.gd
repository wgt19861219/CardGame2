extends Node

var _undo_manager: Node
var _plugin: EditorPlugin

const ALLOWED_NODE_TYPES: Array = [
	"Node3D", "MeshInstance3D", "StaticBody3D", "RigidBody3D",
	"CharacterBody3D", "Camera3D", "Light3D", "DirectionalLight3D",
	"OmniLight3D", "SpotLight3D", "CollisionShape3D", "RayCast3D",
	"Area3D", "Marker3D", "PathFollow3D", "VisibleOnScreenNotifier3D",
	"Node", "Node2D", "Sprite2D", "AnimatedSprite2D",
	"CollisionShape2D", "Area2D", "RigidBody2D", "CharacterBody2D",
	"AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D",
	"AnimationPlayer", "AnimationTree", "Timer",
]

func setup(plugin: EditorPlugin, undo_manager: Node) -> void:
	_undo_manager = undo_manager
	_plugin = plugin

# I-06: null-safe EditorInterface accessor
# 4.7: EditorInterface 不再作为 Engine singleton 注册,改用 EditorPlugin.get_editor_interface()。
func _get_ei() -> EditorInterface:
	if _plugin == null:
		push_error("[MCP] EditorPlugin not available")
		return null
	return _plugin.get_editor_interface()

func handle_add_node(params: Dictionary, request_id: int) -> Dictionary:
	var ei := _get_ei()
	if ei == null: return {"error": {"code": -32000, "message": "EditorInterface not available"}}
	var root = ei.get_edited_scene_root()
	if not root:
		return {"error": {"code": -32003, "message": "No scene loaded"}}

	var node_type: String = params.get("node_type", "Node")
	var node_name: String = params.get("node_name", "NewNode")
	var parent_path: String = params.get("parent_node_path", "")

	# I-5: node_name 字符白名单(与 TS 端 addNode 的 ^[A-Za-z0-9_]+$ 对齐),防特殊字符/换行污染 .tscn 节点名属性。
	var _name_re := RegEx.create_from_string("^[A-Za-z0-9_]+$")
	if node_name.is_empty() or not _name_re.search(node_name):
		return {"error": {"code": -32004, "message": "Invalid node name: %s" % node_name}}

	if not _is_allowed_node_type(node_type):
		return {"error": {"code": -32004, "message": "Blocked node type: %s" % node_type}}

	var parent_node: Node = root
	if not parent_path.is_empty():
		# I-5: 复用 CommandHelpers.has_path_traversal(与 scene_commands/ui_commands 防御深度对齐)。
		# Godot get_node_or_null 受场景树结构限制无法逃出 root,但显式拒绝 .. 段与项目防御一致。
		if CommandHelpers.has_path_traversal(parent_path):
			return {"error": {"code": -32002, "message": "Invalid parent path (traversal): %s" % parent_path}}
		parent_node = root.get_node_or_null(parent_path)  # IMP-1: null-safe; get_node() pushes error on missing path
		if not parent_node:
			return {"error": {"code": -32002, "message": "Parent not found: %s" % parent_path}}

	var cls = ClassDB.instantiate(node_type)
	if not cls:
		return {"error": {"code": -32000, "message": "Cannot instantiate: %s" % node_type}}
	cls.name = node_name

	if _undo_manager != null:
		_undo_manager.create_action_mixed(request_id,
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
	return {"result": {"node_path": str(cls.get_path()), "status": "created"}}

func _is_allowed_node_type(node_type: String) -> bool:
	# I-4: 严格白名单——仅允许 ALLOWED_NODE_TYPES 精确匹配,不再用 is_parent_class 兜底。
	# 原兜底放行任意 Node 子类(含第三方 addon 的 class_name 脚本),实例化时触发其 _ready()/_init()
	# 执行任意 GDScript。需自定义类型请改用 execute_gdscript 或编辑器手动操作。
	return node_type in ALLOWED_NODE_TYPES
