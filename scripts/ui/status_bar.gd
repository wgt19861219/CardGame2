class_name StatusBar
extends Control

## 顶部状态栏（View 层）— 照源 ui/statusbar.lua 简化（Phase 7，2026-07-02）。
## 显示 diamond/vitality/team_level。源复杂（货币/体力/等级/VIP 多元素）。

const DISPLAY_KEYS: Array[String] = ["diamond", "vitality", "team_level"]  # 单机去 VIP 限制（2026-09-08）：vip_level 行退役
const LABEL_X_START: float = 50.0
const LABEL_X_STEP: float = 150.0
const LABEL_Y: float = 10.0

var player: PlayerData = null
var _labels: Dictionary = {}
var _crusade_label: Label = null


func setup(p_player: PlayerData) -> void:
	player = p_player
	_create_labels()
	refresh()


func _create_labels() -> void:
	var x: float = LABEL_X_START
	for key in DISPLAY_KEYS:
		var lbl := Label.new()
		lbl.position = Vector2(x, LABEL_Y)
		add_child(lbl)
		_labels[key] = lbl
		x += LABEL_X_STEP
	_crusade_label = Label.new()
	_crusade_label.position = Vector2(x, LABEL_Y)
	add_child(_crusade_label)


func refresh() -> void:
	if player == null:
		return
	for key in _labels:
		var lbl: Label = _labels[key]
		lbl.text = key + ": " + str(int(player.get(key)))
	if player.crusade_manager != null:
		_crusade_label.text = "远征: " + str(player.crusade_manager.cur_stage) + "/" + str(CrusadeData.MAX_STAGE)
