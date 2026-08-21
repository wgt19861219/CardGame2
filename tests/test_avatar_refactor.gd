extends GutTest
## avatar_panel 两件套守卫测试（2026-07-18 chrome 静态化试点 → 批 4 Task 3 完整树化）。
## 照源 ui/selectwindow/base.lua（96 行 chrome）+ ofavatar.lua（272 行内容）：
##   base：frame main_vit_tips cap(10,10,58,26) scaleSize(530,375) 中心(400,240)；
##   draglist cliprect(154,60,492,365) → AvatarScroll 234/135/726/500；
##   bar bg 2×320 中心(150,240) + bar 4px（滚动时显，draglist.lua:13-16/1116-1204）；
##   explain 仅 param.explain 非空才建——avatar 调用方（configure.lua:1935-1941）
##   只传 name+callback，explain 条件不触发（照源不建）。
##   ofavatar：分类标题 createSubhead（300×20 container + detail_title_bg
##   Scale9 300×12 cap(100,0,304,12) + Label 18 号 ccc3(231,206,19)）；
##   5 列网格 x 步进 100/y 步进 90（getIconPos :129-151）；
##   free 组末尾解锁提示 createUnlockPrompt（:123-128，18 号金）。
## 贴图 PIL 实测（2026-08-17，均无 TextureConfig 条目）：main_vit_tips 103×61、
## detail_title_bg 643×15、hero_icon_frame_1 106×106（显示 = 106/CS1.28125 = 82.73）。
## 守卫：Frame cap 防反写（top=25/bottom=10，批内通病）/ 标题行模板静态树 /
## variation 接线（AvatarTitleLabel 18 号金 + AvatarGrid sep 17/7 照源步进换算）/
## fill 语义（LSTR 文案 + 照源补解锁提示漏译）/ 手算 82.73（勿调 tex_display_size）。

const CONTENT_PATH: String = "res://scenes/ui/avatar_content.tscn"
const TITLE_ITEM_PATH: String = "res://scenes/ui/avatar_title_item.tscn"
const PANEL_PATH: String = "res://scripts/ui/avatar_panel.gd"
const THEME_PATH: String = "res://resources/themes/default_theme.tres"
# 源 cap(10,10,58,26) 批 1 公式（贴图 103×61）：left=10 top=61-10-26=25
# right=103-10-58=35 bottom=10（改造前 tscn top/bottom 写反，批内通病第三例）。
const FRAME_CAP_TOP: int = 25
const FRAME_CAP_BOTTOM: int = 10
# 源 scaleSize(530,375) 中心(400,240) → Godot 中心(480,320)。
const FRAME_L: float = 135.0
const FRAME_T: float = 52.5
const FRAME_W: float = 530.0
const FRAME_H: float = 375.0
# 源 cliprect(154,60,492,365) to_godot 直译。
const SCROLL_L: float = 154.0
const SCROLL_T: float = 55.0
const SCROLL_R: float = 646.0
const SCROLL_B: float = 420.0
# hero_icon_frame_1 106×106 / CS = 82.73（无 TextureConfig 条目，÷CS 轨道）。
const ICON_DISPLAY: float = 82.73
# 源 LSTR 键（ofavatar.lua:9-13 + :124）。
const LSTR_FREE: String = "HEROSELECT.BASIC_AVATAR"
const LSTR_HERO: String = "HEROSELECT.HERO_AVATAR"
const LSTR_WORLDCUP: String = "ofavatar.1.10.1.001"
const LSTR_TIPS: String = "HEROSELECT.TIPS__HERO_ADVANCED_TO_PURPLE_CAN_BE_SET_TO_AVATAR"

var _cm: ConfigManager


func before_all() -> void:
	_cm = ConfigManager.new()
	_cm.load_all()


# ── 动作守卫（2026-07-18 试点六动作，语义延续）──

func test_avatar_panel_no_translation_comments() -> void:
	# 翻译注释（# 源 xxx）归零，保留功能注释
	var script_text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(script_text.count("# 源 "), 0, "avatar_panel.gd 的翻译注释 '# 源 ' 归零")

func test_avatar_panel_no_color_override() -> void:
	# 颜色 override 归零：标题金（源 ccc3(231,206,19)）转 AvatarTitleLabel variation；
	# 滚动条 stylebox override 属引擎缺口例外（SOP 条款），不在此口径内。
	var script_text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(script_text.count("add_theme_color_override"), 0,
		"add_theme_color_override = 0（标题色进 variation，受控 override 退役）")

