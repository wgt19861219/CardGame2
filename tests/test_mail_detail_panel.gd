extends GutTest

## MailDetailPanel UI 装配验证（P1-4：title_bg/attach_bg 装饰背景 + attach_common 7 货币忠实路径）。
## headless 逻辑视觉验收：节点结构断言替 bridge 交互截图。
## C10/C11（2026-07-23）：_on_ok 三分支（未读+附件/未读无附件/已读）行为验证。
## 2026-08-16 批 2 Task 5 两件套改造：TitleBg/AttachBg Scale9 → NinePatchRect 守卫 +
## OkBtn TextureButton → Button theme variation + 静态树 + 零静态构造白名单。

const CONTENT_PATH := "res://scenes/ui/mail_detail_content.tscn"
const CURRENCY_ITEM_PATH := "res://scenes/ui/mail_currency_item.tscn"
const PANEL_PATH := "res://scripts/ui/mail_detail_panel.gd"
const THEME_PATH := "res://resources/themes/default_theme.tres"


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


# P1-4：attach_common 按 type 查 7 货币图标（自造 mail：Gold 5000 + Diamond 200 → 2 货币 icon）。
# 2026-09-16 改自造数据（原依赖 GameData.player 默认 mail 1，真实存档邮箱可空致脆弱）。
func test_panel_currency_icons_match_attach_common() -> void:
	var pd := _make_pd_with_mail(1, "unread", true)
	var panel := MailDetailPanel.new("mail_detail", {})
	panel.setup_panel(pd, 1, Callable())
	var ac: Array = panel._mail.get("attach_common", [])
	# attach_common 2 项（Gold+Diamond），frame 下应有 goldicon_small + shop_token_icon
	assert_eq(ac.size(), 2, "attach_common 2 项")
	assert_true(_has_tex(panel, panel.CURRENCY_ICONS["Gold"]), "Gold 货币图标装配")
	assert_true(_has_tex(panel, panel.CURRENCY_ICONS["Diamond"]), "Diamond 货币图标装配")
	panel.free()


# 递归查 TextureRect/NinePatchRect by resource_path（NinePatchRect 直接继承 Control
# 而非 TextureRect，须并列检查；texture 属性两者同名）。
func _has_tex(node: Node, path: String) -> bool:
	if (node is TextureRect or node is NinePatchRect) and node.get("texture") != null:
		if String((node.get("texture") as Texture2D).resource_path) == path:
			return true
	for c in node.get_children():
		if _has_tex(c, path):
			return true
	return false


# P1（2026-07-16）：UI 文案 LSTR 化验证（ok label CLAIM + attach title 走 GameData.config）。
# 自造 mail（unread + attached）→ ok = CLAIM（源 content.lua:463）。
# 批 2：ok 按钮 TextureButton+子 Label → Button + theme variation（文字走 Button.text）。
# 2026-09-16 改自造数据（原依赖 GameData.player 默认 mail 1，真实存档邮箱可空致脆弱）。
func test_panel_ok_label_uses_lstr() -> void:
	var pd := _make_pd_with_mail(2, "unread", true)
	var panel := MailDetailPanel.new("mail_detail", {})
	panel.setup_panel(pd, 2, Callable())
	var cfg: ConfigManager = GameData.config
	var ok_btns: Array = panel.find_children("*", "Button", true, false)
	assert_eq(ok_btns.size(), 1, "1 个 ok 按钮（Button variation 承载文字）")
	assert_eq(String((ok_btns[0] as Button).text), cfg.get_lstr("MAILBOX.CLAIM"),
		"ok 文字 = LSTR MAILBOX.CLAIM（unread+attached）")
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
		"_diamonds": 200 if attached else 0,
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


# ══════════ 批 2 两件套守卫（2026-08-16，mail/content.lua 直译）══════════

