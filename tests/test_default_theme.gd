extends GutTest

const UIConstants := preload("res://resources/constants/ui_constants.gd")
## 验证 default_theme.tres 被正确加载，且覆盖核心控件类型（Button/Label）。
## TDD Task 3：先红（ThemeManager 不存在）后绿（建 Theme + Manager）。
## 轮 0 TDD：8 个新增变体（TitleLabel/BodyLabel/BodyLabelThin/ShadowedLabel/
## AmountLabel/BtnLabel/DialogLabel/GhostButton）的语义断言。轮 0 写完预期全红
## （变体未建），轮 1 T1 建变体后转绿。详见 设计-add_theme系统化-2026-07-25.md。

func test_theme_manager_loads_default_theme() -> void:
	var theme: Theme = ThemeManager.get_theme()
	assert_not_null(theme, "ThemeManager 返回非空 Theme")

func test_theme_has_button_stylebox() -> void:
	var theme: Theme = ThemeManager.get_theme()
	# Theme 必须为 Button 提供 normal stylebox（归纳自 59 处 add_theme_stylebox_override）
	var sb: StyleBox = theme.get_stylebox("normal", "Button")
	assert_not_null(sb, "Button normal stylebox 存在")

func test_theme_has_label_font_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "Label")
	assert_ne(color, Color.TRANSPARENT, "Label font_color 已设置（非透明默认）")

func test_theme_has_default_font_size() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "Label")
	assert_gt(size, 0, "Label font_size > 0")


# ── 轮 0：8 个新增变体的语义断言（预期全红，变体未建）──
# 轮 1 T1 建变体后，这些断言转绿。
# Color 断言用 assert_color_approx 容差 0.001：.tres 小数形式（如 0.608）与
# ui_constants.gd 的 /255 表达式（155/255=0.60784316）在 Godot Color 严格 ==
# 比较 bit-level 不等，但视觉上数学等价。int 断言保持 assert_eq。
# 注：GUT assert_almost_eq 不支持 Color（仅 Vector2/3/4），故自写 helper。

# 比较 Color 4 通道，每通道 |got - expected| <= 0.001。
func assert_color_approx(got: Color, expected: Color, label: String) -> void:
	var tol: float = 0.001
	assert_true(absf(got.r - expected.r) <= tol, "%s: R %.6f ≈ %.6f ± %.4f" % [label, got.r, expected.r, tol])
	assert_true(absf(got.g - expected.g) <= tol, "%s: G %.6f ≈ %.6f ± %.4f" % [label, got.g, expected.g, tol])
	assert_true(absf(got.b - expected.b) <= tol, "%s: B %.6f ≈ %.6f ± %.4f" % [label, got.b, expected.b, tol])
	assert_true(absf(got.a - expected.a) <= tol, "%s: A %.6f ≈ %.6f ± %.4f" % [label, got.a, expected.a, tol])

func test_title_label_has_gold_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "TitleLabel")
	assert_color_approx(color, UIConstants.COLOR_TITLE_GOLD, "TitleLabel font_color ≈ COLOR_TITLE_GOLD")

func test_title_label_has_title_size() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "TitleLabel")
	assert_eq(size, UIConstants.FONT_SIZE_TITLE, "TitleLabel font_size = FONT_SIZE_TITLE (20)")


func test_body_label_has_white_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "BodyLabel")
	assert_color_approx(color, UIConstants.COLOR_TEXT_DEFAULT, "BodyLabel font_color ≈ COLOR_TEXT_DEFAULT (白)")

func test_body_label_has_btn_outline_size() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_constant("outline_size", "BodyLabel")
	assert_eq(size, UIConstants.OUTLINE_SIZE_BTN, "BodyLabel outline_size = OUTLINE_SIZE_BTN (2)")

func test_body_label_thin_has_thin_outline() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_constant("outline_size", "BodyLabelThin")
	assert_eq(size, UIConstants.OUTLINE_SIZE_THIN, "BodyLabelThin outline_size = OUTLINE_SIZE_THIN (1)")

