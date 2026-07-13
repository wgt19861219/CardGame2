# addons/godot_mcp_server/editor_guards.gd
# 文件冲突守卫 — 防止 MCP 静默覆盖编辑器中打开的文件
extends Node

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


## 公共路径规范化，供 scene_commands 等模块复用（Issue 5 DRY）
func normalize_path(path: String) -> String:
	if path.is_empty():
		return ""
	if path.begins_with("res://") or path.begins_with("user://"):
		return path.simplify_path()
	var res_path: String = ProjectSettings.localize_path(path)
	if not res_path.is_empty():
		return res_path.simplify_path()
	return path.simplify_path()


func get_open_scene_paths() -> Array:
	var paths: Array = []
	if _plugin == null:
		return paths
	var ei: EditorInterface = _plugin.get_editor_interface()
	if ei == null:
		return paths
	var open_scenes: PackedStringArray = ei.get_open_scenes()
	for scene_path: String in open_scenes:
		var normalized: String = normalize_path(scene_path)
		if not normalized.is_empty() and normalized not in paths:
			paths.append(normalized)
	# 也包含当前活跃场景
	var root: Node = ei.get_edited_scene_root()
	if root != null and not root.scene_file_path.is_empty():
		var active: String = normalize_path(root.scene_file_path)
		if active not in paths:
			paths.append(active)
	return paths


func is_scene_path_open(path: String) -> bool:
	var normalized: String = normalize_path(path)
	if normalized.is_empty():
		return false
	return normalized in get_open_scene_paths()


func is_active_scene_path(path: String) -> bool:
	if _plugin == null:
		return false
	var ei: EditorInterface = _plugin.get_editor_interface()
	var root: Node = ei.get_edited_scene_root()
	if root == null:
		return false
	return normalize_path(root.scene_file_path) == normalize_path(path)


func guard_offline_scene_save(path: String) -> Dictionary:
	# 检查场景文件是否在编辑器中打开，如果打开则返回错误阻止离线保存
	var normalized: String = normalize_path(path)
	if not _is_scene_resource_path(normalized):
		return {}
	if is_scene_path_open(normalized):
		return {
			"error": {
				"code": -32009,
				"message": "Refusing to save open scene '%s' outside the Godot editor state" % normalized,
				"data": {
					"path": normalized,
					"open_scenes": get_open_scene_paths(),
					"suggestion": "Use live editor changes plus save_scene, or close the scene before offline edits."
				}
			}
		}
	return {}


func guard_save_inactive_open_scene(path: String) -> Dictionary:
	# 检查是否在从活跃场景保存另一个已打开的非活跃场景
	var normalized: String = normalize_path(path)
	if is_scene_path_open(normalized) and not is_active_scene_path(normalized):
		return {
			"error": {
				"code": -32009,
				"message": "Refusing to save inactive open scene '%s' from the active editor scene" % normalized,
				"data": {
					"path": normalized,
					"suggestion": "Open the target scene tab before saving it, or close it first."
				}
			}
		}
	return {}


func guard_text_resource_write(path: String, force: bool = false) -> Dictionary:
	# 检查脚本/着色器是否在编辑器脚本编辑器中打开
	if force:
		return {}
	if not _is_text_resource_path(path):
		return {}
	var target: String = normalize_path(path)
	if target.is_empty():
		return {}
	# 检查着色器缓存
	if _is_shader_resource_path(target):
		if ResourceLoader.has_cached(target):
			return {
				"error": {
					"code": -32009,
					"message": "Refusing to write open shader resource '%s'" % target,
					"data": {"suggestion": "Close the file in Godot's shader editor or pass force=true."}
				}
			}
		return {}
	# 检查脚本编辑器（Issue 6: get_open_scripts 返回 Resource，直接访问 resource_path）
	if _plugin == null:
		return {}
	var ei: EditorInterface = _plugin.get_editor_interface()
	var script_editor = ei.get_script_editor()
	if script_editor == null:
		return {}
	for open_resource in script_editor.get_open_scripts():
		var resource_path: String = normalize_path(open_resource.resource_path)
		if resource_path == target:
			return {
				"error": {
					"code": -32009,
					"message": "Refusing to write open text resource '%s' outside the script editor state" % target,
					"data": {"suggestion": "Close the file in Godot's script editor or pass force=true."}
				}
			}
	return {}


func _is_scene_resource_path(path: String) -> bool:
	var ext: String = path.get_extension().to_lower()
	return ext == "tscn" or ext == "scn"


func _is_text_resource_path(path: String) -> bool:
	var ext: String = path.get_extension().to_lower()
	return ext == "gd" or ext == "gdshader" or ext == "gdshaderinc" or ext == "shader"


func _is_shader_resource_path(path: String) -> bool:
	var ext: String = path.get_extension().to_lower()
	return ext == "gdshader" or ext == "gdshaderinc" or ext == "shader"
