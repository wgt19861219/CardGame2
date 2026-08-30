class_name PopWindow
extends Control

## 弹窗 MVC 基类（View 层）— 照源 ui/popwindow/popwindow.lua 翻译（Phase 7 起步，2026-07-02）。
## Control 全屏 + shade ColorRect（黑半透遮罩）+ container（内容层）+ show/remove + 生命周期回调。
## onEnterHandlers/onExitHandlers。Godot：shade mouse_filter STOP(swallow)/IGNORE + _enter_tree/_exit_tree。

const DEFAULT_SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 150.0 / 255.0)
# 弹窗缩放入场（源 EaseBackOut 0.2s）：container scale 0→1，pivot 居中。
const SCALE_IN_DUR: float = 0.2
# 打开弹窗音效名（源 common_popup_window；play_open_sfx 开关控制）。
const OPEN_SFX_NAME: String = "common_popup_window"

var identity: String = ""
var param: Dictionary = {}
var shade_layer: ColorRect = null
var container: Control = null
var _on_enter_handlers: Array[Callable] = []
var _on_exit_handlers: Array[Callable] = []
var _swallow: bool = true
# --- T4 样板收敛（审查报告-架构评估与重构方案-2026-08-14 阶段一；默认值保持旧默认行为，子类按需置位）---
# 打开弹窗音效（原 10 份 register_on_enter(func(): AudioPlayer.play_sfx(...)) 样板上收；默认关）。
var play_open_sfx: bool = false
# shade 全透明且不吞点击（原 10 文件静态 shade_layer.color.a=0 + IGNORE hack；pushScene 型面板 tscn 已带全屏 bg）。
var transparent_shade: bool = false
# 点击 shade 是否关闭弹窗（true=旧行为点外关闭；false=吞点击但不关，对齐源 popwindow.lua
# 各面板 cfg 默认无点外关闭——herodetail {touch_priority=-130} 无 not_swallow/no_shade，
# 源 CCLayerColor 黑半透只吞点击，关闭仅靠按钮。2026-08-29 用户反馈点详情页任意位置误返回）。
var shade_close_on_click: bool = true
# HudOverlay identity（非空时 show_window 切换 / remove_window 恢复打开前记录值；
# 原 8 份 remove_window override 样板。嵌套弹窗（如 package→handbook）关内层恢复外层
# identity 而非硬编码 main，否则 main 版含头像 HUD 透过外层弹窗显示（2026-08-20 用户反馈）。
# 动态 identity/恢复的面板（battle_prepare 记 _prev_identity、package 构造传入）不适用，保留各自 override）。
var hud_identity: String = ""
var _hud_identity_prev: String = "main"   # show_window 打开前 identity（remove 恢复用；默认 main=旧行为兜底）


func _init(p_identity: String = "", p_param: Dictionary = {}) -> void:
	identity = p_identity
	param = p_param


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	shade_layer = ColorRect.new()
	shade_layer.color = DEFAULT_SHADE_COLOR
	shade_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade_layer.mouse_filter = Control.MOUSE_FILTER_STOP if _swallow else Control.MOUSE_FILTER_IGNORE
	if transparent_shade:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade_layer)
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 2026-08-18 用户实跑修复：container 根挂（shade 兄弟）——原 shade 子挂时，
	# 嵌套非模态浮层（如 package 内 equipboard，自身全 IGNORE 穿透）的点击会被宿主
	# 全屏 STOP 的 shade 截走，宿主内容层（格子等）永远收不到（源 package 系 pushScene
	# 场景无遮罩概念）。根挂后内容层在 shade 之上：内容命中→处理；空白区穿到 shade→
	# 点外关闭，语义与原等价（container 全屏 IGNORE 不挡 shade 命中）。
	add_child(container)
	# 点击遮罩区域关闭弹窗（手游常见交互）。shade STOP 吞点击，gui_input 捕获后 remove_window。
	# shade_close_on_click=false 时（对齐源 herodetail 等）仍吞点击但不触发关闭。
	shade_layer.gui_input.connect(_on_shade_clicked)


# 点击遮罩区域（弹窗外）→ 关闭弹窗（shade_close_on_click=false 时仅吞点击不关，对齐源）。
func _on_shade_clicked(event: InputEvent) -> void:
	if not shade_close_on_click:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		remove_window()


func show_window(parent: Node) -> void:
	if parent == null:
		return
	if shade_layer == null:
		setup()
	parent.add_child(self)
	# 弹窗置顶（z_index=100 高于英雄详情 BaseLayer z=1/tab z=2，避免被挡）。
	# 源靠 mainLayer z=120 + animLayer z=50；Godot 用 z_index 统一处理，100 兜底所有面板层级。
	z_index = 100
	z_as_relative = false
	if play_open_sfx:
		AudioPlayer.play_sfx(OPEN_SFX_NAME)
	if hud_identity != "":
		_hud_identity_prev = HudOverlay.get_identity()
		HudOverlay.apply_identity(hud_identity)
	for h in _on_enter_handlers:
		h.call()


func remove_window() -> void:
	# 条件恢复：仅当 identity 仍归本面板时恢复记录值——嵌套面板外层先关时不越权
	# 覆盖内层 identity（否则外层恢复值会把内层的 HUD 规则拉错，如 main 版头像透显）。
	if hud_identity != "" and HudOverlay.get_identity() == hud_identity:
		HudOverlay.apply_identity(_hud_identity_prev)
	for h in _on_exit_handlers:
		h.call()
	queue_free()


## Toast 提示（原 7 份逐字复制的反射版 _show_toast 收敛；GUT 环境 Toast autoload 常在，直调）。
func _show_toast(text: String) -> void:
	Toast.show_message(text)


func register_on_enter(handler: Callable) -> void:
	_on_enter_handlers.append(handler)


func register_on_exit(handler: Callable) -> void:
	_on_exit_handlers.append(handler)


func set_swallow(swallow: bool) -> void:
	_swallow = swallow
	if shade_layer != null:
		shade_layer.mouse_filter = Control.MOUSE_FILTER_STOP if _swallow else Control.MOUSE_FILTER_IGNORE


## shade 点击关闭开关（false=吞点击不关，对齐源 herodetail 无点外关闭；默认 true 保持旧行为）。
func set_shade_close_on_click(enabled: bool) -> void:
	shade_close_on_click = enabled


# 弹窗缩放入场（源 EaseBackOut 0.2s scale 0→1）。在 register_on_enter 回调里调用。
# 直接 scale container（全屏 anchor，pivot 取屏幕中心），所有子节点（Bg/按钮）按比例从中心放大。
# Godot 无 Ease.BACK_OUT 直接 ease_name，用 set_trans/set_ease 等价（TRANS_BACK + EASE_OUT）。
func play_scale_in() -> void:
	if container == null or not is_instance_valid(container):
		return
	# container 进入 tree 后 size 已 layout（= 屏幕实际大小），pivot=屏幕中心。
	container.pivot_offset = container.size * 0.5
	container.scale = Vector2.ZERO
	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(container, "scale", Vector2.ONE, SCALE_IN_DUR)
