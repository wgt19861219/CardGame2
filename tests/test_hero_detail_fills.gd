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
