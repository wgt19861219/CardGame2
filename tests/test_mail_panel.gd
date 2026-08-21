extends GutTest
# MailPanel 列表主面板测试（照源 ui/mailbox.lua）。
# 2026-08-16 批 2 Task 5 两件套改造：chrome 静态树守卫（mail_content.tscn）+
# 邮件行模板守卫（mail_item.tscn，源 createMail:445-592 行结构直译）+
# mask 静态化 + press setScale(0.95) + 零静态构造白名单。

var cm: ConfigManager

const CONTENT_PATH := "res://scenes/ui/mail_content.tscn"
const ITEM_PATH := "res://scenes/ui/mail_item.tscn"
const PANEL_PATH := "res://scripts/ui/mail_panel.gd"
const THEME_PATH := "res://resources/themes/default_theme.tres"


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel() -> MailPanel:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := MailPanel.new("mailbox", {})
	panel.setup_panel(pd)
	panel.show_window(root)
	return panel


# P1 源 mailbox.lua:257-258 mailbox_mask_up/down 渐变遮罩：list 顶/底淡出。
# 两件套后 mask 静态化进 mail_content.tscn（TopMask/BottomMask 贴 MailScroll 顶/底）。
func test_scroll_masks_assembled() -> void:
	var panel := _make_panel()
	var content: Control = panel.container.get_child(0)
	var has_up: bool = _has_mask(content, "mailbox_mask_up")
	var has_down: bool = _has_mask(content, "mailbox_mask_down")
	assert_true(has_up, "顶 mailbox_mask_up 渐变遮罩装配（源 :257）")
	assert_true(has_down, "底 mailbox_mask_down 渐变遮罩装配（源 :258）")
	# 静态 mask 贴 ScrollContainer 顶/底（宽=scroll 宽 360，高=纹理显示 20.29）
	var scroll: ScrollContainer = content.get_node("%MailScroll") as ScrollContainer
	var top_mask: Control = _find_mask(content, "mailbox_mask_up")
	assert_almost_eq(top_mask.position.y, scroll.position.y, 0.5, "TopMask 贴 scroll 顶")
	var bottom_mask: Control = _find_mask(content, "mailbox_mask_down")
	assert_almost_eq(bottom_mask.position.y + bottom_mask.size.y, scroll.position.y + scroll.size.y, 0.5,
		"BottomMask 贴 scroll 底")
	panel.remove_window()
	panel.get_parent().queue_free()


# P0-2 源 mailbox.lua:126-132 行 press setScale(0.95)：button_down→缩，button_up→回弹。
# 行模板 root TextureButton 连 button_down/up 信号驱动 scale Tween + pivot 居中。
func test_mail_row_press_scale_wired() -> void:
	var panel := _make_panel()
	if panel._mail_list.get_child_count() > 0:
		var row: TextureButton = panel._mail_list.get_child(0) as TextureButton
		assert_not_null(row, "邮件行是 mail_item.tscn 模板实例（TextureButton root）")
		assert_true(row.button_down.is_connected(panel._tween_row_scale), "button_down 连 _tween_row_scale")
		assert_true(row.button_up.is_connected(panel._tween_row_scale), "button_up 连 _tween_row_scale")
		assert_almost_eq(row.pivot_offset.x, 170.0, 0.5, "行 pivot x 居中（340/2，源 board 中心 setScale）")
		assert_almost_eq(row.pivot_offset.y, 45.0, 0.5, "行 pivot y 居中（90/2）")
	panel.remove_window()
	panel.get_parent().queue_free()


# ══════════ 批 2 两件套守卫（2026-08-16，mailbox.lua create:594-684 直译）══════════

