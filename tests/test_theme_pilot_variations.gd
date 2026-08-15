extends GutTest

## 试点新增 theme variation 回归（两件套 SOP 依赖，防误删/误改）。

const THEME_PATH: String = "res://resources/themes/default_theme.tres"


func _theme() -> Theme:
	return load(THEME_PATH) as Theme


func test_shop_label_variations_exist() -> void:
	var t: Theme = _theme()
	for v in ["ShopTitleLabel", "ShopTalkLabel", "ShopTimeLabel", "ShopItemNameLabel", "ShopItemPriceLabel"]:
		assert_true(v in t.get_type_variation_list("Label"), "%s 应注册为 Label variation" % v)
	assert_false("ShopCostLabel" in t.get_type_variation_list("Label"), "ShopCostLabel 已删（Task 5 三轮：源无刷新花费 label）")


func test_shop_label_sizes() -> void:
	var t: Theme = _theme()
	assert_eq(t.get_font_size("font_size", "ShopTitleLabel"), 24, "标题 24（shop_content.tscn 原 override 值）")
	assert_eq(t.get_font_size("font_size", "ShopTalkLabel"), 20, "NPC 对话 20（源 shop.lua size 20）")
	assert_eq(t.get_font_size("font_size", "ShopTimeLabel"), 16, "刷新时刻 16（源 time label 16）")
	assert_eq(t.get_font_size("font_size", "ShopItemNameLabel"), 20, "商品名 20（源 size 20）")
	assert_eq(t.get_font_size("font_size", "ShopItemPriceLabel"), 20, "商品价格 20（源 size 20）")


func test_hero_detail_button_variations_exist() -> void:
	var t: Theme = _theme()
	for v in ["HeroDetailTab", "HeroDetailTabActive"]:
		assert_true(v in t.get_type_variation_list("Button"), "%s 应注册为 Button variation" % v)


func test_hero_detail_tab_styleboxes_set() -> void:
	var t: Theme = _theme()
	_assert_detail_stylebox(t.get_stylebox("normal", "HeroDetailTab"), "Tab normal=detail-n")
	_assert_detail_stylebox(t.get_stylebox("pressed", "HeroDetailTab"), "Tab pressed=detail-pressed-n")
	_assert_detail_stylebox(t.get_stylebox("normal", "HeroDetailTabActive"), "选中态 normal=detail-a")


## 锁实测值：类型 + texture + margins。assert_not_null 会命中 Godot theme fallback
## （未注册回落 StyleBoxEmpty 非 null），无防护力，故必须锁死具体类型与数值
## （margins 依据 herodetail-detail-*.png 219×67、cap 15,15,138,19 实测推导，
## cap 左下原点 → top=H-y-h=33 / bottom=y=15，批 1 终审必修 1 修正垂直互换）。
func _assert_detail_stylebox(sb: StyleBox, label: String) -> void:
	assert_true(sb is StyleBoxTexture, "%s 应为 StyleBoxTexture（防 fallback 空 box 蒙混）" % label)
	if not (sb is StyleBoxTexture):
		return
	var sbt := sb as StyleBoxTexture
	assert_not_null(sbt.texture, "%s texture 非空" % label)
	assert_eq(sbt.texture_margin_left, 15.0, "%s margin_left=15（cap x）" % label)
	assert_eq(sbt.texture_margin_top, 33.0, "%s margin_top=33（67-15-19）" % label)
	assert_eq(sbt.texture_margin_right, 66.0, "%s margin_right=66（219-15-138）" % label)
	assert_eq(sbt.texture_margin_bottom, 15.0, "%s margin_bottom=15（cap y）" % label)


func test_hero_detail_tab_label_variation() -> void:
	var t: Theme = _theme()
	assert_true("HeroDetailTabLabel" in t.get_type_variation_list("Label"), "HeroDetailTabLabel 注册")
	assert_eq(t.get_color("font_color", "HeroDetailTabLabel"), Color(0, 0, 0, 1), "黑字（源按钮文字 BLACK）")
	assert_eq(t.get_color("font_outline_color", "HeroDetailTabLabel"), Color(1, 1, 1, 1), "白描边（源按钮描边 WHITE）")
	assert_eq(t.get_constant("outline_size", "HeroDetailTabLabel"), 2, "描边宽 2")


func test_hero_detail_content_uses_variations() -> void:
	var content: Control = (load("res://scenes/ui/hero_detail_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var base: Control = content.get_node("%BaseLayer")
	for btn_name in ["TabDetailBtn", "TabCardBtn", "TabSkillBtn", "UpgradeRankBtn"]:
		var btn: Button = base.get_node("%" + btn_name) as Button
		assert_eq(String(btn.theme_type_variation), "HeroDetailTab", "%s 走 HeroDetailTab variation" % btn_name)
	var tab_label: Label = base.get_node("%TabDetailBtn/%TabDetailLabel") as Label
	assert_eq(String(tab_label.theme_type_variation), "HeroDetailTabLabel", "tab 文字走 HeroDetailTabLabel")
	content.free()


func test_hero_detail_fills_style_code_retired() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_fills.gd")
	for dead in ["_apply_detail_style", "_make_stylebox", "_make_tab_stylebox", "add_theme_stylebox_override"]:
		assert_true(text.find(dead) == -1, "%s 已退役（样式进 theme/tscn）" % dead)
