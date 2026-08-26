extends GutTest
# MainStatusBar 装配测试：
# - vitality plus 接 buy_vitality（照源 statusbar.lua:59-68 vitality_add_icon 圆形按钮）
# - gold bar 整条可点 → doClickMidas（照源 statusbar.lua:41-49 money_bg；gold_plus_handler）
# - diamond plus 无 handler → IGNORE（避 STOP 吞点击无响应，P1-复审2-3）

var _collected: Array = []


func before_each() -> void:
	_collected.clear()


# 递归收集所有 Button 子节点（plus 是否装配为可点 Button）。
func _collect_buttons(node: Node) -> void:
	for c in node.get_children():
		if c is Button:
			_collected.append(c)
		_collect_buttons(c)


func test_vitality_plus_clickable_with_handler() -> void:
	# build 传 handler → vitality plus 装配为 Button，pressed 触发 handler（buy_vitality 入口）
	var counter: Array[int] = [0]
	var handler: Callable = func() -> void: counter[0] += 1
	var parent := Control.new()
	add_child_autofree(parent)
	var refs: Dictionary = MainStatusBar.build(parent, handler)
	assert_true(refs.has("vitality"), "vitality label ref 存在")
	_collect_buttons(parent)
	assert_eq(_collected.size(), 1, "有 handler → vitality plus 装配为 1 个 Button")
	if _collected.size() > 0:
		(_collected[0] as Button).pressed.emit()
		assert_eq(counter[0], 1, "vitality plus pressed → 调用 handler")


func test_no_button_without_handler() -> void:
	# 无 handler：gold/diamond 左端不渲染加号（源 empty.png 占位，批 A G1a）、vit 无 Button，共 0 Button
	var parent := Control.new()
	add_child_autofree(parent)
	MainStatusBar.build(parent)
	_collect_buttons(parent)
	assert_eq(_collected.size(), 0, "无 handler → 全部条 0 Button")


# B1 入口接线（第九轮 P1-B1）：gold bar 整条可点 → doClickMidas（照源 statusbar.lua:41-49 money_bg）。
# gold_plus_handler 非 empty → bar Control gui_input 连接 + gold Label IGNORE（避吞点击）。
func test_gold_bar_clickable_with_handler() -> void:
	var counter: Array[int] = [0]
	var handler: Callable = func() -> void: counter[0] += 1
	var parent := Control.new()
	add_child_autofree(parent)
	var refs: Dictionary = MainStatusBar.build(parent, Callable(), Callable(), handler)
	assert_true(refs.has("gold"), "gold bar ref 存在")
	# 2026-08-27 批 A：_build_bar 返回 bar Control 本体（旧版返回 Label 再 get_parent）
	var gold_bar: Control = refs["gold"]
	# 模拟鼠标左键点击 bar（照引擎 gui 系统触发 gui_input 信号）
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	gold_bar.gui_input.emit(ev)
	assert_eq(counter[0], 1, "gold bar 点击 → 调用 handler（照源 money_bg→doClickMidas→midas 面板）")


# 加号视觉尺寸守卫（2026-08-15 两轮修正：初版 Button.icon 原尺寸渲染+撑大 min size 55×55，
# 终版口径：显示尺寸 = 纹理÷CONTENT_SCALE（cocos 点尺寸，无条目散图 Sprite 实际显示），Button 透明命中区与视觉同尺寸，视觉走子 TextureRect 不走 Button.icon）。
func _assert_plus_button_visual_ok() -> void:
	var plus_tex := load(MainStatusBar.PLUS_ICON_RES) as Texture2D
	var expected: Vector2 = plus_tex.get_size() / MainStatusBar.CONTENT_SCALE
	for b in _collected:
		var btn := b as Button
		assert_null(btn.icon, "视觉不走 Button.icon（min size 不可控）")
		assert_almost_eq(btn.size.x, expected.x, 0.01, "Button 命中区宽=加号显示尺寸")
		assert_almost_eq(btn.size.y, expected.y, 0.01, "Button 命中区高=加号显示尺寸")
		var icon_tr: TextureRect = btn.get_node_or_null("plus_icon")
		assert_not_null(icon_tr, "加号视觉为子 TextureRect plus_icon")
		if icon_tr != null:
			assert_almost_eq(icon_tr.size.x, expected.x, 0.01, "加号显示宽=纹理÷CS")
			assert_almost_eq(icon_tr.size.y, expected.y, 0.01, "加号显示高=纹理÷CS")
			assert_eq(icon_tr.mouse_filter, Control.MOUSE_FILTER_IGNORE, "视觉层 IGNORE 不吞点击")


