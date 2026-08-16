extends GutTest
# StageResetConfirm 守卫测试（批 3 Task 1 两件套核对级，2026-08-16）。
# 照源 stagedetail.lua:514-535 doPayReset → dialog.lua confirmDialog
# （showConfirmDialog=createWithText :180-382：base create bg/line + 左右 Scale9 按钮 + text label）。
# 守卫：静态树 rect（÷CS 换算）/ theme variation 接线 / panel 零静态构造 /
# fill 语义（msg+按钮 LSTR）/ confirmed 信号流 / 绘制序。

const CONTENT_PATH: String = "res://scenes/ui/stage_reset_confirm_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/stage_reset_confirm.gd"
const THEME_PATH: String = "res://resources/themes/default_theme.tres"

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ── 静态树 rect 守卫（源坐标换算：bg 局部左下原点 (x,y) → Frame 内左上原点
# （x/CS, 220.88-y/CS）；显示尺寸 = 源点尺寸 ÷ CS=1.28125）──

func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# 遮罩（源 dialog.lua:34 CCLayerColor ccc4(0,0,0,150) 全屏 → alpha=150/255）
	var shade: ColorRect = inst.get_node("Shade") as ColorRect
	assert_almost_eq(shade.color.a, 150.0 / 255.0, 0.001, "Shade alpha=150/255（源 ccc4 a=150）")
	# bg（源 :40-43 dialog_bg 447x283 ÷CS=348.88x220.88，中心 ccp(400,240)→(480,320)）
	var bg: TextureRect = inst.get_node("Bg") as TextureRect
	assert_almost_eq(bg.offset_left, 305.56, 0.1, "Bg 左 = 480-348.88/2")
	assert_almost_eq(bg.offset_top, 209.56, 0.1, "Bg 顶 = 320-220.88/2")
	assert_almost_eq(bg.size.x, 348.88, 0.1, "Bg 宽 = 447/CS")
	assert_almost_eq(bg.size.y, 220.88, 0.1, "Bg 高 = 283/CS")
	assert_eq(bg.texture.resource_path, "res://assets/ui/alpha/HVGA/dialog_bg.png", "Bg 贴图照源 dialog_bg")
	assert_eq(bg.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "Bg expand_mode=1（rect 定显示尺寸）")
	# line（源 :48-51 dialog_line 403x4 ÷CS=314.54x3.12，bg 局部中心 ccp(172,75)）
	var line: TextureRect = inst.get_node("Bg/Line") as TextureRect
	assert_almost_eq(line.size.x, 314.54, 0.1, "Line 宽 = 403/CS")
	assert_almost_eq(line.size.y, 3.12, 0.1, "Line 高 = 4/CS")
	assert_almost_eq(line.position.x + line.size.x * 0.5, 172.0 / 1.28125, 0.1,
		"Line 中心 x = 172/CS（源 bg 局部 ccp(172,75)，左下原点）")
	assert_almost_eq(line.position.y + line.size.y * 0.5, 220.88 - 75.0 / 1.28125, 0.1,
		"Line 中心 y = 220.88-75/CS（Y 翻转）")
	# Msg（源 confirmDialog createWithText :346-356：20 号 dimensions(300,125) 左对齐垂直居中，
	# 中心 ccp(180,135) → ÷CS=234.15x97.56，中心 (140.44,115.51)）
	var msg: Label = inst.get_node("%Msg") as Label
	assert_almost_eq(msg.offset_left, 23.37, 0.1, "Msg 左 = 180/CS-234.15/2")
	assert_almost_eq(msg.offset_top, 66.73, 0.1, "Msg 顶 = (220.88-135/CS)-97.56/2")
	assert_almost_eq(msg.offset_right - msg.offset_left, 234.15, 0.1, "Msg 宽 = 300/CS（源 dimensions，offsets 差——Label size 受 minsize 撑高不等于声明 rect）")
	assert_almost_eq(msg.offset_bottom - msg.offset_top, 97.56, 0.1, "Msg 高 = 125/CS（offsets 差）")
	assert_eq(msg.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "Msg 左对齐（源 kCCTextAlignmentLeft）")
	assert_eq(msg.vertical_alignment, VERTICAL_ALIGNMENT_CENTER, "Msg 垂直居中（源 setVerticalAlignment(1)=Center）")
	assert_eq(msg.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "Msg autowrap（源 setDimensions 换行）")
	assert_eq(String(msg.theme_type_variation), "DialogMsgLabel", "Msg 走 DialogMsgLabel variation")
	# CancelBtn（源 :276-282 Scale9 herodetail-upgrade size(120,49) 中心 ccp(100,44)）
	var cancel_btn: Button = inst.get_node("%CancelBtn") as Button
	assert_almost_eq(cancel_btn.offset_left, 31.22, 0.1, "CancelBtn 左 = 100/CS-93.66/2")
	assert_almost_eq(cancel_btn.offset_top, 167.41, 0.1, "CancelBtn 顶 = (220.88-44/CS)-38.24/2")
	assert_almost_eq(cancel_btn.size.x, 93.66, 0.1, "CancelBtn 宽 = 120/CS（源 setContentSize，非旧 110）")
	assert_almost_eq(cancel_btn.size.y, 38.24, 0.1, "CancelBtn 高 = 49/CS")
	assert_eq(String(cancel_btn.theme_type_variation), "DialogConfirmBtn", "CancelBtn 走 DialogConfirmBtn 三态 variation")
	# OkBtn（源 :297-303 同 left 中心 ccp(250,44)）
	var ok_btn: Button = inst.get_node("%OkBtn") as Button
	assert_almost_eq(ok_btn.offset_left, 148.29, 0.1, "OkBtn 左 = 250/CS-93.66/2")
	assert_almost_eq(ok_btn.offset_top, 167.41, 0.1, "OkBtn 顶与 CancelBtn 同行（源同 y=44）")
	assert_almost_eq(ok_btn.size.x, 93.66, 0.1, "OkBtn 宽 = 120/CS")
	assert_eq(String(ok_btn.theme_type_variation), "DialogConfirmBtn", "OkBtn 走 DialogConfirmBtn")


