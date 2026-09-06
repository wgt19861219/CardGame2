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
# 散件内容缩放（ContentScaleFactor 1.28125）— 仅 unit 傀儡/立绘族散件渲染 ÷CS。
# 2026-09-03 原版锚点标定：船长详情立绘（unit 族）未÷CS 时横向系统性偏宽（帽宽/身高 1.00 vs
# 原版 0.72）；÷CS 后 0.71 精确命中（验收记录-船长详情动画比例调查）。
# ⚠️ 特效族（eff_ 前缀，effect/ 目录 .abc）不 ÷CS：源/本项目 plist sourceSize 逐项相同
# （资产同源仅 pvr→png 转码，非 1.28× 高清重制），÷CS 使特效整体缩小 22%、多散件错位
# ——2026-09-06 宙斯大招回归（game bridge A/B 定格实测：÷CS 细线 35502 高亮像素 vs
# 不÷CS 粗壮闪电 57523；"技能动画错乱"用户主诉），仅 unit 族有 MuMu 标定实证。
const PART_CONTENT_SCALE: float = 1.28125
const EFFECT_RES_PREFIX: String = "eff_"
var _coord_scale: float = BATTLE_SCALE
var _effect_res: bool = false
var _external_positioning: bool = false

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
var _applied_frame: int = -1   # 已应用帧索引（set_action_elapsed 防重复 apply）


func load_from_ani(resource: String, atlas: AtlasSprite) -> bool:
	_coord_scale = UI_SCALE if resource.contains(UI_RES_PREFIX) else BATTLE_SCALE
	_effect_res = resource.begins_with(EFFECT_RES_PREFIX)
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
	# 单位资源 .ani（zip），特效资源 .abc（zip，同结构）—— 两种扩展名都试。
	# 资源可能在根目录或 effect/ 子目录（数据表值无前缀但文件在 effect/ 下），两种都试。
	for base_dir in ["", "effect/"]:
		for ext in [".ani", ".abc"]:
			var zip_path: String = "res://assets/anim_frames/" + base_dir + resource + ext
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


# 加法混合（源 C++ FCA 特效渲染默认加色合成；Godot Sprite2D 默认普通 alpha 混合，
# 半透明光效贴图会渲染成灰白半透色块而非发光——eff_UI 光效族必须 ADD，2026-09-05 实机 A/B 定谳）。
func set_additive_blend() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for s in _sprites:
		(s as Sprite2D).material = mat


# 外部定位模式（照源 setExternalPositioning，chain.lua:104 唯一消费方）：丢弃 cha 仿射，
# 散件以纹理原尺寸居中，节点变换完全由消费方控制（C++ applyFrame external 分支等价）。
func set_external_positioning(enabled: bool = true) -> void:
	_external_positioning = enabled


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
	_applied_frame = -1
	set_process(true)
	var frames: Array = _actions[action].get("frames", [])
	if frames.size() > 0:
		_apply_frame(frames[0])


func set_next_action(action: String) -> void:
	_next_action = action


func set_speed(s: float) -> void:
	# 上限 16：战斗内动画速度 = speeder×2×档位（4x 档 MSPD 50% 时 = 12），旧上限 10 会截高档
	_speed = clampf(s, 0.1, 16.0)


# 照源 LegendAnimation::setActionElapsed（C++ :176-203）：动作时间锚定——帧索引
# clamp/loop 到范围并应用帧，不改 _playing（后续 _process 继续自由推进，锚定仅校正）。
# 施法中每 tick 由 battle_actor 调用，把动作帧锚到技能 phase 进度（源 skill.lua:242
# gotoEventIdx 的 setActionElapsed 等效）——替代原 cast_rate_for 整体慢放（自创方案，
# 大招特效常速播而动作龟速拉伸 = "技能播放比人物响应动画快"根因，2026-08-19）。
func set_action_elapsed(elapsed: float) -> void:
	var action: Dictionary = _actions.get(_action, {})
	var frames: Array = action.get("frames", [])
	if frames.is_empty():
		_elapsed = elapsed
		return
	var fps: float = action.get("fps", 24.0)
	var total_t: float = float(frames.size()) / fps
	_elapsed = clampf(elapsed, 0.0, total_t - _FRAME_EPS)
	var new_frame: int = int(_elapsed * fps)
	if new_frame >= frames.size():
		new_frame = frames.size() - 1
	if new_frame != _applied_frame:
		_applied_frame = new_frame
		_apply_frame(frames[new_frame])


