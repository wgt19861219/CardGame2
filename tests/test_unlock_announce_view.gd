extends GutTest
# Step 4 unlock 公告 View 测试：UNLOCK_STEP_CONFIG 数据完整性 + UnlockAnnounceView 装配（icon 静态图 + fca atlas 静态图）。

# UNLOCK_STEP_CONFIG 15 step 配置完整性（照 tutorialres:809-1005）。
func test_unlock_step_config_all_15() -> void:
	assert_eq(TutorialData.UNLOCK_STEP_CONFIG.size(), 15, "15 unlock step 配置")
	# UNLOCK_STEPS（15 StringName）与 UNLOCK_STEP_CONFIG key 一致
	for step in TutorialData.UNLOCK_STEPS:
		var cfg: Dictionary = TutorialData.get_unlock_config(step)
		assert_false(cfg.is_empty(), "%s 有配置" % String(step))
		assert_true(cfg.has("text"), "%s 有 text" % String(step))


func test_unlock_step_config_icon_vs_fca() -> void:
	# 4 个 icon step（unlockSkillUpgrade/EliteMode/Midas/WorldChannel），其余 11 fca
	var icon_cfg: Dictionary = TutorialData.get_unlock_config(&"unlockSkillUpgrade")
	assert_true(icon_cfg.has("icon"), "unlockSkillUpgrade 用 icon_res")
	var fca_cfg: Dictionary = TutorialData.get_unlock_config(&"unlockShop")
	assert_true(fca_cfg.has("fca_res"), "unlockShop 用 fca_res")
	assert_false(fca_cfg.has("icon"), "unlockShop 无 icon（fca step）")


# UnlockAnnounceView.show_step 装配 panel（bg+light+label，icon step 额外 icon TextureRect）。
func test_show_step_icon_assembles() -> void:
	var view := UnlockAnnounceView.new()
	view.show_step(&"unlockSkillUpgrade", self)
	assert_not_null(view._panel, "panel 已建")
	assert_not_null(view._light, "light 已建")
	# icon_res step：bg + light + icon = 3 TextureRect
	assert_eq(_count_texture_rect(view._panel), 3, "icon step: bg+light+icon 3 TextureRect")
	# label 文本照配置
	var label: Label = _find_label(view._panel)
	assert_not_null(label, "label 已建")
	assert_eq(label.text, "Unlocked skills enhancement", "label 文案照 UNLOCK_STEP_CONFIG")
	view.queue_free()


# fca_res step 照源 atlas 静态图（createStaticSpriteFromSpineAtlas 最大 region）：
# eff_UI_Main_Shop 等 10 个 Spine 资源 atlas 加载成功 → bg+light+static = 3 TextureRect。
func test_show_step_fca_assembles_static() -> void:
	var view := UnlockAnnounceView.new()
	view.show_step(&"unlockShop", self)
	assert_not_null(view._panel, "panel 已建")
	assert_eq(_count_texture_rect(view._panel), 3, "fca step: bg+light+static 3 TextureRect")
	view.queue_free()


# Shop_Star（unlockStarShop）本项目 spine/ 无资源（FCA .abc 在 anim_frames/effect/，未移植）→
# atlas 加载失败降级：bg+light = 2 TextureRect（源走 FCA .abc，本项目 LegendAminationEffect 未移植）。
func test_show_step_shop_star_degraded() -> void:
	var view := UnlockAnnounceView.new()
	view.show_step(&"unlockStarShop", self)
	assert_not_null(view._panel, "panel 已建")
	assert_eq(_count_texture_rect(view._panel), 2, "Shop_Star 降级: bg+light 2 TextureRect")
	view.queue_free()


# 未配置的 step 不崩（show_step 早返 + queue_free）。
func test_show_step_unknown_step_safe() -> void:
	var view := UnlockAnnounceView.new()
	view.show_step(&"nonexistent_step", self)
	# get_unlock_config 返空 → show_step push_warning + queue_free，不崩
	assert_true(is_instance_valid(view), "未配置 step 不崩（queue_free 待帧回收）")


func _count_texture_rect(panel: Node) -> int:
	var n: int = 0
	for c in panel.get_children():
		if c is TextureRect:
			n += 1
	return n


func _find_label(panel: Node) -> Label:
	for c in panel.get_children():
		if c is Label:
			return c
	return null