func test_body_label_thin_has_white_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "BodyLabelThin")
	assert_color_approx(color, UIConstants.COLOR_TEXT_DEFAULT, "BodyLabelThin font_color ≈ 白")


func test_shadowed_label_has_shadow_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_shadow_color", "ShadowedLabel")
	assert_color_approx(color, UIConstants.COLOR_TEXT_SHADOW, "ShadowedLabel font_shadow_color ≈ COLOR_TEXT_SHADOW (黑)")

func test_shadowed_label_has_shadow_offset_y() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var offset: int = theme.get_constant("shadow_offset_y", "ShadowedLabel")
	assert_eq(offset, UIConstants.SHADOW_OFFSET_Y, "ShadowedLabel shadow_offset_y = SHADOW_OFFSET_Y (2)")

func test_shadowed_label_has_shadow_offset_x() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var offset: int = theme.get_constant("shadow_offset_x", "ShadowedLabel")
	assert_eq(offset, UIConstants.SHADOW_OFFSET_X, "ShadowedLabel shadow_offset_x = SHADOW_OFFSET_X (0)")


func test_amount_label_has_amount_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "AmountLabel")
	assert_color_approx(color, UIConstants.COLOR_AMOUNT, "AmountLabel font_color ≈ COLOR_AMOUNT")

func test_amount_label_has_amount_size() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "AmountLabel")
	assert_eq(size, UIConstants.FONT_SIZE_AMOUNT, "AmountLabel font_size = FONT_SIZE_AMOUNT (18)")

func test_btn_label_has_btn_label_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "BtnLabel")
	assert_color_approx(color, UIConstants.COLOR_BTN_LABEL, "BtnLabel font_color ≈ COLOR_BTN_LABEL")

func test_btn_label_has_btn_outline_size() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_constant("outline_size", "BtnLabel")
	assert_eq(size, UIConstants.OUTLINE_SIZE_BTN, "BtnLabel outline_size = OUTLINE_SIZE_BTN (2)")


func test_dialog_label_has_white_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "DialogLabel")
	assert_color_approx(color, UIConstants.COLOR_TEXT_DEFAULT, "DialogLabel font_color ≈ 白")

func test_dialog_label_has_default_outline() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_constant("outline_size", "DialogLabel")
	assert_eq(size, UIConstants.OUTLINE_SIZE_DEFAULT, "DialogLabel outline_size = OUTLINE_SIZE_DEFAULT (3)")


func test_ghost_button_normal_is_stylebox_empty() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var sb: StyleBox = theme.get_stylebox("normal", "GhostButton")
	assert_not_null(sb, "GhostButton normal stylebox 存在")
	assert_true(sb is StyleBoxEmpty, "GhostButton normal 是 StyleBoxEmpty")

func test_ghost_button_hover_is_stylebox_empty() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var sb: StyleBox = theme.get_stylebox("hover", "GhostButton")
	assert_true(sb is StyleBoxEmpty, "GhostButton hover 是 StyleBoxEmpty")

func test_ghost_button_pressed_is_stylebox_empty() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var sb: StyleBox = theme.get_stylebox("pressed", "GhostButton")
	assert_true(sb is StyleBoxEmpty, "GhostButton pressed 是 StyleBoxEmpty")

func test_ghost_button_focus_is_stylebox_empty() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var sb: StyleBox = theme.get_stylebox("focus", "GhostButton")
	assert_true(sb is StyleBoxEmpty, "GhostButton focus 是 StyleBoxEmpty")


# ── 轮 3 新增 10 变体（完整签名断言，spec v2.2 §1.1）──

func test_handbook_entry_label_has_entry_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "HandbookEntryLabel")
	assert_color_approx(color, Color(0.698039, 0.588235, 0.572549, 1), "HandbookEntryLabel font_color")

func test_handbook_entry_label_has_size_16() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "HandbookEntryLabel")
	assert_eq(size, 16, "HandbookEntryLabel font_size = 16")


