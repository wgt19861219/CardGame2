extends GutTest
## configure 两件套守卫测试（2026-07-18 chrome 静态化 → 批 4 Task 10 完整树化）。
## 照源 ui/popwindow/configure.lua createWindow:1062-1316 + createSWButton:719-1061 +
## createName:87-118 / createPlayerInformation:120-209 / createHeadIcon:79-85：
##   frame（:1076-1090）main_vit_tips cap(15,20,45,15)（贴图 PIL 实测 103×61 → 批 1 公式
##   top=61-20-15=26 bottom=20）scaleSize(500,250) anchor(0.5,1)@(394,455) → 终值
##   setContentSize(620,380)（:1339；height 链 260 → createSWButton 内 +60=320 → :1335
##   +60=380，公会/logoff/google/360 单机化裁剪不增量）→ 左上 Cocos(84,455) →
##   Godot (164,105)~(784,485)。
##   close（:1092-1100）(690,435) 中心，65×66px ÷CS1.28125 = 50.73×51.52。
##   头区：pattern(185,360)/bg(185,360)/frame(200,360,z=5) 中心锚 + head icon(185,363,z=3,
##   getHeadIcon length=70 等比)——z3 < z5 即 icon 在 frame 之下（框贴图中心镂空透出头像）。
##   贴图 PIL 实测均无 TextureConfig 条目 → 显示 = 像素 ÷1.28125：patterns 171×171→
##   133.46；head_bg 100×105→78.05×81.95（等比 20:21）；frame 140×104→109.27×81.17。
##   info 行（:159 anchor(0,0.5)@x=305，y=365-22*(i-1)）→ x=385，中心 y 195/217/239。
##   右列按钮 130×55：(615,385)/(615,312)/(615,222)；setup 180×55@(200,115)。
##   分隔线（createSWButton 无条件创建，公会/facebook 功能区块虽裁线体照源保留）：
##   serverselect_delimiter 455×3px（HC 老版复用）cap(170,1,10,1) → patch L170/T1/R275/B1，
##   scaleSize 600×2 中心 x=390 → (170,y-1)~(770,y+1)；society(600-320=280)/language(150)/
##   facebook(85)。
##   单机化重排（受控偏离）：language_button 源 debug_mode 隐藏（:1052-1056），单机版语言
##   切换为正式功能 → 占被裁 select_server(393,115) 中心位 (473,445)；label 中心 = 按钮
##   中心 +(88,0)（源 :964 label@250 = 按钮 162+88）。
##   Scale9 按钮样式收敛：4 按钮同图同 cap（sell_number_button 63×67 cap(15,22,15,25)）
##   与 theme SB_pkg_hb_n/p（批 2 Task 2）完全一致 → ConfigureActionBtn variation 复用，
##   panel 运行时 add_theme_stylebox_override 归零（UiScale9Button 退役守卫）。

const CONTENT_PATH: String = "res://scenes/ui/configure_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/configure_panel.gd"
const THEME_PATH: String = "res://resources/themes/default_theme.tres"
const DELIMITER_PATH: String = "res://assets/ui/alpha/HVGA/serverselect_delimiter.png"

