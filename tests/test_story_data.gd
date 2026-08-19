extends GutTest
# StoryData 数据层测试（2026-08-19 源 storytableconfig.lua 全量导入守卫）。
# 表完整性（109 key/189 节/结构契约）+ get_story 翻译链（LSTR key→中文）+
# icon/name 组（_5v5* 教学剧情）与缺失 key 行为。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_story_table_full_structure() -> void:
	var table: Dictionary = cm.get_raw_table(&"StoryTable")
	assert_gt(table.size(), 100, "源 109 key（lua 重复 key 后者覆盖后唯一化）")
	var sections: int = 0
	var bad: Array = []
	for k in table:
		var row: Dictionary = table[k]
		var content: Array = row.get("content", [])
		if content.is_empty():
			bad.append(k + ":empty")
		for sec in content:
			sections += 1
			if not sec.has("text_key"):
				bad.append(k + ":no_text_key")
			if not ["left", "right"].has(String(sec.get("position", ""))):
				bad.append(k + ":bad_position")
	assert_eq(bad.size(), 0, "结构非法项（前 3）: " + str(bad.slice(0, 3)))
	assert_gt(sections, 180, "源 189 节")


func test_get_story_translates_lstr() -> void:
	var d: Dictionary = StoryData.get_story(cm, "Stage1Wave3")
	assert_false(d.is_empty(), "Stage1Wave3 存在")
	assert_true(bool(d.get("show_once", false)), "Stage1Wave3 ShowOnce=true")
	var content: Array = d.get("content", [])
	assert_eq(content.size(), 3, "Stage1Wave3 三节（怪/英雄/怪）")
	var first: Dictionary = content[0] if content.size() > 0 else {}
	assert_eq(int(first.get("monster_index", -1)), 1, "首节 monster_index=1")
	assert_ne(String(first.get("text", "")), "", "text 已翻译非空")
	assert_ne(String(first.get("text", "")), "STORYTABLECONFIG.YOU_SMALL_BUGS", "text 非 key 本身（LSTR 命中）")
	assert_eq(String(first.get("position", "")), "right", "首节 position=right")


func test_get_story_icon_name_group() -> void:
	var d: Dictionary = StoryData.get_story(cm, "_5v5Coco")
	assert_false(d.is_empty(), "_5v5Coco 存在（教学剧情组）")
	var first: Dictionary = d.get("content", [{}])[0]
	assert_true(first.has("icon"), "icon 字段保留（StoryView 立绘路径）")
	assert_true(first.has("name"), "name 经 name_key 翻译")


func test_get_story_missing_key_returns_empty() -> void:
	assert_true(StoryData.get_story(cm, "NoSuchStory").is_empty(), "缺失 key 返空（StoryView 直接 story_ended）")
	assert_true(StoryData.get_story(null, "Stage1Wave3").is_empty(), "cm null 返空防御")
