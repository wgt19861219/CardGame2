extends GutTest
# 修复轮 A（2026-08-18）：存档管理单机最小版测试（装配/载荷校验/文本往返）。
# 导入不真覆盖用户档——apply_imported_save 走 GameData 留给手动验收。
# 2026-09-05 根修：快照/文本用例全部走沙箱目录（SaveManagerSnapshots.base_dir 注入）——
# 原版直接写/删真实 user://save_index.json，每次跑门禁即清空用户快照列表。

const SANDBOX_DIR: String = "user://gut_test_saves/"

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SANDBOX_DIR))
	SaveManagerSnapshots.base_dir = SANDBOX_DIR


func after_all() -> void:
	# 清沙箱残留（用例中途 fail 遗漏自清理时兜底）+ 还原 base_dir。
	var dir := DirAccess.open(SANDBOX_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir():
				dir.remove(fname)
			fname = dir.get_next()
		dir.list_dir_end()
	SaveManagerSnapshots.base_dir = "user://"


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
	var err: int = SaveManagerPanel._write_text(SANDBOX_DIR + "sm_test_roundtrip.txt", "hello-sm")
	assert_eq(err, OK, "写文件 OK")
	assert_eq(SaveManagerPanel._read_text(SANDBOX_DIR + "sm_test_roundtrip.txt"), "hello-sm", "读回一致")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SANDBOX_DIR + "sm_test_roundtrip.txt"))


# ── 快照槽系统（2026-08-21 修复轮：源面板主体，此前裁剪致「没实现」体感）──

func _make_pd_for_snap() -> PlayerData:
	var pd := PlayerData.new(cm)
	return pd


func test_snapshot_index_roundtrip_and_roll() -> void:
	var index: Array = []
	for i in range(SaveManagerSnapshots.MAX_KEEP + 2):
		index.append({"time": 1000 + i, "type": "manual", "level": i, "team": []})
	SaveManagerSnapshots.write_index(index)
	var loaded: Array = SaveManagerSnapshots.read_index()
	assert_eq(loaded.size(), SaveManagerSnapshots.MAX_KEEP + 2, "index 往返保数量")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManagerSnapshots._index_path()))


func test_snapshot_save_snapshot_inserts_and_trims() -> void:
	var pd := _make_pd_for_snap()
	var idx: Array = []
	for i in range(SaveManagerSnapshots.MAX_KEEP):
		idx.append({"time": 9000 + i, "type": "manual", "level": 1, "team": []})
	SaveManagerSnapshots.write_index(idx)
	# 新快照前插 → 超限截断（最旧 9000 被删）。
	var new_idx: Array = SaveManagerSnapshots.save_snapshot(pd, '{"hero_manager": {"heroes": {}}}')
	assert_eq(new_idx.size(), SaveManagerSnapshots.MAX_KEEP, "截断到 MAX_KEEP")
	assert_gt(int(new_idx[0]["time"]), 9000 + SaveManagerSnapshots.MAX_KEEP - 1, "新快照在队首")
	# 恢复载荷可校验（快照文件已写）。
	var payload: Dictionary = SaveManagerSnapshots.snapshot_payload(new_idx[0])
	assert_false(payload.is_empty(), "快照文件载荷有效（含 hero_manager）")
	# 清理快照文件。
	for e in new_idx:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManagerSnapshots._snap_path(int(e["time"]))))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManagerSnapshots._index_path()))


func test_snapshot_panel_assembles_list() -> void:
	# 显式清沙箱 index（不依赖其他用例的清理顺序），保证空列表分支。
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManagerSnapshots._index_path()))
	var panel := _make_panel()
	# 无 index → 「暂无存档记录」占位（源 :581-586）。
	assert_not_null(panel._snap_host, "快照列表宿主已建")
	assert_eq(panel._snap_host.get_child_count(), 1, "空列表 → 占位文案 1 节点")


func test_set_avatar_marks_dirty() -> void:
	# 2026-08-21：换头像/改名落盘（save_hook 标脏），治「重启丢失」。
	var pd := _make_pd_for_snap()
	var called: Array[int] = [0]
	pd.save_hook = func() -> void: called[0] += 1
	pd.set_avatar(3)
	assert_eq(pd.avatar, 3, "avatar 已设")
	assert_eq(called[0], 1, "set_avatar 触发 save_hook")
	pd.set_player_name("新名字")
	assert_eq(pd.player_name, "新名字", "名字已设")
	assert_eq(called[0], 2, "set_player_name 触发 save_hook")


# 快照时间本地时区守卫（2026-08-21 实机抓出显示差 8h：UTC dict 未加 bias）。
func test_snapshot_header_uses_local_time() -> void:
	var now_unix: int = int(Time.get_unix_time_from_system())
	var row: Control = SaveManagerSnapshots.build_row(
		{"time": now_unix, "type": "manual", "level": 1, "team": []}, 1,
		[15, 26, 43, 20], cm, Callable())
	var header: Label = null
	for c in row.get_children():
		if c is Label and (c as Label).text.begins_with("#1"):
			header = c
			break
	if header == null:
		fail_test("header 标签未建")
		return
	var local_hour: int = Time.get_time_dict_from_system().get("hour", -1)
	assert_true(header.text.contains("%02d:" % local_hour), "header 小时=本地时区（含 %02d:）" % local_hour)
