class_name BattlePauseLayer
extends ColorRect

## 战斗暂停面板（View 层）— 照源 battle_scene.lua:178-330 createPauseLayer/doPauseLayerTouch。
## 黑半透全屏背景 + 三按钮（exit 退出 / sound 音效切换 / resume 恢复）+ 缩放进场/退场动画。
## 挂 ui_layer（scene 创建）。发 exit_requested/resume_requested/sound_toggled 信号。
##
## 重构（2026-07-18，hero_detail 范式）：三按钮 + 三 Label 静态化进
## scenes/battle/battle_pause_layer_content.tscn（instantiate + add_child + get_node + fill）。
## ColorRect 根保留 gd 设（color/mouse_filter/size 模态遮罩），content 挂 panel 自身（无 PopWindow container）。
## 动态：sound 按钮初始贴图（sound_on 参数）+ 信号接线 + 进/退场 scale tween（_content pivot=CENTER）。
## 坐标源 800×480 → Godot 960×640 经 BattleViewCoords.to_godot（exit 255,265→335,295 / sound 400,265→480,295
## / resume 545,265→625,295 / label_y 180→380）固化进 .tscn。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/battle_pause_layer_content.tscn")
const TEXTURE_DIR: String = "res://assets/ui/alpha/HVGA/"
const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 150.0 / 255.0)
const VIEW_SIZE: Vector2 = Vector2(960.0, 640.0)             # HVGA
const CENTER: Vector2 = Vector2(480.0, 320.0)
const ENTER_DURATION: float = 0.2
const EXIT_DURATION: float = 0.2

signal exit_requested
signal resume_requested
signal sound_toggled

var _content: Control = null
var _sound_btn: TextureButton = null
var _sound_on: bool = true


func setup(ui_layer: Node, sound_on: bool) -> void:
	color = BG_COLOR
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截下层点击（源 pauseLayer 触摸吞）
	position = Vector2.ZERO
	size = VIEW_SIZE
	ui_layer.add_child(self)
	_sound_on = sound_on
	_build_content()
	_play_enter_tween()


# 建 UI 内容：三按钮 + 三 Label 从 .tscn instantiate（位置/size 可视化调）；fill 动态贴图 + 接信号。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	_content.pivot_offset = CENTER   # 缩放绕中心（源 pauseContainer anchor 0.5,0.5）
	add_child(_content)
	(_content.get_node("%ExitBtn") as TextureButton).pressed.connect(_on_exit_pressed)
	_sound_btn = _content.get_node("%SoundBtn") as TextureButton
	if not _sound_on:
		_sound_btn.texture_normal = _load("sound_off.png")
	_sound_btn.pressed.connect(_on_sound_pressed)
	(_content.get_node("%ResumeBtn") as TextureButton).pressed.connect(_on_resume_pressed)


func _play_enter_tween() -> void:
	_content.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(_content, "scale", Vector2.ONE, ENTER_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_exit_pressed() -> void:
	exit_requested.emit()


func _on_sound_pressed() -> void:
	_sound_on = not _sound_on
	if _sound_btn != null:
		_sound_btn.texture_normal = _load("sound_on.png" if _sound_on else "sound_off.png")
	sound_toggled.emit()


func _on_resume_pressed() -> void:
	var t := create_tween()
	t.tween_property(_content, "scale", Vector2.ZERO, EXIT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
	resume_requested.emit()


func _load(tex: String) -> Texture2D:
	var path: String = TEXTURE_DIR + tex
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
