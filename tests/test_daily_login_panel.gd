extends GutTest
# DailyLoginPanel 测试（2026-07-14 重建；2026-08-16 批 2 两件套改造）。
# 数据层（build_reward_data 查表 / month_day_amount）+ View 层（chrome 静态树 / 网格 fill /
# 状态色 / 领奖交互）+ builder 退役守卫。照源 ui/popwindow/dailylogin.lua。
# create + createRewardItem + getRewardData + getRewardStatus + createList。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ── 数据层 build_reward_data（照源 getRewardData :147-181）──

func test_build_reward_data_returns_month_days() -> void:
	var data: Array = DailyLoginPanel.build_reward_data(cm)
	assert_gt(data.size(), 0, "查表返当月>=1天")
	var first: Dictionary = data[0]
	for key in ["type", "id", "amount", "vip", "day"]:
		assert_true(first.has(key), "每条含 " + key)
	assert_eq(int(first["day"]), 1, "首条 day=1")


func test_build_reward_data_day_consecutive() -> void:
	var data: Array = DailyLoginPanel.build_reward_data(cm)
	for i in range(data.size()):
		assert_eq(int(data[i]["day"]), i + 1, "day 连续递增")


func test_month_day_amount_with_sample() -> void:
	# 源 :96-108：从 1 递增直到无 Reward Type
	var sample := {"1": {"Reward Type": "Gold"}, "2": {"Reward Type": "Item"}, "3": {"x": 1}}
	assert_eq(DailyLoginPanel.month_day_amount(sample), 2, "前 2 天有 Reward Type，第 3 天无 → 2")


# ── View 层装配 + 交互 ──

func _make_panel() -> DailyLoginPanel:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := DailyLoginPanel.new("dailylogin", {})
	panel.setup_panel(pd)
	panel.show_window(root)
	return panel


func test_panel_builds_chrome_and_grid() -> void:
	var panel: DailyLoginPanel = _make_panel()
	assert_gt(panel._data_list.size(), 0, "数据列表非空")
	assert_eq(panel._cells.size(), panel._data_list.size(), "cell 数 = 天数")
	for c in panel._cells:
		assert_true(c is TextureButton, "cell 元素是 TextureButton（cell 模板实例）")
	assert_not_null(panel._subhead_num, "累计签到 Label 存在")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_first_login_one_common_rest_future() -> void:
	var panel: DailyLoginPanel = _make_panel()
	# 首次 freq=1 status=common → day1=common，其余 future（源 getRewardStatus :119-136）
	assert_eq(panel._cell_statuses.count("common"), 1, "首次登录恰 1 个 common(当日)")
	if panel._data_list.size() > 1:
		assert_eq(panel._cell_statuses.count("future"), panel._data_list.size() - 1, "其余 future")
	assert_eq(panel._cell_statuses.count("past"), 0, "首次无 past")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_claim_marks_day_past() -> void:
	var panel: DailyLoginPanel = _make_panel()
	var mgr: DailyLoginManager = panel._mgr
	var now: int = int(Time.get_unix_time_from_system())
	var freq: int = mgr.get_login_frequency(now)
	# 直接调 Logic 层领奖（不经 panel._claim 避免 Toast autoload 副作用）
	mgr.claim_reward(panel._player, cm, now)
	var st: String = panel._cell_status(freq, mgr.get_login_frequency(now), mgr.get_reward_status(now))
	assert_eq(st, "past", "领后当日格变 past(已领)")
	assert_eq(mgr.get_reward_status(now), "received", "mgr 状态 received")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_cell_status_future_beyond_freq() -> void:
	var panel: DailyLoginPanel = _make_panel()
	# day > freq → future（源 :132-134）
	assert_eq(panel._cell_status(999, 1, "common"), "future", "远未来 future")
	panel.remove_window()
	panel.get_parent().queue_free()


# ── LSTR 化（照源 dailylogin.lua :7/:448/:662/:697/:862 + syncDate :893）──

