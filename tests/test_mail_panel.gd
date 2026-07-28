extends GutTest
# MailPanel 列表面板测试（照源 mailbox.lua）。
# 重点：P1 源 mailbox.lua:257-258 mailbox_mask_up/down 渐变遮罩 + 行 press setScale(0.95)。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# P1 源 mailbox.lua:257-258 mailbox_mask_up/down 渐变遮罩：list 顶/底淡出。
# _build_content 后 content 应含 2 个 mask TextureRect（up + down）。
func test_scroll_masks_assembled() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := MailPanel.new("mailbox", {})
	panel.setup_panel(pd)
	panel.show_window(root)
	# content（container 1 子 = MailContent），扫子树找 mask_up / mask_down。
	var content: Control = panel.container.get_child(0)
	var has_up: bool = _has_mask(content, "mailbox_mask_up")
	var has_down: bool = _has_mask(content, "mailbox_mask_down")
	assert_true(has_up, "顶 mailbox_mask_up 渐变遮罩装配（源 :257）")
	assert_true(has_down, "底 mailbox_mask_down 渐变遮罩装配（源 :258）")
	panel.remove_window()
	root.queue_free()


# P0-2 源 mailbox.lua:126-132 行 press setScale(0.95)：button_down→缩，button_up→回弹。
# 行（Button）连 button_down/up 信号驱动 scale Tween + pivot 居中。
func test_mail_row_press_scale_wired() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := MailPanel.new("mailbox", {})
	panel.setup_panel(pd)
	panel.show_window(root)
	# _mail_list 第 1 行（Button）应连 button_down/up 到 _tween_row_scale。
	if panel._mail_list.get_child_count() > 0:
		var row: Button = panel._mail_list.get_child(0) as Button
		assert_not_null(row, "邮件行是 Button")
		assert_true(row.button_down.is_connected(panel._tween_row_scale), "button_down 连 _tween_row_scale")
		assert_true(row.button_up.is_connected(panel._tween_row_scale), "button_up 连 _tween_row_scale")
		assert_almost_eq(row.pivot_offset.x, MailPanel.ROW_SIZE.x * 0.5, 0.5, "行 pivot x 居中")
	panel.remove_window()
	root.queue_free()


# 递归扫子树找 TextureRect 含指定资源路径片段。
func _has_mask(node: Node, path_fragment: String) -> bool:
	if node is TextureRect and node.texture != null:
		if String(node.texture.resource_path).find(path_fragment) >= 0:
			return true
	for c in node.get_children():
		if _has_mask(c, path_fragment):
			return true
	return false
