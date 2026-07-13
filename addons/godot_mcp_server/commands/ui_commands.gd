extends Node

var _plugin: EditorPlugin
var _undo_manager: Node

const BLOCKED_PROPS: Array = ["script", "owner", "name", "parent", "children", "tree", "meta", "process_mode", "process_priority",
	"process_input", "process_unhandled_input", "process_unhandled_key_input",
	"process_internal", "physics_process_mode", "input_event", "ready",
	"material", "texture", "mesh", "collision_layer", "collision_mask",
	"collision_priority", "transform", "global_transform"]

# IMPORTANT-14 (review): 严格白名单替代 is_parent_class(node_type,"Control") 兜底。
# 原写法放行任意 Control 子类(含第三方 class_name 脚本),实例化时触发其 _init/_ready 执行任意 GDScript。
# 与 node_commands.gd ALLOWED_NODE_TYPES(I-4)对齐;须与 TS 端 ui_create_control 的 29 种 Control 同步。
const ALLOWED_CONTROL_TYPES: Array = [
	"Button", "Label", "Panel", "LineEdit", "TextEdit", "RichTextLabel",
	"LinkButton", "HSlider", "VSlider", "CheckBox", "CheckButton",
	"OptionButton", "SpinBox", "ProgressBar", "TextureRect", "ColorPickerButton",
	"TabContainer", "Tree", "ItemList", "MarginContainer", "HBoxContainer",
	"VBoxContainer", "GridContainer", "CenterContainer", "ScrollContainer",
	"PanelContainer", "HSplitContainer", "VSplitContainer", "NinePatchRect",
]

func setup(plugin: EditorPlugin, undo_manager: Node = null) -> void:
	_plugin = plugin
	_undo_manager = undo_manager


func cleanup() -> void:
	# 阶段5(:649): 统一 cleanup 接口(与 incomplete-cleanup-command-nodes fix 一致)。本模块无信号/定时器,释放引用助 GC。
	_plugin = null
	_undo_manager = null

# ─── ui_create_control ──────────────────────────────────────────────────────

func handle_ui_create_control(params: Dictionary, request_id: int) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_type: String = params.get("node_type", "Label")
	var node_name: String = params.get("node_name", "Control")
	var parent_path: String = params.get("parent_node_path", "")
	var parent_node: Node = CommandHelpers.find_node(root, parent_path) if parent_path != "" else root
	if parent_node == null:
		return {"error": {"code": -32002, "message": "Parent not found: " + parent_path}}

	if not (node_type in ALLOWED_CONTROL_TYPES):
		return {"error": {"code": -32004, "message": "Invalid or blocked Control type: " + node_type}}

	var node = ClassDB.instantiate(node_type)
	if node == null:
		return {"error": {"code": -32000, "message": "Cannot instantiate: " + node_type}}
	node.name = node_name

	var properties = params.get("properties")
	if properties != null and properties is Dictionary:
		for key in properties:
			if key.begins_with("_") or key in BLOCKED_PROPS:
				continue
			if not key is String:
				continue
			if ":" in key or "/" in key:
				continue
			var val = properties[key]
			if val is Object:
				continue
			if CommandHelpers.property_exists_and_type_ok(node, key, val):
				node.set(key, val)

	if _undo_manager != null:
		_undo_manager.create_action_mixed("Create UI Control (req:%d)" % request_id,
			[
				{"type": "method", "target": parent_node, "method": "add_child", "args": [node]},
				{"type": "method", "target": node, "method": "set_owner", "args": [root]},
				{"type": "reference", "value": node}
			],
			[
				{"type": "method", "target": parent_node, "method": "remove_child", "args": [node]}
			]
		)
	else:
		parent_node.add_child(node)
		node.owner = root

	return {"result": {"type": node_type, "name": node_name, "path": str(node.get_path()), "status": "created"}}

# ─── ui_set_layout ──────────────────────────────────────────────────────────