func test_daily_login_lstr_keys_exist() -> void:
	# 验证 daily login 使用的 LSTR key 全部存在（get_lstr 返非 key 本身 = 存在）
	var keys: Array[String] = [
		"DAILYLOGIN.AWARDS_DESCRIPTION",
		"DAILYLOGIN.THIS_MONTH_HAS_A_TOTAL_ATTENDANCE",
		"DAILYLOGIN.TIMES",
		"DAILYLOGIN._D_MONTHLY_ATTENDANCE_AWARDS",
		"DAILYLOGIN.FAILED_TO_RECEIVE",
		"DAILYLOGIN.RECEIVE_THIS_AWARD_AT__D_ATTENDANCE_THIS_MONTH",
	]
	for key in keys:
		var val: String = cm.get_lstr(key)
		assert_ne(val, key, "LSTR key 存在: " + key)
		assert_false(val.is_empty(), "LSTR value 非空: " + key)


func test_panel_title_uses_lstr_month() -> void:
	# 验证标题 LSTR 含 %d 占位符（源 syncDate :893 DAILYLOGIN._D_MONTHLY_ATTENDANCE_AWARDS）
	var fmt: String = cm.get_lstr("DAILYLOGIN._D_MONTHLY_ATTENDANCE_AWARDS")
	assert_true(fmt.find("%d") >= 0, "标题 LSTR 含 %d 月占位符")
	var month: int = int(Time.get_datetime_dict_from_system().get("month", 1))
	assert_eq(fmt % month, "%d月签到奖励" % month, "标题 LSTR 格式化正确")


# P0-8：源 dailylogin.lua:721-732 refreshSubhead：number 弹跳 1→1.5→1。
# _refresh_view(bounce=true) → _subhead_num pivot 居中 + tween 启动。
func test_subhead_bounce_on_claim() -> void:
	var root := Node.new()
	add_child(root)
	var panel := DailyLoginPanel.new("daily_login", {})
	panel.setup_panel(_make_player_with_freq(1))
	panel.show_window(root)
	# 触发领奖路径（_claim 调 _refresh_view(true)）需 day==freq 且 status==common；
	# 直接调 _refresh_view(true) 验证弹跳 tween 启动。
	panel._refresh_view(true)
	await get_tree().create_timer(0.05).timeout
	# bounce tween 应启动且 pivot 居中（scale 绕中心）。
	assert_almost_eq(panel._subhead_num.pivot_offset.x, panel._subhead_num.size.x * 0.5, 0.5, "subhead_num pivot x 居中")
	assert_true(panel._subhead_bounce_tween != null and panel._subhead_bounce_tween.is_valid(), "bounce tween 启动")
	panel.remove_window()
	root.queue_free()


# _make_player_with_freq：构造 PlayerData，DailyLoginManager 返指定 freq + common 状态。
func _make_player_with_freq(freq: int) -> PlayerData:
	var pd := PlayerData.new(cm)
	# DailyLoginManager.get_login_frequency/get_reward_status 默认返 0/"none"，
	# 直接 monkey-patch 不便（RefCounted 无 set_meta 法）。用 GameData 桥接：
	# 实际 freq 来自 save，测试隔离下默认 freq=0 → checkin_num=-1（freq-1）。
	# 本测试不验证 checkin_num 数值，只验证 bounce tween 启动（_refresh_view(true) 总跳）。
	return pd


# ══════════ 批 2 两件套守卫（2026-08-16，核对级照源 dailylogin.lua）══════════

const CONTENT_PATH := "res://scenes/ui/daily_login_content.tscn"
const CELL_PATH := "res://scenes/ui/daily_login_cell.tscn"
const PANEL_PATH := "res://scripts/ui/daily_login_panel.gd"
const THEME_PATH := "res://resources/themes/default_theme.tres"


# builder 退役（两件套范式）：文件删除 + panel 无残留引用。
func test_builder_retired() -> void:
	assert_false(FileAccess.file_exists("res://scripts/ui/daily_login_builder.gd"),
		"daily_login_builder 已退役（两件套范式）")
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_false(text.contains("daily_login_builder"), "panel 无 builder 残留引用")


