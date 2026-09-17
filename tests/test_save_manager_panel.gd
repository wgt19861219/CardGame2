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


# ── 多档位轮（2026-09-17）：档位条构建/回调分流/确认流程守卫 ──

func _chip_labels(chip: Button) -> Array:
	var labels: Array = []
	for c in chip.get_children():
		if c is Label:
			labels.append(c)
	return labels

func test_slot_display_names() -> void:
	assert_eq(SaveManagerSlotBar.slot_display("auto"), "档1", "auto→档1")
	assert_eq(SaveManagerSlotBar.slot_display("save_1"), "档2", "save_1→档2")
	assert_eq(SaveManagerSlotBar.slot_display("save_2"), "档3", "save_2→档3")
	assert_eq(SaveManagerSlotBar.slot_display("weird"), "weird", "未知槽名原样返回（守卫）")

func test_slot_bar_builds_chips_and_routes_clicks() -> void:
	var picked: Array = []
	var bar: Control = SaveManagerSlotBar.build([
		{"slot": "auto", "exists": true, "level": 35, "active": true},
		{"slot": "save_1", "exists": true, "level": 12, "active": false},
		{"slot": "save_2", "exists": false, "level": 1, "active": false},
	], func(slot: String, exists: bool) -> void: picked.append([slot, exists]))
	assert_eq(bar.get_child_count(), 3, "三档胶囊")
	var chip_active := bar.get_child(0) as Button
	var chip_other := bar.get_child(1) as Button
	var chip_empty := bar.get_child(2) as Button
	assert_eq(_chip_labels(chip_active).size(), 2, "胶囊两行标签（档名+副行）")
	# 文案：有档副行 Lv.N；空档副行「新建」。
	var active_labels: Array = _chip_labels(chip_active)
	var empty_labels: Array = _chip_labels(chip_empty)
	var active_sub := active_labels[1] as Label
	var empty_sub := empty_labels[1] as Label
	assert_eq(active_sub.text, "Lv.35", "当前档副行显等级")
	assert_eq(empty_sub.text, "新建", "空档副行显「新建」")
	# 当前档金色高亮；空档非金色。
	var active_name := active_labels[0] as Label
	var empty_name := empty_labels[0] as Label
	assert_eq(active_name.get_theme_color("font_color"), SaveManagerSlotBar.ACTIVE_COLOR, "当前档金色")
	assert_ne(empty_name.get_theme_color("font_color"), SaveManagerSlotBar.ACTIVE_COLOR, "空档非金色")
	# 点击分流：当前档不触发；有档触发 (slot,true)；空档触发 (slot,false)。
	chip_active.pressed.emit()
	chip_other.pressed.emit()
	chip_empty.pressed.emit()
	assert_eq(picked.size(), 2, "当前档点击无操作，其余两档触发回调")
	if picked.size() == 2:
		assert_eq(picked[0], ["save_1", true], "有档点击回调 (slot,true)")
		assert_eq(picked[1], ["save_2", false], "空档点击回调 (slot,false)→新建入口")

func test_panel_slot_pick_opens_confirm_and_cancels() -> void:
	var panel := _make_panel()
	# 空档 → 新建确认（文案带档位显示名 + kind=new）。
	panel._on_slot_picked("save_1", false)
	assert_true(panel._confirm_layer.visible, "空档点击弹确认层")
	assert_eq(panel._pending_slot_action, {"kind": "new", "slot": "save_1"}, "待确认动作=新建")
	assert_true(panel._confirm_msg_label.text.contains("档2"), "确认文案含档位显示名")
	assert_true(panel._confirm_msg_label.text.contains("新建"), "确认文案含新建语义")
	# 取消 → 层收起 + pending 清空。
	panel._on_confirm_cancel()
	assert_false(panel._confirm_layer.visible, "取消后确认层收起")
	assert_eq(panel._pending_slot_action, {}, "取消后 pending 清空")
	# 有档 → 切换确认（kind=switch）。
	panel._on_slot_picked("save_2", true)
	assert_eq(panel._pending_slot_action, {"kind": "switch", "slot": "save_2"}, "待确认动作=切换")
	assert_true(panel._confirm_msg_label.text.contains("切换"), "确认文案含切换语义")
	panel._on_confirm_cancel()
	# 当前档防御分支：无动作。
	panel._pending_slot_action = {"kind": "switch", "slot": GameData.active_slot}
	panel._on_slot_picked(GameData.active_slot, true)
	assert_eq(panel._pending_slot_action, {"kind": "switch", "slot": GameData.active_slot}, "当前档点击不改写 pending（防御分支）")

func test_panel_slot_bar_attached() -> void:
	var panel := _make_panel()
	assert_not_null(panel._slot_bar_host, "档位条宿主已建")
	assert_gt(panel._slot_bar_host.get_child_count(), 0, "档位条含胶囊（测试模式合成三档）")


# ── 确认接线单射守卫（2026-09-17 错误码31 根修）──
# 根因：旧接线 _confirm.open(_on_confirm_ok) 登记的是确定按钮 handler 自身——点确定
# → handler 里 _confirm.confirm() 的状态机回调又进 handler（重入）→ _apply_* 双跑，
# 第二次空 slot switch_slot 返 ERR_INVALID_PARAMETER(31)；既有导入链第二次 apply
# 空字典同病。修=登记动作回调 _on_confirmed（唯一执行点）。
func test_confirm_wiring_single_shot() -> void:
	var panel := _make_panel()
	panel._on_slot_picked("save_1", false)
	assert_true(panel._confirm._on_confirm == panel._on_confirmed,
		"状态机登记回调=动作函数 _on_confirmed（登记按钮 handler 自身即重入双执行根因）")
	assert_true(panel._confirm.is_open(), "待确认状态 OPEN")
	panel._on_confirm_cancel()
	assert_false(panel._confirm.is_open(), "取消后状态机 CLOSED")

func test_confirmed_empty_pending_defensive_close() -> void:
	var panel := _make_panel()
	panel._confirm_layer.visible = true
	panel._on_confirmed()   # 双 pending 皆空 → 防御分支仅收层
	assert_false(panel._confirm_layer.visible, "空 pending 防御收层（不执行任何动作）")