# frame：源 setContentSize(620,380) 终值，anchor(0.5,1)@(394,455)。
const FRAME_L: float = 84.0
const FRAME_T: float = 25.0
const FRAME_R: float = 704.0
const FRAME_B: float = 405.0
const FRAME_CAP_TOP: int = 26
const FRAME_CAP_BOTTOM: int = 20
const FRAME_CAP_RIGHT: int = 43
# close：源 (690,435) 中心，65×66 ÷CS。
const CLOSE_CX: float = 690.0
const CLOSE_CY: float = 45.0
const CLOSE_W: float = 50.73
const CLOSE_H: float = 51.52
# 头区（源 pattern/bg @(185,360)、frame @(200,360)、icon @(185,363)）。
const HEAD_PATTERN_CX: float = 185.0
const HEAD_PATTERN_CY: float = 120.0
const HEAD_PATTERN_DISPLAY: float = 133.46
const HEAD_BG_W: float = 78.05
const HEAD_BG_H: float = 81.95
const HEAD_FRAME_W: float = 109.27
const HEAD_FRAME_H: float = 81.17
const HEAD_FRAME_CX: float = 200.0
# head icon 70×70（源 getHeadIcon length=70），中心 (265,197)（源 185,363）。
const HOST_L: float = 150.0
const HOST_T: float = 82.0
const HOST_R: float = 220.0
const HOST_B: float = 152.0
# info 行：x=源 305 直译（anchor(0,0.5)），中心 y=480−(365−22*(i-1))=115/137/159。
const INFO_L: float = 305.0
const INFO_CY: Array[float] = [115.0, 137.0, 159.0]
# 右列按钮 130×55（源 615,385 / 615,312 / 615,222）。
const RIGHT_BTN_L: float = 550.0
const RIGHT_BTN_R: float = 680.0
const CHANGE_NAME_T: float = 67.5
const CHANGE_HEAD_T: float = 140.5
const SAVE_MANAGER_T: float = 230.5
# setup 180×55（源 200,115 = buttonHeight-height-60）。
const SETUP_L: float = 110.0
const SETUP_T: float = 337.5
const SETUP_R: float = 290.0
const SETUP_B: float = 392.5
# lang 100×60 @ select_server 中心 (473,445)（单机化重排）；label 中心 +(88,0)。
# （Task7 清理：LANG_L/T/R/B 与 NAME_LABEL_L/R 六常量基线即零引用死常量，删。）
const LANG_LABEL_CX: float = 481.0
const LANG_LABEL_CY: float = 362.5
# 分隔线 600×2 中心 x=390 → (170,~)~(770,~)；中心 y 280/410/475（源 600-320/150/85）。
const LINE_L: float = 90.0
const LINE_R: float = 690.0
const LINE_PATCH_LEFT: int = 170
const LINE_PATCH_RIGHT: int = 275
const LINE_PATCH_TOP: int = 1
const LINE_PATCH_BOTTOM: int = 1
# name：源 name_bg fix_wh 225×30 中心 (450,150)；name label 中心同 bg，宽上限 180（:114-116）。
const NAME_BG_L: float = 257.5
const NAME_BG_T: float = 55.0
const NAME_BG_R: float = 482.5
const NAME_BG_B: float = 85.0

# 单机化裁剪（联机残留守卫）：公会/登出/google/360/换服/facebook/web 按钮 + 账号 ID 行。
const CUT_NODES: Array[String] = [
	"SocietyBtn", "LogoffBtn", "GoogleBtn", "SelectServerBtn", "SupportBtn",
	"WebBtn", "FacebookIcon", "AccountIdLine", "InfoLine4",
]


func _content() -> Control:
	var scene: PackedScene = load(CONTENT_PATH) as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)


func test_content_static_tree() -> void:
	# 完整静态树：chrome + 三条分隔线 + 按钮 label 全存在
	var inst := _content()
	var names: Array[String] = [
		"Frame", "CloseBtn", "HeadPattern", "HeadBg", "HeadIconHost", "HeadFrame",
		"NameBg", "NameLabel", "InfoLine1", "InfoLine2", "InfoLine3",
		"ChangeNameBtn", "ChangeNameLabel", "ChangeHeadBtn", "ChangeHeadLabel",
		"SaveManagerBtn", "SaveManagerLabel", "SocietyLine", "LanguageLine",
		"FacebookLine", "SetupBtn", "SetupLabel", "LangBtn", "LangLabel",
	]
	for n in names:
		assert_not_null(_find(inst, n), "静态节点存在：%s" % n)


func test_no_cut_residue() -> void:
	# 单机化裁剪残留守卫：联机功能元素不得回加
	var inst := _content()
	for n in CUT_NODES:
		assert_null(_find(inst, n), "被裁节点不得存在：%s" % n)


