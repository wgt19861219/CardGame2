class_name BattlePauseLayer
extends ColorRect

## 战斗暂停面板（View 层）— 照源 battle_scene.lua:178-330 createPauseLayer/doPauseLayerTouch。
## 黑半透全屏背景 + 三按钮（exit 退出 / sound 音效切换 / resume 恢复）+ 缩放进场/退场动画。
## 挂 ui_layer（scene 创建）。发 exit_requested/resume_requested/sound_toggled 信号。
## 源 doPauseLayerTouch 手动触摸分发 → Godot TextureButton.pressed 直连（引擎适配简化）。

const TEXTURE_DIR: String = "res://assets/ui/alpha/HVGA/"
const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 150.0 / 255.0)  # 源 :216 ccc4(0,0,0,150)
const VIEW_SIZE: Vector2 = Vector2(960.0, 640.0)             # HVGA
const CENTER: Vector2 = Vector2(480.0, 320.0)
const BTN_POS_EXIT: Vector2 = Vector2(255.0, 265.0)          # 源 :232
const BTN_POS_SOUND: Vector2 = Vector2(400.0, 265.0)         # 源 :252
const BTN_POS_RESUME: Vector2 = Vector2(545.0, 265.0)        # 源 :288
const LABEL_Y: float = 180.0                                  # 源 :247/283/316
const ENTER_DURATION: float = 0.2                             # 源 :320 CCScaleTo(0.2,1) EaseBackOut
const EXIT_DURATION: float = 0.2                              # 源 :299 CCScaleTo(0.2,0) EaseBackIn

signal exit_requested
signal resume_requested
signal sound_toggled

var _container: Control = null
var _sound_btn: TextureButton = null
var _sound_on: bool = true
var _label_y_godot: float = 0.0   # LABEL_Y 经 to_godot 翻 Y（源 800×480→Godot 960×640）


# 源 createPauseLayer（:206-330）。sound_on：当前音效开关（决定初始 sound 按钮贴图，源 :257-263）。
func setup(ui_layer: Node, sound_on: bool) -> void:
	color = BG_COLOR
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截下层点击（源 pauseLayer 触摸吞）
	position = Vector2.ZERO
	size = VIEW_SIZE
	ui_layer.add_child(self)
	_container = Control.new()
	_container.position = Vector2.ZERO
	_container.size = VIEW_SIZE
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.pivot_offset = CENTER   # 缩放绕中心（源 pauseContainer anchor 0.5,0.5）
	add_child(_container)
	_sound_on = sound_on
	_label_y_godot = BattleViewCoords.to_godot(0.0, LABEL_Y).y
	var _exit_pos: Vector2 = BattleViewCoords.to_godot(BTN_POS_EXIT.x, BTN_POS_EXIT.y)
	var _sound_pos: Vector2 = BattleViewCoords.to_godot(BTN_POS_SOUND.x, BTN_POS_SOUND.y)
	var _resume_pos: Vector2 = BattleViewCoords.to_godot(BTN_POS_RESUME.x, BTN_POS_RESUME.y)
	# 源 :230-249 exit（back2mapbtn @ 255,265）
	_add_button("exit", "back2mapbtn.png", _exit_pos, "_on_exit_pressed")
	_add_label("退出战斗", _exit_pos.x)
	# 源 :250-285 sound（sound_on/off 按当前开关 @ 400,265）
	var sound_tex: String = "sound_on.png" if _sound_on else "sound_off.png"
	_sound_btn = _add_button("sound", sound_tex, _sound_pos, "_on_sound_pressed")
	_add_label("音效", _sound_pos.x)
	# 源 :286-318 resume（resume_battle @ 545,265）
	_add_button("resume", "resume_battle.png", _resume_pos, "_on_resume_pressed")
	_add_label("继续战斗", _resume_pos.x)
	# 源 :319-328 进场缩放（scale 0→1，EaseBackOut）
	_container.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(_container, "scale", Vector2.ONE, ENTER_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# 源 :230-249/286-292 按钮（sprite + press sprite + handler）。返 TextureButton 供 sound 动态切贴图。
func _add_button(btn_name: String, tex: String, pos: Vector2, method: String) -> TextureButton:
	var btn := TextureButton.new()
	btn.name = btn_name
	btn.texture_normal = _load(tex)
	btn.position = pos
	btn.pressed.connect(Callable(self, method))
	_container.add_child(btn)
	return btn


func _add_label(text: String, x: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(x, _label_y_godot)
	_container.add_child(lbl)


# 源 :240-245 exit handler → ed.scene.exit()
func _on_exit_pressed() -> void:
	exit_requested.emit()


# 源 :267-281 sound handler → turnSoundSwitch + swap 贴图
func _on_sound_pressed() -> void:
	_sound_on = not _sound_on
	if _sound_btn != null:
		_sound_btn.texture_normal = _load("sound_on.png" if _sound_on else "sound_off.png")
	sound_toggled.emit()


# 源 :296-313 resume handler → resetMusicVolume + resumeBattle + 缩放退场移除
func _on_resume_pressed() -> void:
	var t := create_tween()
	t.tween_property(_container, "scale", Vector2.ZERO, EXIT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
	resume_requested.emit()


func _load(tex: String) -> Texture2D:
	var path: String = TEXTURE_DIR + tex
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
