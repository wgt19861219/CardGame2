extends GutTest

## HeroDetailFills 两件套范式守卫（2026-08-14）：builder 退役、纯 fill 定位、无样式 override。

func test_builder_renamed_to_fills() -> void:
	assert_false(ResourceLoader.exists("res://scripts/ui/hero_detail_builder.gd"), "hero_detail_builder.gd 已改名")
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_fills.gd")
	assert_true(text.find("class_name HeroDetailFills") != -1, "class_name HeroDetailFills")

func test_fills_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_fills.gd")
	assert_eq(text.count(".new()"), text.count("AtlasSprite.new()") + text.count("FcaAnimation.new()") + text.count("Node2D.new()") + text.count("TextureRect.new()") + text.count("AtlasTexture.new("), "仅 FCA 立绘降级/动态纹理允许 .new()")

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
	assert_true(tabs.contains("patch_margin_left = 16"), "margin_left 须为 16（÷CS）")
	assert_true(tabs.contains("patch_margin_top = 34"), "margin_top 须为 34（=44 纹理px ÷CS）")
	assert_true(tabs.contains("patch_margin_right = 98"), "margin_right 须为 98（=125 纹理px ÷CS）")
	assert_true(tabs.contains("patch_margin_bottom = 41"), "margin_bottom 须为 41（=52 纹理px ÷CS）")


# 2026-09-10 根修守卫：详情页魂石进度条纹理照源 ClippingNode 裁剪语义走 AtlasTexture 截取。
# 源头：SCALE 整条压缩把条左端 13px 透明带随 ratio 压小（条内容起点左移），而框 NinePatch 左
# patch 恒显示 ~14.1 点——比例越小条内容越画出框左圆头外（用户实拍：魂石 1 时条整体在框左边、
# 20/100 时条压框左圆头 11.8 点）。region 与 rect 同乘 ratio → 压缩比恒 = 框，任意比例恒同位。
func test_fill_stone_bar_texture_region_follows_ratio() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	var base: Control = load("res://scenes/ui/hero_detail_content.tscn").instantiate() as Control
	add_child_autofree(base)
	var cm: ConfigManager = ConfigManager.new()
	cm.load_all()
	var mgr := HeroManager.new(cm)
	var sid: int = ReadheroHandbook.get_stone_id(int(hero.tid), cm)
	var need: int = ReadheroHandbook.get_stone_need(int(hero.tid), cm, mgr)
	mgr.add_fragment(sid, maxi(1, int(need / 2)))
	var bar: TextureRect = base.get_node("%StoneBar") as TextureRect
	HeroDetailFills.fill_stone_bar(base, hero, cm, mgr)
	var ratio: float = float(ReadheroHandbook.get_stone_amount(int(hero.tid), cm, mgr)) / float(need)
	assert_true(bar.texture is AtlasTexture, "部分进度纹理走 AtlasTexture 截取（照源 ClippingNode 语义）")
	if bar.texture is AtlasTexture:
		var at: AtlasTexture = bar.texture as AtlasTexture
		assert_almost_eq(at.region.size.x, 204.0 * ratio, 0.01, "region 宽=源纹理宽×sa/sn")
		assert_eq(at.region.position.x, 0.0, "region 从纹理左端截取")
	assert_almost_eq(bar.offset_right - 256.5, 180.0 * ratio, 0.01, "rect 宽=框宽×sa/sn")