const _FRAME_EPS: float = 0.001   # 锚定钳到末帧内，防 _process 立即触发 finished


# 内容居中：按当前帧可见散件的真实包围盒中心（四角变换，几何正确）把整体平移到节点原点。
# 供大位移资源消费方用（幽灵船投射物等 tx/ty ±5000 的数据，内容中心偏离原点缩后 500px+
# 直接飞出屏幕）；小位移资源调用为近似无操作。首帧后动画内容波动小，一次补偿全程有效。
func center_content() -> void:
	var bmin := Vector2(1e9, 1e9)
	var bmax := Vector2(-1e9, -1e9)
	for c in get_children():
		var s := c as Sprite2D
		if s == null or not s.visible or s.texture == null:
			continue
		var half: Vector2 = s.texture.get_size() * 0.5
		for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(-half.x, half.y), Vector2(half.x, half.y)]:
			var world: Vector2 = s.transform * corner
			bmin = bmin.min(world)
			bmax = bmax.max(world)
	if bmax.x <= bmin.x:
		return   # 无可见内容
	var center: Vector2 = (bmin + bmax) * 0.5
	# 补偿作用于父坐标：当前帧内容中心（FCA 局部，含 sprite transform）× 节点 scale。
	position -= center * scale


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
			_applied_frame = frame_count - 1
			_apply_frame(frames[frame_count - 1])
			action_finished.emit(_action)
			if not _next_action.is_empty():
				var next: String = _next_action
				_next_action = ""
				play(next, true)
			return

	var frame_idx: int = int(_elapsed / frame_time)
	frame_idx = mini(frame_idx, frame_count - 1)
	if frame_idx != _applied_frame:
		_applied_frame = frame_idx
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

		# external positioning 模式（照源 setExternalPositioning，C++ applyFrame external 分支）：
		# 丢弃 cha 仿射与骨架 tx/ty，散件以纹理原尺寸居中（centered=true 即中心锚）——
		# 消费方在节点上直接 setPosition/setRotation/setScale 控制。链条（chain.lua:104
		# setExternalPositioning(true)）唯一消费方：贴图 985×55 原尺寸 × 节点 scale 即细闪电带；
		# 若应用仿射则 a×1/0.09 失控放大（33000px 全屏巨闪，2026-09-06 宙斯连锁闪电回归）。
		if _external_positioning:
			sprite.transform = Transform2D.IDENTITY
			var alpha_e: int = fe.get("alpha", 255)
			sprite.modulate.a = float(alpha_e) / 255.0
			continue

		# ⚠️ tx/ty 原样用于 y-down（源 C++ readFrames 另有 b/c 取反+锚点补偿+ty 取反的
		# adjustment，系 Cocos anchor(0,0)/y-up 语境，直译进 Godot centered/y-down 会翻转
		# 元素朝向——2026-08-19 实测人物元素散架已回退。小位移资源偏差无感；大位移资源
		# （幽灵船投射物）的偏移由消费方按需补偿。
		# ÷CS 仅 unit 傀儡/立绘族（MuMu 标定）；特效族（eff_ 前缀）不÷CS（同上常量注释，
		# 2026-09-06 宙斯大招回归根修）。
		var factor: float = 1.0 / _coord_scale
		if not _effect_res:
			factor /= PART_CONTENT_SCALE
		sprite.transform = Transform2D(
			Vector2(a * factor, b * factor),
			Vector2(c * factor, d * factor),
			Vector2(tx, ty)
		)

		var alpha: int = fe.get("alpha", 255)
		sprite.modulate.a = float(alpha) / 255.0
