extends GutTest
# SweepRewardPopup 扫荡战利品弹窗测试（照源 stagedetail.lua repeatRewardWindow
# :1946-2521，2026-09-04 补全原单机化 Toast 简化）。skip_anim 分支同步完成，
# 动画分支时序不进 GUT（时值常量照源直译，实机目验）。


const CONTENT_PATH: String = "res://scenes/ui/sweep_reward_popup_content.tscn"

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_popup(loot_list: Array) -> SweepRewardPopup:
	var root := Node.new()
	add_child(root)
	var popup := SweepRewardPopup.new("sweepReward", {})
	popup.setup_popup(loot_list, cm, true)
	popup.show_window(root)
	return popup


func _label_texts(popup: SweepRewardPopup) -> PackedStringArray:
	var texts: PackedStringArray = []
	for c in popup._list_layer.get_children():
		if c is Label:
			texts.append((c as Label).text)
	return texts


# tscn 骨架守卫（源 create:2460-2521 直译：FrameBg 九宫格/标题/close 初始隐藏）。
func test_content_scene_static_nodes() -> void:
	var content: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child(content)
	assert_not_null(content.get_node_or_null("%FrameBg"), "FrameBg 节点存在")
	assert_not_null(content.get_node_or_null("%TitleBg"), "TitleBg 节点存在")
	assert_not_null(content.get_node_or_null("%TitleLabel"), "TitleLabel 节点存在")
	assert_not_null(content.get_node_or_null("%ScrollHost"), "ScrollHost 节点存在")
	var close_btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	assert_not_null(close_btn, "CloseBtn 节点存在")
	assert_false(close_btn.visible, "CloseBtn 初始隐藏（源动画完才显示）")
	var frame: NinePatchRect = content.get_node("%FrameBg") as NinePatchRect
	assert_eq(frame.patch_margin_left, 15, "九宫格 left=15（源 cap(15,20,45,15)）")
	assert_eq(frame.patch_margin_top, 20, "九宫格 top=20")
	assert_almost_eq(frame.offset_left, 185.0, 0.01, "FrameBg 左=185（scaleSize 430 中心 400）")
	assert_almost_eq(frame.offset_top, 82.5, 0.01, "FrameBg 顶=82.5（中心 275−192.5）")
	var scroll: ScrollContainer = content.get_node("%ScrollHost") as ScrollContainer
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "横向滚动禁用（源 draglist 仅纵向）")
	content.queue_free()


# skip_anim 全显：组标题/空掉落文案/close 可用（源 skipLootAnim 分支语义）。
func test_popup_skip_anim_groups_and_texts() -> void:
	var loot_list: Array = [
		{"exp": 12, "money": 34, "loots": [{"id": 390, "amount": 2}]},
		{"exp": 12, "money": 34, "loots": []},
		{"loots": [{"id": 1001, "amount": 3}]},
	]
	var popup := _make_popup(loot_list)
	assert_true(popup._anim_done, "skip 分支动画即时完成")
	assert_true(popup._close_btn.visible, "skip 分支 close 即时可见")
	var texts: PackedStringArray = _label_texts(popup)
	assert_true("第1战" in texts, "普通组标题「第1战」（源 THE__D_BATTLE）")
	assert_true("第2战" in texts, "普通组标题「第2战」")
	assert_true("额外奖励" in texts, "末组标题「额外奖励」（源 EXTRA_BONUS）")
	assert_true("此次扫荡未获得物品" in texts, "空掉落组文案（源 NO_ITEM_DROPPED_IN_THIS_RAID）")
	assert_true("12" in texts, "exp 值显示")
	assert_true(":    34" in texts, "金币行照源「:    %d」格式")
	assert_eq(popup._groups.size(), 3, "3 组构建")
	# 组内节点全可见（skip 全显语义）
	for g in popup._groups:
		for n in g.get("header", []) as Array:
			assert_true((n as Control).visible, "header 节点可见")
		for n in g.get("reveal", []) as Array:
			assert_true((n as Control).visible, "reveal 节点可见")
	popup.remove_window()


# 端到端：StageManager.sweep waves → loot_list 组装（panel _show_sweep_reward 同构）→ 弹窗构建。
func test_sweep_result_wiring() -> void:
	var mgr := StageManager.new(cm)
	mgr.exit_stage(-27, 3, true)
	var rng := BattleRng.new(999)
	var r: Dictionary = mgr.sweep(-27, 2, rng)
	var loot_list: Array = []
	for w in (r.get("waves", []) as Array):
		loot_list.append(w)
	loot_list.append({"loots": r.get("raid_bonus", [])})
	assert_eq(loot_list.size(), 3, "2 战 + 末组额外奖励")
	var popup := _make_popup(loot_list)
	assert_eq(popup._groups.size(), 3, "弹窗 3 组构建（含额外奖励末组）")
	var texts: PackedStringArray = _label_texts(popup)
	assert_true("额外奖励" in texts, "末组额外奖励标题")
	popup.remove_window()


