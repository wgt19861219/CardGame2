extends GutTest
# hero_split 三件套守卫（批 1 Task 8，2026-08-15）：window/confirm/explain 两件套改造。
# 框架照源直译：window = uieditor/herosplit.lua + window.lua（单机化裁剪见任务报告）、
# confirm = uieditor/herosplitconfirm.lua + confirm.lua（splitconfirm 语义，单机化合并
# firstConfirm 的 popConfirmDialog 环节）、explain = uieditor/explainwindow.lua 通用窗 +
# explain.lua 4 行文本。坐标换算：cocos(800x480 左下) → godot(960x640 左上) via
# (x+80, 560-y)；frame 子节点局部空间（原点=frame 显示矩形左下角 y-up）→ Godot 容器内
# (x, frameH-y)；window.lua 手写 DGccp(x,y)=×0.78125 → 显示空间再换算。
# 本文件并入旧 test_hero_split_window.gd 的 5 用例（接口适配，用例数不缩水）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_mgr() -> HeroManager:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	mgr.add_hero(2)
	return mgr


func _assert_color_eq(actual: Color, expect: Color, msg: String) -> void:
	assert_almost_eq(actual.r, expect.r, 0.001, msg + " [r]")
	assert_almost_eq(actual.g, expect.g, 0.001, msg + " [g]")
	assert_almost_eq(actual.b, expect.b, 0.001, msg + " [b]")


# ══ 件 1：hero_split_window（源 uieditor/herosplit.lua 声明表直译）══

# 框架布局照源：frame fix_wh(702.34x447.66) 中心 (402.34,240.63) → 全屏 rect；
# close/说明按钮 frame 局部（y-up 原点=frame 左下角 → gy=447.66-y）；
# DetailContainer 照源 Layer 78.13x78.13 anchor(0,0) at (351.17,223.83)。
func test_window_layout_follows_source() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_split_window_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var frame: Control = inst.get_node("Frame") as Control
	assert_almost_eq(frame.offset_left, 51.17, 0.5, "frame 左=源中心 x-半宽")
	assert_almost_eq(frame.offset_top, 15.54, 0.5, "frame 顶=源中心 y-半高")
	assert_almost_eq(frame.offset_right - frame.offset_left, 702.34, 0.5, "frame 宽=源 fix_wh w")
	assert_almost_eq(frame.offset_bottom - frame.offset_top, 447.66, 0.5, "frame 高=源 fix_wh h")
	var close: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq((close.offset_left + close.offset_right) / 2.0, 679.3, 0.5, "close 中心 x=679.3（frame 局部）")
	assert_almost_eq((close.offset_top + close.offset_bottom) / 2.0, 447.66 - 419.92, 0.5,
		"close 中心 y=447.66-419.92（frame 局部 y 翻转）")
	assert_almost_eq(close.offset_right - close.offset_left, 57.81, 0.5, "close 宽=源 fix_wh 57.81")
	var explain: Button = inst.get_node("%ExplainBtn") as Button
	assert_almost_eq((explain.offset_left + explain.offset_right) / 2.0, 83.98, 0.5, "说明按钮中心 x=83.98")
	assert_almost_eq((explain.offset_top + explain.offset_bottom) / 2.0, 447.66 - 44.14, 0.5,
		"说明按钮中心 y=447.66-44.14")
	assert_almost_eq(explain.offset_right - explain.offset_left, 128.13, 0.5, "说明按钮宽=源 scaleSize 128.13")
	var detail: Control = inst.get_node("%DetailContainer") as Control
	assert_almost_eq(detail.offset_left, 351.17, 0.5, "detail 容器左=源 Layer pos x")
	assert_almost_eq(detail.offset_bottom, 223.83, 0.5, "detail 容器底=源 Layer pos y（y 翻转）")
	assert_almost_eq(detail.offset_right - detail.offset_left, 78.13, 0.5, "detail 容器宽=源 scaleSize 78.13")
	# 审查修复守卫（2026-08-15 Critical）：close/explain/detail/hero_scroll 4 节点曾误挂
	# root，offset 是 frame 局部值 → 整体位移 frame 原点 (131.17,95.54)——close 落屏幕
	# 顶缘、explain 探出 frame 左界 111px。offset 比对只验算术，补 global 级断言验布局。
	assert_eq(close.get_parent(), frame, "close 挂 Frame（防 parenting 回归）")
	assert_eq(explain.get_parent(), frame, "explain 挂 Frame（防 parenting 回归）")
	assert_eq(detail.get_parent(), frame, "detail 挂 Frame（防 parenting 回归）")
	var hero_scroll: ScrollContainer = inst.get_node("%HeroScroll") as ScrollContainer
	assert_eq(hero_scroll.get_parent(), frame, "hero_scroll 挂 Frame（防 parenting 回归）")
	assert_almost_eq(frame.global_position.x, 51.17, 0.5, "frame 全局左=131.17")
	assert_almost_eq(frame.global_position.y, 15.54, 0.5, "frame 全局顶=95.54")
	assert_almost_eq(close.global_position.y, 15.54 - 1.56, 0.5, "close 全局顶=frame 顶-1.56（骑 frame 顶边照源）")
	assert_almost_eq(close.global_position.x, 51.17 + 650.4, 0.5, "close 全局左=frame 左+650.4")
	assert_true(explain.global_position.x > frame.global_position.x, "explain 全局左在 frame 左界内（误挂 root 时探出 111px）")
	assert_almost_eq(detail.global_position.x, 51.17 + 351.17, 0.5, "detail 全局左=frame 左+351.17")
	assert_almost_eq(frame.get_global_rect().end.y - detail.get_global_rect().end.y, 223.83, 0.5,
		"detail 全局底=frame 底-223.83（源 Layer anchor(0,0) at y-up 223.83）")
	assert_true(frame.get_global_rect().encloses(detail.get_global_rect()), "detail 容器整体在 frame 内")
	assert_almost_eq(hero_scroll.global_position.x, 51.17 + 155.0, 0.5, "hero_scroll 全局左=frame 左+155")
	assert_almost_eq(hero_scroll.global_position.y, 15.54 + 60.0, 0.5, "hero_scroll 全局顶=frame 顶+60")


