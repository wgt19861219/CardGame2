extends GutTest
## MidasPanel 测试（批 2 Task 6 两件套改造 2026-08-16）。
## 照源 midas.lua：主面板静态树 rect（readnode 第二段挂 ui.content，content 原点
## cocos(187.5,172.5)=godot(267.5,387.5)，子坐标=content 局部空间 + 原点换算）+
## 连兑确认弹窗（独立 PopWindow）+ 按钮禁用态 + .new( 白名单。
## 避 tween/Logic 复杂（MidasManager Logic 在 test_midas_manager 覆盖），专注 View 装配。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel() -> MidasPanel:
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	var panel := MidasPanel.new()
	add_child(panel)
	panel.setup_panel(pd)
	return panel


# 通用递归计数（按谓词，含类型判断）。.tscn instantiate 多一层 content，需递归扫全子树。
func _count_if_recursive(node: Node, fn: Callable) -> int:
	var n: int = 1 if fn.call(node) else 0
	for c in node.get_children():
		n += _count_if_recursive(c, fn)
	return n


# ── 静态树 rect 断言（源坐标直译：content 局部 + 原点 cocos(187.5,172.5)）──

# 主面板静态 rect（tscn instantiate 后直接读，不依赖 panel fill）。
# 源 create :773-1012：frame(400,305)425x245 / close DGccp(524,305) content 局部 →
# 场景(596.9,410.8)→godot 中心(676.9,149.2)，65x66px/CS=50.73x51.51。
func test_content_static_rects() -> void:
	var inst: Control = load("res://scenes/ui/midas_content.tscn").instantiate() as Control
	add_child(inst)
	var frame: NinePatchRect = inst.get_node("%Frame") as NinePatchRect
	assert_almost_eq(frame.position.x, 267.5, 0.5, "Frame 左 = to_godot(400)-425/2")
	assert_almost_eq(frame.position.y, 132.5, 0.5, "Frame 顶 = 560-305-245/2")
	assert_almost_eq(frame.size.x, 425.0, 0.5, "Frame 宽 = 源 scaleSize 425")
	assert_almost_eq(frame.size.y, 245.0, 0.5, "Frame 高 = 源 scaleSize 245")
	# capInsets CCRectMake(10,10,58,26) 纹理 103x61 → left=10 right=103-10-58=35
	# top=61-10-26=25 bottom=10（批 1 公式，修正旧 tscn 10/10/10/10）
	assert_almost_eq(float(frame.patch_margin_left), 10.0, 0.5, "Frame patch_left=10")
	assert_almost_eq(float(frame.patch_margin_right), 35.0, 0.5, "Frame patch_right=35")
	assert_almost_eq(float(frame.patch_margin_top), 25.0, 0.5, "Frame patch_top=25")
	assert_almost_eq(float(frame.patch_margin_bottom), 10.0, 0.5, "Frame patch_bottom=10")
	var close_btn: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(close_btn.position.x + close_btn.size.x * 0.5, 676.9, 0.5,
		"CloseBtn 中心 x = 80+524*0.78125+187.5")
	assert_almost_eq(close_btn.position.y + close_btn.size.y * 0.5, 149.2, 0.5,
		"CloseBtn 中心 y = 560-(305*0.78125+172.5)（贴 frame 右上角）")
	assert_almost_eq(close_btn.size.x, 50.73, 0.5, "CloseBtn 宽 = 65px/CS")
	assert_almost_eq(close_btn.size.y, 51.51, 0.5, "CloseBtn 高 = 66px/CS")
	assert_eq(close_btn.stretch_mode, TextureButton.STRETCH_SCALE, "CloseBtn stretch=SCALE（默认 KEEP 溢出）")
	var icon_frame: TextureRect = inst.get_node("%IconFrame") as TextureRect
	assert_almost_eq(icon_frame.position.x + icon_frame.size.x * 0.5, 367.5, 0.5,
		"IconFrame 中心 x = 80+100+187.5")
	assert_almost_eq(icon_frame.position.y + icon_frame.size.y * 0.5, 182.5, 0.5,
		"IconFrame 中心 y = 560-(205+172.5)")
	assert_almost_eq(icon_frame.size.x, 73.37, 0.5, "IconFrame 宽 = 94px/CS（等比不强拉）")
	assert_almost_eq(icon_frame.size.y, 74.15, 0.5, "IconFrame 高 = 95px/CS")
	var name_lbl: Label = inst.get_node("%NameLabel") as Label
	assert_almost_eq(name_lbl.position.x, 422.5, 0.5, "NameLabel 左 = 80+155+187.5（源 anchor(0,0.5)）")
	assert_almost_eq(name_lbl.position.y + name_lbl.size.y * 0.5, 162.5, 0.5,
		"NameLabel 垂直中心 = 560-(225+172.5)")
	var desc_lbl: Label = inst.get_node("%DescLabel") as Label
	assert_almost_eq(desc_lbl.position.x + desc_lbl.size.x * 0.5, 530.0, 1.0, "DescLabel 水平居中区域")
	assert_almost_eq(desc_lbl.position.y + desc_lbl.size.y * 0.5, 202.5, 0.5,
		"DescLabel 垂直中心 = 560-(185+172.5)")
	inst.free()


