extends GutTest
# SpineAtlas 解析测试（Spine 2.1.07 .atlas 文本格式）。资源 eff_UI_Main_Shop。

const SPINE_ATLAS_PATH: String = "res://assets/spine/eff_UI_Main_Shop/eff_UI_Main_Shop.atlas"


func test_load_atlas_regions() -> void:
	var atlas := SpineAtlas.new()
	assert_true(atlas.load_atlas(SPINE_ATLAS_PATH), "load .atlas 成功")
	assert_true(atlas.is_loaded(), "is_loaded")
	assert_true(atlas.has_region("eff_UI_Main_Shop"), "region eff_UI_Main_Shop")
	assert_true(atlas.has_region("eff_UI_Main_Shop_1"), "region eff_UI_Main_Shop_1")
	assert_true(atlas.has_region("eff_UI_Main_Shop_Light"), "region eff_UI_Main_Shop_Light")


func test_region_size() -> void:
	var atlas := SpineAtlas.new()
	atlas.load_atlas(SPINE_ATLAS_PATH)
	var sz: Vector2 = atlas.get_region_size("eff_UI_Main_Shop")
	assert_eq(sz, Vector2(188.0, 161.0), "shop region 188x161")
	var light_sz: Vector2 = atlas.get_region_size("eff_UI_Main_Shop_Light")
	assert_eq(light_sz, Vector2(30.0, 29.0), "light region 30x29")


func test_region_texture_extracted() -> void:
	var atlas := SpineAtlas.new()
	atlas.load_atlas(SPINE_ATLAS_PATH)
	var tex: Texture2D = atlas.get_region_texture("eff_UI_Main_Shop")
	assert_not_null(tex, "shop region 纹理提取")
	if tex != null:
		assert_eq(tex.get_width(), 188, "纹理宽 188")
		assert_eq(tex.get_height(), 161, "纹理高 161")


func test_missing_region_returns_null() -> void:
	var atlas := SpineAtlas.new()
	atlas.load_atlas(SPINE_ATLAS_PATH)
	assert_null(atlas.get_region_texture("nonexistent"), "不存在 region 返 null")


# 最大 region 静态图（照源 createStaticSpriteFromSpineAtlas 取最大 area region）。
func test_largest_region_texture() -> void:
	var atlas := SpineAtlas.new()
	atlas.load_atlas(SPINE_ATLAS_PATH)
	var tex: Texture2D = atlas.get_largest_region_texture()
	assert_not_null(tex, "最大 region 纹理非 null")
	if tex != null:
		# 最大 region 是主图标 eff_UI_Main_Shop 188x161（Light 30x29 远小）
		assert_eq(tex.get_width(), 188, "最大 region 宽 188")
		assert_eq(tex.get_height(), 161, "最大 region 高 161")