func test_avatar_panel_list_is_container() -> void:
	# 动态项用容器管理（VBox + procedural 挂 %AvatarList，brief 明示保留）
	var script_text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_true(script_text.find("VBoxContainer") != -1, "_list 用 VBoxContainer 容器")

func test_avatar_panel_signals_all_code_connected() -> void:
	# 信号策略 P2——全代码 connect，无 editor 连
	var script_text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_true(script_text.find("connect") != -1, "信号代码 connect（P2 默认规则）")

func test_avatar_panel_static_node_unique_name() -> void:
	# 节点静态化——%AvatarScroll/%AvatarList unique_name 在 .tscn 内
	var tscn_text: String = FileAccess.get_file_as_string(CONTENT_PATH)
	assert_true(tscn_text.find("AvatarList") != -1, "avatar_content.tscn 含 AvatarList 节点")
	assert_true(tscn_text.find("unique_name_in_owner") != -1,
		"avatar_content.tscn 节点标记 unique_name_in_owner")


# ── chrome 静态树（源 base.lua ui_info :54-71 + createListLayer :6-17）──

func test_avatar_content_frame_cap_fixed() -> void:
	# Frame cap 防反写守卫：源 CCRectMake(10,10,58,26)，贴图 103×61 PIL 实测，
	# 批 1 公式 top=H-y-h=25 / bottom=y=10（改造前 top=10/bottom=25 反写，批内通病）。
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var frame: NinePatchRect = inst.get_node("%Frame") as NinePatchRect
	assert_almost_eq(frame.offset_left, FRAME_L, 0.1,
		"Frame 左 = to_godot(400,240).x - 530/2")
	assert_almost_eq(frame.offset_top, FRAME_T, 0.1,
		"Frame 顶 = to_godot(400,240).y - 375/2")
	assert_almost_eq(frame.offset_right - frame.offset_left, FRAME_W, 0.1,
		"Frame 宽 = 源 scaleSize(530,375) 直译")
	assert_almost_eq(frame.offset_bottom - frame.offset_top, FRAME_H, 0.1, "Frame 高直译")
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/main_vit_tips.png",
		"Frame 贴图照源 main_vit_tips")
	assert_eq(frame.patch_margin_left, 10, "NinePatch left = cap.x")
	assert_eq(frame.patch_margin_top, FRAME_CAP_TOP,
		"NinePatch top = H-y-h = 61-10-26 = 25（防反写回归）")
	assert_eq(frame.patch_margin_right, 35, "NinePatch right = W-x-w = 103-10-58（水平不反转）")
	assert_eq(frame.patch_margin_bottom, FRAME_CAP_BOTTOM,
		"NinePatch bottom = cap.y = 10（防反写回归）")

func test_avatar_content_scroll_rect() -> void:
	# 源 draglist cliprect(154,60,492,365) → to_godot 左上 (234,135) 右下 (726,500)。
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var scroll: ScrollContainer = inst.get_node("%AvatarScroll") as ScrollContainer
	assert_almost_eq(scroll.offset_left, SCROLL_L, 0.1, "裁剪层左 = 154+80")
	assert_almost_eq(scroll.offset_top, SCROLL_T, 0.1, "裁剪层顶 = 560-(60+365)")
	assert_almost_eq(scroll.offset_right, SCROLL_R, 0.1, "裁剪层右 = 154+492+80")
	assert_almost_eq(scroll.offset_bottom, SCROLL_B, 0.1, "裁剪层底 = 560-60")
	assert_true(scroll.clip_contents, "源 cliprect → clip_contents 裁剪（坑 #3）")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
		"源竖向 draglist，水平滚动禁用")


# ── 标题行模板（源 createSubhead :109-121，动态行范式）──

