extends GutTest

## ShopRefreshConfirm 单测 — 照源 shop.lua:302-313 doClickRefresh showConfirmDialog。
## GDScript lambda 捕获局部变量 by value，用数组 [bool] 引用语义跨 lambda 传递。


func test_set_message_updates_label() -> void:
	var popup := ShopRefreshConfirm.new()
	add_child(popup)
	popup.set_message("花费 50 钻石刷新？")
	assert_eq(popup._msg_label.text, "花费 50 钻石刷新？", "set_message 更新 Label 文本")
	popup.queue_free()


func test_ok_emits_confirmed() -> void:
	var popup := ShopRefreshConfirm.new()
	add_child(popup)
	var emitted := [false]
	popup.confirmed.connect(func() -> void: emitted[0] = true)
	popup._on_ok()
	assert_true(emitted[0], "_on_ok emit confirmed（源 :309 rightHandler）")
	popup.queue_free()


func test_cancel_does_not_emit() -> void:
	var popup := ShopRefreshConfirm.new()
	add_child(popup)
	var emitted := [false]
	popup.confirmed.connect(func() -> void: emitted[0] = true)
	# 重构后子场景 content 挂 panel（child 0）；%CancelBtn unique_name 在 content 子场景内。
	var content: Node = popup.get_child(0)
	var cancel: Button = content.get_node("%CancelBtn")
	cancel.pressed.emit()
	assert_false(emitted[0], "取消不 emit confirmed")
	popup.queue_free()


# ── 2026-09-10 召唤确认框按钮变形根修守卫（照源 dialog.lua :273-296 直译重建 content）──

func test_content_buttons_source_size_120x49() -> void:
	var popup := ShopRefreshConfirm.new()
	add_child(popup)
	# 2026-09-10 二轮：min size 撑高是 deferred（挂树瞬间 size=offset 差，一帧后才被
	# minimum size 抬高）——必须 await 帧后断言才是真实渲染尺寸（首版未 await 故
	# 实机 66px 偏高漏检，GUT 假绿）。
	await get_tree().process_frame
	await get_tree().process_frame
	var content: Control = popup.get_child(0) as Control
	var bg := content.get_node("Bg") as Control
	var cancel := bg.get_node("%CancelBtn") as Button
	var ok := bg.get_node("%OkBtn") as Button
	# 探针：min size 构成（texture_margin 之和 + 字高 vs 实际）
	var sb: StyleBox = cancel.get_theme_stylebox("normal")
	print("[probe] min=", cancel.get_minimum_size(), " size=", cancel.size,
		" sb_min=", sb.get_minimum_size(),
		" font_h=", cancel.get_theme_font("font").get_height(cancel.get_theme_font_size("font_size")))
	assert_eq(cancel.size, Vector2(120, 49), "取消按钮 120x49（源 :274 setContentSize 直译；await 后真实尺寸）")
	assert_eq(ok.size, Vector2(120, 49), "确认按钮 120x49（源 :294 setContentSize 直译；await 后真实尺寸）")
	popup.queue_free()


func test_content_bg_source_size_and_line() -> void:
	var popup := ShopRefreshConfirm.new()
	add_child(popup)
	var content: Control = popup.get_child(0) as Control
	var bg := content.get_node("Bg") as TextureRect
	assert_almost_eq(bg.size.x, 348.88, 0.5, "bg 宽=447px÷CS=348.88 点（源 :40 dialog_bg）")
	assert_almost_eq(bg.size.y, 220.88, 0.5, "bg 高=283px÷CS=220.88 点")
	assert_ne(bg.get_node_or_null("Line"), null, "line 分隔线存在（源 :48-51 dialog_line）")
	popup.queue_free()