# DetailContainer 内照源（detail 局部坐标，容器高 78.13 → gy=78.13-y）：
# title_bg/title(80.47,189.84) 中心、delimeter(74.22,68.75)、title_2(-153.13,55.47)
# anchor(0,0.5) 左缘、list_bg(75,-67.97) Scale9、split_button(264.06,-179.69)。
func test_window_detail_layout_follows_source() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_split_window_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var detail: Control = inst.get_node("%DetailContainer") as Control
	var title_bg: Control = detail.get_node("TitleBg") as Control
	assert_almost_eq((title_bg.offset_left + title_bg.offset_right) / 2.0, 80.47, 0.5, "title_bg 中心 x=80.47（detail 局部）")
	assert_almost_eq((title_bg.offset_top + title_bg.offset_bottom) / 2.0, 78.13 - 189.84, 0.5,
		"title_bg 中心 y=78.13-189.84")
	assert_almost_eq(title_bg.offset_right - title_bg.offset_left, 506.25, 0.5, "title_bg 宽=源 fix_wh 506.25")
	var delimeter: TextureRect = detail.get_node("Delimeter") as TextureRect
	assert_almost_eq((delimeter.offset_top + delimeter.offset_bottom) / 2.0, 78.13 - 68.75, 0.5,
		"delimeter 中心 y=78.13-68.75")
	assert_almost_eq(delimeter.offset_right - delimeter.offset_left, 455.0, 0.5, "delimeter 宽=源 fix_wh 455")
	var title2: Label = detail.get_node("%Title2") as Label
	assert_almost_eq(title2.offset_left, -153.13, 0.5, "title_2 左缘 x=-153.13（源 anchor(0,0.5)）")
	assert_almost_eq((title2.offset_top + title2.offset_bottom) / 2.0, 78.13 - 55.47, 0.5, "title_2 中心 y=78.13-55.47")
	var list_bg: NinePatchRect = detail.get_node("ListBg") as NinePatchRect
	assert_almost_eq((list_bg.offset_left + list_bg.offset_right) / 2.0, 75.0, 0.5, "list_bg 中心 x=75")
	assert_almost_eq(list_bg.offset_right - list_bg.offset_left, 511.72, 0.5, "list_bg 宽=源 scaleSize 511.72")
	assert_almost_eq(list_bg.offset_bottom - list_bg.offset_top, 167.97, 0.5, "list_bg 高=源 scaleSize 167.97")
	var split: Button = detail.get_node("%SplitBtn") as Button
	assert_almost_eq((split.offset_left + split.offset_right) / 2.0, 264.06, 0.5, "分解按钮中心 x=264.06")
	assert_almost_eq((split.offset_top + split.offset_bottom) / 2.0, 78.13 + 179.69, 0.5,
		"分解按钮中心 y=78.13+179.69（源 y=-179.69 越界挂载）")
	assert_almost_eq(split.offset_right - split.offset_left, 128.91, 0.5, "分解按钮宽=源 scaleSize 128.91")
	# 审查修复守卫（2026-08-15 Important）：detail 子树随 DetailContainer 挂 Frame 后的
	# global 级验证——子节点全局位置 = frame 原点 + detail 局部（防 parenting 回归连带偏移）。
	assert_almost_eq(detail.global_position.x, 51.17 + 351.17, 0.5, "detail 全局左=frame 内 351.17")
	assert_almost_eq(title_bg.global_position.x - detail.global_position.x, -172.66, 0.5,
		"title_bg 全局=detail 局部 -172.66（源负坐标）")
	assert_almost_eq(title_bg.global_position.y - detail.global_position.y, -128.9, 0.5,
		"title_bg 全局=detail 局部 -128.9（detail 局部 gy=78.13-189.84 顶缘）")
	assert_almost_eq(split.global_position.x - detail.global_position.x, 199.61, 0.5,
		"分解按钮全局=detail 局部 199.61")
	assert_almost_eq(split.global_position.y - detail.global_position.y, 233.2, 0.5,
		"分解按钮全局=detail 局部 233.2（源 y=-179.69 越界挂载）")


