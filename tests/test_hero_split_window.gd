extends GutTest
# HeroSplitWindow 测试（2026-07-19）：务实分解链路。
# 选英雄→返还预览→二次确认→split→英雄移除+碎片增加+split_done 信号。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_mgr() -> HeroManager:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	mgr.add_hero(2)
	return mgr


# 窗口列出所有已拥有英雄（单机化 getSplitableHeroes → heroes.values，源联机 split_data 空壳）。
func test_window_lists_all_heroes() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := _make_mgr()
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(mgr, cm)
	window.show_window(root)
	assert_eq(window._grid.get_child_count(), 2, "2 英雄 cell")
	window.remove_window()
	root.queue_free()


# 选英雄 → 返还预览显示碎片 icon（preview_split）+ 分解按钮启用。
func test_select_hero_shows_return_preview() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := _make_mgr()
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(mgr, cm)
	window.show_window(root)
	var hero: HeroInstance = mgr.heroes.values()[0]
	window._select_hero(hero)
	assert_false(window._split_btn.disabled, "选中后分解按钮启用")
	assert_gt(window._return_host.get_child_count(), 0, "返还预览显示碎片 icon")
	window.remove_window()
	root.queue_free()


# 分解 → 英雄移除 + 碎片增加 + split_done 信号。
func test_split_removes_hero_and_adds_fragment() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := _make_mgr()
	var hero: HeroInstance = mgr.heroes.values()[0]
	var inst_id: int = hero.inst_id
	var preview: Dictionary = mgr.preview_split(inst_id)
	var frag_id: int = int(preview["fragment_id"])
	var before_count: int = int(mgr.fragments.get(frag_id, 0))
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(mgr, cm)
	window.show_window(root)
	watch_signals(window)
	window._select_hero(hero)
	window._perform_split()
	assert_eq(mgr.heroes.size(), 1, "分解后英雄数 -1")
	assert_eq(int(mgr.fragments.get(frag_id, 0)), before_count + int(preview["count"]), "碎片 +Convert Fragments")
	assert_signal_emitted(window, "split_done", "split_done 信号触发（hero_package 刷新列表）")
	window.remove_window()
	root.queue_free()


# 未选英雄点分解 → toast 请选择（不执行 split）。
func test_split_without_selection_no_op() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := _make_mgr()
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(mgr, cm)
	window.show_window(root)
	window._on_split_pressed()   # _selected == null → toast，不 split
	assert_eq(mgr.heroes.size(), 2, "未选英雄不分解")
	window.remove_window()
	root.queue_free()


# explain 弹窗 4 行 LSTR 文本填充。
func test_explain_fills_lstr_text() -> void:
	var root := Node.new()
	add_child(root)
	var explain := HeroSplitExplain.new()
	explain.setup(cm)
	root.add_child(explain)   # 触发 _ready → _build_content
	var content: Control = explain.get_child(0) as Control
	assert_not_null(content, "content instantiate")
	if content != null:
		var lbl: Label = content.get_node("%ExplainLabel") as Label
		assert_not_null(lbl, "ExplainLabel 存在")
		if lbl != null:
			assert_gt(lbl.text.length(), 0, "explain 文本非空")
			assert_true(lbl.text.contains("分解"), "explain 含「分解」文案")
	explain.queue_free()
	root.queue_free()
