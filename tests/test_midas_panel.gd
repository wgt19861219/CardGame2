extends GutTest
## MidasPanel 测试（P1-5：照源 midas.lua 18 节点装配 + 连兑确认弹窗 + 坐标转换 + 禁用态）。
## 避 tween/Logic 复杂（MidasManager Logic 在 test_midas_manager 覆盖），专注 View 装配。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 cocos(800×480,y向上) → Godot(960×640 offset 80,80)：_to_godot(cx+80, 560-cy)
func test_to_godot_coord_transform() -> void:
	assert_eq(MidasPanel._to_godot(Vector2(400.0, 305.0)), Vector2(480.0, 255.0), "frame cocos(400,305)→Godot(480,255)")
	# _center（中心 anchor 减 size/2）
	assert_eq(MidasPanel._center(Vector2(400.0, 305.0), Vector2(425.0, 245.0)), Vector2(267.5, 132.5), "center 左上")
	# _left_mid（左中 anchor）
	assert_eq(MidasPanel._left_mid(Vector2(155.0, 225.0), 24.0), Vector2(235.0, 323.0), "left_mid 左上")


func _make_panel() -> MidasPanel:
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	var panel := MidasPanel.new()
	add_child(panel)
	panel.setup_panel(pd)
	return panel


# setup 装配 frame/close/icon/name/desc/cost_board/use 等（源 create 18 节点核心）
func test_setup_assembles_nodes() -> void:
	var panel := _make_panel()
	assert_gt(panel.container.get_child_count(), 6, "装配 6+ 节点（frame/close/icon/name/desc/cost_board/use）")
	assert_ne(panel._use_btn, null, "use 按钮创建（源 :883）")
	assert_true(panel._use_btn is TextureButton, "use 是 TextureButton（源 Scale9Sprite 按钮）")
	panel.free()


# _make_button 返 TextureButton + shade(子0) + label(子1)（源 use/multi_use 结构）
func test_make_button_structure() -> void:
	var panel := _make_panel()
	var btn := panel._make_button("测试", Vector2(130.0, 50.0), MidasPanel.USE_RES, Color.WHITE)
	assert_eq(btn.get_child_count(), 2, "按钮含 shade + label 两子")
	assert_true(btn.get_child(0) is ColorRect, "子0 是 shade 蒙版（源 use_disabled）")
	assert_eq((btn.get_node("Label") as Label).text, "测试", "Label 文本正确")
	btn.free()
	panel.free()


# 连兑确认弹窗（源 createMultiWindow :556-665 popConfirmDialog）
func test_show_confirm_creates_layer() -> void:
	var panel := _make_panel()
	panel._show_confirm(2)
	assert_ne(panel._confirm_layer, null, "确认弹窗层创建（源 :659 popConfirmDialog）")
	assert_gt(panel._confirm_layer.get_child_count(), 4, "确认层含 shade+frame+msg+goldicon+amt+ok+cancel")
	# 确认/取消两按钮
	var btn_count: int = 0
	for c in panel._confirm_layer.get_children():
		if c is Button:
			btn_count += 1
	assert_eq(btn_count, 2, "确认层含 确认/取消 两按钮（源 rightHandler + left）")
	panel._close_confirm()
	assert_eq(panel._confirm_layer, null, "关闭后确认层移除")
	panel.free()


# 禁用态（源 setUseButtonEnabled :214-235）：shade 显 + label 灰
func test_set_use_enabled() -> void:
	var panel := _make_panel()
	panel._set_use_enabled(false)
	assert_true(panel._forbid_use, "forbid_use 置 true")
	assert_true(panel._use_shade.visible, "use shade 显（源 use_disabled）")
	assert_eq(panel._use_label.modulate, MidasPanel.DISABLED_COLOR, "use label 变灰（源 :230 dc）")
	panel._set_use_enabled(true)
	assert_false(panel._use_shade.visible, "enable 后 shade 隐")
	assert_eq(panel._use_label.modulate, MidasPanel.USE_LABEL_COLOR, "use label 恢复原色")
	panel.free()


# 2026-07-16 LSTR 化（源 midas.lua T(LSTR(...)) → cm.get_lstr）：_T 解析非空 + key 不回显
func test_lstr_resolved() -> void:
	var panel := _make_panel()
	var name_text: String = panel._T("MIDAS.GOLDEN_HAND")
	assert_ne(name_text, "", "MIDAS.GOLDEN_HAND LSTR 解析非空")
	assert_ne(name_text, "MIDAS.GOLDEN_HAND", "LSTR 解析为译文非 key 回显")
	var use_text: String = panel._T(MidasPanel.LSTR_USE)
	assert_ne(use_text, "", "MIDAS.USE LSTR 解析非空")
	panel.free()


# 源 :864-879 prompt（YOUVE_USED_UP，maxTimes 时显）；_apply_source_visibility 切 visible
func test_prompt_node_created() -> void:
	var panel := _make_panel()
	assert_ne(panel._prompt, null, "prompt 节点已建（源 :864-879）")
	# midas_times=0 < max_times → prompt 隐
	assert_false(panel._prompt.visible, "有次数时 prompt 隐（源 refreshCost :407）")
	panel.free()


# 源 refreshButton :418-421：times>=maxTimes → use 按钮文本切 MIDAS.VIEW_VIP（"查看VIP"）
func test_view_vip_when_maxed() -> void:
	var panel := _make_panel()
	panel._midas.midas_times = panel._get_max_times()   # 用尽次数
	panel._refresh_button()
	assert_eq(panel._use_label.text, panel._T("MIDAS.VIEW_VIP"), "用尽次数时按钮切 VIEW_VIP（源 :420）")
	panel._apply_source_visibility()
	assert_true(panel._prompt.visible, "用尽次数时 prompt 显（源 refreshCost :407）")
	panel.free()
