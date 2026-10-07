extends GutTest
# BattleRewardPopup 战斗结算奖励弹窗测试（照源 crusade.lua showRewardResult :344-394 +
# crusadeconfig.lua rewardLayer :1201-1306）。
# 2026-10-06 修复回归守卫（验收记录-远征宝箱弹窗缺失-2026-10-06）：旧实现仅遮罩+裸 Label+X 钮
# 致用户观感"没有奖励弹窗"；新实现照源补 bg/标题/确定钮 + ChestBox/CrusadePoint 折算远征币。

const CS: float = 1.28125

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_popup(root: Node, rewards: Array) -> BattleRewardPopup:
	var popup := BattleRewardPopup.new("crusadeReward", {})
	popup.setup_rewards(rewards, cm)
	popup.show_window(root)
	return popup


# 照源 rewardLayer 结构：getitem_bg Scale9 底板 + 标题横幅 + 标题文字 + 确定钮（任意点关闭
# 走 shade）；tscn 旧 CloseBtn 隐藏（源无 X 钮）。
func test_popup_visual_layer_assembled() -> void:
	var root := Node.new()
	add_child(root)
	var popup := _make_popup(root, [{"type": "gold", "amount": 500}])
	var bg: NinePatchRect = popup._content.get_node_or_null("RewardBg") as NinePatchRect
	assert_not_null(bg, "RewardBg Scale9 底板（源 rewardBg common_getitem_bg）")
	if bg != null:
		# 2026-10-06 二轮修正：scaleSize 系 cocos 点空间直用（RuleFrame 550×360 先例），
		# 旧 ÷CS 版 312×171.7 致上下边框区 123+66=189 互叠 → 倒角变形（用户实机反馈）。
		assert_almost_eq(bg.size.x, 400.0, 0.5, "bg 宽 =源 scaleSize 400 点（Scale9 点空间不÷CS）")
		assert_almost_eq(bg.size.y, 220.0, 0.5, "bg 高 =源 scaleSize 220 点")
		assert_almost_eq(bg.position.x + bg.size.x * 0.5, 400.0, 0.5, "bg 中心 x=400（水平居中）")
		# 六轮守卫：整窗垂直居中（源偏上设计 y210 经用户指示下移 30 至 240）。
		assert_almost_eq(bg.position.y + bg.size.y * 0.5, 240.0, 0.5, "bg 中心 y=240（垂直居中，屏幕 480 中点）")
		# 守卫：NinePatchRect margin 同时定义纹理裁剪与控件边距，边框区总和超控件尺寸即绘制互叠。
		assert_lt(bg.patch_margin_top + bg.patch_margin_bottom, bg.size.y, "上下边框区不超出控件高（倒角变形根因守卫）")
		assert_lt(bg.patch_margin_left + bg.patch_margin_right, bg.size.x, "左右边框区不超出控件宽")
		# 2026-10-06 三轮守卫：奖励行宿主与 bg 的树序（后 add 画上面）——bg 须在最底层，
		# 否则奖励行被底板盖住（用户实机报「奖励显示在弹窗层下面」）。
		assert_lt(bg.get_index(), popup._reward_host.get_index(), "RewardBg 树序在 RewardHost 之前（源 rewardBg 最底层）")
	# 七轮：横幅贴图左右不对称退役（PIL 实证源贴图左 336px vs 右 223px 花纹），只留文字标题。
	assert_null(popup._content.get_node_or_null("TitleBanner"), "TitleBanner 横幅退役（源贴图左右不对称）")
	var title: Label = popup._content.get_node_or_null("TitleLabel") as Label
	assert_not_null(title, "TitleLabel 标题文字")
	if title != null:
		assert_eq(title.text, "你获得了以下奖励", "标题文案（源 CRUSADECONFIG.REWARDS_RECEIVED）")
	var buttons: Array = []
	for c in popup._content.get_children():
		if c is Button:
			buttons.append(c)
	assert_eq(buttons.size(), 1, "唯一确认钮（源 conform tavern_button + CHATCONFIG.CONFIRM）")
	var confirm := buttons[0] as Button
	if confirm.get_child_count() > 0:
		assert_eq((confirm.get_child(0) as Label).text, "确定", "确认钮文字")
	var close_btn: BaseButton = popup._content.get_node("%CloseBtn") as BaseButton
	assert_false(close_btn.visible, "旧 X 关闭钮隐藏（源 rewardLayer 无 X，点任意处关闭）")
	popup.remove_window()
	root.queue_free()