# Scale9 九宫格 capInsets（纹理像素，cap 左下原点 → top=H-y-h/bottom=y）→
# NinePatchRect patch_margin 直译（批 1 终审必修 1 修正垂直互换）。
func test_window_ninepatch_margins_follow_source() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_split_window_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var list_bg: NinePatchRect = inst.get_node("%DetailContainer/ListBg") as NinePatchRect
	assert_almost_eq(list_bg.patch_margin_left, 14.06, 0.5, "list_bg 左 margin=源 cap.x")
	assert_almost_eq(list_bg.patch_margin_top, 216.0 - 15.63 - 136.72, 0.5, "list_bg 顶 margin=纹高-cap")
	assert_almost_eq(list_bg.patch_margin_right, 858.0 - 14.06 - 640.63, 0.5, "list_bg 右 margin=纹宽-cap")
	assert_almost_eq(list_bg.patch_margin_bottom, 15.63, 0.5, "list_bg 底 margin=源 cap.y")
	var title_bg: NinePatchRect = inst.get_node("%DetailContainer/TitleBg") as NinePatchRect
	assert_almost_eq(title_bg.patch_margin_left, 78.13, 0.5, "title_bg 左 margin=源 cap.x")
	assert_almost_eq(title_bg.patch_margin_top, 15.0 - 11.72, 0.5, "title_bg 顶 margin=纹高-cap")
	assert_almost_eq(title_bg.patch_margin_bottom, 0.0, 0.5, "title_bg 底 margin=源 cap.y=0")


# 贴图接线（close 双态 + Scale9 贴图）。
func test_window_textures_wired() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_split_window_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var close: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_not_null(close.texture_normal, "close normal 贴图")
	assert_not_null(close.texture_pressed, "close pressed 贴图")
	var list_bg: NinePatchRect = inst.get_node("%DetailContainer/ListBg") as NinePatchRect
	assert_not_null(list_bg.texture, "list_bg 九宫格贴图 equipupgrade_bottom_bg")
	var title_bg: NinePatchRect = inst.get_node("%DetailContainer/TitleBg") as NinePatchRect
	assert_not_null(title_bg.texture, "title_bg 九宫格贴图 task_title_bg")
	var delimeter: TextureRect = inst.get_node("%DetailContainer/Delimeter") as TextureRect
	assert_not_null(delimeter.texture, "delimeter 贴图 chat_delimeter")