# 静态树（chrome 常驻 tscn）：rect 照源换算。
# 源 create :734-887：frame 中心 ccp(400,240) scaleSize 578x420 cap(50,50,478,50)（752x202 纹理）；
# title_bg 中心 (400,441)（445x79÷CS）；close 中心 (675,440)（65x66÷CS）；
# act_bg 中心 (400,420) fix_size(0,35)；title 中心 (400,444) size18 ccc3(231,206,19)；
# explain 中心 (190,400) scaleSize 105x50 cap(20,15,88,19)；subhead 中心 (400,386)；
# createListLayer :634-652 draglist rect CCRectMake(140,40,520,335)；
# createList :380-420 board reward_bg cap(15,15,24,25)（71x71 纹理）。
func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# frame（578x420 中心 to_godot(400,240)=(480,320)；cap 正确公式 top=202-50-50=102 bottom=50）
	var frame: NinePatchRect = inst.get_node("Frame") as NinePatchRect
	assert_almost_eq(frame.offset_left, 191.0, 0.1, "Frame 左 = 480-578/2")
	assert_almost_eq(frame.offset_top, 110.0, 0.1, "Frame 顶 = 320-420/2")
	assert_almost_eq(frame.size.x, 578.0, 0.1, "Frame 宽照源 scaleSize 578")
	assert_almost_eq(frame.size.y, 420.0, 0.1, "Frame 高照源 scaleSize 420")
	assert_eq(frame.patch_margin_left, 50, "Frame cap left=源 cap.x=50")
	assert_eq(frame.patch_margin_top, 102, "Frame cap top=202-50-50=102（批1公式，旧值 50 互换）")
	assert_eq(frame.patch_margin_right, 224, "Frame cap right=752-50-478=224")
	assert_eq(frame.patch_margin_bottom, 50, "Frame cap bottom=源 cap.y=50（旧值 102 互换）")
	# title_bg（445x79 ÷CS=347.32x61.66，中心 (480,119)）
	var title_bg: TextureRect = inst.get_node("TitleBg") as TextureRect
	assert_almost_eq(title_bg.size.x, 347.32, 0.1, "TitleBg 宽 = 445/CS")
	assert_almost_eq(title_bg.size.y, 61.66, 0.1, "TitleBg 高 = 79/CS")
	assert_almost_eq(title_bg.position.x + title_bg.size.x * 0.5, 480.0, 0.1, "TitleBg 中心 x=480")
	assert_almost_eq(title_bg.position.y + title_bg.size.y * 0.5, 119.0, 0.1, "TitleBg 中心 y=560-441")
	# act_bg（fix_size(0,35)：宽=734÷CS=573.17，高 35 直译，中心 (480,140)）
	var act_bg: TextureRect = inst.get_node("ActBg") as TextureRect
	assert_almost_eq(act_bg.size.x, 573.17, 0.1, "ActBg 宽 = 734/CS（fix_size w=0 保持）")
	assert_almost_eq(act_bg.size.y, 35.0, 0.1, "ActBg 高 = fix_size h=35 直译")
	# close（65x66 ÷CS=50.73x51.51，中心 to_godot(675,440)=(755,120)）
	var close_btn: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(close_btn.size.x, 50.73, 0.01, "CloseBtn 宽 = 65/CS")
	assert_almost_eq(close_btn.size.y, 51.51, 0.01, "CloseBtn 高 = 66/CS")
	assert_almost_eq(close_btn.position.x + close_btn.size.x * 0.5, 755.0, 0.1, "CloseBtn 中心 x=755")
	assert_almost_eq(close_btn.position.y + close_btn.size.y * 0.5, 120.0, 0.1, "CloseBtn 中心 y=560-440")
	assert_eq(close_btn.stretch_mode, TextureButton.STRETCH_SCALE, "CloseBtn stretch=SCALE（4.7 默认 KEEP 原尺寸溢出）")
	# title label（中心 (480,116)，variation 接管色/字号，源无描边）
	var title_lbl: Label = inst.get_node("%TitleLabel") as Label
	assert_almost_eq(title_lbl.position.x + title_lbl.size.x * 0.5, 480.0, 0.1, "TitleLabel 中心 x=480")
	assert_almost_eq(title_lbl.position.y + title_lbl.size.y * 0.5, 116.0, 2.0,
		"TitleLabel 中心 y=560-444（容差 2：Godot 18 号行高 23>rect 20 的度量差，非错位）")
	assert_eq(String(title_lbl.theme_type_variation), "DailyLoginTitleLabel", "TitleLabel 走 variation")
	# explain 按钮（105x50 中心 to_godot(190,400)=(270,160)，theme 三态接管 Scale9）
	var explain_btn: Button = inst.get_node("%ExplainBtn") as Button
	assert_almost_eq(explain_btn.size.x, 105.0, 0.01, "ExplainBtn 宽照源 scaleSize 105")
	assert_almost_eq(explain_btn.size.y, 50.0, 0.01, "ExplainBtn 高照源 scaleSize 50")
	assert_almost_eq(explain_btn.position.x + explain_btn.size.x * 0.5, 270.0, 0.1, "ExplainBtn 中心 x=270")
	assert_almost_eq(explain_btn.position.y + explain_btn.size.y * 0.5, 160.0, 0.1, "ExplainBtn 中心 y=560-400")
	assert_eq(String(explain_btn.theme_type_variation), "DailyLoginExplainBtn", "ExplainBtn 走三态 variation")
	var explain_lbl: Label = explain_btn.get_node("%ExplainLabel") as Label
	assert_eq(String(explain_lbl.theme_type_variation), "DailyLoginExplainLabel", "ExplainLabel 走 variation")
	# subhead 3 label（源 createSubhead :653-720，中心 y=560-386+10=174-10=164）
	var pre_lbl: Label = inst.get_node("%SubheadPreLabel") as Label
	assert_almost_eq(pre_lbl.position.y + pre_lbl.size.y * 0.5, 164.0, 2.0,
		"SubheadPreLabel 垂直中心 164（容差 2：16 号行高度量差）")
	assert_eq(String(pre_lbl.theme_type_variation), "DailyLoginSubheadPreLabel", "SubheadPreLabel 走 variation")
	# 滚动区（draglist rect CCRectMake(140,40,520,335) → 220~740 x 185~520）
	var scroll: ScrollContainer = inst.get_node("%GridScroll") as ScrollContainer
	assert_almost_eq(scroll.offset_left, 220.0, 0.1, "GridScroll 左 = 140+80")
	assert_almost_eq(scroll.offset_top, 185.0, 0.1, "GridScroll 顶 = 560-(40+335)")
	assert_almost_eq(scroll.offset_right, 740.0, 0.1, "GridScroll 右 = 660+80")
	assert_almost_eq(scroll.offset_bottom, 520.0, 0.1, "GridScroll 底 = 560-40")
	# 网格底板常驻（createList board Scale9 reward_bg 71x71 cap(15,15,24,25)：
	# 正确公式 left=15 top=71-15-25=31 right=71-15-24=32 bottom=15）
	var grid_content: Control = scroll.get_node("GridContent") as Control
	assert_not_null(grid_content, "GridContent 常驻（fill 只设尺寸+挂 cell）")
	var reward_bg: NinePatchRect = grid_content.get_node("RewardBg") as NinePatchRect
	assert_eq(reward_bg.patch_margin_left, 15, "RewardBg cap left=15")
	assert_eq(reward_bg.patch_margin_top, 31, "RewardBg cap top=71-15-25=31（批1公式）")
	assert_eq(reward_bg.patch_margin_right, 32, "RewardBg cap right=71-15-24=32")
	assert_eq(reward_bg.patch_margin_bottom, 15, "RewardBg cap bottom=源 cap.y=15")


