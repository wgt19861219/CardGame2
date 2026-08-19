extends GutTest
# Spine atlas 纹理 y 翻转守卫（2026-08-19 主城建筑 180° 颠倒修复）。
# 根因：Spine y-up 纹理约定下，SpineSkeleton 根部 scale.y=-1 镜像骨骼树会翻转纹理，
# atlas 提取未预翻补偿，致主城 13/14 建筑上下颠倒（orient_check 实测）。
# 修复：非 rotate region 提取时 flip_y；rotate region 保持旧行为（rotate_90 转正，
# Pve/Mailbox 主贴图修复前视觉正立，保守不动）。

const GuildAtlas = preload("res://scripts/ui/spine_atlas.gd")


func _guild_atlas() -> GuildAtlas:
	var atlas := GuildAtlas.new()
	assert_true(atlas.load_atlas("res://assets/spine/eff_UI_Main_Guild/eff_UI_Main_Guild.atlas"), "load_atlas 成功")
	return atlas


func test_plain_region_texture_flipped() -> void:
	# 非 rotate 主贴图（eff_UI_Main_Guild 196×187）：提取纹理第 k 行像素 == 原区倒数第 k+1 行。
	# 取内容列判定（贴图边缘全透明会让首末行退化相同）
	var atlas := _guild_atlas()
	var tex: Texture2D = atlas.get_region_texture("eff_UI_Main_Guild")
	assert_not_null(tex, "region 纹理存在")
	var sheet: Image = load("res://assets/spine/eff_UI_Main_Guild/eff_UI_Main_Guild.png").get_image()
	# region xy(2,2) size(196,187) 左下原点 → sheet 像素区行 [H-189, H-2)
	var y_top_row: int = sheet.get_height() - 2 - 187   # 区域最上行（sheet 坐标）
	var y_bot_row: int = sheet.get_height() - 2 - 1     # 区域最下行
	var tex_img: Image = tex.get_image()
	var checked: int = 0
	# 纹理第 k 行 ↔ 原区倒数第 k+1 行（sheet 行 y_bot_row - k）。扫描中部行对找有效样本
	for k in [3, 30, 60, 90, 120, 150, 183]:
		var row_a: Color = tex_img.get_pixel(98, k)
		var row_b: Color = sheet.get_pixel(2 + 98, y_bot_row - k)
		var row_unflipped: Color = sheet.get_pixel(2 + 98, y_top_row + k)
		if row_b.a < 0.05:
			continue
		assert_eq(row_a, row_b, "纹理行 k=%d=原区镜像行（已翻转）" % k)
		if row_unflipped != row_b:
			assert_ne(row_a, row_unflipped, "纹理行 k=%d≠原区同位行（未翻转即回归）" % k)
			checked += 1
	assert_gt(checked, 0, "至少一行完成非翻转回归判定（否则样本无效）")


func test_skeleton_main_sprite_world_oriented_upright() -> void:
	# 端到端守卫：Shop2 主贴图（非 rotate）挂 root 骨骼（rot 0），骨骼树镜像后
	# "原图顶部"（flip 后位于局部 +y）世界 y 必须小于底部——上下颠倒回归即失败
	var sk := SpineSkeleton.new()
	add_child(sk)
	assert_true(sk.load_skeleton("res://assets/spine/eff_UI_Main_Shop2", "eff_UI_Main_Shop2"))
	sk._apply(0.0)
	var best: Sprite2D = null
	var best_area: float = 0.0
	for e in sk._slot_sprites:
		var sp: Sprite2D = e["sprite"]
		if sp.texture != null and sp.texture.get_width() * sp.texture.get_height() > best_area:
			best_area = sp.texture.get_width() * sp.texture.get_height()
			best = sp
	assert_not_null(best, "主贴图 sprite 存在")
	var gt: Transform2D = best.get_global_transform()
	var th: float = best.texture.get_height() / 2.0
	var top_world: Vector2 = gt * Vector2(0.0, th)    # flip 后原图顶部在局部 +y
	var bot_world: Vector2 = gt * Vector2(0.0, -th)
	assert_lt(top_world.y, bot_world.y, "主贴图正立（原图顶部世界 y 更小）")
	sk.queue_free()