func test_frame_rect_and_cap() -> void:
	# frame 620×380 终值 + cap 防反写（top=26/bottom=20，批内通病）
	var inst := _content()
	var frame: NinePatchRect = _find(inst, "Frame") as NinePatchRect
	assert_almost_eq(frame.offset_left, FRAME_L, 0.5, "frame 左（源 84 直译）")
	assert_almost_eq(frame.offset_top, FRAME_T, 0.5, "frame 顶（480-455=25）")
	assert_almost_eq(frame.offset_right, FRAME_R, 0.5, "frame 右（源 704 直译）")
	assert_almost_eq(frame.offset_bottom, FRAME_B, 0.5, "frame 底（480-75=405）")
	assert_eq(frame.patch_margin_top, FRAME_CAP_TOP, "cap top=H-y-h=61-20-15（防反写）")
	assert_eq(frame.patch_margin_bottom, 20, "cap bottom=y=20（防反写）")
	assert_eq(frame.patch_margin_right, FRAME_CAP_RIGHT, "cap right=W-x-w=103-15-45")


func test_close_btn_rect_and_stretch() -> void:
	# close 中心 (770,125)（源 690,435）+ 65×66÷CS 显示尺寸 + 显式 stretch_mode=0
	var inst := _content()
	var btn: TextureButton = _find(inst, "CloseBtn") as TextureButton
	assert_almost_eq((btn.offset_left + btn.offset_right) * 0.5, CLOSE_CX, 0.5, "close 中心 x")
	assert_almost_eq((btn.offset_top + btn.offset_bottom) * 0.5, CLOSE_CY, 0.5, "close 中心 y")
	assert_almost_eq(btn.offset_right - btn.offset_left, CLOSE_W, 0.5, "close 宽 65÷CS")
	assert_almost_eq(btn.offset_bottom - btn.offset_top, CLOSE_H, 0.5, "close 高 66÷CS")
	assert_eq(btn.stretch_mode, TextureButton.STRETCH_SCALE, "TextureButton 显式 stretch_mode=0")


func test_head_zone_display_sizes() -> void:
	# 头区贴图显示尺寸 = 像素 ÷CS（均无 TextureConfig 条目）+ 中心照源 + 等比
	var inst := _content()
	var pattern: TextureRect = _find(inst, "HeadPattern") as TextureRect
	assert_almost_eq(pattern.size.x, HEAD_PATTERN_DISPLAY, 0.5, "pattern 171÷CS 宽")
	assert_almost_eq(pattern.size.y / pattern.size.x, 1.0, 0.01, "pattern 正方形等比")
	assert_almost_eq((pattern.offset_left + pattern.offset_right) * 0.5, HEAD_PATTERN_CX, 0.5, "pattern 中心 x（源 185 直译）")
	assert_almost_eq((pattern.offset_top + pattern.offset_bottom) * 0.5, HEAD_PATTERN_CY, 0.5, "pattern 中心 y（480-360=120）")
	var bg: TextureRect = _find(inst, "HeadBg") as TextureRect
	assert_almost_eq(bg.size.x, HEAD_BG_W, 0.5, "bg 100÷CS 宽")
	assert_almost_eq(bg.size.y, HEAD_BG_H, 0.5, "bg 105÷CS 高（非正方形等比 20:21）")
	assert_almost_eq((bg.offset_left + bg.offset_right) * 0.5, HEAD_PATTERN_CX, 0.5, "bg 中心 x 同 pattern（源同位 185,360）")
	var frame: TextureRect = _find(inst, "HeadFrame") as TextureRect
	assert_almost_eq(frame.size.x, HEAD_FRAME_W, 0.5, "frame 140÷CS 宽")
	assert_almost_eq(frame.size.y, HEAD_FRAME_H, 0.5, "frame 104÷CS 高（等比 140:104）")
	assert_almost_eq((frame.offset_left + frame.offset_right) * 0.5, HEAD_FRAME_CX, 0.5, "frame 中心 x（源 200 直译，右移 15 突出）")


