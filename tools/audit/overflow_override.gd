extends Node

## 运行时溢出检测 override（viewport 迁移溢出排查，一次性调试产物）：
## 每 2s 扫描当前场景树，检测"边框类节点的可见子元素超出边框且未被 clip 裁剪"，
## 结果累积写 user://overflow_runtime.json（scene 名 + 节点 + rect + 溢出量）。
## 判定排除项：child 的最近 clip_contents 祖先 rect 包含 border rect → 视为合法裁剪内容。

const OUT := "user://overflow_runtime.json"
const BORDER_HINTS := ["frame", "bg", "box", "board", "window"]
const SKIP_HINTS := ["cloud", "light", "arrow", "shadow", "finger", "particle", "eff", "decorat"]
var _seen := {}
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 2.0
	_timer.autostart = true
	_timer.timeout.connect(_scan)
	add_child(_timer)


func _scan() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var key := scene.name + "@" + str(Time.get_ticks_msec() / 60000)
	var found: Array = []
	for node in _iter(scene):
		if node is Control and _border_like(node.name.to_lower()):
			_check(node, found)
	for f in found:
		var k: String = f.get("scene", "") + "|" + f.get("border", "") + "|" + f.get("child", "")
		if not _seen.has(k):
			_seen[k] = f
	_dump()


func _iter(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_iter(c))
	return out


func _border_like(ln: String) -> bool:
	for h in BORDER_HINTS:
		if ln.find(h) >= 0:
			return true
	return false


func _skipped(ln: String) -> bool:
	for h in SKIP_HINTS:
		if ln.find(h) >= 0:
			return true
	return false


func _clip_covers(border: Control) -> bool:
	# 向上找最近 clip_contents 祖先；其 rect 若包含 border rect 则 border 内的溢出都会被裁掉
	var p := border.get_parent()
	while p is Control:
		var pc := p as Control
		if pc.clip_contents:
			return pc.get_global_rect().encloses(border.get_global_rect())
		p = p.get_parent()
	return false


func _check(border: Control, out: Array) -> void:
	if _skipped(border.name.to_lower()) or _clip_covers(border):
		return
	var br := border.get_global_rect()
	if br.size.x < 40.0 or br.size.y < 40.0:
		return
	for child in _iter(border):
		if not (child is Control) or not child.visible:
			continue
		var c := child as Control
		if _skipped(c.name.to_lower()):
			continue
		var cr := c.get_global_rect()
		if cr.size == Vector2.ZERO or not c.is_visible_in_tree():
			continue
		var over: float = max(max(br.position.x - cr.position.x, br.position.y - cr.position.y), max(cr.end.x - br.end.x, cr.end.y - br.end.y))
		if over > 3.0:
			out.append({
				"scene": get_tree().current_scene.name,
				"border": border.name + "@" + str(border.get_parent().name),
				"border_rect": [roundi(br.position.x), roundi(br.position.y), roundi(br.size.x), roundi(br.size.y)],
				"child": c.name + "@" + str(c.get_parent().name),
				"child_type": c.get_class(),
				"child_rect": [roundi(cr.position.x), roundi(cr.position.y), roundi(cr.size.x), roundi(cr.size.y)],
				"overflow_px": roundi(over),
			})


func _dump() -> void:
	var arr: Array = []
	for k in _seen:
		arr.append(_seen[k])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(arr, "\t"))
		f.close()
