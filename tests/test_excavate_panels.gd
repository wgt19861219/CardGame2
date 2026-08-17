extends GutTest
# Excavate UI Panel 测试（View 层）— 7 panel 照源精修后的 LSTR 化 + 装配验证。
# 照源 ui/excavate/map.lua + search.lua + popwindow/excavateteam.lua + excavatehistory.lua
# + excavatebattlereport.lua + excavateexplain.lua + excavate/giveup.lua。
# P1（2026-07-16）：LSTR key 路由 + fallback 兜底 + 关键装配（按钮/backbtn/Scale9/bg.jpg）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ── ExcavateExplainPanel：LSTR 化（21 处 key 全在 JSON）──

# 解释面板应加载 4 行故事 + 16 行规则 LSTR（无 fallback 出现说明 key 全命中）。
func test_explain_lstr_keys_all_present() -> void:
	# 此测试验证 LSTR JSON 完整性（excavateexplain.lua 全 21 key 应在表里）
	var keys: Array[String] = [
		"EXCAVATEEXPLAIN.DARK_IRON_DWARVES_KINGDOM_BUILDING_IN_THE_GROUND_MORE_WRONG_SECTION_OF_THE_HOLE_DISK_AS_THE_ROOT_OF_THE_TREE_OF_THE_WORLD_TO_BE",
		"EXCAVATEEXPLAIN._ANUBAR_WARS",
		"EXCAVATEEXPLAIN.1_IN_THE_TREASURE_CRYPT_YOU_CAN_FIND_A_VARIETY_OF_RESOURCE_POINTS_INCLUDING_GOLD_DIAMOND_AND_LABORATORY",
		"EXCAVATEEXPLAIN.10_IN_THE_TREASURE_CRYPT_BATTLE_THE_HERO_OF_THE_DEFENSE_WILL_GET_SOME_INITIAL_ENERGY",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中（非 fallback 返 key 本身）：" + k)
		assert_false(v.is_empty(), "LSTR 值非空：" + k)


# ExcavateExplainPanel 装配无异常（ScrollContainer + VBox + 静态标签 fill）
func test_explain_panel_builds_without_error() -> void:
	var root := Node.new()
	add_child(root)
	var panel := ExcavateExplainPanel.new("excavate_explain", {})
	panel.setup_panel()
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "container 非空（content 已装配）")
	panel.remove_window()
	root.queue_free()


