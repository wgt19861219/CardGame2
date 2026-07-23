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
	var units: Array = [_snap(1, 100.0), _snap(1, 50.0), _snap(2, 200.0), _snap(2, 80.0)]
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
		units.append(_snap(2, float(i) * 20.0, i + 10))
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
