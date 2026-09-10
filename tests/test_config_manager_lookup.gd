extends GutTest
# Phase 2.7 续：ConfigManager.lookup 验证（源 ed.lookupDataTable 等价，datatable.lua:163-177）。
# 数字 id 直接命中 + Name 字段查（源 dataTableMetaTables metatable __index 等价）+ column 取字段 + 缺失返空。


var _cm: ConfigManager = null


func before_all() -> void:
	_cm = ConfigManager.new()
	_cm.load_all()


# 数字 id 直接命中：Buff 表 id=1 返非空字典（JSON key=str(id)）。
func test_lookup_by_numeric_id() -> void:
	var row: Variant = _cm.lookup(&"Buff", "", 1)
	assert_true(row is Dictionary, "数字 id 返字典")
	assert_false((row as Dictionary).is_empty(), "Buff id=1 非空")


# Name 字段查（源 metatable __index 等价）：Buff 表 Name="burn"（JSON 数字 key，经 Name 遍历命中）。
func test_lookup_by_name() -> void:
	var row: Variant = _cm.lookup(&"Buff", "", "burn")
	assert_true(row is Dictionary, "name 查返字典")
	assert_eq(str((row as Dictionary).get("Name", "")), "burn", "Name=burn 命中")


# column 非空取字段值（源 lookupDataTable 的 column_name 参数）。
func test_lookup_column() -> void:
	var name_val: Variant = _cm.lookup(&"Buff", "Name", "burn")
	assert_eq(str(name_val), "burn", "column=Name 取字段")


# 查不到：column 空返空字典，非空返 null（源 lookupDataTable 查不到返 nil 等价）。
func test_lookup_missing() -> void:
	var row: Variant = _cm.lookup(&"Buff", "", "not_exist_buff")
	assert_true(row is Dictionary, "查不到返字典类型（空字典默认）")
	assert_true((row as Dictionary).is_empty(), "column 空查不到返空字典")
	var val: Variant = _cm.lookup(&"Buff", "Name", "not_exist_buff")
	assert_eq(val, null, "column 非空查不到返 null")


# 2026-09-10 根修守卫：lookup_str 三态（正常 String / 字段缺失 null / 行缺失 null → ""）。
# 源头：Unit.Narrative 9 真英雄无字段，String(lookup(...)) 裸写 String(null) 构造器崩。
func test_lookup_str_three_states() -> void:
	assert_eq(_cm.lookup_str(&"Unit", &"Display Name", 1), "Unit.hero.alias.001", "正常字段返 String 原值")
	assert_eq(_cm.lookup_str(&"Unit", &"Narrative", 45), "", "字段缺失（tid=45 无 Narrative）返空串不崩")
	assert_eq(_cm.lookup_str(&"Unit", &"NoSuchField", 1), "", "任意英雄无字段返空串")
	assert_eq(_cm.lookup_str(&"NoSuchTable", &"X", 1), "", "表缺失返空串")