# chrome 静态树（mail_detail_content.tscn）：frame/ok 坐标照源直译。
# frame mailbox_letter_bg(421x541px) 中心 ccp(400,240) → 显示 328.59x422.24 中心
# to_godot(400,240)=(480,320)；ok（readnode root=frame，原点=frame 左下角
# (235.71,28.88)）sell_number_button Scale9 cap(15,22,15,25) 165x45 中心
# frame 局部 (162,42) → frame 内 godot 中心 (162.00,380.14)。
func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var frame: TextureRect = inst.get_node("Frame") as TextureRect
	assert_almost_eq(frame.size.x, 328.59, 0.5, "Frame 宽 = 421px/CS")
	assert_almost_eq(frame.size.y, 422.24, 0.5, "Frame 高 = 541px/CS")
	assert_almost_eq(frame.position.x + frame.size.x * 0.5, 400.0, 0.5, "Frame 中心 x = 400+80")
	assert_almost_eq(frame.position.y + frame.size.y * 0.5, 240.0, 0.5, "Frame 中心 y = 560-240")
	var ok_btn: Button = frame.get_node("%OkBtn") as Button
	assert_almost_eq(ok_btn.size.x, 165.0, 0.5, "OkBtn 宽 = scaleSize 165")
	assert_almost_eq(ok_btn.size.y, 45.0, 0.5, "OkBtn 高 = scaleSize 45")
	assert_almost_eq(ok_btn.position.x + ok_btn.size.x * 0.5, 162.0, 0.5, "OkBtn 中心 x = 235.71+162+80-315.71")
	assert_almost_eq(ok_btn.position.y + ok_btn.size.y * 0.5, 380.14, 0.5, "OkBtn 中心 y = frame 内直译")
	# 旧 TextureButton+子 OkLabel 双层结构退役（Button.text 承载）
	assert_eq(frame.find_children("OkLabel", "Control", true, false).size(), 0,
		"OkLabel 退役（Button.text 承载文字）")


# title_bg/attach_bg 源均为 Scale9Sprite（content.lua:10-14 cap(10,10,217,6) +
# :226-228 cap(5,5,16,16)）→ NinePatchRect 化（批 2 公式：纹理像素直读，
# top=H-y-h/bottom=y/left=x/right=W-x-w）。
# equip_craft_money_bg(308x34) cap(10,10,217,6)：top=34-10-6=18 right=308-10-217=81；
# mailbox_letter_addon_bg(34x34) cap(5,5,16,16)：top=34-5-16=13 right=13。
func test_attach_bg_ninepatch_margins() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var title_bg: NinePatchRect = (inst.get_node("Frame") as Control).get_node("TitleBg") as NinePatchRect
	assert_not_null(title_bg, "TitleBg 是 NinePatchRect（源 Scale9 cap(10,10,217,6)）")
	assert_almost_eq(title_bg.patch_margin_left, 8.0, 0.5, "TitleBg left = cap x ÷CS 取整")
	assert_almost_eq(title_bg.patch_margin_top, 14.0, 0.5, "TitleBg top = 18px ÷CS 取整")
	assert_almost_eq(title_bg.patch_margin_right, 63.0, 0.5, "TitleBg right = 81px ÷CS 取整")
	assert_almost_eq(title_bg.patch_margin_bottom, 8.0, 0.5, "TitleBg bottom = cap y ÷CS 取整")
	var attach_bg: NinePatchRect = ((inst.get_node("Frame") as Control).get_node("%AttachHost") as Control).get_node("AttachBg") as NinePatchRect
	assert_not_null(attach_bg, "AttachBg 是 NinePatchRect（源 Scale9 cap(5,5,16,16)）")
	assert_almost_eq(attach_bg.patch_margin_left, 4.0, 0.5, "AttachBg left = cap x ÷CS 取整")
	assert_almost_eq(attach_bg.patch_margin_top, 10.0, 0.5, "AttachBg top = 13px ÷CS 取整")
	assert_almost_eq(attach_bg.patch_margin_right, 10.0, 0.5, "AttachBg right = 13px ÷CS 取整")
	assert_almost_eq(attach_bg.patch_margin_bottom, 4.0, 0.5, "AttachBg bottom = cap y ÷CS 取整")
	assert_almost_eq(attach_bg.size.x, 300.0, 0.5, "AttachBg 宽 = 源 setContentSize 300")
	assert_false(attach_bg.visible, "AttachBg 默认隐藏（有附件 fill 显示）")