# 按钮与历史区 rect：use/multi @ content 局部 (130,50)/(300,50) → godot 中心
# (397.5,337.5)/(567.5,337.5)；history_frame @ (400,115) 场景中心 godot (480,445)。
func test_buttons_and_history_rects() -> void:
	var inst: Control = load("res://scenes/ui/midas_content.tscn").instantiate() as Control
	add_child(inst)
	var use_btn: Button = inst.get_node("%UseBtn") as Button
	assert_almost_eq(use_btn.position.x + use_btn.size.x * 0.5, 397.5, 0.5,
		"UseBtn 中心 x = 80+130+187.5（源 refreshMultiUseButton 解锁位）")
	assert_almost_eq(use_btn.position.y + use_btn.size.y * 0.5, 337.5, 0.5, "UseBtn 中心 y")
	assert_almost_eq(use_btn.size.x, 150.0, 0.5, "UseBtn 宽 = 源 scaleSize 150")
	assert_almost_eq(use_btn.size.y, 45.0, 0.5, "UseBtn 高 = 源 scaleSize 45")
	var multi_btn: Button = inst.get_node("%MultiBtn") as Button
	assert_almost_eq(multi_btn.position.x + multi_btn.size.x * 0.5, 567.5, 0.5, "MultiBtn 中心 x = 80+300+187.5")
	assert_almost_eq(multi_btn.position.y + multi_btn.size.y * 0.5, 337.5, 0.5, "MultiBtn 中心 y")
	var hist_frame: NinePatchRect = inst.get_node("%HistoryFrame") as NinePatchRect
	assert_almost_eq(hist_frame.position.x + hist_frame.size.x * 0.5, 480.0, 0.5,
		"HistoryFrame 中心 x = 80+400（源场景空间）")
	assert_almost_eq(hist_frame.position.y + hist_frame.size.y * 0.5, 445.0, 0.5,
		"HistoryFrame 中心 y = 560-115")
	assert_almost_eq(hist_frame.size.x, 425.0, 0.5, "HistoryFrame 宽 = scaleSize 425")
	assert_almost_eq(hist_frame.size.y, 125.0, 0.5, "HistoryFrame 高 = scaleSize 125")
	assert_false(hist_frame.visible, "HistoryFrame 初始隐藏（源首次兑换才 createHistory）")
	# 裁剪层 = 源 cliprect DGRectMake(35,10,480,145)→(27.3,7.8,375,113.3) history_frame 局部
	var scroll: ScrollContainer = inst.get_node("%HistoryScroll") as ScrollContainer
	assert_almost_eq(scroll.position.x - hist_frame.position.x, 27.3, 0.5, "Scroll 相对 frame 左 = DG(35)")
	assert_almost_eq(hist_frame.position.y + hist_frame.size.y - (scroll.position.y + scroll.size.y), 7.8, 0.5,
		"Scroll 距 frame 底 = DG(10)")
	assert_almost_eq(scroll.size.x, 375.0, 0.5, "Scroll 宽 = DG(480)")
	assert_almost_eq(scroll.size.y, 113.3, 0.5, "Scroll 高 = DG(145)")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "横向禁滚（源 direction=v）")
	inst.free()


# setup 装配 frame/close/icon/name/desc/cost_board/use 等（源 create 18 节点核心）
func test_setup_assembles_nodes() -> void:
	var panel := _make_panel()
	var total: int = _count_if_recursive(panel.container, func(_n: Node) -> bool: return true)
	assert_gt(total, 10, "装配 10+ 节点（frame/close/icon/name/desc/times/cost/use/multi/history，递归扫 content）")
	assert_ne(panel._use_btn, null, "use 按钮装配")
	assert_true(panel._use_btn is Button, "use 是 Button（variation 三态，源 Scale9 按钮）")
	panel.free()