# ── 批4 Task 5 handbook 两件套改造新增（tag 两 variation + 装备名/页码 variation）──

func test_handbook_entry_label_has_unselected_shadow() -> void:
	# 源 doSelectTag :94 未选中 setShadow(ccc3(0,0,0), ccp(0,2))；选中 :100 disableShadow → 两 variation
	var theme: Theme = ThemeManager.get_theme()
	var shadow: Color = theme.get_color("font_shadow_color", "HandbookEntryLabel")
	assert_color_approx(shadow, Color(0, 0, 0, 1), "HandbookEntryLabel 未选中阴影黑")
	assert_eq(theme.get_constant("shadow_offset_x", "HandbookEntryLabel"), 0, "阴影偏移 x=0")
	assert_eq(theme.get_constant("shadow_offset_y", "HandbookEntryLabel"), 2, "阴影偏移 y=2")


func test_handbook_entry_label_selected_white_no_shadow() -> void:
	# 源 doSelectTag :100-101 选中 disableShadow + ccc3(255,255,255)，字号 16 不变
	var theme: Theme = ThemeManager.get_theme()
	assert_color_approx(theme.get_color("font_color", "HandbookEntryLabelSelected"), Color(1, 1, 1, 1), "选中态白")
	assert_eq(theme.get_font_size("font_size", "HandbookEntryLabelSelected"), 16, "选中态 16 号")
	assert_false(theme.has_color("font_shadow_color", "HandbookEntryLabelSelected"), "选中态无阴影")


func test_handbook_equip_name_label_style() -> void:
	# 源 createIcon :443-444 equipNameLabelColor ccc3(182,65,21) size=18 + 黑描边 2px
	var theme: Theme = ThemeManager.get_theme()
	assert_color_approx(theme.get_color("font_color", "HandbookEquipNameLabel"), Color(0.713726, 0.254902, 0.082353, 1), "装备名色 (182,65,21)")
	assert_eq(theme.get_font_size("font_size", "HandbookEquipNameLabel"), 18, "装备名 18 号")
	assert_eq(theme.get_constant("outline_size", "HandbookEquipNameLabel"), 2, "装备名描边 2")
	assert_color_approx(theme.get_color("font_outline_color", "HandbookEquipNameLabel"), Color(0, 0, 0, 1), "描边黑")


func test_handbook_page_label_brown() -> void:
	# 源 setPageTitle :511 pageNumber ccc3(174,133,76) 18 号（原 BlackLabel18 黑色不符）
	var theme: Theme = ThemeManager.get_theme()
	assert_color_approx(theme.get_color("font_color", "HandbookPageLabel"), Color(0.682353, 0.521569, 0.298039, 1), "页码色 (174,133,76)")
	assert_eq(theme.get_font_size("font_size", "HandbookPageLabel"), 18, "页码 18 号")

func test_hero_tab_label_has_white_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "HeroTabLabel")
	assert_color_approx(color, Color(1, 1, 1, 1), "HeroTabLabel font_color")

func test_hero_tab_label_has_dark_red_shadow() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var shadow: Color = theme.get_color("font_shadow_color", "HeroTabLabel")
	assert_color_approx(shadow, Color(0.247, 0.02, 0, 1), "HeroTabLabel font_shadow_color")

func test_hero_tab_label_has_size_20() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "HeroTabLabel")
	assert_eq(size, 20, "HeroTabLabel font_size = 20")

func test_hero_tab_label_has_shadow_offset() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var sx: int = theme.get_constant("shadow_offset_x", "HeroTabLabel")
	var sy: int = theme.get_constant("shadow_offset_y", "HeroTabLabel")
	assert_eq(sx, 0, "HeroTabLabel shadow_offset_x = 0")
	assert_eq(sy, 2, "HeroTabLabel shadow_offset_y = 2")

func test_black_label_18_has_black_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "BlackLabel18")
	assert_color_approx(color, Color(0, 0, 0, 1), "BlackLabel18 font_color")

