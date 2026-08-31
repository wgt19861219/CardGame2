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
# 源 :1241 speedBtn:setPosition(ccp(735,120)) 是 MenuItemImage 锚点中心；贴图 105×60 原尺寸显示
# （MenuItemImage 不÷CS，源 battle_scene.lua:1236 直载）。Godot position=左上角 → 中心减半尺寸。
const GODOT_POS: Vector2 = Vector2(682.5, 330.0)  # 中心 to_godot(735,120)=(735,360) −(105/2,60/2)
const MAX_STATE: int = 4
const SPEED_LABELS := ["1x", "2x", "3x", "4x"]
# 倍速档持久化（源 battle_scene.lua:14/1050 CCUserDefault "battle_speed_state" 等价，
# 照 AudioPlayer sound_cfg 应用级 ConfigFile 范式，不入玩家存档）。
# cfg_path 可注入：测试换 user://battle_test.cfg 隔离玩家真实档（多测试共享 user:// 会互踩）。
const SPEED_CFG_PATH: String = "user://battle.cfg"
var cfg_path: String = SPEED_CFG_PATH

signal speed_changed(state: int)

var _state: int = 1
var _btn: TextureButton = null
var _label: Label = null


func setup(initial_state: int = 1) -> void:
	position = GODOT_POS
	_state = _load_speed_state(initial_state)
	var content := CONTENT_SCENE.instantiate()
	add_child(content)   # Control 组件 content 挂 panel 自身（坑 7，原点 = panel 自身）
	_btn = content.get_node("%Btn") as TextureButton
	_label = content.get_node("%Label") as Label
	if _btn != null:
		_btn.pressed.connect(_on_pressed)
	_apply_state()


func _on_pressed() -> void:
	_state = 1 if _state >= MAX_STATE else _state + 1
	_apply_state()
	_save_speed_state()
	speed_changed.emit(_state)


# 读持久化档（源 :14-15：UserDefault 读，<1 或 >4 越界回 1，非 clamp 边界）。
func _load_speed_state(fallback: int) -> int:
	var v: int = fallback
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) == OK:
		v = int(cfg.get_value("battle", "speed_state", fallback))
	if v < 1 or v > MAX_STATE:
		v = 1
	return v


# 切档写回（源 :1050 setIntegerForKey 持久化，跨战斗/跨启动保留）。
func _save_speed_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("battle", "speed_state", _state)
	cfg.save(cfg_path)


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


func _load_texture(state: int) -> Texture2D:
	var suffix: String = "1" if state == 1 else "2"
	var path: String = TEXTURE_DIR + suffix + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func get_state() -> int:
	return _state
