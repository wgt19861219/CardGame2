class_name AtlasSprite
extends RefCounted

## plist 散件加载器（View 层）— 解析 Axmol plist 精灵图集，提取散件纹理。
## 配套 res://assets/anim_frames/<resource>/sheet.plist + sheet.png（.ani zip 解压产物）。

var _parts: Dictionary = {}
var _sheet_image: Image = null
var _loaded: bool = false
var _part_texture_cache: Dictionary = {}  # part_name→ImageTexture 缓存（同 AtlasSprite 跨 FCA 实例复用，减重复 get_region+create_from_image）


func load_atlas(plist_path: String) -> bool:
	var file := FileAccess.open(plist_path, FileAccess.READ)
	if file == null:
		push_warning("AtlasSprite: 无法打开 plist: " + plist_path)
		return false
	var xml_text := file.get_as_text()
	file.close()

	_parse_frames_from_plist_text(xml_text)
	_load_sheet_image(plist_path)

	if _parts.is_empty():
		push_warning("AtlasSprite: 未找到散件: " + plist_path)
		return false

	_loaded = true
	return true


## 从 .ani/.abc zip 加载 atlas（单位 .ani: sheet.plist+sheet.png；特效 .abc: plist+sheet.pvr）。
func load_atlas_from_ani(ani_path: String) -> bool:
	var reader := ZIPReader.new()
	if reader.open(ani_path) != OK:
		push_warning("AtlasSprite: 无法打开 zip: " + ani_path)
		return false
	# .abc 用 "plist" + "sheet.png"（PVR 已批量转 PNG，tools/convert_abc_pvr.py）
	# .ani 用 "sheet.plist" + "sheet.png"
	var files: PackedStringArray = reader.get_files()
	var plist_entry: String = "sheet.plist" if files.has("sheet.plist") else "plist"
	var plist_bytes: PackedByteArray = reader.read_file(plist_entry)
	var image_entry: String = "sheet.png" if files.has("sheet.png") else "sheet.pvr"
	var image_bytes: PackedByteArray = reader.read_file(image_entry)
	reader.close()
	if plist_bytes.is_empty() or image_bytes.is_empty():
		push_warning("AtlasSprite: zip 缺 plist/png/pvr: " + ani_path)
		return false
	_parse_frames_from_plist_text(plist_bytes.get_string_from_utf8())
	_load_sheet_image_from_bytes(image_bytes)
	if _parts.is_empty():
		push_warning("AtlasSprite: 未解析到散件: " + ani_path)
		return false
	_loaded = true
	return true


func _parse_frames_from_plist_text(text: String) -> void:
	var lines := text.split("\n")
	var i := 0
	while i < lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("<key>") and line.ends_with("</key>"):
			var key_text := line.replace("<key>", "").replace("</key>", "").strip_edges()
			if key_text.ends_with(".png") and key_text != "textureFilename":
				var part_name := key_text
				i += 1
				var frame_data := {}
				var dict_depth := 0
				while i < lines.size():
					var l := lines[i].strip_edges()
					if l == "<dict>":
						dict_depth += 1
						if dict_depth == 1:
							i += 1
							continue
					if l == "</dict>":
						dict_depth -= 1
						if dict_depth == 0:
							break
					if l.begins_with("<key>") and l.ends_with("</key>"):
						var fkey := l.replace("<key>", "").replace("</key>", "").strip_edges()
						i += 1
						if i < lines.size():
							var fval := lines[i].strip_edges()
							if fval.begins_with("<string>"):
								fval = fval.replace("<string>", "").replace("</string>", "").strip_edges()
								frame_data[fkey] = fval
							elif fval.begins_with("<true"):
								frame_data[fkey] = true
							elif fval.begins_with("<false"):
								frame_data[fkey] = false
					i += 1
				if not frame_data.is_empty():
					_parts[part_name] = _parse_frame_data(frame_data)
		i += 1


func _parse_frame_data(data: Dictionary) -> Dictionary:
	var result := {}
	if data.has("frame"):
		result["region"] = _parse_rect(data["frame"])
	if data.has("offset"):
		result["offset"] = _parse_vec2(data["offset"])
	if data.has("sourceSize"):
		result["source_size"] = _parse_vec2(data["sourceSize"])
	result["rotated"] = data.get("rotated", false)
	return result


func _parse_rect(s: String) -> Rect2i:
	s = s.replace("{", "").replace("}", "").replace(" ", "")
	var parts := s.split(",")
	if parts.size() >= 4:
		return Rect2i(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]))
	return Rect2i()


func _parse_vec2(s: String) -> Vector2:
	s = s.replace("{", "").replace("}", "").replace(" ", "")
	var parts := s.split(",")
	if parts.size() >= 2:
		return Vector2(float(parts[0]), float(parts[1]))
	return Vector2()


func _load_sheet_image(plist_path: String) -> void:
	var dir := plist_path.get_base_dir()
	var png_path := dir.path_join("sheet.png")
	if ResourceLoader.exists(png_path):
		var tex := load(png_path) as Texture2D
		if tex:
			_sheet_image = tex.get_image()
		return
	var tex := load(png_path) as Texture2D
	if tex:
		_sheet_image = tex.get_image()
	else:
		push_warning("AtlasSprite: 无法加载 sheet.png: " + png_path)


func _load_sheet_image_from_bytes(png_bytes: PackedByteArray) -> void:
	var img := Image.new()
	if img.load_png_from_buffer(png_bytes) == OK:
		_sheet_image = img
	else:
		push_warning("AtlasSprite: 无法从 bytes 加载 sheet.png")


func get_part_texture(part_name: String) -> Texture2D:
	if _part_texture_cache.has(part_name):
		return _part_texture_cache[part_name]
	if not _parts.has(part_name) or _sheet_image == null:
		return null
	var info: Dictionary = _parts[part_name]
	var region: Rect2i = info.get("region", Rect2i())
	var rotated: bool = info.get("rotated", false)
	if region.size.x <= 0 or region.size.y <= 0:
		return null
	var img: Image
	if rotated:
		var atlas_rect := Rect2i(region.position.x, region.position.y, region.size.y, region.size.x)
		img = _sheet_image.get_region(atlas_rect)
		img.rotate_90(1)
	else:
		img = _sheet_image.get_region(region)
	var tex := ImageTexture.create_from_image(img)
	_part_texture_cache[part_name] = tex  # 缓存（跨 FCA 实例共享同 AtlasSprite 时复用，546 DummyTexture/重复 ImageTexture leak 缓解）
	return tex


func get_part_source_size(part_name: String) -> Vector2:
	if not _parts.has(part_name):
		return Vector2()
	return _parts[part_name].get("source_size", Vector2())


func get_part_offset(part_name: String) -> Vector2:
	if not _parts.has(part_name):
		return Vector2()
	return _parts[part_name].get("offset", Vector2())


func get_part_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for k: String in _parts:
		if k.ends_with(".png"):
			names.append(k)
	return names


func get_sheet_image() -> Image:
	return _sheet_image


func is_loaded() -> bool:
	return _loaded


func unload() -> void:
	_parts.clear()
	_part_texture_cache.clear()
	_sheet_image = null
	_loaded = false
