extends GutTest
# HUD 遮蔽通用治理守卫（2026-09-08，P1）——PopWindow 弹窗栈驱动 HudOverlay 局部黑罩，
# 替代 HUD_HIDDEN_IDENTITIES 打地鼠（旧模式每弹窗须"清单+接线"两处手工登记，已 7 处）。
# 规则（源语义）：hud_identity 空 = 纯弹窗（源 scene/mainLayer 级 z≥100 一律盖 HUD，
# 黑遮罩罩住 statusbar 隐约可见+不可点）→ 遮蔽；hud_identity 非空 = 场景模拟型弹窗
# （源 pushScene 场景，HUD 版式属场景语义、货币条清晰可见）→ 不遮蔽；
# hud_occlude=false = 显式例外（源刻意低于 statusbar 的悬浮板，如 equipboardofpackage z=0）。

var _old_player: Variant = null
var _root: Node = null


func before_all() -> void:
	_old_player = GameData.player
	GameData.player = PlayerData.new(ConfigManager.new())
	HudOverlay._built = false   # 若先跑测试已置 true，按本套件环境重建


func after_all() -> void:
	GameData.player = _old_player
	HudOverlay.set_occluded(false)
	HudOverlay.apply_identity("main")
	HudOverlay._built = false   # 交还全局（后续测试按自身环境重建）


func before_each() -> void:
	_root = Node.new()
	add_child(_root)
	HudOverlay.set_occluded(false)
	HudOverlay.apply_identity("main")


func after_each() -> void:
	HudOverlay.set_occluded(false)
	_root.queue_free()


# ① 纯弹窗 show → HUD 遮蔽（容器压暗 + 子树禁点）；remove → 恢复（白色 + 可点）。
func test_pure_popup_occludes_and_restores() -> void:
	var sub: Panel = HudOverlay._status_parent_sub
	var bar: Control = sub.get_child(0)   # 首个货币条（金币条整条 STOP 可点→midas）
	var bar_filter_orig: int = bar.mouse_filter   # 原值须在遮蔽前置位前读
	var w := PopWindow.new("occl1", {})
	w.show_window(_root)
	assert_true(HudOverlay.is_occluded(), "纯弹窗（hud_identity 空）show → HUD 遮蔽")
	assert_false(HudOverlay.OCCLUDED_MODULATE == Color.WHITE, "常量自检：遮蔽色≠白")
	assert_eq(sub.modulate, HudOverlay.OCCLUDED_MODULATE, "sub 版容器压暗（源黑遮罩罩 statusbar 等价）")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "货币条子树禁点（点击穿到弹窗层）")
	w.remove_window()
	assert_false(HudOverlay.is_occluded(), "remove → 解除遮蔽")
	assert_eq(sub.modulate, Color.WHITE, "容器恢复亮色")
	assert_eq(bar.mouse_filter, bar_filter_orig, "货币条恢复原 mouse_filter（可点）")


# ② 场景模拟型（hud_identity 非空，源 pushScene 场景族）不遮蔽。
func test_scene_popup_does_not_occlude() -> void:
	var w := PopWindow.new("occl2", {})
	w.hud_identity = "crusade"
	w.show_window(_root)
	assert_false(HudOverlay.is_occluded(), "场景模拟型（hud_identity 非空）不遮蔽 HUD")
	w.remove_window()


# ③ 显式例外 hud_occlude=false（源悬浮板族：equipboardofpackage / dungeon 系）。
func test_explicit_optout_not_occlude() -> void:
	var w := PopWindow.new("occl3", {})
	w.hud_occlude = false
	w.show_window(_root)
	assert_false(HudOverlay.is_occluded(), "hud_occlude=false 显式例外不遮蔽")
	w.remove_window()


# ④ 嵌套深度感知：外层纯弹窗 + 内层场景型 → 仍遮蔽（外层在栈）；关内层仍遮蔽；栈空解除。
func test_nested_stack_depth_aware() -> void:
	var outer := PopWindow.new("occl4a", {})
	outer.show_window(_root)
	var inner := PopWindow.new("occl4b", {})
	inner.hud_identity = "crusade"
	inner.show_window(_root)
	assert_true(HudOverlay.is_occluded(), "嵌套：外层纯弹窗在栈 → 仍遮蔽")
	inner.remove_window()
	assert_true(HudOverlay.is_occluded(), "关内层：外层仍在栈 → 仍遮蔽")
	outer.remove_window()
	assert_false(HudOverlay.is_occluded(), "栈空 → 解除")


# ⑤ 全隐 identity（battle 族）下遮蔽态置位（modulate/禁点对不可见容器无视觉副作用——
# 不存在"黑条悬空"问题，modulate 挂容器自身随显隐）。
func test_hidden_identity_no_occluder_visual() -> void:
	HudOverlay.apply_identity("battle")
	var w := PopWindow.new("occl5", {})
	w.show_window(_root)
	assert_true(HudOverlay.is_occluded(), "遮蔽态置位")
	assert_eq(HudOverlay._status_parent_sub.visible, false, "battle 全隐：容器不可见（无视觉副作用）")
	w.remove_window()


# ⑥ task/dailyTask 退役守卫：不再进 HUD_HIDDEN_IDENTITIES（源 z=101 scene 级弹窗盖 HUD，
# 通用遮蔽接管——B 族；对照 A 族 handbook/ranklist/equipstrengthen 保留场景无 HUD 语义）。
func test_task_identity_retired_from_hidden_list() -> void:
	HudOverlay.apply_identity("task")
	assert_true(HudOverlay._status_parent_sub.visible, "task 不再全隐 → sub 版货币条显示（后续被弹窗遮罩罩住）")


# ⑦ external 节点（非 PopWindow 全屏页）默认不遮蔽；set_meta("hud_occlude") 声明后联动。
func test_external_meta_occlusion() -> void:
	var ext := Control.new()
	_root.add_child(ext)
	PopWindow.push_external(ext)
	assert_false(HudOverlay.is_occluded(), "external 默认不遮蔽（battle_prepare 走 identity 隐藏）")
	PopWindow.pop_external(ext)
	ext.set_meta("hud_occlude", true)
	PopWindow.push_external(ext)
	assert_true(HudOverlay.is_occluded(), "external meta hud_occlude=true → 遮蔽")
	PopWindow.pop_external(ext)
	ext.queue_free()