func test_head_icon_draw_order() -> void:
	# 源 z 序：head_frame z=5（configure.lua:1142）> head icon z=3（:83 addChild(head,3)）→
	# 框纹盖头像缘。Godot 走纯声明序（tscn Host 声明于 HeadFrame 前）+ icon 运行时 z_index=0——
	# z_as_relative 默认 true，icon 设 z_index=3 会累加 PopWindow z=100（icon 103 > frame 100）
	# 反序盖框（2026-08-18 审查 Important 守卫，补运行时断言堵 get_index-only 盲区）。
	var inst := _content()
	var host: Control = _find(inst, "HeadIconHost") as Control
	var frame: Control = _find(inst, "HeadFrame") as Control
	assert_true(host.get_index() < frame.get_index(), "icon(z3) 在 frame(z5) 之下绘制")
	# 运行时守卫：panel fill 后 icon 真创建 + z_index 默认 0（禁相对 z 逃逸）
	var cm := ConfigManager.new()
	cm.load_all()
	var pd := PlayerData.new(cm)
	var panel: ConfigurePanel = ConfigurePanel.new("configure", {})
	panel.setup_panel(pd, cm)
	add_child_autofree(panel)
	var rt_content: Control = panel.container.get_node("ConfigureContent")
	var rt_host: Control = rt_content.get_node("%HeadIconHost") as Control
	var rt_frame: Control = rt_content.get_node("%HeadFrame") as Control
	assert_gt(rt_host.get_child_count(), 0, "head icon 已 fill 创建（默认 avatar=1 → Coco.jpg）")
	for child in rt_host.get_children():
		var icon: CanvasItem = child as CanvasItem
		assert_eq(icon.z_index, 0, "head icon z_index=0 默认（禁相对 z 逃逸盖框）")
	assert_true(rt_host.get_index() < rt_frame.get_index(), "运行时声明序 icon 在 frame 之下")


func test_head_icon_host_rect() -> void:
	# host 70×70 中心 (265,197)（源 head (185,363) 中心锚）
	var inst := _content()
	var host: Control = _find(inst, "HeadIconHost") as Control
	assert_almost_eq(host.offset_left, HOST_L, 0.5, "host 左")
	assert_almost_eq(host.offset_top, HOST_T, 0.5, "host 顶（480-363-35=82）")
	assert_almost_eq(host.offset_right, HOST_R, 0.5, "host 右")
	assert_almost_eq(host.offset_bottom, HOST_B, 0.5, "host 底")


func test_info_lines_layout() -> void:
	# info 行 x=385 + 中心 y 195/217/239（源 365-22*(i-1)，行距 22）
	var inst := _content()
	for i in 3:
		var line: Label = _find(inst, "InfoLine" + str(i + 1)) as Label
		assert_almost_eq(line.offset_left, INFO_L, 0.5, "InfoLine%d 左（源 305 直译）" % (i + 1))
		var cy: float = (line.offset_top + line.offset_bottom) * 0.5
		assert_almost_eq(cy, INFO_CY[i], 0.5, "InfoLine%d 中心 y" % (i + 1))
		assert_eq(line.theme_type_variation, &"InfoLineLabel", "InfoLine%d variation" % (i + 1))
	var l2: Label = _find(inst, "InfoLine2") as Label
	var l1: Label = _find(inst, "InfoLine1") as Label
	assert_almost_eq(l2.offset_top - l1.offset_top, 22.0, 0.5, "info 行距 22 照源")


func test_right_column_buttons_layout() -> void:
	# 右列三按钮 130×55（源 615,385/312/222）+ ConfigureActionBtn variation
	var inst := _content()
	var tops: Array[float] = [CHANGE_NAME_T, CHANGE_HEAD_T, SAVE_MANAGER_T]
	var names: Array[String] = ["ChangeNameBtn", "ChangeHeadBtn", "SaveManagerBtn"]
	for i in 3:
		var btn: Button = _find(inst, names[i]) as Button
		assert_almost_eq(btn.offset_left, RIGHT_BTN_L, 0.5, "%s 左（源 615−65=550）" % names[i])
		assert_almost_eq(btn.offset_right, RIGHT_BTN_R, 0.5, "%s 右（130 宽）" % names[i])
		assert_almost_eq(btn.offset_top, tops[i], 0.5, "%s 顶" % names[i])
		assert_almost_eq(btn.offset_bottom - btn.offset_top, 55.0, 0.5, "%s 高 55" % names[i])
		assert_eq(btn.theme_type_variation, &"ConfigureActionBtn", "%s variation" % names[i])


