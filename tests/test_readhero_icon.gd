extends GutTest
# Phase 4 readhero createIcon 头像系统测试（2026-07-02）。
# 验 ReadheroIcon：Portrait 加载（tid→Unit.Portrait→HERO/xx.jpg）/ clipping shader 应用 /
#   frame 选档（rank→hero_icon_frame_N，照源 frames 表）/ stars 拼接 / isHideFrame / level / id==0 unknow。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func after_all() -> void:
	UnitSprite.clear_atlas_cache()


# 源 :343-349 — tid=1 Coco → Portrait "UI/HERO/Coco.jpg" 加载 + clipping shader。
func test_icon_loads_portrait() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1, "stars": 0}, cm)
	assert_not_null(icon.ori_icon, "ori_icon 创建")
	var sprite: Sprite2D = icon.ori_icon as Sprite2D
	assert_not_null(sprite, "id>0 → ori_icon 是 Sprite2D")
	if sprite != null:
		assert_not_null(sprite.texture, "Portrait 加载（Coco.jpg）")
	icon.queue_free()


func test_icon_applies_clip_shader() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1}, cm)
	var sprite: Sprite2D = icon.ori_icon as Sprite2D
	assert_not_null(sprite, "ori_icon Sprite2D")
	if sprite != null:
		var mat: Material = sprite.material
		assert_not_null(mat, "ori_icon 挂 mask material（源 createClippingNode）")
		assert_true(mat is ShaderMaterial, "material 是 ShaderMaterial")
		if mat is ShaderMaterial:
			assert_eq((mat as ShaderMaterial).shader, preload("res://shaders/portrait_mask.gdshader"), "shader = portrait_mask")
	icon.queue_free()


# 源 player.lua:2090-2114 frames 表 + getIconFrameByRank。
func test_frame_id_by_rank() -> void:
	assert_eq(ReadheroIcon._frame_id_by_rank(1), 1, "rank1 → frame_1")
	assert_eq(ReadheroIcon._frame_id_by_rank(5), 5, "rank5 → frame_5")
	assert_eq(ReadheroIcon._frame_id_by_rank(10), 10, "rank10 → frame_10")
	assert_eq(ReadheroIcon._frame_id_by_rank(11), 10, "rank11 → frame_10（源 frames 重复）")
	assert_eq(ReadheroIcon._frame_id_by_rank(12), 11, "rank12 → frame_11")
	assert_eq(ReadheroIcon._frame_id_by_rank(20), 11, "rank20 → frame_11")
	assert_eq(ReadheroIcon._frame_id_by_rank(21), 12, "rank21 → frame_12")
	assert_eq(ReadheroIcon._frame_id_by_rank(25), 1, "越界 → frame_1 默认")


# 源 :367-371 frame 装配（texture = hero_icon_frame_N）。
func test_icon_frame_texture_by_rank() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1, "rank": 5}, cm)
	assert_not_null(icon.frame, "rank=5 → frame 创建")
	if icon.frame != null and icon.frame.texture != null:
		var path: String = icon.frame.texture.resource_path
		assert_true(path.find("hero_icon_frame_5") >= 0, "rank5 → frame_5.png 贴图")
	icon.queue_free()


# 源 :391-398 stars 拼接（i 从 star_count 倒序到 1）。
func test_icon_stars_count() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1, "stars": 3}, cm)
	assert_eq(icon.stars.size(), 3, "stars=3 → 3 star sprites")
	icon.queue_free()


# 源 :372-374 isHideFrame → frame:setVisible(false)（hero_panel 模式）。
func test_icon_hide_frame() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1, "isHideFrame": true}, cm)
	assert_eq(icon.frame.visible, false, "isHideFrame=true → frame.visible=false（源 :373）")
	icon.queue_free()
	var icon2 := ReadheroIcon.new()
	icon2.setup({"id": 1, "isHideFrame": false}, cm)
	assert_eq(icon2.frame.visible, true, "默认 frame 可见")
	icon2.queue_free()


# 源 :355-366 level：heropackage_level_bg + levelLabel。
func test_icon_level_label() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1, "level": 10}, cm)
	var lbl: Label = null
	for c in icon.icon.get_children():
		if c is Label:
			lbl = c
			break
	assert_not_null(lbl, "level label 创建（源 :361）")
	if lbl != null:
		assert_eq(lbl.text, "10", "level label 显 '10'")
	icon.queue_free()


# 源 :330-341 id==0 → 黑底 CCLayerColor + unknow 占位。
func test_icon_id_zero_unknow() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 0}, cm)
	var has_color_rect: bool = false
	for c in icon.ori_icon.get_children():
		if c is ColorRect:
			has_color_rect = true
			break
	assert_true(has_color_rect, "id=0 → unknow 黑底 ColorRect（源 :334）")
	icon.queue_free()


