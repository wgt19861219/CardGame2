extends GutTest
# CrusadeResetConfirm 守卫测试（批 3 Task 3 两件套，2026-08-16）。
# 照源 crusade.lua:660-680 resetBattle → dialog.lua confirmDialog 家族
# showDialog（:373-382）——info.sprite 存在（空 CCSprite）→ 走 createWithSprite
# 分支（:339-363），非 Task 1 stage_reset 的 createWithText：
#   ① spriteLabel 中心 ccp(172,135)（createWithText 为 180，x 差 8 点）；
#   ② rightText 显式传 T(LSTR("CHATCONFIG.CONFIRM"))（crusade.lua:670），
#     非 confirmDialog.create 默认 FASTSELL.GOOD；
#   ③ 空 sprite 无贴图零视觉 → 受控裁剪不建节点（布局后果 172 保留）。
# 守卫：静态树 rect（点空间直译）/ theme variation 接线 / panel 零静态构造 /
# fill 语义（msg+按钮 LSTR）/ confirmed 信号流 / 绘制序。

const CONTENT_PATH: String = "res://scenes/ui/crusade_reset_confirm_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/crusade_reset_confirm.gd"


# ── 静态树 rect 守卫（点空间直译：Cocos 子坐标系原点=父 contentSize 左下角，
# 子坐标数值即点值，bg 子树不做整体 ÷CS。bg 点空间 348.88x220.88（447x283
# 像素÷CS=1.28125，TextureConfig 无 dialog 条目）；bg 内左下原点 (x,y) →
# Bg 内左上原点 (x, 220.88-y)；贴图显示尺寸=纹理像素÷CS，setContentSize/
# setDimensions 数值直译）──

func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# 遮罩（源 dialog.lua:37 CCLayerColor ccc4(0,0,0,150) 全屏 → alpha=150/255）
	var shade: ColorRect = inst.get_node("Shade") as ColorRect
	assert_almost_eq(shade.color.a, 150.0 / 255.0, 0.001, "Shade alpha=150/255（源 ccc4 a=150）")
	# bg（源 :40-43 dialog_bg 447x283 像素÷CS=348.88x220.88 点，中心 ccp(400,240)→(480,320)）
	var bg: TextureRect = inst.get_node("Bg") as TextureRect
	assert_almost_eq(bg.offset_left, 225.56, 0.1, "Bg 左 = 480-348.88/2")
	assert_almost_eq(bg.offset_top, 129.56, 0.1, "Bg 顶 = 320-220.88/2")
	assert_almost_eq(bg.size.x, 348.88, 0.1, "Bg 宽 = 447/CS")
	assert_almost_eq(bg.size.y, 220.88, 0.1, "Bg 高 = 283/CS")
	assert_eq(bg.texture.resource_path, "res://assets/ui/alpha/HVGA/dialog_bg.png", "Bg 贴图照源 dialog_bg")
	assert_eq(bg.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "Bg expand_mode=1（rect 定显示尺寸）")
	# line（源 :48-51 dialog_line 403x4 像素÷CS=314.54x3.12 点，bg 局部中心 ccp(172,75) 点直译）
	var line: TextureRect = inst.get_node("Bg/Line") as TextureRect
	assert_almost_eq(line.size.x, 314.54, 0.1, "Line 宽 = 403/CS（贴图显示尺寸仍÷CS）")
	assert_almost_eq(line.size.y, 3.12, 0.1, "Line 高 = 4/CS")
	assert_almost_eq(line.position.x + line.size.x * 0.5, 172.0, 0.1,
		"Line 中心 x = 172 点（源 bg 局部 ccp(172,75) 数值即点值，不÷CS）")
	assert_almost_eq(line.position.y + line.size.y * 0.5, 220.88 - 75.0, 0.1,
		"Line 中心 y = 220.88-75（Y 翻转，子坐标点值直译）")
	# Msg（源 createWithSprite :349-356 spriteLabel：20 号白 dimensions(300,125) 直译
	# 左对齐垂直居中，中心 ccp(172,135) 点——createWithSprite 分支 x=172 非
	# createWithText 的 180 → Bg 内 (22,23.38)-(322,148.38)）
	var msg: Label = inst.get_node("%Msg") as Label
	assert_almost_eq(msg.offset_left, 22.0, 0.1, "Msg 左 = 172-300/2（createWithSprite 点直译，非 createWithText 的 30）")
	assert_almost_eq(msg.offset_top, 23.38, 0.1, "Msg 顶 = (220.88-135)-125/2（点直译）")
	assert_almost_eq(msg.offset_right - msg.offset_left, 300.0, 0.1, "Msg 宽 = 300（源 setDimensions 直译，offsets 差）")
	assert_almost_eq(msg.offset_bottom - msg.offset_top, 125.0, 0.1, "Msg 高 = 125（直译，offsets 差）")
	assert_eq(msg.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "Msg 左对齐（源 kCCTextAlignmentLeft）")
	assert_eq(msg.vertical_alignment, VERTICAL_ALIGNMENT_CENTER, "Msg 垂直居中（源 setVerticalAlignment(1)=Center）")
	assert_eq(msg.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "Msg autowrap（源 setDimensions 换行）")
	assert_eq(String(msg.theme_type_variation), "DialogMsgLabel", "Msg 走 DialogMsgLabel variation")
	# CancelBtn（源 confirmDialog.create :273-277 left Scale9 herodetail-upgrade
	# size(120,49) 直译，中心 bg 局部 ccp(100,44) 点）
	var cancel_btn: Button = inst.get_node("%CancelBtn") as Button
	assert_almost_eq(cancel_btn.offset_left, 40.0, 0.1, "CancelBtn 左 = 100-120/2（点直译）")
	assert_almost_eq(cancel_btn.offset_top, 152.38, 0.1, "CancelBtn 顶 = (220.88-44)-49/2（点直译）")
	assert_almost_eq(cancel_btn.size.x, 120.0, 0.1, "CancelBtn 宽 = 120（源 setContentSize 直译）")
	assert_almost_eq(cancel_btn.size.y, 49.0, 0.1, "CancelBtn 高 = 49（直译）")
	assert_eq(String(cancel_btn.theme_type_variation), "DialogConfirmBtn", "CancelBtn 走 DialogConfirmBtn 三态 variation")
	# OkBtn（源 :292-296 right 同 left 中心 bg 局部 ccp(250,44) 点）
	var ok_btn: Button = inst.get_node("%OkBtn") as Button
	assert_almost_eq(ok_btn.offset_left, 190.0, 0.1, "OkBtn 左 = 250-120/2（点直译）")
	assert_almost_eq(ok_btn.offset_top, 152.38, 0.1, "OkBtn 顶与 CancelBtn 同行（源同 y=44）")
	assert_almost_eq(ok_btn.size.x, 120.0, 0.1, "OkBtn 宽 = 120（直译）")
	assert_eq(String(ok_btn.theme_type_variation), "DialogConfirmBtn", "OkBtn 走 DialogConfirmBtn")


