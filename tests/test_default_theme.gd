extends GutTest
## 验证 default_theme.tres 被正确加载，且覆盖核心控件类型（Button/Label）。
## TDD Task 3：先红（ThemeManager 不存在）后绿（建 Theme + Manager）。
## 渐进策略：Label font_size/color/outline + 容器 separation + Button 空 stylebox 骨架；
## Button 纹理(59 处散落)留 Task 4 试点 + 后续批次逐步归纳。

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