func test_bottom_row_layout() -> void:
	# setup 180×55 照源 (200,115)；lang 100×60 占 select_server 位；label 中心 +88
	var inst := _content()
	var setup: Button = _find(inst, "SetupBtn") as Button
	assert_almost_eq(setup.offset_left, SETUP_L, 0.5, "setup 左（源中心 200−半宽 90=110）")
	assert_almost_eq(setup.offset_top, SETUP_T, 0.5, "setup 顶（480−115−27.5）")
	assert_almost_eq(setup.offset_right, SETUP_R, 0.5, "setup 右（180 宽）")
	assert_almost_eq(setup.offset_bottom, SETUP_B, 0.5, "setup 底")
	assert_eq(setup.theme_type_variation, &"ConfigureActionBtn", "setup variation")
	var lang: TextureButton = _find(inst, "LangBtn") as TextureButton
	assert_almost_eq((lang.offset_left + lang.offset_right) * 0.5, 393.0, 0.5, "lang 中心 x（单机化重排占 select_server 位）")
	assert_almost_eq((lang.offset_top + lang.offset_bottom) * 0.5, 362.5, 0.5, "lang 中心 y（底对齐底排 472.5，100x60 高于 55 按钮）")
	assert_almost_eq(lang.offset_bottom, 392.5, 0.5, "lang 底与 setup 底齐（不压 FacebookLine 474）")
	assert_almost_eq(lang.offset_bottom - lang.offset_top, 60.0, 0.5, "lang 高 60 照源 scaleSize")
	assert_eq(lang.stretch_mode, TextureButton.STRETCH_SCALE, "lang 显式 stretch_mode=0")
	var label: Label = _find(inst, "LangLabel") as Label
	assert_almost_eq((label.offset_left + label.offset_right) * 0.5, LANG_LABEL_CX, 0.5, "lang label 中心 x（源 按钮中心+88）")
	assert_almost_eq((label.offset_top + label.offset_bottom) * 0.5, LANG_LABEL_CY, 0.5, "lang label 中心 y 同按钮")


func test_delimiter_lines() -> void:
	# 三条分隔线：贴图（HC 复用）600×2 直译 + patch L170/T1/R275/B1（455×3 cap(170,1,10,1)）
	var inst := _content()
	var cases: Dictionary = {"SocietyLine": 200.0, "LanguageLine": 330.0, "FacebookLine": 395.0}
	for n: String in cases:
		var line: NinePatchRect = _find(inst, n) as NinePatchRect
		assert_not_null(line, "%s 存在" % n)
		if line == null:
			continue
		assert_almost_eq(line.offset_left, LINE_L, 0.5, "%s 左（600 宽中心 390）" % n)
		assert_almost_eq(line.offset_right, LINE_R, 0.5, "%s 右" % n)
		var cy: float = (line.offset_top + line.offset_bottom) * 0.5
		assert_almost_eq(cy, cases[n], 0.5, "%s 中心 y" % n)
		assert_almost_eq(line.offset_bottom - line.offset_top, 2.0, 0.5, "%s 高 2 照源 scaleSize" % n)
		assert_eq(line.patch_margin_left, LINE_PATCH_LEFT, "%s cap left" % n)
		assert_eq(line.patch_margin_right, LINE_PATCH_RIGHT, "%s cap right=455-170-10" % n)
		assert_eq(line.patch_margin_top, LINE_PATCH_TOP, "%s cap top=3-1-1" % n)
		assert_eq(line.patch_margin_bottom, LINE_PATCH_BOTTOM, "%s cap bottom" % n)
	assert_true(ResourceLoader.exists(DELIMITER_PATH), "分隔线贴图落位（HC 老版复用）")


func test_name_label_style() -> void:
	# name label：中心锚定 name_bg（源 (370,410) 中心 = bg 中心），宽上限 180，居中 + variation
	var inst := _content()
	var bg: TextureRect = _find(inst, "NameBg") as TextureRect
	assert_almost_eq(bg.offset_left, NAME_BG_L, 0.5, "name_bg 左（源 fix_wh 225 直译）")
	assert_almost_eq(bg.offset_top, NAME_BG_T, 0.5, "name_bg 顶（480-410-15=55）")
	assert_almost_eq(bg.offset_right, NAME_BG_R, 0.5, "name_bg 右")
	assert_almost_eq(bg.offset_bottom, NAME_BG_B, 0.5, "name_bg 底（30 高）")
	var label: Label = _find(inst, "NameLabel") as Label
	assert_almost_eq((label.offset_left + label.offset_right) * 0.5, 370.0, 0.5, "name label 中心 x 同 bg（源 370 直译）")
	assert_almost_eq((label.offset_top + label.offset_bottom) * 0.5, 70.0, 0.5, "name label 中心 y（480-410=70）")
	assert_almost_eq(label.offset_right - label.offset_left, 180.0, 0.5, "name label 宽上限 180（源 :114-116 scale 限制）")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "name label 居中（源中心锚点）")
	assert_eq(label.theme_type_variation, &"ConfigureNameLabel", "name label variation（白 20 黑影）")