# 绘制序守卫（源 bg:addChild 声明序：line(:51)→left(:279)→right(:298)→
# sprite(:346)→spriteLabel(:357) 最后置顶；空 sprite 裁剪不建）：
# 同父 get_index 级防反盖（Msg 最后置顶恒在按钮/Line 之上）。
func test_content_draw_order() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var bg: TextureRect = inst.get_node("Bg") as TextureRect
	var line: CanvasItem = inst.get_node("Bg/Line") as CanvasItem
	var msg: CanvasItem = inst.get_node("%Msg") as CanvasItem
	var cancel_btn: CanvasItem = inst.get_node("%CancelBtn") as CanvasItem
	var ok_btn: CanvasItem = inst.get_node("%OkBtn") as CanvasItem
	assert_eq(line.get_parent(), bg, "Line 挂 Bg 子树（源 line bg:addChild）")
	assert_lt(line.get_index(), cancel_btn.get_index(), "Line 先于按钮（源 create 序 :48→:273）")
	assert_lt(cancel_btn.get_index(), ok_btn.get_index(), "Cancel 先于 Ok（源 left→right）")
	assert_gt(msg.get_index(), cancel_btn.get_index(), "Msg 后于 Cancel（源 spriteLabel 最后追加置顶 :357）")
	assert_gt(msg.get_index(), ok_btn.get_index(), "Msg 后于 Ok（源 spriteLabel 最后追加置顶 :357）")


