extends GutTest
## 全库 TextureButton stretch_mode 守卫（2026-08-31 全库 stretch 清偿）。
## 判例（战前布阵四轮实锤）：ignore_texture_size=true 未显式设 stretch_mode 时
## Godot 4 默认 STRETCH_KEEP(2)=纹理按原始像素渲染（偏大 1.28×），rect 只管布局/点击。
## 约定：凡 ignore_texture_size = true 的 TextureButton 必须显式写 stretch_mode。


func _collect_tscn_files() -> Array[String]:
	var out: Array[String] = []
	var stack: Array[String] = ["res://scenes"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			var full := dir_path + "/" + name
			if dir.current_is_dir():
				stack.push_back(full)
			elif name.ends_with(".tscn"):
				out.push_back(full)
			name = dir.get_next()
		dir.list_dir_end()
	return out


func _scan_violations() -> Array[String]:
	var violations: Array[String] = []
	for path in _collect_tscn_files():
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty() or text.find("TextureButton") == -1:
			continue
		var lines := text.split("\n")
		var in_texture_button := false
		var has_ignore := false
		var has_stretch := false
		var node_name := ""
		for line in lines:
			var stripped := line.strip_edges()
			if stripped.begins_with("[node "):
				if in_texture_button and has_ignore and not has_stretch:
					violations.append("%s :: %s" % [path, node_name])
				in_texture_button = stripped.find('type="TextureButton"') != -1
				var name_pos := stripped.find('name="')
				if name_pos != -1:
					var name_end := stripped.find('"', name_pos + 6)
					node_name = stripped.substr(name_pos + 6, name_end - name_pos - 6)
				has_ignore = false
				has_stretch = false
			elif in_texture_button:
				if stripped == "ignore_texture_size = true":
					has_ignore = true
				elif stripped.begins_with("stretch_mode"):
					has_stretch = true
		if in_texture_button and has_ignore and not has_stretch:
			violations.append("%s :: %s" % [path, node_name])
	return violations


func _count_guarded_buttons() -> int:
	var count := 0
	for path in _collect_tscn_files():
		var text := FileAccess.get_file_as_string(path)
		if text.find("TextureButton") == -1:
			continue
		for line in text.split("\n"):
			if line.strip_edges() == "ignore_texture_size = true":
				count += 1
	return count


func test_all_ignore_texture_size_buttons_have_explicit_stretch_mode() -> void:
	var violations := _scan_violations()
	assert_eq(violations.size(), 0,
		"ignore_texture_size=true 必须显式 stretch_mode（默认 KEEP 原像素渲染偏大 1.28×）：" +
		str(violations))


func test_scanner_actually_scans() -> void:
	# 健全性：守卫对象基数 >100，防扫描器空转假绿（2026-08-31 清偿后全库 146）。
	var count := _count_guarded_buttons()
	assert_gt(count, 100, "守卫按钮基数异常（扫描器失效或约定被破坏）")