# variation 接线（Label/Button 走 theme_type_variation，禁运行时 override）。
func test_window_variations_wired() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_split_window_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	assert_eq((inst.get_node("%DetailContainer/TitleLabel") as Label).theme_type_variation,
		&"HeroSplitTitleLabel", "详情标题走 HeroSplitTitleLabel")
	assert_eq((inst.get_node("%DetailContainer/%Title2") as Label).theme_type_variation,
		&"HeroSplitSectionLabel", "你将获得标签走 HeroSplitSectionLabel")
	assert_eq((inst.get_node("%ExplainBtn") as Button).theme_type_variation,
		&"HeroSplitSellButton", "说明按钮走 HeroSplitSellButton")
	assert_eq((inst.get_node("%DetailContainer/%SplitBtn") as Button).theme_type_variation,
		&"HeroSplitTaskButton", "分解按钮走 HeroSplitTaskButton")


# theme 表项数值照源（GUT 节点级不解析 variation，走 theme 资源断言）。
func test_window_theme_entries() -> void:
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroSplitTitleLabel"), 23,
		"详情标题字号 23 照源 title_label size")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroSplitTitleLabel") as Color,
		Color.WHITE, "详情标题白照源 ccc3(255,255,255)")
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroSplitSectionLabel"), 19,
		"分区标签字号 19 照源 title_2 size")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroSplitSectionLabel") as Color,
		Color(57.0 / 255.0, 44.0 / 255.0, 36.0 / 255.0), "分区标签色 (57,44,36) 照源")
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroSplitSellButton"), 22,
		"sell_number 按钮字号 22 照源 size")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroSplitSellButton") as Color,
		Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0), "sell_button 文字色 (234,225,205) 照源")
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroSplitTaskButton"), 22,
		"task_button 按钮字号 22 照源 size")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroSplitTaskButton") as Color,
		Color(254.0 / 255.0, 244.0 / 255.0, 16.0 / 255.0), "task_button 文字色 (254,244,16) 照源")


# fill 静态文案（LSTR：分解详情/你将获得/详细规则/分解）。
func test_window_fill_titles() -> void:
	var root := Node.new()
	add_child(root)
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(_make_mgr(), cm)
	window.show_window(root)
	var content: Control = window._content
	assert_eq((content.get_node("%DetailContainer/TitleLabel") as Label).text, cm.get_lstr("herosplit.1.10.1.003"),
		"详情标题=LSTR 003（分解详情）")
	assert_eq((content.get_node("%DetailContainer/%Title2") as Label).text, cm.get_lstr("herosplit.1.10.1.005"),
		"你将获得=LSTR 005")
	assert_eq((content.get_node("%ExplainBtn") as Button).text, cm.get_lstr("herosplit.1.10.1.001"),
		"说明按钮=LSTR 001（详细规则）")
	assert_eq((content.get_node("%DetailContainer/%SplitBtn") as Button).text, cm.get_lstr("heropackage.1.10.1.001"),
		"分解按钮=LSTR heropackage.001（分解）")
	window.remove_window()
	root.queue_free()


# 窗口列出所有已拥有英雄（单机化 getSplitableHeroes → heroes.values，源联机 split_data 空壳）。
func test_window_lists_all_heroes() -> void:
	var root := Node.new()
	add_child(root)
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(_make_mgr(), cm)
	window.show_window(root)
	assert_eq(window._grid.get_child_count(), 2, "2 英雄 cell")
	window.remove_window()
	root.queue_free()


# 未选英雄 → 详情组隐藏（源 create 后 detail_container:setVisible(false) 照源）。
func test_detail_hidden_before_select() -> void:
	var root := Node.new()
	add_child(root)
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(_make_mgr(), cm)
	window.show_window(root)
	assert_false(window._detail.visible, "未选英雄详情组隐藏（源 setVisible(false)）")
	assert_false(window._split_btn.is_visible_in_tree(), "分解按钮随详情组隐藏（树内不可见）")
	window.remove_window()
	root.queue_free()


