extends GutTest
# StageDetailPanel 关卡详情面板测试（P1-2026-07-10：照源 stagedetail 翻译）。
# 重构（2026-07-17）：.tscn instantiate + fill 范式（同 hero_detail），测试递归扫 container→content→%...。
# 两件套（2026-08-16 批3 Task 6）：builder（stage_detail_builder.gd）退役，fill/动态内容并入 panel；
# 本文件合并原 test_stage_detail_builder.gd 全部用例语义（12 例）+ 新增两件套守卫。
# 贴图口径（批3定稿）：显示 = 像素÷CS(1.28125)×条目CS（Prescaled=true 才施加）；
# 本面板贴图除 bg.jpg（Prescaled=true CS=2）外全无条目 → 像素÷CS；frame 系条目
# Prescaled=false/CS=0 → 不施加条目 CS，同像素÷CS（936×507 → 730.54×395.71）。

const CONTENT_PATH: String = "res://scenes/ui/stage_detail_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/stage_detail_panel.gd"
const BUILDER_PATH: String = "res://scripts/ui/stage_detail_builder.gd"
const CS: float = 1.28125

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel() -> StageDetailPanel:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(5)
	var panel := StageDetailPanel.new("stagedetail", {})
	panel.setup_panel(1, mgr, pd, rng)
	panel.show_window(root)
	return panel


func _content_of(panel: StageDetailPanel) -> Control:
	return panel.container.get_child(0) as Control


func _find_button_recursive(node: Node, text: String) -> bool:
	# SweepBtn 用独立 Label 子节点承载文字（Button.text 清空，照 hero_detail 范式），
	# 故 Button 自身 + 其 Label 子节点的 text 均扫描。
	if node is Button:
		if (node as Button).text == text:
			return true
		for c in node.get_children():
			if c is Label and (c as Label).text == text:
				return true
		return false
	for c in node.get_children():
		if _find_button_recursive(c, text):
			return true
	return false


# ── 现存用例（2026-07-10 起，语义保留）──────────────────────────────


func test_panel_assembles_with_enemy_and_award() -> void:
	var panel := _make_panel()
	# container 应含 content（.tscn root，含 base 层静态节点 + host）
	assert_eq(panel.container.get_child_count(), 1, "container 含 content（.tscn instantiate）")
	var content: Control = _content_of(panel)
	assert_not_null(content.get_node_or_null("%GoButton"), "GoButton 节点存在")
	assert_not_null(content.get_node_or_null("%EnemyHBox"), "EnemyHBox 节点存在")
	assert_not_null(content.get_node_or_null("%StarHBox"), "StarHBox 节点存在")
	assert_not_null(content.get_node_or_null("%CloseBtn"), "CloseBtn 节点存在")
	# 星已静态化进 %StarHBox（Star1/2/3 TextureRect，按源 createStars :1212-1260）
	var star_box: Node = content.get_node("%StarHBox")
	assert_eq(star_box.get_child_count(), 3, "StarHBox 含 3 颗静态星")
	panel.remove_window()


func test_panel_shows_sweep_for_3_star_stage() -> void:
	# 3 星通关的关卡应显示扫荡按钮（照源 createRepeatBattle 3 星条件）
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	# 手动设 3 星解锁扫荡按钮（progress 字典 key=sid value=星数）
	mgr.progress[1] = 3
	var rng := BattleRng.new(5)
	var panel := StageDetailPanel.new("stagedetail", {})
	panel.setup_panel(1, mgr, pd, rng)
	panel.show_window(root)
	# 递归扫 container 子树找扫荡按钮（%SweepCluster，3 星时 visible=true + Label text="扫荡"）
	var has_sweep: bool = _find_button_recursive(panel.container, "扫荡")
	assert_true(has_sweep, "3 星关卡显示扫荡按钮")
	panel.remove_window()


# ── builder 用例迁移（原 test_stage_detail_builder.gd 12 例语义全保）──


func test_to_godot_conversion() -> void:
	# cocos(400,205) → Godot(480,355)（offset 80 + y 翻转 560-cy）
	assert_eq(StageDetailPanel.to_godot(400.0, 205.0), Vector2(400.0, 275.0))
	assert_eq(StageDetailPanel.to_godot(0.0, 0.0), Vector2(0.0, 480.0))
	assert_eq(StageDetailPanel.to_godot(800.0, 480.0), Vector2(800.0, 0.0))


