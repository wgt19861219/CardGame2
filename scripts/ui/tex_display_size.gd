class_name TexDisplaySize
extends RefCounted

## sprite 显示尺寸工具（照源 resource_manager.lua:44-57 getSpriteOriginalScale +
## :58-76 createSprite 翻译）。
##
## 贴图显示尺寸（CLAUDE.md SOP 终局口径，2026-08-15 货币栏三轮实证）：
##   显示像素 = 纹理像素 ÷ CS(1.28125) × 条目 ContentScale（无条目=÷CS）。
## setContentScaleFactor（hello.lua:311）下 cocos Texture:getContentSize() 返回点尺寸
## （像素÷CS），createSprite 再乘条目 scale；viewport 迁移 800×480（=源设计空间）后
## Godot 场景单位即源点尺寸，÷CS 口径直接成立。
##
## ContentScale 规则（源 getSpriteOriginalScale :44-56）：
##   TextureConfig 无条目 → 1；Prescaled=false（Win32）→ 1；ContentScale=0 → 1；否则 ContentScale。
## 修正史：
##   2026-07-20：此前 base*cs/CONTENT_SCALE 多除 CS 致 sprite 偏小 1.28×
##   （stage_select frame 实测 76%×61%，源照源应 97%×79%）；当时 viewport 尚为
##   960×640，误判"960×640 直接等价源设计分辨率不除 CS"，改回 base×cs。
##   2026-08-21（Task 5 口径回归）：viewport 已迁 800×480（=源设计空间），上述
##   "不除 CS"前提作废，恢复 ÷CS 终局口径 base/CS×cs；原 base×cs 对无条目散图
##   偏大 1.28×（全局挂账债，本 commit 清偿）。

const TEXTURE_CONFIG_JSON: String = "res://resources/data/TextureConfig.json"
const CS: float = 1.28125   # hello.lua:311 setContentScaleFactor(615/480)

static var _tex_config_cache: Dictionary = {}


# sprite 显示尺寸 = 纹理原尺寸 ÷ CS × 条目 ContentScale（SOP 终局口径）。
static func display_size(res_path: String) -> Vector2:
	return _base_size(res_path) / CS * content_scale_of(res_path)


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