# 选英雄 → 详情组显示 + 返还预览碎片 icon（preview_split）+ 分解按钮可见。
func test_select_hero_shows_return_preview() -> void:
	var root := Node.new()
	add_child(root)
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(_make_mgr(), cm)
	window.show_window(root)
	var hero: HeroInstance = _make_mgr().heroes.values()[0]
	window._select_hero(hero)
	assert_true(window._detail.visible, "选中后详情组显示（源 setSplitStone setVisible(true)）")
	assert_true(window._split_btn.visible, "选中后分解按钮可见")
	assert_gt(window._return_host.get_child_count(), 0, "返还预览显示碎片 icon")
	window.remove_window()
	root.queue_free()


# 分解 → 英雄移除 + 碎片增加 + split_done 信号。
func test_split_removes_hero_and_adds_fragment() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := _make_mgr()
	var hero: HeroInstance = mgr.heroes.values()[0]
	var inst_id: int = hero.inst_id
	var preview: Dictionary = mgr.preview_split(inst_id)
	var frag_id: int = int(preview["fragment_id"])
	var before_count: int = int(mgr.fragments.get(frag_id, 0))
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(mgr, cm)
	window.show_window(root)
	watch_signals(window)
	window._select_hero(hero)
	window._perform_split()
	assert_eq(mgr.heroes.size(), 1, "分解后英雄数 -1")
	assert_eq(int(mgr.fragments.get(frag_id, 0)), before_count + int(preview["count"]), "碎片 +Convert Fragments")
	assert_signal_emitted(window, "split_done", "split_done 信号触发（hero_package 刷新列表）")
	window.remove_window()
	root.queue_free()


# 未选英雄点分解 → 不执行 split（源 firstConfirm 无 hid 守卫，单机化保留）。
func test_split_without_selection_no_op() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := _make_mgr()
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(mgr, cm)
	window.show_window(root)
	window._on_split_pressed()   # _selected == null → toast，不 split
	assert_eq(mgr.heroes.size(), 2, "未选英雄不分解")
	window.remove_window()
	root.queue_free()


# 两件套红线：静态结构零 .new()（白名单：网格 cell Control + 两个子弹窗构造 + icon 工厂）。
# 计数用 ".new(" 宽口径（带参构造不含 ".new()" 字面，窄口径漏检）。
func test_window_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_split_window.gd")
	assert_eq(text.count(".new("),
		text.count("Control.new(") + text.count("HeroSplitConfirm.new(") + text.count("HeroSplitExplain.new("),
		"静态节点零 .new(，仅网格 cell/子弹窗/icon 工厂白名单")


# ══ 件 2：hero_split_confirm（源 uieditor/herosplitconfirm.lua splitconfirm 窗）══

