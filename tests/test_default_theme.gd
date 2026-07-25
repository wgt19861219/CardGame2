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

func test_title_label_has_gold_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "TitleLabel")
	assert_eq(color, UIConstants.COLOR_TITLE_GOLD, "TitleLabel font_color = COLOR_TITLE_GOLD")

func test_title_label_has_title_size() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "TitleLabel")
	assert_eq(size, UIConstants.FONT_SIZE_TITLE, "TitleLabel font_size = FONT_SIZE_TITLE (20)")


func test_body_label_has_white_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "BodyLabel")
	assert_eq(color, UIConstants.COLOR_TEXT_DEFAULT, "BodyLabel font_color = COLOR_TEXT_DEFAULT (白)")

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
	assert_eq(color, UIConstants.COLOR_TEXT_DEFAULT, "BodyLabelThin font_color = 白")


func test_shadowed_label_has_shadow_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_shadow_color", "ShadowedLabel")
	assert_eq(color, UIConstants.COLOR_TEXT_SHADOW, "ShadowedLabel font_shadow_color = COLOR_TEXT_SHADOW (黑)")

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
	assert_eq(color, UIConstants.COLOR_AMOUNT, "AmountLabel font_color = COLOR_AMOUNT")

func test_amount_label_has_amount_size() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_font_size("font_size", "AmountLabel")
	assert_eq(size, UIConstants.FONT_SIZE_AMOUNT, "AmountLabel font_size = FONT_SIZE_AMOUNT (18)")

func test_btn_label_has_btn_label_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "BtnLabel")
	assert_eq(color, UIConstants.COLOR_BTN_LABEL, "BtnLabel font_color = COLOR_BTN_LABEL")

func test_btn_label_has_btn_outline_size() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var size: int = theme.get_constant("outline_size", "BtnLabel")
	assert_eq(size, UIConstants.OUTLINE_SIZE_BTN, "BtnLabel outline_size = OUTLINE_SIZE_BTN (2)")


func test_dialog_label_has_white_color() -> void:
	var theme: Theme = ThemeManager.get_theme()
	var color: Color = theme.get_color("font_color", "DialogLabel")
	assert_eq(color, UIConstants.COLOR_TEXT_DEFAULT, "DialogLabel font_color = 白")

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
