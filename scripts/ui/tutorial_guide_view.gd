class_name TutorialGuideView
extends PopWindow

## 新手引导 UI（View 层）— 照源 tutorialmaker 框架最小重建（2026-07-02）。
## tutorialmaker/tutorialres Cocos UI 节点树缺（同 UIRes 阻塞）→ 代码重建最小：
##   当前步骤 Label + next/skip 按钮 + 信号。
## 留续（源 maker 大模块）：步骤高亮(定位 UI 元素)+对话气泡(tutorialDialog)+fadeIn/Out 动画+触摸拦截(touchHandler)。
##
## ⚠️ 受控偏离（用户决策 2026-07-26）：Next/Skip 按钮是本项目自建——源 tutorial.lua/tutorialmaker.lua
## 是引导手指/提示层机制（createCommonFingerLayer/createCommonTipsLayer），无独立 Next/Skip 按钮 UI。
## 保留 Next/Skip 理由：单机化无联机引导手指的多人协同场景，独立按钮交互更友好（优化阶段允许受控偏离）。
##
## 重构（2026-07-18，hero_detail 范式）：静态节点（skip/bubble/head/step label/next btn）位置/size
## 静态化进 scenes/ui/tutorial_guide_view_content.tscn（编辑器可视化调）；
## circle/finger 高亮位置随步骤变，保留 procedural 挂 %HighlightHost（源 tutorialmaker getFinger）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/tutorial_guide_view_content.tscn")
const FADE_DURATION: float = 0.3
const FINGER_TEX := "res://assets/ui/alpha/HVGA/tutorial_finger.png"

var tutorial: TutorialManager = null
var step_label: Label = null
var _host: Control = null           # .tscn %HighlightHost（circle/finger 动态挂）
var _circle: Sprite2D = null
var _finger: Sprite2D = null
var _circle_tween: Tween = null

signal step_advanced
signal tutorial_skipped


func setup_panel(p_tutorial: TutorialManager) -> void:
	tutorial = p_tutorial
	setup()
	_build_content()
	_refresh()
	modulate.a = 0.0
	register_on_enter(func() -> void:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, FADE_DURATION))


# 建 UI 内容。静态节点（skip/bubble/head/step label/next）从 .tscn instantiate + 连信号；
# circle/finger 高亮位置随步骤变，挂 %HighlightHost 保留 procedural。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	step_label = content.get_node("%StepLabel") as Label
	_host = content.get_node("%HighlightHost") as Control
	(content.get_node("%SkipBtn") as BaseButton).pressed.connect(_on_skip)
	(content.get_node("%NextBtn") as BaseButton).pressed.connect(_on_next)


func _on_next() -> void:
	if tutorial == null:
		return
	tutorial.complete_current()
	step_advanced.emit()
	_refresh()


func _on_skip() -> void:
	if tutorial == null:
		return
	tutorial.skip_all()
	tutorial_skipped.emit()
	_fade_out_and_remove()


func _refresh() -> void:
	if tutorial == null:
		return
	var step: StringName = tutorial.current_step()
	if step == &"":
		step_label.text = "引导完成"
		_fade_out_and_remove()
		return
	var desc: String = TutorialData.get_description(step)
	step_label.text = "当前步骤：" + String(step) + "\n" + desc if desc != "" else "当前步骤：" + String(step)
	_update_highlight(step)


func _fade_out_and_remove() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tw.tween_callback(remove_window)


# + finger（指向手 at pos+(-4,4)）。circle png 直径缩放到 circle_radius×2。
func _update_highlight(step: StringName) -> void:
	if _circle != null:
		_circle.queue_free()
		_circle = null
	if _finger != null:
		_finger.queue_free()
		_finger = null
	if _circle_tween != null:
		_circle_tween.kill()
		_circle_tween = null
	var hl: Dictionary = TutorialData.get_highlight(step)
	if hl.is_empty() or String(hl.get("type", "")) != "finger":
		return
	var pos: Vector2 = Vector2(hl.get("circle_center", Vector2.ZERO))
	var radius: float = float(hl.get("circle_radius", 60.0))
	var circle_res: String = String(hl.get("circle_res", "res://assets/ui/alpha/HVGA/tutorial_circle.png"))
	if ResourceLoader.exists(circle_res):
		_circle = Sprite2D.new()
		_circle.texture = load(circle_res)
		_circle.position = pos
		var tex_size: Vector2 = _circle.texture.get_size() if _circle.texture != null else Vector2(128.0, 128.0)
		var base_scale: float = radius * 2.0 / maxf(tex_size.x, 1.0)   # 直径→radius
		_circle.scale = Vector2(base_scale, base_scale)
		_host.add_child(_circle)
		_circle_tween = create_tween().set_loops()
		_circle_tween.tween_property(_circle, "scale", Vector2(base_scale * 1.1, base_scale * 1.1), 0.6).set_trans(Tween.TRANS_SINE)
		_circle_tween.tween_property(_circle, "scale", Vector2(base_scale, base_scale), 0.6).set_trans(Tween.TRANS_SINE)
	if ResourceLoader.exists(FINGER_TEX):
		_finger = Sprite2D.new()
		_finger.texture = load(FINGER_TEX)
		_finger.position = pos + Vector2(-4.0, 4.0)
		_host.add_child(_finger)
