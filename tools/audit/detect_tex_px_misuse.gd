extends SceneTree

## tscn 纹理 px 直用检测器（viewport 迁移溢出专项）：
## godot --headless --path . --script tools/audit/detect_tex_px_misuse.gd
## 遍历 scenes/**/*.tscn，instantiate 后检测 TextureRect/NinePatchRect/Sprite2/TextureButton：
## 显示 size ≈ 纹理原始像素（±2px）者为嫌疑（正确口径应为 纹理÷1.28125，除非有显式放大语义）。
## 输出 JSON 报告供人工甄别（容器拉伸/scale=1.28 类会标注）。

const REPORT_PATH := "res://.superpowers/sdd/tex_px_report.json"
const SCAN_DIRS := ["res://scenes/ui", "res://scenes/battle", "res://scenes/main_menu", "res://scenes/hero"]
const CS := 1.28125

var _results: Array = []
var _scanned: int = 0


func _init() -> void:
	for d in SCAN_DIRS:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".tscn"):
				_scan_file(d + "/" + fname)
			fname = dir.get_next()
		dir.list_dir_end()
	var out := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify({"scanned": _scanned, "suspects": _results}, "\t"))
	out.close()
	print("tex px scan done: %d files, %d suspects -> %s" % [_scanned, _results.size(), REPORT_PATH])
	quit(0)


func _scan_file(path: String) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		return
	var inst: Node = packed.instantiate()
	if inst.get_script() != null:
		inst.free()
		return
	_scanned += 1
	root.add_child(inst)
	for node in _iter(inst):
		var tex: Texture2D = null
		var c := node as Control
		if node is TextureRect:
			tex = (node as TextureRect).texture
		elif node is NinePatchRect:
			tex = (node as NinePatchRect).texture
		elif node is TextureButton:
			var tb := node as TextureButton
			tex = tb.texture_normal if tb.texture_normal != null else tb.texture_pressed
			if tex == null or not (tb.ignore_texture_size or tb.stretch_mode == TextureButton.STRETCH_KEEP):
				# TextureButton 默认 min size=纹理（非显式设定不算滥用）
				if tex != null and tb.ignore_texture_size:
					tex = tex
		if tex == null or c == null:
			continue
		var ts: Vector2 = tex.get_size()
		var cs: Vector2 = c.get_size()
		if ts == Vector2.ZERO or cs == Vector2.ZERO:
			continue
		var eff := c.get_global_rect()  # 含父链 scale 的实际显示
		var note := ""
		if node is TextureButton and not (node as TextureButton).ignore_texture_size:
			continue  # 默认行为，跳过
		var dx: float = abs(eff.size.x - ts.x)
		var dy: float = abs(eff.size.y - ts.y)
		if dx <= 2.0 and dy <= 2.0:
			_results.append({
				"scene": path.replace("res://", ""),
				"node": String(c.name),
				"type": c.get_class(),
				"tex_px": [roundi(ts.x), roundi(ts.y)],
				"display": [roundi(eff.size.x), roundi(eff.size.y)],
				"should_be": [roundi(ts.x / CS), roundi(ts.y / CS)],
				"note": note,
			})
	root.remove_child(inst)
	inst.free()


func _iter(n: Node) -> Array:
	var out: Array = []
	for ch in n.get_children():
		out.append(ch)
		out.append_array(_iter(ch))
	return out