func test_panel_no_runtime_stylebox() -> void:
	# Scale9 样式收敛 variation 守卫：运行时 stylebox override 与 UiScale9Button 引用归零
	var script_text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(script_text.count("add_theme_stylebox_override"), 0, "panel 无运行时 stylebox override")
	assert_eq(script_text.count("UiScale9Button"), 0, "UiScale9Button 退役（同图同 cap 走 ConfigureActionBtn）")
	assert_eq(script_text.count("ui_scale9_button"), 0, "ui_scale9_button preload 退役")


func test_theme_variations_registered() -> void:
	# GUT 下 variation 不解析 → 读 tres 文本表项（约束 #9）
	var theme_text: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(theme_text.contains("ConfigureActionBtn/styles/normal = SubResource(\"SB_pkg_hb_n\")"), "按钮 normal 复用 SB_pkg_hb_n")
	assert_true(theme_text.contains("ConfigureActionBtn/styles/pressed = SubResource(\"SB_pkg_hb_p\")"), "按钮 pressed 复用 SB_pkg_hb_p")
	assert_true(theme_text.contains("ConfigureActionBtn/styles/focus = SubResource(\"StyleBoxEmpty_0oxu6\")"), "按钮 focus 空")
	assert_true(theme_text.contains("ConfigureNameLabel/font_sizes/font_size = 20"), "name label 20 号")
	assert_true(theme_text.contains("ConfigureNameLabel/colors/font_color = Color(1, 1, 1, 1)"), "name label 白字（源无 config.color 默认白）")
	assert_true(theme_text.contains("ConfigureLangLabel/colors/font_color = Color(0.862745, 0.690196, 0.403922, 1)"), "lang label ccc3(220,176,103)")


func test_fill_semantics() -> void:
	# fill 语义：name/info 行文案 + 满级 ps 追加（源 createPlayerInformation :130）
	var cm := ConfigManager.new()
	cm.load_all()
	var pd := PlayerData.new(cm)
	var panel: ConfigurePanel = ConfigurePanel.new("configure", {})
	panel.setup_panel(pd, cm)
	add_child_autofree(panel)
	var content: Control = panel.container.get_node("ConfigureContent")
	assert_eq((content.get_node("%NameLabel") as Label).text, pd.player_name, "name fill")
	var line1: Label = content.get_node("%InfoLine1") as Label
	assert_true(line1.text.contains(str(pd.team_level)), "InfoLine1 含战队等级值")
	assert_true(line1.text.contains("战队等级"), "InfoLine1 含 LSTR 文案（zh-CN）")
	var line2: Label = content.get_node("%InfoLine2") as Label
	assert_true(line2.text.contains("/"), "InfoLine2 经验 exp/max 格式")
	var line3: Label = content.get_node("%InfoLine3") as Label
	assert_true(line3.text.contains(str(pd.MAX_TEAM_LEVEL)), "InfoLine3 含英雄等级上限")


func test_fill_level_cap_ps() -> void:
	# 源 :130 checkLevelMax → 满级时 title 后追加 HAS_REACHED_THE_LEVEL_CAP
	var cm := ConfigManager.new()
	cm.load_all()
	var pd := PlayerData.new(cm)
	pd.team_level = pd.MAX_TEAM_LEVEL
	var panel: ConfigurePanel = ConfigurePanel.new("configure", {})
	panel.setup_panel(pd, cm)
	add_child_autofree(panel)
	var content: Control = panel.container.get_node("ConfigureContent")
	var line1: Label = content.get_node("%InfoLine1") as Label
	assert_true(line1.text.contains("（已达到等级上限）"), "满级时追加 ps 提示（照源 :130/:186-206）")
