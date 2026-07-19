## command_helpers.gd — Shared utility functions for editor command modules.
## C-05: Extracted from 7 files to eliminate ~120 lines of duplication.

class_name CommandHelpers


## Get the root node of the currently edited scene.
## Tries EditorInterface first (editor mode), falls back to SceneTree root child (headless).
static func get_edited_scene_root(plugin: EditorPlugin = null) -> Node:
	if plugin != null:
		var ei: EditorInterface = plugin.get_editor_interface()
		if ei != null:
			var edited: Node = ei.get_edited_scene_root()
			if edited != null:
				return edited
	var ml: MainLoop = Engine.get_main_loop()
	if ml == null or not (ml is SceneTree):
		return null
	var st: SceneTree = ml as SceneTree
	if st == null or st.root == null:
		return null
	if st.root.get_child_count() > 0:
		return st.root.get_child(0)
	return null


## Find a node by path relative to root.
## Strips leading "root/" prefix and leading slashes.
static func find_node(root: Node, path: String) -> Node:
	if path == "" or path == "root":
		return root
	var p: String = path
	while p.begins_with("/"):
		p = p.substr(1)
	if p.begins_with("root/"):
		p = p.substr(5)
	if p.begins_with(root.name + "/"):
		p = p.substr(root.name.length() + 1)
	elif p == root.name:
		return root
	if p == "":
		return root
	return root.get_node_or_null(p)


## Check for path traversal (`..` segments) in a resource path.
## C-1 / IMP-2-CONSISTENCY: 共享段级 `..` 阻断,被 scene_commands 与 ui_commands 复用,
## 保持防御深度一致(与 godot_operations._sanitize_res_path 对齐)。单一实现消除重复。
static func has_path_traversal(p: String) -> bool:
	return "/../" in p or p.begins_with("../") or p.ends_with("/..") or p == ".."


## Check that a property exists on an object and its value type is compatible.
## Replaces duplicated copies in scene_commands.gd and ui_commands.gd.
## C-03: Removed string wildcard pass-through — strings are only allowed when
## the target property is also a string, or when str_to_var can parse them into
## the correct type (e.g., "Vector2(1, 2)" for a Vector2 property).
static func property_exists_and_type_ok(obj: Object, prop_name: String, val) -> bool:
	var found: bool = false
	for p: Dictionary in obj.get_property_list():
		if p["name"] == prop_name:
			found = true
			break
	if not found:
		return false
	var current: Variant = obj.get(prop_name)
	if current == null:
		return val == null
	var current_type: int = typeof(current)
	var val_type: int = typeof(val)
	if current_type == val_type:
		return true
	# Allow float/int interchange
	if (current_type == TYPE_FLOAT and val_type == TYPE_INT) or (current_type == TYPE_INT and val_type == TYPE_FLOAT):
		return true
	# C-03: String values only allowed for string properties, or when a safe
	# type-specific constructor can convert them to the expected type.
	if val_type == TYPE_STRING:
		if current_type == TYPE_STRING:
			return true
		# C-02 fix: replace str_to_var with safe type-specific constructors.
		# str_to_var can deserialize arbitrary objects; only allow known-safe scalar/math types.
		return _try_safe_string_convert(val, current_type)
	return false  # type mismatch — reject


## Try to convert a string value to the expected type using safe constructors only.
## Returns true if the string can be safely converted to match target_type.
## C-02: Replaces str_to_var which can deserialize arbitrary objects.
static func _try_safe_string_convert(val: String, target_type: int) -> bool:
	match target_type:
		TYPE_BOOL:
			return val == "true" or val == "false" or val == "True" or val == "False"
		TYPE_INT:
			return val.is_valid_int()
		TYPE_FLOAT:
			return val.is_valid_float() or val.is_valid_int()
		TYPE_COLOR:
			# Valid if the parse ignores the supplied default (same result for two different defaults).
			return Color.from_string(val, Color(0, 0, 0, 0)) == Color.from_string(val, Color(1, 1, 1, 1))
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return _count_number_components(val) == 2
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return _count_number_components(val) == 3
		TYPE_RECT2, TYPE_RECT2I, TYPE_PLANE, TYPE_QUATERNION:
			return _count_number_components(val) == 4
		TYPE_AABB, TYPE_TRANSFORM2D:
			return _count_number_components(val) == 6
		TYPE_BASIS:
			return _count_number_components(val) == 9
		TYPE_TRANSFORM3D:
			return _count_number_components(val) == 12
	return false


## Parse a Vector3 from JSON/array sources. T5: shared vec3 parser for asset_placer
## (replaces per-file _vec3 copies from asset-forge). Accepts Array or PackedFloat64Array
## of length >= 3; any other type or short array returns Vector3.ZERO (defensive).
static func parse_vec3(v: Variant) -> Vector3:
	if v is Array:
		var a: Array = v as Array
		if a.size() >= 3:
			return Vector3(float(a[0]), float(a[1]), float(a[2]))
		return Vector3.ZERO
	if v is PackedFloat64Array:
		var p: PackedFloat64Array = v as PackedFloat64Array
		if p.size() >= 3:
			return Vector3(p[0], p[1], p[2])
		return Vector3.ZERO
	return Vector3.ZERO


