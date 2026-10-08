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


# 2026-10-08 红阶红框受控增强守卫：用户定案"橙色后面是红色"（源定制版 bf5c0cc 红阶只有红字
# 无红框资产，本项目自制 frame_13/card_bg_red）。橙阶 12-17 → 11、红阶 18-23 → 13；
# 名条源 name_frame_12 银白系（用户实测"进阶到顶名条变白"）退役不映射。
func test_red_rank_frames_18_to_23() -> void:
	for rank in range(18, 24):
		assert_eq(HeroDetailFills._name_frame_no(rank), 13, "名条 rank %d → frame_13 红款" % rank)
	assert_eq(HeroDetailFills._name_frame_no(17), 11, "名条 rank17 → frame_11 金（橙阶末档）")
	assert_eq(HeroDetailFills._name_frame_no(23), 13, "名条 rank23 满阶红（旧表 22 项缺末位致越界，2026-10-08 修）")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/herodetail_name_frame_13.png"), "名条红款资产存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/hero_icon_frame_13.png"), "头像框红款资产存在")
	assert_true(HeroDetailTabs._card_frame_res(18).contains("card_bg_red"), "卡片框 rank18 → red")
	assert_true(HeroDetailTabs._card_frame_res(17).contains("card_bg_orange"), "卡片框 rank17 → orange")
	assert_true(HeroDetailTabs._card_frame_res(23).contains("card_bg_red"), "卡片框 rank23 → red")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/card/card_bg_red.png"), "卡片红款资产存在")


# 2026-10-08 详情页"+N"后缀补译守卫（源 readhero.lua:939 createHeroNameByInfo heroStar 段）：
# 此前详情页只有纯名字；rank 23 满阶"红+5"用户实机找不到的根因之一（另一为 HERO_STAR 表 22 档）。
func test_name_suffix_filled_by_rank() -> void:
	var base: Control = load("res://scenes/ui/hero_detail_content.tscn").instantiate() as Control
	add_child_autofree(base)
	var cm: ConfigManager = ConfigManager.new()
	cm.load_all()
	var suffix: Label = base.get_node_or_null("%NameSuffix") as Label
	assert_not_null(suffix, "%NameSuffix 节点存在（tscn 静态）")
	if suffix == null:
		return
	# rank 23（Red+5 满阶）→ "+5" 红字；rank 1（White）→ 隐藏
	var hero_max := HeroInstance.new(1)
	hero_max.rank = 23
	HeroDetailFills.fill_name_board(base.get_node("%TypeIcon") as TextureRect, base.get_node("%NameLabel") as Label, base.get_node_or_null("%NameFrame") as TextureRect, hero_max, cm, suffix)
	assert_true(suffix.visible, "rank 23 后缀可见")
	assert_eq(suffix.text, "+5", "rank 23 → '+5'")
	assert_eq(suffix.get_theme_color("font_color"), ReadheroHandbook.NAME_COLOR_RED, "rank 23 后缀红字")
	var hero_min := HeroInstance.new(1)
	hero_min.rank = 1
	HeroDetailFills.fill_name_board(base.get_node("%TypeIcon") as TextureRect, base.get_node("%NameLabel") as Label, base.get_node_or_null("%NameFrame") as TextureRect, hero_min, cm, suffix)
	assert_false(suffix.visible, "rank 1 无后缀隐藏")
