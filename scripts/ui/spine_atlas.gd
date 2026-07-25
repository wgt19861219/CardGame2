class_name SpineAtlas
extends RefCounted

## Spine .atlas 解析器（View 层）— Spine 2.1.07 region 纹理提取。
## 配套 assets/spine/<name>/<name>.atlas + <name>.png。region xy 左下原点 → Godot 左上翻转。

var _regions: Dictionary = {}    # region_name -> {xy: Vector2i, size: Vector2i, rotate: bool, orig, offset}
var _region_cache: Dictionary = {}   # region_name -> ImageTexture（get_region_texture 缓存，避免每帧重建）
var _sheet_image: Image = null
var _sheet_size: Vector2i = Vector2i.ZERO
var _loaded: bool = false


## 读 <atlas_path>（.atlas 文本）+ 同目录 .png，解析 region 块。
func load_atlas(atlas_path: String) -> bool:
	var f: FileAccess = FileAccess.open(atlas_path, FileAccess.READ)
	if f == null:
		push_warning("SpineAtlas: 无法打开 .atlas: " + atlas_path)
		return false
	var text: String = f.get_as_text()
	f.close()
	_parse_atlas_text(text)
	var png_path: String = atlas_path.get_basename() + ".png"
	var tex: Texture2D = load(png_path) as Texture2D
	if tex == null:
		push_warning("SpineAtlas: 无法加载 .png: " + png_path)
		return false
	_sheet_image = tex.get_image()
	_sheet_size = Vector2i(int(tex.get_width()), int(tex.get_height()))
	_loaded = not _regions.is_empty() and _sheet_image != null
	if not _loaded:
		push_warning("SpineAtlas: 未解析到 region: " + atlas_path)
	return _loaded


# .atlas 格式：空行 + 页面头（png 名 + size:/format:/filter:/repeat:）+ region 块（名 + 缩进字段）。
# 跳过页面头（含冒号 / endswith .png / 空行）→ 首个非缩进非冒号行 = region 名；缩进行 = 字段。
func _parse_atlas_text(text: String) -> void:
	var lines: PackedStringArray = text.split("\n")
	var current: String = ""
	var i: int = 0
	while i < lines.size():
		var s: String = lines[i].strip_edges()
		if s == "" or s.ends_with(".png") or s.find(":") >= 0:
			i += 1
			continue
		break   # 首个 region 名
	while i < lines.size():
		var raw: String = lines[i]
		var s: String = raw.strip_edges()
		if s == "":
			i += 1
			continue
		var indented: bool = raw.length() > 0 and (raw[0] == " " or raw[0] == "\t")
		if not indented:
			current = s
			_regions[current] = {"rotate": false, "xy": Vector2i.ZERO, "size": Vector2i.ZERO, "orig": Vector2i.ZERO, "offset": Vector2i.ZERO}
		elif current != "":
			_parse_region_field(_regions[current], s)
		i += 1


func _parse_region_field(r: Dictionary, s: String) -> void:
	var colon: int = s.find(":")
	if colon < 0:
		return
	var key: String = s.substr(0, colon).strip_edges()
	var val: String = s.substr(colon + 1).strip_edges()
	match key:
		"rotate":
			r["rotate"] = (val == "true")
		"xy":
			r["xy"] = _parse_vec2i(val)
		"size":
			r["size"] = _parse_vec2i(val)
		"orig":
			r["orig"] = _parse_vec2i(val)
		"offset":
			r["offset"] = _parse_vec2i(val)


func _parse_vec2i(s: String) -> Vector2i:
	var p: PackedStringArray = s.replace(" ", "").split(",")
	if p.size() >= 2:
		return Vector2i(int(float(p[0])), int(float(p[1])))
	return Vector2i.ZERO


## 取 region 纹理（atlas xy 左下 → Godot 左上：godot_y = sheet_h - xy_y - size_h）。
func get_region_texture(region_name: String) -> Texture2D:
	if _region_cache.has(region_name):
		return _region_cache[region_name]
	if not _regions.has(region_name) or _sheet_image == null:
		return null
	var r: Dictionary = _regions[region_name]
	var xy: Vector2i = r["xy"]
	var sz: Vector2i = r["size"]
	var rotate: bool = r["rotate"]
	if sz.x <= 0 or sz.y <= 0:
		return null
	# rotate region 在图集里按旋转后宽高存储（宽高 swap），取 region 用存储朝向，rotate_90 转回原朝向 sz
	var stored_w: int = int(sz.y) if rotate else int(sz.x)
	var stored_h: int = int(sz.x) if rotate else int(sz.y)
	var godot_y: int = _sheet_size.y - xy.y - stored_h
	var rect: Rect2i = Rect2i(xy.x, godot_y, stored_w, stored_h)
	var img: Image = _sheet_image.get_region(rect)
	if rotate:
		img.rotate_90(1)
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_region_cache[region_name] = tex
	return tex


func get_region_size(region_name: String) -> Vector2:
	if not _regions.has(region_name):
		return Vector2.ZERO
	return Vector2(_regions[region_name]["size"])


## 取面积最大的 region 纹理（照源 createStaticSpriteFromSpineAtlas 选最大 area region，
## resource_manager.lua:548-558）。unlock 公告不传 aniType → Spine 资源走此静态图 fallback。
func get_largest_region_texture() -> Texture2D:
	var best_name: String = ""
	var best_area: int = 0
	for name in _regions:
		var r: Dictionary = _regions[name]
		var sz: Vector2i = r["size"]
		# rotate 时宽高互换（照源 :553-554 w/h 交换）
		var w: int = int(sz.y) if bool(r["rotate"]) else int(sz.x)
		var h: int = int(sz.x) if bool(r["rotate"]) else int(sz.y)
		var area: int = w * h
		if area > best_area:
			best_area = area
			best_name = String(name)
	if best_name.is_empty():
		return null
	return get_region_texture(best_name)


func has_region(region_name: String) -> bool:
	return _regions.has(region_name)


func is_loaded() -> bool:
	return _loaded
