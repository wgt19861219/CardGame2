extends GutTest
# 排行榜 NPC 假榜测试（照源 local_server.lua:2227-2332 query_ranklist）。
# selfParam 5 档聚合（源 :2234-2272）：top_gs/full_hero_gs/hero_team_gs/hero_evo_star/hero_arousal/default。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_generate_ranklist_20_entries() -> void:
	var rm := RanklistManager.new()
	var pd := PlayerData.new(cm)
	var r: Dictionary = rm.generate_ranklist(pd, "top_gs")
	var items: Array = r["items"]
	assert_eq(items.size(), 20, "20 NPC 假榜")
	for i in items.size():
		var item: Dictionary = items[i]
		assert_true(String(item["name"]) != "", "NPC 名非空")
		assert_gte(int(item["param"]), 10, "param 下限 10（源 :2281）")


func test_self_param_uses_hero_gs() -> void:
	# 源 :2234-2257 selfParam 基于英雄 gs（top15Gs），非旧简化 team_level×100
	var rm := RanklistManager.new()
	var pd := PlayerData.new(cm)
	pd.team_level = 99  # 故意高，验证 self_param 不再依赖 team_level
	var no_hero: int = int(rm.generate_ranklist(pd, "top_gs")["self_param"])
	assert_eq(no_hero, 0, "无英雄 self_param=0（top15Gs）")
	pd.hero_manager.add_hero(1)
	var with_hero: int = int(rm.generate_ranklist(pd, "top_gs")["self_param"])
	assert_gte(with_hero, no_hero, "加英雄后 self_param >= 加前（top15Gs 含英雄 gs）")


func test_rank_type_5_buckets() -> void:
	# 源 :2259-2272 5 档 rank_type 聚合不同维度（旧版 5 榜同分，修后应区分）
	var rm := RanklistManager.new()
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)  # HeroInstance: gs=calc_gs, stars=1, rank=1
	var top_gs: int = int(rm.generate_ranklist(pd, "top_gs")["self_param"])         # top15Gs
	var full_gs: int = int(rm.generate_ranklist(pd, "full_hero_gs")["self_param"])  # totalGs
	var evo_star: int = int(rm.generate_ranklist(pd, "hero_evo_star")["self_param"])  # Σstars
	var arousal: int = int(rm.generate_ranklist(pd, "hero_arousal")["self_param"])   # Σrank
	# 1 英雄：top15Gs == totalGs == top5Gs（都=该英雄 gs）
	assert_eq(top_gs, full_gs, "1 英雄 top_gs(top15)==full_hero_gs(totalGs)")
	assert_eq(evo_star, 1, "hero_evo_star = Σstars = 1（HeroInstance.stars 默认 1）")
	assert_eq(arousal, 1, "hero_arousal = Σrank = 1（HeroInstance.rank 默认 1）")


# 源 :2284-2292 guildliveness 公会活跃榜（假榜硬编码 guildNames，_guild_summary 结构 + param=max(3000-i*120,100)）。
# guildNames :2230 非联机数据（同 AI_NAMES 假名），不属公会裁剪范畴，照源补 Logic 分支。
func test_guildliveness_branch() -> void:
	var rm := RanklistManager.new()
	var pd := PlayerData.new(cm)
	var r: Dictionary = rm.generate_ranklist(pd, "guildliveness")
	var items: Array = r["items"]
	assert_eq(items.size(), 20, "公会活跃榜 20 条")
	# 源 :2288 _name=guildNames[ni]（非 user 榜的 npcNames）
	assert_eq(String(items[0]["name"]), "暗影军团", "第 1 名=暗影军团（GUILD_NAMES[0]，源 :2230）")
	# 源 :2291 param=max(3000-i*120,100)：第 1 名 2880 / 第 20 名 600
	assert_eq(int(items[0]["param"]), 2880, "第 1 名 param=3000-1×120=2880（源 :2291）")
	assert_eq(int(items[19]["param"]), 600, "第 20 名 param=3000-20×120=600（源 :2291）")
	# 源 _guild_summary 无 _level（user 榜 _user_summary 才有 _level）
	assert_eq(int(items[0]["level"]), 0, "公会榜无 level（源 _guild_summary 结构）")


