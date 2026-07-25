class_name SpineSkeleton
extends Node2D

## Spine 2.1.07 简化骨骼动画播放器（View 层）— region-only（无 mesh/权重/IK/约束/事件/变形）。
## 骨骼层级 Node2D + region Sprite2D 附件 + 每帧贝塞尔插值 bone rotate/translate/scale + slot color。
## 配套 assets/spine/<name>/<name>.json + .atlas + .png。Spine y 上 → Godot y 下：整体 scale.y=-1 翻转。

const SpineAtlas = preload("res://scripts/ui/spine_atlas.gd")
const SpineSkeletonData = preload("res://scripts/ui/spine_skeleton_data.gd")

signal action_finished(action_name: String)

var _data: SpineSkeletonData = null
var _atlas: SpineAtlas = null
var _bone_nodes: Dictionary = {}        # name -> Node2D
var _slot_sprites: Array = []           # [{sprite, slot_name, setup_color}]
var _setup_pos: Dictionary = {}         # bone -> Vector2（setup position）
var _setup_rot: Dictionary = {}         # bone -> float rad
var _setup_scale: Dictionary = {}       # bone -> Vector2
var _action: String = ""
var _elapsed: float = 0.0
var _loop: bool = true
var _playing: bool = false


func load_skeleton(spine_dir: String, res_name: String) -> bool:
	var json_path: String = spine_dir + "/" + res_name + ".json"
	var atlas_path: String = spine_dir + "/" + res_name + ".atlas"
	_data = SpineSkeletonData.new()
	if not _data.load_json(json_path):
		return false
	_atlas = SpineAtlas.new()
	if not _atlas.load_atlas(atlas_path):
		return false
	# Spine y 上 → Godot y 下：整体翻转（Sprite 纹理随翻，Spine 纹理设计为 y 上，翻后正立）
	scale = Vector2(scale.x, -abs(scale.y) if scale.y != 0 else -1.0)
	_build_nodes()
	return true


func _build_nodes() -> void:
	for name in _data.bones:
		var b: Dictionary = _data.bones[name]
		var node := Node2D.new()
		node.name = String(name)
		node.position = Vector2(float(b["x"]), float(b["y"]))
		node.rotation = deg_to_rad(float(b["rotation"]))
		node.scale = Vector2(float(b["scaleX"]), float(b["scaleY"]))
		_bone_nodes[String(name)] = node
		_setup_pos[String(name)] = node.position
		_setup_rot[String(name)] = node.rotation
		_setup_scale[String(name)] = node.scale
	# 挂层级
	for name in _data.bones:
		var b: Dictionary = _data.bones[name]
		var parent: String = String(b["parent"])
		var node: Node2D = _bone_nodes[String(name)]
		if parent.is_empty() or not _bone_nodes.has(parent):
			add_child(node)
		else:
			_bone_nodes[parent].add_child(node)
	# slot Sprite 附件
	for slot in _data.slots:
		var slot_name: String = String(slot["name"])
		var att: Dictionary = _data.get_attachment(slot_name, String(slot["attachment"]))
		if att.is_empty():
			continue
		var tex: Texture2D = _atlas.get_region_texture(String(slot["attachment"]))
		if tex == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.position = Vector2(float(att.get("x", 0.0)), float(att.get("y", 0.0)))
		sprite.rotation = deg_to_rad(float(att.get("rotation", 0.0)))
		var sx: float = float(att.get("scaleX", 1.0))
		var sy: float = float(att.get("scaleY", 1.0))
		sprite.scale = Vector2(sx, sy)
		var bone_name: String = String(slot["bone"])
		if _bone_nodes.has(bone_name):
			_bone_nodes[bone_name].add_child(sprite)
		var col: Color = SpineSkeletonData.parse_color_hex(String(slot["color"]))
		sprite.modulate = col
		_slot_sprites.append({"sprite": sprite, "slot_name": slot_name, "setup_color": col, "default_att": String(slot["attachment"])})


func play(action: String, loop: bool = true) -> void:
	if _data == null or not _data.has_action(action):
		return
	_action = action
	_loop = loop
	_elapsed = 0.0
	_playing = true
	set_process(true)
	_apply(0.0)


func stop() -> void:
	_playing = false
	set_process(false)


func is_playing() -> bool:
	return _playing


func has_action(action: String) -> bool:
	return _data != null and _data.has_action(action)


