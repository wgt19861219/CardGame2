extends GutTest

# DungeonDegreePopup 守卫测试（批 3 Task 2 两件套，2026-08-16）。
# 照源 dungeon_map.lua:256-438 showDegreePopup + :446-520 popupTouchHandler
# （brief 源对照表"dungeon.lua 367 行"系误配——该文件为副本入口列表弹窗，
# 难度弹窗真源即现 panel 头注所指 dungeon_map.lua showDegreePopup 段）。
# 点空间直译口径（批 3 Task 1 定稿）：frame 子树坐标是 frame contentSize(705x300)
# 左下原点点值直译（y' = 300-y），close 是 container 场景空间走 to_godot；
# 贴图显示尺寸 = 像素/CS(1.28125)（本弹窗全部贴图无 TextureConfig 条目，实测 2026-08-16）。
# 守卫：content/item 静态树 rect / NinePatch cap 公式 / variation 接线 /
# panel 零静态构造 / fill 语义（格定位/灰态/icon 等比居中）/ 信号流 / 绘制序。

const CONTENT_PATH: String = "res://scenes/ui/dungeon_degree_popup_content.tscn"
const ITEM_PATH: String = "res://scenes/ui/dungeon_degree_item.tscn"
const PANEL_PATH: String = "res://scripts/ui/dungeon_degree_popup.gd"
const THEME_PATH: String = "res://resources/themes/default_theme.tres"
# 难度按钮点尺寸 = act_select_bg 221x195 像素 / CS = 172.49x152.20。
const BTN_W: float = 172.49
const BTN_H: float = 152.20


# ── content 静态树（源 :269-301 ui_info：frame(400,220) scaleSize(705,300) /
# close(750,350)；:304-326 title frame 局部(352,272)）──

func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# Frame（源 Scale9 main_vit_tips cap(10,10,58,26) scaleSize(705,300) 中心(400,220)
	# → Godot (480,340) → [480-352.5, 340-150, 480+352.5, 340+150]）
	var frame: NinePatchRect = inst.get_node("%Frame") as NinePatchRect
	assert_almost_eq(frame.offset_left, 47.5, 0.1, "Frame 左 = 480-705/2（to_godot(400,220)）")
	assert_almost_eq(frame.offset_top, 110.0, 0.1, "Frame 顶 = 340-300/2")
	assert_almost_eq(frame.offset_right - frame.offset_left, 705.0, 0.1, "Frame 宽 = 源 scaleSize 直译")
	assert_almost_eq(frame.offset_bottom - frame.offset_top, 300.0, 0.1, "Frame 高 = 源 scaleSize 直译")
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/main_vit_tips.png",
		"Frame 贴图照源 main_vit_tips")
	# cap(10,10,58,26) 批 1 公式（贴图 103x61）：left=10 top=61-10-26=25 right=103-10-58=35 bottom=10
	assert_eq(frame.patch_margin_left, 10, "NinePatch left = cap.x")
	assert_eq(frame.patch_margin_top, 25, "NinePatch top = H-y-h = 61-10-26")
	assert_eq(frame.patch_margin_right, 35, "NinePatch right = W-x-w = 103-10-58（水平不反转）")
	assert_eq(frame.patch_margin_bottom, 10, "NinePatch bottom = cap.y")
	# CloseBtn（源 close 中心(750,350)，65x66 像素/CS = 50.73x51.51 → [804.63,184.24,855.37,235.76]）
	var close_btn: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(close_btn.offset_left, 724.63, 0.1, "CloseBtn 左 = 830-50.73/2（to_godot(750,350)）")
	assert_almost_eq(close_btn.offset_top, 104.24, 0.1, "CloseBtn 顶 = 210-51.51/2")
	assert_almost_eq(close_btn.offset_right - close_btn.offset_left, 50.73, 0.1, "CloseBtn 宽 = 65/CS")
	assert_almost_eq(close_btn.offset_bottom - close_btn.offset_top, 51.51, 0.1, "CloseBtn 高 = 66/CS")
	assert_eq(close_btn.texture_pressed.resource_path,
		"res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png",
		"源 close_press Sprite visible 切换 → texture_pressed 等价")
	assert_eq(close_btn.stretch_mode, TextureButton.STRETCH_SCALE,
		"TextureButton stretch_mode=0 显式（默认 KEEP 不填 rect，批 2 方法论）")
	# TitleLabel（源 title frame 局部(352,272) 中心锚 → Frame 内中心 (352, 300-272=28)；
	# fontinfo ui_normal_button + 金(231,206,19) 与 exercise title 同款（:304-323））
	var title: Label = inst.get_node("%TitleLabel") as Label
	assert_almost_eq(title.anchor_left, 0.5, 0.001, "Title 中心锚（源 readnode Label 默认锚(0.5,0.5)）")
	assert_almost_eq(title.anchor_right, 0.5, 0.001, "Title 四锚同点 + offsets（禁单侧锚点写法）")
	assert_almost_eq(title.anchor_top, 28.0 / 300.0, 0.001, "Title 锚 y = 28/300（frame 局部 y'=300-272）")
	assert_almost_eq(title.offset_right - title.offset_left, 160.0, 0.1, "Title 宽 160（17 号占位）")
	assert_eq(String(title.theme_type_variation), "ExerciseTitleLabel",
		"Title 走 ExerciseTitleLabel（源 fontinfo=ui_normal_button 同 exercise :766-776 定稿）")
	# DegreeHost（难度格宿主，Frame 全域；源按钮 readnode root=ui.frame）
	var host: Control = inst.get_node("%DegreeHost") as Control
	assert_almost_eq(host.offset_right - host.offset_left, 705.0, 0.1, "DegreeHost 覆盖 Frame 全域")
	assert_eq(host.mouse_filter, Control.MOUSE_FILTER_IGNORE, "DegreeHost 装饰容器不吞点击")


