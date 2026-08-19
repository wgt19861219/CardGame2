extends GutTest
# StageDoneScene 胜利结算场景测试（照源 ui/stagedone.lua，2026-07-03 第二十一轮动画版）。
# 动画态测试：setup 后初始隐藏态（star scale=0/hero opacity=0/button opacity=0/label "+0"）+
#   skip_anim 跳终态（star scale=1/hero opacity=1/bar tExp/tMaxExp/label 终值）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_param(stars: int = 2) -> Dictionary:
	return {
		"stage_id": -27, "victory": true, "stars": stars, "is_key_stage": true,
		"exp": 100, "gold": 500,
		# pre（动画起点）+ t（终态）双态字段（源 hero_info：level/exp/max_exp 为 pre，t_* 为终态）
		"heroes": [
			{"id": 1, "rank": 1, "level": 3, "exp": 20, "max_exp": 80,
			 "t_level": 5, "t_exp": 50, "t_max_exp": 100, "add_hero_exp": 30},
			{"id": 2, "rank": 1, "level": 4, "exp": 10, "max_exp": 60,
			 "t_level": 4, "t_exp": 10, "t_max_exp": 60, "add_hero_exp": 30},
		],
		"loot_list": {
			101: {"amount": 2, "type": "equip"},
			105: {"amount": 1, "type": "hero"},
		},
		"player_info": {"ori_level": 3, "exp": 100, "level": 3, "add_exp": 100,
			"max_exp": 200, "ori_exp": 0, "ori_max_exp": 200, "anim_list": []},
	}


const SCENE_PACKED: PackedScene = preload("res://scenes/battle/stage_done_scene.tscn")


func _make_scene(stars: int = 2) -> StageDoneScene:
	# 2026-08-05 合并后：静态节点固化进 .tscn，必须 instantiate（不能 new()，否则无子节点）。
	var scene := SCENE_PACKED.instantiate() as StageDoneScene
	add_child(scene)
	scene.setup(_make_param(stars), cm)
	return scene


func test_setup_creates_nodes() -> void:
	var scene := _make_scene()
	# 重构后静态节点在 stage_done_scene.tscn（scene._content=self 子树，unique_name % 查找）
	var c: Control = scene._content
	assert_not_null(c.get_node_or_null("%Bg"), "Bg 节点")
	assert_not_null(c.get_node_or_null("%Shelter"), "Shelter 节点")
	assert_not_null(c.get_node_or_null("%Light"), "Light 节点")
	assert_not_null(c.get_node_or_null("%Star1"), "Star1")
	assert_not_null(c.get_node_or_null("%Star2"), "Star2")
	assert_not_null(c.get_node_or_null("%Star3"), "Star3")
	assert_not_null(c.get_node_or_null("%Replay"), "Replay 按钮")
	assert_not_null(c.get_node_or_null("%Next"), "Next 按钮")
	assert_not_null(c.get_node_or_null("%InfoBg"), "InfoBg 节点")
	scene.queue_free()


func test_play_enter_sets_anim_flag() -> void:
	# setup → play_enter → _anim_playing=true（tween 启动，GUT 同步不 step）
	var scene := _make_scene()
	assert_true(scene._anim_playing, "play_enter 后 _anim_playing=true")
	scene.queue_free()


func test_initial_state_hidden() -> void:
	# 动画起点：star scale=0 / info_bg modulate.a=0 / button modulate.a=0 / gold·exp label "+0"
	var scene := _make_scene()
	var star1: Sprite2D = scene._content.get_node("%Star1")
	# tween 启动后 GUT 同步不 step，但创建时浮点级微小插值（0.00001），用容差断言接近 0
	assert_almost_eq(star1.scale.x, 0.0, 0.01, "Star1 scale≈0（动画起点）")
	assert_eq(scene._info_bg.modulate.a, 0.0, "info_bg modulate.a=0（fade 前）")
	assert_eq(scene._next_btn.modulate.a, 0.0, "next button modulate.a=0")
	assert_eq(scene._gold_label.text, "+0", "gold label 初始 +0（跳动前）")
	assert_eq(scene._exp_label.text, "+0", "exp label 初始 +0")
	scene.queue_free()


func test_hero_initial_hidden() -> void:
	# hero icon modulate.a=0；bar scale.x = pre_exp/pre_max ×(1/CS)（hero1: 20/80=0.25 → 0.195）
	var scene := _make_scene()
	var ri: ReadheroIcon = scene._hero_icon_nodes[0]
	assert_eq(ri.icon.modulate.a, 0.0, "hero icon modulate.a=0（fade 前）")
	var bar: Sprite2D = scene._hero_bars[0]
	assert_almost_eq(bar.scale.x, 0.25 / StageDoneScene.CONTENT_SCALE, 0.001,
		"bar scale.x = pre_exp/pre_max ×1/CS（20/80 ÷CS）")
	scene.queue_free()