# 货币附件行模板（mail_currency_item.tscn，源 createCommonAttach :162-214）：
# icon fix_height=25（readnode:201-204 等比缩放，非强拉）+ amount right2 icon+20。
func test_currency_item_template_static_tree() -> void:
	var inst: Control = (load(CURRENCY_ITEM_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var icon: TextureRect = inst.get_node("%Icon") as TextureRect
	assert_almost_eq(icon.position.x, 40.0, 0.5, "Icon x = 40（anchor(0,1) at (40,y)）")
	assert_almost_eq(icon.size.y, 25.0, 0.5, "Icon 高 = fix_height 25")
	var amount: Label = inst.get_node("%Amount") as Label
	assert_almost_eq(amount.position.x, 85.0, 0.5, "Amount x = 40+25+20（right2 offset=20）")
	assert_almost_eq(inst.size.y, 30.0, 0.5, "行高 30（源逐行 y-30）")


# panel 零静态构造（宽口径白名单）：货币行走 mail_currency_item.tscn 模板 +
# TitleBg/AttachBg/AttachTitle 静态化，仅弹窗工厂 2 处 .new（溢满 + 领取奖励展示）。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count("MailOverfullPopup.new("), 1, "仅 1 处溢满弹窗工厂 MailOverfullPopup.new(")
	assert_eq(text.count("MailClaimRewardsPopup.new("), 1, "仅 1 处奖励展示弹窗工厂 MailClaimRewardsPopup.new(")
	assert_eq(text.count(".new("), 2, "宽口径 .new( 总数 = 白名单之和")


# theme variation 接线（读 tres 文本表项）。
# 源字号/色：title size18 ccc3(172,75,30)（:23-35）；body/from size16 ccc3(162,88,41)；
# attach_title size18 ccc3(152,98,34)；amount size18 ccc3(129,61,22)；
# ok_label fontinfo ui_normal_button 17 号 + config 色 ccc3(236,222,209)。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("MailDetailTitleLabel/font_sizes/font_size = 18"), "title 字号 18")
	assert_true(t.contains("MailDetailTitleLabel/colors/font_color = Color(0.67451, 0.294118, 0.117647, 1)"),
		"title 色 = ccc3(172,75,30)")
	assert_true(t.contains("MailDetailTextLabel/font_sizes/font_size = 16"), "body/from 字号 16")
	assert_true(t.contains("MailDetailTextLabel/colors/font_color = Color(0.635294, 0.345098, 0.160784, 1)"),
		"body/from 色 = ccc3(162,88,41)")
	assert_true(t.contains("MailAttachTitleLabel/colors/font_color = Color(0.596078, 0.384314, 0.133333, 1)"),
		"attach_title 色 = ccc3(152,98,34)")
	assert_true(t.contains("MailAttachAmountLabel/colors/font_color = Color(0.505882, 0.239216, 0.086275, 1)"),
		"amount 色 = ccc3(129,61,22)")
	assert_true(t.contains("MailDetailOkBtn/styles/normal = SubResource(\"SB_pkg_hb_n\")"),
		"ok 按钮三态复用 SB_pkg_hb（同图同 cap(15,22,15,25)）")
	assert_true(t.contains("MailDetailOkBtn/font_sizes/font_size = 17"), "ok 字号 17（ui_normal_button）")


# ── 物品 icon 点击领取（2026-09-16 用户反馈「点附件物品图标没反应」）──
# 源 content.lua createItemAttach 的 icon 无点击绑定（唯一领取路径=ok 按钮）；
# Godot 原生适配阶段按用户期望增强：点物品 icon 走 _on_ok 同一三分支领取流程。

func _make_pd_with_item_mail(mail_id: int) -> PlayerData:
	var pd := PlayerData.new(GameData.config)
	var md := MailData.new()
	md._raw_mails = [{
		"_id": mail_id,
		"_status": "unread",
		"_date": "2026-09-16",
		"_content": {"_plain_mail": {"_from": "系统", "_title": "道具", "_content": "内容"}},
		"_money": 100,
		"_diamonds": 0,
		"_skill_point": 0,
		"_items": [{"id": 101, "amount": 2}],
	}]
	pd.mailbox = md
	return pd


# 点物品 icon（gui_input 左键 release）→ 触发 _on_ok 领取：邮件 erase + 回调关闭 + 物品到账。
func test_item_icon_click_triggers_claim() -> void:
	var pd := _make_pd_with_item_mail(300)
	var panel := MailDetailPanel.new("mail_detail", {})
	add_child(panel)
	var closed := [false]
	panel.setup_panel(pd, 300, Callable(func() -> void: closed[0] = true))
	var icon: Control = panel._attach_host.get_child(panel._attach_host.get_child_count() - 1)   # 物品 icon 最后挂（货币行之后）
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	icon.gui_input.emit(ev)
	assert_eq(pd.mailbox.get_mail(300), {}, "点物品 icon 后邮件被领取移除（claim_attach erase）")
	assert_eq(int(pd.items.get(101, 0)), 2, "物品 101×2 到账")
	assert_true(closed[0], "领取后面板关闭（_on_closed 回调）")
	# 领取同时弹出的奖励展示窗（PopWindow 系）挂测试父节点，显式清理防污染后续用例
	# （is 过滤脚本类，find_children type 参数不识别 class_name——Godot 4 ClassDB 无脚本类；
	# is_instance_valid 前置防 queue_free 帧末窗口内已删实例参与 is 判定）。
	for c in panel.get_parent().find_children("*", "Control", true, false):
		if is_instance_valid(c) and c is MailClaimRewardsPopup:
			c.free()
	panel.free()


# icon 可命中（mouse_filter 非 IGNORE，点击不穿透）+ 桌面手型光标。
func test_item_icon_clickable_shape() -> void:
	var pd := _make_pd_with_item_mail(301)
	var panel := MailDetailPanel.new("mail_detail", {})
	add_child(panel)
	panel.setup_panel(pd, 301, Callable())
	var icon: Control = panel._attach_host.get_child(panel._attach_host.get_child_count() - 1)
	assert_ne(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE, "物品 icon 可命中（非 IGNORE）")
	assert_eq(icon.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "物品 icon 手型光标")
	# 基准 scale 不被 press 反馈破坏：ICON_SCALE 保持
	assert_almost_eq(icon.scale.x, 60.0 / (94.0 / 1.28125), 0.0001, "基准 scale 保持")
	panel.free()


# ── 领取奖励展示（2026-09-16 二轮，用户验收反馈「少了领取效果」）──
# 源 doReadMail 领取后 destroy({skipAnim=true}) 无任何展示（源本无领取效果）；
# 受控增强：领取后弹 MailClaimRewardsPopup（货币行+物品 icon），点击任意处关闭。

# 领取（_on_ok 未读+附件分支）后弹出奖励展示：货币行数=attach_common、物品 icon 数=items。
func test_claim_shows_rewards_popup() -> void:
	var pd := _make_pd_with_item_mail(400)
	var panel := MailDetailPanel.new("mail_detail", {})
	add_child(panel)
	panel.setup_panel(pd, 400, Callable())
	panel._on_ok()
	assert_eq(pd.mailbox.get_mail(400), {}, "领取发生（邮件 erase）")
	var popups: Array = []
	for c in panel.get_parent().find_children("*", "Control", true, false):
		if c is MailClaimRewardsPopup:
			popups.append(c)
	assert_eq(popups.size(), 1, "领取后弹 1 个奖励展示弹窗")
	if popups.is_empty():
		panel.free()
		return
	var popup: Control = popups[0] as Control
	# mail 400：money 100 → 1 货币行；items 1 个 → 1 物品 icon
	var rows: Array = (popup.container.get_node("MailClaimRewardsContent/%Host") as Control).get_children()
	assert_eq(rows.size(), 1 + 1, "Host 子节点 = 货币行 1 + 物品 icon 1")
	assert_eq(int(pd.items.get(101, 0)), 2, "物品照常到账（展示不阻塞领取）")
	popup.free()
	panel.free()


# 奖励展示 CloseBtn 关闭（PopWindow remove_window → queue_free）。
func test_rewards_popup_click_closes() -> void:
	var popup := MailClaimRewardsPopup.new("mail_claim_rewards", {})
	popup.setup_panel([{"type": "Gold", "amount": 5}], [], GameData.config)
	add_child(popup)
	assert_false(popup.is_queued_for_deletion(), "弹窗初始存活")
	(popup.container.get_node("MailClaimRewardsContent/%CloseBtn") as BaseButton).pressed.emit()
	assert_true(popup.is_queued_for_deletion(), "点关闭后弹窗销毁（remove_window）")


# 奖励内容落框内 + chrome 与 SweepRewardPopup 同款（六轮样式统一守卫：main_vit_tips
# 框/task_title_bg 标题带/关闭钮；旧自建 common_alert_bg 小框系「变形」反馈源头）。
func test_rewards_content_inside_frame() -> void:
	var popup := MailClaimRewardsPopup.new("mail_claim_rewards", {})
	popup.setup_panel([{"type": "Gold", "amount": 5}], [{"id": 101, "amount": 1}], GameData.config)
	add_child(popup)
	var content: Control = popup.container.get_node("MailClaimRewardsContent")
	var frame: Control = content.get_node("FrameBg")
	var host: Control = content.get_node("%Host")
	assert_gt(host.global_position.y, frame.global_position.y, "Host 起于框内（上缘内）")
	assert_lt(host.global_position.y + host.size.y, frame.global_position.y + frame.size.y + 0.5,
		"Host 止于框内（下缘内）")
	var frame_tex: Texture2D = (frame as NinePatchRect).texture
	assert_eq(frame_tex.resource_path, "res://assets/ui/alpha/HVGA/main_vit_tips.png",
		"框贴图 = sweep 同款 main_vit_tips")
	var title_bg: TextureRect = content.get_node("TitleBg") as TextureRect
	assert_eq((title_bg.texture as Texture2D).resource_path, "res://assets/ui/alpha/HVGA/task_title_bg.png",
		"标题带 = sweep 同款 task_title_bg")
	# root 全屏守卫（PopWindow.setup 离树时 set_anchors_preset → offsets 归零，anchors=1）
	assert_eq(popup.anchor_right, 1.0, "root 右锚 1")
	assert_almost_eq(popup.offset_right, 0.0, 0.5, "root 右 offset 归零")
	popup.free()


# 物品附件 icon 定位/缩放（task-11 守卫）：源 content.lua:137-151 getpos icon 中心
# (34+65col+32.5, y-65row-32.5) frame 局部 y-up + createIconWithAmount(id,60) 显示 60 点。
# ReadequipIcon frame Sprite2D 按纹理原尺寸渲染（94×95px）→ scale 基准 94（曾 60/72 致
# 视觉 78×79 溢出 65 步进互相叠、偏左上 2.5px——验收"icon 不在图标框里"）。
func test_item_attach_icon_scale_position() -> void:
	var panel := MailDetailPanel.new("mail_detail", {})
	panel.pd = GameData.player
	var host := Control.new()
	add_child_autofree(host)
	panel._attach_host = host
	panel._add_item_attach(248.24, [{"id": 101, "amount": 2}, {"id": 101, "amount": 2}])
	assert_eq(host.get_child_count(), 2, "2 个物品 icon")
	var icon0: Control = host.get_child(0)
	assert_almost_eq(icon0.scale.x, 60.0 / (94.0 / 1.28125), 0.0001, "icon scale=60/(94/CS)（视觉宽 60；2026-08-22 双重÷CS修）")
	var vis_h: float = 95.0 / 1.28125 * (60.0 / (94.0 / 1.28125))   # 产物显示 95/CS × scale = 60.64
	assert_almost_eq(icon0.position.x + 30.0, 66.5, 0.1, "首列视觉中心 x=66.5（源 ox+icon_len/2）")
	assert_almost_eq(icon0.position.y + vis_h * 0.5, 280.74, 0.1, "首行视觉中心 y=248.24+32.5（源 getpos）")
	var icon1: Control = host.get_child(1)
	assert_almost_eq(icon1.position.x, 36.5 + 65.0, 0.1, "第 2 列左 = 66.5+65-30（源 dx=icon_len=65）")
	assert_almost_eq(icon1.position.y, icon0.position.y, 0.01, "同行 y 相同")
	panel.free()


# ── 领取链立即存盘守卫（2026-09-17 同召唤判例 fix/summon-save-persist）──
# 修复前 _claim_and_close 只 mark_save_dirty：60s 自动存盘窗口内杀进程读档回滚
# （资产回退 + 邮件未读回来 = 可重复领取刷钻洞；竞技场每日排名奖励链真机三段式
# 实测复现：领取 +550 钻/+10000 金 → 杀进程 → diamond/gold 回退、邮件 9001 回列表）。
# 附件入账=资产变更链，判例要求 View 层成功分支显式 GameData.save()（立即落盘）。
func test_claim_persists_via_explicit_save() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	var claim_idx: int = text.find("claim_attach(")
	var save_idx: int = text.find("GameData.save()")
	assert_gt(claim_idx, -1, "claim_attach 调用存在")
	assert_gt(save_idx, claim_idx, "claim_attach 之后有显式 GameData.save()（领取即落盘）")
	assert_eq(text.count("mark_save_dirty"), 0, "面板内不再用 mark_save_dirty（防标脏回退）")