# 标题 LSTR fill + 光效节点（源尾标 light；raid_title 双端缺受控裁剪）。
func test_popup_title_and_end_light() -> void:
	var popup := _make_popup([{"exp": 1, "money": 2, "loots": []}, {"loots": []}])
	assert_eq(popup._title_label.text, "扫荡", "标题 LSTR PRIVILEGE.FARM")
	assert_not_null(popup._end_light, "尾标光效节点存在（lettherebelight）")
	assert_true(popup._end_light.visible, "skip 分支光效可见")
	popup.remove_window()


# 列表内容以滚动区水平居中（坐标系三坑①回归守卫）：源 draglist listLayer 挂全屏原点，
# 内容 x 是全屏场景坐标（400=cliprect 中心、图标列 250..550）；漏换算时内容以 ScrollHost
# 局部坐标使用全屏值，整体右偏一个 host 原点 x=200（2026-09-05 用户反馈"内容没有居中"）。
# 断言用局部坐标（GUT 视口非 800 宽，global 链有环境缩放差）。
func test_list_content_centered_in_host() -> void:
	var loots: Array = []
	for i in range(6):   # 6 物品跨 2 行×5 列，覆盖第 1/5 列边界
		loots.append({"id": 390, "amount": 1})
	var popup := _make_popup([{"exp": 12, "money": 34, "loots": loots}, {"loots": []}])
	var host: ScrollContainer = popup._content.get_node("%ScrollHost") as ScrollContainer
	# 列表层负向平移抵消 host 原点（ScrollContainer 重排直接子层，故平移在内层，见实现注释）
	assert_almost_eq(popup._list_layer.position.x, -host.offset_left, 0.01,
		"列表层负向平移 = host 原点 x（源坐标换算）")
	# 滚动区中心恰在源场景坐标 400（tscn offset 声明值守卫；GUT headless 视口会使
	# 运行时 size 有环境膨胀，offset 恒定，真机 EXACT_FIT 下 rect 即 offset 值）
	assert_almost_eq(host.offset_left + (host.offset_right - host.offset_left) * 0.5, 400.0, 0.01,
		"滚动区中心=源场景 x400")
	# 组标题条中心 = 源场景 400 = 滚动区中心（源 subtitle ccp(400)）
	var sub: TextureRect = popup._groups[0]["header"][0] as TextureRect
	assert_almost_eq(sub.position.x + sub.size.x * 0.5, 400.0, 0.5,
		"组标题条中心=源场景 x400")
	# 贴图显示尺寸 ÷CS 生效（TextureRect 默认 EXPAND_KEEP_SIZE 会以纹理原始像素顶开 Control）
	assert_almost_eq(sub.size.y, 44.0 / 1.28125, 0.5, "subtitle bg 高=44px÷CS=34.34")
	var item_bg: TextureRect = popup._groups[0]["reveal"][0] as TextureRect
	assert_almost_eq(item_bg.size.y, 98.0 / 1.28125, 0.5, "物品行底板高=98px÷CS=76.49")
	# 图标列照源：第 1 列 250、第 5 列 550，均落在滚动区显示范围 [offset_left, +width]
	var reveal: Array = popup._groups[0]["reveal"]
	var icon1: Control = reveal[2] as Control   # reveal = [bg×2, icon×6]
	var icon5: Control = reveal[6] as Control
	assert_almost_eq(icon1.position.x + icon1.size.x * 0.5, 250.0, 0.5,
		"第 1 列图标中心=源 250+75*0")
	assert_almost_eq(icon5.position.x + icon5.size.x * 0.5, 550.0, 0.5,
		"第 5 列图标中心=源 250+75*4")
	assert_true(popup._list_layer.position.x + 550.0 <= host.size.x,
		"最右图标（局部 550−200=350）落在滚动区宽 400 内")


# 末组（额外奖励）前源有 lh+20（stagedetail.lua:2038-2040，拉开与上一组间距）。
# 布局（受控偏离，用户裁决尾标收尾）：组1..N → 尾标垫底。组1（6 物品）源累计 lh：
# 0→35→90→250；末组 subtitle 中心 y=250+20=270；尾标在末组之下保滚动链单调。
func test_last_group_head_gap() -> void:
	var loots: Array = []
	for i in range(6):
		loots.append({"id": 390, "amount": 1})
	var popup := _make_popup([{"exp": 12, "money": 34, "loots": loots}, {"loots": []}])
	var last_sub: TextureRect = popup._groups[1]["header"][0] as TextureRect
	assert_almost_eq(last_sub.position.y + last_sub.size.y * 0.5, 270.0, 0.5,
		"末组 subtitle 中心 y=270（组1 lh=250 + 源末组前 20）")
	# 尾标垫底在末组之下（滚动链组 lh_end 递增 → 尾标底单调的前提，防倒滚回潮）
	assert_true(popup._end_light.position.y > last_sub.position.y + last_sub.size.y * 0.5,
		"尾标中心在末组标题之下（末组先显示、尾标最后收尾）")
	assert_true(float(popup._groups.back().get("lh_end", 0.0)) < popup._end_tag_end_y,
		"末组 lh_end < 尾标底（自动滚动链全程单调）")


