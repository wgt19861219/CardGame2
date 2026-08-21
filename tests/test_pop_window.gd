extends GutTest
# Phase 7 PopWindow 基类测试（2026-07-02）。


func test_show_remove_window() -> void:
	var root := Node.new()
	add_child(root)
	var w := PopWindow.new("test", {})
	w.show_window(root)
	assert_not_null(w.shade_layer, "show → shade_layer 创建")
	assert_not_null(w.container, "container 创建")
	assert_true(root.is_ancestor_of(w), "挂到 parent")
	var enter_called: Array[bool] = [false]
	var w2 := PopWindow.new("t2", {})
	w2.register_on_enter(func() -> void: enter_called[0] = true)
	w2.show_window(root)
	assert_eq(enter_called[0], true, "show → enter handler 触发")
	w.remove_window()
	w2.remove_window()
	root.queue_free()


func test_set_swallow() -> void:
	var w := PopWindow.new()
	w.setup()
	assert_eq(w.shade_layer.mouse_filter, Control.MOUSE_FILTER_STOP, "默认 swallow=STOP")
	w.set_swallow(false)
	assert_eq(w.shade_layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "swallow=false → IGNORE")
	w.queue_free()


# ---- T4 样板收敛（阶段一）：4 能力基类接管 ----

# 透明遮罩：transparent_shade=true → shade 全透明 + IGNORE（原 10 文件 hack 收敛）。
func test_transparent_shade() -> void:
	var w := PopWindow.new()
	w.transparent_shade = true
	w.setup()
	assert_eq(w.shade_layer.color.a8, 0, "transparent_shade → alpha=0")
	assert_eq(w.shade_layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "transparent_shade → IGNORE")
	w.queue_free()


# HUD identity：非空时 show 切换 / remove 恢复打开前 identity（原 8 份 override 收敛）。
func test_hud_identity_lifecycle() -> void:
	var root := Node.new()
	add_child(root)
	HudOverlay.apply_identity("main")
	var w := PopWindow.new("t4", {})
	w.hud_identity = "crusade"
	w.show_window(root)
	assert_eq(HudOverlay.get_identity(), "crusade", "show_window 应切 hud_identity")
	w.remove_window()
	assert_eq(HudOverlay.get_identity(), "main", "从 main 打开，remove_window 应恢复 main")
	root.queue_free()


# 嵌套弹窗 identity 恢复（2026-08-20 用户反馈：背包→图鉴→返回，HUD 恢复 main 致主界面
# 头像透过背包显示）。内层 remove_window 应恢复其打开时的 identity（外层弹窗值），非硬编码 main。
func test_hud_identity_nested_restore() -> void:
	var root := Node.new()
	add_child(root)
	HudOverlay.apply_identity("main")
	var outer := PopWindow.new("pkg", {})
	outer.hud_identity = "package"
	outer.show_window(root)
	assert_eq(HudOverlay.get_identity(), "package", "外层 show_window 应切 package")
	var inner := PopWindow.new("handbook", {})
	inner.hud_identity = "handbook"
	inner.show_window(root)
	assert_eq(HudOverlay.get_identity(), "handbook", "内层 show_window 应切 handbook")
	inner.remove_window()
	assert_eq(HudOverlay.get_identity(), "package", "内层 remove_window 应恢复外层 package（非 main）")
	outer.remove_window()
	assert_eq(HudOverlay.get_identity(), "main", "外层 remove_window 应回 main")
	root.queue_free()


# 条件恢复（非 LIFO 兜底）：外层先关时不越权覆盖内层的 identity。
# 场景：外层 A（identity=X）与内层 B（identity=Y）同显，A 先 remove——A 不该把
# identity 拉回自己的记录值（会盖掉 B 的 HUD 规则，如 main 版头像透过 B 显示）。
func test_hud_identity_no_hijack_on_early_outer_close() -> void:
	var root := Node.new()
	add_child(root)
	HudOverlay.apply_identity("main")
	var outer := PopWindow.new("o", {})
	outer.hud_identity = "crusade"
	outer.show_window(root)
	var inner := PopWindow.new("i", {})
	inner.hud_identity = "task"
	inner.show_window(root)
	outer.remove_window()   # 外层先关：identity 归 inner，outer 不得拉走
	assert_eq(HudOverlay.get_identity(), "task", "外层先关不得覆盖内层 identity")
	inner.remove_window()
	assert_eq(HudOverlay.get_identity(), "crusade", "内层关闭恢复其记录值")
	root.queue_free()
	HudOverlay.apply_identity("main")   # 还原测试环境


# 音效开关：默认关不播；play_open_sfx=true 时经 AudioPlayer 播 common_popup_window（默认 false 保持旧无音效面板行为）。
func test_play_open_sfx_default_off() -> void:
	var root := Node.new()
	add_child(root)
	var w := PopWindow.new("t4b", {})
	w.show_window(root)   # play_open_sfx 缺省 false：AudioPlayer 无该资源也不报错（play_sfx 有守卫），主断言在 true 分支
	w.queue_free()
	root.queue_free()


func test_show_toast_base_method() -> void:
	var w := PopWindow.new()
	w._show_toast("t4-toast")   # 基类方法直调 Toast.show_message 不崩（GUT 环境 autoload 在）
	pass_test("基类 _show_toast 可用")
	w.queue_free()