# P0-7：源 ranklist.lua:1318-1571 createMyselfRankSummary。self_rank<=2 不建浮窗（前 2 已列表显）。
func test_overlay_skipped_when_rank_le_2() -> void:
	var parent := Control.new()
	add_child(parent)
	var page1: Control = RanklistMyselfOverlay.build(parent, 1, "P", 10, "")
	var page2: Control = RanklistMyselfOverlay.build(parent, 2, "P", 10, "")
	assert_null(page1, "self_rank=1 不建浮窗（前 2 已列表显）")
	assert_null(page2, "self_rank=2 不建浮窗")
	parent.queue_free()


# P0-7：self_rank>2 建浮窗（pageContainer > board ranklist_my_bg + 排名 + up 箭头 + delta + name）。
func test_overlay_built_when_rank_gt_2() -> void:
	var parent := Control.new()
	add_child(parent)
	var page: Control = RanklistMyselfOverlay.build(parent, 5, "测试玩家", 30, "")
	assert_not_null(page, "self_rank=5 建浮窗 pageContainer")
	assert_eq(page.name, "PageContainer", "pageContainer 节点名")
	assert_eq(page.get_child_count(), 1, "page > board（ranklist_my_bg）")
	var board: TextureRect = page.get_child(0) as TextureRect
	assert_not_null(board, "board 是 ranklist_my_bg TextureRect")
	# board 含 rank 数字 + arrow + hint + delta + name（5 个子）
	assert_gte(board.get_child_count(), 4, "board 含 rank/arrow/hint/delta/name 多子")
	# delta>0（rank=5，prev=0 单机）→ 应有 pvp_up 箭头（资源存在）
	var has_arrow: bool = false
	for c in board.get_children():
		if c is TextureRect and c.texture != null and String(c.texture.resource_path).find("pvp_up") >= 0:
			has_arrow = true
			break
	assert_true(has_arrow, "delta>0 → pvp_up 升箭头")
	parent.queue_free()


# P0-7：>3 排名用数字 Label（#N），1/2/3 用徽章图（资源存在时）。
func test_overlay_rank_3_uses_badge_or_number() -> void:
	var parent := Control.new()
	add_child(parent)
	var page: Control = RanklistMyselfOverlay.build(parent, 3, "P", 10, "")
	assert_not_null(page, "self_rank=3 建浮窗")
	var board: TextureRect = page.get_child(0) as TextureRect
	# 3rd 徽章资源存在 → TextureRect（pvp_rank_3rd_star）；否则数字 Label
	var has_badge: bool = false
	for c in board.get_children():
		if c is TextureRect and c.texture != null and String(c.texture.resource_path).find("pvp_rank_3rd") >= 0:
			has_badge = true
			break
	assert_true(has_badge, "self_rank=3 → 3rd 徽章图（资源存在）")
	parent.queue_free()


# ==================== 批4 Task 8 两件套守卫（2026-08-18）====================
# 源 uieditor/ranklistwindow.lua 声明表坐标 = 最终点值直译（star_shop 先例）。
# 声明表坐标即 Cocos 800×480 y-up 点空间 → to_godot(x,y)=(x+80, 560-y)。

const CONTENT_PATH: String = "res://scenes/ui/ranklist_content.tscn"
const THEME_PATH: String = "res://resources/themes/default_theme.tres"


func _instantiate_content() -> Control:
	var content: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child(content)
	return content


# 声明表元素 4 window：ranklist_bg.png scaleSize(722,400.25) @中心(400,216)
# → Godot 中心 (480,344) → rect (119,143.875,841,544.125) 取整 (119,144,841,544)。
# 声明表元素 1 bg：bg.jpg fix_wh(800,481.25) 铺满语义 → FrameworkBg 全屏（crusade 先例）。
func test_content_window_layout_from_uieditor() -> void:
	var content := _instantiate_content()
	var bg: TextureRect = content.get_node("FrameworkBg") as TextureRect
	assert_not_null(bg, "FrameworkBg 全屏底（声明表 bg.jpg，铺满语义）")
	assert_eq(bg.size, Vector2(960.0, 640.0), "bg 铺满全屏（crusade 先例口径）")
	var window: TextureRect = content.get_node("Window") as TextureRect
	assert_not_null(window, "Window 节点（声明表 window 元素）")
	assert_eq(window.size, Vector2(722.0, 400.0), "window 722×400（声明表 scaleSize 直译取整）")
	assert_eq(window.position, Vector2(119.0, 144.0), "window 左上 (119,144)（中心 (480,344)）")
	content.queue_free()


