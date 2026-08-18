extends GutTest
# 修复轮 A（2026-08-18）：存档管理单机最小版测试（装配/载荷校验/文本往返）。
# 导入不真覆盖用户档——apply_imported_save 走 GameData 留给手动验收。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel() -> SaveManagerPanel:
	var panel := SaveManagerPanel.new("savemanager_test", {})
	panel.setup_panel()
	add_child_autofree(panel)
	return panel


func test_panel_assemble() -> void:
	var panel := _make_panel()
	assert_ne(panel.container, null, "container 创建（PopWindow 基类）")
	assert_gt(panel.container.get_child_count(), 2, "frame/title/按钮组装（>2 顶层内容节点）")


func test_validate_import_text_rejects_garbage() -> void:
	var d: Dictionary = SaveManagerPanel.validate_import_text("not-a-save|||")
	assert_true(d.is_empty(), "非法载荷被拒（str_to_var 失败 → 空字典）")


func test_validate_import_text_rejects_missing_hero_manager() -> void:
	var d: Dictionary = SaveManagerPanel.validate_import_text('{"foo": 1}')
	assert_true(d.is_empty(), "缺 hero_manager 键被拒（源 :207-214 完整性校验等价）")


func test_validate_import_text_accepts_save_shape() -> void:
	var d: Dictionary = SaveManagerPanel.validate_import_text('{"hero_manager": {"heroes": {}}, "v": 1}')
	assert_false(d.is_empty(), "合法载荷通过（含 hero_manager）")


func test_text_roundtrip() -> void:
	var err: int = SaveManagerPanel._write_text("user://sm_test_roundtrip.txt", "hello-sm")
	assert_eq(err, OK, "写文件 OK")
	assert_eq(SaveManagerPanel._read_text("user://sm_test_roundtrip.txt"), "hello-sm", "读回一致")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sm_test_roundtrip.txt"))
