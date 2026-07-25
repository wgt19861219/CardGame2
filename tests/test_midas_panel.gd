extends GutTest
## MidasPanel 测试（P1-5：照源 midas.lua 18 节点装配 + 连兑确认弹窗 + 坐标转换 + 禁用态）。
## 避 tween/Logic 复杂（MidasManager Logic 在 test_midas_manager 覆盖），专注 View 装配。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 cocos(800×480,y向上) → Godot(960×640 offset 80,80)：to_godot(cx+80, 560-cy)
# 渲染 helper 外迁后（2026-07-25 批次 1 第 3 拆分），坐标转换走 MidasRenderer
func test_to_godot_coord_transform() -> void:
	assert_eq(MidasRenderer.to_godot(Vector2(400.0, 305.0)), Vector2(480.0, 255.0), "frame cocos(400,305)→Godot(480,255)")
	# center（中心 anchor 减 size/2）
	assert_eq(MidasRenderer.center(Vector2(400.0, 305.0), Vector2(425.0, 245.0)), Vector2(267.5, 132.5), "center 左上")
	# left_mid（左中 anchor）
	assert_eq(MidasRenderer.left_mid(Vector2(155.0, 225.0), 24.0), Vector2(235.0, 323.0), "left_mid 左上")


func _make_panel() -> MidasPanel:
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	var panel := MidasPanel.new()
	add_child(panel)
	panel.setup_panel(pd)
	return panel


# 通用递归计数（按谓词，含类型判断）。.tscn instantiate 多一层 content（container→content→18 节点），
# container.get_child_count() 仅 1（content），需递归扫全子树数节点（参照 hero_detail 测试）。
func _count_if_recursive(node: Node, fn: Callable) -> int:
	var n: int = 1 if fn.call(node) else 0
	for c in node.get_children():
		n += _count_if_recursive(c, fn)
	return n


# setup 装配 frame/close/icon/name/desc/cost_board/use 等（源 create 18 节点核心）
func test_setup_assembles_nodes() -> void:
	var panel := _make_panel()
	var total: int = _count_if_recursive(panel.container, func(_n: Node) -> bool: return true)
	assert_gt(total, 6, "装配 6+ 节点（frame/close/icon/name/desc/cost_board/use，递归扫 content）")
	assert_ne(panel._use_btn, null, "use 按钮创建（源 :883）")
	assert_true(panel._use_btn is TextureButton, "use 是 TextureButton（源 Scale9Sprite 按钮）")
	panel.free()


# UseBtn 在 .tscn 静态化（TextureButton + Shade 子0 + Label 子1，照源 use_disabled+use_label 结构）。
# 原 procedural _make_button 工厂已删（.tscn 替代），改测 .tscn 静态按钮结构等价。
func test_button_structure() -> void:
	var panel := _make_panel()
	assert_eq(panel._use_btn.get_child_count(), 2, "UseBtn 含 shade + label 两子（源 use_disabled + use_label）")
	assert_true(panel._use_btn.get_child(0) is ColorRect, "子0 是 shade 蒙版（源 use_disabled）")
	assert_eq((panel._use_btn.get_node("Label") as Label).text, panel._T(MidasPanel.LSTR_USE), "UseBtn Label 文本=MIDAS.USE")
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


# ── C8（2026-07-23）：历史行多节点（源 initHistoryItemHandler :425-545 6 节点 + 可选 ratio 图）──

# 源每行 6 节点（USE label + cost + shop_token icon + GET label + goldicon + acquire）+ ratio 图。
# 修复前每行 1 Label（"USE cost GET acquire ×N"）；照源补 6 节点 HBoxContainer。
# 渲染外迁后（2026-07-25）改调 MidasRenderer.rebuild_history（lstr_resolver Callable 注入）
func test_history_row_has_six_nodes() -> void:
	var panel := _make_panel()
	panel._history = [{"cost": 10, "acquire": 5000, "ratio": 1}]   # ratio=1 无 ratio 图
	MidasRenderer.rebuild_history(panel._history_host, panel._history, func(k: String) -> String: return panel._T(k))
	# HBoxContainer + 6 子节点（USE label / cost label / token icon / GET label / gold icon / acquire label）
	var rows: Array = panel._history_host.get_children()
	assert_eq(rows.size(), 1, "1 行历史")
	var row: HBoxContainer = rows[0] as HBoxContainer
	assert_true(row is HBoxContainer, "行容器是 HBoxContainer（源 HorizontalNode）")
	# token/gold icon 资源存在 → 6 子节点；若资源缺则降级少 icon（项目两 icon 资源均就位 → 6）
	assert_gte(row.get_child_count(), 6, "行内至少 6 子节点（源 6 节点）")
	# 第 1 子是 Label 且 text 是 USE LSTR（源 :469 T(LSTR MIDAS.USE)）
	var first_child: Label = row.get_child(0) as Label
	assert_eq(first_child.text, panel._T(MidasPanel.LSTR_USE), "行首 Label = MIDAS.USE（源 :469）")
	panel.free()


# 源 :532-544 ratio>=2 行追加 ratio 图（ratio_res 缺 → Label 降级 ×N!）
func test_history_row_ratio_appends_label_when_image_missing() -> void:
	var panel := _make_panel()
	panel._history = [{"cost": 10, "acquire": 10000, "ratio": 4}]   # ratio=4 → midas_crip10.png 缺 → Label
	MidasRenderer.rebuild_history(panel._history_host, panel._history, func(k: String) -> String: return panel._T(k))
	var row: HBoxContainer = panel._history_host.get_child(0) as HBoxContainer
	# 源 6 节点 + ratio 降级 Label = 7 子节点（midas_crip10.png 缺）
	assert_gte(row.get_child_count(), 7, "ratio=4 追加 ratio 图/Label（源 :532-544）")
	# 末子是 ratio 降级 Label，text="×10!!"（RATIO_TEXT[4]，搬至 MidasRenderer）
	var last: Label = row.get_child(row.get_child_count() - 1) as Label
	assert_eq(last.text, String(MidasRenderer.RATIO_TEXT[4]), "ratio=4 降级 Label ×10!!（源 ratio_res 缺）")
	panel.free()


# 空历史 → 不建行（rebuild_history early return）
func test_history_empty_no_rows() -> void:
	var panel := _make_panel()
	panel._history = []
	MidasRenderer.rebuild_history(panel._history_host, panel._history, func(k: String) -> String: return panel._T(k))
	assert_eq(panel._history_host.get_child_count(), 0, "空历史 0 行")
	panel.free()


# 多行历史 → 每行 6+ 节点结构一致
func test_history_multiple_rows() -> void:
	var panel := _make_panel()
	panel._history = [
		{"cost": 10, "acquire": 5000, "ratio": 1},
		{"cost": 20, "acquire": 10000, "ratio": 2},
		{"cost": 30, "acquire": 30000, "ratio": 3},
	]
	MidasRenderer.rebuild_history(panel._history_host, panel._history, func(k: String) -> String: return panel._T(k))
	assert_eq(panel._history_host.get_child_count(), 3, "3 行历史")
	for i in range(3):
		var row: HBoxContainer = panel._history_host.get_child(i) as HBoxContainer
		assert_gte(row.get_child_count(), 6, "第 %d 行至少 6 子节点" % i)
	panel.free()