# 框架布局照源：frame Scale9 462.5x329.69 中心 (403.13,233.59)；子节点 frame 局部
# （gy=329.69-y）：title_bg(229.69,288.28)/close(430.47,294.53)/ok(231.25,50.78)/
# arrow(230.47,207.81)；icon 挂点 window.lua DGccp(195/400,262)×0.78125。
func test_confirm_layout_follows_source() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_split_confirm_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var frame: NinePatchRect = inst.get_node("Frame") as NinePatchRect
	assert_almost_eq((frame.offset_left + frame.offset_right) / 2.0, 403.13, 0.5, "frame 中心 x=483.13")
	assert_almost_eq((frame.offset_top + frame.offset_bottom) / 2.0, 480.0 - 233.59, 0.5, "frame 中心 y=326.41")
	assert_almost_eq(frame.offset_right - frame.offset_left, 462.5, 0.5, "frame 宽=源 scaleSize 462.5")
	assert_almost_eq(frame.offset_bottom - frame.offset_top, 329.69, 0.5, "frame 高=源 scaleSize 329.69")
	assert_almost_eq(frame.patch_margin_left, 58.59, 0.5, "frame 左 margin=源 cap.x")
	assert_almost_eq(frame.patch_margin_top, 252.0 - 85.94 - 15.63, 0.5, "frame 顶 margin=纹高-cap")
	assert_almost_eq(frame.patch_margin_bottom, 85.94, 0.5, "frame 底 margin=源 cap.y")
	var title_bg: NinePatchRect = frame.get_node("TitleBg") as NinePatchRect
	assert_almost_eq((title_bg.offset_left + title_bg.offset_right) / 2.0, 229.69, 0.5, "title_bg 中心 x=229.69（frame 局部）")
	assert_almost_eq((title_bg.offset_top + title_bg.offset_bottom) / 2.0, 329.69 - 288.28, 0.5,
		"title_bg 中心 y=329.69-288.28")
	assert_almost_eq(title_bg.offset_right - title_bg.offset_left, 359.38, 0.5, "title_bg 宽=源 scaleSize 359.38")
	assert_almost_eq(title_bg.patch_margin_top, 15.0 - 11.72, 0.5, "title_bg 顶 margin=纹高-cap")
	assert_almost_eq(title_bg.patch_margin_bottom, 0.0, 0.5, "title_bg 底 margin=源 cap.y=0")
	var close: TextureButton = frame.get_node("%CloseBtn") as TextureButton
	assert_almost_eq((close.offset_left + close.offset_right) / 2.0, 430.47, 0.5, "close 中心 x=430.47")
	assert_almost_eq((close.offset_top + close.offset_bottom) / 2.0, 329.69 - 294.53, 0.5, "close 中心 y=329.69-294.53")
	assert_almost_eq(close.offset_right - close.offset_left, 49.22, 0.5, "close 宽=源 fix_wh 49.22")
	var ok: Button = frame.get_node("%OkBtn") as Button
	assert_almost_eq((ok.offset_left + ok.offset_right) / 2.0, 231.25, 0.5, "ok 中心 x=231.25")
	assert_almost_eq((ok.offset_top + ok.offset_bottom) / 2.0, 329.69 - 50.78, 0.5, "ok 中心 y=329.69-50.78")
	assert_almost_eq(ok.offset_right - ok.offset_left, 118.75, 0.5, "ok 宽=源 scaleSize 118.75")
	var arrow: TextureRect = frame.get_node("Arrow") as TextureRect
	assert_almost_eq((arrow.offset_left + arrow.offset_right) / 2.0, 230.47, 0.5, "箭头中心 x=230.47")
	assert_almost_eq((arrow.offset_top + arrow.offset_bottom) / 2.0, 329.69 - 207.81, 0.5, "箭头中心 y=329.69-207.81")
	assert_almost_eq(arrow.offset_right - arrow.offset_left, 28.91, 0.5, "箭头宽=源 fix_wh 28.91")
	# icon 挂点（window.lua initWindow DGccp(195,262)/(400,262) ×0.78125 → (152.34/312.5, 204.69)）
	var icon_l: Control = frame.get_node("%IconHostL") as Control
	assert_almost_eq(icon_l.offset_left, 152.34, 0.5, "左 icon 挂点 x=DGccp(195)*")
	assert_almost_eq(icon_l.offset_bottom, 329.69 - 204.69, 0.5, "左 icon 挂点 y=329.69-204.69")
	var icon_r: Control = frame.get_node("%IconHostR") as Control
	assert_almost_eq(icon_r.offset_left, 312.5, 0.5, "右 icon 挂点 x=DGccp(400)*")


# confirm theme 表项（title 22 (255,222,16) / 警示行 20 (255,227,133) / ok 白 22）。
func test_confirm_theme_entries() -> void:
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroSplitConfirmTitleLabel"), 22,
		"confirm 标题字号 22 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroSplitConfirmTitleLabel") as Color,
		Color(1.0, 222.0 / 255.0, 16.0 / 255.0), "confirm 标题色 (255,222,16) 照源")
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroSplitConfirmWarnLabel"), 20,
		"confirm 警示行字号 20 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroSplitConfirmWarnLabel") as Color,
		Color(1.0, 227.0 / 255.0, 133.0 / 255.0), "confirm 警示行色 (255,227,133) 照源")
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroSplitConfirmOkButton"), 22,
		"ok 按钮字号 22 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroSplitConfirmOkButton") as Color,
		Color.WHITE, "ok 按钮白字照源 labelConfig ccc3(255,255,255)")