func _process(delta: float) -> void:
	if not _playing or _data == null:
		return
	_elapsed += delta
	var duration: float = _get_action_duration(_action)
	if duration <= 0.0:
		_playing = false
		set_process(false)
		return
	var t: float = _elapsed
	if t >= duration:
		if _loop:
			_elapsed = fmod(t, duration)
			t = _elapsed
		else:
			t = duration
			_playing = false
			set_process(false)
			_apply(t)
			action_finished.emit(_action)
			return
	_apply(t)


func _apply(t: float) -> void:
	# 重置 setup + 应用 animation（timeline 值相对 setup）
	for name in _bone_nodes:
		var n: Node2D = _bone_nodes[name]
		n.position = _setup_pos[name]
		n.rotation = _setup_rot[name]
		n.scale = _setup_scale[name]
	for e in _slot_sprites:
		(e["sprite"] as Sprite2D).modulate = e["setup_color"]
	var anim: Dictionary = _data.animations.get(_action, {})
	if anim.is_empty():
		return
	var bones_anim: Dictionary = anim.get("bones", {})
	for bn in bones_anim:
		if not _bone_nodes.has(String(bn)):
			continue
		var n: Node2D = _bone_nodes[String(bn)]
		var ba: Dictionary = bones_anim[bn]
		if ba.has("rotate"):
			n.rotation = float(_setup_rot[String(bn)]) + deg_to_rad(_interp_num(ba["rotate"], t, "angle"))
		if ba.has("translate"):
			n.position = Vector2(_setup_pos[String(bn)]) + _interp_vec(ba["translate"], t)
		if ba.has("scale"):
			var sc: Vector2 = _interp_vec(ba["scale"], t)
			n.scale = Vector2(_setup_scale[String(bn)]) * sc
	var slots_anim: Dictionary = anim.get("slots", {})
	for sn in slots_anim:
		var sa: Dictionary = slots_anim[sn]
		var has_att: bool = sa.has("attachment")
		var has_col: bool = sa.has("color")
		if not has_att and not has_col:
			continue
		var target_att: String = ""
		var att_set: bool = false
		if has_att:
			var default_att: String = ""
			for e in _slot_sprites:
				if String(e["slot_name"]) == String(sn):
					default_att = String(e.get("default_att", ""))
					break
			target_att = _slot_attachment_at(sa["attachment"], t, default_att)
			att_set = true
		var col: Color = Color.WHITE
		if has_col:
			col = _interp_color(sa["color"], t)
		for e in _slot_sprites:
			if String(e["slot_name"]) == String(sn):
				var sp: Sprite2D = e["sprite"]
				if att_set:
					if target_att.is_empty():
						sp.visible = false
					else:
						var tex: Texture2D = _atlas.get_region_texture(target_att)
						if tex != null:
							sp.texture = tex
						sp.visible = true
				if has_col:
					sp.modulate = col


func _get_action_duration(action: String) -> float:
	var anim: Dictionary = _data.animations.get(action, {})
	var max_t: float = 0.0
	var bones_anim: Dictionary = anim.get("bones", {})
	for bn in bones_anim:
		var ba: Dictionary = bones_anim[bn]
		for k in ["rotate", "translate", "scale"]:
			if ba.has(k):
				max_t = max(max_t, _last_time(ba[k]))
	var slots_anim: Dictionary = anim.get("slots", {})
	for sn in slots_anim:
		var sa: Dictionary = slots_anim[sn]
		for k in ["color"]:
			if sa.has(k):
				max_t = max(max_t, _last_time(sa[k]))
	return max_t


func _last_time(timeline: Array) -> float:
	if timeline.is_empty():
		return 0.0
	return float(timeline[timeline.size() - 1].get("time", 0.0))


# 找 t 落在哪两个关键帧之间 + curve 插值 alpha。
func _keyframes(timeline: Array, t: float) -> Dictionary:
	if timeline.is_empty():
		return {}
	var first: Dictionary = timeline[0]
	if t <= float(first.get("time", 0.0)):
		return {"i0": 0, "i1": 0, "alpha": 0.0}
	var last: int = timeline.size() - 1
	var lf: Dictionary = timeline[last]
	if t >= float(lf.get("time", 0.0)):
		return {"i0": last, "i1": last, "alpha": 0.0}
	for i in last:
		var t0: float = float(timeline[i].get("time", 0.0))
		var t1: float = float(timeline[i + 1].get("time", 0.0))
		if t >= t0 and t < t1:
			var raw: float = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
			return {"i0": i, "i1": i + 1, "alpha": _eval_curve(timeline[i].get("curve", "linear"), raw)}
	return {"i0": last, "i1": last, "alpha": 0.0}


