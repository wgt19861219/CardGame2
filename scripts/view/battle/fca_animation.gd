class_name FcaAnimation
extends Node2D

## FCA 散件动画播放器（View 层）— 解析 .key 二进制，驱动 Sprite2D 散件帧动画。
## 配套 res://assets/anim_frames/<resource>.ani（zip，含 sheet.key）+ AtlasSprite（sheet.plist/png）。

signal action_finished(action_name: String)

# 坐标转换系数 — 源 ed.cha_scale（战斗 0.09）/ ed.cha_ui_scale（UI eff_UI_ 前缀 0.39）。
# 当前 FCA 用 _coord_scale（load_from_ani 检 UI 前缀定，默认战斗 0.09）。
const BATTLE_SCALE: float = 0.09
const UI_SCALE: float = 0.39
const UI_RES_PREFIX: String = "eff_UI"
var _coord_scale: float = BATTLE_SCALE

# ── 静态缓存（resource_name -> {elements, actions, action_names}）──
static var _cache: Dictionary = {}

# ── 解析数据 ──
var _elements: Array = []       # [{layer, resource, index}]
var _actions: Dictionary = {}   # action_name -> {fps, frames}
var _action_names: PackedStringArray = []

# ── 散件精灵（按 element index 0-based 排列）──
var _sprites: Array = []

# ── 播放状态 ──
var _action: String = ""
var _elapsed: float = 0.0
var _loop: bool = true
var _speed: float = 1.0
var _playing: bool = false
var _finished: bool = false
var _next_action: String = ""


func load_from_ani(resource: String, atlas: AtlasSprite) -> bool:
	_coord_scale = UI_SCALE if resource.contains(UI_RES_PREFIX) else BATTLE_SCALE
	var cached: Dictionary = _cache.get(resource, {})
	if not cached.is_empty():
		_elements = cached["elements"]
		_actions = cached["actions"]
		_action_names = cached["action_names"]
		_create_sprites(atlas)
		return true

	var key_data: PackedByteArray = _read_key_data(resource)
	if key_data.is_empty():
		return false

	var parsed: Dictionary = _parse_key(key_data)
	if parsed.is_empty():
		return false

	_cache[resource] = parsed
	_elements = parsed["elements"]
	_actions = parsed["actions"]
	_action_names = parsed["action_names"]
	_create_sprites(atlas)
	return true


func _read_key_data(resource: String) -> PackedByteArray:
	# 单位资源 .ani（zip），特效资源 .abc（zip，同结构）—— 两种扩展名都试
	for ext in [".ani", ".abc"]:
		var zip_path: String = "res://assets/anim_frames/" + resource + ext
		if FileAccess.file_exists(zip_path):  # .abc/.ani 是 zip 非 Godot 资源
			var reader: ZIPReader = ZIPReader.new()
			if reader.open(zip_path) == OK:
				# .ani 用 "sheet.key"，.abc 用 "cha"（同格式，源 LegendAnimationFileInfo 适配）
				var files: PackedStringArray = reader.get_files()
				var key_entry: String = "sheet.key" if files.has("sheet.key") else "cha"
				var data: PackedByteArray = reader.read_file(key_entry)
				reader.close()
				if not data.is_empty():
					return data

	var key_path: String = "res://assets/anim_frames/" + resource + "/sheet.key"
	if FileAccess.file_exists(key_path):
		var f: FileAccess = FileAccess.open(key_path, FileAccess.READ)
		if f:
			var data: PackedByteArray = f.get_buffer(f.get_length())
			f.close()
			return data

	return PackedByteArray()


func _parse_key(data: PackedByteArray) -> Dictionary:
	var off: int = 0
	var total: int = data.size()

	if total < 8:
		return {}

	off = _skip_string(data, off)
	if off < 0:
		return {}

	var elem_count: int = data.decode_u32(off); off += 4
	var elements: Array = []
	for _i in range(elem_count):
		if off + 4 > total:
			break
		var layer: String = _read_string(data, off)
		off += 4 + layer.length()
		var resource: String = _read_string(data, off)
		off += 4 + resource.length()
		var idx: int = data.decode_u32(off); off += 4
		elements.append({layer = layer, resource = resource, index = idx})

	if off + 4 > total:
		return {}
	var action_count: int = data.decode_u32(off); off += 4

	var actions: Dictionary = {}
	var action_names: PackedStringArray = []

	for _ai in range(action_count):
		if off + 4 > total:
			break
		var aname: String = _read_string(data, off)
		off += 4 + aname.length()

		if off + 8 > total:
			break
		var fps: float = data.decode_float(off); off += 4
		var frame_count: int = data.decode_u32(off); off += 4

		var frames: Array = []
		for _fi in range(frame_count):
			if off + 4 > total:
				break
			var event_count: int = data.decode_u32(off); off += 4
			var events: Array = []
			for _ei in range(event_count):
				if off + 4 > total:
					break
				var evt_type: int = data.decode_u32(off); off += 4
				var evt_arg: String = _read_string(data, off)
				off += 4 + evt_arg.length()
				off += 8   # x1, x2 (2 floats)
				off += 24  # affine (6 floats)
				off += 4   # zorder
				events.append({type = evt_type, arg = evt_arg})

			if off + 4 > total:
				break
			var fe_count: int = data.decode_u32(off); off += 4
			var frame_elems: Array = []
			for _fei in range(fe_count):
				if off + 27 > total:
					break
				var fe_idx: int = data.decode_u16(off); off += 2
				var fe_alpha: int = data[off]; off += 1
				var a: float = data.decode_float(off); off += 4
				var b: float = data.decode_float(off); off += 4
				var c: float = data.decode_float(off); off += 4
				var d: float = data.decode_float(off); off += 4
				var tx: float = data.decode_float(off); off += 4
				var ty: float = data.decode_float(off); off += 4
				frame_elems.append({idx = fe_idx, alpha = fe_alpha, a = a, b = b, c = c, d = d, tx = tx, ty = ty})
			frames.append({events = events, elements = frame_elems})

		actions[aname] = {fps = fps, frames = frames}
		action_names.append(aname)

	return {elements = elements, actions = actions, action_names = action_names}