func test_get_res_info_normal() -> void:
	var ri: Dictionary = StageDetailPanel.get_res_info("normal")
	assert_eq(String(ri["frame"]), "res://assets/ui/alpha/HVGA/stage-map-frame.png")
	assert_eq(String(ri["title_bg"]), "res://assets/ui/alpha/HVGA/Normal_title_bg.png")
	assert_eq(int(ri["star_gap"]), 55)
	assert_eq(Vector2(ri["go_btn_pos"]), Vector2(698.0, 80.0))
	assert_eq(Vector2(ri["frame_pos"]), Vector2(400.0, 205.0))


func test_get_res_info_elite() -> void:
	var ri: Dictionary = StageDetailPanel.get_res_info("elite")
	assert_eq(String(ri["frame"]), "res://assets/ui/alpha/HVGA/stage-map-elite-frame.png")
	assert_eq(String(ri["title_bg"]), "res://assets/ui/alpha/HVGA/Elite_title_bg.png")
	assert_eq(int(ri["star_gap"]), 50)
	assert_eq(Vector2(ri["frame_pos"]), Vector2(400.0, 207.0))


func test_get_res_info_raid() -> void:
	var ri: Dictionary = StageDetailPanel.get_res_info("raid")
	assert_eq(String(ri["frame"]), "res://assets/ui/alpha/HVGA/stage_map_guild_frame.png")


func test_get_res_info_dungeon() -> void:
	var ri: Dictionary = StageDetailPanel.get_res_info("dungeon")
	assert_eq(String(ri["frame"]), "res://assets/ui/alpha/HVGA/stage-map-elite-frame.png")


# 照源 LSTR 化（源 :1686 PHYSICAL_EXERTION / :1834 ENEMY_LINEUP / :1848 MAY_BE_OBTAINED / :1807 PURCHASE）。
func test_fill_content_uses_lstr_for_section_labels() -> void:
	var panel := _make_panel()
	var content: Control = _content_of(panel)
	assert_eq((content.get_node("%PowerTitle") as Label).text, "体力消耗", "power_title LSTR STAGEDETAIL.PHYSICAL_EXERTION")
	assert_eq((content.get_node("%EnemyTitle") as Label).text, "敌方阵容", "enemy_title LSTR STAGEDETAIL.ENEMY_LINEUP")
	assert_eq((content.get_node("%AwardTitle") as Label).text, "可能获得", "award_title LSTR STAGEDETAIL.MAY_BE_OBTAINED")
	assert_eq((content.get_node("%ResetLabel") as Label).text, "购买", "reset_label LSTR EQUIPINFO.PURCHASE")
	panel.remove_window()


# 源 :1730 T(LSTR("EXERCISE.REMAINING_TIMES_FOR_TODAY_"), count) — key="今日剩余次数:" + 数字拼接。
# Stage 1 Daily Limit=0 → left=0-0=0 → "今日剩余次数:0"（normal 型 count 三件 visible=false，text 仍 fill）。
func test_fill_content_count_title_lstr_concat_left() -> void:
	var panel := _make_panel()
	var content: Control = _content_of(panel)
	var count_title: Label = content.get_node("%CountTitle") as Label
	assert_eq(count_title.text, "今日剩余次数:0", "count_title = LSTR + left(0-0=0)")
	assert_false(count_title.visible, "normal 型 count_title 隐藏（源 :1906-1910）")
	assert_false((content.get_node("%TotalNumber") as Label).visible, "normal 型 total_number 隐藏")
	panel.remove_window()


func test_fill_content_fills_detail_text() -> void:
	var panel := _make_panel()
	var content: Control = _content_of(panel)
	var detail: Label = content.get_node("%Detail") as Label
	# Stage 1 description 经 get_lstr 本地化后非空 → visible（源 :1663 visible = isKeyStage or detail ~= nil）
	assert_true(detail.visible, "detail 非空 → visible")
	assert_ne(detail.text, "", "detail 文本已 fill")
	panel.remove_window()


func test_go_and_reset_are_texturebutton_and_shade_hidden() -> void:
	var panel := _make_panel()
	var content: Control = _content_of(panel)
	assert_true(content.get_node("%GoButton") is TextureButton, "go_button 应为 TextureButton")
	assert_true(content.get_node("%Reset") is TextureButton, "reset 应为 TextureButton")
	# 新档 vitality 满(≥6) + Daily Limit=0(limit<=0 视为不限) → enabled → shade 隐藏（源 :1881/:825-832）
	var gs: TextureRect = content.get_node("%GoButtonShade") as TextureRect
	assert_false(gs.visible, "go_button_shade 默认隐藏")
	panel.remove_window()


