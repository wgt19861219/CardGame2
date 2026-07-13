extends GutTest
# exercise_panel 试炼入口选择面板测试。

func test_panel_assembles() -> void:
	var panel := ExercisePanel.new()
	add_child(panel)
	assert_eq(panel.get_child_count(), 4, "应有 4 个子节点（bg/title/close/grid）")
	panel.queue_free()


func test_entry_keys_complete() -> void:
	# 7 个入口
	assert_eq(ExercisePanel.ENTRY_KEYS.size(), 7, "应有 7 个入口")
	var keys: Array = []
	for e in ExercisePanel.ENTRY_KEYS:
		keys.append(e.key)
	assert_true(keys.has("em"), "应有 em（英雄副本）")
	assert_true(keys.has("equip"), "应有 equip（装备副本）")
	assert_true(keys.has("str"), "应有 str（力量试炼）")
	assert_true(keys.has("agi"), "应有 agi（敏捷试炼）")
	assert_true(keys.has("int"), "应有 int（智力试炼）")
	assert_true(keys.has("exp"), "应有 exp（经验试炼）")
	assert_true(keys.has("money"), "应有 money（金币试炼）")


var _cb_key: String = ""
var _cb_groups: Array = []

func test_entry_callback() -> void:
	var panel := ExercisePanel.new()
	add_child(panel)
	_cb_key = ""; _cb_groups = []
	panel.set_entry_callback(_on_test_callback)
	panel._on_entry_pressed(ExercisePanel.ENTRY_KEYS[0])
	assert_eq(_cb_key, "em", "回调应收到 key=em")
	assert_eq(_cb_groups.size(), 3, "em 应有 3 个 group")
	panel.queue_free()

func _on_test_callback(key: String, groups: Array) -> void:
	_cb_key = key; _cb_groups = groups


func test_em_groups() -> void:
	var entry: Dictionary = ExercisePanel.ENTRY_KEYS[0]
	assert_eq(entry.groups, [50005, 50006, 50007], "em 应映射英雄副本 50005-7")


func test_equip_groups() -> void:
	var entry: Dictionary = ExercisePanel.ENTRY_KEYS[1]
	assert_eq(entry.groups, [50001, 50002, 50003, 50004], "equip 应映射装备副本 50001-4")


func test_resource_trial_groups() -> void:
	# str=20005, agi=20004, int=20003, exp=20001, money=20002
	var by_key: Dictionary = {}
	for e in ExercisePanel.ENTRY_KEYS:
		by_key[e.key] = e
	assert_eq(by_key.str.groups, [20005], "str→20005")
	assert_eq(by_key.agi.groups, [20004], "agi→20004")
	assert_eq(by_key.int.groups, [20003], "int→20003")
	assert_eq(by_key.exp.groups, [20001], "exp→20001")
	assert_eq(by_key.money.groups, [20002], "money→20002")
