class_name BattleTimer
extends Control

## 战斗计时器（View 层）— 照源 battle_scene.lua:1341-1387（resetUI 装配）/1406-1427（updateTimer）。
## bg（battle_number_bg）+ mask（timermask，<20s 显红闪）+ text（mm:ss Label 适配 createNumbers 数字精灵图缺失）。
## update(time_limit, running) 每帧由 scene 调：seconds=ceil(time_limit)，变化时更新 text + <20s 红 + mask 显。
##
## 重构（2026-07-18，hero_detail 范式）：bg/mask/hourglass 静态节点搬进
## scenes/battle/battle_timer_content.tscn（位置编辑器可视化调），
## Control 组件 content 挂 panel 自身（坑 7）。setup instantiate + get_node("%Xxx") as 取节点；
## 倒计时文本与 mask visible/<20s 红闪保留 fill 动态（update）。
## 坐标源（procedural 现值，BattleViewCoords.to_godot 已烘焙）：
## bg/mask (690,120)=to_godot(610,440)，hourglass (757,123)=to_godot(677,437)，
## text (702,142)=bg_pos+(12,22)（源 TEXT_LOCAL_POS）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/battle_timer_content.tscn")

const WARN_THRESHOLD: int = 20
const WARN_COLOR: Color = Color(1.0, 144.0 / 255.0, 144.0 / 255.0)
const NORMAL_COLOR: Color = Color.WHITE

var _mask: Sprite2D = null
var _text: Label = null
var _value: int = -1


func setup() -> void:
	var content := CONTENT_SCENE.instantiate()
	add_child(content)   # Control 组件 content 挂 panel 自身（坑 7，坐标 = BattleTimer 局部）
	_mask = content.get_node("%Mask") as Sprite2D
	_text = content.get_node("%TimeText") as Label


func update(time_limit: float, running: bool) -> void:
	var seconds: int = int(ceil(time_limit))
	if seconds != _value:
		_value = seconds
		_text.text = "%02d:%02d" % [seconds / 60, seconds % 60]
		if seconds < WARN_THRESHOLD:
			if _mask:
				_mask.visible = true
			_text.add_theme_color_override("font_color", WARN_COLOR)
	if not running:
		if _mask:
			_mask.visible = false
		_text.add_theme_color_override("font_color", NORMAL_COLOR)
