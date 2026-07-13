class_name StageSelectMap
extends RefCounted

## 关卡选择地图布局数据（Logic 层）— 照源 stageselectres.lua map + stageselect.lua getStageRes。
## 读 stageselect_map.json（extract_stageselect_map.py 生成），提供章节 stage 坐标 + icon 决策。
## 坐标系：源 cocos(800×480 左下原点)，View 层用 to_godot(cx,cy)=(cx+80, 560-cy) 转换。

const MAP_JSON: String = "res://resources/data/stageselect_map.json"
const CHAPTER_MIN: int = 1
const CHAPTER_MAX: int = 14   # 源 stageselect.lua:13 CHAPTER_MAX=13（GameConfig.MaxChapter）；res 含 14 章
const RES_PREFIX_GODOT: String = "res://assets/ui/"   # 源 "UI/" → Godot "res://assets/ui/"
const SKELETON_RES_FMT: String = "res://assets/ui/alpha/HVGA/stagecircle_skeleton%d.png"   # 源 stageRes.locked（% tag）
const CIRCLE_CURRENT: String = "res://assets/ui/alpha/HVGA/stagecircle_current.png"        # 源 stageRes.current
const CIRCLE_ELITE: String = "res://assets/ui/alpha/HVGA/stagecircle_elite.png"            # 源 stageRes.passed/elite
const KEY_LOCKED_FMT: String = "res://assets/ui/alpha/HVGA/key_stages/stage-%d-locked.png"  # 源 keyStageRes.icon.locked
const KEY_PASSED_FMT: String = "res://assets/ui/alpha/HVGA/key_stages/stage-%d.png"         # 源 keyStageRes.icon.passed/current
const MASK_PASSED: String = "res://assets/ui/alpha/HVGA/key_stages/stage-passed.png"        # 源 keyStageRes.mask.passed
const MASK_CURRENT: String = "res://assets/ui/alpha/HVGA/key_stages/stage-current.png"      # 源 keyStageRes.mask.current

static var _cache: Dictionary = {}


static func load_map() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(MAP_JSON, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			_cache = parsed if parsed is Dictionary else {}
	return _cache


static func clear_cache() -> void:   # 测试隔离用
	_cache.clear()


static func get_chapter(chapter: int) -> Dictionary:
	return load_map().get("chapter" + str(chapter), {})


static func get_stages(chapter: int) -> Array:
	return get_chapter(chapter).get("stage", [])


static func get_tag(chapter: int) -> int:
	return int(get_chapter(chapter).get("tag", 1))


static func is_guild_instance_chapter(chapter: int) -> bool:
	return bool(get_chapter(chapter).get("guildInstance", false))


static func get_bg_res(chapter: int) -> String:
	return _to_godot_res(String(get_chapter(chapter).get("bg", {}).get("res", "")))


static func get_route_res(chapter: int) -> String:
	return _to_godot_res(String(get_chapter(chapter).get("route", {}).get("res", "")))


static func _to_godot_res(ui_path: String) -> String:
	if ui_path.is_empty():
		return ""
	# 源 "UI/alpha/HVGA/x.png" → "res://assets/ui/alpha/HVGA/x.png"
	return RES_PREFIX_GODOT + ui_path.substr("UI/".length())


# 源 stageselect.lua getStageRes(:992-1043) — stage icon 决策。
# cm: ConfigManager（查 Stage 表 Key Stage 字段）；star_of: Callable(int)->int（玩家该关星数）。
# 返回 {type, icon, mask}。type ∈ "locked"/"current"/"passed"；mask 可空（key_stage 闪烁遮罩）。
static func decide_stage_icon(stage_info: Dictionary, tag: int, mode: String, cm: Variant, star_of: Callable) -> Dictionary:
	var id: int = int(stage_info.get("id", 0))
	var eid: int = int(stage_info.get("eid", 0))
	var resid: int = int(stage_info.get("resid", id))
	var stage_table: Dictionary = cm.get_raw_table(&"Stage")
	# stage_info.is_key override（测试可控），否则查 Stage 表 Key Stage 字段（源 stageInfo[id]["Key Stage"]）
	var is_key: bool = bool(stage_info.get("is_key", stage_table.get(str(id), {}).get("Key Stage", false)))
	if mode == "elite":
		if is_key:
			if id > 1 and _star(star_of, eid) <= 0 and _star(star_of, eid - 1) <= 0:
				return _res("locked", KEY_LOCKED_FMT % resid)
			elif _star(star_of, eid) <= 0:
				return _res_mask("current", KEY_PASSED_FMT % resid, MASK_CURRENT)
			return _res_mask("passed", KEY_PASSED_FMT % resid, MASK_PASSED)
		return _res("locked", CIRCLE_ELITE)   # 源 :1011 elite 非 key 一律 locked
	elif mode == "normal":
		if is_key:
			if id > 1 and _star(star_of, id) <= 0 and _star(star_of, id - 1) <= 0:
				return _res("locked", KEY_LOCKED_FMT % resid)
			elif _star(star_of, id) <= 0:
				return _res_mask("current", KEY_PASSED_FMT % resid, MASK_CURRENT)
			return _res_mask("passed", KEY_PASSED_FMT % resid, MASK_PASSED)
		elif id > 1 and _star(star_of, id) <= 0 and _star(star_of, id - 1) <= 0:
			return _res("locked", SKELETON_RES_FMT % tag)
		elif _star(star_of, id) <= 0:
			return _res("current", CIRCLE_CURRENT)
		return _res("passed", CIRCLE_ELITE)
	else:   # guild（源 :1029-1041 走 guild.getInstanceInfo；单机化无公会，key 当可挑战、非 key locked）
		if is_key:
			return _res("passed", KEY_PASSED_FMT % resid)
		return _res("locked", CIRCLE_ELITE)


static func _star(star_of: Callable, sid: int) -> int:
	if sid <= 0:
		return 0
	return int(star_of.call(sid))


static func _res(t: String, icon: String) -> Dictionary:
	return {"type": t, "icon": icon, "mask": ""}


static func _res_mask(t: String, icon: String, mask: String) -> Dictionary:
	return {"type": t, "icon": icon, "mask": mask}