func handle_ui_set_layout(params: Dictionary, request_id: int = 0) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var node = CommandHelpers.find_node(root, node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + node_path}}
	if not (node is Control):
		return {"error": {"code": -32004, "message": "Node is not a Control: " + node.get_class()}}

	var ctrl: Control = node

	var anchors = params.get("anchors")
	if anchors != null and anchors is Dictionary:
		if anchors.has("left"):
			ctrl.anchor_left = float(anchors["left"])
		if anchors.has("right"):
			ctrl.anchor_right = float(anchors["right"])
		if anchors.has("top"):
			ctrl.anchor_top = float(anchors["top"])
		if anchors.has("bottom"):
			ctrl.anchor_bottom = float(anchors["bottom"])

	var offsets = params.get("offsets")
	if offsets != null and offsets is Dictionary:
		if offsets.has("left"):
			ctrl.offset_left = float(offsets["left"])
		if offsets.has("right"):
			ctrl.offset_right = float(offsets["right"])
		if offsets.has("top"):
			ctrl.offset_top = float(offsets["top"])
		if offsets.has("bottom"):
			ctrl.offset_bottom = float(offsets["bottom"])

	var min_size = params.get("min_size")
	if min_size != null and min_size is Dictionary:
		if min_size.has("x"):
			ctrl.custom_minimum_size = Vector2(float(min_size["x"]), ctrl.custom_minimum_size.y)
		if min_size.has("y"):
			ctrl.custom_minimum_size = Vector2(ctrl.custom_minimum_size.x, float(min_size["y"]))

	var custom_minimum_size = params.get("custom_minimum_size")
	if custom_minimum_size != null and custom_minimum_size is Dictionary:
		var cx = float(custom_minimum_size.get("x", ctrl.custom_minimum_size.x))
		var cy = float(custom_minimum_size.get("y", ctrl.custom_minimum_size.y))
		ctrl.custom_minimum_size = Vector2(cx, cy)

	var grow_direction: String = params.get("grow_direction", "")
	if grow_direction != "":
		match grow_direction:
			"both":
				ctrl.grow_horizontal = Control.GROW_DIRECTION_BOTH
				ctrl.grow_vertical = Control.GROW_DIRECTION_BOTH
			"up":
				ctrl.grow_vertical = Control.GROW_DIRECTION_BEGIN
			"down":
				ctrl.grow_vertical = Control.GROW_DIRECTION_END
			"left":
				ctrl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			"right":
				ctrl.grow_horizontal = Control.GROW_DIRECTION_END
			_:
				return {"error": {"code": -32004, "message": "Invalid grow_direction: " + grow_direction}}

	return {"result": {"node": node_path, "status": "layout_set"}}

# ─── ui_get_layout ──────────────────────────────────────────────────────────

func handle_ui_get_layout(params: Dictionary) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var node = CommandHelpers.find_node(root, node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + node_path}}
	if not (node is Control):
		return {"error": {"code": -32004, "message": "Node is not a Control: " + node.get_class()}}

	var ctrl: Control = node
	var info = {
		"anchor_left": ctrl.anchor_left,
		"anchor_right": ctrl.anchor_right,
		"anchor_top": ctrl.anchor_top,
		"anchor_bottom": ctrl.anchor_bottom,
		"offset_left": ctrl.offset_left,
		"offset_right": ctrl.offset_right,
		"offset_top": ctrl.offset_top,
		"offset_bottom": ctrl.offset_bottom,
		"global_position": {"x": ctrl.global_position.x, "y": ctrl.global_position.y},
		"size": {"x": ctrl.size.x, "y": ctrl.size.y},
	}

	return {"result": {"node": node_path, "layout": info}}

# ─── ui_anchor_preset ───────────────────────────────────────────────────────