# theme variation 接线复用 Task 1 的 DialogConfirmBtn/DialogMsgLabel（同源
# dialog.lua 样式：按钮 20 号白+阴影 ccc3(63,5,0)(1,2)+cap(20,20,40,29) 三态；
# 正文 20 号白）——GUT 下节点级不解析 variation，断言 tres 表项 + tscn 接线。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string("res://resources/themes/default_theme.tres")
	assert_true(t.contains("DialogConfirmBtn/font_sizes/font_size = 20"),
		"DialogConfirmBtn 字号 20（源 createttf 20 号）")
	assert_true(t.contains("DialogConfirmBtn/styles/pressed = SubResource(\"SB_dialog_confirm_p\")"),
		"DialogConfirmBtn pressed=SB_dialog_confirm_p（源 press mask）")
	assert_true(t.contains("DialogMsgLabel/font_sizes/font_size = 20"),
		"DialogMsgLabel 字号 20（源 createttf(spriteLabel,20)）")
	assert_true(t.contains("DialogMsgLabel/colors/font_color = Color(1, 1, 1, 1)"),
		"DialogMsgLabel 白（源 setLabelColor(255,255,255)）")


# panel 零静态构造（宽口径白名单）：content 全静态 + fill，无动态构造需求。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count(".new("), 0, "panel 零 .new(（两件套：静态节点全在 tscn）")
	assert_false(text.contains("UiScale9Button"), "不再走 UiScale9Button 运行时 override（theme variation 三态）")


# 源对照语义：rightText 显式传 T(LSTR("CHATCONFIG.CONFIRM"))（crusade.lua:670
# "确定"），非 confirmDialog.create 默认 FASTSELL.GOOD——与 Task 1 stage_reset
# （走默认）方向相反，本弹窗键照源保留 CHATCONFIG.CONFIRM。
func test_ok_button_uses_source_lstr_key() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_true(text.contains("LSTR_OK_KEY: String = \"CHATCONFIG.CONFIRM\""),
		"Ok 文案键照源 crusade.lua:670 显式传 CHATCONFIG.CONFIRM（常量定义级断言）")
	assert_false(text.contains("LSTR_OK_KEY: String = \"FASTSELL.GOOD\""),
		"Ok 文案常量不用 FASTSELL.GOOD（那是未传 rightText 的默认值路径）")


# fill 语义：_ready 即挂 content 接信号并 fill msg/按钮文案（GameData.config
# LSTR；GUT 下 autoload 已 load_all，断言 zh-CN 实值）。
func test_fill_semantics() -> void:
	var panel: CrusadeResetConfirm = CrusadeResetConfirm.new()
	add_child_autofree(panel)
	var msg_lbl: Label = panel.get_node("CrusadeResetConfirmContent/%Msg") as Label
	assert_eq(msg_lbl.text, "是否结束本次远征并重新开始？",
		"Msg=LSTR CRUSADE.END_THIS_EXPEDITION_AND_START_OVER zh-CN 实值")
	var cancel_btn: Button = panel.get_node("CrusadeResetConfirmContent/%CancelBtn") as Button
	var ok_btn: Button = panel.get_node("CrusadeResetConfirmContent/%OkBtn") as Button
	assert_eq(cancel_btn.text, "取消", "CancelBtn=LSTR CHATCONFIG.CANCEL=取消")
	assert_eq(ok_btn.text, "确定", "OkBtn=LSTR CHATCONFIG.CONFIRM=确定")


# confirmed 信号流（源 rightHandler：crusade.lua:671-676 发 reset 消息 →
# 单机化 confirmed 信号，调用方 crusade_panel._on_reset_confirmed 执行 reset）：
# Ok → confirmed + queue_free；Cancel → 仅关窗无 confirmed（源无 leftHandler）。
func test_confirm_signal_and_close() -> void:
	var panel: CrusadeResetConfirm = CrusadeResetConfirm.new()
	add_child_autofree(panel)
	watch_signals(panel)
	var ok_btn: Button = panel.get_node("CrusadeResetConfirmContent/%OkBtn") as Button
	ok_btn.pressed.emit()
	assert_signal_emitted(panel, "confirmed", "Ok 触发 confirmed（调用方执行 reset）")
	assert_true(panel.is_queued_for_deletion(), "Ok 后 queue_free（源 destroy）")

	var panel2: CrusadeResetConfirm = CrusadeResetConfirm.new()
	add_child_autofree(panel2)
	watch_signals(panel2)
	var cancel_btn: Button = panel2.get_node("CrusadeResetConfirmContent/%CancelBtn") as Button
	cancel_btn.pressed.emit()
	assert_signal_not_emitted(panel2, "confirmed", "Cancel 仅关窗（源 left 无 handler 仅 destroy）")
	assert_true(panel2.is_queued_for_deletion(), "Cancel 后 queue_free")