# 绘制序守卫（源 bg:addChild 声明序：bg→line→left→right，label 最后追加）：
# 同父 get_index 级防反盖（Msg/按钮恒居 Line 之上；Bg 与 Line 跨父子不可比 index）。
func test_content_draw_order() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var bg: TextureRect = inst.get_node("Bg") as TextureRect
	var line: CanvasItem = inst.get_node("Bg/Line") as CanvasItem
	var msg: CanvasItem = inst.get_node("%Msg") as CanvasItem
	var cancel_btn: CanvasItem = inst.get_node("%CancelBtn") as CanvasItem
	var ok_btn: CanvasItem = inst.get_node("%OkBtn") as CanvasItem
	assert_eq(line.get_parent(), bg, "Line 挂 Bg 子树（源 line bg:addChild）")
	assert_lt(line.get_index(), msg.get_index(), "Line 先于 Msg（源 create 序 :40→:48）")
	assert_lt(msg.get_index(), cancel_btn.get_index(), "Msg 先于按钮")
	assert_lt(cancel_btn.get_index(), ok_btn.get_index(), "Cancel 先于 Ok（源 left→right）")


# theme variation 接线（GUT 下节点级不解析 variation，读 tres 文本表项）。
# 源按钮字：dialog.lua:291-296 createttf(text,20,ed.selfFont) 白 normalColor +
# 阴影 ccc3(63,5,0) 偏移 (1,2)；SB cap CCRectMake(20,20,40,29)（97x67 纹理 →
# left=20 top=67-20-29=18 right=97-20-40=37 bottom=20，批 1 公式）。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("DialogConfirmBtn/font_sizes/font_size = 20"),
		"DialogConfirmBtn 字号 20（源 createttf 20 号）")
	assert_true(t.contains("DialogConfirmBtn/colors/font_shadow_color = Color(0.247059, 0.019608, 0, 1)"),
		"DialogConfirmBtn shadow=ccc3(63,5,0)（63/255,5/255,0）")
	assert_true(t.contains("DialogConfirmBtn/constants/shadow_offset_x = 1"),
		"DialogConfirmBtn shadow_offset_x=1（源 ccp(1,2)）")
	assert_true(t.contains("DialogConfirmBtn/constants/shadow_offset_y = 2"),
		"DialogConfirmBtn shadow_offset_y=2")
	assert_true(t.contains("DialogConfirmBtn/styles/pressed = SubResource(\"SB_dialog_confirm_p\")"),
		"DialogConfirmBtn pressed=SB_dialog_confirm_p（源 press mask）")
	var sb_n: int = t.find("SB_dialog_confirm_n")
	assert_gt(sb_n, 0, "SB_dialog_confirm_n sub_resource 存在")
	var sb_block: String = t.substr(sb_n - 60, 400)
	assert_true(sb_block.contains("texture_margin_left = 20.0"), "SB margin left=源 cap.x=20")
	assert_true(sb_block.contains("texture_margin_top = 18.0"), "SB margin top=67-20-29=18（批 1 公式）")
	assert_true(sb_block.contains("texture_margin_right = 37.0"), "SB margin right=97-20-40=37")
	assert_true(sb_block.contains("texture_margin_bottom = 20.0"), "SB margin bottom=源 cap.y=20")
	assert_true(t.contains("DialogMsgLabel/font_sizes/font_size = 20"),
		"DialogMsgLabel 字号 20（源 createttf(text,20)）")
	assert_true(t.contains("DialogMsgLabel/colors/font_color = Color(1, 1, 1, 1)"),
		"DialogMsgLabel 白（源 setLabelColor(255,255,255)）")