# 声明表元素 2 back_button：fix_wh(57.8125,58.59375) @中心(63.28,439.06)
# → Godot 中心 (143.28,120.94) → rect (114.375,91.64,172.19,150.23) 取整 (114,92,172,150)。
# 旧实现 74×75 为像素值未 ÷CS（backbtn.png 74×75px ÷1.28125 = 57.8×58.6 点）。
func test_content_closebtn_size_from_uieditor() -> void:
	var content := _instantiate_content()
	var btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	assert_not_null(btn, "CloseBtn 存在")
	assert_almost_eq(btn.size.x, 57.81, 0.01, "close 宽（贴角惯例，offset 差值浮点容差）")
	assert_almost_eq(btn.size.y, 58.59, 0.01, "close 高")
	assert_eq(btn.position, Vector2(20.0, 15.0), "close 左上贴角 (20,15)（2026-08-18 导航惯例归位，excavate 判例）")
	assert_eq(btn.stretch_mode, TextureButton.STRETCH_SCALE, "TextureButton 显式 stretch_mode=0（批惯例）")
	content.queue_free()


# create :1949-1952 重建 title_bg：createSprite ranklist_title_bg @DGccp(511,563)=(399.22,439.84)
# → Godot 中心 (479.22,120.16)；尺寸 = 纹理 546×75px ÷CS = 425.85×58.54。
# initTitle :1782-1797 "排行榜" 24 号 ccc3(255,214,17) @DGccp(512,567) → 中心 (480,117.03)。
func test_content_title_and_titlebg_layout() -> void:
	var content := _instantiate_content()
	var title_bg: TextureRect = content.get_node("TitleBg") as TextureRect
	assert_not_null(title_bg, "TitleBg（create :1949 重建版；声明表 title_bg visible=false 弃用）")
	assert_eq(title_bg.size, Vector2(426.0, 58.0), "title_bg 426×58（纹理 546×75 ÷CS）")
	assert_eq(title_bg.position, Vector2(266.0, 91.0), "title_bg 左上 (266,91)（中心 (479.22,120.16)）")
	var title: Label = content.get_node("%Title") as Label
	assert_not_null(title, "Title Label")
	assert_eq(title.text, "排行榜", "标题文本（RANKLIST.RANKLISTTITLE）")
	assert_almost_eq(title.position.y, 105.0, 0.5, "title 顶 ~105（中心 y=117.03）")
	assert_eq(String(title.theme_type_variation), "RanklistTitleLabel", "title 走 RanklistTitleLabel variation")
	content.queue_free()


# 源 createRankSelListLayer :2177-2191 draglist cliprect CCRectMake(50,26,210,380)（场景点坐标）
# → Godot (130,154)-(340,534)。源 initListLayer :1697 scrollview cliprect CCRectMake(249,26,512,380)
# → Godot (329,154)-(841,534)（旧实现 420×360 偏小）。
func test_content_clip_layers_source_rects() -> void:
	var content := _instantiate_content()
	var tab_clip: Control = content.get_node("TabClip") as Control
	assert_not_null(tab_clip, "TabClip 裁剪层（源 draglist cliprect）")
	assert_true(tab_clip.clip_contents, "TabClip clip_contents=true（源 cliprect 裁剪）")
	assert_eq(tab_clip.position, Vector2(130.0, 154.0), "TabClip 左上 (130,154)")
	assert_eq(tab_clip.size, Vector2(210.0, 380.0), "TabClip 210×380（源 cliprect 尺寸直译）")
	var scroll: ScrollContainer = content.get_node("%ScrollLayer") as ScrollContainer
	assert_not_null(scroll, "ScrollLayer 存在")
	assert_eq(scroll.position, Vector2(329.0, 154.0), "ScrollLayer 左上 (329,154)")
	assert_eq(scroll.size, Vector2(512.0, 380.0), "ScrollLayer 512×380（源 scrollview cliprect 直译）")
	content.queue_free()