# fill：左右英雄 icon（左=当前态、右=初始态）+ 两行警示文字含英雄名。
func test_confirm_fills_hero_icons_and_text() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := _make_mgr()
	var hero: HeroInstance = mgr.heroes.values()[0]
	var confirm := HeroSplitConfirm.new()
	confirm.setup(hero, cm)
	root.add_child(confirm)
	await get_tree().process_frame
	var content: Control = confirm.get_child(0) as Control
	var icon_l: Control = content.get_node("%IconHostL") as Control
	assert_gt(icon_l.get_child_count(), 0, "左 icon 挂 ReadheroIcon（当前态）")
	var icon_r: Control = content.get_node("%IconHostR") as Control
	assert_gt(icon_r.get_child_count(), 0, "右 icon 挂 ReadheroIcon（初始态 rank1/stars/level1）")
	var warn: Label = content.get_node("%WarnLabel") as Label
	assert_eq(warn.text, cm.get_lstr("confirm.1.10.1.001"), "警示行=LSTR 001（无法撤消）")
	var ask: Label = content.get_node("%AskLabel") as Label
	var hero_name: String = confirm._hero_display_name()
	assert_true(ask.text.contains(hero_name), "确认行含英雄名")
	assert_true(ask.text.contains(cm.get_lstr("confirm.1.10.1.002")), "确认行含 LSTR 002（是否确认分解英雄）")
	confirm.queue_free()
	root.queue_free()


# ok 按钮 → confirmed 信号 + 自毁（源 ok_button doSplit+destroy）。
func test_confirm_ok_emits_confirmed() -> void:
	var root := Node.new()
	add_child(root)
	var hero: HeroInstance = _make_mgr().heroes.values()[0]
	var confirm := HeroSplitConfirm.new()
	confirm.setup(hero, cm)
	root.add_child(confirm)
	await get_tree().process_frame
	watch_signals(confirm)
	confirm._on_ok()
	assert_signal_emitted(confirm, "confirmed", "ok 触发 confirmed")
	await get_tree().process_frame
	assert_false(is_instance_valid(confirm), "ok 后窗口销毁")
	if is_instance_valid(root):
		root.queue_free()


# 源 splitconfirm 无取消按钮（close 即取消）→ 迁移发明的 CancelBtn 已删。
func test_confirm_has_no_cancel_button() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_split_confirm_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	assert_null(inst.get_node_or_null("Frame/%CancelBtn"), "无取消按钮（源 splitconfirm 只有 close/ok）")
	assert_null(inst.find_child("CancelBtn", true, false), "全树无 CancelBtn 残留")


# ══ 件 3：hero_split_explain（uieditor/explainwindow.lua 通用窗 + explain.lua 文本）══

