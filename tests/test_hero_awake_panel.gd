extends GutTest
# hero_awake 觉醒展示弹窗两件套守卫（批 1 Task 4，2026-08-15）。
# 照源 popheroawake.lua（178 行，代码式建 UI）直译：bg 三色底/light 光圈/cardui 卡宿主 +
# 运行时 FCA 双宿主；静态树全在 hero_awake_content.tscn，panel 只做 fill + 动画时序。
# 源无文字标签 → 无 theme variation 接线（区别于 eatexp/stone_detail）。

var cm: ConfigManager

const CS: float = 1.28125


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _instantiate_content() -> Control:
	var scene: PackedScene = load("res://scenes/ui/hero_awake_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


# tid → Unit.Bg Color（实测分布：1=blue / 3=red / 6=green）。
func _make_awake_panel(tid: int) -> HeroAwakePanel:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var inst_id: int = pd.hero_manager.add_hero(tid)
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	var panel := HeroAwakePanel.new("popheroawake", {})
	panel.setup_awake(hero, cm)
	panel.show_window(root)
	return panel


# ── 静态树照源直译（源 create :88-162 ui_info :109-145）──

func test_content_layout_follows_source() -> void:
	# bg（源 :110-120 Sprite tavern_get_hero_bg 512x384 at (400,240) 中心锚）：
	# 显示 399.6x299.7 = 纹理÷CS，中心 _g(400,240)=(480,320)；modulate a=0 照源 config opacity=0
	var inst: Control = _instantiate_content()
	var bg: TextureRect = inst.get_node("%BgRect") as TextureRect
	assert_almost_eq((bg.offset_left + bg.offset_right) / 2.0, 480.0, 0.5, "bg 中心 x=480")
	assert_almost_eq((bg.offset_top + bg.offset_bottom) / 2.0, 320.0, 0.5, "bg 中心 y=320")
	assert_almost_eq(bg.offset_right - bg.offset_left, 512.0 / CS, 0.5, "bg 宽=512/CS（照源纹理÷CS）")
	assert_almost_eq(bg.offset_bottom - bg.offset_top, 384.0 / CS, 0.5, "bg 高=384/CS")
	assert_almost_eq(bg.modulate.a, 0.0, 0.001, "bg 初始透明（源 config opacity=0）")
	# light（源 :121-131 Sprite shine.png 139x136 at (400,550) 中心锚 scale=6）：
	# 显示尺寸=像素÷CS → Sprite2D scale=6/CS（Task 3 mark 59/CS*0.8 同口径）
	var light: Sprite2D = inst.get_node("%LightSprite") as Sprite2D
	assert_almost_eq(light.position.x, 480.0, 0.5, "light 中心 x=480（源 (400,550)）")
	assert_almost_eq(light.position.y, 10.0, 0.5, "light 中心 y=10（560-550）")
	assert_almost_eq(light.scale.x, 6.0 / CS, 0.01, "light scale=6/CS（显示尺寸÷CS 口径）")
	assert_almost_eq(light.modulate.a, 0.0, 0.001, "light 初始透明（源 config opacity=0）")
	assert_not_null(light.texture, "light 贴图接线 shine.png")


func test_content_fca_hosts_position_and_order() -> void:
	# FCA 双宿主（源 showCardui :26-33 bubble at (400,240) scale1.5；:38-44 card_<color>
	# at (400,240) z=10 scale1.5）→ (480,320)；树序照源 z 序：bubble(0) < cardui(1) < card FCA(10)
	var inst: Control = _instantiate_content()
	var bubble_host: Node2D = inst.get_node("%FcaBubbleHost") as Node2D
	var card_host: Control = inst.get_node("%CardHost") as Control
	var card_fca_host: Node2D = inst.get_node("%FcaCardHost") as Node2D
	assert_not_null(bubble_host, "bubble FCA 宿主常驻 tscn")
	assert_not_null(card_fca_host, "card FCA 宿主常驻 tscn")
	assert_almost_eq(bubble_host.position.x, 480.0, 0.5, "bubble 宿主 x=480（源 (400,240)）")
	assert_almost_eq(bubble_host.position.y, 320.0, 0.5, "bubble 宿主 y=320")
	assert_almost_eq(bubble_host.scale.x, 1.5, 0.001, "bubble 宿主 scale=1.5 照源")
	assert_almost_eq(card_fca_host.position.x, 480.0, 0.5, "card FCA 宿主 x=480")
	assert_almost_eq(card_fca_host.position.y, 320.0, 0.5, "card FCA 宿主 y=320")
	assert_almost_eq(card_fca_host.scale.x, 1.5, 0.001, "card FCA 宿主 scale=1.5 照源")
	assert_true(bubble_host.get_index() < card_host.get_index(), "bubble 宿主树序在卡前（源 z0<z1）")
	assert_true(card_host.get_index() < card_fca_host.get_index(), "card FCA 树序在卡后（源 z10>z1）")


func test_content_all_fullscreen_host_static() -> void:
	# CardHost 全屏宿主常驻（源 cardui 容器语义，卡实例由 panel fill 挂入）
	var inst: Control = _instantiate_content()
	var card_host: Control = inst.get_node("%CardHost") as Control
	assert_not_null(card_host, "CardHost 常驻 tscn")
	assert_eq(card_host.anchor_left, 0.0, "CardHost 左锚 0")
	assert_eq(card_host.anchor_right, 1.0, "CardHost 右锚 1（全屏）")


# ── panel fill 与业务 ──

func test_bg_texture_filled_by_unit_bg_color() -> void:
	# 源 :102-107 color=Unit["Bg Color"]，bg_res 三色表 → panel fill bg.texture
	var panel: HeroAwakePanel = _make_awake_panel(1)   # tid1 Bg Color=blue
	assert_not_null(panel._bg.texture, "bg 贴图已 fill")
	assert_true(String(panel._bg.texture.resource_path).contains("tavern_get_hero_bg_blue"),
		"blue 英雄 fill 蓝底（Unit.Bg Color）")
	panel.remove_window()
	var panel_red: HeroAwakePanel = _make_awake_panel(3)   # tid3 Bg Color=red
	assert_true(String(panel_red._bg.texture.resource_path).contains("tavern_get_hero_bg_red"),
		"red 英雄 fill 红底")
	panel_red.remove_window()


func test_card_instance_mounted_and_hidden_until_fade() -> void:
	# 源 cardui opacity=0（:142 config），delay 0.4 后 CCFadeIn(0.2)（:21-36）。
	# 卡实例挂 CardHost，初始 modulate.a=0；复用 hero_detail_card_tab（+200 居中适配）
	var panel: HeroAwakePanel = _make_awake_panel(1)
	assert_gt(panel._card_host.get_child_count(), 0, "卡实例已挂 CardHost")
	var card: Control = panel._card_host.get_child(0) as Control
	assert_almost_eq(card.modulate.a, 0.0, 0.001, "卡初始透明（源 config opacity=0）")
	assert_almost_eq(card.offset_left, 200.0, 0.5, "卡 offset=200（CardFrame center→(480,320)）")
	panel.remove_window()


func test_awake_shown_signal_after_fade_in() -> void:
	# 动画时序照源：bg CCFadeIn(0.4) → showCardui（light 旋转 + card fade + FCA）→ awake_shown
	var panel: HeroAwakePanel = _make_awake_panel(1)
	watch_signals(panel)
	await get_tree().create_timer(0.95).timeout   # bg 0.4s 淡入后 light 再 0.4s 淡入，留 buffer
	assert_signal_emit_count(panel, "awake_shown", 1, "bg 淡入后 awake_shown 发射一次")
	assert_almost_eq(panel._bg.modulate.a, 1.0, 0.05, "bg 淡入至不透明")
	assert_almost_eq(panel._light.modulate.a, 1.0, 0.05, "light 淡入至不透明")
	panel.remove_window()


func test_click_closes_window() -> void:
	# 源 doClickLayer :49-72：点击任意处 handler + destroy（觉醒恒单卡，多卡分支不迁移）
	var panel: HeroAwakePanel = _make_awake_panel(1)
	var closed_flag: Array = []
	panel.closed.connect(func() -> void: closed_flag.append(true))
	panel._on_click_layer()
	await get_tree().process_frame
	assert_eq(closed_flag.size(), 1, "closed 信号发射")
	assert_false(is_instance_valid(panel), "关闭后 panel 销毁")


func test_close_handler_called_on_click() -> void:
	# 源 handler() 回调（:156 announce param.handler → 本项目 set_close_handler）
	var panel: HeroAwakePanel = _make_awake_panel(1)
	var called: Array = []
	panel.set_close_handler(func() -> void: called.append(true))
	panel._on_click_layer()
	await get_tree().process_frame
	assert_eq(called.size(), 1, "close handler 被调用")


func test_panel_no_static_construction() -> void:
	# 两件套红线：静态结构零 .new()（bg/light/宿主全在 tscn）。
	# 白名单：AtlasSprite（RefCounted 图集加载器）+ FcaAnimation（FCA 播放器工厂，
	# 源 createFcaNode 运行时创建等价）。
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_awake_panel.gd")
	assert_eq(text.count(".new()"), text.count("AtlasSprite.new()") + text.count("FcaAnimation.new()"),
		"静态节点零 .new()，仅 FCA 工厂白名单")


func test_fca_loaded_into_static_hosts() -> void:
	# FCA 资源齐备（eff_UI_tavern_bubble/card_blue.abc 实测存在）→ 动画启动后工厂节点
	# 挂静态宿主；card FCA 按 Unit.Bg Color 选 eff_UI_tavern_card_<color>（源 :38）
	var panel: HeroAwakePanel = _make_awake_panel(1)   # blue
	await get_tree().create_timer(1.2).timeout   # card FCA 0.4s 起 / bubble 1.0s 起（delay 链），留 buffer
	assert_gt(panel._bubble_host.get_child_count(), 0, "bubble FCA 工厂节点挂 FcaBubbleHost")
	assert_gt(panel._card_fca_host.get_child_count(), 0, "card FCA 工厂节点挂 FcaCardHost")
	panel.remove_window()
