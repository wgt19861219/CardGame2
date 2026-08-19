class_name StoryData
extends RefCounted

## 剧情分节数据（Data 层）— 源 gametable/storytableconfig.lua 全量导入。
## 数据源 resources/data/StoryTable.json（tools/convert_storytable.py 生成，2026-08-19）：
## 109 key / 189 节（Stage{N}Wave{M} + WinBackToSelect{N} + OpeningMain + _5v5* 教学组），
## text/name 存 LSTR key 运行时按当前语言翻译（保多语言），icon 直存 UI 相对路径。
## 源数据缺口：STORYTABLECONFIG.FIRE（_5v5Coco）源 LSTR 表本缺，get_lstr 返回 key 本身兜底（与源一致）。


static func get_story(cm: Variant, story_name: String) -> Dictionary:
	if cm == null:
		return {}
	var row: Dictionary = cm.get_raw_table(&"StoryTable").get(story_name, {})
	if row.is_empty():
		return {}
	var content: Array = []
	for sec in row.get("content", []):
		var s: Dictionary = {
			"position": String(sec.get("position", "left")),
			"text": String(cm.get_lstr(String(sec.get("text_key", "")))),
		}
		if sec.has("monster_index"):
			s["monster_index"] = int(sec["monster_index"])
		if sec.has("play_index"):
			s["play_index"] = int(sec["play_index"])
		if sec.has("icon"):
			s["icon"] = String(sec["icon"])
		if sec.has("name_key"):
			s["name"] = String(cm.get_lstr(String(sec["name_key"])))
		content.append(s)
	return {"show_once": bool(row.get("show_once", false)), "content": content}