# 框架布局照源：window_container(183.59,398.44) 子层 → frame main_vit_tips 548.44x378.91
# anchor(0,1) at (-58.59,31.25) → 世界左上 (125,429.69)；title_bg/close/title 同层；
# draglist cliprect DGRectMake(200,98,622,362)×0.78125 → 显示 (156.25,76.56,485.94,282.81)。
func test_explain_layout_follows_source() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_split_explain_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var frame: NinePatchRect = inst.get_node("Frame") as NinePatchRect
	assert_almost_eq(frame.offset_left, 125.0, 0.5, "frame 左=源世界 x+80")
	assert_almost_eq(frame.offset_top, 480.0 - 429.69, 0.5, "frame 顶=560-源世界顶 y")
	assert_almost_eq(frame.offset_right - frame.offset_left, 548.44, 0.5, "frame 宽=源 scaleSize 548.44")
	assert_almost_eq(frame.offset_bottom - frame.offset_top, 378.91, 0.5, "frame 高=源 scaleSize 378.91")
	assert_almost_eq(frame.patch_margin_left, 17.19, 0.5, "frame 左 margin=源 cap.x")
	assert_almost_eq(frame.patch_margin_top, 61.0 - 17.19 - 15.63, 0.5, "frame 顶 margin=纹高-cap")
	assert_almost_eq(frame.patch_margin_bottom, 17.19, 0.5, "frame 底 margin=源 cap.y")
	var title_bg: NinePatchRect = inst.get_node("TitleBg") as NinePatchRect
	assert_almost_eq((title_bg.offset_left + title_bg.offset_right) / 2.0, 398.44, 0.5,
		"title_bg 中心 x=478.44（世界）")
	assert_almost_eq(title_bg.offset_right - title_bg.offset_left, 480.47, 0.5, "title_bg 宽=源 scaleSize 480.47")
	assert_almost_eq(title_bg.patch_margin_top, 44.0 - 34.38, 0.5, "title_bg 顶 margin=纹高-cap")
	assert_almost_eq(title_bg.patch_margin_bottom, 0.0, 0.5, "title_bg 底 margin=源 cap.y=0")
	var close: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq((close.offset_left + close.offset_right) / 2.0, 659.38, 0.5, "close 中心 x=739.38（世界）")
	assert_almost_eq(close.offset_right - close.offset_left, 49.22, 0.5, "close 宽=源 fix_wh 49.22")
	var scroll: ScrollContainer = inst.get_node("%ScrollHost") as ScrollContainer
	assert_almost_eq(scroll.offset_left, 156.25, 0.5, "scroll 左=cliprect x*0.78125+80")
	assert_almost_eq(scroll.offset_top, 480.0 - 76.56 - 282.81, 0.5, "scroll 顶=560-cliprect 顶底")
	assert_almost_eq(scroll.offset_right - scroll.offset_left, 485.94, 0.5, "scroll 宽=cliprect 宽")
	assert_almost_eq(scroll.offset_bottom - scroll.offset_top, 282.81, 0.5, "scroll 高=cliprect 高")


# 4 行规则文本（源 explain.lua text_list LSTR 001-004）+ 源 dy=3 行距。
func test_explain_four_rows_lstr() -> void:
	var root := Node.new()
	add_child(root)
	var explain := HeroSplitExplain.new()
	explain.setup(cm)
	root.add_child(explain)
	await get_tree().process_frame
	var content: Control = explain.get_child(0) as Control
	var vbox: VBoxContainer = content.get_node("%ScrollHost/ListHost") as VBoxContainer
	assert_eq(vbox.get_child_count(), 4, "4 行规则文本")
	assert_eq(vbox.get("theme_override_constants/separation"), 3, "行距=源 dy 3")
	for i in 4:
		var lbl: Label = vbox.get_child(i) as Label
		assert_eq(lbl.text, cm.get_lstr("explain.1.10.1.00%d" % (i + 1)), "第 %d 行=LSTR 00%d" % [i + 1, i + 1])
		assert_almost_eq(lbl.offset_right - lbl.offset_left, 478.13, 0.5,
			"行宽=源 label_dimensions DGSizeMake(612,0)*0.78125")
	explain.queue_free()
	root.queue_free()


# 标题=LSTR PVP.RULE_DESCRIPTION（源 explainwindow 通用窗标题，herosplit 复用）。
func test_explain_title_lstr() -> void:
	var root := Node.new()
	add_child(root)
	var explain := HeroSplitExplain.new()
	explain.setup(cm)
	root.add_child(explain)
	await get_tree().process_frame
	var content: Control = explain.get_child(0) as Control
	assert_eq((content.get_node("%TitleLabel") as Label).text, cm.get_lstr("PVP.RULE_DESCRIPTION"),
		"标题=规则说明（源 PVP.RULE_DESCRIPTION）")
	explain.queue_free()
	root.queue_free()


# explain theme 表项（title 24 (234,171,41) / 正文 16 (238,204,119)）。
func test_explain_theme_entries() -> void:
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroSplitExplainTitleLabel"), 24,
		"explain 标题字号 24 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroSplitExplainTitleLabel") as Color,
		Color(234.0 / 255.0, 171.0 / 255.0, 41.0 / 255.0), "explain 标题色 (234,171,41) 照源")
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroSplitExplainBodyLabel"), 16,
		"explain 正文字号 16 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroSplitExplainBodyLabel") as Color,
		Color(238.0 / 255.0, 204.0 / 255.0, 119.0 / 255.0), "explain 正文色 (238,204,119) 照源")
