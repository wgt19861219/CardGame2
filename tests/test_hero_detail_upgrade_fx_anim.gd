extends GutTest
# 进阶特效测试（照源 upgradeReply window.lua:609-690 表现链补译，2026-09-05）：
# ①FCA 光效 z_index=100（旧实现 z=0 被 z=2~16 的内容盖住 → 用户"特效没有"根因）
# ②playEquipAnim 装备上交：6 槽旧装备图标从槽位飞向中心消失（源 :612-649）
# ③play_hero_cheer 英雄欢呼（源 :28-40 changeFca("Cheer")，播完回 Idle）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_host() -> Control:
	var host := Control.new()
	host.size = Vector2(800, 480)
	add_child_autofree(host)
	return host


func _make_base_layer() -> Control:
	# 用真实 tscn：EquipSlot1-6 带 unique_name_in_owner（% 查找依赖场景 owner，运行时造节点不行）
	var scene: PackedScene = load("res://scenes/ui/hero_detail_content.tscn")
	var root := scene.instantiate() as Control
	add_child_autofree(root)
	return root.get_node("BaseLayer") as Control


# FCA 光效：挂 host、z_index=100（回归断言：旧实现 z=0 不可见）+ ADD 混合 + 源位置
func test_play_upgrade_effect_high_z() -> void:
	var host := _make_host()
	HeroDetailUpgradeFx.play_upgrade_effect(host)
	var fca_nodes := host.find_children("*", "FcaAnimation", true, false)
	assert_gte(fca_nodes.size(), 1, "FCA 光效节点已创建")
	for n in fca_nodes:
		var fca := n as FcaAnimation
		assert_eq(fca.z_index, 100, "光效 z_index=100 盖过内容层")
		assert_eq(fca.position, Vector2(460.0, 260.0), "光效位置=源锚点 fallback(400,215)+源 delta(60,45)（rootPos-heropos 补偿特效内容左偏）")
		for sp in fca.find_children("*", "Sprite2D", true, false):
			var mat := (sp as Sprite2D).material as CanvasItemMaterial
			assert_not_null(mat, "特效 sprite 挂混合材质")
			if mat != null:
				assert_eq(mat.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD, "加法混合（源 C++ FCA 加色合成）")


# 装备上交：3 件旧装备 → 3 个飞行图标；0 件 → 不建节点
func test_play_equip_fly_anim() -> void:
	var host := _make_host()
	var base := _make_base_layer()
	var old_ids: Array[int] = [102, 102, 111, 0, 0, 0]
	var flown: int = HeroDetailUpgradeFx.play_equip_fly_anim(host, base, old_ids, cm, self)
	assert_eq(flown, 3, "3 件旧装备 → 3 个飞行图标")
	var icons := host.find_children("*", "Control", true, false).filter(
		func(c: Node) -> bool: return c.has_meta(&"equip_fly_icon"))
	assert_eq(icons.size(), 3, "飞行图标挂 fx host（重建后仍存活）")
	for c in icons:
		assert_eq((c as CanvasItem).z_index, 100, "飞行图标 z=100")
	var flown2: int = HeroDetailUpgradeFx.play_equip_fly_anim(host, base, [0, 0, 0, 0, 0, 0], cm, self)
	assert_eq(flown2, 0, "无旧装备不建图标")


# 英雄欢呼：无 FCA 子树静默返回 false（降级安全）；有 FcaAnimation 但无 Cheer 动作不崩
func test_play_hero_cheer_no_fca_safe() -> void:
	var host := _make_host()
	var ok: bool = HeroDetailUpgradeFx.play_hero_cheer(host)
	assert_false(ok, "无 FCA 立绘 → 返 false 不崩")


# 运行时锚点推导：宿主被右移 140（详情 tab BASE_SLIDE_OFFSET 同款）后，特效必须跟到英雄实际站位
# （回归背景：2026-09-06 用户实测特效偏左 140——死常量锚点漏了 BaseLayer 运行时滑动偏移）
func test_hero_anchor_tracks_runtime_host_offset() -> void:
	var host := _make_host()
	var scene: PackedScene = load("res://scenes/ui/hero_detail_content.tscn")
	var content := scene.instantiate() as Control
	host.add_child(content)   # 生产链路：content 整棵挂 fx_host(panel 根)树下
	var ph := content.find_child("PortraitHost", true, false) as Control
	assert_not_null(ph, "tscn 内有 PortraitHost")
	var parts := Node2D.new()
	parts.position = Vector2(400.0, 215.0)   # fill_portrait 的 HERO_FCA_COCOS 局部位
	ph.add_child(parts)
	ph.position = Vector2(140.0, 0.0)   # 模拟详情 tab BaseLayer 右移 140
	HeroDetailUpgradeFx.play_upgrade_effect(host)
	var fca_nodes := host.find_children("*", "FcaAnimation", true, false)
	assert_gte(fca_nodes.size(), 1, "FCA 光效节点已创建")
	if fca_nodes.size() > 0:
		var expect: Vector2 = host.get_global_transform().affine_inverse() * parts.global_position \
			+ Vector2(60.0, 45.0)   # 源 rootPos-heropos delta
		assert_eq((fca_nodes[0] as FcaAnimation).position, expect,
			"特效锚点=英雄实际站位（含宿主偏移 140）+ 源 delta 补偿，视觉重心落英雄身上")
