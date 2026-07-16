class_name ShortcutPanel
extends Control

## 快捷栏抽屉（View 层）— 照源 ui/shortcut.lua（button_info + createButtons + createBoard）
## + framework.lua:42-65 doShortcut / :378-554 popBoard·pushBoard 动画 / :556-658 路由 翻译。
## 屏幕右侧竖排 5 按钮（heroPackage/package/fragment/task/todoList）+ 切换按钮（down/up）+ 抽屉板。
## 收起（板高 40，按钮叠在切换钮位置 opacity=0）/ 展开（板高 460，按钮竖排 opacity=255）。
## Tween 动画 0.12s（源 shortcut_board_pop_time），展开后 shade 点 board 外收起。
## 非常驻弹窗，Control 直接挂场景树（z 等价源 frameworkLayer:100）。坐标源 cocos→Godot y 翻转（边缘 UI 非中心对称）。
## tag 红点角标（源 refreshTags/getCheckSCTagHandler）依赖各类 Logic 判定，第 26+ 段接；本段建节点先全隐藏。

const SCREEN_H: float = 640.0
const BOARD_CENTER_X: float = 900.0             # 源 shortcut_pos_x
# 用户视觉偏好(2026-07-14):快捷栏"更上一点贴近顶部"。整个抽屉上移 100px(板顶 180→80 / toggle 200→100,底部留 100px 空白)。
# 源 uires.lua shortcut_board_pos.y=460 / shortcut_pos_y=440(Cocos 960×640,源贴屏底)→ 偏离源,同 backbtn (113,88)→(20,15) 用户偏好先例。
const BOARD_UP_OFFSET: float = -100.0           # 整个抽屉上移量(负=上,用户偏好;BUTTON_CENTER_Y 已含同 offset)
const BOARD_TOP_Y: float = SCREEN_H - 460.0 + BOARD_UP_OFFSET   # 源板顶 180 + 上移 100 → 80
const BOARD_WIDTH: float = 82.0                 # 源 shortcut_board_width
const BOARD_H_MIN: float = 40.0                 # 源 shortcut_board_height_min（收起）
const BOARD_H_MAX: float = 460.0                # 源 shortcut_board_height_max（展开）
const TOGGLE_CENTER: Vector2 = Vector2(900.0, SCREEN_H - 440.0 + BOARD_UP_OFFSET)   # 源 (900,200) + 上移 100 → (900,100)
# 源 shortcutBoardButtonPosY（已 +s_b_offset_y=-20）[362,287,217,142,63] → Godot [278,353,423,498,577] + BOARD_UP_OFFSET(上移100) → [178,253,323,398,477]
const BUTTON_CENTER_Y: Array[float] = [178.0, 268.0, 358.0, 448.0, 538.0]   # 间距 90（源 70~79 太挤，用户要加大；顶部 178 不变）
const BUTTON_ORIGIN_CENTER: Vector2 = TOGGLE_CENTER   # 收起叠点 = 切换钮位置（源 button_ori_pos）
const ANIM_DUR: float = 0.12                    # 源 shortcut_board_pop_time
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)   # 透明检测区（源 out_board shortcut_board_rect 无视觉 shade，仅点击收起检测）
const TOUCH_WIDTH: float = 100.0                # 源 shortcut_board_touch_width（out_board 检测宽）

# ── 按钮 key + 资源（源 button_info :11-49）──
const BUTTON_KEYS: Array[String] = ["heroPackage", "package", "fragment", "task", "todoList"]
const RES_NORMAL: Dictionary = {
	"heroPackage": "res://assets/ui/alpha/HVGA/main_hero_button.png",
	"package": "res://assets/ui/alpha/HVGA/main_package_button.png",
	"fragment": "res://assets/ui/alpha/HVGA/main_fragment_button.png",
	"task": "res://assets/ui/alpha/HVGA/main_task_button.png",
	"todoList": "res://assets/ui/alpha/HVGA/main_menu_todolist_1.png",
}
const RES_PRESS: Dictionary = {
	"heroPackage": "res://assets/ui/alpha/HVGA/main_hero_button_shade.png",
	"package": "res://assets/ui/alpha/HVGA/main_package_button_shade.png",
	"fragment": "res://assets/ui/alpha/HVGA/main_fragment_button_shade.png",
	"task": "res://assets/ui/alpha/HVGA/main_task_button_shade.png",
	"todoList": "res://assets/ui/alpha/HVGA/main_menu_todolist_2.png",
}
const RES_BOARD: String = "res://assets/ui/alpha/HVGA/main_shortcut_board.png"
const RES_DOWN: String = "res://assets/ui/alpha/HVGA/main_down_button.png"
const RES_UP: String = "res://assets/ui/alpha/HVGA/main_up_button.png"

