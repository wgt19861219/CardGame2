extends GutTest

## HeroDetailFills 两件套范式守卫（2026-08-14）：builder 退役、纯 fill 定位、无样式 override。

func test_builder_renamed_to_fills() -> void:
	assert_false(ResourceLoader.exists("res://scripts/ui/hero_detail_builder.gd"), "hero_detail_builder.gd 已改名")
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_fills.gd")
	assert_true(text.find("class_name HeroDetailFills") != -1, "class_name HeroDetailFills")

func test_fills_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_fills.gd")
	assert_eq(text.count(".new()"), text.count("AtlasSprite.new()") + text.count("FcaAnimation.new()") + text.count("Node2D.new()") + text.count("TextureRect.new()"), "仅 FCA 立绘降级允许 .new()（动态内容）")

func test_panel_and_tabs_use_fills() -> void:
	var panel: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_panel.gd")
	assert_true(panel.find("HeroDetailBuilder") == -1, "panel 引用改名")
	var tabs: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_tabs.gd")
	assert_true(tabs.find("HeroDetailBuilder") == -1, "tabs 引用改名")

func test_skill_desc_capinsets_converted() -> void:
	## 技能说明框 capInsets 换算守卫（批 2 终审顺手修，批 1 漏网点）。
	## 源 skillstren.lua:20 capInsets = CCRectMake(20, 52, 200, 5)（左下原点），贴图 345x101，
	## 公式 L=x/T=H-y-h/R=W-x-w/B=y → 20/44/125/52（禁止回退为源值直传 20/52/200/5）。
	var tabs: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_tabs.gd")
	assert_true(tabs.contains("patch_margin_left = 20"), "margin_left 须为 20")
	assert_true(tabs.contains("patch_margin_top = 44"), "margin_top 须为 44（=101-52-5，源值直传 52 是未换算）")
	assert_true(tabs.contains("patch_margin_right = 125"), "margin_right 须为 125（=345-20-200，源值直传 200 是未换算）")
	assert_true(tabs.contains("patch_margin_bottom = 52"), "margin_bottom 须为 52（=源 y）")
