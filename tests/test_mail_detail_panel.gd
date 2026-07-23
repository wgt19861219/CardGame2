extends GutTest

## MailDetailPanel UI 装配验证（P1-4：title_bg/attach_bg 装饰背景 + attach_common 7 货币忠实路径）。
# headless 逻辑视觉验收：节点结构断言替 bridge 交互截图。
# C10/C11（2026-07-23）：_on_ok 三分支（未读+附件/未读无附件/已读）行为验证。


# P1-4：title_bg（equip_craft_money_bg，源 createTitle :9-20）装配。
func test_panel_assembles_title_bg() -> void:
	var panel := MailDetailPanel.new("mail_detail", {})
	panel.setup_panel(GameData.player, 1, Callable())
	assert_true(_has_tex(panel, panel.TITLE_BG_TEX), "title_bg 装配（equip_craft_money_bg）")
	panel.free()


# P1-4：attach_bg（mailbox_letter_addon_bg，源 createAttach :221-234）装配（mail 1 有附件）。
func test_panel_assembles_attach_bg() -> void:
	var panel := MailDetailPanel.new("mail_detail", {})
	panel.setup_panel(GameData.player, 1, Callable())
	assert_true(_has_tex(panel, panel.ATTACH_BG_TEX), "attach_bg 装配（mailbox_letter_addon_bg）")
	panel.free()


# P1-4：attach_common 按 type 查 7 货币图标（mail 1：Gold 5000 + Diamond 200 → 2 货币 icon）。
func test_panel_currency_icons_match_attach_common() -> void:
	var panel := MailDetailPanel.new("mail_detail", {})
	panel.setup_panel(GameData.player, 1, Callable())
	var ac: Array = panel._mail.get("attach_common", [])
	# mail 1 attach_common 2 项（Gold+Diamond），frame 下应有 goldicon_small + shop_token_icon
	assert_eq(ac.size(), 2, "mail 1 attach_common 2 项")
	assert_true(_has_tex(panel, panel.CURRENCY_ICONS["Gold"]), "Gold 货币图标装配")
	assert_true(_has_tex(panel, panel.CURRENCY_ICONS["Diamond"]), "Diamond 货币图标装配")
	panel.free()


# 递归查 TextureRect by resource_path。
func _has_tex(node: Node, path: String) -> bool:
	if node is TextureRect and node.texture != null and node.texture.resource_path == path:
		return true
	for c in node.get_children():
		if _has_tex(c, path):
			return true
	return false


# P1（2026-07-16）：UI 文案 LSTR 化验证（ok label CLAIM + attach title 走 GameData.config）。
# mail 1 welcome：unread + attached → ok label = CLAIM（源 content.lua:463）。
func test_panel_ok_label_uses_lstr() -> void:
	var panel := MailDetailPanel.new("mail_detail", {})
	panel.setup_panel(GameData.player, 1, Callable())
	var cfg: ConfigManager = GameData.config
	var ok_btns: Array = panel.find_children("*", "TextureButton", true, false)
	assert_eq(ok_btns.size(), 1, "1 个 ok 按钮")
	var lbl_text: String = ""
	for c in ok_btns[0].get_children():
		if c is Label:
			lbl_text = String(c.text)
	assert_eq(lbl_text, cfg.get_lstr("MAILBOX.CLAIM"), "ok label = LSTR MAILBOX.CLAIM（mail 1 unread+attached）")
	assert_true(_has_label_text(panel, cfg.get_lstr("MAILBOX.ATTACHMENTS_")), "attach title 走 LSTR MAILBOX.ATTACHMENTS_")
	panel.free()


# 递归查 Label by text。
func _has_label_text(node: Node, text: String) -> bool:
	if node is Label and String(node.text) == text:
		return true
	for c in node.get_children():
		if _has_label_text(c, text):
			return true
	return false


# ── C10/C11（2026-07-23）：_on_ok 三分支行为验证 ──
# 源 content.lua:483-491 doClickRead + local_server.lua:2750-2779 read_mail handler。
# 未读无附件 → mark_read+erase_mail（C10 补 erase）；已读 → _close（C11 补 else 分支）。

# 构造 PlayerData（含 1 封指定状态/附件的 raw 邮件），setup_panel 取该邮件后调 _on_ok。
# 用 PlayerData.new(GameData.config) 真实例（保 setup_panel 类型注解兼容）+ 自定义 MailData 注入。
func _make_pd_with_mail(mail_id: int, status: String, attached: bool) -> PlayerData:
	var pd := PlayerData.new(GameData.config)
	var md := MailData.new()
	var raw: Dictionary = {
		"_id": mail_id,
		"_status": status,
		"_date": "2026-07-23",
		"_content": {"_plain_mail": {"_from": "系统", "_title": "通知", "_content": "内容"}},
		"_money": 5000 if attached else 0,
		"_diamonds": 0,
		"_skill_point": 0,
		"_items": [],
	}
	md._raw_mails = [raw]
	pd.mailbox = md
	return pd


# C10：未读无附件邮件点 ok → mark_read + erase_mail（照源 read_mail:2755-2760 从 mails 移除）。
# 修复前 mark_read 只改 status，未读无附件邮件永久留列表（claim_attach 分支已 erase，此处对齐）。
func test_on_ok_unread_no_attach_erases_mail() -> void:
	var pd := _make_pd_with_mail(100, "unread", false)
	var panel := MailDetailPanel.new("mail_detail", {})
	add_child(panel)
	var closed := [false]
	panel.setup_panel(pd, 100, Callable(func() -> void: closed[0] = true))
	assert_eq(str(panel._mail.get("status", "")), "unread", "mail 100 初始 unread")
	assert_false(bool(panel._mail.get("attached", true)), "mail 100 无附件")
	panel._on_ok()
	assert_eq(pd.mailbox.ordered_mails().size(), 0, "未读无附件点 ok 后从 mails 移除（照源 read_mail）")
	assert_eq(pd.mailbox.get_mail(100), {}, "get_mail 返空（raw 已 erase）")
	assert_true(closed[0], "_on_closed 回调被触发（_close）")
	panel.free()


# C11：已读邮件点 ok → _close（源 doClickRead:483-491 else 分支 destroy+callback）。
# 修复前三分支无 else，已读邮件点 ok 啥也不做（不关闭）。
func test_on_ok_read_closes_panel() -> void:
	var pd := _make_pd_with_mail(200, "read", false)
	var panel := MailDetailPanel.new("mail_detail", {})
	add_child(panel)
	var closed := [false]
	panel.setup_panel(pd, 200, Callable(func() -> void: closed[0] = true))
	assert_eq(str(panel._mail.get("status", "")), "read", "mail 200 初始 read")
	panel._on_ok()
	# 已读点 ok 不 erase（源 doClickRead else 仅 destroy，不触发 read_mail handler）
	assert_ne(pd.mailbox.get_mail(200), {}, "已读点 ok 不 erase（源 doClickRead else destroy 不移除 raw）")
	assert_true(closed[0], "已读点 ok 触发 _close（源 destroy callback）")
	panel.free()