func handle_ui_anchor_preset(params: Dictionary, request_id: int = 0) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var node = CommandHelpers.find_node(root, node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + node_path}}
	if not (node is Control):
		return {"error": {"code": -32004, "message": "Node is not a Control: " + node.get_class()}}

	var preset: String = params.get("preset", "")
	var preset_map = {
		"top_left": Control.PRESET_TOP_LEFT,
		"top_right": Control.PRESET_TOP_RIGHT,
		"bottom_left": Control.PRESET_BOTTOM_LEFT,
		"bottom_right": Control.PRESET_BOTTOM_RIGHT,
		"center_left": Control.PRESET_CENTER_LEFT,
		"center_top": Control.PRESET_CENTER_TOP,
		"center_right": Control.PRESET_CENTER_RIGHT,
		"center_bottom": Control.PRESET_CENTER_BOTTOM,
		"center": Control.PRESET_CENTER,
		"left_wide": Control.PRESET_LEFT_WIDE,
		"top_wide": Control.PRESET_TOP_WIDE,
		"right_wide": Control.PRESET_RIGHT_WIDE,
		"bottom_wide": Control.PRESET_BOTTOM_WIDE,
		"vcenter_wide": Control.PRESET_VCENTER_WIDE,
		"hcenter_wide": Control.PRESET_HCENTER_WIDE,
		"full_rect": Control.PRESET_FULL_RECT,
	}
	if not preset_map.has(preset):
		return {"error": {"code": -32004, "message": "Unknown preset: " + preset + ". Available: " + str(preset_map.keys())}}

	var ctrl: Control = node
	ctrl.set_anchors_preset(preset_map[preset])

	return {"result": {"node": node_path, "preset": preset, "status": "preset_applied"}}

# ─── ui_set_theme ───────────────────────────────────────────────────────────

func handle_ui_set_theme(params: Dictionary) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var node = CommandHelpers.find_node(root, node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + node_path}}
	if not (node is Control):
		return {"error": {"code": -32004, "message": "Node is not a Control: " + node.get_class()}}

	var ctrl: Control = node
	var action: String = params.get("action", "")

	match action:
		"create":
			var theme = Theme.new()
			ctrl.theme = theme
		"set_params":
			var theme = ctrl.theme
			if theme == null:
				return {"error": {"code": -32004, "message": "Node has no theme assigned"}}
			var p = params.get("params")
			if p != null and p is Dictionary:
				for key in p:
					if not key is String:
						continue
					if ":" in key or "/" in key:
						continue
					var val = p[key]
					if val is Object:
						continue
					theme.set(key, val)
		"save":
			var theme = ctrl.theme
			if theme == null:
				return {"error": {"code": -32004, "message": "Node has no theme to save"}}
			var save_path: String = params.get("theme_path", "")
			if save_path == "":
				return {"error": {"code": -32004, "message": "theme_path is required for save action"}}
			if not _validate_resource_path(save_path):
				return {"error": {"code": -32004, "message": "theme_path must start with res:// or user://: " + save_path}}
			var err = ResourceSaver.save(theme, save_path)
			if err != OK:
				return {"error": {"code": -32000, "message": "Failed to save theme: " + str(err)}}
		"load":
			var load_path: String = params.get("theme_path", "")
			if load_path == "":
				return {"error": {"code": -32004, "message": "theme_path is required for load action"}}
			if not _validate_resource_path(load_path):
				return {"error": {"code": -32004, "message": "theme_path must start with res:// or user://: " + load_path}}
			var res = load(load_path)
			if res == null:
				return {"error": {"code": -32000, "message": "Failed to load theme from: " + load_path}}
			ctrl.theme = res
		_:
			return {"error": {"code": -32004, "message": "Invalid action: " + action + ". Must be: set_params, create, save, load"}}

	return {"result": {"node": node_path, "action": action, "status": "theme_set"}}

# ─── ui_container_add ───────────────────────────────────────────────────────

func handle_ui_container_add(params: Dictionary, request_id: int) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var container = CommandHelpers.find_node(root, node_path)
	if container == null:
		return {"error": {"code": -32002, "message": "Container node not found: " + node_path}}

	var child_type: String = params.get("child_type", "Label")
	if not (child_type in ALLOWED_CONTROL_TYPES):
		return {"error": {"code": -32004, "message": "Invalid or blocked Control type: " + child_type}}

	var child_name: String = params.get("child_name", "Child")
	var child = ClassDB.instantiate(child_type)
	if child == null:
		return {"error": {"code": -32000, "message": "Cannot instantiate: " + child_type}}
	child.name = child_name

	var child_properties = params.get("child_properties")
	if child_properties != null and child_properties is Dictionary:
		for key in child_properties:
			if key.begins_with("_") or key in BLOCKED_PROPS:
				continue
			if not key is String:
				continue
			if ":" in key or "/" in key:
				continue
			var cval = child_properties[key]
			if cval is Object:
				continue
			if CommandHelpers.property_exists_and_type_ok(child, key, cval):
				child.set(key, cval)

	if _undo_manager != null:
		_undo_manager.create_action_mixed("UI Container Add (req:%d)" % request_id,
			[
				{"type": "method", "target": container, "method": "add_child", "args": [child]},
				{"type": "method", "target": child, "method": "set_owner", "args": [root]},
				{"type": "reference", "value": child}
			],
			[
				{"type": "method", "target": container, "method": "remove_child", "args": [child]}
			]
		)
	else:
		container.add_child(child)
		child.owner = root

	return {"result": {"container": node_path, "child_type": child_type, "child_name": child_name, "child_path": str(child.get_path()), "status": "child_added"}}