# cell 模板静态树（照源 createRewardItem :222-378）：
# board matrix 133x130 ÷CS=103.80x101.46；checked 132x130÷CS 中心=board 中心 z=10；
# vip_bg 77x80÷CS anchor(0,1) 局部 (0,102)→top=-0.5；light 230x231÷CS 中心局部 (51,51.5)；
# amount size24 anchor(1,0.5) 局部 (92,22)→(92,79.5)；三态贴图 fill 切换故默认全隐。
func test_cell_template_static_tree() -> void:
	var inst: TextureButton = (load(CELL_PATH) as PackedScene).instantiate() as TextureButton
	add_child_autofree(inst)
	assert_almost_eq(inst.size.x, 103.80, 0.01, "board 宽 = 133/CS")
	assert_almost_eq(inst.size.y, 101.46, 0.01, "board 高 = 130/CS")
	assert_eq(inst.stretch_mode, TextureButton.STRETCH_SCALE, "board stretch=SCALE（修正 KEEP 默认原尺寸溢出 1.28x）")
	assert_eq((inst.texture_normal as Texture2D).resource_path,
		"res://assets/ui/alpha/HVGA/dailylogin/dailylogin_matrix.png", "board 默认 matrix（fill 切 yellow）")
	var checked: TextureRect = inst.get_node("%CheckedIcon") as TextureRect
	assert_almost_eq(checked.size.x, 103.02, 0.01, "checked 宽 = 132/CS")
	assert_almost_eq(checked.position.x + checked.size.x * 0.5, inst.size.x * 0.5, 0.01, "checked 中心=board 中心")
	assert_false(checked.visible, "checked 默认隐藏（fill 按 past 切换）")
	var vip_bg: TextureRect = inst.get_node("%VipBg") as TextureRect
	assert_almost_eq(vip_bg.size.x, 60.10, 0.01, "vip_bg 宽 = 77/CS")
	assert_almost_eq(vip_bg.position.y, -0.5, 0.01, "vip_bg 顶 = 101.5-102（anchor(0,1) 局部 (0,102)）")
	assert_false(vip_bg.visible, "vip_bg 默认隐藏")
	var vip_num: Label = inst.get_node("%VipNum") as Label
	assert_almost_eq(vip_num.rotation, -PI / 4.0, 0.001, "vip num 旋转 -45°（源 :218）")
	assert_false(vip_num.visible, "vip num 默认隐藏")
	var light: TextureRect = inst.get_node("%Light") as TextureRect
	assert_almost_eq(light.size.x, 179.51, 0.01, "light 宽 = 230/CS")
	assert_almost_eq(light.pivot_offset.x, light.size.x * 0.5, 0.01, "light pivot 居中（旋转绕中心）")
	assert_false(light.visible, "light 默认隐藏（fill 按 Hero+状态切）")
	var amount: Label = inst.get_node("%AmountLabel") as Label
	assert_eq(String(amount.theme_type_variation), "DailyLoginAmountLabel", "amount 走 variation")
	assert_not_null(inst.get_node("%IconHost"), "IconHost 常驻（fill 挂 icon）")


