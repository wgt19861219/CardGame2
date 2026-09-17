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
	DirAccess.remove_absolute(TEST_DIR + "save_corrupt.json")
	for f in DirAccess.get_files_at(TEST_DIR):
		if String(f).begins_with("save_corrupt.json.corrupt_"):
			DirAccess.remove_absolute(TEST_DIR + f)

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


# 2026-09-07 用户档毁灭事故根修守卫：解析失败（str_to_var 非 Dictionary）必须先把原档
# 备份成 .corrupt_<epoch> 再返回空——原版静默返空 → GameData 新号 → 登录首存原地覆盖，
# 坏档零残留不可抢救（读侧兜底与写侧原子写不对称）。
func test_corrupt_parse_backs_up_then_returns_empty() -> void:
	var path := TEST_DIR + "save_corrupt.json"
	var tf := FileAccess.open(path, FileAccess.WRITE)
	tf.store_string("this is { not a valid variant dict |||")
	tf.close()
	var loaded := _sm.load_slot("corrupt")
	assert_push_error("解析失败", "坏档解析失败应 push_error 显式告警（治静默覆盖）")
	assert_eq(loaded, {}, "坏档解析失败返回空字典（走新号）")
	var backups: Array = []
	for f in DirAccess.get_files_at(TEST_DIR):
		if String(f).begins_with("save_corrupt.json.corrupt_"):
			backups.append(String(f))
	assert_eq(backups.size(), 1, "原坏档应被改名备份为 .corrupt_<epoch>（不原地消灭）")
	if backups.size() == 1:
		var bf := FileAccess.open(TEST_DIR + String(backups[0]), FileAccess.READ)
		assert_eq(bf.get_as_text(), "this is { not a valid variant dict |||", "备份内容与原坏档一致")
		bf.close()
	assert_false(FileAccess.file_exists(path), "原路径坏档应已改名让位（新号首存不覆盖坏档内容）")


# ── 多档位（2026-09-17）：list_slots 只认 SLOT_NAMES 槽且按其顺序输出 ──
func _write_raw(name: String, content: String) -> void:
	var f := FileAccess.open(TEST_DIR + name, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()

func test_list_slots_filters_and_orders() -> void:
	_sm.save_slot("save_1", {"b": 2})
	_sm.save_slot("auto", {"a": 1})
	_sm.save_slot("slot9", {"c": 3})   # 非 SLOT_NAMES 历史槽名，应被过滤
	_write_raw("save_index.json", "[]")   # 快照 index 同前缀杂项，应被过滤
	_write_raw("save_snap_123.json", "{}")   # 快照文件，应被过滤
	_write_raw("save_auto.json.tmp", "")   # 原子写临时文件，应被过滤
	_write_raw("save_auto.json.bak_pre_import", "")   # 导入备份，应被过滤
	assert_eq(_sm.list_slots(), ["auto", "save_1"] as Array[String], "只列 SLOT_NAMES 槽且顺序稳定")
	for f in ["save_save_1.json", "save_auto.json", "save_slot9.json", "save_index.json",
			"save_snap_123.json", "save_auto.json.tmp", "save_auto.json.bak_pre_import"]:
		DirAccess.remove_absolute(TEST_DIR + f)
