extends GutTest
# BattleStatisticsPanel 装配测试（照源 ui/battleStatistics.lua）。
# 覆盖：静态框架节点（HurtBg/CExit/Shelter/标题）+ 英雄行装配计数 + max_dmg 守卫 + 标题多语言 fill。
# 动画（Tween）GUT 同步不 step，仅测初始态（icon modulate.a=0 / count text="0" / bar scale.x=0）。
# unique_name_in_owner 的 owner 是 _content（.tscn scene root），非 panel 自身 — 经 panel._content 访问。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# finalizer 快照格式（tid/camp/dmg_statistics/rank/stars/level）
func _snap(c: int, dmg: float, tid: int = 1) -> Dictionary:
	return {"tid": tid, "camp": c, "dmg_statistics": dmg, "rank": 1, "stars": 0, "level": 1}


func _make_panel(units: Array = []) -> BattleStatisticsPanel:
	var panel := BattleStatisticsPanel.new()
	add_child(panel)
	panel.setup(units, cm)
	return panel


func test_setup_creates_static_nodes() -> void:
	var panel := _make_panel([_snap(1, 100.0), _snap(2, 200.0)])
	assert_not_null(panel._hurt_bg, "HurtBg 节点装配（panel._hurt_bg 字段）")
	var content: Control = panel._content
	assert_not_null(content.get_node_or_null("%CExit"), "CExit 按钮")
	assert_not_null(content.get_node_or_null("%Shelter"), "Shelter 遮罩")
	assert_not_null(panel._hurt_bg.get_node_or_null("HurtBg1"), "HurtBg1 内框")
	assert_not_null(panel._hurt_bg.get_node_or_null("%TitleOur"), "TitleOur 标题")
	assert_not_null(panel._hurt_bg.get_node_or_null("%TitleEnemy"), "TitleEnemy 标题")
	panel.queue_free()


func test_titles_filled_from_lstr() -> void:
	var panel := _make_panel([_snap(1, 100.0)])
	assert_eq(str((panel._hurt_bg.get_node("%TitleOur") as Label).text), "我方", "TitleOur 从 LSTR fill")
	assert_eq(str((panel._hurt_bg.get_node("%TitleEnemy") as Label).text), "敌方", "TitleEnemy 从 LSTR fill")
	assert_eq(str((panel._hurt_bg.get_node("%TitleOurDmg") as Label).text), "输出伤害", "TitleOurDmg 从 LSTR fill")
	panel.queue_free()


func test_rows_created_per_camp() -> void:
	# 每方 2 个单位 → 每2行（icon + count + bar_bg + bar_fill = 4 节点/行）
	var units: Array = [_snap(1, 100.0), _snap(1, 50.0), _snap(-1, 200.0), _snap(-1, 80.0)]
	var panel := _make_panel(units)
	# 静态子（HurtBg1/CExit/4标题=6）+ 动态行（2行×4 + 2行×4 = 16）= 22
	var dynamic_children: int = panel._hurt_bg.get_child_count() - 6
	assert_eq(dynamic_children, 16, "4行×4节点=16 动态子节点")
	panel.queue_free()


func test_caps_at_five_per_camp() -> void:
	# 每方7个 → 截断到5
	var units: Array = []
	for i in 7:
		units.append(_snap(1, float(i) * 10.0, i + 1))
	for i in 3:
		units.append(_snap(-1, float(i) * 20.0, i + 10))
	var panel := _make_panel(units)
	# 5行×4 + 3行×4 = 32 动态
	var dynamic_children: int = panel._hurt_bg.get_child_count() - 6
	assert_eq(dynamic_children, 32, "player 5行 + enemy 3行 = 32 节点")
	panel.queue_free()


func test_empty_units_no_crash() -> void:
	# max_dmg=0 守卫（防空除），空 unit_snapshot 不崩
	var panel := _make_panel([])
	assert_eq(panel._hurt_bg.get_child_count(), 6, "空 units 仅6静态子")
	panel.queue_free()


