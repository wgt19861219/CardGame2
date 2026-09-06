extends GutTest
## 全局滚动条隐藏守卫（2026-09-06）。
## 源手游 draglist 触屏拖拽无可见滚动条；default_theme 对 VScrollBar/HScrollBar
## 全 stylebox 置空（StyleBoxEmpty 无 min size → 厚度 0 不占视口，滚轮/拖拽不受影响）。
## 本测试锁 theme 资源契约 + 运行时生效链路，防样式回归露 Godot 默认灰条。

const THEME_RES: String = "res://resources/themes/default_theme.tres"
const STYLEBOX_KEYS: Array[String] = [
	"scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed",
]


func test_theme_scrollbar_styleboxes_empty() -> void:
	var theme: Theme = load(THEME_RES) as Theme
	assert_not_null(theme, "default_theme.tres 可加载")
	for type_name: String in ["VScrollBar", "HScrollBar"]:
		for key: String in STYLEBOX_KEYS:
			var sb: StyleBox = theme.get_stylebox(key, type_name)
			assert_true(sb is StyleBoxEmpty,
				"%s/%s 为 StyleBoxEmpty（当前 %s）" % [type_name, key, sb.get_class()])


func test_runtime_scrollbar_hidden_via_root_theme() -> void:
	# ThemeManager autoload 把 theme 挂 root Viewport → 其下 ScrollContainer 内部
	# 滚动条沿主题链取到空样式。探针直接挂 root：GutTest 为普通 Node 会断
	# Control 主题链（AGENTS.md 主题链红线），隔普通 Node 会回落引擎默认样式。
	assert_not_null(get_tree().root.theme, "ThemeManager 已把 default_theme 挂 root viewport")
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(300.0, 100.0)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(280.0, 500.0)
	box.size_flags_horizontal = Control.SIZE_FILL
	scroll.add_child(box)
	get_tree().root.add_child(scroll)
	await get_tree().process_frame
	await get_tree().process_frame
	var vs: VScrollBar = scroll.get_v_scroll_bar()
	for key: String in STYLEBOX_KEYS:
		assert_true(vs.get_theme_stylebox(key) is StyleBoxEmpty,
			"运行时 VScrollBar/%s 沿 root theme 取空样式" % key)
	# StyleBoxEmpty 无 min size → 布局后滚动条厚度 0（零像素 = 不可见且不占视口）。
	assert_almost_eq(vs.size.x, 0.0, 0.01, "垂直滚动条厚度 0（不可见、不占视口）")
	# 视觉隐藏不影响滚动功能：内容 500 > 视口 100 → 滚动范围展开。
	assert_gt(vs.max_value, 0.0, "内容超高时滚动范围仍存在（滚轮/拖拽可用）")
	scroll.free()


func test_scroll_texture_styling_retired() -> void:
	# avatar/task 贴图化滚动条随全局隐藏退役（2026-09-06），panel 层不得回潮
	# add_theme_stylebox_override 套滚动条样式。
	for panel_path: String in [
		"res://scripts/ui/avatar_panel.gd",
		"res://scripts/ui/task_panel.gd",
	]:
		var script_text: String = FileAccess.get_file_as_string(panel_path)
		assert_eq(script_text.count("add_theme_stylebox_override"), 0,
			"%s 无滚动条 stylebox override（贴图化退役）" % panel_path)