# apply_stars：星星静态化进 .tscn（%StarHBox 下 Star1/2/3），按 star_count 切换 texture。
func test_apply_stars_switches_textures_by_count() -> void:
	var panel := _make_panel()
	var star_box: Node = _content_of(panel).get_node("%StarHBox")
	panel.apply_stars(star_box, 2)
	assert_eq(star_box.get_child_count(), 3, "应含 3 个静态星 TextureRect")
	var s0: TextureRect = star_box.get_child(0) as TextureRect
	var s2: TextureRect = star_box.get_child(2) as TextureRect
	assert_ne(s0.texture, null, "亮星应加载 detail_star 纹理")
	assert_ne(s2.texture, null, "暗星应加载 detail_star_grey 纹理")
	assert_ne(s2.texture.resource_path, s0.texture.resource_path, "第3颗(i=2>=2)应为暗星纹理")
	panel.remove_window()


# create_enemy：容器化（ReadheroIcon 套 Control wrapper 进 HBox，范式同 excavate_team）。
func test_create_enemy_wraps_in_control_into_hbox() -> void:
	var panel := _make_panel()
	var hbox := HBoxContainer.new()
	add_child(hbox)
	var enemies := [{"tid": 1, "level": 1}, {"tid": 2, "level": 1, "is_boss": true}]
	panel.create_enemy(hbox, enemies, cm)
	assert_eq(hbox.get_child_count(), 2, "2 个敌人各套一个 Control wrapper")
	var wrapper: Control = hbox.get_child(0) as Control
	assert_gt(wrapper.custom_minimum_size.x, 0.0, "wrapper 应有 custom_minimum_size 供 HBox 排版")
	panel.remove_window()
	hbox.queue_free()


# create_reward（Task 9 修复后）：HBox 一帧后重置直接子项 scale（实测 0.7→1.0，
# frame 94×95 原像素渲染底 557 压 Frame2 底 553）→ wrapper 承载 HBox 排布（72 槽
# +8 sep=80 步进照源），内层 icon 在 wrapper 内保 scale=1/CS（源 createIcon 无
# length → frame 原样 px/CS=73.37×74.14）且底对齐 wrapper 底（源 anchor(0.5,0)）。
func test_create_reward_adds_control_to_hbox() -> void:
	var panel := _make_panel()
	var hbox := HBoxContainer.new()
	add_child(hbox)
	panel.create_reward(hbox, [{"item_id": 1001}, {"item_id": 1002}], cm)
	assert_eq(hbox.get_child_count(), 2, "2 个奖励 wrapper 直接进 HBox")
	var wrapper: Control = hbox.get_child(0) as Control
	assert_almost_eq(wrapper.custom_minimum_size.x, 72.0, 0.01, "wrapper 72 槽（HBox 步进 72+8=80 照源 ox 步进 80）")
	var icon: Control = wrapper.get_child(0) as Control
	assert_almost_eq(icon.scale.x, 1.0 / CS, 0.001, "icon scale=1/CS 保住（wrapper 非 Container 不重置；修复前直接挂 HBox 被重置 1.0）")
	# icon 底对齐 wrapper 底：position.y = 72 - 95/CS（frame 视觉高 74.14，底=wrapper 底）。
	assert_almost_eq(icon.position.y, 72.0 - 95.0 / CS, 0.01, "icon 底对齐 wrapper 底（源 anchor(0.5,0) 底锚）")
	var visual_bottom: float = wrapper.position.y + icon.position.y + 95.0 * icon.scale.y
	assert_almost_eq(visual_bottom, 72.0, 0.01, "frame 视觉底 = wrapper 底（不再压 Frame2 底框 553）")
	panel.remove_window()
	hbox.queue_free()


# ── 两件套守卫（2026-08-16 批3 Task 6 新增）────────────────────────


