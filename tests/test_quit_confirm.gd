extends GutTest

## 退出确认守卫（2026-10-09 受控增强）：组件行为 + HudOverlay 集成 + 配置/源码防回归。
## _execute_quit 的真实 quit 不在 GUT 跑（会杀测试进程），由源码守卫 + bridge 实测覆盖。


const QuitConfirmScript = preload("res://scripts/ui/quit_confirm.gd")


# ── 组件（QuitConfirm）──────────────────────────────────────────────

func test_component_fallback_texts() -> void:
	var qc: Control = add_child_autofree(QuitConfirmScript.new())
	qc.setup(null)   # cm 未注入 → fallback 中文
	assert_eq((qc.get_node("ShopRefreshConfirmContent/Bg/MsgLabel") as Label).text,
		"确定退出游戏?", "消息文案 fallback=源语言包 tools.exitgame 中文")
	assert_eq((qc.get_node("ShopRefreshConfirmContent/Bg/MsgLabel") as Label).horizontal_alignment,
		HORIZONTAL_ALIGNMENT_CENTER, "文案水平居中（短文案左对齐视觉偏左 91px 实测修正）")
	assert_eq((qc.get_node("ShopRefreshConfirmContent/Bg/CancelBtn") as Button).text,
		"取消", "取消按钮 fallback")
	assert_eq((qc.get_node("ShopRefreshConfirmContent/Bg/OkBtn") as Button).text,
		"确定", "确认按钮 fallback")


func test_component_confirm_emits_and_frees() -> void:
	var qc: Control = add_child_autofree(QuitConfirmScript.new())
	qc.setup(null)
	watch_signals(qc)
	(qc.get_node("ShopRefreshConfirmContent/Bg/OkBtn") as Button).pressed.emit()
	assert_signal_emitted(qc, "confirmed", "点确认 → confirmed 信号")
	assert_true(qc.is_queued_for_deletion(), "点确认 → 自身销毁")


func test_component_cancel_is_silent() -> void:
	var qc: Control = add_child_autofree(QuitConfirmScript.new())
	qc.setup(null)
	watch_signals(qc)
	(qc.get_node("ShopRefreshConfirmContent/Bg/CancelBtn") as Button).pressed.emit()
	assert_signal_not_emitted(qc, "confirmed", "点取消不发 confirmed")
	assert_true(qc.is_queued_for_deletion(), "点取消 → 自身销毁（不退出）")


func test_component_modal_full_rect() -> void:
	var qc: Control = add_child_autofree(QuitConfirmScript.new())
	qc.setup(null)
	assert_eq(qc.mouse_filter, Control.MOUSE_FILTER_STOP, "模态拦截底层点击")
	assert_eq(qc.size, Vector2(800, 480), "拉满全屏（PRESET_FULL_RECT 判例防 size=0 回归）")


# ── HudOverlay 集成 ────────────────────────────────────────────────

func test_hud_show_quit_confirm_opens() -> void:
	var hud: CanvasLayer = get_node("/root/HudOverlay")
	hud.show_quit_confirm()
	await get_tree().process_frame   # add_child 走 call_deferred，等一帧进树
	assert_not_null(hud._quit_confirm, "弹窗已创建")
	assert_true(hud._quit_confirm.is_inside_tree(), "弹窗挂在 HudOverlay（CanvasLayer 150 恒顶层）")
	assert_eq(hud._quit_confirm.get_parent(), hud, "父节点=HudOverlay 本体（不受 identity 三容器显隐影响）")
	_cleanup_quit_confirm(hud)


func test_hud_no_duplicate_on_repeat() -> void:
	var hud: CanvasLayer = get_node("/root/HudOverlay")
	hud.show_quit_confirm()
	await get_tree().process_frame
	var first: Control = hud._quit_confirm
	hud.show_quit_confirm()   # 连按返回键场景
	assert_eq(hud._quit_confirm, first, "已打开时不叠加（防重）")
	_cleanup_quit_confirm(hud)


# ── 配置与源码防回归 ───────────────────────────────────────────────

func test_quit_on_go_back_disabled() -> void:
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back"),
		"quit_on_go_back=false：Android 返回键只发通知不直接退出")


func test_execute_quit_saves_before_quit_source_guard() -> void:
	var f := FileAccess.open("res://scripts/autoload/hud_overlay.gd", FileAccess.READ)
	var src := f.get_as_text()
	f.close()
	assert_string_contains(src, "GameData.save()", "确认路径先存档")
	assert_string_contains(src, "get_tree().quit()", "确认路径后退出")


func _cleanup_quit_confirm(hud: CanvasLayer) -> void:
	if hud._quit_confirm != null and is_instance_valid(hud._quit_confirm):
		hud._quit_confirm.queue_free()
	hud._quit_confirm = null