# 动画分支端到端（真跑 async 链 标题→组→尾标→末组→close，~1.6s）：
# 源 createLootAnim 链时序常量直译，此处只验证链完整走通不卡死（时序观感留实机目验）。
func test_popup_anim_branch_completes() -> void:
	var loot_list: Array = [
		{"exp": 12, "money": 34, "loots": [{"id": 390, "amount": 1}]},
		{"loots": []},
	]
	var root := Node.new()
	add_child(root)
	var popup := SweepRewardPopup.new("sweepReward", {})
	popup.setup_popup(loot_list, cm, false)
	popup.show_window(root)
	var frames: int = 0
	while not popup._anim_done and frames < 480:
		await get_tree().process_frame
		frames += 1
	assert_true(popup._anim_done, "动画分支完整走完（%d 帧内）" % frames)
	assert_true(popup._close_btn.visible, "动画完 close 显示（源 setAnimEnd 后）")
	assert_true(popup._title_label.visible, "标题动画后可见")
	popup.remove_window()


# ---- 自动跟滚守卫（源 playListLayerAnim:1961-1981 每组构建完 ey=max(lh-oh,0) 平移列表层， ----
# 曾漏译致 10 连扫荡新组在视口外闪现，2026-09-14 用户反馈后补）。
# 断言用运行时视口高（GUT headless 视口有环境膨胀，见 test_list_content_centered_in_host）。


func _host_of(popup: SweepRewardPopup) -> ScrollContainer:
	return popup._content.get_node("%ScrollHost") as ScrollContainer


# 组标题中心（_list_layer 内容坐标）滚入滚动后视口区间 [scroll, scroll+size.y]。
func _assert_header_in_view(host: ScrollContainer, header: TextureRect, msg: String) -> void:
	var cy: float = header.position.y + header.size.y * 0.5
	assert_between(cy, host.scroll_vertical - 1.0, host.scroll_vertical + host.size.y + 1.0, msg)


# 动画分支：4 战+末组总高远超视口 374，链走完后终态滚动 >0 且末组标题在视口内（~6s）。
func test_auto_scroll_follows_groups_after_anim() -> void:
	var loot_list: Array = []
	for i in range(4):
		loot_list.append({"exp": 12, "money": 34, "loots": [{"id": 390, "amount": 1}]})
	loot_list.append({"loots": []})
	var root := Node.new()
	add_child(root)
	var popup := SweepRewardPopup.new("sweepReward", {})
	popup.setup_popup(loot_list, cm, false)
	popup.show_window(root)
	# 出场时序守卫（受控偏离）：末组最后节点先可见，尾标最后收尾（用户裁决）
	var last_node: Control = (popup._groups[4]["reveal"] as Array).back() as Control
	var node_seen: int = -1
	var light_seen: int = -1
	var frames: int = 0
	while not popup._anim_done and frames < 3600:
		await get_tree().process_frame
		frames += 1
		if node_seen < 0 and last_node.visible:
			node_seen = frames
		if light_seen < 0 and popup._end_light.visible:
			light_seen = frames
	assert_true(popup._anim_done, "动画链完整走完（%d 帧内）" % frames)
	assert_true(node_seen > 0 and light_seen > node_seen,
		"末组节点先显示、尾标光效最后收尾（受控偏离时序）")
	var host: ScrollContainer = _host_of(popup)
	assert_true(host.scroll_vertical > 0, "内容超高时动画终态滚动 >0（逐组跟滚）")
	assert_eq(host.mouse_filter, Control.MOUSE_FILTER_STOP, "动画完恢复用户滚动（源 setTouchEnabled(true)）")
	_assert_header_in_view(host, popup._groups[4]["header"][0] as TextureRect,
		"末组标题滚入视口")
	popup.remove_window()


# skip 分支：源 skipLootAnim ll:setPosition(ep) 瞬时触底；等 SCROLL_SETTLE_SEC 布局就绪后断言。
func test_skip_scroll_to_bottom() -> void:
	var loot_list: Array = []
	for i in range(4):
		loot_list.append({"exp": 12, "money": 34, "loots": []})
	loot_list.append({"loots": []})
	var popup := _make_popup(loot_list)
	await get_tree().create_timer(0.2).timeout
	var host: ScrollContainer = _host_of(popup)
	assert_true(host.scroll_vertical > 0, "skip 分支超高内容瞬时触底滚动 >0")
	_assert_header_in_view(host, popup._groups[4]["header"][0] as TextureRect,
		"skip 触底后末组标题在视口内")
	popup.remove_window()


# 目标 lh 低于视口（源 ey=max(lh-oh,0)=0）不滚：直调 _scroll_to 守卫 0 分支
# （照源布局尾标高 270，最小 2 组内容 580>374 必滚，全链构造不出矮列表）。
func test_no_scroll_when_target_below_view() -> void:
	var popup := _make_popup([{"exp": 1, "money": 2, "loots": []}, {"loots": []}])
	await get_tree().create_timer(0.2).timeout
	var host: ScrollContainer = _host_of(popup)
	host.scroll_vertical = 0
	popup._scroll_to(300.0)
	assert_eq(host.scroll_vertical, 0, "目标 lh(300)<视口高时 target=0 不滚动")
	popup.remove_window()