func _eval_curve(curve: Variant, raw: float) -> float:
	# curve 是 String（"linear"/"stepped"）或 Array（贝塞尔 [c1,c2,c3,c4]）。
	# 先 typeof 避免 String(Array/float) 构造器报 Nonexistent（GDScript 4 String(Variant) 限制，[[gdscript-string-constructor-variant]]）。
	if typeof(curve) == TYPE_STRING:
		return 0.0 if String(curve) == "stepped" else raw
	if typeof(curve) == TYPE_ARRAY and (curve as Array).size() >= 4:
		var c: Array = curve
		return _bezier_y(raw, float(c[0]), float(c[1]), float(c[2]), float(c[3]))
	return raw


# P0=(0,0) P1=(c1,c2) P2=(c3,c4) P3=(1,1)，给 x=tx 牛顿迭代求 y。
func _bezier_y(tx: float, c1: float, c2: float, c3: float, c4: float) -> float:
	var t: float = tx
	for _i in 5:
		var x: float = _bez(t, c1, c3)
		var dx: float = _bez_d(t, c1, c3)
		if absf(dx) < 1e-6:
			break
		t = clampf(t - (x - tx) / dx, 0.0, 1.0)
	return _bez(t, c2, c4)


func _bez(t: float, p1: float, p2: float) -> float:
	var mt: float = 1.0 - t
	return 3.0 * mt * mt * t * p1 + 3.0 * mt * t * t * p2 + t * t * t


func _bez_d(t: float, p1: float, p2: float) -> float:
	var mt: float = 1.0 - t
	return 3.0 * mt * mt * p1 + 6.0 * mt * t * (p2 - p1) + 3.0 * t * t * (1.0 - p2)


func _interp_num(timeline: Array, t: float, field: String) -> float:
	var k: Dictionary = _keyframes(timeline, t)
	if k.is_empty():
		return 0.0
	var v0: float = float(timeline[k["i0"]].get(field, 0.0))
	var v1: float = float(timeline[k["i1"]].get(field, 0.0))
	return v0 + (v1 - v0) * float(k["alpha"])


func _interp_vec(timeline: Array, t: float) -> Vector2:
	var k: Dictionary = _keyframes(timeline, t)
	if k.is_empty():
		return Vector2.ZERO
	var f0: Dictionary = timeline[k["i0"]]
	var f1: Dictionary = timeline[k["i1"]]
	var a: float = float(k["alpha"])
	return Vector2(float(f0.get("x", 0.0)) + (float(f1.get("x", 0.0)) - float(f0.get("x", 0.0))) * a, float(f0.get("y", 0.0)) + (float(f1.get("y", 0.0)) - float(f0.get("y", 0.0))) * a)


func _interp_color(timeline: Array, t: float) -> Color:
	var k: Dictionary = _keyframes(timeline, t)
	if k.is_empty():
		return Color.WHITE
	var c0: Color = SpineSkeletonData.parse_color_hex(String(timeline[k["i0"]].get("color", "ffffffff")))
	var c1: Color = SpineSkeletonData.parse_color_hex(String(timeline[k["i1"]].get("color", "ffffffff")))
	return c0.lerp(c1, float(k["alpha"]))


# Spine slot attachment timeline（序列帧切换）：找 t 时刻该 slot 显示的 attachment 名。
# timeline = [{time, name}]，name=null/空=隐藏，name=附件名=显示。t < 首帧 time 时用 slot 默认 attachment。
func _slot_attachment_at(timeline: Array, t: float, default_att: String) -> String:
	if timeline.is_empty():
		return default_att
	var first_time: float = float(timeline[0].get("time", 0.0))
	if t < first_time:
		return default_att   # t 在首帧之前，用 slot 默认 attachment
	var last_name: String = ""
	for i in timeline.size():
		var frame: Dictionary = timeline[i]
		if float(frame.get("time", 0.0)) <= t:
			var n: Variant = frame.get("name", null)
			last_name = "" if n == null else String(n)
		else:
			break
	return last_name
