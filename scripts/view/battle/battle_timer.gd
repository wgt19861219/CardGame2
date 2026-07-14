class_name BattleTimer
extends Control

## 战斗计时器（View 层）— 照源 battle_scene.lua:1341-1387（resetUI 装配）/1406-1427（updateTimer）。
## bg（battle_number_bg）+ mask（timermask，<20s 显红闪）+ text（mm:ss Label 适配 createNumbers 数字精灵图缺失）。
## update(time_limit, running) 每帧由 scene 调：seconds=ceil(time_limit)，变化时更新 text + <20s 红 + mask 显。

const TEXTURE_DIR: String = "res://assets/ui/alpha/HVGA/"
const BG_POS: Vector2 = Vector2(610.0, 440.0)         # 源 :1351 ccp(610-ox, header_y)，ox/oy=0
const HOURGLASS_POS: Vector2 = Vector2(677.0, 437.0)  # 源 :1363 ccp(677-ox, header_y-3)
const TEXT_LOCAL_POS: Vector2 = Vector2(12.0, 22.0)   # 源 :1384 ccp(12,22)（bg 内）
const WARN_THRESHOLD: int = 20                        # 源 :1416 seconds<20 红闪
const WARN_COLOR: Color = Color(1.0, 144.0 / 255.0, 144.0 / 255.0)  # 源 :1418 ccc3(255,144,144)
const NORMAL_COLOR: Color = Color.WHITE               # 源 :1424 ccc3(255,255,255)

var _mask: Sprite2D = null
var _text: Label = null
var _value: int = -1   # 源 :1347 timer.value=-1（强制首帧更新）


func setup() -> void:
	var _bg_pos: Vector2 = BattleViewCoords.to_godot(BG_POS.x, BG_POS.y)
	var _hg_pos: Vector2 = BattleViewCoords.to_godot(HOURGLASS_POS.x, HOURGLASS_POS.y)
	var bg: Sprite2D = _load_sprite("battle_number_bg.png")
	if bg:
		bg.position = _bg_pos
		add_child(bg)
	_mask = _load_sprite("timermask.png")
	if _mask:
		_mask.position = _bg_pos   # 源 :1354-1357 mask 覆盖 bg 区域
		_mask.visible = false
		add_child(_mask)
	var hourglass: Sprite2D = _load_sprite("hourglass.png")
	if hourglass:
		hourglass.position = _hg_pos
		add_child(hourglass)
	_text = Label.new()
	_text.position = _bg_pos + TEXT_LOCAL_POS   # 源 text 挂 bg 内 (12,22)
	_text.add_theme_color_override("font_color", NORMAL_COLOR)
	add_child(_text)


# 源 updateTimer（:1406-1427）：seconds=ceil(time_limit)，变化→更新 text+<20s 红+mask 显；!running→还原。
func update(time_limit: float, running: bool) -> void:
	var seconds: int = int(ceil(time_limit))
	if seconds != _value:
		_value = seconds
		_text.text = "%02d:%02d" % [seconds / 60, seconds % 60]   # 源 :1414
		if seconds < WARN_THRESHOLD:
			if _mask:
				_mask.visible = true   # 源 :1417
			_text.add_theme_color_override("font_color", WARN_COLOR)   # 源 :1418
	if not running:
		if _mask:
			_mask.visible = false   # 源 :1423
		_text.add_theme_color_override("font_color", NORMAL_COLOR)   # 源 :1424


func _load_sprite(tex: String) -> Sprite2D:
	var path: String = TEXTURE_DIR + tex
	if not ResourceLoader.exists(path):
		return null
	var s := Sprite2D.new()
	s.texture = load(path) as Texture2D
	return s
