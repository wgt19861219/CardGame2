extends GutTest
# SaveManager 单测：原子存档往返 + 删除 + 缺失处理。

const TEST_DIR := "user://gut_test_saves/"

var _sm: SaveManager

func before_each() -> void:
	_sm = SaveManager.new(TEST_DIR)

func after_each() -> void:
	DirAccess.remove_absolute(TEST_DIR + "save_slot1.json")
	DirAccess.remove_absolute(TEST_DIR + "save_slot2.json")
	DirAccess.remove_absolute(TEST_DIR + "save_int.json")

func test_roundtrip_preserves_int() -> void:
	var data := {"hp": 100, "name": "Hero", "items": [1, 2, 3]}
	assert_eq(_sm.save_slot("slot1", data), OK, "保存应成功")
	var loaded := _sm.load_slot("slot1")
	assert_eq(loaded, data, "加载应与保存一致")

func test_int_not_corrupted_to_float() -> void:
	# 防旧版 JSON float→int 坑：整数往返必须仍是 int
	_sm.save_slot("int", {"count": 42})
	var loaded := _sm.load_slot("int")
	assert_eq(typeof(loaded["count"]), TYPE_INT, "整数往返后类型必须仍是 int")

func test_load_missing_returns_empty() -> void:
	assert_eq(_sm.load_slot("nonexistent"), {}, "不存在的槽位返回空字典")

func test_delete_removes_slot() -> void:
	_sm.save_slot("slot2", {"x": 1})
	assert_eq(_sm.delete_slot("slot2"), OK, "删除应成功")
	assert_eq(_sm.load_slot("slot2"), {}, "删除后加载为空")

func test_no_temp_residue() -> void:
	# 原子性旁证：保存成功后不应残留 .tmp 文件
	_sm.save_slot("slot1", {"a": 1})
	assert_false(
		FileAccess.file_exists(TEST_DIR + "save_slot1.json.tmp"),
		"成功保存后不应残留临时文件"
	)