signal open_requested(key: String)   # 按钮点击 → main_scene 路由（package/fragment→PackagePanel / heroPackage→hero_scene）

var _is_open: bool = false
var _shade: ColorRect = null
var _board: TextureRect = null
var _toggle_down: TextureButton = null
var _toggle_up: TextureButton = null
var _buttons: Dictionary = {}    # key(String) -> TextureButton
var _tween: Tween = null


# 源 createBoard（framework.lua scCreateBoard:256-332）+ createButtons（shortcut.lua:180-254）。
# 初始收起（源 isShortcutOpen = identity=="main"；本项目独立面板默认收起）。
func setup_panel(open_initial: bool = false) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 自身不吞，子节点（shade/board/button）各自 STOP 吞
	_create_shade()
	_create_board()
	_create_toggle()
	_create_buttons()
	if open_initial:
		_apply_open_instant()   # 照源 isShortcutOpen = identity=="main"（主界面默认展开）
	else:
		_apply_closed_instant()


func _create_shade() -> void:
	_shade = ColorRect.new()
	_shade.color = SHADE_COLOR   # 透明（源 out_board 无视觉，仅点击检测）
	# 源 shortcut_board_rect = CCRectMake(board_pos.x - touch_w/2, 0, touch_w, 480)：右侧 board 区局部检测（非全屏 shade）
	_shade.position = Vector2(BOARD_CENTER_X - TOUCH_WIDTH / 2.0, 0.0)
	_shade.size = Vector2(TOUCH_WIDTH, SCREEN_H)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP   # 展开时点 shade（=board 外）→ 收起
	_shade.gui_input.connect(_on_shade_gui_input)
	_shade.visible = false
	add_child(_shade)


func _create_board() -> void:
	_board = TextureRect.new()
	if ResourceLoader.exists(RES_BOARD):
		_board.texture = load(RES_BOARD)
	# 纹理原始尺寸（91×?）会撑大 TextureRect minimum_size 覆盖 size；IGNORE_SIZE + 清 minimum 保 scaleSize 受控（源 Scale9Sprite 等价）。
	_board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_board.custom_minimum_size = Vector2.ZERO
	_board.size = Vector2(BOARD_WIDTH, BOARD_H_MIN)
	# 源 anchor=(0.5,1) 顶边中心；Godot position 左上角 = (center_x - w/2, top_y)
	_board.position = Vector2(BOARD_CENTER_X - BOARD_WIDTH / 2.0, BOARD_TOP_Y)
	_board.mouse_filter = Control.MOUSE_FILTER_STOP   # 板面吞点击（点 board 内空隙不收起）
	add_child(_board)


func _create_toggle() -> void:
	# down（收起显示）/ up（展开显示）同位置（源 down/up 都在 shortcut_pos）。
	_toggle_down = _make_texture_button(RES_DOWN, RES_DOWN)
	_toggle_down.mouse_filter = Control.MOUSE_FILTER_STOP   # 切换钮须可点（_make_texture_button :201 默认 IGNORE 是给收起态 5 按钮的；toggle 须覆盖 STOP，否则点击穿透被 board STOP 吞致无反应）
	_place_center_texture(_toggle_down, TOGGLE_CENTER)
	_toggle_down.pressed.connect(_toggle_open)
	add_child(_toggle_down)
	_toggle_up = _make_texture_button(RES_UP, RES_UP)
	_toggle_up.mouse_filter = Control.MOUSE_FILTER_STOP
	_place_center_texture(_toggle_up, TOGGLE_CENTER)
	_toggle_up.pressed.connect(_toggle_open)
	add_child(_toggle_up)


func _create_buttons() -> void:
	for i in range(BUTTON_KEYS.size()):
		var key: String = BUTTON_KEYS[i]
		var btn := _make_texture_button(String(RES_NORMAL.get(key, "")), String(RES_PRESS.get(key, "")))
		btn.pressed.connect(_on_button_pressed.bind(key))
		add_child(btn)
		_buttons[key] = btn


# 源 doShortcut（framework.lua:42-65）：toggle isShortcutOpen → open/close board。
func _toggle_open() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if _is_open:
		_close()
	else:
		_open()