func test_avatar_title_item_static_tree() -> void:
	# 分类标题数量随解锁变（1-3 个）→ 行模板 tscn + fill 文案（两件套动态行范式）。
	assert_true(ResourceLoader.exists(TITLE_ITEM_PATH, "PackedScene"), "标题行模板存在")
	if not ResourceLoader.exists(TITLE_ITEM_PATH, "PackedScene"):
		return
	var inst: Control = (load(TITLE_ITEM_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# 源 container 300×20 视觉条 + titleHeight=40 计账（initListHeight :20）→ 行高 40。
	assert_almost_eq(inst.size.y, 40.0, 0.1, "标题行高 = 源 titleHeight=40 计账")
	var bg: NinePatchRect = inst.get_node("%TitleBg") as NinePatchRect
	# 源 detail_title_bg Scale9 setContentSize(300,12) 贴图 643×15 cap(100,0,304,12)。
	# Godot NinePatchRect min=patch 和(100+239=339)>300 钳宽 → AtlasTexture 预裁
	# region(0,0,404,15)（左 100+中心 304，裁右侧延伸区）右 patch 归零，视觉等价源。
	var bg_tex: AtlasTexture = bg.texture as AtlasTexture
	assert_ne(bg_tex, null, "底板贴图 AtlasTexture 预裁（绕 NinePatch min 钳制）")
	if bg_tex != null:
		assert_eq(bg_tex.region, Rect2(0.0, 0.0, 404.0, 15.0),
			"裁剪区 = 左 patch 100 + 中心 304（右 239 延伸区裁除）")
	assert_almost_eq(bg.size.x, 300.0, 0.1, "标题底板宽 = 源 setContentSize(300,12)")
	assert_almost_eq(bg.size.y, 12.0, 0.1, "标题底板高 = 12")
	assert_eq(bg.patch_margin_left, 100, "底板 cap left = 100")
	assert_eq(bg.patch_margin_top, 3, "底板 cap top = H-y-h = 15-0-12（防反写）")
	assert_eq(bg.patch_margin_right, 0, "底板 cap right = 0（右 patch 区已预裁进 region）")
	assert_eq(bg.patch_margin_bottom, 0, "底板 cap bottom = y = 0（防反写）")
	assert_almost_eq(bg.position.x + bg.size.x * 0.5, inst.size.x * 0.5, 0.1,
		"底板水平居中（源 bg/label 同心 (150,10)=container 中心）")
	assert_almost_eq(bg.position.y + bg.size.y * 0.5, inst.size.y * 0.5, 0.1, "底板垂直居中")
	var lbl: Label = inst.get_node("%TitleLabel") as Label
	assert_eq(String(lbl.theme_type_variation), "AvatarTitleLabel",
		"标题 Label 走 AvatarTitleLabel variation（18 号 ccc3(231,206,19)）")
	assert_eq(lbl.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "源 label 中心锚 → 水平居中")


# ── theme variation 接线（GUT 下 get_theme_font_size 不解析 variation，读 tres 文本）──

func test_theme_variation_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("AvatarTitleLabel/base_type = &\"Label\""),
		"AvatarTitleLabel variation 注册")
	assert_true(t.contains("AvatarTitleLabel/font_sizes/font_size = 18"),
		"标题字号 18（源 createttf(text, 18)）")
	assert_true(t.contains("AvatarTitleLabel/colors/font_color = Color(0.905882, 0.807843, 0.07451, 1)"),
		"标题字色 = ccc3(231,206,19)（源 setLabelColor）")
	assert_true(t.contains("AvatarGrid/base_type = &\"GridContainer\""),
		"AvatarGrid variation 注册")
	assert_true(t.contains("AvatarGrid/constants/h_separation = 17"),
		"网格列距 = 100-82.73 ≈ 17（源 x 步进 100 换算）")
	assert_true(t.contains("AvatarGrid/constants/v_separation = 7"),
		"网格行距 = 90-82.73 ≈ 7（源 y 步进 90 换算）")

func test_avatar_grid_variation_wired() -> void:
	# procedural GridContainer 接 AvatarGrid variation（声明式，非 override 函数）。
	var script_text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_true(script_text.contains("theme_type_variation = &\"AvatarGrid\""),
		"网格容器接 AvatarGrid variation（sep 照源步进换算进 theme）")


# ── 贴图显示尺寸口径（批 4 手算，勿调 tex_display_size——其公式漏除 CS 偏大 1.28×）──

func test_avatar_panel_no_tex_display_size() -> void:
	var script_text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(script_text.count("TexDisplaySize"), 0,
		"panel 不调 TexDisplaySize（无条目散图 ÷CS 口径手算，批 4 约束）")
	assert_true(script_text.contains("82.73"), "icon 显示 106/CS = 82.73 手算落位")


# ── panel fill 语义（源 LSTR 文案 + 照源补解锁提示漏译）──

func test_avatar_panel_fill_semantics() -> void:
	# 等级 1 新档：free 11 项可见 / hero 0 / worldcup 0（Avatar 表实测）
	# → fill 后 _list 子序 [标题行, 网格, 解锁提示]（源 free 组 i=1 标题 +
	# i=#resList.free 解锁提示 :158-167）。
	var pd := PlayerData.new(_cm)
	var panel: AvatarPanel = AvatarPanel.new("avatar", {})
	panel.setup_panel(pd, _cm)
	add_child_autofree(panel)
	var list: VBoxContainer = panel._list
	assert_gte(list.get_child_count(), 3,
		"free 组 fill 后含 [标题, 网格, 解锁提示] 三段（提示照源补漏译）")
	if list.get_child_count() < 3:
		return
	# 标题行 = 行模板实例（%TitleLabel fill 文案）
	var title_root: Control = list.get_child(0) as Control
	var title_lbl: Label = title_root.get_node("%TitleLabel") as Label
	assert_eq(title_lbl.text, _cm.get_lstr(LSTR_FREE),
		"free 标题文案照源 LSTR（T(LSTR(HEROSELECT.BASIC_AVATAR))）")
	# 网格：5 列 + 首格 82.73 显示尺寸（手算口径）
	var grid: GridContainer = list.get_child(1) as GridContainer
	assert_eq(grid.columns, 5, "源 5 列网格（(i-1)%%5 步进）")
	var cell: Control = grid.get_child(0) as Control
	assert_almost_eq(cell.size.x, ICON_DISPLAY, 0.2,
		"icon 宽 = 106/CS = 82.73（÷CS 轨道，勿偏大 1.28×）")
	assert_almost_eq(cell.size.y, ICON_DISPLAY, 0.2, "icon 高 = 82.73")
	assert_eq((cell as TextureButton).stretch_mode, TextureButton.STRETCH_SCALE,
		"TextureButton stretch_mode=0 显式（默认 KEEP 不填 rect，批 2 方法论）")
	# 解锁提示照源补（createUnlockPrompt :123-128，18 号金）
	var tips: Label = list.get_child(2) as Label
	assert_eq(tips.text, _cm.get_lstr(LSTR_TIPS),
		"free 组末尾解锁提示照源（此前漏译，2026-08-17 补）")

func test_avatar_panel_lstr_keys_wired() -> void:
	# 三组标题键接线（源 type_priority :4-8 / type_title :9-13）；
	# worldcup 键 ofavatar.1.10.1.001 = 球队头像（此前硬编码"世界杯头像"与源值不符）。
	var script_text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_true(script_text.contains(LSTR_FREE), "free 标题键接线")
	assert_true(script_text.contains(LSTR_HERO), "hero 标题键接线")
	assert_true(script_text.contains(LSTR_WORLDCUP), "worldcup 标题键接线（球队头像）")
	assert_true(script_text.contains(LSTR_TIPS), "解锁提示键接线")


# ── chrome 补全：滚动条照源贴图（源 draglist bar，引擎缺口例外路径）──

func test_avatar_scrollbar_styled() -> void:
	# 源 bar bg=scroll_bar_bg(2px 厚) + bar=scroll_bar.png(4px 厚)，滚动时显示；
	# Godot ScrollContainer 默认灰圆角条 → fill 期 StyleBoxTexture 贴图化
	# （add_theme_stylebox_override 引擎缺口例外，SOP 滚动条条款）。
	var pd := PlayerData.new(_cm)
	var panel: AvatarPanel = AvatarPanel.new("avatar", {})
	panel.setup_panel(pd, _cm)
	add_child_autofree(panel)
	var scroll: ScrollContainer = panel._content.get_node("%AvatarScroll") as ScrollContainer
	var vs: VScrollBar = scroll.get_v_scroll_bar()
	assert_true(vs.get_theme_stylebox("grabber") is StyleBoxTexture,
		"grabber 贴图化（源 scroll_bar.png）")
	assert_true(vs.get_theme_stylebox("scroll") is StyleBoxTexture,
		"轨道贴图化（源 scroll_bar_bg.png）")
	assert_eq((vs.get_theme_stylebox("grabber") as StyleBoxTexture).texture.resource_path,
		"res://assets/ui/alpha/HVGA/scroll_bar.png", "grabber 贴图照源")


# ── 静态结构禁令（标题底板/装饰结构进模板，panel 不建静态节点）──

func test_avatar_panel_no_static_construction() -> void:
	# 标题底板 NinePatchRect 静态化进行模板后，panel 零 NinePatchRect.new；
	# 动态项（GridContainer/TextureButton/TextureRect/Label）为 brief 明示保留的
	# procedural 范围，不在禁令内。
	var script_text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(script_text.count("NinePatchRect.new"), 0,
		"标题底板 NinePatchRect 静态化进 avatar_title_item.tscn（panel 零静态建造）")