func test_black_label_18_has_size_18() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "BlackLabel18")
	assert_eq(size, 18, "BlackLabel18 font_size = 18")

func test_config_title_label_has_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "ConfigTitleLabel")
	assert_color_approx(color, Color(0.922, 0.875, 0.812, 1), "ConfigTitleLabel font_color")

func test_config_title_label_has_black_shadow() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var shadow: Color = theme.get_color("font_shadow_color", "ConfigTitleLabel")
	assert_color_approx(shadow, Color(0, 0, 0, 1), "ConfigTitleLabel font_shadow_color")

func test_config_title_label_has_size_20() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "ConfigTitleLabel")
	assert_eq(size, 20, "ConfigTitleLabel font_size = 20")

func test_config_title_label_has_shadow_offset() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var sx: int = theme.get_constant("shadow_offset_x", "ConfigTitleLabel")
	var sy: int = theme.get_constant("shadow_offset_y", "ConfigTitleLabel")
	assert_eq(sx, 0, "ConfigTitleLabel shadow_offset_x = 0")
	assert_eq(sy, 2, "ConfigTitleLabel shadow_offset_y = 2")

# stage_detail 区块标题（体力消耗/今日剩余/敌方阵容/可能获得，2026-07-17 立原名
# StageTitleLabel，批 3 Task 6 改名 StageSectionLabel——与 Task 5 stage_select 章节标题
# 撞名致后定义覆盖前定义，改名让位）。色/号不变。
func test_stage_section_label_has_section_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "StageSectionLabel")
	assert_color_approx(color, Color(0.945, 0.757, 0.443, 1), "StageSectionLabel font_color")

func test_stage_section_label_has_size_22() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "StageSectionLabel")
	assert_eq(size, 22, "StageSectionLabel font_size = 22")

# stage_select 章节标题（批 3 Task 5）：撞名修复后唯一定义生效，锁定源
# stageselect.lua createTitleText size18 ccc3(250,205,16) + shadow ccc3(63,5,0)。
func test_stage_title_label_has_gold_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "StageTitleLabel")
	assert_color_approx(color, Color(0.980392, 0.803922, 0.062745, 1), "StageTitleLabel font_color")

func test_stage_title_label_has_size_17() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "StageTitleLabel")
	assert_eq(size, 17, "StageTitleLabel font_size = 17（源 fontconfigs ui_normal_button，批3 批末勘误）")

func test_stage_title_label_has_shadow() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var shadow: Color = theme.get_color("font_shadow_color", "StageTitleLabel")
	assert_color_approx(shadow, Color(0.247059, 0.019608, 0, 1), "StageTitleLabel font_shadow_color")

# stage_detail 扫荡按钮三态（批 3 Task 6）：SB_sweep_n/p（tavern_button_normal cap 20,15,90,15）。
func test_stage_sweep_btn_normal_stylebox() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var sb: StyleBox = theme.get_stylebox("normal", "StageSweepBtn")
	assert_true(sb is StyleBoxTexture, "StageSweepBtn normal 是 StyleBoxTexture")
	var tex_sb: StyleBoxTexture = sb as StyleBoxTexture
	assert_ne(tex_sb.texture, null, "扫荡按钮 normal 有底图")
	assert_eq(tex_sb.texture.resource_path, "res://assets/ui/alpha/HVGA/tavern_button_normal_1.png", "normal 用 tavern_button_normal_1")
	var psb: StyleBox = theme.get_stylebox("pressed", "StageSweepBtn")
	assert_eq((psb as StyleBoxTexture).texture.resource_path, "res://assets/ui/alpha/HVGA/tavern_button_normal_2.png", "pressed 用 tavern_button_normal_2")

func test_warn_label_has_warn_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "WarnLabel")
	assert_color_approx(color, Color(0.572549, 0, 0.0156863, 1), "WarnLabel font_color")