# chrome 静态树（mail_content.tscn）：frame/scroll 坐标照源直译。
# frame mailbox_frame(508x571px) 中心 ccp(400,240) → 显示 396.49x445.66 中心
# to_godot(400,240)=(480,320)；close(65x66px) frame 局部 (395,420)（readnode root=
# frame，原点=frame 左下角 (201.75,17.17)）→ 中心 (596.75,437.17)；
# draglist cliprect CCRectMake(20,20,360,370)（mailbox.lua:253）frame 局部 →
# 场景 (221.75,37.17) → Godot (301.75,152.83)-(661.75,522.83)。
func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var frame: TextureRect = inst.get_node("Frame") as TextureRect
	assert_almost_eq(frame.size.x, 396.49, 0.5, "Frame 宽 = 508px/CS")
	assert_almost_eq(frame.size.y, 445.66, 0.5, "Frame 高 = 571px/CS")
	assert_almost_eq(frame.position.x + frame.size.x * 0.5, 400.0, 0.5, "Frame 中心 x = 400+80")
	assert_almost_eq(frame.position.y + frame.size.y * 0.5, 240.0, 0.5, "Frame 中心 y = 560-240")
	var close_btn: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(close_btn.size.x, 50.73, 0.5, "CloseBtn 宽 = 65px/CS")
	assert_almost_eq(close_btn.size.y, 51.51, 0.5, "CloseBtn 高 = 66px/CS")
	assert_almost_eq(close_btn.position.x + close_btn.size.x * 0.5, 596.75, 0.5,
		"CloseBtn 中心 x = 201.75+395+80（frame 左下原点直译）")
	assert_almost_eq(close_btn.position.y + close_btn.size.y * 0.5, 42.86, 0.5,
		"CloseBtn 中心 y = 560-(17.17+420)")
	assert_eq(close_btn.stretch_mode, TextureButton.STRETCH_SCALE, "CloseBtn stretch=SCALE（默认 KEEP 溢出）")
	var title_bg: TextureRect = inst.get_node("TitleBg") as TextureRect
	assert_almost_eq(title_bg.size.x, 328.59, 0.5, "TitleBg 宽 = 421px/CS")
	assert_almost_eq(title_bg.position.x + title_bg.size.x * 0.5, 401.75, 0.5,
		"TitleBg 中心 x = 201.75+200+80")
	var scroll: ScrollContainer = inst.get_node("%MailScroll") as ScrollContainer
	assert_almost_eq(scroll.offset_left, 221.75, 0.5, "MailScroll 左 = cliprect 直译")
	assert_almost_eq(scroll.offset_top, 72.83, 0.5, "MailScroll 顶 = 560-(37.17+370)")
	assert_almost_eq(scroll.offset_right, 581.75, 0.5, "MailScroll 右 = 301.75+360")
	assert_almost_eq(scroll.offset_bottom, 442.83, 0.5, "MailScroll 底 = 560-37.17")
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "纵向滚动启用（源 draglist）")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "横向禁滚")


# 邮件行模板静态树（mail_item.tscn）：源 createMail:445-592 行结构直译。
# 行 board 340x90（:450-451）；icon_bg @ (45,45) 中心（:484-487）默认 task_icon_bg
# 显示 73.37x78.83；icon_frame gocha @ (45,46)（:564-570）显示 73.37x74.15；
# letter icon @ (45,47)（:576-583）显示 60.88x60.88；name @ (95,70) anchor(0,0.5)
# size20 宽上限 200（:552-554）；from_title @ (95,40) size18；from right2 from_title
# 宽上限 180；date @ (95,15) size18。行内 y-up → Godot (x, 90-y)。
func test_mail_item_template_static_rects() -> void:
	var inst: TextureButton = (load(ITEM_PATH) as PackedScene).instantiate() as TextureButton
	add_child_autofree(inst)
	assert_almost_eq(inst.size.x, 340.0, 0.5, "行宽 = board 340")
	assert_almost_eq(inst.size.y, 90.0, 0.5, "行高 = board 90")
	assert_eq(inst.stretch_mode, TextureButton.STRETCH_SCALE, "行 bg stretch=SCALE（源 Sprite mediate 填满 board）")
	var icon_bg: TextureRect = inst.get_node("%IconBg") as TextureRect
	assert_almost_eq(icon_bg.position.x + icon_bg.size.x * 0.5, 45.0, 0.5, "IconBg 中心 x = 45")
	assert_almost_eq(icon_bg.position.y + icon_bg.size.y * 0.5, 45.0, 0.5, "IconBg 中心 y = 90-45")
	assert_almost_eq(icon_bg.size.x, 73.37, 0.5, "IconBg 默认宽 = task_icon_bg 94px/CS")
	assert_almost_eq(icon_bg.size.y, 78.83, 0.5, "IconBg 默认高 = 101px/CS（不再强拉 50 方形）")
	var icon_frame: TextureRect = inst.get_node("%IconFrame") as TextureRect
	assert_false(icon_frame.visible, "IconFrame 默认隐藏（iconres 分支 fill 显示）")
	assert_almost_eq(icon_frame.position.x + icon_frame.size.x * 0.5, 45.0, 0.5, "IconFrame 中心 x = 45")
	assert_almost_eq(icon_frame.position.y + icon_frame.size.y * 0.5, 44.0, 0.5, "IconFrame 中心 y = 90-46")
	var letter_icon: TextureRect = inst.get_node("%LetterIcon") as TextureRect
	assert_false(letter_icon.visible, "LetterIcon 默认隐藏（iconres 分支 fill 显示）")
	assert_almost_eq(letter_icon.size.x, 60.88, 0.5, "LetterIcon 宽 = 78px/CS")
	assert_almost_eq(letter_icon.position.y + letter_icon.size.y * 0.5, 43.0, 0.5, "LetterIcon 中心 y = 90-47")
	var name_lbl: Label = inst.get_node("%Name") as Label
	assert_almost_eq(name_lbl.position.x, 95.0, 0.5, "Name x = 95（anchor(0,0.5)）")
	assert_almost_eq(name_lbl.position.y + name_lbl.size.y * 0.5, 20.0, 1.0, "Name 垂直中心 = 90-70")
	assert_almost_eq(name_lbl.size.x, 200.0, 0.5, "Name 宽上限 200（源 :552 超宽 scale）")
	var from_title: Label = inst.get_node("%FromTitle") as Label
	assert_almost_eq(from_title.position.x, 95.0, 0.5, "FromTitle x = 95")
	assert_almost_eq(from_title.position.y + from_title.size.y * 0.5, 50.0, 1.0, "FromTitle 垂直中心 = 90-40")
	var from_lbl: Label = inst.get_node("%From") as Label
	assert_almost_eq(from_lbl.position.x, 199.0, 0.5, "From x 紧接 FromTitle 右（right2）")
	var date_lbl: Label = inst.get_node("%Date") as Label
	assert_almost_eq(date_lbl.position.x, 95.0, 0.5, "Date x = 95")
	assert_almost_eq(date_lbl.position.y + date_lbl.size.y * 0.5, 75.0, 1.0, "Date 垂直中心 = 90-15")


