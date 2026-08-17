class_name ExcavateGiveupPanel
extends PopWindow

## 放弃矿点确认（View 层）— 照源 ui/excavate/giveup.lua pop:3 → popConfirmDialog
## （announce/confirmdialog.lua + uieditor/confirmdialog.lua 声明表，param.node 分支）。
## 显示已产出资源三行 + 确认放弃 → ExcavateManager.drop 结算（照 doGiveup:681）。
## 两件套（2026-08-17）：frame/delimeter/按钮/三行内容全静态进 excavate_giveup_content.tscn；
## 按钮三态走 theme GiveupConfirmBtn（sell_number cap 15.63,15.63,19.53,15.63 复用
## SB_mo_btn_n/p），行文案走 GiveupRowLabel/GiveupRowValue variation。
## 单机化受控裁剪：源掠夺比例 rr（getRobRatio，其他人抢走部分）不存在 → 实得=全额产出
## （源 :24 rg*(1-rr)>0 分支退化为 rg>0；rr 仅影响数值不影响形态）。
## 受控简化：源 ChaosNode 运行时测宽横排（initWindow 按 nh 动态缩 frame 高），
## 静态化按典型文案估宽定版 500x280（w 公式下限 + 3 行 x26），fill 只改文本/icon。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_giveup_content.tscn")
const LSTR_ROW1_KEY: String = "giveup.1.10.1.001"
const ROW1_FALLBACK: String = "你目前累计开采了"
const LSTR_ROW2_KEY: String = "giveup.1.10.1.002"
const ROW2_FALLBACK: String = "如果主动撤退只能获得"
const LSTR_MSG_KEY: String = "giveup.1.10.1.005"
const MSG_FALLBACK: String = "是否确认从这座宝藏撤退？"
const LSTR_LEAVE_KEY: String = "giveup.1.10.1.003"
const LEAVE_FALLBACK: String = "如果从宝藏撤退,将失去这座宝藏"
const LSTR_SETTEAM_KEY: String = "giveup.1.10.1.004"
const SETTEAM_FALLBACK: String = "如果不派英雄驻守,你将失去这座宝藏"
const LSTR_CONFIRM_KEY: String = "CHATCONFIG.CONFIRM"
const CONFIRM_FALLBACK: String = "确认"
const LSTR_CANCEL_KEY: String = "CHATCONFIG.CANCEL"
const CANCEL_FALLBACK: String = "取消"
const FROM_SETTEAM: String = "setteam"
# 源 giveup.lua:15-19 icon_res（ExcavateTreasure "Produce Type" → 贴图）
const ICON_DIAMOND: Texture2D = preload("res://assets/ui/alpha/HVGA/shop_token_icon.png")
const ICON_GOLD: Texture2D = preload("res://assets/ui/alpha/HVGA/goldicon_small.png")
const ICON_ITEM: Texture2D = preload("res://assets/ui/alpha/HVGA/excavate/excavate_exp_icon.png")
# 产出行隐藏组（源 else 分支 row_ui_1 单元素化，Godot 静态树等价：分支 B 隐藏行 1 后半 + 行 2）
const HIDDEN_ON_EMPTY: Array[String] = ["%R12Icon", "%R13Label", "%R21Label", "%R22Icon", "%R23Label"]

var pd: PlayerData
var _excavate_id: int
var _on_confirmed: Callable
var _from: String = "giveup"


func setup_panel(p_pd: PlayerData, excavate_id: int, on_confirmed: Callable, from: String = "giveup") -> void:
	pd = p_pd
	_excavate_id = excavate_id
	_on_confirmed = on_confirmed
	_from = from
	setup()
	_build_content()


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = pd.cm
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# 两件套 fill：分支文案/数值/icon + 信号 connect（位置/样式全在 tscn + theme）。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	var now: int = int(Time.get_unix_time_from_system())
	var rg: int = pd.excavate.produce_amount(_excavate_id, now)
	var r11: Label = content.get_node("%R11Label") as Label
	if rg > 0:
		r11.text = _lstr(LSTR_ROW1_KEY, ROW1_FALLBACK)
		(content.get_node("%R13Label") as Label).text = str(rg)
		(content.get_node("%R21Label") as Label).text = _lstr(LSTR_ROW2_KEY, ROW2_FALLBACK)
		(content.get_node("%R23Label") as Label).text = str(rg)
		var icon: Texture2D = _produce_icon()
		(content.get_node("%R12Icon") as TextureRect).texture = icon
		(content.get_node("%R22Icon") as TextureRect).texture = icon
	else:
		# 源 :88-91 from="setteam"（battleprepare 空队放弃）用 .004，否则 .003
		if _from == FROM_SETTEAM:
			r11.text = _lstr(LSTR_SETTEAM_KEY, SETTEAM_FALLBACK)
		else:
			r11.text = _lstr(LSTR_LEAVE_KEY, LEAVE_FALLBACK)
		for node_name: String in HIDDEN_ON_EMPTY:
			(content.get_node(node_name) as CanvasItem).visible = false
	(content.get_node("%R31Label") as Label).text = _lstr(LSTR_MSG_KEY, MSG_FALLBACK)
	# 取消/确认（源 confirmdialog 声明表 DGButton：left=CANCEL、right=CONFIRM）
	var cancel_btn: Button = content.get_node("%CancelBtn") as Button
	cancel_btn.text = _lstr(LSTR_CANCEL_KEY, CANCEL_FALLBACK)
	cancel_btn.pressed.connect(remove_window)
	var confirm_btn: Button = content.get_node("%ConfirmBtn") as Button
	confirm_btn.text = _lstr(LSTR_CONFIRM_KEY, CONFIRM_FALLBACK)
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


# 产出类型 → icon 贴图（源 icon_res 映射，fix_size 25x25 在 tscn）。
func _produce_icon() -> Texture2D:
	match ExcavateData.produce_type(pd.cm, _type_id_cached()):
		ExcavateData.PRODUCE_DIAMOND:
			return ICON_DIAMOND
		ExcavateData.PRODUCE_GOLD:
			return ICON_GOLD
		ExcavateData.PRODUCE_ITEM:
			return ICON_ITEM
	return ICON_ITEM


# fill 期 type_id（drop 前矿点 data 仍在，照 _on_confirm_pressed 同源取法）。
func _type_id_cached() -> int:
	var d: Dictionary = pd.excavate.get_data(_excavate_id)
	return int(d.get("_type_id", 0))