func test_warn_label_has_size_18() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "WarnLabel")
	assert_eq(size, 18, "WarnLabel font_size = 18")

func test_info_line_label_has_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "InfoLineLabel")
	assert_color_approx(color, Color(0.858824, 0.768627, 0.494118, 1), "InfoLineLabel font_color")

func test_info_line_label_has_size_19() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "InfoLineLabel")
	assert_eq(size, 19, "InfoLineLabel font_size = 19")

func test_stage_number_label_has_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "StageNumberLabel")
	assert_color_approx(color, Color(0.961, 0.882, 0.745, 1), "StageNumberLabel font_color")

func test_stage_number_label_has_size_22() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "StageNumberLabel")
	assert_eq(size, 22, "StageNumberLabel font_size = 22")

func test_detail_base_label_has_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "DetailBaseLabel")
	assert_color_approx(color, Color(1, 0.918, 0.776, 1), "DetailBaseLabel font_color")

func test_detail_base_label_has_size_16() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "DetailBaseLabel")
	assert_eq(size, 16, "DetailBaseLabel font_size = 16")

func test_accent_gold_row_label_has_gold_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "AccentGoldRowLabel")
	assert_color_approx(color, Color(0.945, 0.757, 0.443, 1), "AccentGoldRowLabel font_color")

func test_accent_gold_row_label_has_size_16() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "AccentGoldRowLabel")
	assert_eq(size, 16, "AccentGoldRowLabel font_size = 16")

# ── 轮 4 新增 5 变体（完整签名断言，spec §1.1）──

func test_white_label_16_has_white_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "WhiteLabel16")
	assert_color_approx(color, Color(1, 1, 1, 1), "WhiteLabel16 font_color")

func test_white_label_16_has_size_16() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "WhiteLabel16")
	assert_eq(size, 16, "WhiteLabel16 font_size = 16")

func test_white_label_18_has_white_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "WhiteLabel18")
	assert_color_approx(color, Color(1, 1, 1, 1), "WhiteLabel18 font_color")

func test_white_label_18_has_size_18() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "WhiteLabel18")
	assert_eq(size, 18, "WhiteLabel18 font_size = 18")

func test_white_label_18_has_outline_2() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var outline: int = theme.get_constant("outline_size", "WhiteLabel18")
	assert_eq(outline, 2, "WhiteLabel18 outline_size = 2")

# WhiteLabel20 两用例已删（批 2 Task 2）：package tab label 迁往 PackageTabLabel 后
# WhiteLabel20 成孤儿 variation 同步删除（守卫规约 1，死用例随资源退役）。

func test_battle_prepare_tab_label_has_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "BattlePrepareTabLabel")
	assert_color_approx(color, Color(0.769, 0.733, 0.667, 1), "BattlePrepareTabLabel font_color")

func test_battle_prepare_tab_label_has_shadow() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var shadow: Color = theme.get_color("font_shadow_color", "BattlePrepareTabLabel")
	assert_color_approx(shadow, Color(0.165, 0.122, 0.086, 1), "BattlePrepareTabLabel font_shadow_color")

func test_battle_prepare_tab_label_has_size_20() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "BattlePrepareTabLabel")
	assert_eq(size, 20, "BattlePrepareTabLabel font_size = 20")

func test_battle_prepare_tab_label_has_shadow_offset() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var sx: int = theme.get_constant("shadow_offset_x", "BattlePrepareTabLabel")
	var sy: int = theme.get_constant("shadow_offset_y", "BattlePrepareTabLabel")
	assert_eq(sx, 0, "BattlePrepareTabLabel shadow_offset_x = 0")
	assert_eq(sy, 2, "BattlePrepareTabLabel shadow_offset_y = 2")

func test_stone_amount_label_has_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "StoneAmountLabel")
	assert_color_approx(color, Color(0.663, 0.357, 0.110, 1), "StoneAmountLabel font_color")

func test_stone_amount_label_has_size_16() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "StoneAmountLabel")
	assert_eq(size, 16, "StoneAmountLabel font_size = 16")