# 源 openShortcutBoard（framework.lua:532-545）+ popBoard（:440-483）：板高 min→max，按钮 staggered fadeIn+moveTo。
func _open() -> void:
	_is_open = true
	Events.bus.emit_tutorial_step(&"SUopenShortcut")   # 源 framework.lua:595（展开 shortcut）
	_shade.visible = true
	_toggle_down.visible = false
	_toggle_up.visible = true
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_board, "size", Vector2(BOARD_WIDTH, BOARD_H_MAX), ANIM_DUR).set_ease(Tween.EASE_OUT)
	# 按钮 staggered（源 popBoard :466-475 阈值显现；本项目按索引延迟，等价效果）
	for i in range(BUTTON_KEYS.size()):
		var key: String = BUTTON_KEYS[i]
		var btn: TextureButton = _buttons[key]
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var delay: float = i * (ANIM_DUR * 0.2)
		var target_pos: Vector2 = _center_to_topleft(Vector2(BOARD_CENTER_X, BUTTON_CENTER_Y[i]), btn)
		_tween.parallel().tween_property(btn, "position", target_pos, ANIM_DUR * 0.5).set_delay(delay)
		_tween.parallel().tween_property(btn, "modulate:a", 1.0, ANIM_DUR * 0.5).set_delay(delay)


# 源 closeShortcutBoard（framework.lua:547-554）+ pushBoard（:393-423）：板高 max→min，按钮 fadeOut+叠回。
func _close() -> void:
	_is_open = false
	_toggle_down.visible = true
	_toggle_up.visible = false
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_board, "size", Vector2(BOARD_WIDTH, BOARD_H_MIN), ANIM_DUR).set_ease(Tween.EASE_IN)
	var target_pos: Vector2 = _center_to_topleft(BUTTON_ORIGIN_CENTER, _toggle_down)
	for i in range(BUTTON_KEYS.size()):
		var key: String = BUTTON_KEYS[i]
		var btn: TextureButton = _buttons[key]
		_tween.parallel().tween_property(btn, "position", target_pos, ANIM_DUR * 0.4)
		_tween.parallel().tween_property(btn, "modulate:a", 0.0, ANIM_DUR * 0.4)
	_tween.chain().tween_callback(_on_close_finished)


func _on_close_finished() -> void:
	_shade.visible = false
	for key in _buttons:
		(_buttons[key] as TextureButton).mouse_filter = Control.MOUSE_FILTER_IGNORE


# 初始展开态（无动画，照源 isShortcutOpen=main）：板高 max，按钮竖排 opacity=1，up 可见 down 隐藏，shade 透明检测。
func _apply_open_instant() -> void:
	_is_open = true
	_shade.visible = true
	_toggle_down.visible = false
	_toggle_up.visible = true
	_board.size = Vector2(BOARD_WIDTH, BOARD_H_MAX)
	for i in range(BUTTON_KEYS.size()):
		var key: String = BUTTON_KEYS[i]
		var btn: TextureButton = _buttons[key]
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.position = _center_to_topleft(Vector2(BOARD_CENTER_X, BUTTON_CENTER_Y[i]), btn)
		btn.modulate.a = 1.0


# 初始收起态（无动画）：按钮叠 origin opacity=0 + IGNORE，板高 min，down 可见 up 隐藏。
func _apply_closed_instant() -> void:
	var origin_topleft: Vector2 = _center_to_topleft(BUTTON_ORIGIN_CENTER, _toggle_down)
	for key in _buttons:
		var btn: TextureButton = _buttons[key]
		btn.position = origin_topleft
		btn.modulate.a = 0.0
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.size = Vector2(BOARD_WIDTH, BOARD_H_MIN)
	_toggle_up.visible = false
	_toggle_down.visible = true
	_shade.visible = false


# 源 getSCButtonTouchHandler（framework.lua:556-658）：点按钮跳场景。本项目 emit key，main_scene 路由。
func _on_button_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if key == "heroPackage":
		Events.bus.emit_tutorial_step(&"SUclickHeroPackage")   # 源 framework.lua:596（点英雄包按钮）
	open_requested.emit(key)
	_close()   # 选完收起抽屉（源点按钮跳转场景，本项目弹窗后收起）


func _on_shade_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_close()


func _make_texture_button(normal_path: String, press_path: String) -> TextureButton:
	var btn := TextureButton.new()
	if normal_path != "" and ResourceLoader.exists(normal_path):
		btn.texture_normal = load(normal_path)
	if press_path != "" and ResourceLoader.exists(press_path):
		btn.texture_pressed = load(press_path)
	# 不设 ignore_texture_size（默认 false）让按钮按纹理原始尺寸定 size；曾设 true 致 size=0 不可点不可见（@232 实测 size=(0,0)，点击无区域）。
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 收起态默认不可点（_open 时切 STOP）
	return btn


func _place_center_texture(btn: TextureButton, center: Vector2) -> void:
	btn.position = _center_to_topleft(center, btn)


func _center_to_topleft(center: Vector2, btn: TextureButton) -> Vector2:
	return center - _button_size(btn) / 2.0


func _button_size(btn: TextureButton) -> Vector2:
	if btn.texture_normal != null:
		return btn.texture_normal.get_size()
	return Vector2(76.0, 76.0)   # 估算（无纹理降级，Phase 4 校准）


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