func test_initial_icon_hidden_and_count_zero() -> void:
	# 动画初始态：icon modulate.a=0（fade 前）/ count text="0"（number_jump 前）/ bar scale.x=0
	var panel := _make_panel([_snap(1, 100.0)])
	var found_hidden_icon: bool = false
	var found_zero_count: bool = false
	for child in panel._hurt_bg.get_children():
		if child is ReadheroIcon and not found_hidden_icon:
			assert_eq((child as ReadheroIcon).modulate.a, 0.0, "icon 初始 modulate.a=0")
			found_hidden_icon = true
		if child is Label and str((child as Label).text) == "0" and not found_zero_count:
			found_zero_count = true
	assert_true(found_hidden_icon, "找到动态 icon")
	assert_true(found_zero_count, "找到动态 count（初始 '0'）")
	panel.queue_free()


func test_close_emits_signal_and_frees() -> void:
	# GDScript lambda 按值捕获局部 bool，改用 Array 引用让回调内修改对外可见
	var emitted: Array = [false]
	var panel := _make_panel([_snap(1, 100.0)])
	panel.closed.connect(func() -> void: emitted[0] = true)
	panel.close()
	assert_true(emitted[0], "close emit closed 信号")


# 九宫格 capInsets 守卫（批 2 Task 8，批 1 终审存疑项确认同款互换后修复）：
# - tscn HurtBg：源 battleStatisticsConfig hurtBg main_vit_tips capInsets CCRectMake(15,20,45,15)，
#   贴图 103×61 → L15/T26/R43/B20（旧 T20/B26 互换）。
# - tscn HurtBg1：源 hurtBg1 tip_detail_bg 同 cap（源从 hurtBg 复制），贴图 161×27 cap 越界（20+15>27）
#   → Cocos 越界 clamp 等价 L15/T0/R101/B20（旧 T20/B0 互换）。
# - panel _make_bar_bg：源 ui1 hp_black_small capInsets CCRectMake(12,4,12,4)，贴图 89×11
#   → L12/T3/R65/B4（旧 T4/B3 互换）。公式：top=H-y-h/bottom=y（批 1 fde903b）。
func test_hurt_bg_patch_margins() -> void:
	var panel := _make_panel([_snap(1, 100.0)])
	var hurt_bg: NinePatchRect = panel._hurt_bg as NinePatchRect
	assert_not_null(hurt_bg, "HurtBg 为 NinePatchRect")
	if hurt_bg != null:
		assert_eq(hurt_bg.patch_margin_left, 12, "HurtBg L=15（源 cap x=15）")
		assert_eq(hurt_bg.patch_margin_top, 20, "HurtBg T=26（H-y-h=61-20-15）")
		assert_eq(hurt_bg.patch_margin_right, 34, "HurtBg R=43（W-x-w=103-15-45）")
		assert_eq(hurt_bg.patch_margin_bottom, 16, "HurtBg B=20（源 cap y=20）")
	var hurt_bg1: NinePatchRect = panel._hurt_bg.get_node("HurtBg1") as NinePatchRect
	assert_not_null(hurt_bg1, "HurtBg1 为 NinePatchRect")
	if hurt_bg1 != null:
		assert_eq(hurt_bg1.patch_margin_left, 12, "HurtBg1 L=12（cap 15÷CS）")
		assert_eq(hurt_bg1.patch_margin_top, 0, "HurtBg1 T=0（cap 越界 clamp：max(27-20-15,0)）")
		assert_eq(hurt_bg1.patch_margin_right, 79, "HurtBg1 R=79（101px÷CS）")
		assert_eq(hurt_bg1.patch_margin_bottom, 16, "HurtBg1 B=16（cap 20÷CS）")
	panel.queue_free()


func test_bar_bg_patch_margins() -> void:
	var panel := _make_panel([])
	var bar_bg: Control = panel._make_bar_bg(136.0, 250.0, 137.0)
	assert_true(bar_bg is NinePatchRect, "bar 底条为 NinePatchRect（源 ui1 Scale9Sprite）")
	if bar_bg is NinePatchRect:
		var npr: NinePatchRect = bar_bg as NinePatchRect
		assert_eq(npr.patch_margin_left, 9, "bar L=12（源 cap x=12）")
		assert_eq(npr.patch_margin_top, 2, "bar T=3（H-y-h=11-4-4）")
		assert_eq(npr.patch_margin_right, 51, "bar R=65（W-x-w=89-12-12）")
		assert_eq(npr.patch_margin_bottom, 3, "bar B=4（源 cap y=4）")
	assert_eq(bar_bg.size, Vector2(137.0, 15.0), "bar 尺寸 137×15（源 scaleSize）")
	bar_bg.queue_free()
	panel.queue_free()
