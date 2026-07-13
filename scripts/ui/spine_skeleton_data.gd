class_name SpineSkeletonData
extends RefCounted

## Spine 2.1.07 .json 解析（View 层）— bones/slots/skins.default/animations。
## 照源 SpineContainer:create + spine runtime 简化（region-only，无 mesh/权重/IK/约束/事件/变形）。
## 配套 assets/spine/<name>/<name>.json。timeline curve：缺省线性 / "stepped" / [c1,c2,c3,c4] 贝塞尔。

var bones: Dictionary = {}       # name -> {parent, x, y, rotation, scaleX, scaleY, length}
var slots: Array = []            # [{name, bone, attachment, color}]
var skins: Dictionary = {}       # slot -> {attachment -> {x, y, rotation, scaleX, scaleY, width, height}}
var animations: Dictionary = {}  # action -> {bones: {bone: {rotate,translate,scale:[timeline]}}, slots: {slot: {color:[timeline]}}}
var _loaded: bool = false


func load_json(json_path: String) -> bool:
	var f: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		push_warning("SpineSkeletonData: 无法打开 .json: " + json_path)
		return false
	var text: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		push_warning("SpineSkeletonData: JSON 解析失败: " + json_path)
		return false
	var d: Dictionary = data
	if not d.has("bones"):
		push_warning("SpineSkeletonData: 无 bones: " + json_path)
		return false
	_parse_bones(d["bones"])
	_parse_slots(d.get("slots", []))
	_parse_skins(d.get("skins", {}))
	_parse_animations(d.get("animations", {}))
	_loaded = not bones.is_empty()
	return _loaded


func _parse_bones(arr: Array) -> void:
	for bv in arr:
		var b: Dictionary = bv
		var name: String = String(b.get("name", ""))
		if name == "":
			continue
		bones[name] = {
			"parent": String(b.get("parent", "")),
			"x": float(b.get("x", 0.0)),
			"y": float(b.get("y", 0.0)),
			"rotation": float(b.get("rotation", 0.0)),
			"scaleX": float(b.get("scaleX", 1.0)),
			"scaleY": float(b.get("scaleY", 1.0)),
			"length": float(b.get("length", 0.0)),
		}


func _parse_slots(arr: Array) -> void:
	for sv in arr:
		var s: Dictionary = sv
		slots.append({
			"name": String(s.get("name", "")),
			"bone": String(s.get("bone", "")),
			"attachment": String(s.get("attachment", "")),
			"color": String(s.get("color", "ffffffff")),
		})


func _parse_skins(d: Dictionary) -> void:
	var default: Dictionary = d.get("default", {})
	for slot_name in default:
		skins[String(slot_name)] = default[slot_name]


func _parse_animations(d: Dictionary) -> void:
	for action in d:
		var anim: Dictionary = d[action]
		animations[String(action)] = {
			"bones": anim.get("bones", {}),
			"slots": anim.get("slots", {}),
		}


func get_attachment(slot_name: String, attachment_name: String) -> Dictionary:
	var slot_skins: Dictionary = skins.get(slot_name, {})
	return slot_skins.get(attachment_name, {})


func has_action(action: String) -> bool:
	return animations.has(action)


func get_action_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for k in animations:
		names.append(String(k))
	return names


func is_loaded() -> bool:
	return _loaded


## hex "rrggbbaa" → Color（Spine slot/animation color 格式）。
static func parse_color_hex(hex: String) -> Color:
	var r: float = float(hex.substr(0, 2).hex_to_int()) / 255.0 if hex.length() >= 2 else 1.0
	var g: float = float(hex.substr(2, 2).hex_to_int()) / 255.0 if hex.length() >= 4 else 1.0
	var b: float = float(hex.substr(4, 2).hex_to_int()) / 255.0 if hex.length() >= 6 else 1.0
	var a: float = float(hex.substr(6, 2).hex_to_int()) / 255.0 if hex.length() >= 8 else 1.0
	return Color(r, g, b, a)