# A 类债 #3 归源（excavate 批 Task 2，2026-08-17）：explain 框走 explainwindow
# 通用说明窗（uieditor/explainwindow.lua:22-41 Scale9Sprite main_vit_tips
# cap(17.19,17.19,46.88,15.63)@103x61 像素直译：L=17.19→17、B=17.19→17、
# R=103-17.19-46.88=38.93→39、T=61-17.19-15.63=28.18→28），
# scaleSize 548.44x378.91 anchor(0,1) 局部 (-58.59,31.25)@window_container(183.59,398.44)
# → 世界左上 (125,429.69) → Godot (205,130.31)-(753.44,509.22)。
# 弃 excavate_main_frame 误用（600x440 强拉，ratio 1.364 vs 纹理 1.613 偏差 15.5%）。
func test_explain_frame_source_fidelity() -> void:
	var content: Control = (load("res://scenes/ui/excavate_explain_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: NinePatchRect = content.get_node_or_null("Frame") as NinePatchRect
	assert_not_null(frame, "Frame 存在且为 NinePatchRect（源 Scale9Sprite）")
	if frame == null:
		content.queue_free()
		return
	assert_not_null(frame.texture, "frame 有贴图")
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/main_vit_tips.png",
		"frame 贴图归源 main_vit_tips（explainwindow 通用窗，弃 excavate_main_frame 误用）")
	assert_eq(frame.patch_margin_left, 17, "cap left=17.19 取整 17")
	assert_eq(frame.patch_margin_bottom, 17, "cap bottom=17.19 取整 17")
	assert_eq(frame.patch_margin_right, 39, "cap right=38.93 取整 39")
	assert_eq(frame.patch_margin_top, 28, "cap top=28.18 取整 28")
	content.queue_free()


# 静态 rect 守卫（防 parenting 回归）：照 uieditor/explainwindow.lua 声明表直译。
# title_bg 480.47x39.06 中心 (214.84,-8.59)→世界 (398.44,389.84)→Godot (478.44,170.16)；
# title size24 中心 (212.5,-8.59)→(476.09,170.16)；close fix_wh 49.22x52.34 中心 (475.78,11.72)
# →世界 (659.38,410.16)→Godot (739.38,149.84) 骑框右上边；scroll=源 createListLayer
# cliprect DGRectMake(200,98,622,362)×0.78125=(156.25,76.56,485.94,282.81)→Godot
# (236.25,200.63)-(722.19,483.44)；ListHost 局部 (3.75,9.37)（left_x 160-156.25 / clip 顶 359.37-350）。
func test_explain_content_static_rects() -> void:
	var content: Control = (load("res://scenes/ui/excavate_explain_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: Control = content.get_node("Frame") as Control
	assert_almost_eq(frame.position.x, 205.0, 0.02, "frame offset_left=205")
	assert_almost_eq(frame.position.y, 130.31, 0.02, "frame offset_top=130.31")
	assert_almost_eq(frame.size.x, 548.44, 0.02, "frame w=548.44（scaleSize 直译）")
	assert_almost_eq(frame.size.y, 378.91, 0.02, "frame h=378.91")
	var title_bg: Control = content.get_node("TitleBg") as Control
	assert_almost_eq(title_bg.position.x + title_bg.size.x * 0.5, 478.44, 0.02, "title_bg 中心 x=478.44")
	assert_almost_eq(title_bg.position.y + title_bg.size.y * 0.5, 170.16, 0.02, "title_bg 中心 y=170.16")
	assert_almost_eq(title_bg.size.x, 480.47, 0.02, "title_bg w=480.47")
	var title: Control = content.get_node("%TitleLabel") as Control
	assert_almost_eq(title.position.x + title.size.x * 0.5, 476.09, 0.02, "title 中心 x=476.09")
	assert_almost_eq(title.position.y + title.size.y * 0.5, 170.16, 0.02, "title 中心 y=170.16")
	var close_btn: Control = content.get_node("%CloseBtn") as Control
	assert_almost_eq(close_btn.position.x + close_btn.size.x * 0.5, 739.38, 0.02, "close 中心 x=739.38")
	assert_almost_eq(close_btn.position.y + close_btn.size.y * 0.5, 149.84, 0.02, "close 中心 y=149.84 骑框右上")
	# 纵横比守卫（对齐 scan_texture_aspect 8% 判据）：显示 49.22/52.34=0.9404 vs 纹理 65/66=0.9848 偏差 4.5%
	var tex: Texture2D = (content.get_node("%CloseBtn") as TextureButton).texture_normal
	var ratio_dev: float = abs(close_btn.size.x / close_btn.size.y - float(tex.get_width()) / float(tex.get_height())) / (float(tex.get_width()) / float(tex.get_height()))
	assert_lt(ratio_dev, 0.08, "close 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (ratio_dev * 100.0))
	var scroll: Control = content.get_node("%ScrollHost") as Control
	assert_almost_eq(scroll.position.x, 240.0, 0.02, "scroll offset_left=240（cliprect 156.25+3.75 内边距烘入，场景 160）")
	assert_almost_eq(scroll.position.y, 210.0, 0.02, "scroll offset_top=210（200.63+9.37 内边距烘入，场景 350）")
	assert_almost_eq(scroll.position.x + scroll.size.x, 722.19, 0.02, "scroll 右缘=clip 右 722.19")
	assert_almost_eq(scroll.position.y + scroll.size.y, 483.44, 0.02, "scroll 底缘=clip 底 483.44")
	# ScrollContainer 接管子项 position（恒滚动偏移 0），源内边距已烘进 scroll rect
	var list_host: Control = content.get_node("%ListHost") as Control
	assert_almost_eq(list_host.position.x, 0.0, 0.02, "ListHost x=0（滚动接管，边距在 scroll rect）")
	assert_almost_eq(list_host.position.y, 0.0, 0.02, "ListHost y=0（滚动接管）")
	var rule_row: Control = content.get_node("%RuleRow1") as Control
	assert_almost_eq(rule_row.size.x, 478.13, 0.02, "行宽=源 label_dimensions 612x0×0.78125=478.13")
	# 绘制序守卫（防重排反盖）：框最底层 → 标题条/标题 → 关闭钮最上层（源 z 0/1/1/20）
	assert_lt(content.get_node("Frame").get_index(), content.get_node("TitleBg").get_index(), "frame 声明序先于 title_bg")
	assert_lt(content.get_node("TitleBg").get_index(), content.get_node("%TitleLabel").get_index(), "title_bg 先于 title")
	assert_lt(content.get_node("%TitleLabel").get_index(), content.get_node("%CloseBtn").get_index(), "close 最后声明（最上层）")
	content.queue_free()


# 旧范式退役守卫（两件套 SOP）：panel.gd 源码无运行时样式/节点构造。
func test_explain_no_legacy_runtime_styling() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/excavate_explain_panel.gd")
	assert_false(src.contains("UiScale9Button"), "UiScale9Button 已退役")
	assert_false(src.contains("add_theme_color_override"), "运行时颜色 override 已退役")
	assert_false(src.contains("add_theme_font_size_override"), "运行时字号 override 已退役")
	assert_false(src.contains(".new("), "无运行时节点构造（23 行 label 全静态进 tscn）")


# fill 守卫：标题/故事 4 行+签名/规则 18 行 LSTR 全命中，行结构照源
# （签名右对齐 anchor(1,1)@rx=634；签名后 +20 间距 → VBox sep3+gap17）。
func test_explain_fill_labels() -> void:
	var root := Node.new()
	add_child(root)
	var panel := ExcavateExplainPanel.new("excavate_explain", {})
	panel.setup_panel()
	panel.show_window(root)
	var content: Control = panel.container.get_node("ExcavateExplainContent") as Control
	assert_not_null(content, "content 已装配")
	if content == null:
		panel.remove_window()
		root.queue_free()
		return
	assert_eq((content.get_node("%TitleLabel") as Label).text, cm.get_lstr("PVP.RULE_DESCRIPTION"),
		"标题归源 PVP.RULE_DESCRIPTION（弃迁移发明『藏宝地穴说明』）")
	var list_host: VBoxContainer = content.get_node("%ListHost") as VBoxContainer
	assert_eq(list_host.get_child_count(), 24, "ListHost 24 子节点（4 故事+1 签名+1 gap+18 规则）")
	var story_keys: Array[String] = [
		"EXCAVATEEXPLAIN.DARK_IRON_DWARVES_KINGDOM_BUILDING_IN_THE_GROUND_MORE_WRONG_SECTION_OF_THE_HOLE_DISK_AS_THE_ROOT_OF_THE_TREE_OF_THE_WORLD_TO_BE",
		"EXCAVATEEXPLAIN.BUT_ITS_HISTORY_OLDER_THAN_THE_WORLD_TREE_ITSELF_WHEN_THESE_DORMANT_FOR_MILLIONS_OF_YEARS_OF_HEAVY_TREASURE",
		"EXCAVATEEXPLAIN.SEE_THE_LIGHT_EXPLORERS_WERE_SURPRISED_TO_HAVE_FOUND_GOLD_AND_DIAMONDS_ARE_STILL_DWARVES_TIMELESS_A",
		"EXCAVATEEXPLAIN.DUST_IS_NOT_DYED_BUT_WITH_GOLD_AS_ETERNAL_HUMAN_GREED_AND_PLUNDER",
	]
	for i: int in story_keys.size():
		var row: Label = content.get_node("%%StoryRow%d" % (i + 1)) as Label
		assert_eq(row.text, cm.get_lstr(story_keys[i]), "故事行 %d LSTR fill" % (i + 1))
		assert_false(row.text.is_empty(), "故事行 %d 非空" % (i + 1))
	var sign: Label = content.get_node("%StorySign") as Label
	assert_eq(sign.text, cm.get_lstr("EXCAVATEEXPLAIN._ANUBAR_WARS"), "签名 LSTR fill")
	assert_eq(sign.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "签名右对齐（源 anchor(1,1)@rx）")
	var gap: Control = content.get_node("%StoryGap") as Control
	assert_almost_eq(gap.custom_minimum_size.y, 17.0, 0.02, "签名后 20 间距 = sep3+gap17")
	for i: int in [1, 18]:
		var rule: Label = content.get_node("%%RuleRow%d" % i) as Label
		assert_false(rule.text.is_empty(), "规则行 %d 非空" % i)
	assert_eq((content.get_node("%RuleRow1") as Label).text,
		cm.get_lstr("EXCAVATEEXPLAIN.1_IN_THE_TREASURE_CRYPT_YOU_CAN_FIND_A_VARIETY_OF_RESOURCE_POINTS_INCLUDING_GOLD_DIAMOND_AND_LABORATORY"),
		"规则行 1 LSTR fill")
	assert_eq((content.get_node("%RuleRow18") as Label).text,
		cm.get_lstr("EXCAVATEEXPLAIN.10_IN_THE_TREASURE_CRYPT_BATTLE_THE_HERO_OF_THE_DEFENSE_WILL_GET_SOME_INITIAL_ENERGY"),
		"规则行 18 LSTR fill")
	panel.remove_window()
	root.queue_free()


# ── ExcavateGiveupPanel：LSTR + 两件套守卫（excavate 批 Task 1，2026-08-17）──

# giveup 5 个 LSTR key + 资源名 key 全在 JSON
func test_giveup_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"giveup.1.10.1.001", "giveup.1.10.1.002", "giveup.1.10.1.003",
		"giveup.1.10.1.005", "CHATCONFIG.CANCEL", "CHATCONFIG.CONFIRM",
		"RECHARGE.DIAMOND", "TASK.GOLD", "EQUIP.EXPERIENCE_CREAMS",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# A 类债 #7：frame 归源 uieditor/confirmdialog.lua:2-21（Scale9Sprite main_vit_tips
# cap 19.53,19.53,46.88,11.72；giveup 走 param.node 分支，弹窗贴图与 excavate 无关）。
# cap 换算（像素直译口径，H/W 用 PIL 实测 103x61）：L=x=19.53、B=y=19.53、
# R=W-x-w=103-19.53-46.88=36.59、T=H-y-h=61-19.53-11.72=29.75；NinePatchRect
# patch_margin 为 int 取整 20/20/37/30。
func test_giveup_frame_source_fidelity() -> void:
	var content: Control = (load("res://scenes/ui/excavate_giveup_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: NinePatchRect = content.get_node_or_null("Frame") as NinePatchRect
	assert_not_null(frame, "Frame 存在且为 NinePatchRect（源 Scale9Sprite）")
	if frame == null:
		content.queue_free()
		return
	assert_not_null(frame.texture, "frame 有贴图")
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/main_vit_tips.png",
		"frame 贴图归源 main_vit_tips（弃 excavate_main_frame 误用）")
	assert_eq(frame.patch_margin_left, 20, "cap left=19.53 取整 20")
	assert_eq(frame.patch_margin_bottom, 20, "cap bottom=19.53 取整 20")
	assert_eq(frame.patch_margin_right, 37, "cap right=36.59 取整 37")
	assert_eq(frame.patch_margin_top, 30, "cap top=29.75 取整 30")
	content.queue_free()


# 静态 rect 守卫（防 parenting 回归）：照源声明表 + initWindow 直译。
# frame 中心 (481.56,325.62)=to_godot(401.56,234.38)；尺寸 w=500（max 下限）、
# h=180+3×26×1.28≈280；按钮 (w/7*2,58)/(w/7*5,58)→中心 y=280-58=222；delimeter 中心 (250,180)。
func test_giveup_content_static_rects() -> void:
	var content: Control = (load("res://scenes/ui/excavate_giveup_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: Control = content.get_node("Frame") as Control
	assert_almost_eq(frame.position.x, 231.56, 0.02, "frame offset_left=231.56")
	assert_almost_eq(frame.position.y, 185.62, 0.02, "frame offset_top=185.62")
	assert_almost_eq(frame.size.x, 500.0, 0.02, "frame w=500（initWindow 下限）")
	assert_almost_eq(frame.size.y, 280.0, 0.02, "frame h=180+nh*1.28")
	var del: Control = frame.get_node("Delimeter") as Control
	assert_almost_eq(del.position.x + del.size.x * 0.5, 250.0, 0.02, "delimeter 中心 x=w/2")
	assert_almost_eq(del.position.y + del.size.y * 0.5, 180.0, 0.02, "delimeter 中心 y=h-100")
	var cancel_btn: Control = frame.get_node("CancelBtn") as Control
	assert_almost_eq(cancel_btn.position.x + cancel_btn.size.x * 0.5, 500.0 / 7.0 * 2.0, 0.02, "left btn 中心 x=w/7*2")
	assert_almost_eq(cancel_btn.position.y + cancel_btn.size.y * 0.5, 222.0, 0.02, "left btn 中心 y=h-58")
	assert_almost_eq(cancel_btn.size.y, 54.69, 0.02, "btn 高 scaleSize 54.69")
	var ok_btn: Control = frame.get_node("ConfirmBtn") as Control
	assert_almost_eq(ok_btn.position.x + ok_btn.size.x * 0.5, 500.0 / 7.0 * 5.0, 0.02, "right btn 中心 x=w/7*5")
	# 绘制序守卫（防重排反盖）：delimeter 底层装饰位 → 行内容 → 按钮最上层可点
	assert_lt(frame.get_node("Delimeter").get_index(), frame.get_node("R11Label").get_index(),
		"delimeter 声明序先于行内容")
	assert_gt(frame.get_node("ConfirmBtn").get_index(), frame.get_node("R31Label").get_index(),
		"按钮声明序后于行内容（最上层）")
	content.queue_free()


# 旧范式退役守卫：panel.gd 源码无运行时样式套用（两件套 SOP）。
func test_giveup_no_legacy_runtime_styling() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/excavate_giveup_panel.gd")
	assert_false(src.contains("UiScale9Button"), "UiScale9Button 已退役")
	assert_false(src.contains("add_theme_color_override"), "运行时颜色 override 已退役")
	assert_false(src.contains("add_theme_stylebox_override"), "运行时样式 override 已退役")


# fill 分支（源 giveup.lua:24-105 两形态）：rg>0 三行（label+icon+数值）；
# rg=0 单行警示（.003/.004 按 from）+ 产出行隐藏。单机化 rr=0 → 实得=全额。
func test_giveup_fill_branches() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.excavate.excavate_data.append({
		"_id": 1, "_type_id": 1, "_owner": "mine", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 0.0, "_storage": 500, "_res_got": 352.0, "_wild_id": 30001, "_team": [],
	})
	var panel := ExcavateGiveupPanel.new("excavate_giveup", {})
	panel.setup_panel(pd, 1, Callable())
	panel.show_window(root)
	var content: Control = panel.container.get_node("ExcavateGiveupContent") as Control
	assert_not_null(content, "content 已装配")
	if content == null:
		panel.remove_window()
		root.queue_free()
		return
	var r13: Label = content.get_node("%R13Label") as Label
	assert_eq(r13.text, "352", "分支A：产出数值 fill")
	var r12: TextureRect = content.get_node("%R12Icon") as TextureRect
	assert_not_null(r12.texture, "分支A：icon 已 fill")
	var r21: Control = content.get_node("%R21Label") as Control
	assert_true(r21.visible, "分支A：行2 可见")
	panel.remove_window()
	# rg=0 分支：res_got=0 + speed=0 → 产出 0，走 else（.003 文案 + 行2 隐藏）
	var pd2 := PlayerData.new(cm)
	pd2.apply_default_data()
	pd2.excavate.excavate_data.append({
		"_id": 2, "_type_id": 1, "_owner": "mine", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 0.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 30001, "_team": [],
	})
	var panel2 := ExcavateGiveupPanel.new("excavate_giveup", {})
	panel2.setup_panel(pd2, 2, Callable())
	panel2.show_window(root)
	var content2: Control = panel2.container.get_node("ExcavateGiveupContent") as Control
	var r11b: Label = content2.get_node("%R11Label") as Label
	assert_eq(r11b.text, cm.get_lstr("giveup.1.10.1.003"), "分支B：r11=tt 文案（.003）")
	var r21b: Control = content2.get_node("%R21Label") as Control
	assert_false(r21b.visible, "分支B：行2 隐藏")
	panel2.remove_window()
	root.queue_free()


# ── ExcavateHistoryPanel：两件套 + 行模板（excavate 批 Task 3，2026-08-17）──

# 时间 4 档 LSTR key 全在 JSON
func test_history_time_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"EXCAVATEHISTORY._D_DAYS_AGO", "PVP._D_HOURS_AGO",
		"PVP._D_MINUTES_AGO", "PVP._D_SECONDS_AGO",
		"EXCAVATEHISTORY.ATTACK_YOUR__S",
		"EXCAVATEHISTORY.DEFENSIVE_RECORD",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# A 类债 #5 归源（读源三份原文实证，非盲信批 2 甄别表预设——giveup/explain 均走
# 通用窗，本件框体预设经原文复核为真）：uieditor/excavatehistory.lua:7,12
# frame = Sprite package_herolist_bg fix_wh 568.75x409.21875 anchor(0.5,0.5)@(393.75,212.5)
# → Godot (189.375,142.89)-(758.125,552.11)。纹理 700x485(ratio 1.4433)，fix ratio 1.3902
# 偏差 3.7% ≤8%（源显式拉伸照源直译）。弃 excavate_main_frame 600x440 误用
# （ratio 1.364 vs 1.613 偏差 15.5%，scan_texture_aspect 报警件）。
func test_history_frame_source_fidelity() -> void:
	var content: Control = (load("res://scenes/ui/excavate_history_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: TextureRect = content.get_node_or_null("Frame") as TextureRect
	assert_not_null(frame, "Frame 存在且为 TextureRect（源 t=Sprite 非 Scale9）")
	if frame == null:
		content.queue_free()
		return
	assert_not_null(frame.texture, "frame 有贴图")
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/package_herolist_bg.png",
		"frame 贴图归源 package_herolist_bg（弃 excavate_main_frame 误用）")
	assert_almost_eq(frame.size.x, 568.75, 0.02, "frame w=568.75（fix_wh 直译）")
	assert_almost_eq(frame.size.y, 409.22, 0.02, "frame h=409.22")
	# 纵横比守卫（对齐 scan_texture_aspect 8% 判据）
	var tex: Texture2D = frame.texture
	var ratio_dev: float = abs(frame.size.x / frame.size.y - float(tex.get_width()) / float(tex.get_height())) / (float(tex.get_width()) / float(tex.get_height()))
	assert_lt(ratio_dev, 0.08, "frame 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (ratio_dev * 100.0))
	content.queue_free()


# 静态 rect 守卫（防 parenting 回归）：照 uieditor/excavatehistory.lua + excavatehistory.lua:173-188 直译。
# title_bg fix_wh 521.09x39.06 中心 frame 局部 (270.31,398.83)（frame 底左世界 (109.375,7.89)）
# → 世界中心 (379.69,406.72) → Godot 中心 (459.69,153.28)，骑框顶边（局部 top=-9.14）；
# title size22 ccc3(252,216,17) 中心局部 (260.55,19.53)=title_bg 几何中心 → 全矩形居中；
# close fix_wh 57.81x58.59 中心 (678.91,389.06) → Godot (730.0,141.64)-(787.82,200.24)；
# scroll=源 createListLayer cliprect DGRectMake(165,35,690,485)×0.78125=(128.91,27.34,539.06,378.91)
# → Godot (208.91,153.75)-(747.97,532.66)，item 左 6.09/首行顶 4.25 内边距烘入 →
# (215,158)-(747.97,532.66)（批2 口径：ScrollContainer 接管子项 position）。
func test_history_content_static_rects() -> void:
	var content: Control = (load("res://scenes/ui/excavate_history_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: Control = content.get_node("Frame") as Control
	assert_almost_eq(frame.position.x, 189.375, 0.02, "frame offset_left=189.375")
	assert_almost_eq(frame.position.y, 142.89, 0.02, "frame offset_top=142.89")
	assert_almost_eq(frame.position.x + frame.size.x, 758.125, 0.02, "frame 右缘=758.125")
	assert_almost_eq(frame.position.y + frame.size.y, 552.11, 0.02, "frame 底缘=552.11")
	var title_bg: Control = frame.get_node("TitleBg") as Control
	assert_almost_eq(title_bg.position.x + title_bg.size.x * 0.5, 270.31, 0.02, "title_bg frame 局部中心 x=270.31")
	assert_almost_eq(title_bg.position.y + title_bg.size.y * 0.5, 10.39, 0.02, "title_bg frame 局部中心 y=10.39")
	assert_almost_eq(title_bg.size.x, 521.09, 0.02, "title_bg w=521.09")
	assert_lt(title_bg.position.y, 0.0, "title_bg 骑框顶边（局部 top<0，源 398.83+19.53>框高）")
	var title: Control = frame.get_node("%TitleLabel") as Control
	assert_almost_eq(title.position.x + title.size.x * 0.5, title_bg.size.x * 0.5, 0.02, "title 居中 title_bg（源中心 (260.55,19.53)≈几何中心）")
	assert_almost_eq(title.position.y + title.size.y * 0.5, title_bg.size.y * 0.5, 0.02, "title 垂直居中")
	var close_btn: Control = content.get_node("%CloseBtn") as Control
	assert_almost_eq(close_btn.position.x + close_btn.size.x * 0.5, 758.91, 0.02, "close 中心 x=758.91")
	assert_almost_eq(close_btn.position.y + close_btn.size.y * 0.5, 170.94, 0.02, "close 中心 y=170.94")
	assert_almost_eq(close_btn.size.x, 57.81, 0.02, "close w=57.81")
	assert_almost_eq(close_btn.size.y, 58.59, 0.02, "close h=58.59")
	# 纵横比守卫：close 57.81/58.59=0.9867 vs 纹理 65/66=0.9848
	var close_tex: Texture2D = (content.get_node("%CloseBtn") as TextureButton).texture_normal
	var close_dev: float = abs(close_btn.size.x / close_btn.size.y - float(close_tex.get_width()) / float(close_tex.get_height())) / (float(close_tex.get_width()) / float(close_tex.get_height()))
	assert_lt(close_dev, 0.08, "close 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (close_dev * 100.0))
	var scroll: Control = content.get_node("%HistoryScroll") as Control
	assert_almost_eq(scroll.position.x, 215.0, 0.02, "scroll offset_left=215（clip 左 208.91+item 左 6.09 烘入）")
	assert_almost_eq(scroll.position.y, 158.0, 0.02, "scroll offset_top=158（clip 顶 153.75+首行顶差 4.25 烘入）")
	assert_almost_eq(scroll.position.x + scroll.size.x, 747.97, 0.02, "scroll 右缘=clip 右 747.97")
	assert_almost_eq(scroll.position.y + scroll.size.y, 532.66, 0.02, "scroll 底缘=clip 底 532.66")
	# 绘制序守卫（防重排反盖）：框最底层（源 z=1）→ 滚动区（源 z=5）→ 关闭钮最上层
	# （源 z=20>5；重叠角 scroll 左上 730-748x158-200 需 close 绘制于 scroll 之上可点，
	# 审查 Important 修复 2026-08-17）
	assert_lt(frame.get_index(), content.get_node("%HistoryScroll").get_index(), "frame 声明序先于 scroll")
	assert_gt(content.get_node("%CloseBtn").get_index(), content.get_node("%HistoryScroll").get_index(), "close 后于 scroll 声明=绘制在上（源 z=20>5）")
	content.queue_free()


# 行模板结构守卫：照 uieditor/itemexcavatehistory.lua 直译（scrollview itemSize CCSizeMake(512,82)）。
# board Scale9 equip_detail_panel_bg scaleSize 514.06x74.22 中心 (257.03,34.38) → 行内
# (0,10.51)-(514.06,84.73)；cap(67.97,36.72,265.63,60.94)@533x175 → L68/B37/R199/T77，
# 但 cap 顶+底=114>显示高 74.22 系源退化九宫格（cocos 静默挤压渲染）→ Godot 需非退化
# margin，按 T:B=77.34:36.72 原比例钳到 50/24（受控修正，报告记录）。
# tag fix_wh 28.91x50 中心 (27.34,50.78)；check 57.81x58.59 中心 (475,35.16)；
# 单机受控裁剪（数据层 excavate_history.gd 恒 _vatility=0/无服务器）：vit_button/red_tag/
# enemy_svr_name 不进模板。
func test_history_item_template_structure() -> void:
	var item: Control = (load("res://scenes/ui/excavate_history_item.tscn") as PackedScene).instantiate() as Control
	add_child(item)
	assert_almost_eq(item.size.x, 512.0, 0.02, "行根宽=源 itemSize 512")
	assert_almost_eq(item.size.y, 82.0, 0.02, "行根高=源 itemSize 82（列表 stride）")
	var board: NinePatchRect = item.get_node_or_null("Board") as NinePatchRect
	assert_not_null(board, "Board 存在且为 NinePatchRect（源 Scale9Sprite）")
	if board == null:
		item.queue_free()
		return
	assert_eq(board.texture.resource_path, "res://assets/ui/alpha/HVGA/equip_detail_panel_bg.png", "board 贴图归源")
	assert_almost_eq(board.position.x, 0.0, 0.02, "board offset_left=0（中心 257.03=半宽）")
	assert_almost_eq(board.size.x, 514.06, 0.02, "board w=514.06（scaleSize 直译）")
	assert_almost_eq(board.size.y, 74.22, 0.02, "board h=74.22")
	assert_eq(board.patch_margin_left, 68, "cap left=67.97 取整 68")
	assert_eq(board.patch_margin_right, 199, "cap right=533-67.97-265.63=199.4 取整 199")
	assert_lte(board.patch_margin_top + board.patch_margin_bottom, board.size.y, "纵向 margin 非退化（源退化九宫格已按比例钳制）")
	var tag_win: Control = item.get_node("%TagWin") as Control
	assert_almost_eq(tag_win.position.x + tag_win.size.x * 0.5, 27.34, 0.02, "tag 中心 x=27.34")
	assert_almost_eq(tag_win.size.x, 28.91, 0.02, "tag w=28.91")
	assert_almost_eq(tag_win.size.y, 50.0, 0.02, "tag h=50")
	assert_false(tag_win.visible, "tag_win 默认隐藏（fill 按 result 切换）")
	assert_false((item.get_node("%TagLose") as Control).visible, "tag_lose 默认隐藏")
	var name_bg: Control = item.get_node("EnemyNameBg") as Control
	assert_almost_eq(name_bg.modulate.a, 100.0 / 255.0, 0.005, "enemy_name_bg opacity=100/255（源 config.opacity）")
	var check_btn: TextureButton = item.get_node("%CheckBtn") as TextureButton
	assert_almost_eq(check_btn.position.x + check_btn.size.x * 0.5, 475.0, 0.02, "check 中心 x=475")
	assert_almost_eq(check_btn.position.y + check_btn.size.y * 0.5, 46.84, 0.02, "check 中心 y=46.84（行内 82-35.16）")
	assert_eq(check_btn.stretch_mode, 0, "TextureButton stretch_mode 显式 0（批2 教训：默认 KEEP 不缩放）")
	assert_eq(check_btn.texture_normal.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_history_button_detail_1.png", "check 贴图归源 detail_1")
	# 单机受控裁剪守卫：vit/red_tag/svr 不建（数据层恒 _vatility=0）
	assert_null(item.get_node_or_null("VitButton"), "vit_button 不建（单机无防御体力奖励）")
	assert_null(item.get_node_or_null("RedTag"), "red_tag 不建（随 vit_button 裁）")
	assert_null(item.get_node_or_null("EnemySvrName"), "enemy_svr_name 不建（单机无服务器）")
	item.queue_free()


# 旧范式退役守卫（两件套 SOP）：panel.gd + row_builder 无运行时样式/静态节点构造。
func test_history_no_legacy_runtime_styling() -> void:
	var panel_src: String = FileAccess.get_file_as_string("res://scripts/ui/excavate_history_panel.gd")
	assert_false(panel_src.contains("UiScale9Button"), "panel: UiScale9Button 已退役")
	assert_false(panel_src.contains("add_theme_color_override"), "panel: 运行时颜色 override 已退役")
	assert_false(panel_src.contains("add_theme_font_size_override"), "panel: 运行时字号 override 已退役")
	assert_false(panel_src.contains("add_theme_stylebox_override"), "panel: 运行时样式 override 已退役")
	for ctor: String in ["Label.new(", "Button.new(", "HBoxContainer.new(", "VBoxContainer.new(", "TextureRect.new("]:
		assert_false(panel_src.contains(ctor), "panel: 无静态节点构造 %s" % ctor)
	var builder_src: String = FileAccess.get_file_as_string("res://scripts/ui/excavate_history_row_builder.gd")
	assert_false(builder_src.contains("UiScale9Button"), "builder: UiScale9Button 已退役")
	assert_false(builder_src.contains("add_theme_color_override"), "builder: 运行时颜色 override 已退役")
	assert_false(builder_src.contains("add_theme_font_size_override"), "builder: 运行时字号 override 已退役")
	assert_false(builder_src.contains("add_theme_stylebox_override"), "builder: 运行时样式 override 已退役")
	for ctor2: String in ["Label.new(", "Button.new(", "HBoxContainer.new(", "VBoxContainer.new(", "TextureRect.new("]:
		assert_false(builder_src.contains(ctor2), "builder: 禁建静态结构 %s（静态结构全在 item tscn）" % ctor2)


# fill 分支：双行（get_all 按 _time 倒序 → 行1=新记录 lose/行2=旧记录 win）tag 互斥 +
# 敌方名 + 相对时间分档（天档）+ 行动文案 LSTR + ActionLabel 照源 ed.right2 定位在
# TimeLabel 右侧 gap10；空态（EmptyLabel 单机自创兜底文案，源无空态）。
func test_history_fill_rows_and_tags() -> void:
	var root := Node.new()
	add_child(root)
	var now: int = int(Time.get_unix_time_from_system())
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.excavate.history.add({"excavate_id": 1, "result": "win", "enemy_name": "哥布林矿工",
		"_time": now - 172800, "self_team": [], "oppo_team": []})
	pd.excavate.history.add({"excavate_id": 1, "result": "lose", "enemy_name": "骷髅守卫",
		"_time": now - 60, "self_team": [], "oppo_team": []})
	var panel := ExcavateHistoryPanel.new("excavate_history", {})
	panel.setup_panel(pd)
	panel.show_window(root)
	var content: Control = panel.container.get_node("ExcavateHistoryContent") as Control
	assert_not_null(content, "content 已装配")
	if content == null:
		panel.remove_window()
		root.queue_free()
		return
	assert_eq((content.get_node("%TitleLabel") as Label).text, cm.get_lstr("EXCAVATEHISTORY.DEFENSIVE_RECORD"),
		"标题 fill EXCAVATEHISTORY.DEFENSIVE_RECORD（源 uieditor title text）")
	var list_host: VBoxContainer = content.get_node("%HistoryList") as VBoxContainer
	assert_eq(list_host.get_child_count(), 2, "两条记录 → 两行（行模板实例）")
	var row1: Control = list_host.get_child(0)
	assert_true((row1.get_node("%TagLose") as Control).visible, "行1（新，60 秒前）lose tag 可见")
	assert_false((row1.get_node("%TagWin") as Control).visible, "行1 win tag 隐藏（互斥照源 :63-69）")
	assert_eq((row1.get_node("%EnemyNameLabel") as Label).text, "骷髅守卫", "行1 敌方名 fill")
	var row2: Control = list_host.get_child(1)
	assert_true((row2.get_node("%TagWin") as Control).visible, "行2（旧，2 天前）win tag 可见")
	assert_false((row2.get_node("%TagLose") as Control).visible, "行2 lose tag 隐藏")
	var time2: Label = row2.get_node("%TimeLabel") as Label
	assert_true(time2.text.contains("天"), "行2 相对时间走天档（2 天前）")
	var action2: Label = row2.get_node("%ActionLabel") as Label
	assert_true(action2.text.contains("偷袭了你的"), "行动文案 LSTR fill（EXCAVATEHISTORY.ATTACK_YOUR__S）")
	# ed.right2 语义（excavatehistory.lua:107）：ActionLabel.x = TimeLabel.x + 时间文本宽 + 10
	assert_almost_eq(action2.position.x, time2.position.x + time2.get_combined_minimum_size().x + 10.0, 0.02,
		"ActionLabel 在 TimeLabel 右侧 gap10（源 ed.right2）")
	assert_almost_eq(action2.position.y, time2.position.y, 0.02, "ActionLabel 与 TimeLabel 同行对齐（同为 anchor(0,0.5)）")
	# fill 幂等（审查 Minor 修复 2026-08-17）：重复 fill 先清 %HistoryList 老行不叠行
	panel._fill_rows()
	assert_eq(list_host.get_child_count(), 2, "重复 fill 行数仍 2（幂等清理，对齐 shop_panel 范式）")
	panel.remove_window()
	# 空态分支
	var pd2 := PlayerData.new(cm)
	pd2.apply_default_data()
	var panel2 := ExcavateHistoryPanel.new("excavate_history", {})
	panel2.setup_panel(pd2)
	panel2.show_window(root)
	var content2: Control = panel2.container.get_node("ExcavateHistoryContent") as Control
	assert_true((content2.get_node("%EmptyLabel") as Label).visible, "空态 EmptyLabel 可见")
	assert_eq((content2.get_node("%EmptyLabel") as Label).text, "暂无战斗记录", "空态兜底文案（单机自创，源无）")
	assert_false((content2.get_node("%HistoryScroll") as Control).visible, "空态 scroll 隐藏")
	assert_eq((content2.get_node("%HistoryList") as VBoxContainer).get_child_count(), 0, "空态无行")
	panel2.remove_window()
	root.queue_free()


# ── ExcavateBattleReportPanel：两件套 + 玩家行模板（excavate 批 Task 5，2026-08-17）──

# THE+BATTLE 拼接 "第" + "1" + "战"（title fill 依赖）
func test_battle_report_title_lstr_concat() -> void:
	var the: String = cm.get_lstr("EXCAVATEBATTLEREPORT.THE")
	var battle: String = cm.get_lstr("EXCAVATEBATTLEREPORT.BATTLE")
	assert_eq(the, "第", "THE = 第")
	assert_eq(battle, "战", "BATTLE = 战")
	var title: String = the + "1" + battle
	assert_eq(title, "第1战", "title 拼接正确")


# 窗口层侧标题 LSTR key 全在 JSON（源 left_title=OFFENCE / right_title=DEFENDER）
func test_battle_report_window_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"EXCAVATEBATTLEREPORT.OFFENCE",
		"EXCAVATEBATTLEREPORT.DEFENDER",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)
		assert_false(v.is_empty(), "LSTR 值非空：" + k)


# A 类债 #4 归源（读源原文实证，非盲信 A 债表"待核"预设）：uieditor/
# excavatebattlereport.lua:2-22 frame = Scale9Sprite **main_vit_tips**
# scaleSize 703.13x434.38（scaleSize 直译）cap CCRectMake(21.88,21.09,39.06,11.72)
# @103x61 像素直译：L=21.88→22、B=21.09→21、R=103-21.88-39.06=42.06→42、
# T=61-21.09-11.72=28.19→28。贴图选择+尺寸双重失真（现状 excavate_main_frame
# 600x440 强拉，ratio 1.364 vs 纹理 1.613 偏差 15.5%，scan_texture_aspect 报警件）。
func test_battle_report_frame_source_fidelity() -> void:
	var content: Control = (load("res://scenes/ui/excavate_battle_report_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: NinePatchRect = content.get_node_or_null("Frame") as NinePatchRect
	assert_not_null(frame, "Frame 存在且为 NinePatchRect（源 Scale9Sprite）")
	if frame == null:
		content.queue_free()
		return
	assert_not_null(frame.texture, "frame 有贴图")
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/main_vit_tips.png",
		"frame 贴图归源 main_vit_tips（弃 excavate_main_frame 误用，A 债 #4）")
	assert_almost_eq(frame.size.x, 703.13, 0.02, "frame w=703.13（scaleSize 直译）")
	assert_almost_eq(frame.size.y, 434.38, 0.02, "frame h=434.38")
	assert_eq(frame.patch_margin_left, 22, "cap left=21.88 取整 22")
	assert_eq(frame.patch_margin_bottom, 21, "cap bottom=21.09 取整 21")
	assert_eq(frame.patch_margin_right, 42, "cap right=42.06 取整 42")
	assert_eq(frame.patch_margin_top, 28, "cap top=28.19 取整 28")
	content.queue_free()


# 静态 rect 守卫（防 parenting 回归）：窗口层 to_godot(x,y)=(x+80,560-y) 直译 +
# item 层经源 scrollview 摆放链（createListLayer:41-58 oriPosition DGccp(107,325)
# ×0.78125=(83.59,253.91)（readnode.lua:25-30 DG 前缀像素→点）+ getItemPos:122-127
# item1 世界原点=(83.59,253.91) → Godot item 左 163.59 / 底 306.09）：
# frame 中心 (419.53,233.59) → Godot (147.97,109.22)；close fix_wh 49.22x52.34
# 中心 (752.34,432.81) → (807.73,101.02)-(856.95,153.36)；left_title size22 中心
# (239.06,426.56) → (319.06,133.44)；right_title → (634.69,133.44)；
# title_bg 中心局部 (313.28,135.94) → Godot 中心 (476.87,170.15)；vs_icon 中心
# 局部 (313.28,63.28) → (476.87,242.81)；left_container 312.5x125 @(0,0) →
# (163.59,181.09)-(476.09,306.09)；right_container @(315.63,-0.78) →
# (479.22,181.87)-(791.72,306.87)。replay_button 单机裁（联机 query_replay）。
func test_battle_report_content_static_rects() -> void:
	var content: Control = (load("res://scenes/ui/excavate_battle_report_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: Control = content.get_node("Frame") as Control
	assert_almost_eq(frame.position.x, 147.97, 0.02, "frame offset_left=147.97")
	assert_almost_eq(frame.position.y, 109.22, 0.02, "frame offset_top=109.22")
	assert_almost_eq(frame.size.x, 703.13, 0.02, "frame w=703.13")
	assert_almost_eq(frame.size.y, 434.38, 0.02, "frame h=434.38")
	var enemy_title: Control = content.get_node("%EnemyTitle") as Control
	assert_almost_eq(enemy_title.position.x + enemy_title.size.x * 0.5, 319.06, 0.02, "left_title 中心 x=319.06")
	assert_almost_eq(enemy_title.position.y + enemy_title.size.y * 0.5, 133.44, 0.02, "left_title 中心 y=133.44")
	var self_title: Control = content.get_node("%SelfTitle") as Control
	assert_almost_eq(self_title.position.x + self_title.size.x * 0.5, 634.69, 0.02, "right_title 中心 x=634.69")
	assert_almost_eq(self_title.position.y + self_title.size.y * 0.5, 133.44, 0.02, "right_title 中心 y=133.44")
	var title_bg: Control = content.get_node("TitleBg") as Control
	assert_almost_eq(title_bg.position.x + title_bg.size.x * 0.5, 476.87, 0.02, "title_bg 中心 x=476.87")
	assert_almost_eq(title_bg.position.y + title_bg.size.y * 0.5, 170.15, 0.02, "title_bg 中心 y=170.15")
	assert_almost_eq(title_bg.size.x, 314.84, 0.02, "title_bg w=314.84（scaleSize 直译）")
	assert_almost_eq(title_bg.size.y, 11.72, 0.02, "title_bg h=11.72")
	var title_label: Control = content.get_node("%TitleLabel") as Control
	assert_almost_eq(title_label.position.x + title_label.size.x * 0.5, title_bg.size.x * 0.5, 0.02,
		"title 居中 title_bg（源中心 (314.84,135.16)≈title_bg 几何中心，局部坐标同 history 先例）")
	assert_almost_eq(title_label.position.y + title_label.size.y * 0.5, title_bg.size.y * 0.5, 0.02,
		"title 垂直居中")
	var vs_icon: Control = content.get_node("VsIcon") as Control
	assert_almost_eq(vs_icon.position.x + vs_icon.size.x * 0.5, 476.87, 0.02, "vs_icon 中心 x=476.87")
	assert_almost_eq(vs_icon.position.y + vs_icon.size.y * 0.5, 242.81, 0.02, "vs_icon 中心 y=242.81")
	assert_almost_eq(vs_icon.size.x, 44.53, 0.02, "vs_icon w=44.53（fix_wh 直译）")
	assert_almost_eq(vs_icon.size.y, 36.72, 0.02, "vs_icon h=36.72")
	var vs_tex: Texture2D = (content.get_node("VsIcon") as TextureRect).texture
	var vs_dev: float = abs(vs_icon.size.x / vs_icon.size.y - float(vs_tex.get_width()) / float(vs_tex.get_height())) / (float(vs_tex.get_width()) / float(vs_tex.get_height()))
	assert_lt(vs_dev, 0.08, "vs_icon 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (vs_dev * 100.0))
	var enemy_ctn: Control = content.get_node("%EnemyContainer") as Control
	assert_almost_eq(enemy_ctn.position.x, 163.59, 0.02, "left_container offset_left=163.59")
	assert_almost_eq(enemy_ctn.position.y, 181.09, 0.02, "left_container offset_top=181.09")
	assert_almost_eq(enemy_ctn.size.x, 312.5, 0.02, "left_container w=312.5（scaleSize 直译）")
	assert_almost_eq(enemy_ctn.size.y, 125.0, 0.02, "left_container h=125")
	var self_ctn: Control = content.get_node("%SelfContainer") as Control
	assert_almost_eq(self_ctn.position.x, 479.22, 0.02, "right_container offset_left=479.22（局部 315.63）")
	assert_almost_eq(self_ctn.position.y, 181.87, 0.02, "right_container offset_top=181.87（局部 -0.78）")
	var close_btn: Control = content.get_node("%CloseBtn") as Control
	assert_almost_eq(close_btn.position.x + close_btn.size.x * 0.5, 832.34, 0.02, "close 中心 x=832.34")
	assert_almost_eq(close_btn.position.y + close_btn.size.y * 0.5, 127.19, 0.02, "close 中心 y=127.19")
	assert_almost_eq(close_btn.size.x, 49.22, 0.02, "close w=49.22（fix_wh 直译）")
	assert_almost_eq(close_btn.size.y, 52.34, 0.02, "close h=52.34")
	# 纵横比守卫：49.22/52.34=0.9403 vs 纹理 65/66=0.9848 偏差 4.5%（源轻微拉伸照源）
	var close_tex: Texture2D = (content.get_node("%CloseBtn") as TextureButton).texture_normal
	var close_dev: float = abs(close_btn.size.x / close_btn.size.y - float(close_tex.get_width()) / float(close_tex.get_height())) / (float(close_tex.get_width()) / float(close_tex.get_height()))
	assert_lt(close_dev, 0.08, "close 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (close_dev * 100.0))
	assert_eq(close_tex.resource_path, "res://assets/ui/alpha/HVGA/common/common_tips_button_close_1.png",
		"close 贴图归源 common_tips_button_close_1（弃 herodetail-detail-close 误用）")
	# 绘制序守卫（防反盖）：源 z frame=1 < left_title=2 < right_title=4 < scrollview 内容=5 < close=20
	assert_lt(content.get_node("Frame").get_index(), enemy_title.get_index(), "frame 声明序先于 left_title（z 1<2）")
	assert_lt(self_title.get_index(), content.get_node("TitleBg").get_index(), "right_title 先于 item 内容（z 4<5）")
	assert_gt(content.get_node("%CloseBtn").get_index(), content.get_node("VsIcon").get_index(), "close 最后声明（源 z=20>5）")
	# 单机受控裁剪守卫：replay_button 不建（联机 query_replay 回放，验收记录受控偏离）
	assert_null(content.get_node_or_null("ReplayButton"), "replay_button 不建（单机无回放数据）")
	content.queue_free()


# 玩家行模板结构守卫：照 uieditor/itemexcavatebattleplayer.lua（216 行）直译，
# 行根 = 两侧 container 声明 scaleSize 312.5x125（itemexcavatebattlereport.lua:52/70），
# 条目局部坐标（Cocos y-up → Godot y-down = 125-y）：
# board Sprite chat_replay_bg fix_wh 290.625x101.5625 中心 (154.69,60.16) →
# (9.38,14.06)-(300.0,115.62)；tag_win/lose fix_wh 28.91x50 中心 (39.06,89.06) →
# (24.61,10.94)-(53.51,60.94) 互斥；icon_container 46.88² @(52.34,68.75)；
# level_container 35.16x31.25 @(100,73.44)；name_bg fix_wh 164.84x26.56 中心 (207.03,90.63)
# → (124.61,21.09)-(289.45,47.66)【源显式压扁 50%（纹理 422x34 等比应 329x26.5）→
# 显式 stretch_mode=0 声明设计意图，scan 尊重跳过】；name_label anchor(0,0.5)@(137.5,92.19)
# 白 21；hicon_container_1..5 46.88² @(25/78.91/132.03/185.16/238.28,17.19)。
# avatar/level 徽章容器照源建位（fill 受控降级：无 getTeamHead/getLevelIcon 基础设施）。
func test_battle_report_player_item_structure() -> void:
	var item: Control = (load("res://scenes/ui/excavate_battle_player_item.tscn") as PackedScene).instantiate() as Control
	add_child(item)
	assert_almost_eq(item.size.x, 312.5, 0.02, "行根宽=源 container scaleSize 312.5")
	assert_almost_eq(item.size.y, 125.0, 0.02, "行根高=125")
	var board: TextureRect = item.get_node_or_null("Board") as TextureRect
	assert_not_null(board, "Board 存在且为 TextureRect（源 t=Sprite）")
	if board == null:
		item.queue_free()
		return
	assert_eq(board.texture.resource_path, "res://assets/ui/alpha/HVGA/chat/chat_replay_bg.png", "board 贴图归源")
	assert_almost_eq(board.position.x, 9.38, 0.02, "board offset_left=9.38")
	assert_almost_eq(board.position.y, 14.06, 0.02, "board offset_top=14.06")
	assert_almost_eq(board.size.x, 290.63, 0.02, "board w=290.63（fix_wh 直译）")
	assert_almost_eq(board.size.y, 101.56, 0.02, "board h=101.56")
	var board_dev: float = abs(board.size.x / board.size.y - float(board.texture.get_width()) / float(board.texture.get_height())) / (float(board.texture.get_width()) / float(board.texture.get_height()))
	assert_lt(board_dev, 0.08, "board 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (board_dev * 100.0))
	var tag_win: Control = item.get_node("%TagWin") as Control
	var tag_lose: Control = item.get_node("%TagLose") as Control
	assert_almost_eq(tag_win.position.x + tag_win.size.x * 0.5, 39.06, 0.02, "tag 中心 x=39.06")
	assert_almost_eq(tag_win.position.y + tag_win.size.y * 0.5, 35.94, 0.02, "tag 中心 y=35.94（125-89.06）")
	assert_almost_eq(tag_win.size.x, 28.91, 0.02, "tag w=28.91")
	assert_almost_eq(tag_win.size.y, 50.0, 0.02, "tag h=50")
	assert_false(tag_win.visible, "tag_win 默认隐藏（fill 互斥切换）")
	assert_false(tag_lose.visible, "tag_lose 默认隐藏")
	assert_eq((item.get_node("%TagWin") as TextureRect).texture.resource_path,
		"res://assets/ui/alpha/HVGA/pvp/pvp_win.png", "tag_win 贴图归源 pvp_win")
	assert_eq((item.get_node("%TagLose") as TextureRect).texture.resource_path,
		"res://assets/ui/alpha/HVGA/pvp/pvp_lose.png", "tag_lose 贴图归源 pvp_lose")
	assert_not_null(item.get_node_or_null("%IconContainer"), "icon_container 照源建位（头像 fill 受控降级）")
	assert_not_null(item.get_node_or_null("%LevelContainer"), "level_container 照源建位（等级徽章 fill 受控降级")
	var name_bg: TextureRect = item.get_node("NameBg") as TextureRect
	assert_almost_eq(name_bg.position.x + name_bg.size.x * 0.5, 207.03, 0.02, "name_bg 中心 x=207.03")
	assert_almost_eq(name_bg.position.y + name_bg.size.y * 0.5, 34.37, 0.02, "name_bg 中心 y=34.37（125-90.63）")
	assert_almost_eq(name_bg.size.x, 164.84, 0.02, "name_bg w=164.84（源显式压扁 50%）")
	assert_almost_eq(name_bg.size.y, 26.56, 0.02, "name_bg h=26.56")
	assert_eq(name_bg.stretch_mode, 0, "name_bg 显式 stretch_mode=0（源显式拉伸声明，scan 尊重跳过）")
	var name_label: Label = item.get_node("%NameLabel") as Label
	assert_almost_eq(name_label.position.x, 137.5, 0.02, "name_label 左缘 x=137.5（源 anchor(0,0.5)）")
	assert_almost_eq(name_label.position.y + name_label.size.y * 0.5, 32.81, 0.02, "name_label 垂直中心 y=32.81（125-92.19）")
	for i: int in range(1, 6):
		var slot: Control = item.get_node("Hicon%d" % i) as Control
		assert_not_null(slot, "hicon_container_%d 存在" % i)
		assert_almost_eq(slot.position.y, 60.93, 0.02, "hicon_%d offset_top=60.93（125-17.19-46.88）" % i)
		assert_almost_eq(slot.size.x, 46.88, 0.02, "hicon_%d w=46.88（scaleSize 直译）" % i)
	assert_almost_eq((item.get_node("Hicon1") as Control).position.x, 25.0, 0.02, "hicon_1 x=25")
	assert_almost_eq((item.get_node("Hicon5") as Control).position.x, 238.28, 0.02, "hicon_5 x=238.28")
	# 绘制序守卫：源 z board=1 < tag=2 < icon_container/level_container=3、name_label=4
	assert_lt(board.get_index(), tag_win.get_index(), "board 声明序先于 tag（z 1<2）")
	assert_lt(tag_win.get_index(), item.get_node("%IconContainer").get_index(), "tag 先于 icon_container（z 2<3）")
	item.queue_free()


# 旧范式退役守卫（两件套 SOP）：panel.gd + row_builder 无运行时样式/静态节点构造。
func test_battle_report_no_legacy_runtime_styling() -> void:
	var panel_src: String = FileAccess.get_file_as_string("res://scripts/view/battle/excavate_battle_report_panel.gd")
	assert_false(panel_src.contains("UiScale9Button"), "panel: UiScale9Button 已退役")
	assert_false(panel_src.contains("add_theme_color_override"), "panel: 运行时颜色 override 已退役")
	assert_false(panel_src.contains("add_theme_font_size_override"), "panel: 运行时字号 override 已退役")
	assert_false(panel_src.contains("add_theme_stylebox_override"), "panel: 运行时样式 override 已退役")
	for ctor: String in ["Label.new(", "Button.new(", "HBoxContainer.new(", "VBoxContainer.new(", "TextureRect.new("]:
		assert_false(panel_src.contains(ctor), "panel: 无静态节点构造 %s" % ctor)
	var builder_src: String = FileAccess.get_file_as_string("res://scripts/view/battle/excavate_battle_player_row_builder.gd")
	assert_false(builder_src.contains("UiScale9Button"), "builder: UiScale9Button 已退役")
	assert_false(builder_src.contains("add_theme_color_override"), "builder: 运行时颜色 override 已退役")
	assert_false(builder_src.contains("add_theme_font_size_override"), "builder: 运行时字号 override 已退役")
	assert_false(builder_src.contains("add_theme_stylebox_override"), "builder: 运行时样式 override 已退役")
	for ctor2: String in ["Label.new(", "Button.new(", "HBoxContainer.new(", "VBoxContainer.new(", "TextureRect.new("]:
		assert_false(builder_src.contains(ctor2), "builder: 禁建静态结构 %s（静态结构全在 item tscn；ReadheroIcon 工具实例化除外）" % ctor2)


# fill：win 记录 → 敌方(=源 left/_oppo_team)显示败 tag + 敌方名；我方(=源 right/
# _self_team)显示胜 tag + 玩家名；hicon 1..5 槽照源 j 循环有 hero 才填 ReadheroIcon。
func test_battle_report_fill_sides_and_heroes() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var now: int = int(Time.get_unix_time_from_system())
	pd.excavate.history.add({"excavate_id": 1, "result": "win", "enemy_name": "哥布林矿工",
		"_time": now,
		"self_team": {"_hero": [
			{"_base": {"_tid": 1001, "_level": 10, "_rank": 2, "_stars": 3}, "_dyna": {}},
			{"_base": {"_tid": 1002, "_level": 8, "_rank": 1, "_stars": 2}, "_dyna": {}},
		]},
		"oppo_team": {"_hero": [
			{"_base": {"_tid": 2001, "_level": 9, "_rank": 3, "_stars": 4}, "_dyna": {}},
		]}})
	var panel := ExcavateBattleReportPanel.new("excavate_battle_report", {})
	panel.setup_panel(pd, 1)
	panel.show_window(root)
	var content: Control = panel.container.get_node("ExcavateBattleReportContent") as Control
	assert_not_null(content, "content 已装配")
	if content == null:
		panel.remove_window()
		root.queue_free()
		return
	assert_eq((content.get_node("%TitleLabel") as Label).text, "第1战", "标题 fill 第1战（单机单条即第 1 战）")
	assert_eq((content.get_node("%EnemyTitle") as Label).text, cm.get_lstr("EXCAVATEBATTLEREPORT.OFFENCE"),
		"左侧标题 fill OFFENCE（源 left_title）")
	assert_eq((content.get_node("%SelfTitle") as Label).text, cm.get_lstr("EXCAVATEBATTLEREPORT.DEFENDER"),
		"右侧标题 fill DEFENDER（源 right_title）")
	var enemy_row: Control = (content.get_node("%EnemyContainer") as Control).get_child(0)
	assert_true((enemy_row.get_node("%TagLose") as Control).visible, "敌方行（win 记录）lose tag 可见（源 :115-120 left victory → tag_win 隐藏）")
	assert_false((enemy_row.get_node("%TagWin") as Control).visible, "敌方行 win tag 隐藏（互斥）")
	assert_eq((enemy_row.get_node("%NameLabel") as Label).text, "哥布林矿工", "敌方名 fill（单机映射 enemy_name，源 playerData._name 无对应数据）")
	var self_row: Control = (content.get_node("%SelfContainer") as Control).get_child(0)
	assert_true((self_row.get_node("%TagWin") as Control).visible, "我方行 win tag 可见（源 :121-124 right victory → tag_lose 隐藏）")
	assert_false((self_row.get_node("%TagLose") as Control).visible, "我方行 lose tag 隐藏")
	assert_eq((self_row.get_node("%NameLabel") as Label).text, pd.player_name, "我方名 fill pd.player_name")
	assert_gt((enemy_row.get_node("Hicon1") as Control).get_child_count(), 0, "敌方 Hicon1 已填 ReadheroIcon（1 英雄）")
	assert_eq((enemy_row.get_node("Hicon2") as Control).get_child_count(), 0, "敌方 Hicon2 空（heroData[2] 无）")
	assert_gt((self_row.get_node("Hicon1") as Control).get_child_count(), 0, "我方 Hicon1 已填")
	assert_gt((self_row.get_node("Hicon2") as Control).get_child_count(), 0, "我方 Hicon2 已填（2 英雄）")
	assert_eq((self_row.get_node("Hicon3") as Control).get_child_count(), 0, "我方 Hicon3 空")
	panel.remove_window()
	root.queue_free()


# ── ExcavateMapPanel：两件套 + A 债 #6/#8 归源（excavate 批 Task 7，2026-08-17）──

# map 面板 LSTR key 全在 JSON（按钮/产量行/掠夺/矿上限/倒计时系）
func test_map_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"EXCAVATEMAP.RULES", "EXCAVATEHISTORY.DEFENSIVE_RECORD",
		"RECHARGE.DIAMOND", "TASK.GOLD", "EQUIP.EXPERIENCE_CREAMS",
		"MAP.MY_ACCUMULATED_RESOURCES_", "MAP.MY_PRODUCTION_SPEED_",
		"MAP.YOU_CAN_PLUNDER_", "EXCAVATEMAP.PRODUCTION_SPEED_",
		"MAP.TODAY_THE_SEARCH_HAS_REACHED_THE_MAXIMUM_NUMBER_OF_TIMES_",
		"ERRORINFO.INSUFFICIENT_COINS", "TIME.HOUR",
		"MAP._S_AFTER_THE_START_GENERATING_RESOURCES",
		"MAP.AFTER_MINING_APPROXIMATELY__D_HOURS",
		"MAP.THIS_TREASURE_IS_ABOUT_TO_FINISH_MINING",
		"MAP.THE_TREASURE_HAS_REACHED_THE_MAXIMUM_NUMBER_",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# map 关键资源存在（bg/框体双层/标题 9 图/翻页 tag 系/信息面板/按钮贴图全量）
func test_map_assets_exist() -> void:
	var paths: Array[String] = [
		"res://assets/ui/alpha/HVGA/bg.jpg",
		"res://assets/ui/alpha/HVGA/excavate/excavate_main_bg.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_name_diamond_1.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_name_gold_1.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_name_exp_1.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_main_title.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_fog.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_info_bg.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_cycle_bg.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_cycle_mask_left.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_cycle_mask_right.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_cycle_gold.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_cycle_gold_current.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_cycle_search.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_exp_icon.png",
		"res://assets/ui/alpha/HVGA/backbtn.png",
		"res://assets/ui/alpha/HVGA/prevchap.png",
		"res://assets/ui/alpha/HVGA/sell_number_button.png",
		"res://assets/ui/alpha/HVGA/crusade/crusade_reset_bg.png",
		"res://assets/ui/alpha/HVGA/tavern_button_1.png",
		"res://assets/ui/alpha/HVGA/goldicon_small.png",
		"res://assets/ui/alpha/HVGA/shop_token_icon.png",
	]
	for p in paths:
		assert_true(ResourceLoader.exists(p), "资源存在：" + p)


# A 类债 #6/#8 归源（读源原文实证，非盲信 A 债表预设）：
# uieditor/excavatemap.lua:125-143 frame = Sprite excavate_main_frame
# fix_wh 733.59375x454.6875（与 search 同款同尺寸；PIL 实测纹理 734x455
# ratio 1.6132，fix ratio 1.6134 完全等比 → 偏差 0.01%）。弃迁移 600x440 强拉
# （ratio 1.364 vs 1.613 偏差 15.5%，scan_texture_aspect 报警件）。
# frame_bg（同表 :107-124）= excavate_main_bg fix_wh 733.59x454.69 与框同尺寸
# （search 的 frame_bg 是 excavate_empty 702.34x392.97，两表不同物）。
# #8 title（:144-162）= **excavate_name_diamond_1**（A 债表预设 excavate_main_title
# 315x46 系误——map.lua:1188 main_title 仅搜索动画期 initPageTitle 临时替换；
# refreshPageTitle:1192 按 typeid 换 9 张 name 图，tscn 静态默认=表值 name_diamond_1）
# fix_wh 339.84x37.5，纹理 435x48 ratio 9.0625 完全等比（偏差 0.003%）。
# 弃迁移 excavate_main_title 340x38 误用（ratio 8.95 vs 纹理 6.85 偏差 31%）。
func test_map_frame_source_fidelity() -> void:
	var content: Control = (load("res://scenes/ui/excavate_map_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: TextureRect = content.get_node_or_null("FrameContainer/Frame") as TextureRect
	assert_not_null(frame, "Frame 存在且为 TextureRect（源 t=Sprite）")
	if frame == null:
		content.queue_free()
		return
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png",
		"frame 贴图归源 excavate_main_frame")
	assert_almost_eq(frame.size.x, 733.59, 0.02, "frame w=733.59（fix_wh 直译，A 债 #6）")
	assert_almost_eq(frame.size.y, 454.69, 0.02, "frame h=454.69")
	var tex: Texture2D = frame.texture
	var ratio_dev: float = abs(frame.size.x / frame.size.y - float(tex.get_width()) / float(tex.get_height())) / (float(tex.get_width()) / float(tex.get_height()))
	assert_lt(ratio_dev, 0.08, "frame 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (ratio_dev * 100.0))
	var frame_bg: TextureRect = content.get_node_or_null("FrameContainer/FrameBg") as TextureRect
	assert_not_null(frame_bg, "FrameBg 存在（源表 z=1 底层，迁移漏建）")
	if frame_bg != null:
		assert_eq(frame_bg.texture.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_main_bg.png",
			"frame_bg 贴图归源 excavate_main_bg")
		assert_almost_eq(frame_bg.size.x, 733.59, 0.02, "frame_bg w=733.59（fix_wh 直译）")
		assert_almost_eq(frame_bg.size.y, 454.69, 0.02, "frame_bg h=454.69")
	var title: TextureRect = content.get_node_or_null("FrameContainer/Title") as TextureRect
	assert_not_null(title, "Title 存在且为 TextureRect")
	if title == null:
		content.queue_free()
		return
	assert_eq(title.texture.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_name_diamond_1.png",
		"title 贴图归源 excavate_name_diamond_1（A 债 #8，弃 main_title 误用）")
	assert_almost_eq(title.size.x, 339.84, 0.02, "title w=339.84（fix_wh 直译）")
	assert_almost_eq(title.size.y, 37.5, 0.02, "title h=37.5")
	var title_tex: Texture2D = title.texture
	var title_dev: float = abs(title.size.x / title.size.y - float(title_tex.get_width()) / float(title_tex.get_height())) / (float(title_tex.get_width()) / float(title_tex.get_height()))
	assert_lt(title_dev, 0.08, "title 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (title_dev * 100.0))
	content.queue_free()


# 静态 rect 守卫（防 parenting 回归）：照 uieditor/excavatemap.lua 声明表直译。
# 场景层 to_godot(x,y)=(x+80,560-y)：bg 中心 (400,239.84)→(480,320.16)；
# frame_container Layer 800x480.47 anchor(0,0)@(-3.13,3.91)→(76.875,75.625)；
# left 42.97x58.59 中心 (63.28,217.19)→(143.28,342.81)；right 中心 (735.94,217.97)
# →(815.94,342.03)；search_fog 702.34x392.97 中心 (396.88,220.31)→(476.88,339.69)
# opacity 0 → modulate.a。frame_container 局部（H=480.47，y-up→y-down=480.47-cy）：
# frame_bg 中心 (402.34,245.31)；frame @(402.34,246.88)；title @(402.34,49.22)；
# back 74x75px÷CS=57.78x58.54 中心 (65.63,46.09)；page_tag_container 78.13²
# anchor(0,0)@(416.41,81.25)→局部 top=480.47-81.25-78.13=321.09。
# info_layer 与 frame_container 同 rect（pos(0,0) size 800x480.47）：
# explain_bg Scale9 281.25x99.22 anchor(1,1)@(742.97,400.78)→右 742.97/底 79.69；
# histroy 117.19x53.13 中心 (154.69,80.47)→(154.69,400)；explain 66.41x53.13
# 中心 (250.78,80.47)；research_frame 171.88x101.56 中心 (637.5,99.22)→(637.5,381.25)。
# research_container@research_frame 局部 (85.94,7.81) 39.06²（同 search 件先例）；
# explain_container 39.06²@(601.56,89.85)；lack/speed/count_time 容器 156.25x46.88
# @(-106.25,-3.13)/(-105.47,30.46)/(-106.25,64.84)（explain_container 39.06 高局部）。
func test_map_content_static_rects() -> void:
	var content: Control = (load("res://scenes/ui/excavate_map_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var fc: Control = content.get_node("FrameContainer") as Control
	assert_almost_eq(fc.position.x, 76.875, 0.02, "frame_container offset_left=76.875")
	assert_almost_eq(fc.position.y, 75.625, 0.02, "frame_container offset_top=75.625")
	assert_almost_eq(fc.size.x, 800.0, 0.02, "frame_container w=800（scaleSize 直译）")
	assert_almost_eq(fc.size.y, 480.47, 0.02, "frame_container h=480.47")
	var bg: Control = content.get_node("Bg") as Control
	# 实跑反馈修复（2026-08-17）：源 pushScene 全屏页语义，bg 铺满视口 960×640 + STOP
	# 挡点击穿透 shade（原 fix_wh 800×481 直译不满屏致主城透过/弹窗内点击误关窗）。
	assert_almost_eq(bg.position.x, 0.0, 0.02, "bg 铺满 offset_left=0")
	assert_almost_eq(bg.position.y, 0.0, 0.02, "bg 铺满 offset_top=0")
	assert_almost_eq(bg.size.x, 960.0, 0.02, "bg w=960（pushScene 全屏语义）")
	assert_almost_eq(bg.size.y, 640.0, 0.02, "bg h=640")
	assert_eq((bg as TextureRect).mouse_filter, Control.MOUSE_FILTER_STOP, "bg STOP 挡点击穿透（pushScene 页无点外关闭）")
	var mslbl: TextureButton = content.get_node("%ResearchFrame/ResearchContainer/%ResearchButton/SearchLabel") as TextureButton
	assert_eq(mslbl.texture_normal.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_word_search.png",
		"map SearchLabel 接线文字图 word_search（实跑反馈修复同 search 件）")
	var frame: Control = fc.get_node("Frame") as Control
	assert_almost_eq(frame.position.x + frame.size.x * 0.5, 402.34, 0.02, "frame 局部中心 x=402.34")
	assert_almost_eq(frame.position.y + frame.size.y * 0.5, 246.88, 0.02, "frame 局部中心 y=246.88（480.47-233.59）")
	var title: Control = fc.get_node("Title") as Control
	assert_almost_eq(title.position.x + title.size.x * 0.5, 402.34, 0.02, "title 局部中心 x=402.34")
	assert_almost_eq(title.position.y + title.size.y * 0.5, 49.22, 0.02, "title 局部中心 y=49.22（480.47-431.25）")
	var back_btn: Control = fc.get_node("%BackButton") as Control
	assert_almost_eq(back_btn.position.x + back_btn.size.x * 0.5, 65.63, 0.02, "back 局部中心 x=65.63")
	assert_almost_eq(back_btn.position.y + back_btn.size.y * 0.5, 46.09, 0.02, "back 局部中心 y=46.09（480.47-434.38）")
	var back_tex: Texture2D = (fc.get_node("%BackButton") as TextureButton).texture_normal
	var back_dev: float = abs(back_btn.size.x / back_btn.size.y - float(back_tex.get_width()) / float(back_tex.get_height())) / (float(back_tex.get_width()) / float(back_tex.get_height()))
	assert_lt(back_dev, 0.08, "back 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (back_dev * 100.0))
	var ptc: Control = fc.get_node("%PageTagContainer") as Control
	assert_almost_eq(ptc.position.x, 416.41, 0.02, "page_tag_container offset_left=416.41")
	assert_almost_eq(ptc.position.y, 321.09, 0.02, "page_tag_container offset_top=321.09（480.47-81.25-78.13）")
	assert_almost_eq(ptc.size.x, 78.13, 0.02, "page_tag_container w=78.13（scaleSize 直译）")
	var tag_bg: NinePatchRect = ptc.get_node("TagBg") as NinePatchRect
	assert_not_null(tag_bg, "TagBg 存在且为 NinePatchRect（源 Scale9Sprite）")
	if tag_bg != null:
		assert_almost_eq(tag_bg.size.x, 210.94, 0.02, "tag_bg w=210.94（scaleSize 直译）")
		assert_almost_eq(tag_bg.size.y, 30.47, 0.02, "tag_bg h=30.47")
		assert_eq(tag_bg.texture.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_cycle_bg.png", "tag_bg 贴图归源")
		assert_eq(tag_bg.patch_margin_left, 16, "cap left=15.63 取整 16")
		assert_eq(tag_bg.patch_margin_right, 32, "cap right=60-15.63-12.5=31.87 取整 32")
		assert_eq(tag_bg.patch_margin_top, 9, "cap top=39-0-29.69=9.31 取整 9")
		assert_eq(tag_bg.patch_margin_bottom, 0, "cap bottom=0（源 y=0）")
		assert_almost_eq(tag_bg.position.x + tag_bg.size.x * 0.5, ptc.size.x * 0.5, 0.02, "tag_bg 居中容器（源 pos(0,0) 中心锚）")
	var il: Control = fc.get_node("InfoLayer") as Control
	assert_almost_eq(il.position.x, 0.0, 0.02, "info_layer 与 frame_container 同 rect（源 pos(0,0) 800x480.47）")
	assert_almost_eq(il.size.y, 480.47, 0.02, "info_layer h=480.47")
	var explain_bg: NinePatchRect = il.get_node("%ExplainBg") as NinePatchRect
	assert_not_null(explain_bg, "ExplainBg 存在且为 NinePatchRect（源 Scale9Sprite）")
	if explain_bg != null:
		assert_almost_eq(explain_bg.position.x + explain_bg.size.x, 742.97, 0.02, "explain_bg 右缘 x=742.97（源 anchor(1,1)）")
		assert_almost_eq(explain_bg.position.y + explain_bg.size.y, 79.69, 0.02, "explain_bg 底缘 y=79.69（480.47-400.78）")
		assert_almost_eq(explain_bg.size.x, 281.25, 0.02, "explain_bg w=281.25（scaleSize 直译）")
		assert_eq(explain_bg.patch_margin_left, 133, "cap left=132.81 取整 133")
		assert_eq(explain_bg.patch_margin_right, 58, "cap right=281-132.81-89.84=58.35 取整 58")
	var histroy: Control = il.get_node("%HistroyButton") as Control
	assert_almost_eq(histroy.position.x + histroy.size.x * 0.5, 154.69, 0.02, "histroy 中心 x=154.69（info_layer 局部）")
	assert_almost_eq(histroy.position.y + histroy.size.y * 0.5, 400.0, 0.02, "histroy 中心 y=400（480.47-80.47）")
	assert_almost_eq(histroy.size.x, 117.19, 0.02, "histroy w=117.19（scaleSize 直译）")
	var explain: Control = il.get_node("%ExplainButton") as Control
	assert_almost_eq(explain.position.x + explain.size.x * 0.5, 250.78, 0.02, "explain 中心 x=250.78")
	assert_almost_eq(explain.size.x, 66.41, 0.02, "explain w=66.41（scaleSize 直译）")
	var research_frame: Control = il.get_node("%ResearchFrame") as Control
	assert_almost_eq(research_frame.position.x + research_frame.size.x * 0.5, 637.5, 0.02, "research_frame 中心 x=637.5")
	assert_almost_eq(research_frame.position.y + research_frame.size.y * 0.5, 381.25, 0.02, "research_frame 中心 y=381.25（480.47-99.22）")
	assert_almost_eq(research_frame.size.x, 171.88, 0.02, "research_frame w=171.88（scaleSize 直译）")
	assert_almost_eq((research_frame as Control).modulate.a, 200.0 / 255.0, 0.005, "research_frame opacity=200/255（源 config.opacity）")
	var research_btn: Control = il.get_node("%ResearchButton") as Control
	assert_almost_eq(research_btn.size.x, 140.63, 0.02, "research_button w=140.63（scaleSize 直译）")
	assert_almost_eq(research_btn.size.y, 50.78, 0.02, "research_button h=50.78")
	var btn_center: Vector2 = research_btn.get_global_rect().get_center()
	assert_almost_eq(btn_center.y, fc.position.y + 330.46875 + 7.8125 + 60.9375, 0.02,
		"research_button 全局中心 y（research_frame 330.47+container 7.81+cy=-21.88 越界挂下）")
	var explain_ctn: Control = il.get_node("%ExplainContainer") as Control
	assert_almost_eq(explain_ctn.position.x, 601.56, 0.02, "explain_container offset_left=601.56")
	assert_almost_eq(explain_ctn.position.y, 89.84, 0.02, "explain_container offset_top=89.84（480.47-351.56-39.06）")
	var lack_ctn: Control = explain_ctn.get_node("LackLabelContainer") as Control
	assert_almost_eq(lack_ctn.position.x, -106.25, 0.02, "lack_container offset_left=-106.25（源 anchor(0,0)@(-106.25,-4.69)）")
	assert_almost_eq(lack_ctn.position.y, -3.13, 0.02, "lack_container offset_top=-3.13（39.06+4.69-46.88）")
	assert_almost_eq(lack_ctn.size.x, 156.25, 0.02, "lack_container w=156.25（scaleSize 直译）")
	var speed_ctn: Control = explain_ctn.get_node("SpeedLabelContainer") as Control
	assert_almost_eq(speed_ctn.position.y, 30.46, 0.02, "speed_container offset_top=30.46（39.06+38.28-46.88）")
	var count_ctn: Control = explain_ctn.get_node("CountTimeContainer") as Control
	assert_almost_eq(count_ctn.position.y, 64.84, 0.02, "count_time_container offset_top=64.84（39.06+72.66-46.88）")
	var lack_title: Label = lack_ctn.get_node("%LackTitle") as Label
	assert_almost_eq(lack_title.position.x + lack_title.size.x, 85.94, 0.02, "lack_title 右缘 x=85.94（源 anchor(1,0.5)）")
	assert_almost_eq(lack_title.offset_top, 12.44, 0.02, "lack_title offset_top=12.44（源中线 23.44-半高 11，min size 拉伸只动 bottom）")
	assert_eq(lack_title.vertical_alignment, 1, "lack_title 垂直居中（源 anchor(*,0.5)）")
	var lack_num: Label = lack_ctn.get_node("%LackNumber") as Label
	assert_almost_eq(lack_num.position.x, 121.09, 0.02, "lack_number 左缘 x=121.09（源 anchor(0,0.5)）")
	var left: Control = content.get_node("%LeftButton") as Control
	assert_almost_eq(left.position.x + left.size.x * 0.5, 143.28, 0.02, "left_button 中心 x=143.28（to_godot(63.28)）")
	assert_almost_eq(left.position.y + left.size.y * 0.5, 342.81, 0.02, "left_button 中心 y=342.81（560-217.19）")
	assert_almost_eq(left.size.x, 42.97, 0.02, "left_button w=42.97（fix_wh 直译）")
	var right: Control = content.get_node("%RightButton") as Control
	assert_almost_eq(right.position.x + right.size.x * 0.5, 815.94, 0.02, "right_button 中心 x=815.94（to_godot(735.94)）")
	assert_almost_eq(right.position.y + right.size.y * 0.5, 342.03, 0.02, "right_button 中心 y=342.03（560-217.97）")
	assert_true((content.get_node("%RightButton") as TextureButton).flip_h, "right_button flip_h（源 flip=x）")
	var fog: Control = content.get_node("%SearchFog") as Control
	assert_almost_eq(fog.position.x + fog.size.x * 0.5, 476.88, 0.02, "search_fog 中心 x=476.88（to_godot(396.88)）")
	assert_almost_eq(fog.size.x, 702.34, 0.02, "search_fog w=702.34（fix_wh 直译）")
	assert_almost_eq(fog.modulate.a, 0.0, 0.005, "search_fog opacity=0（源 config.opacity=0，fill 淡入）")
	# 绘制序守卫（防反盖）：源 z bg=0 < frame_container=5（内：frame_bg=1 < 动态矿点
	# clipNode=2 < info_layer=15 < frame=20 < title=24 < page_tag/back=30）< 根级
	# fog/left/right=10 < search_icon=15
	assert_lt(content.get_node("Bg").get_index(), fc.get_index(), "bg 声明序先于 frame_container（z 0<5）")
	assert_lt(fc.get_node("FrameBg").get_index(), fc.get_node("InfoLayer").get_index(), "frame_bg 先于 info_layer（z 1<15）")
	assert_lt(fc.get_node("InfoLayer").get_index(), fc.get_node("Frame").get_index(), "info_layer 先于 frame（z 15<20）")
	assert_lt(fc.get_node("Frame").get_index(), fc.get_node("Title").get_index(), "frame 先于 title（z 20<24）")
	assert_lt(fc.get_node("NodeHost").get_index(), fc.get_node("InfoLayer").get_index(), "NodeHost（矿点宿主）先于 info_layer（源 clipNode z=2<15）")
	assert_lt(fc.get_index(), fog.get_index(), "frame_container 先于 fog（z 5<10）")
	content.queue_free()


# 旧范式退役守卫（两件套 SOP）：panel.gd 无运行时样式/静态结构构造。
# 矿点动态格子（Button/TextureRect，brief 明示业务层保留）与页签动态图标
# TextureRect 为白名单豁免；Label/静态容器构造仍禁。
func test_map_no_legacy_runtime_styling() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/excavate_map_panel.gd")
	assert_false(src.contains("UiScale9Button"), "UiScale9Button 已退役")
	assert_false(src.contains("add_theme_color_override"), "运行时颜色 override 已退役")
	assert_false(src.contains("add_theme_font_size_override"), "运行时字号 override 已退役")
	assert_false(src.contains("add_theme_stylebox_override"), "运行时样式 override 已退役（矿点热区=透明 Button+子 TextureRect 等比）")
	for ctor: String in ["Label.new(", "HBoxContainer.new(", "VBoxContainer.new(", "Control.new("]:
		assert_false(src.contains(ctor), "无静态节点构造 %s（静态结构全在 tscn）" % ctor)
	assert_false(src.contains("apply_with_label"), "UiScale9Button.apply_with_label 已退役")
	var fills_src: String = FileAccess.get_file_as_string("res://scripts/ui/excavate_map_fills.gd")
	assert_false(fills_src.contains("UiScale9Button"), "fills: UiScale9Button 已退役")
	assert_false(fills_src.contains("add_theme_color_override"), "fills: 运行时颜色 override 已退役")
	assert_false(fills_src.contains("add_theme_stylebox_override"), "fills: 运行时样式 override 已退役")
	for ctor2: String in ["Label.new(", "Button.new(", "TextureRect.new(", "Control.new("]:
		assert_false(fills_src.contains(ctor2), "fills: 纯数据绑定禁建节点 %s" % ctor2)


# map 面板空矿点列表兜底（源 checkWork:911 空数据即弹走，map 不应存在空态；
# 单机 giveup 后团队面板回 map 可能瞬时空 → EmptyLabel 护栏）
func test_map_panel_empty_list_no_crash() -> void:
	# hud_identity 接线守卫（同 search 件，setup_panel 时设 "excavate"）
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := ExcavateMapPanel.new("excavate_map", {})
	panel.setup_panel(pd, BattleRng.new(1))
	assert_eq(panel.hud_identity, "excavate", "map 件 hud_identity=excavate（头像区透过修复）")
	panel.show_window(root)
	assert_true((panel.container.get_node("ExcavateMapContent/FrameContainer/InfoLayer/%EmptyLabel") as Control).visible,
		"空列表 EmptyLabel 可见（单机护栏，源无空态文本）")
	assert_eq((panel.container.get_node("ExcavateMapContent/FrameContainer/InfoLayer/%EmptyLabel") as Label).text,
		"暂无矿点，点击「搜索」发现矿点", "空列表兜底文案")
	panel.remove_window()
	root.queue_free()


# fill：mine+monster 双矿点 → 翻页/页签/箭头联动（照源 doTurnPage/refreshPageTag/
# showArrow）+ title 贴图随 typeid 切换（refreshPageTitle）+ 产量行 mine 分支
# （refreshBaseRecord）+ cost 数值与颜色二态（refreshCostLabel）。
func test_map_fill_pages_tags_and_records() -> void:
	var root := Node.new()
	add_child(root)
	var now: int = int(Time.get_unix_time_from_system())
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.excavate.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": now - 60, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0,
		"_wild_id": 30001, "_team": [],
	})
	pd.excavate.excavate_data.append({
		"_id": 2, "_type_id": 1, "_owner": "monster", "_state": "searched",
		"_found_ts": now - 60, "_produce_speed": 5.0, "_storage": 300, "_res_got": 0.0,
		"_wild_id": 30002, "_team": [],
	})
	var panel := ExcavateMapPanel.new("excavate_map", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	var fc: Control = panel.container.get_node("ExcavateMapContent/FrameContainer") as Control
	if fc == null:
		fail_test("content 未装配")
		panel.remove_window()
		root.queue_free()
		return
	# 首页（index 0 = mine typeid 4 gold）：title 贴图随 typeid 切 gold_1
	var title: TextureRect = fc.get_node("%Title") as TextureRect
	assert_eq(title.texture.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_name_gold_1.png",
		"title fill typeid=4 → name_gold_1（源 refreshPageTitle title_res[4]）")
	# 箭头显隐（源 showArrow:513-530）：2 条数据双箭头可见，index=1 隐藏左
	assert_false(left_arrow(panel).visible, "首页 left_button 隐藏（源 :523-525 index==1）")
	assert_true(right_arrow(panel).visible, "首页 right_button 可见")
	# 产量行 mine 分支（源 refreshBaseRecord:318-377）
	var explain_ctn: Control = fc.get_node("InfoLayer/%ExplainContainer") as Control
	var lack_ctn: Control = explain_ctn.get_node("LackLabelContainer") as Control
	assert_eq((lack_ctn.get_node("%LackTitle") as Label).text, cm.get_lstr("MAP.MY_ACCUMULATED_RESOURCES_"),
		"mine：lack 标题=我的累计资源（源 :336 storageTitle）")
	assert_true((lack_ctn.get_node("%LackIconGold") as Control).visible, "mine：typeid=4 → gold icon（源 :350-375）")
	assert_false((lack_ctn.get_node("%LackIconDiamond") as Control).visible, "mine：diamond icon 隐藏")
	assert_eq((lack_ctn.get_node("%LackNumber") as Label).text, "x10",
		"mine：累计=x10（speed 10/分×1 分，源 getProduced）")
	var speed_ctn: Control = explain_ctn.get_node("SpeedLabelContainer") as Control
	assert_eq((speed_ctn.get_node("%SpeedTitle") as Label).text, cm.get_lstr("MAP.MY_PRODUCTION_SPEED_"),
		"mine：speed 标题=我的生产速度")
	# 页签（源 refreshPageTag：2 数据可见、2 图标、当前页 selected 态）
	var ptc: Control = fc.get_node("%PageTagContainer") as Control
	assert_true(ptc.visible, "≥2 数据 page_tag_container 可见（源 :1067-1072）")
	var tag_host: Control = ptc.get_node("%TagHost") as Control
	assert_eq(tag_host.get_child_count(), 2, "2 矿点 → 2 页签图标")
	var tag1: TextureRect = tag_host.get_child(0) as TextureRect
	assert_true(tag1.texture.resource_path.contains("_current"), "当前页 tag1=selected 态（_current 贴图）")
	assert_true(tag1.texture.resource_path.contains("gold"), "tag1 类型图 gold（typeid=4）")
	var tag2: TextureRect = tag_host.get_child(1) as TextureRect
	assert_false(tag2.texture.resource_path.contains("_current"), "非当前页 tag2=normal 态")
	# cost fill（源 refreshCostLabel:1209：数值+颜色随金币）
	var cost: Label = fc.get_node("InfoLayer/%ResearchFrame/ResearchContainer/%CostLabel") as Label
	assert_eq(cost.text, "100", "首搜 cost=100 fill")
	assert_eq(cost.modulate, Color.WHITE, "金币充足态 modulate 白（基色橙）")
	# search/research label 二态（源 refresh:407-413 checkSearching）
	assert_true((fc.get_node("InfoLayer/%ResearchFrame/ResearchContainer/%ResearchButton/SearchLabel") as Control).visible,
		"无进行中搜索点 → search_label 显示")
	# 翻页（源 turnPage/doTurnPage：index+1 + refresh 联动）
	panel._on_next()
	assert_eq(title.texture.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_name_diamond_1.png",
		"翻页后 title 切 typeid=1 → name_diamond_1")
	assert_true((tag_host.get_child(1) as TextureRect).texture.resource_path.contains("_current"),
		"翻页后 tag2 selected")
	assert_false((tag_host.get_child(0) as TextureRect).texture.resource_path.contains("_current"),
		"tag1 回 normal")
	# monster 分支产量行（源 :330-334 可掠夺）
	assert_eq((lack_ctn.get_node("%LackTitle") as Label).text, cm.get_lstr("MAP.YOU_CAN_PLUNDER_"),
		"monster：lack 标题=可以掠夺（源 :331）")
	assert_true((lack_ctn.get_node("%LackIconDiamond") as Control).visible, "monster：typeid=1 → diamond icon")
	assert_false((lack_ctn.get_node("%LackIconGold") as Control).visible, "monster：gold icon 隐藏")
	# 末页右箭头隐藏（源 showArrow index==#data）
	assert_false(right_arrow(panel).visible, "末页 right_button 隐藏（源 :520-522）")
	assert_true(left_arrow(panel).visible, "末页 left_button 可见")
	panel.remove_window()
	root.queue_free()


# 辅助：根级左右箭头（非 FrameContainer 子）
func left_arrow(panel: ExcavateMapPanel) -> Control:
	return panel.container.get_node("ExcavateMapContent/%LeftButton") as Control


func right_arrow(panel: ExcavateMapPanel) -> Control:
	return panel.container.get_node("ExcavateMapContent/%RightButton") as Control


# map 内搜索（照源 registerSearchButton:137-204 clickHandler → showFog 搜索链，
# 单机 fog fade/转圈动画简化为 icon 圆周 + 完成回调）：research_button 点击 →
# ExcavateManager.search → 新矿点 focus 定位 + tag/title 刷新 + 消耗联动。
func test_map_search_in_place_flow() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.excavate.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0,
		"_wild_id": 30001, "_team": [],
	})
	var panel := ExcavateMapPanel.new("excavate_map", {})
	panel.setup_panel(pd, BattleRng.new(7))
	panel.show_window(root)
	var btn: Button = panel.container.get_node("ExcavateMapContent/FrameContainer/InfoLayer/%ResearchFrame/ResearchContainer/%ResearchButton") as Button
	btn.pressed.emit()
	assert_true(panel._searching, "点击 research_button 进入搜索动画态（源 showFog→showSearchIcon）")
	assert_eq(pd.excavate.get_data_list().size(), 1, "动画期未入列（源转圈完成后才 search）")
	panel._finish_search()
	assert_eq(pd.excavate.get_data_list().size(), 2, "完成后新矿点入列（源 doSearchExcavateReply refreshData）")
	assert_eq(pd.excavate.search_times, 1, "search_times +1（源 refreshExcavateSearchTime）")
	assert_false(panel._searching, "动画态复位")
	var fc: Control = panel.container.get_node("ExcavateMapContent/FrameContainer") as Control
	var ptc: Control = fc.get_node("%PageTagContainer") as Control
	assert_eq((ptc.get_node("%TagHost") as Control).get_child_count(), 2, "页签随新点更新")
	panel.remove_window()
	root.queue_free()


# focus_excavate 定位（战斗结束重弹定位刚打矿点，接口保留）
func test_map_focus_excavate() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	for i: int in range(3):
		pd.excavate.excavate_data.append({
			"_id": i + 1, "_type_id": 4 + i, "_owner": "mine", "_state": "occupy",
			"_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0,
			"_wild_id": 30001, "_team": [],
		})
	var panel := ExcavateMapPanel.new("excavate_map", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	panel.focus_excavate(3)
	assert_eq(panel._index, 2, "focus 定位到 id=3（index 2）")
	var fc: Control = panel.container.get_node("ExcavateMapContent/FrameContainer") as Control
	assert_true(((fc.get_node("%PageTagContainer/%TagHost") as Control).get_child(2) as TextureRect).texture.resource_path.contains("_current"),
		"focus 后 tag3 selected")
	panel.remove_window()
	root.queue_free()


# ── ExcavateSearchPanel：两件套 + A 债 #1/#2 归源（excavate 批 Task 4，2026-08-17）──

# search toast + type name + 按钮文案 LSTR key 全在 JSON
func test_search_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"MAP.TODAY_THE_SEARCH_HAS_REACHED_THE_MAXIMUM_NUMBER_OF_TIMES_",
		"ERRORINFO.INSUFFICIENT_COINS",
		"MAP.DIAMOND_MINE", "MAP.GOLDMINE", "MAP.LABORATORY",
		"EXCAVATEHISTORY.DEFENSIVE_RECORD", "EXCAVATEMAP.RULES",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# search 关键资源存在（bg/框体/按钮/图标贴图全量）
func test_search_assets_exist() -> void:
	var paths: Array[String] = [
		"res://assets/ui/alpha/HVGA/bg.jpg",
		"res://assets/ui/alpha/HVGA/excavate/excavate_empty.jpg",
		"res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_main_title.png",
		"res://assets/ui/alpha/HVGA/excavate/excavate_magnifier.png",
		"res://assets/ui/alpha/HVGA/backbtn.png",
		"res://assets/ui/alpha/HVGA/tavern_button_1.png",
		"res://assets/ui/alpha/HVGA/tavern_button_2.png",
		"res://assets/ui/alpha/HVGA/sell_number_button.png",
		"res://assets/ui/alpha/HVGA/sell_number_button_down.png",
		"res://assets/ui/alpha/HVGA/crusade/crusade_reset_bg.png",
		"res://assets/ui/alpha/HVGA/goldicon_small.png",
	]
	for p in paths:
		assert_true(ResourceLoader.exists(p), "资源存在：" + p)


# A 类债 #1/#2 归源：uieditor/excavatesearch.lua:112（frame_bg fix_wh 702.34375x392.96875）
# 与 :129-135（frame fix_wh 733.59375x454.6875，PIL 实测纹理 734x455 ratio 1.6132，
# fix ratio 1.61325 完全等比 → 偏差 0.004%）。弃迁移 520x400/500x380 强拉
# （ratio 1.30/1.32 vs 1.6132 偏差 19%/18%，scan_texture_aspect 报警件）。
# frame_bg 照源 702.34x392.97 系源对老资产(899x503÷1.28)的等比值，现资产 734x455
# 资产换代致 ratio 1.7873 vs 1.6132 偏差 10.8%（HC 多语言项目查无 899x503 版）——
# 源显式尺寸照源直译不"修正"（宽度 702.34 为填满 frame 透明内空的功能尺寸，
# 等比收窄会露 bg 缝），故 frame 断言 ratio 守卫、frame_bg 只断言尺寸。
# search_frame=Scale9Sprite crusade_reset_bg cap(23.44,23.44,19.53,19.53)@75x75
# → patch L23/B23/R32/T32，opacity 200 → modulate.a=200/255。
func test_search_frame_source_fidelity() -> void:
	var content: Control = (load("res://scenes/ui/excavate_search_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: TextureRect = content.get_node_or_null("FrameContainer/Frame") as TextureRect
	assert_not_null(frame, "Frame 存在且为 TextureRect（源 t=Sprite）")
	if frame == null:
		content.queue_free()
		return
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png",
		"frame 贴图归源 excavate_main_frame")
	assert_almost_eq(frame.size.x, 733.59, 0.02, "frame w=733.59（fix_wh 直译，A 债 #1）")
	assert_almost_eq(frame.size.y, 454.69, 0.02, "frame h=454.69")
	var tex: Texture2D = frame.texture
	var ratio_dev: float = abs(frame.size.x / frame.size.y - float(tex.get_width()) / float(tex.get_height())) / (float(tex.get_width()) / float(tex.get_height()))
	assert_lt(ratio_dev, 0.08, "frame 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (ratio_dev * 100.0))
	var frame_bg: TextureRect = content.get_node_or_null("FrameContainer/FrameBg") as TextureRect
	assert_not_null(frame_bg, "FrameBg 存在且为 TextureRect")
	if frame_bg != null:
		assert_eq(frame_bg.texture.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_empty.jpg",
			"frame_bg 贴图归源 excavate_empty")
		assert_almost_eq(frame_bg.size.x, 702.34, 0.02, "frame_bg w=702.34（fix_wh 直译，A 债 #2）")
		assert_almost_eq(frame_bg.size.y, 392.97, 0.02, "frame_bg h=392.97（源显式尺寸，资产换代 10.8% 记录不断言）")
	var search_frame: NinePatchRect = content.get_node_or_null("SearchFrame") as NinePatchRect
	assert_not_null(search_frame, "SearchFrame 存在且为 NinePatchRect（源 Scale9Sprite）")
	if search_frame != null:
		assert_eq(search_frame.texture.resource_path, "res://assets/ui/alpha/HVGA/crusade/crusade_reset_bg.png",
			"search_frame 贴图归源 crusade_reset_bg")
		assert_eq(search_frame.patch_margin_left, 23, "cap left=23.44 取整 23")
		assert_eq(search_frame.patch_margin_bottom, 23, "cap bottom=23.44 取整 23")
		assert_eq(search_frame.patch_margin_right, 32, "cap right=75-23.44-19.53=32.03 取整 32")
		assert_eq(search_frame.patch_margin_top, 32, "cap top=32.03 取整 32")
		assert_almost_eq(search_frame.modulate.a, 200.0 / 255.0, 0.005, "opacity=200/255（源 config.opacity）")
	# 受控裁剪守卫：history_red_tag 不建（源 refreshHistoryTag 依赖服务器已读标记
	# checkUnreadExcavateHistory，数据层无对应状态恒不可见，照 history 批 vit_button 口径）
	var histroy: Button = content.get_node_or_null("%HistroyButton") as Button
	assert_not_null(histroy, "HistroyButton 存在（源节点名 histroy_button 拼写照源）")
	if histroy != null:
		assert_eq(histroy.get_child_count(), 0, "histroy_button 无子节点（label 走 Button.text，red_tag 受控裁剪）")
	content.queue_free()


# 静态 rect 守卫（防 parenting 回归）：照 uieditor/excavatesearch.lua 声明表直译。
# 场景层 to_godot(x,y)=(x+80,560-y)：frame_container Layer 800x480.47 anchor(0,0)
# @(-3.13,3.91) → (76.875,75.625)-(876.875,556.094)；search_icon 中心 (400,254.69)
# → (480,305.31)；histroy 117.19x53.13 中心 (154.69,81.25)→(234.69,478.75)；
# explain 66.41x53.13 中心 (250.78,81.25)→(330.78,478.75)；search_frame 171.88x101.56
# 中心 (637.5,99.22)→(717.5,460.78)。frame_container 局部（Cocos 子 y 翻转从上=480.47-cy）：
# frame 中心 (402.34,246.88)；title 中心 (402.34,49.22) 246.09x35.94；back 74x75px÷CS
# =57.78x58.54 中心 (65.63,46.09)。search_container@search_frame 局部 (85.94,7.81)
# 39.06²；search_button 140.63x50.78 中心 container 局部 (0.78,60.94)（cy=-21.88 越界
# 挂下）；cost_label anchor(1,0.5) 右缘 container 局部 48.44 → 全局 765.94。
func test_search_content_static_rects() -> void:
	var content: Control = (load("res://scenes/ui/excavate_search_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var bg_s: Control = content.get_node("Bg") as Control
	# 实跑反馈修复（2026-08-17）：pushScene 全屏页语义铺满视口 + STOP（同 map 件守卫）。
	assert_almost_eq(bg_s.size.x, 960.0, 0.02, "search bg w=960 全屏")
	assert_almost_eq(bg_s.size.y, 640.0, 0.02, "search bg h=640 全屏")
	assert_eq((bg_s as TextureRect).mouse_filter, Control.MOUSE_FILTER_STOP, "search bg STOP 挡点击穿透")
	var slbl: TextureButton = content.get_node("SearchFrame/SearchContainer/%SearchButton/SearchLabel") as TextureButton
	assert_eq(slbl.texture_normal.resource_path, "res://assets/ui/alpha/HVGA/excavate/excavate_word_search.png",
		"SearchLabel 接线文字图 word_search（源在库未接线的本地化遗留，受控偏离）")
	assert_almost_eq(slbl.size.x, 87.0, 0.02, "SearchLabel w=87（word_search 原尺寸）")
	assert_almost_eq(slbl.size.y, 25.0, 0.02, "SearchLabel h=25")
	var fc: Control = content.get_node("FrameContainer") as Control
	assert_almost_eq(fc.position.x, 76.875, 0.02, "frame_container offset_left=76.875")
	assert_almost_eq(fc.position.y, 75.625, 0.02, "frame_container offset_top=75.625")
	assert_almost_eq(fc.size.x, 800.0, 0.02, "frame_container w=800（scaleSize 直译）")
	assert_almost_eq(fc.size.y, 480.47, 0.02, "frame_container h=480.47")
	var frame: Control = fc.get_node("Frame") as Control
	assert_almost_eq(frame.position.x + frame.size.x * 0.5, 402.34, 0.02, "frame 局部中心 x=402.34")
	assert_almost_eq(frame.position.y + frame.size.y * 0.5, 246.88, 0.02, "frame 局部中心 y=246.88（480.47-233.59）")
	var title: Control = fc.get_node("Title") as Control
	assert_almost_eq(title.position.x + title.size.x * 0.5, 402.34, 0.02, "title 局部中心 x=402.34")
	assert_almost_eq(title.position.y + title.size.y * 0.5, 49.22, 0.02, "title 局部中心 y=49.22（480.47-431.25）")
	assert_almost_eq(title.size.x, 246.09, 0.02, "title w=246.09（fix_wh 直译）")
	var title_tex: Texture2D = (fc.get_node("Title") as TextureRect).texture
	var title_dev: float = abs(title.size.x / title.size.y - float(title_tex.get_width()) / float(title_tex.get_height())) / (float(title_tex.get_width()) / float(title_tex.get_height()))
	assert_lt(title_dev, 0.08, "title 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (title_dev * 100.0))
	var back_btn: Control = fc.get_node("%BackButton") as Control
	assert_almost_eq(back_btn.position.x + back_btn.size.x * 0.5, 65.63, 0.02, "back 局部中心 x=65.63")
	assert_almost_eq(back_btn.position.y + back_btn.size.y * 0.5, 46.09, 0.02, "back 局部中心 y=46.09（480.47-434.38）")
	var back_tex: Texture2D = (fc.get_node("%BackButton") as TextureButton).texture_normal
	var back_dev: float = abs(back_btn.size.x / back_btn.size.y - float(back_tex.get_width()) / float(back_tex.get_height())) / (float(back_tex.get_width()) / float(back_tex.get_height()))
	assert_lt(back_dev, 0.08, "back 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (back_dev * 100.0))
	var icon: Control = content.get_node("%SearchIcon") as Control
	assert_almost_eq(icon.position.x + icon.size.x * 0.5, 480.0, 0.02, "search_icon 中心 x=480（to_godot(400)）")
	assert_almost_eq(icon.position.y + icon.size.y * 0.5, 305.31, 0.02, "search_icon 中心 y=305.31（560-254.69）")
	assert_almost_eq(icon.size.x, 100.78, 0.02, "search_icon w=100.78（fix_wh 直译）")
	assert_almost_eq(icon.size.y, 102.34, 0.02, "search_icon h=102.34")
	var histroy: Control = content.get_node("%HistroyButton") as Control
	assert_almost_eq(histroy.position.x + histroy.size.x * 0.5, 234.69, 0.02, "histroy 中心 x=234.69（to_godot(154.69)）")
	assert_almost_eq(histroy.position.y + histroy.size.y * 0.5, 478.75, 0.02, "histroy 中心 y=478.75（560-81.25）")
	assert_almost_eq(histroy.size.x, 117.19, 0.02, "histroy w=117.19（scaleSize 直译）")
	assert_almost_eq(histroy.size.y, 53.13, 0.02, "histroy h=53.13")
	var explain: Control = content.get_node("%ExplainButton") as Control
	assert_almost_eq(explain.position.x + explain.size.x * 0.5, 330.78, 0.02, "explain 中心 x=330.78（to_godot(250.78)）")
	assert_almost_eq(explain.size.x, 66.41, 0.02, "explain w=66.41（scaleSize 直译）")
	var search_frame: Control = content.get_node("SearchFrame") as Control
	assert_almost_eq(search_frame.position.x + search_frame.size.x * 0.5, 717.5, 0.02, "search_frame 中心 x=717.5（to_godot(637.5)）")
	assert_almost_eq(search_frame.position.y + search_frame.size.y * 0.5, 460.78, 0.02, "search_frame 中心 y=460.78（560-99.22）")
	assert_almost_eq(search_frame.size.x, 171.88, 0.02, "search_frame w=171.88（scaleSize 直译）")
	assert_almost_eq(search_frame.size.y, 101.56, 0.02, "search_frame h=101.56")
	var search_btn: Control = content.get_node("%SearchButton") as Control
	assert_almost_eq(search_btn.size.x, 140.63, 0.02, "search_button w=140.63（scaleSize 直译）")
	assert_almost_eq(search_btn.size.y, 50.78, 0.02, "search_button h=50.78")
	var btn_center: Vector2 = search_btn.get_global_rect().get_center()
	assert_almost_eq(btn_center.x, 718.28, 0.02, "search_button 全局中心 x=718.28（cy=-21.88 越界挂下）")
	assert_almost_eq(btn_center.y, 478.75, 0.02, "search_button 全局中心 y=478.75")
	var gold: Control = content.get_node("%GoldIcon") as Control
	var gold_tex: Texture2D = (content.get_node("%GoldIcon") as TextureRect).texture
	var gold_dev: float = abs(gold.size.x / gold.size.y - float(gold_tex.get_width()) / float(gold_tex.get_height())) / (float(gold_tex.get_width()) / float(gold_tex.get_height()))
	assert_lt(gold_dev, 0.08, "gold 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (gold_dev * 100.0))
	var cost: Control = content.get_node("%CostLabel") as Control
	assert_almost_eq(cost.get_global_rect().position.x + cost.size.x, 765.94, 0.02, "cost 右缘全局 x=765.94（源 anchor(1,0.5)@48.44）")
	# 绘制序守卫（防反盖）：源 z bg=0 < frame_container=5 < 同 z=10 组按声明序
	# （search_icon→histroy→explain→search_frame）
	assert_lt(content.get_node("Bg").get_index(), fc.get_index(), "bg 声明序先于 frame_container（z 0<5）")
	assert_lt(fc.get_index(), content.get_node("%SearchIcon").get_index(), "frame_container 先于 search_icon（z 5<10）")
	assert_lt(content.get_node("%SearchIcon").get_index(), histroy.get_index(), "search_icon 先于 histroy（同 z=10 声明序）")
	assert_lt(explain.get_index(), search_frame.get_index(), "explain 先于 search_frame（同 z=10 声明序）")
	content.queue_free()


# 旧范式退役守卫（两件套 SOP）：panel.gd 源码无运行时样式/静态节点构造。
func test_search_no_legacy_runtime_styling() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/excavate_search_panel.gd")
	assert_false(src.contains("UiScale9Button"), "UiScale9Button 已退役")
	assert_false(src.contains("add_theme_color_override"), "运行时颜色 override 已退役")
	assert_false(src.contains("add_theme_font_size_override"), "运行时字号 override 已退役")
	assert_false(src.contains("add_theme_stylebox_override"), "运行时样式 override 已退役")
	for ctor: String in ["Label.new(", "Button.new(", "TextureRect.new(", "TextureButton.new(", "Control.new("]:
		assert_false(src.contains(ctor), "无运行时静态节点构造 %s（静态结构全在 tscn）" % ctor)


# search 面板装配 + fill（按钮 LSTR 文案 / cost 数值与颜色二态）
func test_search_panel_builds_without_error() -> void:
	# hud_identity 接线守卫（实跑反馈修复二轮 2026-08-17：头像区透过——search/map 须切子场景精简 StatusBar）
	var sp := ExcavateSearchPanel.new("excavate", {})
	assert_eq(sp.hud_identity, "", "构造期未设（setup_panel 时设）")
	sp.queue_free()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := ExcavateSearchPanel.new("excavate", {})
	panel.setup_panel(pd, BattleRng.new(1))
	assert_eq(panel.hud_identity, "excavate", "search 件 hud_identity=excavate（头像区透过修复）")
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "container 非空")
	assert_eq(panel._cost_label.text, "100", "首搜消耗显示 100")
	# cost 颜色二态走 fill modulate（金币 100000 充足 → 白=基色橙）
	assert_eq(panel._cost_label.modulate, Color.WHITE, "cost 充足态 modulate 白（基色橙，源 refreshCostLabel:88）")
	pd.hero_manager.gold = 50
	panel._refresh_cost()
	assert_eq(panel._cost_label.modulate, Color(1.0, 0.0, 0.0), "cost 不足态 modulate 红（清 G/B 通道，源 :86）")
	var histroy: Button = panel.container.get_node("ExcavateSearchContent/%HistroyButton") as Button
	assert_eq(histroy.text, cm.get_lstr("EXCAVATEHISTORY.DEFENSIVE_RECORD"), "histroy 文案 fill（源节点名拼写照源）")
	var explain: Button = panel.container.get_node("ExcavateSearchContent/%ExplainButton") as Button
	assert_eq(explain.text, cm.get_lstr("EXCAVATEMAP.RULES"), "explain 文案 fill")
	panel.remove_window()
	root.queue_free()


# ── ExcavateTeamPanel：两件套 + 静态 5 英雄槽（excavate 批 Task 6，2026-08-17）──

# team LSTR key 全在 JSON（按钮/产量行/野怪名/小时后缀）
func test_team_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"EXCAVATETEAM.ADJUST_FORMATION", "excavateteam.1.10.1.002",
		"EXCAVATETEAM.CUMULATIVE_PRODUCTION_RESOURCES_",
		"EXCAVATEMAP.PRODUCTION_SPEED_", "TIME.HOUR",
		"EXCAVATEWILDENEMY.WITHERED_MINERS",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)
		assert_false(v.is_empty(), "LSTR 值非空：" + k)


# 框体归源（本件不在 A 债 8 处清单内，照源实证）：uieditor/excavateteam.lua:2-22
# frame = Scale9Sprite **main_vit_tips** scaleSize 632.81x242.19 中心 (400,219.53)，
# cap CCRectMake(17.97,18.75,46.88,11.72)@103x61 像素直译：L=17.97→18、B=18.75→19、
# R=103-17.97-46.88=38.15→38、T=61-18.75-11.72=30.53→31。
# 弃 excavate_main_frame 600x440 误用（贴图选择+尺寸双重失真：Scale9 框拉到
# 2.61 比例非源 632.81/242.19 口径，且源框本是 main_vit_tips 系）。
func test_team_frame_source_fidelity() -> void:
	var content: Control = (load("res://scenes/ui/excavate_team_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: NinePatchRect = content.get_node_or_null("Frame") as NinePatchRect
	assert_not_null(frame, "Frame 存在且为 NinePatchRect（源 Scale9Sprite）")
	if frame == null:
		content.queue_free()
		return
	assert_not_null(frame.texture, "frame 有贴图")
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/main_vit_tips.png",
		"frame 贴图归源 main_vit_tips（弃 excavate_main_frame 误用）")
	assert_almost_eq(frame.size.x, 632.81, 0.02, "frame w=632.81（scaleSize 直译）")
	assert_almost_eq(frame.size.y, 242.19, 0.02, "frame h=242.19")
	assert_eq(frame.patch_margin_left, 18, "cap left=17.97 取整 18")
	assert_eq(frame.patch_margin_bottom, 19, "cap bottom=18.75 取整 19")
	assert_eq(frame.patch_margin_right, 38, "cap right=38.15 取整 38")
	assert_eq(frame.patch_margin_top, 31, "cap top=30.53 取整 31")
	content.queue_free()


# 静态 rect 守卫（防 parenting 回归）：照 uieditor/excavateteam.lua 声明表直译。
# 场景层：frame 中心 (400,219.53) → Godot (163.595,219.375)-(796.405,461.565)。
# frame_container Layer 156.25² @frame 局部 (316.41,142.97)（frame H=242.19）→
# Godot offset (316.41,-57.03)；monster 分支 fill 整层下移（源 :530 DGccp(0,-35)px
# →27.34 点）。fc 局部（H=156.25，y-up→y-down）：close 中心 (303.13,82.81)→(303.13,73.44)；
# player 组（原点 (4.69,-3.13)）：head (-280.47,73.44) 62.5²、level (-213.28,86.72)
# 39.06x31.25、name_bg 中心 (-26.56,103.91) 329.69x26.56。team 组（原点 (0,-8.59)）：
# hero_container_1..5 85.94² x=-281.25/-188.28/-96.88/-4.69/85.16 y≈-74；
# cg 组（原点 (0,5.47)）：change 中心 (236.72,167.97)、giveup 中心 (236.72,221.88)
# 各 125x49.22；go_battle 中心 (233.59,110.94) 100x96.09 默认隐藏。
func test_team_content_static_rects() -> void:
	var content: Control = (load("res://scenes/ui/excavate_team_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: Control = content.get_node("Frame") as Control
	assert_almost_eq(frame.position.x, 163.595, 0.02, "frame offset_left=163.595")
	assert_almost_eq(frame.position.y, 219.375, 0.02, "frame offset_top=219.375")
	var fc: Control = content.get_node("Frame/FrameContainer") as Control
	assert_almost_eq(fc.position.x, 316.41, 0.02, "frame_container offset_left=316.41（frame 局部）")
	assert_almost_eq(fc.position.y, -57.03, 0.02, "frame_container offset_top=-57.03")
	assert_almost_eq(fc.size.x, 156.25, 0.02, "frame_container w=156.25（scaleSize 直译）")
	var close_btn: Control = fc.get_node("%CloseBtn") as Control
	assert_almost_eq(close_btn.position.x + close_btn.size.x * 0.5, 303.13, 0.02, "close 中心 x=303.13")
	assert_almost_eq(close_btn.position.y + close_btn.size.y * 0.5, 73.44, 0.02, "close 中心 y=73.44（156.25-82.81）")
	assert_almost_eq(close_btn.size.x, 49.22, 0.02, "close w=49.22（fix_wh 直译）")
	assert_almost_eq(close_btn.size.y, 52.34, 0.02, "close h=52.34")
	# 纵横比守卫：49.22/52.34=0.9404 vs 纹理 65/66=0.9848 偏差 4.5%（源轻微拉伸照源）
	var close_tex: Texture2D = (fc.get_node("%CloseBtn") as TextureButton).texture_normal
	var close_dev: float = abs(close_btn.size.x / close_btn.size.y - float(close_tex.get_width()) / float(close_tex.get_height())) / (float(close_tex.get_width()) / float(close_tex.get_height()))
	assert_lt(close_dev, 0.08, "close 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (close_dev * 100.0))
	# 玩家信息区（head/level 建位不填，getTeamHead/getLevelIcon 基础设施缺失照 battle_report 口径）
	var head: Control = fc.get_node("HeadContainer") as Control
	assert_almost_eq(head.position.x, -280.47, 0.02, "head_container offset_left=-280.47")
	assert_almost_eq(head.position.y, 73.44, 0.02, "head_container offset_top=73.44")
	assert_almost_eq(head.size.x, 62.5, 0.02, "head_container w=62.5")
	var name_bg: Control = fc.get_node("NameBg") as Control
	assert_almost_eq(name_bg.position.x + name_bg.size.x * 0.5, -26.56, 0.02, "name_bg 中心 x=-26.56")
	assert_almost_eq(name_bg.position.y + name_bg.size.y * 0.5, 103.91, 0.02, "name_bg 中心 y=103.91")
	assert_almost_eq(name_bg.size.x, 329.69, 0.02, "name_bg w=329.69（fix_wh 直译）")
	var name_dev: float = abs(name_bg.size.x / name_bg.size.y - 422.0 / 34.0) / (422.0 / 34.0)
	assert_lt(name_dev, 0.08, "name_bg 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (name_dev * 100.0))
	# 静态 5 英雄槽（源 hero_container_1..5 声明表静态槽位，非动态行）
	var slot1: Control = fc.get_node("HeroSlot1") as Control
	assert_almost_eq(slot1.position.x, -281.25, 0.02, "hero_slot_1 offset_left=-281.25")
	assert_almost_eq(slot1.position.y, 153.13, 0.02, "hero_slot_1 offset_top=153.13")
	var slot5: Control = fc.get_node("HeroSlot5") as Control
	assert_almost_eq(slot5.position.x, 85.16, 0.02, "hero_slot_5 offset_left=85.16")
	assert_almost_eq(slot5.position.y, 152.34, 0.02, "hero_slot_5 offset_top=152.34（y=-73.44 档）")
	assert_almost_eq(slot5.size.x, 85.94, 0.02, "hero_slot w=85.94（scaleSize 直译）")
	# cg 按钮组（change/giveup，源 :733-788 scaleSize 125x49.22）
	var cg: Control = fc.get_node("CgButtonContainer") as Control
	var change_btn: Control = cg.get_node("%ChangeBtn") as Control
	assert_almost_eq(change_btn.position.x + change_btn.size.x * 0.5, 236.72, 0.02, "change 中心 x=236.72")
	assert_almost_eq(change_btn.position.y + change_btn.size.y * 0.5, 167.97, 0.02, "change 中心 y=167.97（156.25+11.72）")
	assert_almost_eq(change_btn.size.x, 125.0, 0.02, "change w=125（scaleSize 直译）")
	assert_almost_eq(change_btn.size.y, 49.22, 0.02, "change h=49.22")
	var giveup_btn: Control = cg.get_node("%GiveupBtn") as Control
	assert_almost_eq(giveup_btn.position.y + giveup_btn.size.y * 0.5, 221.88, 0.02, "giveup 中心 y=221.88（156.25+65.63）")
	# 出战按钮（go_battle fix_wh 100x96.09 默认隐藏，fill 按 owner 切；team 层摊平
	# 进 fc：中心 fc y-up = -8.59-32.81=-41.41 → Godot 197.66）
	var battle_btn: Control = fc.get_node("%BattleBtn") as Control
	assert_almost_eq(battle_btn.position.x + battle_btn.size.x * 0.5, 233.59, 0.02, "battle 中心 x=233.59")
	assert_almost_eq(battle_btn.position.y + battle_btn.size.y * 0.5, 197.66, 0.02, "battle 中心 y=197.66（156.25+8.59+32.81）")
	assert_almost_eq(battle_btn.size.x, 100.0, 0.02, "battle w=100（fix_wh 直译）")
	assert_false(battle_btn.visible, "battle 默认隐藏（源 config.visible=false，fill 按 owner 切）")
	var battle_tex: Texture2D = (fc.get_node("%BattleBtn") as TextureButton).texture_normal
	var battle_dev: float = abs(battle_btn.size.x / battle_btn.size.y - float(battle_tex.get_width()) / float(battle_tex.get_height())) / (float(battle_tex.get_width()) / float(battle_tex.get_height()))
	assert_lt(battle_dev, 0.08, "battle 显示比例 vs 纹理比例偏差 ≤8%%（实测 %.1f%%）" % (battle_dev * 100.0))
	# 产量行（explain_container 局部）：lack/speed 容器 156.25x46.88 @(-249.22,-132.03)/(-22.66,-132.03)
	var explain: Control = fc.get_node("%ExplainContainer") as Control
	var lack_ctn: Control = explain.get_node("LackLabelContainer") as Control
	assert_almost_eq(lack_ctn.position.x, -249.22, 0.02, "lack_container offset_left=-249.22")
	assert_almost_eq(lack_ctn.position.y, 241.41, 0.02, "lack_container offset_top=241.41（156.25+132.03-46.88）")
	var speed_ctn: Control = explain.get_node("SpeedLabelContainer") as Control
	assert_almost_eq(speed_ctn.position.x, -22.66, 0.02, "speed_container offset_left=-22.66")
	var lack_title: Label = lack_ctn.get_node("%LackTitle") as Label
	assert_almost_eq(lack_title.position.x + lack_title.size.x, 88.28, 0.02, "lack_title 右缘 x=88.28（源 anchor(1,0.5)）")
	assert_almost_eq(lack_title.position.y + lack_title.size.y * 0.5, 23.44, 0.02, "lack_title 中线 y=23.44（46.88-23.44）")
	var lack_num: Label = lack_ctn.get_node("%LackNumber") as Label
	assert_almost_eq(lack_num.position.x, 125.0, 0.02, "lack_number 左缘 x=125（源 anchor(0,0.5)）")
	# 结构守卫（防 parenting 回归）：frame_container 挂 Frame 内（源 parent="frame"），
	# 且 Frame 为 content 首个静态底板节点
	assert_eq(fc.get_parent(), frame, "frame_container 挂 Frame 下（源 parent=frame）")
	assert_eq(frame.get_index(), 0, "Frame 为 content 首子节点（最底层绘制）")
	assert_eq(fc.get_index(), 0, "frame_container 为 Frame 首子节点（源声明序首位）")
	# 单机受控裁剪守卫：guild 组（mine/monster 均恒隐藏）、vitality 组（单机战斗无体力
	# 消耗，显示即欺骗 UI）、迁移发明 Title（源标题区是玩家名 name_bg+name）不建。
	assert_null(content.get_node_or_null("Title"), "迁移发明 Title 不建（源无标题 Label，name_bg+name 即标题区）")
	assert_null(fc.get_node_or_null("GuildContainer"), "guild 组不建（联机公会信息，单机恒不可见）")
	assert_null(fc.get_node_or_null("VitalityContainer"), "vitality 组不建（单机 excavate 战斗不扣体力）")
	content.queue_free()


# 旧范式退役守卫（两件套 SOP）：panel.gd 源码无运行时样式/静态节点构造
# （ReadheroIcon 跨域展示工具实例化除外，照 battle_report builder 口径）。
func test_team_no_legacy_runtime_styling() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/excavate_team_panel.gd")
	assert_false(src.contains("UiScale9Button"), "UiScale9Button 已退役")
	assert_false(src.contains("add_theme_color_override"), "运行时颜色 override 已退役")
	assert_false(src.contains("add_theme_font_size_override"), "运行时字号 override 已退役")
	assert_false(src.contains("add_theme_stylebox_override"), "运行时样式 override 已退役")
	for ctor: String in ["Label.new(", "Button.new(", "HBoxContainer.new(", "VBoxContainer.new(", "TextureRect.new(", "Control.new("]:
		assert_false(src.contains(ctor), "无运行时静态节点构造 %s（静态结构全在 tscn；ReadheroIcon 工具实例化除外）" % ctor)


# fill 分支（源 :489-536 enterExcavateTeam）：mine → cg 显示/battle 隐藏/explain 显示
# + 玩家名 + 产量行（icon 按 produce_type 三选一 + 数值）+ 5 槽 ReadheroIcon；
# monster → battle 显示/cg 隐藏/explain 隐藏 + 野怪名 LSTR + 框体矮化
# （frame 高 265px÷1.28=206.87 + frame_container 下移 35px÷1.28=27.34，源 :530-531）。
func test_team_fill_mine_and_monster() -> void:
	var root := Node.new()
	add_child(root)
	var now: int = int(Time.get_unix_time_from_system())
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.excavate.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": now, "_produce_speed": 10.0, "_storage": 500, "_res_got": 352.0,
		"_wild_id": 30001, "_team": [{"_team_id": 0,
			"_hero_bases": [1001, 1002],
			"_hero_dynas": [{"_hp_perc": 10000, "_mp_perc": 0}, {"_hp_perc": 10000, "_mp_perc": 0}]}],
	})
	var panel := ExcavateTeamPanel.new("excavate_team", {})
	panel.setup_panel(pd, 1, BattleRng.new(1), Callable())
	panel.show_window(root)
	var fc: Control = panel.container.get_node("ExcavateTeamContent/Frame/FrameContainer") as Control
	if fc == null:
		fail_test("content 未装配")
		panel.remove_window()
		root.queue_free()
		return
	assert_true((fc.get_node("CgButtonContainer") as Control).visible, "mine：cg 容器可见（源 :111-137 teamid=userid，容器级切换）")
	assert_true((fc.get_node("CgButtonContainer/%ChangeBtn") as Control).visible, "mine：change 按钮节点可见")
	assert_false((fc.get_node("%BattleBtn") as Control).visible, "mine：battle 隐藏（源 :110）")
	assert_true((fc.get_node("%ExplainContainer") as Control).visible, "mine：explain 显示（源 :507）+ vitality/guild 隐藏（:505-506）")
	assert_eq((fc.get_node("NameBg/%NameLabel") as Label).text, pd.player_name, "mine：玩家名 fill（源 :305-306 player 名兜底）")
	var slot1: Control = fc.get_node("HeroSlot1") as Control
	assert_gt(slot1.get_child_count(), 0, "mine：槽1 已填 ReadheroIcon")
	assert_gt((fc.get_node("HeroSlot2") as Control).get_child_count(), 0, "mine：槽2 已填")
	assert_eq((fc.get_node("HeroSlot3") as Control).get_child_count(), 0, "mine：槽3 空（2 英雄）")
	assert_false((fc.get_node("%EmptyHint") as Control).visible, "mine：有队空态提示隐藏")
	# 产量行 fill（type_id 4 → gold 组 icon，源 :441-457 type_id_group gold={4,5,6}）
	var explain: Control = fc.get_node("%ExplainContainer") as Control
	var lack_ctn: Control = explain.get_node("LackLabelContainer") as Control
	assert_eq((lack_ctn.get_node("%LackTitle") as Label).text, cm.get_lstr("EXCAVATETEAM.CUMULATIVE_PRODUCTION_RESOURCES_"), "lack 标题 LSTR fill")
	assert_true((lack_ctn.get_node("%LackIconGold") as Control).visible, "type_id=4 → gold icon 显示（源 :441-448）")
	assert_false((lack_ctn.get_node("%LackIconDiamond") as Control).visible, "diamond icon 隐藏")
	assert_eq((lack_ctn.get_node("%LackNumber") as Label).text, "x352", "lack 数值 fill（res_got=352，elapsed=0）")
	var speed_ctn: Control = explain.get_node("SpeedLabelContainer") as Control
	assert_eq((speed_ctn.get_node("%SpeedNumber") as Label).text, "x600/1" + cm.get_lstr("TIME.HOUR"),
		"speed 数值 fill（10/分×60=600/1小时，源 :469-476 整数档 %%d/%%d）")
	assert_true((speed_ctn.get_node("%SpeedIconGold") as Control).visible, "speed gold icon 显示")
	panel.remove_window()
	# monster 分支
	var pd2 := PlayerData.new(cm)
	pd2.apply_default_data()
	pd2.excavate.excavate_data.append({
		"_id": 2, "_type_id": 4, "_owner": "monster", "_state": "searched",
		"_found_ts": now, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0,
		"_wild_id": 1, "_team": [{"_team_id": 0,
			"_hero_bases": [{"_tid": 1001, "_level": 9, "_rank": 3, "_stars": 4}],
			"_hero_dynas": [{"_hp_perc": 10000, "_mp_perc": 0}]}],
	})
	var panel2 := ExcavateTeamPanel.new("excavate_team", {})
	panel2.setup_panel(pd2, 2, BattleRng.new(1), Callable())
	panel2.show_window(root)
	var fc2: Control = panel2.container.get_node("ExcavateTeamContent/Frame/FrameContainer") as Control
	assert_true((fc2.get_node("%BattleBtn") as Control).visible, "monster：battle 可见（源 :175）")
	assert_false((fc2.get_node("CgButtonContainer") as Control).visible, "monster：cg 容器隐藏（源 :174 容器级切换）")
	assert_false((fc2.get_node("%ExplainContainer") as Control).visible, "monster：explain 隐藏（源 :527）")
	assert_eq((fc2.get_node("NameBg/%NameLabel") as Label).text, cm.get_lstr("EXCAVATEWILDENEMY.WITHERED_MINERS"),
		"monster：野怪名 LSTR fill（源 :325 row[Player Name]）")
	var frame2: Control = panel2.container.get_node("ExcavateTeamContent/Frame") as Control
	assert_almost_eq(frame2.size.y, 206.87, 0.02, "monster：frame 高 265px÷1.28=206.87（源 :531 DGSizeMake）")
	assert_almost_eq(frame2.get_rect().get_center().y, 340.47, 0.02, "monster：frame 保持中心（Cocos setContentSize 中心锚不动）")
	assert_almost_eq(fc2.position.y, -57.03 + 27.34, 0.02, "monster：frame_container 下移 35px÷1.28=27.34（源 :530）")
	assert_gt((fc2.get_node("HeroSlot1") as Control).get_child_count(), 0, "monster：槽1 已填敌英雄")
	panel2.remove_window()
	root.queue_free()


# 换队交互（源 :113-122 change_team_button → enterExcavateChange；单机化 = 当前阵容
# 一键驻防 set_defend_team + 刷新）：驻防后槽重填且空态提示消隐。
func test_team_change_team_refresh() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.excavate.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0,
		"_wild_id": 30001, "_team": [],
	})
	var panel := ExcavateTeamPanel.new("excavate_team", {})
	panel.setup_panel(pd, 1, BattleRng.new(1), Callable())
	panel.show_window(root)
	var fc: Control = panel.container.get_node("ExcavateTeamContent/Frame/FrameContainer") as Control
	assert_true((fc.get_node("%EmptyHint") as Control).visible, "空队：空态提示可见（单机兜底，源空队直接进换队 :405-408）")
	assert_eq((fc.get_node("HeroSlot1") as Control).get_child_count(), 0, "空队：槽1 空")
	panel._on_change_team()
	assert_false((fc.get_node("%EmptyHint") as Control).visible, "换队后空态提示隐藏")
	assert_gt((fc.get_node("HeroSlot1") as Control).get_child_count(), 0, "换队后槽1 已填（当前阵容驻防）")
	panel.remove_window()
	root.queue_free()


# team 面板 monster 矿点装配无 crash（回归底线用例，保留自迁移期）
func test_team_panel_monster_builds() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	# 直接注入 monster 矿点（避 search 随机）
	pd.excavate.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 30001, "_team": [],
	})
	var panel := ExcavateTeamPanel.new("excavate_team", {})
	panel.setup_panel(pd, 1, BattleRng.new(1), Callable())
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "monster team container 非空")
	panel.remove_window()
	root.queue_free()