func test_content_scene_uses_dialog_confirm_btn_variation() -> void:
	var f := FileAccess.open("res://scenes/ui/shop_refresh_confirm_content.tscn", FileAccess.READ)
	var t := f.get_as_text()
	f.close()
	assert_true(t.count('theme_type_variation = &"DialogConfirmBtn"') == 2,
		"双按钮走 DialogConfirmBtn（cap right=37 源 dialog 口径，2026-09-10 根修）")
	assert_false(t.contains("ShopConfirmBtn"), "弃 ShopConfirmBtn（cap 误用 equip 口径 right=24 旧根因）")
	assert_true(t.contains("dialog_bg.png"), "框体贴图 dialog_bg（源 :40）")
	assert_true(t.contains("dialog_line.png"), "分隔线贴图 dialog_line（源 :48）")


func test_confirm_button_text_follows_source_default() -> void:
	var popup := ShopRefreshConfirm.new()
	add_child(popup)
	var content: Control = popup.get_child(0) as Control
	var ok := content.get_node("Bg/%OkBtn") as Button
	assert_eq(ok.text, "好的",
		"右按钮默认文案 FASTSELL.GOOD（源 :304-310 rightText 默认，调用方未传）")
	popup.queue_free()


# 2026-09-10 二轮全族守卫：herodetail-upgrade 系 8 个 SB 全部换烘焙成品图且 margin=0。
# 根因=实机（真 GPU）StyleBoxTexture.get_minimum_size()=texture_margin 之和计入 Button
# min → margin(57,38)+字高(28)=min(97,66) 把源 49/45 高按钮撑到 66+（四处确认框/equip
# 强化/选英雄/碎片合成全族）；headless sb_min=(8,8) 环境差异致尺寸断言假绿（挂树瞬间
# 49 一帧后才被撑），故守卫锁 theme 静态构成（margin 禁回潮+烘焙图引用），实机行为
# 靠 bridge 探针复验。
# 2026-09-11 四轮扩：herodetail-detail 系 7 个 SB 同机制烘焙（英雄详情 tab 120x49/
# 进阶觉醒 100x42/宝石返回 200x49 三档；旧 top=33/bottom=15 批 1 翻转误写截底帽 18px
# =用户所见"下半部分截变形"），全族 15 张。
func test_upgrade_family_styles_baked_no_margin() -> void:
	var f := FileAccess.open("res://resources/themes/default_theme.tres", FileAccess.READ)
	var t := f.get_as_text()
	f.close()
	# SB 块只引用 ExtResource id（路径在头部 ext_resource 区），故断 id 映射 + 全局计数
	var baked_ids: Dictionary = {
		"SB_dialog_confirm_n": "21_bkconfn", "SB_dialog_confirm_p": "22_bkconfp",
		"SB_upgrade_n": "23_bkstrn", "SB_upgrade_p": "24_bkstrp",
		"SB_equip_select_n": "25_bkseln", "SB_equip_select_p": "26_bkselp",
		"SB_fc_ok_n": "27_bkfcn", "SB_fc_ok_p": "28_bkfcp",
		"SB_detail_n": "29_dtabn", "SB_detail_a": "30_dtaba", "SB_detail_p": "31_dtabp",
		"SB_detail_rank_n": "32_drkn", "SB_detail_rank_p": "33_drkp",
		"SB_detail_stone_ok_n": "34_dson", "SB_detail_stone_ok_p": "35_dsop",
	}
	for sb: String in baked_ids.keys():
		var i: int = t.find("id=\"%s\"" % sb)
		assert_gt(i, 0, "%s sub_resource 存在" % sb)
		var blk: String = t.substr(i, 200)
		assert_false(blk.contains("texture_margin"),
			"%s 无 texture_margin（margin 计入实机 Button min size 致按钮撑高，禁回潮）" % sb)
		assert_true(blk.contains('texture = ExtResource("%s")' % baked_ids[sb]),
			"%s 引用烘焙成品图 %s" % [sb, baked_ids[sb]])
	assert_eq(t.count('path="res://assets/ui/baked/'), 15,
		"烘焙图 ext_resource 15 张全量声明（upgrade 系 8 + detail 系 7，assets/ui/baked/）")
	assert_false(t.contains('path="res://assets/ui/alpha/HVGA/herodetail-detail-'),
		"旧 herodetail-detail 原图 ext_resource 声明已删（换烘焙图后无引用，防孤儿行回潮）")
