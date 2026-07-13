class_name TutorialGuideView
extends PopWindow

## 新手引导 UI（View 层）— 照源 tutorialmaker 框架最小重建（2026-07-02）。
## tutorialmaker/tutorialres Cocos UI 节点树缺（同 UIRes 阻塞）→ 代码重建最小：
##   当前步骤 Label + next/skip 按钮 + 信号。
## 留续（源 maker 大模块）：步骤高亮(定位 UI 元素)+对话气泡(tutorialDialog)+fadeIn/Out 动画+触摸拦截(touchHandler)。

const LABEL_POS: Vector2 = Vector2(360.0, 200.0)
const NEXT_BTN_POS: Vector2 = Vector2(400.0, 300.0)
const SKIP_BTN_POS: Vector2 = Vector2(800.0, 50.0)
const BTN_SIZE: Vector2 = Vector2(80.0, 40.0)
const BUBBLE_TEX := "res://assets/ui/alpha/HVGA/tutorial_bubble_big.png"
const HEAD_TEX := "res://assets/ui/alpha/HVGA/tutorial_head_cm.png"
const BUBBLE_POS: Vector2 = Vector2(300.0, 130.0)
const BUBBLE_SIZE: Vector2 = Vector2(360.0, 180.0)
const HEAD_POS: Vector2 = Vector2(230.0, 150.0)
const HEAD_SIZE: Vector2 = Vector2(90.0, 110.0)
const FADE_DURATION: float = 0.3                    # 源 tutorialmaker fadeIn/Out 动画时长
const FINGER_TEX := "res://assets/ui/alpha/HVGA/tutorial_finger.png"

var tutorial: TutorialManager = null
var step_label: Label = null
var _circle: Sprite2D = null       # 源 tutorial_circle（高亮圆环）
var _finger: Sprite2D = null       # 源 tutorial_finger（指向手）
var _circle_tween: Tween = null

signal step_advanced
signal tutorial_skipped


func setup_panel(p_tutorial: TutorialManager) -> void:
	tutorial = p_tutorial
	setup()
	_create_skip_button()
	_create_step_label()
	_create_next_button()
	_refresh()
	modulate.a = 0.0
	register_on_enter(func() -> void:   # 源 fadeIn（enter 时触发，Panel 在树内 Tween 才运行）
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, FADE_DURATION))


func _create_skip_button() -> void:
	var btn := Button.new()
	btn.text = "跳过引导"
	btn.position = SKIP_BTN_POS
	btn.size = BTN_SIZE
	btn.pressed.connect(_on_skip)
	container.add_child(btn)


func _create_step_label() -> void:
	# 源 tutorialDialog：bubble 背景 + head 头像（dialog_head_side left）+ 文字
	var bubble := TextureRect.new()
	bubble.texture = _load_tex(BUBBLE_TEX)
	bubble.position = BUBBLE_POS
	bubble.size = BUBBLE_SIZE
	bubble.ignore_texture_size = true
	bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	container.add_child(bubble)
	var head := TextureRect.new()
	head.texture = _load_tex(HEAD_TEX)
	head.position = HEAD_POS
	head.size = HEAD_SIZE
	head.ignore_texture_size = true
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	container.add_child(head)
	step_label = Label.new()
	step_label.position = LABEL_POS
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(step_label)


## 资源安全加载。
static func _load_tex(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null


func _create_next_button() -> void:
	var btn := Button.new()
	btn.text = "下一步"
	btn.position = NEXT_BTN_POS
	btn.size = BTN_SIZE
	btn.pressed.connect(_on_next)
	container.add_child(btn)


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
		_fade_out_and_remove()   # 源 tutorial 完成自动 destroy
		return
	var desc: String = TutorialData.get_description(step)
	step_label.text = "当前步骤：" + String(step) + "\n" + desc if desc != "" else "当前步骤：" + String(step)
	_update_highlight(step)   # 源 tutorialmaker getFinger：finger type 步骤显示 circle + finger 高亮


# 源 tutorialmaker fadeOut 动画（close 时 modulate:a → 0 + remove）。
func _fade_out_and_remove() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tw.tween_callback(remove_window)


# 源 tutorialmaker getFinger（:151-178）：finger type 步骤在 circle_center 显示 circle（缩放脉冲）
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
		container.add_child(_circle)
		# 源 :155-158 circle 缩放脉冲动画（CCScaleBy 循环）
		_circle_tween = create_tween().set_loops()
		_circle_tween.tween_property(_circle, "scale", Vector2(base_scale * 1.1, base_scale * 1.1), 0.6).set_trans(Tween.TRANS_SINE)
		_circle_tween.tween_property(_circle, "scale", Vector2(base_scale, base_scale), 0.6).set_trans(Tween.TRANS_SINE)
	if ResourceLoader.exists(FINGER_TEX):
		_finger = Sprite2D.new()
		_finger.texture = load(FINGER_TEX)
		_finger.position = pos + Vector2(-4.0, 4.0)   # 源 :161 ccp(x-4, y+4)
		container.add_child(_finger)
