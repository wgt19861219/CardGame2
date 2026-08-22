extends SceneTree

## 一次性审计脚本（viewport 迁移后溢出检测）：
## godot --headless --path . --script tools/audit/detect_overflow.gd
## 遍历 scenes/**/*.tscn，instantiate 后检测"边框类节点"（名字含 Frame/Bg/Box/Board/Window
## 的 Control 系）的子孙节点 rect 是否超出边框边界（含容差），输出 JSON 报告。
## 注意：只测静态 tscn（content 无脚本，instantiate 安全）；动态填充行另走 bridge 抽查。

const REPORT_PATH := "res://.superpowers/sdd/overflow_report.json"
const SCAN_DIRS := ["res://scenes/ui", "res://scenes/battle", "res://scenes/main_menu", "res://scenes/hero"]
const BORDER_HINTS := ["frame", "bg", "box", "board", "window", "panel"]
# 边框语义强的名字优先；纯装饰（云/光效/箭头）误报多，白名单排除
const SKIP_NODE_HINTS := ["cloud", "light", "arrow", "shadow", "finger", "particle", "eff", "decorat"]

var _results: Array = []
var _scanned: int = 0


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var files := _collect_tscn()
	for f in files:
		_scan_file(f)
	var out := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify({
		"scanned_files": _scanned,
		"total_tscn": files.size(),
		"overflow_cases": _results,
		"elapsed_ms": Time.get_ticks_msec() - t0,
	}, "\t"))
	out.close()
	print("overflow scan done: %d/%d files, %d cases -> %s" % [_scanned, files.size(), _results.size(), REPORT_PATH])
	quit(0)


func _collect_tscn() -> Array:
	var out: Array = []
	for d in SCAN_DIRS:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.ends_with(".tscn"):
				out.append(d + "/" + name)
			name = dir.get_next()
		dir.list_dir_end()
	return out


func _scan_file(path: String) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		return
	var inst: Node = packed.instantiate()
	# content 底板多为 Control 根；跳过需要外部上下文的（入口场景带脚本）
	if inst.get_script() != null:
		inst.free()
		return
	_scanned += 1
	root.add_child(inst)  # 入树触发布局（无脚本节点安全）
	for node in _iter_children(inst):
		if node is Control and _is_border_like(node.name.to_lower()):
			_check_border(path, node)
	inst.queue_free()
	root.remove_child(inst)  # 立即摘除避免同帧残留（headless 单帧顺序执行）


func _iter_children(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		out.append(c)
		out.append_array(_iter_children(c))
	return out


func _is_border_like(lower_name: String) -> bool:
	for h in BORDER_HINTS:
		if lower_name.find(h) >= 0:
			return true
	return false


func _check_border(src: String, border: Control) -> void:
	var b_lower := border.name.to_lower()
	for s in SKIP_NODE_HINTS:
		if b_lower.find(s) >= 0:
			return
	var b_rect := border.get_global_rect()
	# 边框自身太小（<40px）多半是标签底板之类，跳过减噪
	if b_rect.size.x < 40.0 or b_rect.size.y < 40.0:
		return
	for child in _iter_children(border):
		if not (child is Control):
			continue
		var c := child as Control
		if not c.visible:
			continue
		var c_lower := c.name.to_lower()
		var skipped := false
		for s in SKIP_NODE_HINTS:
			if c_lower.find(s) >= 0:
				skipped = true
				break
		if skipped:
			continue
		var c_rect := c.get_global_rect()
		if c_rect.size == Vector2.ZERO:
			continue
		# 溢出量（正=超出）。容差 2px 抗浮点/描边
		var over_l := b_rect.position.x - c_rect.position.x
		var over_t := b_rect.position.y - c_rect.position.y
		var over_r := c_rect.end.x - b_rect.end.x
		var over_b := c_rect.end.y - b_rect.end.y
		var max_over: float = max(max(over_l, over_t), max(over_r, over_b))
		if max_over > 2.0:
			_results.append({
				"scene": src.replace("res://", ""),
				"border": String(border.name),
				"border_rect": [roundi(b_rect.position.x), roundi(b_rect.position.y), roundi(b_rect.size.x), roundi(b_rect.size.y)],
				"child": String(c.name),
				"child_type": c.get_class(),
				"child_rect": [roundi(c_rect.position.x), roundi(c_rect.position.y), roundi(c_rect.size.x), roundi(c_rect.size.y)],
				"overflow_px": roundi(max_over),
				"over_dir": _dir(over_l, over_t, over_r, over_b),
			})


func _dir(l: float, t: float, r: float, b: float) -> String:
	var m: float = max(max(l, t), max(r, b))
	if m == l: return "left"
	if m == t: return "top"
	if m == r: return "right"
	return "bottom"