func test_builder_retired_and_new_whitelist() -> void:
	assert_false(ResourceLoader.exists(BUILDER_PATH), "stage_detail_builder.gd 已退役删除")
	assert_false(FileAccess.file_exists(BUILDER_PATH), "builder 文件不存在")
	var panel_src: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_false(panel_src.contains("stage_detail_builder"), "panel 无 builder 引用（代码级守卫，注释头不计）")
	# .new( 白名单（宽口径含带参构造）：panel 并入 builder 后恰 7 处——
	# BattlePreparePanel/StageResetConfirm 弹窗 2 + ReadheroIcon/Control wrapper×2
	# （敌方头像 + Task 9 奖励 wrapper）/Sprite2D tag/Label fallback。
	var panel_new: PackedStringArray = _collect_new_calls(panel_src)
	assert_eq(panel_new.size(), 7, "panel .new( 恰 7 处（2 弹窗 + 5 动态图标件）")
	var joined: String = "\n".join(panel_new)
	assert_true(joined.contains("BattlePreparePanel.new("), "出战弹窗在白名单")
	assert_true(joined.contains("StageResetConfirm.new("), "重置确认弹窗在白名单")
	assert_true(joined.contains("ReadheroIcon.new()"), "敌方头像图标在白名单")
	assert_true(joined.count("Control.new()") >= 2, "敌方/奖励 HBox wrapper 在白名单")
	assert_true(joined.contains("Sprite2D.new()"), "boss 标签贴图在白名单")
	assert_true(joined.contains("Label.new()"), "boss 标签缺图 fallback 在白名单")