func test_skip_sets_labels() -> void:
	# skip 后 gold/exp label 终值
	var scene := _make_scene()
	scene.skip_anim()
	assert_eq(scene._exp_label.text, "+100", "skip 后 exp label 终值")
	assert_eq(scene._gold_label.text, "+500", "skip 后 gold label 终值")
	scene.queue_free()


func test_skip_stars_final() -> void:
	# stars=2 → skip 后 Star1/Star2 scale=1，Star3 scale=0
	var scene := _make_scene(2)
	scene.skip_anim()
	assert_eq((scene._content.get_node("%Star1") as Sprite2D).scale, Vector2.ONE, "Star1 scale=1（stars=2）")
	assert_eq((scene._content.get_node("%Star2") as Sprite2D).scale, Vector2.ONE, "Star2 scale=1")
	# Star3（stars=2 时第3颗）未在 skip 终态设置，保留初始+tween 微小残留，用容差
	assert_almost_eq((scene._content.get_node("%Star3") as Sprite2D).scale.x, 0.0, 0.01, "Star3 scale≈0")
	scene.queue_free()


func test_skip_hero_final() -> void:
	# skip 后 hero icon modulate.a=1，bar scale.x=t_exp/t_max_exp ×(1/CS)（hero1: 50/100=0.5 → 0.39）
	var scene := _make_scene()
	scene.skip_anim()
	var ri: ReadheroIcon = scene._hero_icon_nodes[0]
	assert_eq(ri.icon.modulate.a, 1.0, "hero icon modulate.a=1（skip 终态）")
	var bar: Sprite2D = scene._hero_bars[0]
	assert_almost_eq(bar.scale.x, 0.5 / StageDoneScene.CONTENT_SCALE, 0.001,
		"bar scale.x = t_exp/t_max_exp ×1/CS（50/100 ÷CS）")
	scene.queue_free()


func test_skip_loot_final() -> void:
	var scene := _make_scene()
	scene.skip_anim()
	for icon in scene._loot_icon_nodes:
		assert_eq((icon as Control).scale, Vector2.ONE, "loot icon scale=1（skip 终态）")
	scene.queue_free()


func test_skip_anim_flag_false() -> void:
	var scene := _make_scene()
	scene.skip_anim()
	assert_false(scene._anim_playing, "skip 后 _anim_playing=false")
	scene.queue_free()


func test_skip_idempotent() -> void:
	# 已 skip 后再 skip 不重复（_anim_playing 守卫）
	var scene := _make_scene()
	scene.skip_anim()
	scene.skip_anim()   # 第二次应直接 return（_anim_playing 已 false）
	assert_false(scene._anim_playing, "二次 skip 无副作用")
	scene.queue_free()


func test_replay_pressed_connected() -> void:
	var scene := _make_scene()
	var replay: TextureButton = scene._content.get_node("%Replay")
	assert_true(replay.pressed.is_connected(scene._on_replay_pressed), "Replay pressed 连接")
	scene.queue_free()


func test_next_pressed_connected() -> void:
	var scene := _make_scene()
	var next_btn: TextureButton = scene._content.get_node("%Next")
	assert_true(next_btn.pressed.is_connected(scene._on_next_pressed), "Next pressed 连接")
	scene.queue_free()


func test_shelter_full_rect() -> void:
	var scene := _make_scene()
	var shelter: ColorRect = scene._content.get_node("%Shelter")
	assert_eq(shelter.anchor_right, 1.0, "Shelter 全屏 anchor_right=1")
	assert_eq(shelter.anchor_bottom, 1.0, "Shelter 全屏 anchor_bottom=1")
	scene.queue_free()


func test_hero_and_loot_counts() -> void:
	var scene := _make_scene()
	assert_eq(scene._hero_icon_nodes.size(), 2, "英雄图标数 = heroes 数组长度")
	assert_eq(scene._loot_icon_nodes.size(), 2, "掉落图标数 = loot_list 项数")
	scene.queue_free()


# P1-16（2026-07-11）：battleStatist 按钮 + gold_icon + 装饰背景层补全。
# 2026-08-05 重构：BattleStatistNode(Sprite2D 父) → BattleStatistBtn(Button) + BattleCount(Label 子节点) 静态化进 .tscn。
func test_battle_statist_node_created() -> void:
	var scene := _make_scene()
	assert_not_null(scene._battle_statist_btn, "BattleStatistBtn 装配")
	assert_eq(scene._battle_statist_btn.modulate.a, 0.0, "BattleStatistBtn 初始 modulate.a=0（独立 fade）")
	assert_not_null(scene._battle_statist_btn.get_node_or_null("BattleCount"), "battleCount Label")
	scene.queue_free()


# P1-16：InfoBg 子节点含 4 装饰背景 + gold_icon + exp_icon（照源 :1457-1618/1713-1738）。
func test_info_bg_has_decor_and_icons() -> void:
	var scene := _make_scene()
	var info_bg: Sprite2D = scene._info_bg
	# 4 装饰背景 + gold_icon/exp_icon + lv/gold/exp label + battleStatistBtn = 10 子节点
	assert_gt(info_bg.get_child_count(), 5, "InfoBg 子节点 >5（装饰背景+图标+label+statist）")
	scene.queue_free()


