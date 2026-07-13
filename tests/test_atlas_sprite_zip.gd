extends GutTest
# AtlasSprite.load_atlas_from_ani 测试（解锁 effect FCA atlas zip 加载，Task #14）。

const CHEST_ANI: String = "res://assets/anim_frames/effect/eff_UI_tarven_open_chest.ani"


func test_load_atlas_from_ani() -> void:
	var atlas := AtlasSprite.new()
	assert_true(atlas.load_atlas_from_ani(CHEST_ANI), "加载 .ani zip atlas")
	assert_true(atlas.is_loaded(), "is_loaded")
	assert_gt(atlas.get_part_names().size(), 0, "解析到散件")


func test_load_atlas_from_ani_missing() -> void:
	var atlas := AtlasSprite.new()
	assert_false(atlas.load_atlas_from_ani("res://nonexist.ani"), "不存在 .ani → false")
	assert_false(atlas.is_loaded(), "未加载")