static func _collect_new_calls(src: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var idx: int = src.find(".new(")
	while idx != -1:
		var ls: int = src.rfind("\n", idx) + 1
		var le: int = src.find("\n", idx)
		out.append(src.substr(ls, le - ls).strip_edges())
		idx = src.find(".new(", idx + 1)
	return out


# tscn 静态 rect 源直译守卫（显示尺寸 = 像素÷CS；本面板贴图全无条目或 Prescaled=false）。
func test_content_static_rects_source_aligned() -> void:
	var content: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child(content)
	# Frame2/Frame3：detail_bg_2/stage-map-frame 936×507px ÷CS → 730.54×395.71，
	# 中心 to_godot(400,205)=(480,355)（源 framePosNormal，Task 5 同口径撤销 0.9 偏好补偿）。
	var frame2: TextureRect = content.get_node("%Frame2") as TextureRect
	var frame3: TextureRect = content.get_node("%Frame3") as TextureRect
	for fr in [frame2, frame3]:
		assert_almost_eq(fr.size.x, 936.0 / CS, 0.6, "frame 宽 = 936px÷CS 源直译")
		assert_almost_eq(fr.size.y, 507.0 / CS, 0.6, "frame 高 = 507px÷CS 源直译")
		assert_almost_eq(fr.position.x + fr.size.x * 0.5, 400.0, 0.6, "frame 中心 x=480")
		assert_almost_eq(fr.position.y + fr.size.y * 0.5, 275.0, 0.6, "frame 中心 y=355")
	# TitleBg 细条：detail_title_bg Scale9，normal 504×12 中心 to_godot(400,355)=(480,205)。
	var title_bg: TextureRect = content.get_node("%TitleBg") as TextureRect
	assert_almost_eq(title_bg.size.x, 504.0, 0.6, "TitleBg normal 基线宽 504（elite fill 改 404）")
	assert_almost_eq(title_bg.size.y, 12.0, 0.6, "TitleBg 高 12")
	assert_almost_eq(title_bg.position.y + title_bg.size.y * 0.5, 125.0, 0.6, "TitleBg 中心 y=205（源 titlepos 355）")
	# EnemyBg：detail_enemy_bg 877×103px ÷CS → 684.49×80.39，左下(90,130) anchor(0,0)
	# → godot 左上 (170, 560-130-80.39=349.61)。
	var enemy_bg: TextureRect = content.get_node("%EnemyBg") as TextureRect
	assert_almost_eq(enemy_bg.position.x, 90.0, 0.6, "EnemyBg 左 x=170")
	assert_almost_eq(enemy_bg.size.x, 877.0 / CS, 0.6, "EnemyBg 宽 = 877px÷CS（修 540 无口径错值）")
	assert_almost_eq(enemy_bg.size.y, 103.0 / CS, 0.6, "EnemyBg 高 = 103px÷CS（修 103 原始像素漏÷CS）")
	assert_almost_eq(enemy_bg.position.y + enemy_bg.size.y, 350.0, 0.6, "EnemyBg 底边 y=430（源 y=130）")
	# GoButton：startbtn 128×123px ÷CS → 99.9×96.0 等比（修 133×60 强拉变形），
	# 中心 goButtonPosNormal ccp(698,80) → godot(778,480)。
	var go_btn: TextureButton = content.get_node("%GoButton") as TextureButton
	assert_almost_eq(go_btn.size.x, 128.0 / CS, 0.6, "GoButton 宽 = 128px÷CS 等比")
	assert_almost_eq(go_btn.size.y, 123.0 / CS, 0.6, "GoButton 高 = 123px÷CS 等比")
	assert_almost_eq(go_btn.position.x + go_btn.size.x * 0.5, 698.0, 0.6, "GoButton 中心 x=778")
	assert_almost_eq(go_btn.position.y + go_btn.size.y * 0.5, 400.0, 0.6, "GoButton 中心 y=480")
	assert_eq(go_btn.stretch_mode, TextureButton.STRETCH_SCALE, "GoButton stretch_mode=0 显式")
	# CloseBtn：backbtn 74×75px ÷CS → 57.76×58.54 等比（修 50×30 强拉变形），框架位 (20,15)。
	var close_btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(close_btn.size.x, 74.0 / CS, 0.6, "CloseBtn 宽 = 74px÷CS 等比")
	assert_almost_eq(close_btn.size.y, 75.0 / CS, 0.6, "CloseBtn 高 = 75px÷CS 等比")
	assert_eq(close_btn.stretch_mode, TextureButton.STRETCH_SCALE, "CloseBtn stretch_mode=0 显式")
	# SweepCluster：main_vit_tips scaleSize 135×150 anchor(0.5,0) pos(662,131)
	# → 底中心 godot(742,429) → rect 674.5..809.5/279..429（07-30 容器化固化）。
	var cluster: Control = content.get_node("%SweepCluster") as Control
	assert_almost_eq(cluster.position.x, 594.5, 0.6, "SweepCluster 左 x=674.5")
	assert_almost_eq(cluster.position.y, 199.0, 0.6, "SweepCluster 顶 y=279")
	assert_almost_eq(cluster.size.x, 135.0, 0.6, "SweepCluster 宽 135")
	assert_almost_eq(cluster.size.y, 150.0, 0.6, "SweepCluster 高 150")
	# 星区归源（Task 9 修复）：源 createStars:1212-1261 star 左下 anchor(0,0)
	# pos(320+55*(i-1),336) scale 0.8 → 70×71px÷CS×0.8=43.71×44.33，星底=560-336=224，
	# 星1 左=400（旧 56 大星 + 顶 165 偏高 14px 致 TitleBg 细条 199..211 压星下缘）。
	var star_box: Control = content.get_node("%StarHBox") as Control
	assert_almost_eq(star_box.position.x, 320.0, 0.6, "星区左 x=400（源 star1 左 320+80）")
	assert_almost_eq(star_box.position.y + star_box.size.y, 144.0, 0.7, "星底 y=224（源 pos y=336 直译）")
	var star1: TextureRect = star_box.get_child(0) as TextureRect
	assert_almost_eq(star1.custom_minimum_size.x, 70.0 / CS * 0.8, 0.05, "星宽 =70px÷CS×0.8（源 scale 0.8）")
	assert_almost_eq(star1.custom_minimum_size.y, 71.0 / CS * 0.8, 0.05, "星高 =71px÷CS×0.8")
	assert_eq(star_box.get_theme_constant("separation"), 11, "星间距 11（步进 54.71，源 gap 55 差 0.29）")
	content.queue_free()


# variation 撞名守卫：StageTitleLabel 曾在 theme 双定义（stage_select 新版被本面板老版覆盖），
# 本面板区块标题已改名 StageSectionLabel，StageTitleLabel 应只余 stage_select 一处定义。
func test_section_label_variation_unique() -> void:
	var theme_src: String = FileAccess.get_file_as_string("res://resources/themes/default_theme.tres")
	assert_eq(theme_src.count("StageSectionLabel/base_type"), 1, "StageSectionLabel 恰 1 处定义（本面板区块标题）")
	assert_eq(theme_src.count("StageTitleLabel/base_type"), 1, "StageTitleLabel 恰 1 处定义（stage_select 章节标题）")
	var tscn_src: String = FileAccess.get_file_as_string(CONTENT_PATH)
	assert_eq(tscn_src.count("StageSectionLabel"), 4, "本面板 4 处区块标题用 StageSectionLabel")
	assert_false(tscn_src.contains("StageTitleLabel"), "本面板不再用 StageTitleLabel（让位 stage_select）")
