class_name BattleSpeedButton
extends Control

## 战斗加速按钮（View 层）— 照源 battle_scene.lua:1032-1061（handler）/1235-1250（装配）。
## 点击循环速度档 1→2→3→4→1；档 1 显 CombatAcceleration_1.png 无 label，
## 档 2-4 显 _2.png + 黄色倍率 label（源 updateSpeedBtnLabel）。发 speed_changed(state) 给 scene。
##
## 重构（2026-07-18，hero_detail 范式）：TextureButton + Label 静态化进
## scenes/battle/battle_speed_button_content.tscn（label pos/color 固化 theme_override），
## Control 组件 content 挂 panel 自身（坑 7）。setup instantiate + get_node("%Xxx") as
## 取节点 + _apply_state fill（texture_normal 切图 + label visible/text 切换，坑 5 常驻不再 free+重建）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/battle_speed_button_content.tscn")
const TEXTURE_DIR: String = "res://assets/ui/alpha/HVGA/CombatAcceleration_"
const BUTTON_POS: Vector2 = Vector2(735.0, 120.0)    # 源 :1240 ccp(735,120)
const MAX_STATE: int = 4
# 源 :1031 speedLabels = {[1]="1x",[2]="2x",[3]="3x",[4]="4x"}
const SPEED_LABELS := ["1x", "2x", "3x", "4x"]

signal speed_changed(state: int)

var _state: int = 1
var _btn: TextureButton = null
var _label: Label = null


# 源 resetUI 装配 speedBtn（:1235-1243）：setPosition(735,120) + registerScriptTapHandler(speedBtnHandler)。
func setup(initial_state: int = 1) -> void:
	position = BattleViewCoords.to_godot(BUTTON_POS.x, BUTTON_POS.y)
	_state = clampi(initial_state, 1, MAX_STATE)
	var content := CONTENT_SCENE.instantiate()
	add_child(content)   # Control 组件 content 挂 panel 自身（坑 7，原点 = panel 自身）
	_btn = content.get_node("%Btn") as TextureButton
	_label = content.get_node("%Label") as Label
	if _btn != null:
		_btn.pressed.connect(_on_pressed)
	_apply_state()


# 源 speedBtnHandler（:1047-1061）：curSpeedState>=4 → 1 else +1 + updateSpeedBtnLabel + 同步（同步在 scene 端）。
func _on_pressed() -> void:
	_state = 1 if _state >= MAX_STATE else _state + 1
	_apply_state()
	speed_changed.emit(_state)


# 源 updateSpeedBtnLabel（:1032-1046）：state==1 显 _1.png 无 label，else _2.png + 黄 label。
# 重构：texture_normal 切图 + label visible/text 切换（坑 5 常驻 .tscn，不再 free+重建）。
func _apply_state() -> void:
	if _btn != null:
		_btn.texture_normal = _load_texture(_state)
	if _label != null:
		if _state == 1:
			_label.visible = false
		else:
			_label.text = String(SPEED_LABELS[_state - 1])
			_label.visible = true


# 源 :1037/1039 setNormalImage(CombatAcceleration_1 或 _2.png)
func _load_texture(state: int) -> Texture2D:
	var suffix: String = "1" if state == 1 else "2"
	var path: String = TEXTURE_DIR + suffix + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func get_state() -> int:
	return _state