## Coerce MCP JSON Array values to Godot math types matching the target property.
## Godot's Object.set() does NOT auto-convert Array to Vector3 etc (Godot 4.7
## verified: set("position", [0,0,-6]) is a silent no-op). Mirrors the parse_vec3
## path that asset_placer uses for create/batch position. Returns val unchanged
## when no coercion applies so non-math properties fall through to type_ok / Godot.
## Fixes instance_scene properties.position / set_instance_property Vector3 set
## (asset create/batch already worked via parse_vec3; scene tools did not).
static func coerce_value_for_property(obj: Object, prop_name: String, val: Variant) -> Variant:
	if val is Array:
		var current = obj.get(prop_name)
		if current != null:
			match typeof(current):
				TYPE_VECTOR2:
					if val.size() >= 2:
						return Vector2(float(val[0]), float(val[1]))
				TYPE_VECTOR2I:
					if val.size() >= 2:
						return Vector2i(int(val[0]), int(val[1]))
				TYPE_VECTOR3:
					if val.size() >= 3:
						return Vector3(float(val[0]), float(val[1]), float(val[2]))
				TYPE_VECTOR3I:
					if val.size() >= 3:
						return Vector3i(int(val[0]), int(val[1]), int(val[2]))
				TYPE_VECTOR4:
					if val.size() >= 4:
						return Vector4(float(val[0]), float(val[1]), float(val[2]), float(val[3]))
				TYPE_COLOR:
					if val.size() >= 3:
						return Color(float(val[0]), float(val[1]), float(val[2]), float(val[3]) if val.size() > 3 else 1.0)
				TYPE_PLANE:
					if val.size() >= 4:
						return Plane(float(val[0]), float(val[1]), float(val[2]), float(val[3]))
				TYPE_QUATERNION:
					if val.size() >= 4:
						return Quaternion(float(val[0]), float(val[1]), float(val[2]), float(val[3]))
	return val


## editor 侧 BLOCKED_PROPERTIES —— 对齐 headless godot_operations.gd BLOCKED_PROPERTIES + TS BLOCKED_PROPS。
## instance 额外在 coerce_property_value 内双保险拒绝（I-2: 可注入 ExtResource 实例化恶意场景 _ready）。
const BLOCKED_PROPERTIES := [
	"script", "owner", "process_mode", "process_priority", "process_input",
	"process_unhandled_input", "process_unhandled_key_input", "process_internal",
	"physics_process_mode", "physics_interpolation_mode", "name", "meta",
	"input_event", "ready", "tree_entered", "tree_exited", "tree_exiting",
	"instance",  # I-2: instance 可注入 ExtResource 实例化恶意场景 _ready，与 script 同级危险
]


## 统一 property coerce（editor 侧）。关键不对称：只 coerce 不 set（返 {"ok","value","error"}），
## set 由 handler 经 undo 系统 do_op 执行——editor 要 per-property undo（do=set new / undo=set old），
## helper 内置 set 会与 do_op 重复执行。与 headless _set_property_with_coerce（godot_operations.gd，
## 内置 set 因 headless 无 per-property undo、走整场景 pack+save）刻意不对称。靠 defects.ts 双向 detect 防漂移。
static func coerce_property_value(obj: Object, prop: String, val: Variant) -> Dictionary:
	# 1. BLOCKED 过滤 + instance 双保险（即使漏加 BLOCKED_PROPERTIES 也拒）
	if prop in BLOCKED_PROPERTIES or prop == "instance":
		return {"ok": false, "value": null, "error": "Blocked property: %s" % prop}
	# 2. 属性存在性 + 取声明类型
	var prop_type := -1
	for p in obj.get_property_list():
		if String(p.get("name", "")) == prop:
			prop_type = int(p.get("type", TYPE_NIL))
			break
	if prop_type == -1:
		return {"ok": false, "value": null, "error": "Property not found: %s on %s" % [prop, obj.get_class()]}
	# 3. 类型分支（严格对齐 headless _set_property_with_coerce 语义，消除 editor/headless 撕裂）
	var coerced: Variant = val
	if prop_type == TYPE_OBJECT:
		if val is String and val.begins_with("res://"):
			if has_path_traversal(val):
				return {"ok": false, "value": null, "error": "Path traversal blocked: %s" % val}
			coerced = load(val)
			if coerced == null:
				return {"ok": false, "value": null, "error": "Failed to load resource: %s" % val}
		elif val is String:
			# Resource 属性传非 res:// String → 非静默拒绝（对齐 headless，修 batch silently fail 同根因）
			return {"ok": false, "value": null, "error": "Property %s expects Resource, got plain String '%s' (use res:// path)" % [prop, val]}
		# val 非 String → 透传（JSON 无法表达 Resource 实例，交 Godot set 处理，与 headless 一致）
	else:
		# 非 TYPE_OBJECT：Array 走数学类型 coerce（Vector2/3/Color...），非 Array 透传
		coerced = coerce_value_for_property(obj, prop, val)
	return {"ok": true, "value": coerced, "error": ""}


## Count comma-separated numeric components, ignoring surrounding brackets/parens/whitespace.
## Returns -1 if any component is not a number. Safe replacement for str_to_var (C-02).
static func _count_number_components(val: String) -> int:
	var cleaned := val.strip_edges()
	for ch in ["(", ")", "[", "]", "{", "}"]:
		cleaned = cleaned.replace(ch, "")
	if cleaned == "":
		return 0
	var parts := cleaned.split(",", false)
	for p in parts:
		var t := p.strip_edges()
		if not (t.is_valid_float() or t.is_valid_int()):
			return -1
	return parts.size()
