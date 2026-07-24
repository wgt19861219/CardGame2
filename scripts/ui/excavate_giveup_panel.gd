class_name ExcavateGiveupPanel
extends PopWindow

## 放弃矿点确认（View 层）— 照源 ui/excavate/giveup.lua pop:3。
## 显示已产出资源 + 确认放弃 → ExcavateManager.drop 结算（照 doGiveup:681）。
## 单机简化：源掠夺比例 Loot Ratio（其他人抢夺）裁剪，实得=全额产出。
## P1（2026-07-16）：LSTR giveup.1.10.1.005 + CHATCONFIG.CANCEL/CONFIRM + 资源名（DIAMOND/GOLD/CREAMS）。
## Phase A 静态化（2026-07-18）：frame/title/body/cancel/confirm 从 procedural 改 instantiate
## excavate_giveup_content.tscn（位置/size .tscn 固化，照 hero_detail 范式）。

# 静态 panel 层子场景（位置/size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_giveup_content.tscn")
# 源 :114 popConfirmDialog 右按钮（ed.popConfirmDialog 通用确认/取消）
const LSTR_CONFIRM_KEY: String = "CHATCONFIG.CONFIRM"
const CONFIRM_FALLBACK: String = "确认"
const LSTR_CANCEL_KEY: String = "CHATCONFIG.CANCEL"
const CANCEL_FALLBACK: String = "取消"
# 源 :132-136 popConfirmDialog（giveup.lua:132）sell_number_button Scale9 capInsets 15.63,15.63,19.53,15.63 + 浅金 ccc3(234,225,205)。
const SELL_BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const SELL_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const SELL_BTN_CAP: Rect2 = Rect2(15.63, 15.63, 19.53, 15.63)
const BTN_LABEL_COLOR: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
# 源 :114 giveup.1.10.1.005 "是否确认从这座宝藏撤退？"
const LSTR_BODY_KEY: String = "giveup.1.10.1.005"
const BODY_FALLBACK: String = "是否确认从这座宝藏撤退？"
# 源 giveup.lua:13-19 icon_res 映射：Diamond→shop_token_icon / Gold→goldicon_small / Item→excavate_exp_icon
const ICON_DIAMOND_RES: String = "res://assets/ui/alpha/HVGA/shop_token_icon.png"
const ICON_GOLD_RES: String = "res://assets/ui/alpha/HVGA/goldicon_small.png"
const ICON_ITEM_RES: String = "res://assets/ui/alpha/HVGA/excavate/excavate_exp_icon.png"
# 源 map.lua:951-960 资源名（Diamond/Gold/Item 三类）
const LSTR_DIAMOND_KEY: String = "RECHARGE.DIAMOND"
const LSTR_GOLD_KEY: String = "TASK.GOLD"
const LSTR_ITEM_KEY: String = "EQUIP.EXPERIENCE_CREAMS"
const NAME_DIAMOND_FALLBACK: String = "钻石"
const NAME_GOLD_FALLBACK: String = "金币"
const NAME_ITEM_FALLBACK: String = "经验药膏"

var pd: PlayerData
var _excavate_id: int
var _on_confirmed: Callable


func setup_panel(p_pd: PlayerData, excavate_id: int, on_confirmed: Callable) -> void:
	pd = p_pd
	_excavate_id = excavate_id
	_on_confirmed = on_confirmed
	setup()
	_build_content()


# 源 LSTR 走 GameData.config（autoload）；未初始化（headless 测试）fallback 中文兜底。
func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# Phase A：静态节点从 .tscn instantiate（位置/size .tscn 固化）+ fill 动态文案/Scale9 + 信号绑定。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	# 源 :12-14 累计产出 + 抢夺比例（单机裁 rr=0 实得=全额）
	var now: int = int(Time.get_unix_time_from_system())
	var amount: int = pd.excavate.produce_amount(_excavate_id, now)
	var type_id: int = int(pd.excavate.get_data(_excavate_id).get("_type_id", 0))
	# 源 :114 单一文本行 giveup.1.10.1.005（rr=0 时源走 row_ui_1 单行确认问句）
	var body_lbl: Label = content.get_node("%BodyLabel") as Label
	body_lbl.text = _lstr(LSTR_BODY_KEY, BODY_FALLBACK) + "\n" + str(amount) + " " + _type_name(type_id)
	# 取消/确认按钮（源 :132-136 sell_number_button Scale9 cap 15.63,15.63,19.53,15.63 + 浅金 ccc3）
	var cancel_btn: Button = content.get_node("%CancelBtn") as Button
	UiScale9Button.apply_with_label(cancel_btn, SELL_BTN_RES, SELL_BTN_PRESS_RES, SELL_BTN_CAP, _lstr(LSTR_CANCEL_KEY, CANCEL_FALLBACK), BTN_LABEL_COLOR)
	cancel_btn.pressed.connect(remove_window)
	var confirm_btn: Button = content.get_node("%ConfirmBtn") as Button
	UiScale9Button.apply_with_label(confirm_btn, SELL_BTN_RES, SELL_BTN_PRESS_RES, SELL_BTN_CAP, _lstr(LSTR_CONFIRM_KEY, CONFIRM_FALLBACK), BTN_LABEL_COLOR)
	confirm_btn.pressed.connect(_on_confirm_pressed)


func _on_confirm_pressed() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	# drop 前取 type_id（drop 移除矿点 data），照源 _drop_excavate:3958 buildResourceReward(typeRow, produced) 发放弃结算。
	var d: Dictionary = pd.excavate.get_data(_excavate_id)
	var type_id: int = int(d.get("_type_id", 0))
	var amount: int = pd.excavate.drop(_excavate_id, now)
	ExcavateData.grant_resource_reward(pd, ExcavateData.build_resource_reward(pd.cm, type_id, amount))
	if _on_confirmed.is_valid():
		_on_confirmed.call(amount)
	remove_window()


# 源 map.lua:951-960 epn 映射 + giveup.lua:15-19 icon_res（Diamond/Gold/Item 三类资源名）。
func _type_name(type_id: int) -> String:
	match ExcavateData.produce_type(pd.cm, type_id):
		ExcavateData.PRODUCE_DIAMOND:
			return _lstr(LSTR_DIAMOND_KEY, NAME_DIAMOND_FALLBACK)
		ExcavateData.PRODUCE_GOLD:
			return _lstr(LSTR_GOLD_KEY, NAME_GOLD_FALLBACK)
		ExcavateData.PRODUCE_ITEM:
			return _lstr(LSTR_ITEM_KEY, NAME_ITEM_FALLBACK)
	return ""
