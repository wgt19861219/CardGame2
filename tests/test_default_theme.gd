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

func test_stage_title_label_has_gold_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "StageTitleLabel")
	assert_color_approx(color, Color(0.945, 0.757, 0.443, 1), "StageTitleLabel font_color")

func test_stage_title_label_has_size_22() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "StageTitleLabel")
	assert_eq(size, 22, "StageTitleLabel font_size = 22")

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