# panel 零静态构造（宽口径白名单）：签到格走 cell 模板 tscn，仅 PlayerEXP 资产缺失降级 Label.new(。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count("Label.new("), 1, "仅 1 处 Label.new(（PlayerEXP 降级 EXP 标签）")
	assert_eq(text.count(".new("), 1, "宽口径 .new( 总数 = Label.new( 白名单")


# theme variation 接线（GUT 下节点级不解析 variation，读 tres 文本表项）。
# 源字号/色：title size18 ccc3(231,206,19)（:813-826）；explain_label size18 ccc3(225,209,186)
# （:858-873）；amount size24 白 stroke ccc3(95,64,43) size2（:356-375）；
# explain cap CCRectMake(20,15,88,19)（166x63 纹理）→ left=20 top=63-15-19=29 right=166-20-88=58 bottom=15。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("DailyLoginTitleLabel/font_sizes/font_size = 18"), "TitleLabel 字号 18")
	assert_true(t.contains("DailyLoginTitleLabel/colors/font_color = Color(0.905882, 0.807843, 0.07451, 1)"),
		"TitleLabel 色=ccc3(231,206,19)")
	assert_true(t.contains("DailyLoginExplainLabel/colors/font_color = Color(0.882353, 0.819608, 0.729412, 1)"),
		"ExplainLabel 色=ccc3(225,209,186)")
	assert_true(t.contains("DailyLoginExplainBtn/styles/normal = SubResource(\"SB_dl_explain_n\")"),
		"ExplainBtn normal=SB_dl_explain_n")
	assert_true(t.contains("DailyLoginExplainBtn/styles/pressed = SubResource(\"SB_dl_explain_p\")"),
		"ExplainBtn pressed=SB_dl_explain_p")
	var sb_n: int = t.find("SB_dl_explain_n")
	assert_gt(sb_n, 0, "SB_dl_explain_n sub_resource 存在")
	var sb_block: String = t.substr(sb_n - 40, 400)
	assert_true(sb_block.contains("texture_margin_left = 20.0"), "SB margin left=源 cap.x=20")
	assert_true(sb_block.contains("texture_margin_top = 29.0"), "SB margin top=63-15-19=29（批1公式）")
	assert_true(sb_block.contains("texture_margin_right = 58.0"), "SB margin right=166-20-88=58")
	assert_true(sb_block.contains("texture_margin_bottom = 15.0"), "SB margin bottom=源 cap.y=15")
	assert_true(t.contains("DailyLoginAmountLabel/font_sizes/font_size = 24"), "Amount 字号 24")
	assert_true(t.contains("DailyLoginAmountLabel/colors/font_outline_color = Color(0.372549, 0.25098, 0.168627, 1)"),
		"Amount 描边=ccc3(95,64,43)")
	assert_true(t.contains("DailyLoginVipNum/font_sizes/font_size = 14"), "VipNum 字号 14")
	assert_true(t.contains("DailyLoginSubheadPreLabel/colors/font_color = Color(0.933333, 0.8, 0.466667, 1)"),
		"SubheadPre 色=ccc3(238,204,119)")
	assert_true(t.contains("DailyLoginSubheadSufLabel/colors/font_color = Color(1, 0.8, 0.356863, 1)"),
		"SubheadSuf 色=ccc3(255,204,91)")