# 源 createIconByHero :465 — hero→info 包装 createIcon。
func test_create_icon_by_hero() -> void:
	var hero := HeroInstance.new(1, 1, 1)   # tid=1 Coco stars=1
	hero.level = 1
	hero.rank = 5
	var icon := ReadheroIcon.create_icon_by_hero(hero, cm)
	assert_not_null(icon, "create_icon_by_hero 创建")
	assert_not_null(icon.frame, "rank=5 → frame 装配")
	if icon.frame != null and icon.frame.texture != null:
		assert_true(icon.frame.texture.resource_path.find("hero_icon_frame_5") >= 0, "hero.rank=5 → frame_5（包装传 rank）")
	icon.queue_free()


# ===== hp/mp 血条（源 readhero.lua:266-305 addHpInfo，2026-07-05 stagedone hp 视觉补全）=====

# 源 :281-289 hp>0 画 hp 血条（bg + bar，bar scaleX = hp/10000）。
# 2026-08-19：显示尺寸 ÷CS（CONTENT_SCALE，源 createSprite 等价）——scale = (perc, 1)/CS，
# 修前原尺寸显示致血/蓝条高 10 > 中心距 7 互相叠 3px（源 7.8 高仅微叠 0.8 点不可见）。
func test_icon_hp_bar_drawn() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1, "hp": 5000}, cm)   # hp=5000 万分比 = 50%
	var hp_bar: Sprite2D = _find_sprite_by_texture(icon, "crusade_hp_bar.png")
	assert_not_null(hp_bar, "hp=5000 → hp bar 画（源 :282）")
	if hp_bar != null:
		assert_true(abs(hp_bar.scale.x - 0.5 / ReadheroIcon.CONTENT_SCALE) < 0.01,
			"hp bar scaleX = (hp/10000)/CS（源 :289 × ÷CS 口径）")
	icon.queue_free()


# 血/蓝条显示高 = 贴图高(10)÷CS ≈ 7.8px，中心距 7 → 互叠 ≤0.8px（源等价；回归守卫）。
func test_icon_bars_display_height_no_overlap() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1, "hp": 10000, "mp": 10000}, cm)
	var hp_bar: Sprite2D = _find_sprite_by_texture(icon, "crusade_hp_bar.png")
	var mp_bar: Sprite2D = _find_sprite_by_texture(icon, "crusade_mp_bar.png")
	if hp_bar != null and mp_bar != null:
		assert_true(abs(hp_bar.scale.y - 1.0 / ReadheroIcon.CONTENT_SCALE) < 0.001,
			"条 scale.y = 1/CS（÷CS 显示口径）")
		var overlap: float = 10.0 / ReadheroIcon.CONTENT_SCALE - abs(hp_bar.position.y - mp_bar.position.y)
		assert_lt(overlap, 1.0, "显示高7.8-中心距7 → 互叠 0.8px ≤1（源等价；修前原尺寸叠 3px 此断言红）")
	icon.queue_free()


# 源 :290-300 mp 血条（hp + mp 都传才画）。
func test_icon_mp_bar_drawn() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1, "hp": 5000, "mp": 3000}, cm)
	assert_not_null(_find_sprite_by_texture(icon, "crusade_mp_bar.png"), "hp+mp → mp bar 画（源 :292）")
	icon.queue_free()


# 源 :272-279 hp<=0 死亡标识（黑 shade alpha 150，dead 图缺失降级 shade only）。
func test_icon_hp_zero_dead_shade() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1, "hp": 0}, cm)   # hp=0 死亡
	var has_shade: bool = false
	for c in icon.icon.get_children():
		if c is ColorRect and abs((c as ColorRect).color.a - 150.0 / 255.0) < 0.01:
			has_shade = true
			break
	assert_true(has_shade, "hp=0 → 死亡 shade（ColorRect alpha 150，源 :277）")
	icon.queue_free()


# 源 :271 hp==nil 守卫 → 不画血条（hero_panel 用 readhero.createIcon 不传 hp）。
func test_icon_hp_null_no_bar() -> void:
	var icon := ReadheroIcon.new()
	icon.setup({"id": 1}, cm)   # 不传 hp
	assert_null(_find_sprite_by_texture(icon, "crusade_hp_bar.png"), "hp=nil → 不画 hp bar（源 :271 守卫）")
	icon.queue_free()


func _find_sprite_by_texture(icon: ReadheroIcon, tex_name: String) -> Sprite2D:
	for c in icon.icon.get_children():
		if c is Sprite2D:
			var s: Sprite2D = c as Sprite2D
			if s.texture != null and s.texture.resource_path.find(tex_name) >= 0:
				return s
	return null
