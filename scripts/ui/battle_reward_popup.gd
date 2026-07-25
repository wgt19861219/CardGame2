class_name BattleRewardPopup
extends PopWindow

## 战斗结算奖励弹窗（照源 crusade.lua showRewardResult :344-394）。
## gold/crusadepoint 货币 Label + item ReadequipIcon + 关闭按钮。
##
## 重构（2026-07-18，hero_detail 范式）：CloseBtn 静态化进
## scenes/ui/battle_reward_popup_content.tscn（位置/size 编辑器可视化调）；
## reward items（数量随 rewards 变）保留 procedural 挂 %RewardHost。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/battle_reward_popup_content.tscn")
const REWARD_ORIGIN: Vector2 = Vector2(200.0, 200.0)
const CELL: Vector2 = Vector2(110.0, 110.0)   # 网格步距
const REWARD_COLS: int = 5
const GOLD_KEY: String = "gold"
const CRUSADE_POINT_KEY: String = "CrusadePoint"
const EXP_KEY: String = "exp"

var _content: Control = null              # .tscn 根（%RewardHost/%CloseBtn 持有者）
var _reward_host: Control = null          # .tscn %RewardHost（reward 节点容器）


func setup_rewards(rewards: Array, p_cm: Variant) -> void:
	setup()
	_build_content()
	_show_rewards(rewards, p_cm)


# panel 层从 .tscn instantiate（CloseBtn 位置 .tscn 固化）+ connect close。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_reward_host = _content.get_node("%RewardHost") as Control
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)


func _show_rewards(rewards: Array, p_cm: Variant) -> void:
	var idx: int = 0
	for r in rewards:
		var stype: String = String(r.get("type", ""))
		var amount: int = int(r.get("amount", 0))
		var node: Control = _reward_node(stype, amount, int(r.get("id", 0)), p_cm)
		node.position = _reward_pos(idx)
		_reward_host.add_child(node)
		idx += 1


func _reward_node(stype: String, amount: int, id: int, p_cm: Variant) -> Control:
	if stype == "Item":
		return ReadequipIcon.create_icon(id, amount, p_cm)
	var lbl := Label.new()
	lbl.text = _currency_label(stype, amount)
	return lbl


func _currency_label(stype: String, amount: int) -> String:
	if stype == CRUSADE_POINT_KEY:
		return "远征币 x" + str(amount)
	if stype == GOLD_KEY:
		return "金币 x" + str(amount)
	if stype == EXP_KEY:
		return "经验 x" + str(amount)
	return stype + " x" + str(amount)


func _reward_pos(index: int) -> Vector2:
	var col: int = index % REWARD_COLS
	var row: int = index / REWARD_COLS
	return Vector2(REWARD_ORIGIN.x + CELL.x * col, REWARD_ORIGIN.y + CELL.y * row)
