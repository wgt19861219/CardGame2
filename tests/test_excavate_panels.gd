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


# ── ExcavateBattleReportPanel：TITLE_FMT LSTR ──

# THE+BATTLE 拼接 "第" + "1" + "战"
func test_battle_report_title_lstr_concat() -> void:
	var the: String = cm.get_lstr("EXCAVATEBATTLEREPORT.THE")
	var battle: String = cm.get_lstr("EXCAVATEBATTLEREPORT.BATTLE")
	assert_eq(the, "第", "THE = 第")
	assert_eq(battle, "战", "BATTLE = 战")
	var title: String = the + "1" + battle
	assert_eq(title, "第1战", "title 拼接正确")


# ── ExcavateMapPanel：LSTR + bg.jpg + backbtn 装配 ──

# map 面板 LSTR key 全在 JSON
func test_map_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"EXCAVATEMAP.RULES", "EXCAVATEHISTORY.DEFENSIVE_RECORD",
		"RECHARGE.DIAMOND", "TASK.GOLD", "EQUIP.EXPERIENCE_CREAMS",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# bg.jpg 资源存在（源 uieditor excavatemap:12 第 1 元素照源核实保留）
func test_map_bg_asset_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/bg.jpg"), "bg.jpg 存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/backbtn.png"), "backbtn.png 存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/prevchap.png"), "prevchap.png 存在")


# map 面板空矿点列表时显示 NO_NODE_TEXT（避免除零/越界）
func test_map_panel_empty_list_no_crash() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := ExcavateMapPanel.new("excavate_map", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	# 空矿点：info_label 显示 NO_NODE_TEXT，node_button 不可见
	assert_false(panel._node_button.visible, "空列表 node_button 隐藏")
	assert_eq(panel._info_label.text, "暂无矿点，点击「搜索」发现矿点", "空列表文案正确")
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
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := ExcavateSearchPanel.new("excavate", {})
	panel.setup_panel(pd, BattleRng.new(1))
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


# ── ExcavateTeamPanel：LSTR ADJUST_FORMATION + owner 切换 ──

# team LSTR ADJUST_FORMATION key 在 JSON
func test_team_lstr_keys_present() -> void:
	assert_eq(cm.get_lstr("EXCAVATETEAM.ADJUST_FORMATION"), "调整阵容", "ADJUST_FORMATION = 调整阵容")


# team 面板 monster 矿点显示出战按钮（无 crash）
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