# ─── theme_create ───────────────────────────────────────────────────────────

func handle_theme_create(params: Dictionary) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var action: String = params.get("action", "create")
	var theme: Theme

	match action:
		"create":
			theme = Theme.new()
		"extract":
			var source_path: String = params.get("source_node_path", "")
			var source = CommandHelpers.find_node(root, source_path)
			if source == null:
				return {"error": {"code": -32002, "message": "Source node not found: " + source_path}}
			if not (source is Control):
				return {"error": {"code": -32004, "message": "Source node is not a Control: " + source.get_class()}}
			var src_theme = source.theme
			if src_theme == null:
				return {"error": {"code": -32004, "message": "Source node has no theme"}}
			theme = src_theme
		_:
			return {"error": {"code": -32004, "message": "Invalid action: " + action + ". Must be: create, extract"}}

	var save_path: String = params.get("save_path", "")
	if save_path != "":
		if not _validate_resource_path(save_path):
			return {"error": {"code": -32004, "message": "save_path must start with res:// or user://: " + save_path}}
		var err = ResourceSaver.save(theme, save_path)
		if err != OK:
			return {"error": {"code": -32000, "message": "Failed to save theme: " + str(err)}}

	return {"result": {"action": action, "status": "theme_created"}}

# IMP-2: 资源路径必须为 res:// 或 user:// 前缀,堵已认证用户的本地任意文件写入/读取
# IMP-2-CONSISTENCY: 加段级 .. 阻断,与 scene_commands._has_path_traversal 防御深度对齐
func _validate_resource_path(p: String) -> bool:
	if not (p.begins_with("res://") or p.begins_with("user://")):
		return false
	if CommandHelpers.has_path_traversal(p):
		return false
	return true


# ─── theme_set_property ─────────────────────────────────────────────────────

func handle_theme_set_property(params: Dictionary) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var theme_node_path: String = params.get("theme_node_path", "")
	var node = CommandHelpers.find_node(root, theme_node_path)
	if node == null:
		return {"error": {"code": -32002, "message": "Node not found: " + theme_node_path}}

	var theme = node.theme
	if theme == null:
		return {"error": {"code": -32004, "message": "Node has no theme assigned"}}
	if not (theme is Theme):
		return {"error": {"code": -32004, "message": "Node.theme is not a Theme"}}

	var item_type: String = params.get("item_type", "")
	var prop_name: String = params.get("name", "")
	var theme_type: String = params.get("theme_type", "")
	var value = params.get("value")

	match item_type:
		"default_font":
			var font_path: String = str(value)
			if not _validate_resource_path(font_path):
				return {"error": {"code": -32004, "message": "font path must start with res:// or user://: " + font_path}}
			theme.set_default_font(load(font_path))
		"color":
			var c = value
			if c is Array and c.size() >= 3:
				var a = float(c[3]) if c.size() >= 4 else 1.0
				theme.set_color(prop_name, theme_type, Color(float(c[0]), float(c[1]), float(c[2]), a))
			else:
				return {"error": {"code": -32004, "message": "Color value must be array [r, g, b] or [r, g, b, a]"}}
		"constant":
			theme.set_constant(prop_name, theme_type, int(value))
		"stylebox":
			var sb_path: String = str(value)
			if not _validate_resource_path(sb_path):
				return {"error": {"code": -32004, "message": "stylebox path must start with res:// or user://: " + sb_path}}
			theme.set_stylebox(prop_name, theme_type, load(sb_path))
		_:
			return {"error": {"code": -32004, "message": "Invalid item_type: " + item_type + ". Must be: default_font, color, constant, stylebox"}}

	return {"result": {"node": theme_node_path, "item_type": item_type, "name": prop_name, "status": "property_set"}}