# ── item 行模板静态树（源 :337-401 btn_info：button/button_press/button_icon/
# vit_bg/vit_number/vit_icon；格 = button 行+vit 行纵向并集）──

func test_item_static_tree() -> void:
	var inst: Control = (load(ITEM_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# DiffBtn（源 act_select_bg 221x195/CS=172.49x152.20，格内 [0,0] 起）
	var btn: TextureButton = inst.get_node("%DiffBtn") as TextureButton
	assert_almost_eq(btn.offset_left, 0.0, 0.01, "DiffBtn 贴格左上")
	assert_almost_eq(btn.offset_top, 0.0, 0.01, "DiffBtn 顶 = 格顶（源 button 中心 y=140 顶界）")
	assert_almost_eq(btn.offset_right - btn.offset_left, BTN_W, 0.1, "DiffBtn 宽 = 221/CS")
	assert_almost_eq(btn.offset_bottom - btn.offset_top, BTN_H, 0.1, "DiffBtn 高 = 195/CS")
	assert_eq(btn.texture_normal.resource_path, "res://assets/ui/alpha/HVGA/act/act_select_bg.png",
		"DiffBtn normal 照源 act_select_bg")
	assert_eq(btn.texture_pressed.resource_path,
		"res://assets/ui/alpha/HVGA/act/act_select_bg_chosen.png",
		"源 button_press Sprite visible 切换 → texture_pressed 等价")
	assert_eq(btn.stretch_mode, TextureButton.STRETCH_SCALE, "DiffBtn stretch_mode=0 显式")
	# DiffIcon（源 button_icon mediate=true 居中于 button，act_icon_difficulty_1 165x165/CS=128.78）
	var icon: TextureRect = inst.get_node("%DiffIcon") as TextureRect
	assert_almost_eq(icon.position.x + icon.size.x * 0.5, BTN_W * 0.5, 0.1,
		"Icon 中心 x = 按钮中心（源 mediate=parent contentSize/2）")
	assert_almost_eq(icon.position.y + icon.size.y * 0.5, BTN_H * 0.5, 0.1, "Icon 中心 y = 按钮中心")
	assert_almost_eq(icon.size.x, 128.78, 0.1, "Icon 宽 = 165/CS（占位 diff1，fill 覆盖）")
	assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Icon 装饰不吞点击")
	# VitBg（源 act_comment_bg 182x44/CS=141.95x34.34 中心(x,45) → 格内中心 y=171.10）
	var vit_bg: TextureRect = inst.get_node("%VitBg") as TextureRect
	assert_almost_eq(vit_bg.position.x + vit_bg.size.x * 0.5, BTN_W * 0.5, 0.1,
		"VitBg 中心 x = 格中心（源 vit_bg 中心 x 与 button 同列）")
	assert_almost_eq(vit_bg.size.x, 141.95, 0.1, "VitBg 宽 = 182/CS")
	assert_almost_eq(vit_bg.size.y, 34.34, 0.1, "VitBg 高 = 44/CS")
	# VitIcon（源 vitalityicon 47x63 fix_height=35 → scale=35/49.17 显示 26.11x35；
	# anchor(0,0.5) 左端 x+5）
	var vit_icon: TextureRect = inst.get_node("%VitIcon") as TextureRect
	assert_almost_eq(vit_icon.size.y, 35.0, 0.1, "VitIcon 高 = 源 fix_height 直译")
	assert_almost_eq(vit_icon.size.x, 26.11, 0.1, "VitIcon 宽 = 47/CS*35/(63/CS) 等比（fix_height 系 scale）")
	assert_almost_eq(vit_icon.position.x - BTN_W * 0.5, 5.0, 0.1, "VitIcon 左端 = 中心+5（源 anchor(0,0.5) x+5）")
	assert_almost_eq(vit_icon.position.y + vit_icon.size.y * 0.5,
		vit_bg.position.y + vit_bg.size.y * 0.5, 0.1, "VitIcon 与 VitBg 同水平中心（源同 y=ly）")
	# VitNum（源 18 号 (233,214,181) anchor(1,0.5) 右端 x-5）
	var vit_num: Label = inst.get_node("%VitNum") as Label
	assert_almost_eq(BTN_W * 0.5 - (vit_num.position.x + vit_num.size.x), 5.0, 0.1,
		"VitNum 右端 = 中心-5（源 anchor(1,0.5) x-5，数字在图标左侧）")
	assert_eq(vit_num.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "VitNum 右对齐（右端锚定）")
	assert_eq(String(vit_num.theme_type_variation), "DungeonVitNumberLabel",
		"VitNum 走 DungeonVitNumberLabel variation")


# 照源 :337-401 难度按钮只有 icon（无难度名 Label），难度区分由图标承担
# （原项目自造 DIFF_LABELS/DIFF_COLORS + name_lbl 是无源发明，已照源移除）。
func test_degree_button_has_no_name_label() -> void:
	var inst: Control = (load(ITEM_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var btn: TextureButton = inst.get_node("%DiffBtn") as TextureButton
	for i in range(btn.get_child_count()):
		assert_false(btn.get_child(i) is Label,
			"源难度按钮无难度名 Label（仅 icon + 格内 vit 行）")
	var has_icon := false
	for i in range(btn.get_child_count()):
		if btn.get_child(i) is TextureRect:
			has_icon = true
	assert_true(has_icon, "难度按钮含 icon TextureRect（源 :358-366 button_icon）")


# 照源 :318 text = boss.name or ""（无 fallback）；空名不自造"选择难度"文案。
func test_title_no_fallback_when_empty() -> void:
	var popup: DungeonDegreePopup = DungeonDegreePopup.new("dungeonDegree", {})
	var diffs: Array = [{"diff": 1, "unlock_level": 1, "vit": 10}]
	popup.setup_popup(1, "", diffs, 80)
	var title: Label = popup._content.get_node("%TitleLabel") as Label
	assert_eq(title.text, "", "源空名无 fallback（不自造选择难度）")
	popup.free()


# fill 语义：格定位（源 :330-332 ox=97 dx=170 oy=140 ly=45；
# 格左 = 97-86.24 + 170*(di-1)，格顶 = 300-140-152.20/2 = 83.90）+ 数量随 difficulties。
func test_setup_popup_fills_grid() -> void:
	var popup: DungeonDegreePopup = DungeonDegreePopup.new("dungeonDegree", {})
	var diffs: Array = [
		{"diff": 1, "unlock_level": 1, "vit": 10},
		{"diff": 2, "unlock_level": 1, "vit": 20},
		{"diff": 3, "unlock_level": 90, "vit": 30},
	]
	popup.setup_popup(1, "boss_a", diffs, 80)
	add_child_autofree(popup)
	var host: Control = popup._content.get_node("%DegreeHost") as Control
	assert_eq(host.get_child_count(), 3, "格数随 difficulties（源 ipairs 实际数量）")
	var first: Control = host.get_child(0) as Control
	assert_almost_eq(first.position.x, 10.76, 0.1, "格1 左 = 97-172.49/2（源 ox=97 中心锚）")
	assert_almost_eq(first.position.y, 83.90, 0.1, "格顶 = 300-140-152.2/2（源 oy=140 中心锚）")
	var second: Control = host.get_child(1) as Control
	assert_almost_eq(second.position.x - first.position.x, 170.0, 0.1, "格距 = 源 dx=170 直译")
	# vit 数值 fill
	var num: Label = second.get_node("%VitNum") as Label
	assert_eq(num.text, "20", "VitNum fill diff.vit")
	# 灰态（源 :335 :407-409 unlockLevel > level → setSpriteGray + touch 不响应）
	var locked_btn: TextureButton = (host.get_child(2) as Control).get_node("%DiffBtn") as TextureButton
	assert_true(locked_btn.disabled, "未解锁难度 disabled（源 isUnlock 才进 press 判定）")
	assert_almost_eq(locked_btn.modulate.v, 0.4, 0.01, "未解锁置灰 modulate 0.4（源 setSpriteGray 等价）")
	var open_btn: TextureButton = (host.get_child(0) as Control).get_node("%DiffBtn") as TextureButton
	assert_almost_eq(open_btn.modulate.v, 1.0, 0.01, "已解锁不灰")


# icon fill 等比居中（源 :358-366 mediate 居中不缩放；diff4 贴图 174x174/CS=135.80）。
func test_icon_fill_size_centered() -> void:
	var popup: DungeonDegreePopup = DungeonDegreePopup.new("dungeonDegree", {})
	var diffs: Array = [{"diff": 4, "unlock_level": 1, "vit": 40}]
	popup.setup_popup(1, "boss_b", diffs, 80)
	add_child_autofree(popup)
	var host: Control = popup._content.get_node("%DegreeHost") as Control
	var icon: TextureRect = (host.get_child(0) as Control).get_node("%DiffIcon") as TextureRect
	assert_eq(icon.texture.resource_path,
		"res://assets/ui/alpha/HVGA/act/act_icon_difficulty_4.png", "Icon fill iconres[di]")
	assert_almost_eq(icon.size.x, 135.80, 0.1, "diff4 宽 = 174/CS（贴图驱动）")
	assert_almost_eq(icon.size.y, 135.80, 0.1, "diff4 方形等比")
	assert_almost_eq(icon.position.x + icon.size.x * 0.5, BTN_W * 0.5, 0.1, "fill 后仍居中按钮")


# theme variation 接线（GUT 下节点级不解析 variation，读 tres 文本表项）。
# 源 vit_number：:376-388 createttf size=18 + ccc3(233,214,181)。
# Title 复用 ExerciseTitleLabel（源 fontinfo=ui_normal_button 同 exercise 定稿 17 号金影）。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("DungeonVitNumberLabel/font_sizes/font_size = 18"),
		"DungeonVitNumberLabel 字号 18（源 size=18）")
	assert_true(t.contains("DungeonVitNumberLabel/colors/font_color = Color(0.913725, 0.839216, 0.709804, 1)"),
		"DungeonVitNumberLabel 色 = 233,214,181（/255）")
	assert_true(t.contains("ExerciseTitleLabel/font_sizes/font_size = 17"),
		"Title 复用 ExerciseTitleLabel（源 fontinfo ui_normal_button 同款，不新增）")


# panel 零静态构造（宽口径白名单）：两件套后静态结构全在 tscn，
# 难度格走行模板 instantiate（动态行 SOP），panel 内 .new( 应为 0。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count(".new("), 0,
		"panel 零 .new(（7 处旧构造全数消亡/入模板：VBox/HBox 迁移发明删除，按钮/icon/vit 行进 item tscn）")


# 绘制序守卫（源 readnode 声明序：frame(:271) → close(:281) → title 后挂 frame(:325)
# → 难度按钮最后逐格挂 frame(:404)）：CloseBtn 后于 Frame（兄弟），
# DegreeHost 后于 TitleLabel（Frame 内同父）防反盖。
func test_content_draw_order() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var frame: CanvasItem = inst.get_node("%Frame") as CanvasItem
	var close_btn: CanvasItem = inst.get_node("%CloseBtn") as CanvasItem
	var title: CanvasItem = inst.get_node("%TitleLabel") as CanvasItem
	var host: CanvasItem = inst.get_node("%DegreeHost") as CanvasItem
	assert_eq(title.get_parent(), frame, "Title 挂 Frame 子树（源 title frame:addChild）")
	assert_eq(host.get_parent(), frame, "DegreeHost 挂 Frame 子树（源按钮 readnode root=ui.frame）")
	assert_lt(frame.get_index(), close_btn.get_index(), "Frame 先于 CloseBtn（源声明序）")
	assert_lt(title.get_index(), host.get_index(), "Title 先于难度格（源 title_info 先于按钮循环）")


# 信号流（源 popupTouchHandler ended：难度命中 → 进战斗（Godot 侧 emit
# degree_selected 由调用方装配）；close → destroyPopup）。
func test_degree_selected_signal_and_close() -> void:
	var popup: DungeonDegreePopup = DungeonDegreePopup.new("dungeonDegree", {})
	var diff: Dictionary = {"diff": 2, "unlock_level": 1, "vit": 20}
	popup.setup_popup(1, "boss_c", [diff], 80)
	add_child_autofree(popup)
	watch_signals(popup)
	var host: Control = popup._content.get_node("%DegreeHost") as Control
	var btn: TextureButton = (host.get_child(0) as Control).get_node("%DiffBtn") as TextureButton
	btn.pressed.emit()
	# GUT 此断言第 4 参是 index(int) 非 message，说明文字并进此行注释
	assert_signal_emitted_with_parameters(popup, "degree_selected", [1, diff])
	assert_signal_emitted(popup, "close_requested", "选难度后关窗（源 destroyPopup 后进战斗）")

	var popup2: DungeonDegreePopup = DungeonDegreePopup.new("dungeonDegree", {})
	popup2.setup_popup(1, "boss_d", [{"diff": 1, "unlock_level": 1, "vit": 10}], 80)
	add_child_autofree(popup2)
	watch_signals(popup2)
	(popup2._content.get_node("%CloseBtn") as BaseButton).pressed.emit()
	assert_signal_emitted(popup2, "close_requested", "CloseBtn emit close_requested（源 destroy）")
	assert_signal_not_emitted(popup2, "degree_selected", "关窗不选难度")