func _read_string(data: PackedByteArray, off: int) -> String:
	var slen: int = data.decode_u32(off)
	return data.slice(off + 4, off + 4 + slen).get_string_from_ascii()


func _skip_string(data: PackedByteArray, off: int) -> int:
	if off + 4 > data.size():
		return -1
	var slen: int = data.decode_u32(off)
	return off + 4 + slen


func _create_sprites(atlas: AtlasSprite) -> void:
	for elem: Dictionary in _elements:
		var res: String = elem.get("resource", "")
		var tex: Texture2D = atlas.get_part_texture(res + ".png")
		var s: Sprite2D = Sprite2D.new()
		s.name = res
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if tex:
			s.texture = tex
		else:
			s.visible = false
		add_child(s)
		_sprites.append(s)
	# Node2D 整体 scale（等价源 batchNode setScale，缩 sprite 渲染 + 子坐标 + a/b/c/d 反向后净效果）。
	scale = Vector2(_coord_scale, _coord_scale)


# ── 播放控制 ──

func play(action: String, loop: bool = true) -> void:
	if not _actions.has(action):
		return
	_next_action = ""
	_action = action
	_elapsed = 0.0
	_loop = loop
	_playing = true
	_finished = false
	set_process(true)
	var frames: Array = _actions[action].get("frames", [])
	if frames.size() > 0:
		_apply_frame(frames[0])


func set_next_action(action: String) -> void:
	_next_action = action


func set_speed(s: float) -> void:
	_speed = clampf(s, 0.1, 10.0)


func stop() -> void:
	_playing = false
	set_process(false)


func is_playing() -> bool:
	return _playing


func is_finished() -> bool:
	return _finished


static func clear_cache() -> void:
	_cache.clear()


func has_action(action: String) -> bool:
	return _actions.has(action)


func get_action_names() -> PackedStringArray:
	return _action_names


func get_action_duration(action: String) -> float:
	var a: Dictionary = _actions.get(action, {})
	if a.is_empty():
		return 0.0
	return float(a.get("frames", []).size()) / a.get("fps", 24.0)


func get_attack_frame_time(action: String) -> float:
	var a: Dictionary = _actions.get(action, {})
	if a.is_empty():
		return 0.0
	var fps: float = a.get("fps", 24.0)
	var frames: Array = a.get("frames", [])
	for i in range(frames.size()):
		var events: Array = frames[i].get("events", [])
		for evt: Dictionary in events:
			if evt.get("type", -1) == 0:
				return float(i) / fps
	return 0.0


func get_current_action() -> String:
	return _action


func _process(delta: float) -> void:
	if not _playing:
		return

	_elapsed += delta * _speed

	var action: Dictionary = _actions.get(_action, {})
	if action.is_empty():
		_playing = false
		return

	var fps: float = action.get("fps", 24.0)
	var frames: Array = action.get("frames", [])
	var frame_count: int = frames.size()
	if frame_count == 0:
		_playing = false
		return

	var frame_time: float = 1.0 / fps
	var total_time: float = frame_time * float(frame_count)

	if _elapsed >= total_time:
		if _loop:
			_elapsed = fmod(_elapsed, total_time)
		else:
			_elapsed = total_time - 0.001
			_playing = false
			_finished = true
			set_process(false)
			_apply_frame(frames[frame_count - 1])
			action_finished.emit(_action)
			if not _next_action.is_empty():
				var next: String = _next_action
				_next_action = ""
				play(next, true)
			return

	var frame_idx: int = int(_elapsed / frame_time)
	frame_idx = mini(frame_idx, frame_count - 1)
	_apply_frame(frames[frame_idx])


func _apply_frame(frame: Dictionary) -> void:
	var elements: Array = frame.get("elements", [])
	for s: Sprite2D in _sprites:
		s.visible = false

	var draw_order: int = 0
	for fe: Dictionary in elements:
		var idx: int = fe.get("idx", 0) - 1
		if idx < 0 or idx >= _sprites.size():
			continue

		var sprite: Sprite2D = _sprites[idx]
		sprite.visible = true
		sprite.z_index = draw_order
		draw_order += 1

		var a: float = fe.get("a", 1.0)
		var b: float = fe.get("b", 0.0)
		var c: float = fe.get("c", 0.0)
		var d: float = fe.get("d", 1.0)
		var tx: float = fe.get("tx", 0.0)
		var ty: float = fe.get("ty", 0.0)

		# origin 用原始 tx/ty（Node2D scale 整体缩，等价源 batchNode setScale）。
		var factor: float = 1.0 / _coord_scale
		sprite.transform = Transform2D(
			Vector2(a * factor, b * factor),
			Vector2(c * factor, d * factor),
			Vector2(tx, ty)
		)

		var alpha: int = fe.get("alpha", 255)
		sprite.modulate.a = float(alpha) / 255.0