# panel 零静态构造（宽口径白名单）：本 panel 无动态构造需求（content 全静态 + fill），
# 现值 0，改造后若引入动态构造须白名单并说明。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count(".new("), 0, "panel 零 .new(（两件套：静态节点全在 tscn）")


# 源对照语义：right 按钮默认文案源是 FASTSELL.GOOD（dialog.lua:312
# rightText or T(LSTR("FASTSELL.GOOD"))，"好的"），非 CHATCONFIG.CONFIRM。
func test_ok_button_uses_source_lstr_key() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_true(text.contains("LSTR_OK_KEY: String = \"FASTSELL.GOOD\""),
		"Ok 文案键照源 FASTSELL.GOOD（常量定义级断言，注释提及不计数）")
	assert_false(text.contains("LSTR_OK_KEY: String = \"CHATCONFIG.CONFIRM\""),
		"Ok 文案常量不再用 CHATCONFIG.CONFIRM（源对照修正）")


# fill 语义：_ready 即挂 content 接信号（fallback 文案）；setup_msg 注入 cm 后
# deferred 刷新 msg + 按钮文字走 LSTR。
func test_fill_semantics() -> void:
	var panel: StageResetConfirm = StageResetConfirm.new()
	add_child_autofree(panel)
	# _ready 后 fallback 文案（无 cm）
	var cancel_btn: Button = panel.get_node("StageResetConfirmContent/%CancelBtn") as Button
	var ok_btn: Button = panel.get_node("StageResetConfirmContent/%OkBtn") as Button
	assert_eq(cancel_btn.text, "取消", "CancelBtn fallback=取消（CHATCONFIG.CANCEL 中文值）")
	assert_eq(ok_btn.text, "好的", "OkBtn fallback=好的（FASTSELL.GOOD 中文值）")
	# setup_msg 注入 cm + msg → deferred 刷新
	panel.setup_msg("重置关卡进入次数需要花费50钻石.\n是否继续？（今日已重置2次）", cm)
	await get_tree().process_frame
	await get_tree().process_frame
	var msg_lbl: Label = panel.get_node("StageResetConfirmContent/%Msg") as Label
	assert_eq(msg_lbl.text, "重置关卡进入次数需要花费50钻石.\n是否继续？（今日已重置2次）",
		"setup_msg 后 Msg.text=调用方拼好的文案")
	assert_eq(cancel_btn.text, "取消", "CancelBtn 走 LSTR CHATCONFIG.CANCEL=取消")
	assert_eq(ok_btn.text, "好的", "OkBtn 走 LSTR FASTSELL.GOOD=好的")


# confirmed 信号流（源 rightHandler：doPayReset rightHandler → doResetElite）：
# Ok → confirmed + queue_free；Cancel → 仅关窗无 confirmed。
func test_confirm_signal_and_close() -> void:
	var panel: StageResetConfirm = StageResetConfirm.new()
	add_child_autofree(panel)
	watch_signals(panel)
	var ok_btn: Button = panel.get_node("StageResetConfirmContent/%OkBtn") as Button
	ok_btn.pressed.emit()
	assert_signal_emitted(panel, "confirmed", "Ok 触发 confirmed（调用方执行 reset）")
	assert_true(panel.is_queued_for_deletion(), "Ok 后 queue_free（源 destroy）")

	var panel2: StageResetConfirm = StageResetConfirm.new()
	add_child_autofree(panel2)
	watch_signals(panel2)
	var cancel_btn: Button = panel2.get_node("StageResetConfirmContent/%CancelBtn") as Button
	cancel_btn.pressed.emit()
	assert_signal_not_emitted(panel2, "confirmed", "Cancel 仅关窗（源 left 无 handler 仅 destroy）")
	assert_true(panel2.is_queued_for_deletion(), "Cancel 后 queue_free")