# 源声明表 left_arrow/right_arrow pos y=21700 屏外（编辑器残留）+ initArrow→refreshArrow :1860-1864
# setVisible(false) 双重死元素 → 受控裁剪不进 tscn。tscn theme_override 样式清零（两件套 SOP）。
func test_content_no_arrows_and_no_theme_override() -> void:
	var content := _instantiate_content()
	assert_false(content.has_node("LeftArrow"), "LeftArrow 不存在（源 :21700 屏外+refreshArrow 隐藏，受控裁剪）")
	assert_false(content.has_node("RightArrow"), "RightArrow 不存在（同上）")
	content.queue_free()
	var tscn_text: String = FileAccess.get_file_as_string(CONTENT_PATH)
	assert_eq(tscn_text.count("theme_override_colors"), 0, "tscn 无 font_color override（走 variation）")
	assert_eq(tscn_text.count("theme_override_font_sizes"), 0, "tscn 无 font_size override（走 variation）")


# tab 树静态常驻（源 ranklisttree 2 组 4 子 + createRankBtn :2005-2175 按钮贴图/Label 18 号）。
# 折叠 = 子按钮 visible 切换 + 重排（fill），不再 procedural 重建（SOP visible 切换条款）。
func test_tab_buttons_static_six() -> void:
	var content := _instantiate_content()
	var host: Control = content.get_node("%TabHost") as Control
	assert_not_null(host, "TabHost 存在")
	var btns: Array = []
	for c in host.get_children():
		if c is TextureButton:
			btns.append(c)
	assert_eq(btns.size(), 6, "6 静态 tab 按钮（2 组 + 4 子，单机化 2 分组 4 子项）")
	var group_arena: TextureButton = content.get_node("%GroupArena") as TextureButton
	assert_eq(group_arena.size, Vector2(135.0, 59.0), "组按钮 135×59（源 DGSizeMake(173,75)=(135.16,58.59)）")
	var sub_pvp: TextureButton = content.get_node("%SubPvp") as TextureButton
	var lbl: Label = sub_pvp.get_child(0) as Label
	assert_eq(lbl.text, "竞技场每日排名", "子 tab 文本 LSTR ARENADAY（源 rankconfig[1]）")
	assert_eq(String(lbl.theme_type_variation), "RanklistSubTabSelLabel", "选中子 tab 走 variation")
	# 默认组 2 折叠：子 3 个 visible=false
	var sub_gs: TextureButton = content.get_node("%SubFullHeroGs") as TextureButton
	assert_false(sub_gs.visible, "默认战力组折叠（源 ranklisttree[2].collapsed=true）")
	content.queue_free()


# variation 注册守卫（GUT 下 get_theme_font_size 不解析 variation → 读 tres 文本，批内惯例）。
func test_theme_registers_ranklist_variations() -> void:
	var theme_text: String = FileAccess.get_file_as_string(THEME_PATH)
	for v: String in [
		"RanklistTitleLabel", "RanklistGroupTabSelLabel", "RanklistGroupTabLabel",
		"RanklistSubTabSelLabel", "RanklistSubTabLabel", "RanklistRowRecordLabel",
		"RanklistSummaryTitleLabel", "RanklistSummaryValueLabel",
		"RanklistOverlayHintLabel", "RanklistOverlayDeltaLabel", "RanklistWhiteLabel18",
	]:
		assert_true(theme_text.find("%s/base_type" % v) != -1, "theme 注册 %s" % v)


# panel fill 化：行板 Scale9 化（源 initCommonItemHandler :780-793 board capInsets DG(65,25,545,25)
# ×贴图 638×97px → patch L=65 T=97-25-25=47 R=638-65-545=28 B=25；scaleSize DG(650,95)=(507.81,74.22)）。
func test_panel_rows_after_setup() -> void:
	var rm := RanklistManager.new()
	var pd := PlayerData.new(cm)
	var panel := RanklistPanel.new("ranklist", {})
	panel.setup_panel(pd, rm, "pvp")
	add_child(panel)
	var rows: VBoxContainer = panel.container.get_node("RanklistContent/%ScrollLayer/%Rows") as VBoxContainer
	assert_not_null(rows, "Rows 行容器（%ScrollLayer/%Rows）")
	assert_eq(rows.get_child_count(), 21, "21 行（1 self + 20 NPC 假榜）")
	var first_row: Control = rows.get_child(0) as Control
	var board: NinePatchRect = first_row.get_child(0) as NinePatchRect
	assert_not_null(board, "行板 NinePatchRect（源 Scale9Sprite board）")
	assert_eq(board.patch_margin_left, 65, "patch left=65（源 cap x=65 DG 裸值直译，非 ×CS：65×CS=83.28≠65）")
	assert_eq(board.patch_margin_top, 47, "patch top=47（H-y-h=97-25-25）")
	assert_eq(board.patch_margin_right, 28, "patch right=28（W-x-w=638-65-545）")
	assert_eq(board.patch_margin_bottom, 25, "patch bottom=25（源 cap y=25 DG 裸值直译，非 ×CS）")
	assert_almost_eq(board.size.x, 507.81, 0.5, "行板宽 507.81（源 DGSizeMake(650,95)）")
	assert_almost_eq(board.size.y, 74.22, 0.5, "行板高 74.22")
	assert_almost_eq(first_row.custom_minimum_size.y, 74.22, 0.5, "行高 74.22（源 itemSize dy 105DG-板 95DG 余量内）")
	panel.queue_free()


