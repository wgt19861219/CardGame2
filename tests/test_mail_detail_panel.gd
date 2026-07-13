extends GutTest

## MailDetailPanel UI 装配验证（P1-4：title_bg/attach_bg 装饰背景 + attach_common 7 货币忠实路径）。
# headless 逻辑视觉验收：节点结构断言替 bridge 交互截图。


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