# fill 语义：三态贴图/勾/VIP 角标/Hero 光效/静态类型 icon（8 月表 day1=Item vip1、
# day2=Diamond、day7=Hero；首登 freq=1 common → day1 common 其余 future）。
func test_grid_fill_semantics() -> void:
	var panel: DailyLoginPanel = _make_panel()
	var day1: TextureButton = panel._cells[0]
	assert_eq((day1.texture_normal as Texture2D).resource_path,
		"res://assets/ui/alpha/HVGA/dailylogin/dailylogin_matrix_yellow.png", "当日格(common)=yellow")
	assert_true((day1.get_node("%VipBg") as TextureRect).visible, "day1 vip=1 → 角标显示")
	assert_eq((day1.get_node("%VipNum") as Label).text, "VIP1", "VipNum 文案 VIP1")
	assert_false((day1.get_node("%CheckedIcon") as TextureRect).visible, "当日未领无勾")
	var day2: TextureButton = panel._cells[1]
	assert_eq((day2.texture_normal as Texture2D).resource_path,
		"res://assets/ui/alpha/HVGA/dailylogin/dailylogin_matrix.png", "未来格=matrix")
	assert_not_null((day2.get_node("%IconHost") as TextureRect).texture, "day2 Diamond → host 填 rmb icon")
	var day7: TextureButton = panel._cells[6]
	assert_true((day7.get_node("%Light") as TextureRect).visible, "day7 Hero future → 光效显示")
	var amount_lbl: Label = day2.get_node("%AmountLabel") as Label
	assert_eq(amount_lbl.text, "x%d" % int(panel._data_list[1]["amount"]), "amount 文案 x+数量")
	panel.remove_window()
	panel.get_parent().queue_free()