# UseBtn 结构（照源 use + use_disabled 图蒙版 + use_label）：Button 化后
# 子 UseDisabled TextureRect（tavern_button_normal_1 替代旧迁移发明 Shade ColorRect）
# + Label（variation MidasUseBtnLabel）。
func test_button_structure() -> void:
	var panel := _make_panel()
	assert_eq(panel._use_btn.get_child_count(), 2, "UseBtn 含 disabled 蒙版 + label 两子（源 :888-935）")
	assert_true(panel._use_btn.get_child(0) is TextureRect, "子0 是 UseDisabled 蒙版（源 use_disabled 图）")
	assert_eq((panel._use_btn.get_node("Label") as Label).text, panel._T(MidasPanel.LSTR_USE), "UseBtn Label 文本=MIDAS.USE")
	assert_true(String(panel._use_btn.theme_type_variation) == "MidasUseBtn", "UseBtn variation=MidasUseBtn")
	assert_false((panel._use_btn.get_child(0) as TextureRect).visible, "UseDisabled 初始隐藏")
	panel.free()


# .new( 宽口径白名单：飘字 Label（transient 动画）+ 确认弹窗 MidasConfirm 构造 +
# 解锁查询 FeatureLimit 构造（批 1 Task 9 教训：带参构造也计入 .new( 宽口径）。
func test_panel_new_whitelist() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	var allowed: int = script_text.count("Label.new(") \
		+ script_text.count("MidasConfirm.new(") + script_text.count("FeatureLimit.new(")
	assert_eq(script_text.count(".new("), allowed, "panel .new( 全在白名单（无静态 UI 构造）")
	assert_eq(script_text.count("Label.new("), 1, "飘字工厂唯一 Label.new")
	assert_eq(script_text.count("MidasConfirm.new("), 1, "确认弹窗唯一构造")
	assert_eq(script_text.count("FeatureLimit.new("), 1, "解锁查询唯一构造")


# 按钮位置 fill（源 refreshMultiUseButton :1025-1034）：解锁 use (130,50) + multi_use 显，
# 锁定 use (210,50) + multi_use 隐（真值判断照源 getAreaUnlockvip）。
func test_use_button_position_fill() -> void:
	var panel := _make_panel()
	# 源 VIP0 不含 Multiple Midas（VIP.json false）→ 锁定位 (210,50)
	assert_almost_eq(panel._use_btn.position.x, 402.5, 0.5, "锁定位 use pos.x = 477.5-150/2（源 :1031）")
	assert_false(panel._multi_btn.visible, "锁定 multi_use 隐（源 :1032）")
	panel._multi_unlocked = true
	panel._fill_buttons()
	assert_almost_eq(panel._use_btn.position.x, 322.5, 0.5, "解锁位 use pos.x = 397.5-150/2（源 :1030，VIP2+）")
	panel.free()


# 今日可用次数 TimesBoard（源 refreshTimesBoard :342-396 独立 HorizontalNode，
# 修正旧实现并入 desc 的偏差）：4 label（文案/剩余红/总数/")"）。
func test_times_board_structure() -> void:
	var panel := _make_panel()
	var times_board: HBoxContainer = panel._content.get_node("%TimesBoard") as HBoxContainer
	assert_eq(times_board.get_child_count(), 4, "TimesBoard 4 label（源 :355-393）")
	var left: Label = times_board.get_node("TimesLeftLabel") as Label
	var max_lbl: Label = times_board.get_node("TimesMaxLabel") as Label
	assert_eq(left.text, str(panel._get_max_times()), "剩余次数 fill = max-times")
	assert_eq(max_lbl.text, "/" + str(panel._get_max_times()), "总数 label = /max（源 :379）")
	var desc: Label = panel._content.get_node("%DescLabel") as Label
	assert_false(desc.text.contains("/"), "desc 不再拼接次数行（照源拆分，desc 单行说明）")
	panel.free()


# 禁用态（源 setUseButtonEnabled :214-235）：UseDisabled 显 + label 灰。
func test_set_use_enabled() -> void:
	var panel := _make_panel()
	panel._set_use_enabled(false)
	assert_true(panel._forbid_use, "forbid_use 置 true")
	var disabled_tex: TextureRect = panel._use_btn.get_child(0) as TextureRect
	assert_true(disabled_tex.visible, "use disabled 蒙版显（源 use_disabled）")
	assert_eq(panel._use_label.modulate, MidasPanel.DISABLED_COLOR, "use label 变灰（源 :230 dc）")
	panel._set_use_enabled(true)
	assert_false(disabled_tex.visible, "enable 后蒙版隐")
	assert_eq(panel._use_label.modulate, MidasPanel.USE_LABEL_COLOR, "use label 恢复原色")
	panel.free()


