class_name TexDisplaySize
extends RefCounted

## sprite 显示尺寸工具（照源 resource_manager.lua:44-57 getSpriteOriginalScale +
## :58-76 createSprite 翻译）。
##
## Cocos 显示尺寸 = 纹理 × ContentScale。
## setContentScaleFactor（hello.lua:311）是 Director 级渲染缩放（设计分辨率→屏幕映射），
## Godot 960×640 viewport 直接等价源设计分辨率，CS 被屏幕分辨率抵消，不影响 sprite 占屏比例。
## 故 Godot 显示像素 = 纹理像素 × ContentScale（不除 CS）。
##
## ContentScale 规则（源 getSpriteOriginalScale :44-56）：
##   TextureConfig 无条目 → 1；Prescaled=false（Win32）→ 1；ContentScale=0 → 1；否则 ContentScale。
## 修正（2026-07-20）：此前 base*cs/CONTENT_SCALE 多除 CS 致 sprite 偏小 1.28×
## （stage_select frame 实测 76%×61%，源照源应 97%×79%，用户截图比对发现）。

const TEXTURE_CONFIG_JSON: String = "res://resources/data/TextureConfig.json"

static var _tex_config_cache: Dictionary = {}


# sprite 显示尺寸 = 纹理原尺寸 × ContentScale（源 createSprite 等价，不除 CS）。
static func display_size(res_path: String) -> Vector2:
	var base: Vector2 = _base_size(res_path)
	var cs: float = content_scale_of(res_path)
	return base * cs


static func content_scale_of(res_path: String) -> float:
	# res://assets/ui/alpha/HVGA/x.png → UI/alpha/HVGA/x.png（TextureConfig key 源大写 UI）
	# 本项目 assets 目录用小写 ui（windows 不分大小写），TextureConfig key 保留源大写。
	var ui_key: String = res_path.replace("res://assets/ui/", "UI/")
	var cfg: Dictionary = _load_tex_config()
	var entry: Dictionary = cfg.get(ui_key, {})
	if entry.is_empty():
		return 1.0
	if not bool(entry.get("Prescaled", false)):
		return 1.0
	var cs: int = int(entry.get("ContentScale", 0))
	return float(cs) if cs != 0 else 1.0


static func _base_size(res: String) -> Vector2:
	if not ResourceLoader.exists(res):
		return Vector2(45.0, 45.0)
	var t: Texture2D = load(res) as Texture2D
	return t.get_size() if t != null else Vector2(45.0, 45.0)


static func _load_tex_config() -> Dictionary:
	if _tex_config_cache.is_empty():
		var f := FileAccess.open(TEXTURE_CONFIG_JSON, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			_tex_config_cache = parsed if parsed is Dictionary else {}
	return _tex_config_cache