# parenting 回归守卫：show_window 后格心 global = 场景坐标（board 顶对齐 GridContent 顶基线，
# 首格中心 GridContent 局部 (58,56) → 场景 (220+58, 185+56)）。
func test_cell_global_position() -> void:
	var panel: DailyLoginPanel = _make_panel()
	var day1: TextureButton = panel._cells[0]
	assert_almost_eq(day1.global_position.x + day1.size.x * 0.5, 278.0, 0.5, "day1 格心 global x=278")
	assert_almost_eq(day1.global_position.y + day1.size.y * 0.5, 241.0, 0.5, "day1 格心 global y=241")
	panel.remove_window()
	panel.get_parent().queue_free()


# Item/Hero icon 居中定位（task-11 守卫）：源 :317-334 createIcon(id) 无 length → 显示原点
# 尺寸 = frame 纹理 94×95 ÷CS ≈ 73.37×74.13，icon 中心 board 局部 (51,52)（y-up → godot 49.5）。
# 曾因 ReadequipIcon Sprite2D 按纹理原尺寸渲染且未补偿：icon 视觉 94×95 从 (15,13.5) 起 →
# 中心 (57,61) 偏右下、溢出 board(103.8x101.46)、盖住 VipBg（验收三症状同源）。
func test_item_icon_centered_in_board() -> void:
	var panel: DailyLoginPanel = _make_panel()
	var target_day: int = -1
	for i in range(panel._data_list.size()):
		var t: String = String(panel._data_list[i].get("type", ""))
		if t == "Item" or t == "Hero":
			target_day = i
			break
	assert_gt(target_day, -1, "当月表含 Item/Hero 奖励")
	var cell: TextureButton = panel._cells[target_day]
	var icon: Control = (cell.get_node("%IconHost") as TextureRect).get_child(0) as Control
	assert_almost_eq(icon.scale.x, 1.0 / 1.28125, 0.0001, "icon scale=1/CS（视觉 73.37×74.13）")
	var vis: Vector2 = Vector2(94.0, 95.0) / 1.28125
	assert_almost_eq(icon.position.x + vis.x * 0.5, 51.0, 0.1, "icon 视觉中心 x=51（源 :334 ccp(51,52)）")
	assert_almost_eq(icon.position.y + vis.y * 0.5, 49.5, 0.1, "icon 视觉中心 y=49.5（52 y 翻转）")
	assert_almost_eq(icon.position.x, 14.31, 0.1, "icon 左 = 51-73.37/2")
	assert_almost_eq(icon.position.y, 12.43, 0.1, "icon 顶 = 49.5-74.13/2")
	panel.remove_window()
	panel.get_parent().queue_free()


# cell 内 z 序（task-11 守卫）：源序 light→icon→vip_bg（vip 后加盖 icon）、checked z=10 置顶。
# 曾因 IconHost 排 VipBg 后声明且无 z：icon 盖 vip（vip 须反过来盖 icon）。
func test_cell_z_order_icon_below_vip_below_checked() -> void:
	var inst: TextureButton = (load(CELL_PATH) as PackedScene).instantiate() as TextureButton
	add_child_autofree(inst)
	var icon_host: TextureRect = inst.get_node("%IconHost") as TextureRect
	var vip_bg: TextureRect = inst.get_node("%VipBg") as TextureRect
	var checked: TextureRect = inst.get_node("%CheckedIcon") as TextureRect
	assert_true(int(vip_bg.z_index) > int(icon_host.z_index), "VipBg z=1 > icon z=0（源 vip 后加盖 icon）")
	assert_true(int(checked.z_index) > int(vip_bg.z_index), "CheckedIcon z=2 > vip（源 checked z=10 置顶）")
