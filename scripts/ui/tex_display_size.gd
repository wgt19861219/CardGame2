class_name TexDisplaySize
extends RefCounted

## sprite 显示尺寸工具（照源 resource_manager.lua:44-57 getSpriteOriginalScale +
## :58-76 createSprite 翻译）。
##
## 源 ed.createSprite(res) = CCSprite(contentSize=纹理/CS) + setScale(ContentScale)，
## 最终 Cocos 显示尺寸 = 纹理 × ContentScale。
## 本项目 Godot 直接显示纹理原像素，等价：Godot 显示像素 = 纹理像素 × ContentScale / CS。
##
## ContentScale 规则（源 getSpriteOriginalScale）：
##   TextureConfig 表无条目 → 1；Prescaled=false（Win32 平台）→ 1；ContentScale=0 → 1；否则返回 ContentScale。
## 修正影响：48 个 CS=2 + 4 个 CS=4 大图，此前各 builder 只算「纹理/CS」漏乘 ContentScale → 显示偏小。

# 源 hello.lua:311 setContentScaleFactor(615/480)=1.28125。
const CONTENT_SCALE: float = 1.28125
const TEXTURE_CONFIG_JSON: String = "res://resources/data/TextureConfig.json"   # 源 TextureConfig.lua 表

static var _tex_config_cache: Dictionary = {}


# sprite 显示尺寸 = 纹理原尺寸 × ContentScale / CS（源 createSprite 等价）。
static func display_size(res_path: String) -> Vector2:
	var base: Vector2 = _base_size(res_path)
	var cs: float = content_scale_of(res_path)
	return base * cs / CONTENT_SCALE


# 源 getSpriteOriginalScale：查 TextureConfig，无条目 / Prescaled=false / CS=0 → 1。
static func content_scale_of(res_path: String) -> float:
	# res://assets/ui/alpha/HVGA/x.png → UI/alpha/HVGA/x.png（TextureConfig key，源用大写 UI）
	# 本项目 assets 目录用小写 ui（windows 不分大小写），TextureConfig key 保留源大写。
	var ui_key: String = res_path.replace("res://assets/ui/", "UI/")
	var cfg: Dictionary = _load_tex_config()
	var entry: Dictionary = cfg.get(ui_key, {})
	if entry.is_empty():
		return 1.0   # 源 not config → 1
	if not bool(entry.get("Prescaled", false)):
		return 1.0   # 源 EDFLAGWIN32 and not Prescaled → 1
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