# gd 运行时 theme override 清零守卫（panel + overlay 两文件，brief：gd add_theme 11 全清）。
func test_panel_no_runtime_theme_override() -> void:
	for path: String in [
		"res://scripts/ui/ranklist_panel.gd",
		"res://scripts/ui/ranklist_myself_overlay.gd",
	]:
		var script_text: String = FileAccess.get_file_as_string(path)
		assert_eq(script_text.count("add_theme_color_override"), 0, "%s 无 font_color override" % path)
		assert_eq(script_text.count("add_theme_font_size_override"), 0, "%s 无 font_size override" % path)


# ==================== 审查更正守卫（2026-08-18 Important×2）====================
# 源 reCalculateRankBtnPos :1898-1925 精确直译：height=380+5 起步、循环内先 -5 再用（组1 pos=380，
# 非 385）；展开组尾 -5 + 下组开头 -5 = 组间 gap 10；折叠组子按钮只藏不占位（:1915-1918）。
# 断言值 = 源 height 反推 TabHost 局部：x_组=2.42/x_子=10.42；y_组=376.705-h/y_子=381.705-pc。
func _make_panel_for_layout() -> RanklistPanel:
	var rm := RanklistManager.new()
	var pd := PlayerData.new(cm)
	var panel := RanklistPanel.new("ranklist", {})
	panel.setup_panel(pd, rm, "pvp")
	add_child(panel)
	return panel


func test_layout_tabs_group1_pos_from_source() -> void:
	var panel := _make_panel_for_layout()
	var host: Control = panel.container.get_node("RanklistContent/TabClip/TabHost")
	var group1: TextureButton = host.get_node("GroupArena") as TextureButton
	assert_almost_eq(group1.position.x, 2.42, 0.05, "组1 x=场景 120 → TabHost 局部 2.42")
	assert_almost_eq(group1.position.y, -3.295, 0.05, "组1 pos=源 380（:1903 循环内先 -5 再用，非 385）")
	var sub_pvp: TextureButton = host.get_node("SubPvp") as TextureButton
	assert_almost_eq(sub_pvp.position.y, 48.705, 0.05, "组1 子 pc=源 333（380-47）")
	var group2: TextureButton = host.get_node("GroupFightvalue") as TextureButton
	assert_almost_eq(group2.position.y, 100.705, 0.05, "组2 pos=源 276（展开尾 5+下组开头 5，gap=10 非 5）")
	panel.queue_free()


# 折叠组不占位（源 :1915-1918 折叠分支不减 height）：组1 折叠 → 组2 顶到源 328。
func test_layout_tabs_collapsed_group_takes_no_space() -> void:
	var panel := _make_panel_for_layout()
	panel._collapsed = {0: true, 1: false}
	panel._layout_tabs()
	var host: Control = panel.container.get_node("RanklistContent/TabClip/TabHost")
	var sub_pvp: TextureButton = host.get_node("SubPvp") as TextureButton
	assert_false(sub_pvp.visible, "组1 折叠 → 子按钮隐藏")
	var group2: TextureButton = host.get_node("GroupFightvalue") as TextureButton
	assert_almost_eq(group2.position.y, 48.705, 0.05, "组1 折叠不占位 → 组2 pos=源 328（380-47 后直接 -5+5）")
	var sub_gs: TextureButton = host.get_node("SubFullHeroGs") as TextureButton
	assert_true(sub_gs.visible, "组2 展开 → 子按钮可见")
	assert_almost_eq(sub_gs.position.y, 100.705, 0.05, "组2 展开子1 pc=源 281（328-47）")
	panel.queue_free()