# 2026-08-05 重构：HeroHost/LootHost 起始坐标固化进 .tscn，hero/loot icon procedural 挂此。
func test_hero_loot_host_exist() -> void:
	var scene := _make_scene()
	assert_not_null(scene._hero_host, "%HeroHost 节点存在")
	assert_not_null(scene._loot_host, "%LootHost 节点存在")
	# hero/loot icon 挂在 Host 下（数量随 _param）
	assert_eq(scene._hero_host.get_child_count(), scene._hero_icon_nodes.size(), "HeroHost 子节点数 = hero icon 数")
	assert_eq(scene._loot_host.get_child_count(), scene._loot_icon_nodes.size(), "LootHost 子节点数 = loot icon 数")
	scene.queue_free()


# 经验条源位断言（源 stagedone.lua:364-374：bar 左中锚 (0,-8)/bg 中心 (40,-8)/exp 文本 (38,-30)，
# Cocos 头像 104×104 左下原点 → Godot 左上原点中心线 y=104+8=112 / 104+30=134）。
# 回归锚点：2026-08-19 修复 ①BAR_OFFSET=(0,-8) 照抄未翻转（条跑到头像上方）②原尺寸显示（÷CS 修）。
func test_hero_exp_bar_source_positions() -> void:
	var scene := _make_scene()
	var bar_bg: Sprite2D = scene._hero_bar_bgs[0]
	assert_true(bar_bg.centered, "bar_bg 中心锚（源默认锚点 0.5,0.5）")
	assert_eq(bar_bg.position, Vector2(40.0, 112.0), "bar_bg 中心 (40,112)（源 40,-8 翻转）")
	var bar_scale: Vector2 = Vector2.ONE / StageDoneScene.CONTENT_SCALE
	assert_almost_eq(bar_bg.scale.x, bar_scale.x, 0.001, "bar_bg ÷CS 缩放（107→83.5 显示）")
	var bar: Sprite2D = scene._hero_bars[0]
	assert_false(bar.centered, "bar 左上锚（源锚点 0,0.5）")
	assert_almost_eq(bar.position.y, 112.0 - 17.0 / StageDoneScene.CONTENT_SCALE * 0.5, 0.01,
		"bar 左端 x=0 中心线 y=112（左上角 = 112-显示高/2）")
	var exp_lbl: Label = (scene._hero_icon_nodes[0].icon.get_child(-1) as Label)
	assert_eq(exp_lbl.position, Vector2(-2.0, 125.0), "exp label 左上 (38,134)-size/2")
	assert_eq(exp_lbl.label_settings.font_size, 18, "exp label 字号 18（源 createttf 18）")
	scene.queue_free()


# skip 后 fade 组终态恢复（回归锚点：2026-08-19 修复 skip 冻结 InfoBg modulate.a=0 整条透明）。
func test_skip_restores_fade_group() -> void:
	var scene := _make_scene()
	scene.skip_anim()
	assert_eq(scene._info_bg.modulate.a, 1.0, "skip 后 InfoBg 不透明")
	assert_eq(scene._light.modulate.a, 1.0, "skip 后 Light 不透明")
	assert_eq(scene._battle_statist_btn.modulate.a, 1.0, "skip 后统计按钮不透明")
	assert_eq(scene._next_btn.modulate.a, 1.0, "skip 后 Next 按钮不透明")
	var ri: ReadheroIcon = scene._hero_icon_nodes[0]
	assert_eq(ri.icon.rotation, 0.0, "skip 后 hero icon 无旋转残留")
	scene.queue_free()


# InfoBg 文字样式断言（源 lv 18 号 / gold·exp 19 号 + ccc3(169,70,6) 棕红）。
func test_info_bg_label_styles() -> void:
	var scene := _make_scene()
	var info_bg: Sprite2D = scene._info_bg
	var lv: Label = info_bg.get_node("%Lv") as Label
	var gold: Label = info_bg.get_node("%Gold") as Label
	var exp_lbl: Label = info_bg.get_node("%Exp") as Label
	assert_eq(lv.label_settings.font_size, 18, "Lv 字号 18（源）")
	assert_eq(gold.label_settings.font_size, 19, "Gold 字号 19（源）")
	assert_eq(exp_lbl.label_settings.font_size, 19, "Exp 字号 19（源）")
	var src_color: Color = Color(169.0 / 255.0, 70.0 / 255.0, 6.0 / 255.0)
	assert_almost_eq(gold.label_settings.font_color.r8, 169, 1, "Gold 字色 R=169（源 ccc3(169,70,6)）")
	assert_almost_eq(gold.label_settings.font_color.g8, 70, 1, "Gold 字色 G=70")
	assert_almost_eq(gold.label_settings.font_color.b8, 6, 1, "Gold 字色 B=6")
	assert_almost_eq(exp_lbl.label_settings.font_color.r8, 169, 1, "Exp 字色 R=169")
	assert_almost_eq(lv.label_settings.font_color.r8, 169, 1, "Lv 字色 R=169")
	scene.queue_free()