# 2026-07-16 LSTR 化：_T 解析非空 + key 不回显。
func test_lstr_resolved() -> void:
	var panel := _make_panel()
	var name_text: String = panel._T("MIDAS.GOLDEN_HAND")
	assert_ne(name_text, "", "MIDAS.GOLDEN_HAND LSTR 解析非空")
	assert_ne(name_text, "MIDAS.GOLDEN_HAND", "LSTR 解析为译文非 key 回显")
	var use_text: String = panel._T(MidasPanel.LSTR_USE)
	assert_ne(use_text, "", "MIDAS.USE LSTR 解析非空")
	panel.free()


# 源 :864-879 prompt（maxTimes 时显）；_apply_source_visibility 切 visible。
func test_prompt_node_created() -> void:
	var panel := _make_panel()
	assert_ne(panel._prompt, null, "prompt 节点已建（源 :864-879）")
	assert_false(panel._prompt.visible, "有次数时 prompt 隐（源 refreshCost :407）")
	panel.free()


# 源 refreshButton :418-421：times>=maxTimes → use 按钮文本切 MIDAS.VIEW_VIP。
func test_view_vip_when_maxed() -> void:
	var panel := _make_panel()
	panel._midas.midas_times = panel._get_max_times()   # 用尽次数
	panel._refresh_button()
	assert_eq(panel._use_label.text, panel._T("MIDAS.VIEW_VIP"), "用尽次数时按钮切 VIEW_VIP（源 :420）")
	panel._apply_source_visibility()
	assert_true(panel._prompt.visible, "用尽次数时 prompt 显（源 refreshCost :407）")
	panel.free()


# 连兑确认弹窗（源 createMultiWindow :550-666 → 独立 PopWindow confirmdialog 声明表直译）。
func test_show_confirm_creates_window() -> void:
	var panel := _make_panel()
	panel._show_confirm(2)
	assert_ne(panel._confirm_window, null, "确认弹窗创建（源 ed.popConfirmDialog :659）")
	var confirm: MidasConfirm = panel._confirm_window
	assert_eq((confirm._frame.get_node("%OkBtn") as Button).text, panel._T("CHATCONFIG.CONFIRM"), "确认按钮文本 fill")
	assert_eq((confirm._frame.get_node("%CancelBtn") as Button).text, panel._T("CHATCONFIG.CANCEL"), "取消按钮文本 fill")
	var count_lbl: Label = confirm._frame.get_node("%Rows/RowTimes/TimesCountLabel") as Label
	assert_eq(count_lbl.text, "2", "连兑次数 fill（源 midas.1.10.1.002 行）")
	panel._close_confirm()
	assert_eq(panel._confirm_window, null, "关闭后弹窗移除")
	panel.free()


# global_position 级防 parenting 回归（IconFrame/UseBtn 必须挂 content 直下而非 Frame 子层，
# 否则 position 相同但 global 偏移 Frame 原点）。
func test_global_position_parenting_guard() -> void:
	var panel := _make_panel()
	await get_tree().process_frame
	var icon_frame: TextureRect = panel._content.get_node("%IconFrame") as TextureRect
	assert_almost_eq(icon_frame.global_position.x, 330.8, 1.0, "IconFrame global x ≈ 静态 offset（挂 content 直下）")
	assert_almost_eq(icon_frame.global_position.y, 145.4, 1.0, "IconFrame global y ≈ 静态 offset")
	var use_btn: Button = panel._content.get_node("%UseBtn") as Button
	assert_almost_eq(use_btn.global_position.y, 315.0, 1.0, "UseBtn global y ≈ 315（content 局部=场景坐标）")
	panel.free()


# 历史区 visible 切换（源 createHistory 首次兑换才建 frame；静态化后 visible 切）。
func test_history_frame_visible_toggle() -> void:
	var panel := _make_panel()
	var hist_frame: CanvasItem = panel._content.get_node("%HistoryFrame") as CanvasItem
	assert_false(hist_frame.visible, "无历史时 HistoryFrame 隐")
	panel._history = [{"cost": 10, "acquire": 5000, "ratio": 1}]
	panel._refresh_view()
	assert_true(hist_frame.visible, "有历史时 HistoryFrame 显")
	assert_eq((panel._content.get_node("%HistoryScroll/HistoryRows") as VBoxContainer).get_child_count(), 1,
		"历史行经 fills 挂 VBox")
	panel.free()