# 折算口径照源 local_server getCrusadeReward：crusadepoint=amount×10、chestbox=coins×10
# （coinMap{1:50,2:100,3:200,4:100,5:200,6:400} 默认 50），与 apply_rewards 入账一致；
# diamond 为通关奖励受控增强槽（五轮改版入弹窗展示）。
func test_currency_pair_conversion() -> void:
	var popup := BattleRewardPopup.new("crusadeReward", {})
	var pair_gold: Dictionary = popup._currency_pair("gold", 500, 0)
	assert_eq(pair_gold["text"], "500", "gold 直显数量（源 <text|normal_button|N>）")
	var pair_cp: Dictionary = popup._currency_pair("CrusadePoint", 200, 0)
	assert_eq(pair_cp["text"], "x2000", "CrusadePoint ×10（源 param1=amount*10）")
	var pair_box4: Dictionary = popup._currency_pair("ChestBox", 1, 4)
	assert_eq(pair_box4["text"], "x1000", "ChestBox id4 → 100×10 远征币（源 coinMap[4]=100）")
	var pair_box7: Dictionary = popup._currency_pair("ChestBox", 1, 99)
	assert_eq(pair_box7["text"], "x500", "ChestBox 未知 id → 默认 50×10")
	var pair_diamond: Dictionary = popup._currency_pair("diamond", 30, 0)
	assert_eq(pair_diamond["text"], "x30", "diamond 直显数量（通关奖励入弹窗展示）")
	assert_true(String(pair_diamond["res"]).ends_with("rmbicon.png"), "diamond 用钻石图标")
	popup.queue_free()


# 奖励行：单 HBox 居中流式排（源 RichText 单行），不再网格。
func test_setup_rewards_mixed_single_row() -> void:
	var root := Node.new()
	add_child(root)
	var popup := _make_popup(root, [
		{"type": "gold", "amount": 500},
		{"type": "CrusadePoint", "amount": 200},
		{"type": "ChestBox", "id": 4, "amount": 1},
	])
	var row: HBoxContainer = popup._reward_host.get_child(0) as HBoxContainer
	assert_not_null(row, "奖励挂 RewardRow（HBox 居中流式，源 RichText）")
	if row != null:
		# gold/crusadepoint/chestbox 各 = 图标 + 文字 2 节点，共 6。
		assert_eq(row.get_child_count(), 6, "3 货币奖励 ×（图标+文字）=6 子")
		var texts: Array = []
		for c in row.get_children():
			if c is Label:
				texts.append((c as Label).text)
		assert_has(texts, "500", "gold 行文字")
		assert_has(texts, "x2000", "远征币 ×10 文字")
		assert_has(texts, "x1000", "ChestBox 折算文字")
		# 七轮守卫：行中心 = bg 正中（用户指示「奖励在背景框居中位置」）。
		assert_almost_eq(row.position.y + row.size.y * 0.5, 240.0, 0.5, "奖励行中心 y=240（bg 正中）")
	popup.remove_window()
	root.queue_free()


# 源 layerColor ccc4(0,0,0,190)：遮罩比 PopWindow 默认 150 深。
func test_shade_alpha_sourced() -> void:
	var root := Node.new()
	add_child(root)
	var popup := _make_popup(root, [])
	assert_almost_eq(popup.shade_layer.color.a, 190.0 / 255.0, 0.01, "遮罩 α=190/255（源 layerColor）")
	popup.remove_window()
	root.queue_free()