# ── 批4 Task 6 equipboard 两件套（源 board.lua + ofpackage.lua，2026-08-17）──

# 源 board.lua:323-337 name size24 ccc3(66,45,28) + shadow ccc3(0,0,0) offset(0,2)。
# 修复轮 D（2026-08-18）：字号 24 点×CS(1.28125)=31px（本 panel 布局常量全是"源点数×CS"口径如
# NAME_MAX_W 208=源 160 点，字号漏乘致 24px 字配 208px 框比例小 22% 观感发灰）+ 挂源字体。
func test_equipboard_name_label_style() -> void:
	var theme: Theme = ThemeManager.get_theme()
	assert_color_approx(theme.get_color("font_color", "EquipboardNameLabel"), Color(0.259, 0.176, 0.11, 1), "EquipboardNameLabel 棕 (66,45,28)")
	assert_eq(theme.get_font_size("font_size", "EquipboardNameLabel"), 31, "EquipboardNameLabel 31px（源 24 点×CS）")
	assert_eq(theme.get_font("font", "EquipboardNameLabel").resource_path, "res://resources/fonts/arial_unicode_ms.ttf", "挂源字体 arial_unicode_ms")
	assert_color_approx(theme.get_color("font_shadow_color", "EquipboardNameLabel"), Color(0, 0, 0, 1), "EquipboardNameLabel 影黑")
	assert_eq(theme.get_constant("shadow_offset_y", "EquipboardNameLabel"), 2, "影偏移 y=2（源有影，旧 tscn 漏）")

# 源 board.lua:55-70 amount_title size20 ccc3(67,59,56)。修复轮 D：20 点×CS=26px + 源字体。
func test_equipboard_have_label_size_20() -> void:
	var theme: Theme = ThemeManager.get_theme()
	assert_color_approx(theme.get_color("font_color", "EquipboardHaveLabel"), Color(0.263, 0.231, 0.22, 1), "EquipboardHaveLabel (67,59,56)")
	assert_eq(theme.get_font_size("font_size", "EquipboardHaveLabel"), 26, "EquipboardHaveLabel 26px（源 20 点×CS）")
	assert_eq(theme.get_font("font", "EquipboardHaveLabel").resource_path, "res://resources/fonts/arial_unicode_ms.ttf", "挂源字体")

# 源 board.lua:142-159 att size18 ccc3(64,63,63) + shadow(0,2)。修复轮 D：18 点×CS=23px + 源字体。
func test_equipboard_att_label_style() -> void:
	var theme: Theme = ThemeManager.get_theme()
	assert_color_approx(theme.get_color("font_color", "EquipboardAttLabel"), Color(0.251, 0.247, 0.247, 1), "EquipboardAttLabel 灰 (64,63,63)")
	assert_eq(theme.get_font_size("font_size", "EquipboardAttLabel"), 23, "EquipboardAttLabel 23px（源 18 点×CS）")
	assert_eq(theme.get_font("font", "EquipboardAttLabel").resource_path, "res://resources/fonts/arial_unicode_ms.ttf", "挂源字体")
	assert_color_approx(theme.get_color("font_shadow_color", "EquipboardAttLabel"), Color(0, 0, 0, 1), "EquipboardAttLabel 影黑")
	assert_eq(theme.get_constant("shadow_offset_y", "EquipboardAttLabel"), 2, "影偏移 y=2（源有影，旧 gd 漏）")

# 源 board.lua:206-238 fragment_title/amount size18 ccc3(66,45,28) + shadow(0,2)。修复轮 D：×CS=23px。
func test_equipboard_fragment_label_style() -> void:
	var theme: Theme = ThemeManager.get_theme()
	assert_color_approx(theme.get_color("font_color", "EquipboardFragmentLabel"), Color(0.259, 0.176, 0.11, 1), "EquipboardFragmentLabel 棕 (66,45,28)")
	assert_eq(theme.get_font_size("font_size", "EquipboardFragmentLabel"), 23, "EquipboardFragmentLabel 23px（源 18 点×CS）")
	assert_eq(theme.get_constant("shadow_offset_y", "EquipboardFragmentLabel"), 2, "影偏移 y=2")

