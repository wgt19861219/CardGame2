class_name StoryData
extends RefCounted

## 剧情分节数据（Data 层）— 源 gametable/storytableconfig.lua（1527 行，审查 P2-4 原判"源不可得"有误）。
## 单机化：剧情文本可选（不阻塞核心玩法），此处提供框架 + 占位。
## P2-4 核实：源 D:\workspace\projects\CardGameAxmol\Content\src\gametable\storytableconfig.lua 实际存在（926 条赋值），
## 含 Stage{N}Wave3 / WinBackToSelect{N} / OpeningMain 等约 40+ key，每条 Content 内含 monsterIndex/playIndex + position + LSTR text。
## 占位 3 条待用 lua_to_json 导入源数据替换（LSTR key → 中文映射），属纯翻译工作非设计。

# 占位数据框架（源 storytableconfig.lua key 结构：Content=[{monsterIndex/playIndex, position, text}] + ShowOnce）
# 以下 3 条为占位，待 lua_to_json 从源导入实际数据替换
const _STORIES: Dictionary = {
	# 占位：源 OpeningMain 待导入（源 storytableconfig.lua 无此 key，源 storylayer.lua:50 默认 nil 跳过）
	"Stage1Wave3": {"show_once": true, "content": [
		{"monsterIndex": 1, "position": "right", "text": "（占位待导入源 LSTR）"},
		{"playIndex": 3, "position": "left", "text": "（占位待导入源 LSTR）"},
	]},
	# 其他 key 待 lua_to_json 批量导入
}


static func get_story(story_name: String) -> Dictionary:
	return _STORIES.get(story_name, {})
