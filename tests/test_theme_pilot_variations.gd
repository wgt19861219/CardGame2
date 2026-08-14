extends GutTest

## 试点新增 theme variation 回归（两件套 SOP 依赖，防误删/误改）。

const THEME_PATH: String = "res://resources/themes/default_theme.tres"


func _theme() -> Theme:
	return load(THEME_PATH) as Theme


func test_shop_label_variations_exist() -> void:
	var t: Theme = _theme()
	for v in ["ShopTitleLabel", "ShopCostLabel", "ShopTalkLabel", "ShopTimeLabel"]:
		assert_true(v in t.get_type_variation_list("Label"), "%s 应注册为 Label variation" % v)


func test_shop_label_sizes() -> void:
	var t: Theme = _theme()
	assert_eq(t.get_font_size("font_size", "ShopTitleLabel"), 24, "标题 24（shop_content.tscn 原 override 值）")
	assert_eq(t.get_font_size("font_size", "ShopCostLabel"), 14, "刷新花费 14")
	assert_eq(t.get_font_size("font_size", "ShopTalkLabel"), 16, "NPC 对话 16")
	assert_eq(t.get_font_size("font_size", "ShopTimeLabel"), 13, "刷新时刻 13")


func test_hero_detail_button_variations_exist() -> void:
	var t: Theme = _theme()
	for v in ["HeroDetailTab", "HeroDetailTabActive"]:
		assert_true(v in t.get_type_variation_list("Button"), "%s 应注册为 Button variation" % v)


func test_hero_detail_tab_styleboxes_set() -> void:
	var t: Theme = _theme()
	assert_not_null(t.get_stylebox("normal", "HeroDetailTab"), "Tab normal=detail-n")
	assert_not_null(t.get_stylebox("pressed", "HeroDetailTab"), "Tab pressed=detail-pressed-n")
	assert_not_null(t.get_stylebox("normal", "HeroDetailTabActive"), "选中态 normal=detail-a")


func test_hero_detail_tab_label_variation() -> void:
	var t: Theme = _theme()
	assert_true("HeroDetailTabLabel" in t.get_type_variation_list("Label"), "HeroDetailTabLabel 注册")
	assert_ne(t.get_color("font_color", "HeroDetailTabLabel"), Color.WHITE, "黑字（源按钮文字 BLACK）")