func test_plus_button_visual_source_size_build() -> void:
	# build 版（main identity：vitality plus 为 Button）
	var parent := Control.new()
	add_child_autofree(parent)
	MainStatusBar.build(parent, func() -> void: pass)
	_collect_buttons(parent)
	assert_eq(_collected.size(), 1, "vitality plus 装配为 1 个 Button")
	_assert_plus_button_visual_ok()


func test_plus_button_visual_source_size_bars_only() -> void:
	# 子场景版（build_bars_only）：批 A 后 gold 也走整条可点不再渲染加号钮，仅 vitality 1 个 Button
	var parent := Control.new()
	add_child_autofree(parent)
	var handler: Callable = func() -> void: pass
	MainStatusBar.build_bars_only(parent, [331.0, 514.0, 681.0], 50.0, handler, handler)
	_collect_buttons(parent)
	assert_eq(_collected.size(), 1, "仅 vitality plus 装配 Button（gold 走整条 gui_input）")
	_assert_plus_button_visual_ok()


# 货币图标等比缩放 + 中心点守卫（2026-08-15 用户实测：三图标变形且对齐偏）。
# 三图标纹理均非正方形（金币 43×39/钻石 50×38/体力 44×50），统一正方形 rect 强拉会变形；
# 正确行为 = 显示尺寸 纹理÷CONTENT_SCALE（cocos 点尺寸换算），
# 中心点照源 BAR_ICON_CENTER。
func _collect_icons(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is TextureRect and c.name == &"icon":
			out.append(c)
		_collect_icons(c, out)


func test_currency_icons_keep_aspect_and_source_center() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	MainStatusBar.build(parent)
	var icons: Array = []
	_collect_icons(parent, icons)
	assert_eq(icons.size(), 3, "三条货币图标")
	# 中心点集合按 x 排序后应与源 BAR_ICON_CENTER 排序一致（vit 125 < rmb 156 < money 158）
	var centers: Array = []
	for tr in icons:
		var rect: TextureRect = tr as TextureRect
		var tex := rect.texture as Texture2D
		var disp: Vector2 = tex.get_size() / MainStatusBar.CONTENT_SCALE
		# 等比：显示纵横比 == 显示口径纵横比（不变形）
		assert_almost_eq(rect.size.x / rect.size.y, disp.x / disp.y, 0.01,
			"图标等比缩放（%s 显示 %.2f vs 口径 %.2f）" % [rect.get_parent().name, rect.size.x / rect.size.y, disp.x / disp.y])
		assert_almost_eq(rect.size.x, disp.x, 0.01, "显示宽=纹理÷CS")
		assert_almost_eq(rect.size.y, disp.y, 0.01, "显示高=纹理÷CS")
		centers.append(rect.position + rect.size / 2.0)
	centers.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var expected: Array = (MainStatusBar.BAR_ICON_CENTER as Array).duplicate()
	expected.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for i in range(expected.size()):
		assert_almost_eq((centers[i] as Vector2).x, (expected[i] as Vector2).x, 0.1, "图标中心 x 照源")
		assert_almost_eq((centers[i] as Vector2).y, (expected[i] as Vector2).y, 0.1, "图标中心 y 照源")


# ── 头像图回传（2026-08-21 修复轮：此前 build 从未建头像图节点，换头像无从回传主界面）──
var _cm: ConfigManager


func before_all() -> void:
	_cm = ConfigManager.new()
	_cm.load_all()


func _make_pd() -> PlayerData:
	var pd := PlayerData.new(_cm)
	return pd


func test_head_icon_assembled_with_player() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var pd := _make_pd()
	pd.avatar = 1
	var refs: Dictionary = MainStatusBar.build(parent, Callable(), Callable(), Callable(), pd, _cm)
	var icon: TextureRect = refs.get("head_icon", null)
	assert_not_null(icon, "头像图节点已建（head_icon）")
	if icon != null:
		assert_not_null(icon.texture, "Avatar[1].Picture 贴图已加载")
		assert_eq(icon.get_meta(&"avatar_id", 0), 1, "meta 记初始 avatar id")


func test_head_icon_refreshes_on_avatar_change() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var pd := _make_pd()
	pd.avatar = 1
	var refs: Dictionary = MainStatusBar.build(parent, Callable(), Callable(), Callable(), pd, _cm)
	var icon: TextureRect = refs.get("head_icon", null)
	if icon == null:
		fail_test("head_icon 未建")
		return
	var before: Texture2D = icon.texture
	pd.avatar = 2   # 换头像（Avatar 表 id=2 存在则贴图不同）
	MainStatusBar.refresh(refs, pd.team_level, 0, 0, pd.vitality, pd.vitality_max, pd.player_name, pd.vip_level, pd.avatar)
	assert_eq(icon.get_meta(&"avatar_id", 0), 2, "refresh 后 meta 更新为新 id")
	if ResourceLoader.exists("res://assets/ui/HERO/" + String(_cm.get_raw_table(&"Avatar").get("2", {}).get("Picture", "")).get_file()):
		assert_ne(icon.texture, before, "贴图已随 avatar 切换")


func test_head_icon_refresh_skips_same_avatar() -> void:
	# 同 id 刷新不重载（meta 短路防高频 refresh 重 load）。
	var parent := Control.new()
	add_child_autofree(parent)
	var pd := _make_pd()
	pd.avatar = 1
	var refs: Dictionary = MainStatusBar.build(parent, Callable(), Callable(), Callable(), pd, _cm)
	var icon: TextureRect = refs.get("head_icon", null)
	if icon == null:
		fail_test("head_icon 未建")
		return
	var before: Texture2D = icon.texture
	MainStatusBar.refresh(refs, pd.team_level, 0, 0, pd.vitality, pd.vitality_max, pd.player_name, pd.vip_level, pd.avatar)
	assert_eq(icon.texture, before, "同 id 刷新不重载")


# 头像位置照源直译守卫（2026-08-21 用户反馈「图标没在框里」后修正回归防护）：
# 源 head_icon_pos=ccp(40,54)（uires.lua:41，中心锚、cocos 左下原点）
# → Godot 左上 (5,16)（HEAD_POS(150,66) 中心 - HEAD_SIZE/2 = (81.5,13.5) 框原点）。
func test_head_icon_position_from_source() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var pd := _make_pd()
	pd.avatar = 1
	var refs: Dictionary = MainStatusBar.build(parent, Callable(), Callable(), Callable(), pd, _cm)
	var icon: TextureRect = refs.get("head_icon", null)
	if icon == null:
		fail_test("head_icon 未建")
		return
	# 2026-08-21 三修：icon 等比（高随贴图 70×h/w），左上随比例浮动 → 断言中心恒 (40,51)
	#（源 head_icon_pos=ccp(40,54) 中心锚直译）。宽恒 70。
	var center: Vector2 = icon.position + icon.size * 0.5
	assert_almost_eq(center.x, 40.0, 0.01, "icon 中心 x=40（源锚）")
	assert_almost_eq(center.y, 51.0, 0.01, "icon 中心 y=51（源 105-54）")
	assert_almost_eq(icon.size.x, 70.0, 0.01, "icon 宽恒 70（源 length）")


# 框贴图显示尺寸照源直译守卫（2026-08-21 二次修正回归防护）：
# 源 readnode head_bg/head_frame anchor(0,0)@cocos(0,10) 无 scaleSize → 贴图
# 140×104px ÷CS=109.3×81.2；旧实现铺满 137×105 拉伸 1.26× 致盾窗错位。
func test_head_bg_frame_not_stretched() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var pd := _make_pd()
	var refs: Dictionary = MainStatusBar.build(parent, Callable(), Callable(), Callable(), pd, _cm)
	var head: Control = refs["head"]
	var bg: TextureRect = head.get_node_or_null("head_bg")
	if bg == null:
		fail_test("head_bg 未建")
		return
	assert_almost_eq(bg.size.x, 109.3, 0.1, "框贴图宽 109.3（贴图÷CS 不拉伸）")
	assert_almost_eq(bg.size.y, 81.2, 0.1, "框贴图高 81.2")
	assert_almost_eq(bg.position.y, 13.8, 0.1, "框贴图顶 13.8（源 cocos y10 底部抬升）")


# ── 批 A G1a/G1b 像素级对齐守卫（2026-08-27：源 statusbar.lua empty 占位 + getNumberNode 贴图数字）──

func test_number_node_format_comma() -> void:
	# 源 tools.lua formatNumWithComma：自右每三位插逗号
	assert_eq(NumberNode.format_comma(0), "0")
	assert_eq(NumberNode.format_comma(999), "999")
	assert_eq(NumberNode.format_comma(1000), "1,000")
	assert_eq(NumberNode.format_comma(9980159), "9,980,159")
	assert_eq(NumberNode.format_comma(10000029), "10,000,029")


func test_number_node_build_structure_and_place_right() -> void:
	var host := NumberNode.build("123,456")
	autofree(host)
	# 6 数字 + 1 逗号 = 7 字符贴图子节点（缺资源跳过，white 目录全量在库）
	var trs: Array = []
	for c in host.get_children():
		if c is TextureRect:
			trs.append(c)
	assert_eq(trs.size(), 7, "逐字符 TextureRect 数 = 7（含 comma）")
	if trs.size() == 7:
		var first: TextureRect = trs[0]
		# 显示尺寸 = 字符像素 ÷ CS（19×25 white → ~14.8×19.5）
		var expected: Vector2 = (first.texture as Texture2D).get_size() / NumberNode.CONTENT_SCALE
		assert_almost_eq(first.size.y, expected.y, 0.01, "字符显示高=纹理÷CS")
		# 右缘锚定：place_right 后 右缘 = right_x、垂直中心 = center_y
		NumberNode.place_right(host, 135.0, 23.0)
		assert_almost_eq(host.position.x + host.size.x, 135.0, 0.01, "右缘 x=right_x")
		assert_almost_eq(host.position.y + host.size.y * 0.5, 23.0, 0.01, "垂直中心 y=center_y")
		host.free()


func test_gold_diamond_bars_have_no_left_plus() -> void:
	# G1a 防回归：源 money/rmb 左端 res=empty.png 占位 → Godot 侧不建任何 plus 节点；
	# 仅 vitality（有 handler）渲染加号 Button。
	var parent := Control.new()
	add_child_autofree(parent)
	var refs: Dictionary = MainStatusBar.build(parent, Callable(), Callable(), Callable())
	for key in ["gold", "diamond"]:
		var bar: Control = refs[key]
		for c in bar.get_children():
			assert_false(String(c.name).begins_with("plus"), "%s 条左端无 plus 节点（源 empty.png）" % key)
	var parent2 := Control.new()
	add_child_autofree(parent2)
	var refs2: Dictionary = MainStatusBar.build(parent2, func() -> void: pass)
	var found_plus: bool = false
	for c in (refs2["vitality"] as Control).get_children():
		if c is Button:
			found_plus = true
	assert_true(found_plus, "vitality 加号为可点 Button（照源真贴图）")


func test_refresh_builds_digit_sprites_right_aligned() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var refs: Dictionary = MainStatusBar.build(parent)
	MainStatusBar.refresh(refs, 81, 9980159, 10000029, 100, 171, "Player", 0, 1)
	# gold："9,980,159" = 7 数字 + 2 逗号 = 9 字符
	var gold_bar: Control = refs["gold"]
	var num: Control = gold_bar.get_node("num")
	assert_eq(num.get_child_count(), 9, "gold 数字字符组 9 子节点")
	assert_almost_eq(num.position.x + num.size.x, MainStatusBar.GOLD_NUM_RIGHT_X, 0.01, "gold 右缘对齐 rightPoint(135)")
	assert_almost_eq(num.position.y + num.size.y * 0.5, MainStatusBar.NUM_CENTER_Y, 0.01, "数字中心 y=23（cocos y25 直译）")
	# 数字观感 = digits/white 贴图（A/B 样张定案）
	var first_tr: TextureRect = num.get_child(0) as TextureRect
	assert_true((first_tr.texture as Texture2D).resource_path.contains("/digits/white/"), "白底黑描边数字贴图")


func test_vitality_normal_and_over_max_folders() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var refs: Dictionary = MainStatusBar.build(parent)
	MainStatusBar.refresh(refs, 81, 1000, 1000, 120, 171, "Player", 0, 1)
	var vit_bar: Control = refs["vitality"]
	var max_num: Control = vit_bar.get_node("max_num")
	var vit_num: Control = vit_bar.get_node("num")
	assert_eq(max_num.get_child_count(), 4, 'maxVit "/171" = slash + 3 数字')
	assert_almost_eq(max_num.position.x + max_num.size.x, MainStatusBar.MAXVIT_NUM_RIGHT_X, 0.01, "/max 组右缘 107")
	# vitability 右缘紧贴 maxVitText 左缘（源 left2(text, maxVitText)）
	assert_almost_eq(vit_num.position.x + vit_num.size.x, max_num.position.x, 0.01, "vit 数字右缘接 /max 左缘")
	# 未超上限 → white；超上限 → main_blue（statusbar.lua:1121 folder 条件）
	var normal_tex: Texture2D = (vit_num.get_child(0) as TextureRect).texture
	assert_true(normal_tex.resource_path.contains("/digits/white/"), "未超限 white 贴图")
	MainStatusBar.refresh(refs, 81, 1000, 1000, 200, 171, "Player", 0, 1)
	var over_tex: Texture2D = (vit_num.get_child(0) as TextureRect).texture
	assert_true(over_tex.resource_path.contains("/digits/main_blue/"), "超上限 main_blue 贴图")