# 行装配走 mail_item.tscn 模板（源 createMail + getMailPos oy=335 dy=100 → 行距 100）。
# PlayerData 默认 2 封系统邮件（welcome + newbie），源 orderMailData:304-320 同 status
# 按 id 大者在前 → newbie（道具礼包，id 大）行1、welcome 行2；newbie 带装备 icon（iconid 分支）。
func test_mail_rows_from_template() -> void:
	var panel := _make_panel()
	await get_tree().process_frame   # 等 VBox 完成一帧排版（行距断言）
	var rows: Array = panel._mail_list.get_children()
	assert_eq(rows.size(), 2, "默认 2 封系统邮件")
	for r in rows:
		assert_true(r is TextureButton, "邮件行是模板实例（TextureButton root）")
		for w in ["%IconBg", "%IconFrame", "%LetterIcon", "%Name", "%FromTitle", "%From", "%Date"]:
			assert_true((r as Node).has_node(w), "行模板子节点存在: " + w)
	var first: TextureButton = rows[0] as TextureButton
	var name_lbl: Label = first.get_node("%Name") as Label
	assert_eq(String(name_lbl.text), "道具礼包", "行1 name fill（newbie，id 大排前）")
	assert_almost_eq(first.position.y, 0.0, 0.5, "首行 y = 0（VBox 顶起）")
	assert_almost_eq((rows[1] as Control).position.y, 100.0, 0.5, "行距 100 = 行高 90 + separation 10（源 dy=100）")
	# newbie 行带 items → iconid 分支：IconFrame/LetterIcon 隐藏、EquipHost 显示
	assert_false((first.get_node("%IconFrame") as CanvasItem).visible, "装备邮件行 IconFrame 隐藏（iconid 分支）")
	assert_true((first.get_node("%EquipHost") as CanvasItem).visible, "装备邮件行 EquipHost 显示（iconid 分支）")
	var second: TextureButton = rows[1] as TextureButton
	assert_true((second.get_node("%IconFrame") as CanvasItem).visible, "welcome 行 IconFrame 显示（iconres 分支）")
	assert_true((second.get_node("%LetterIcon") as CanvasItem).visible, "welcome 行 LetterIcon 显示（iconres 分支）")
	panel.remove_window()
	panel.get_parent().queue_free()


# panel 零静态构造（宽口径白名单）：行走 mail_item.tscn 模板，仅详情面板工厂 1 处 .new(。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count("MailDetailPanel.new("), 1, "仅 1 处详情面板工厂 MailDetailPanel.new(")
	assert_eq(text.count(".new("), 1, "宽口径 .new( 总数 = 白名单之和")


# theme variation 接线（读 tres 文本表项；GUT 下节点级不解析 variation）。
# 源字号/色：title size26 ccc3(251,206,16)（:659-671）；name size20 ccc3(67,59,56)；
# from_title size18 ccc3(67,59,56)；from size18 ccc3(138,56,1)；date size18 ccc3(157,117,89)。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("MailTitleLabel/font_sizes/font_size = 26"), "title 字号 26")
	assert_true(t.contains("MailTitleLabel/colors/font_color = Color(0.984314, 0.807843, 0.062745, 1)"),
		"title 色 = ccc3(251,206,16)")
	assert_true(t.contains("MailRowNameLabel/font_sizes/font_size = 20"), "name 字号 20")
	assert_true(t.contains("MailRowNameLabel/colors/font_color = Color(0.262745, 0.231373, 0.219608, 1)"),
		"name 色 = ccc3(67,59,56)")
	assert_true(t.contains("MailRowFromLabel/colors/font_color = Color(0.541176, 0.219608, 0.003922, 1)"),
		"from 色 = ccc3(138,56,1)")
	assert_true(t.contains("MailRowDateLabel/colors/font_color = Color(0.615686, 0.458824, 0.34902, 1)"),
		"date 色 = ccc3(157,117,89)")


# 递归扫子树找 TextureRect 含指定资源路径片段。
func _has_mask(node: Node, path_fragment: String) -> bool:
	return _find_mask(node, path_fragment) != null


func _find_mask(node: Node, path_fragment: String) -> Control:
	if node is TextureRect and node.texture != null:
		if String(node.texture.resource_path).find(path_fragment) >= 0:
			return node as Control
	for c in node.get_children():
		var found: Control = _find_mask(c, path_fragment)
		if found != null:
			return found
	return null