# 源 ofpackage.lua:91-104 sell_number size18 ccc3(155,34,14)。修复轮 D：18 点×CS=23px + 源字体。
func test_equipboard_price_label_style() -> void:
	var theme: Theme = ThemeManager.get_theme()
	assert_color_approx(theme.get_color("font_color", "EquipboardPriceLabel"), Color(0.607843, 0.133333, 0.054902, 1), "EquipboardPriceLabel 红 (155,34,14)")
	assert_eq(theme.get_font_size("font_size", "EquipboardPriceLabel"), 23, "EquipboardPriceLabel 23px（源 18 点×CS）")

# 源 ofpackage.lua:140-152 按钮 label fontinfo ui_normal_button 白 + shadow ccc3(42,31,22) offset(0,2)。
# 修复轮 D：源字号修正——ofpackage base 无 size → readnode:342-346 取 fontInfo.size=17 点
# （fontconfigs.lua ui_normal_button，批 4 Task 6 记 20 系笔误）→ 17×CS≈22px。
func test_equipboard_btn_label_style() -> void:
	var theme: Theme = ThemeManager.get_theme()
	assert_color_approx(theme.get_color("font_color", "EquipboardBtnLabel"), Color(1, 1, 1, 1), "EquipboardBtnLabel 白")
	assert_eq(theme.get_font_size("font_size", "EquipboardBtnLabel"), 22, "EquipboardBtnLabel 22px（源 fontinfo 17 点×CS）")
	assert_color_approx(theme.get_color("font_shadow_color", "EquipboardBtnLabel"), Color(0.164706, 0.121569, 0.086275, 1), "EquipboardBtnLabel 影 (42,31,22)")
	assert_eq(theme.get_constant("shadow_offset_y", "EquipboardBtnLabel"), 2, "影偏移 y=2")

# 源 ofpackage.lua:108-135 Scale9 package_button cap(10,10,236,29)；pressed=package_button_down。
# 贴图 335×67（PIL 实测）→ margin L10/T28/R89/B10；content_margin 全 0 保按钮文字全 rect 居中。
func test_equipboard_btn_stylebox() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var sb: StyleBox = theme.get_stylebox("normal", "EquipboardBtn")
	assert_true(sb is StyleBoxTexture, "EquipboardBtn normal 是 StyleBoxTexture")
	var tex_sb: StyleBoxTexture = sb as StyleBoxTexture
	assert_eq(tex_sb.texture.resource_path, "res://assets/ui/alpha/HVGA/package_button.png", "normal 用 package_button")
	assert_eq(tex_sb.texture_margin_left, 10.0, "cap margin left=10")
	assert_eq(tex_sb.texture_margin_top, 28.0, "cap margin top=67-10-29=28（cap 顶/底反写）")
	assert_eq(tex_sb.texture_margin_right, 89.0, "cap margin right=335-10-236=89")
	assert_eq(tex_sb.texture_margin_bottom, 10.0, "cap margin bottom=10")
	assert_eq(tex_sb.content_margin_left, 0.0, "content_margin_left=0（cap 不对称防文字偏移）")
	assert_eq(tex_sb.content_margin_top, 0.0, "content_margin_top=0")
	var psb: StyleBox = theme.get_stylebox("pressed", "EquipboardBtn")
	assert_eq((psb as StyleBoxTexture).texture.resource_path, "res://assets/ui/alpha/HVGA/package_button_down.png", "pressed 用 package_button_down")
	var hsb: StyleBox = theme.get_stylebox("hover", "EquipboardBtn")
	assert_eq((hsb as StyleBoxTexture).texture.resource_path, "res://assets/ui/alpha/HVGA/package_button.png", "hover 同 normal")
