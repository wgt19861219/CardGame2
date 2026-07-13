class_name BattleRewardPopup
extends PopWindow

## 战斗结算奖励弹窗（照源 crusade.lua showRewardResult :344-394）。
## gold/crusadepoint 货币 Label + item ReadequipIcon + 关闭按钮。
## 源 rewardLayer 为 cocos Studio UIRes 构建（UIRes 缺，Godot 用 PopWindow + 节点重建）。

const REWARD_ORIGIN: Vector2 = Vector2(200.0, 200.0)
const CELL: Vector2 = Vector2(110.0, 110.0)   # 网格步距
const REWARD_COLS: int = 5
const CLOSE_BTN_POS: Vector2 = Vector2(400.0, 420.0)
const BTN_SIZE: Vector2 = Vector2(160.0, 49.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const GOLD_KEY: String = "gold"
const CRUSADE_POINT_KEY: String = "CrusadePoint"
const EXP_KEY: String = "exp"


func setup_rewards(rewards: Array, p_cm: Variant) -> void:
	setup()
	_show_rewards(rewards, p_cm)
	_create_close_button()


func _show_rewards(rewards: Array, p_cm: Variant) -> void:
	var idx: int = 0
	for r in rewards:
		var stype: String = String(r.get("type", ""))
		var amount: int = int(r.get("amount", 0))
		var node: Control = _reward_node(stype, amount, int(r.get("id", 0)), p_cm)
		node.position = _reward_pos(idx)
		container.add_child(node)
		idx += 1


# 源 :362-385 分支：item 用 ReadequipIcon，gold/crusadepoint 货币 Label。
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


func _create_close_button() -> void:
	var close: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_BTN_POS)
	close.pressed.connect(remove_window)
	container.add_child(close)
