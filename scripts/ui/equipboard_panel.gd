class_name EquipboardPanel
extends PopWindow

## 装备浮层（View 层）— 照源 equipboard ofpackage.lua（299 行，2 按钮动态浮层）。
## 接 PackagePanel.cell_clicked 弹出。左卖出（始终）+ 右动态（prop 查看/consume 使用/fragment 合成）。
## propType 判定照源 refreshPropType :233-253（Category=FRAGMENT 有产物→fragment / CONSUMABLES+EXPERIENCE_PILL→consume / 其他→prop）。
## sell 接 PlayerData.sell_equip + compose 接 FragmentComposePanel（第 21 段）+ check 接 EquipdetailPanel（第 26 段）+ use 接 EatexpPanel（第 27 段）。
## 坐标：frame(package_detail_bg 369×493)内子元素走 _gl（源相对 frame sprite 左下角 y-up → Godot Control 左上角 y-down）；
## frame 自身走 _g(FRAME_POS)（全屏），frame.position = _g(FRAME_POS) - FRAME_SIZE/2（左上角 = 中心 godot - 半尺寸）。

# ── propType（源 refreshPropType）──
const PROPTYPE_PROP: String = "prop"
const PROPTYPE_CONSUME: String = "consume"
const PROPTYPE_FRAGMENT: String = "fragment"

# ── Equip.json 字段值（源 LSTR key）──
const CAT_FRAGMENT: String = "EQUIP.FRAGMENT"
const CAT_CONSUMABLES: String = "EQUIP.CONSUMABLES"
const CONSUME_EXPERIENCE_PILL: String = "EQUIP.EXPERIENCE_PILL"

# ── 坐标常量（源 cocos 值，frame package_detail_bg.png 内相对）──
const FRAME_POS: Vector2 = Vector2(400.0, 240.0)      # board.lua:426
const FRAME_SIZE: Vector2 = Vector2(369.0, 493.0)    # package_detail_bg 实际尺寸 369×493（Phase 4 校准）
const ICON_POS: Vector2 = Vector2(50.0, 328.0)        # board.lua:320
const NAME_POS: Vector2 = Vector2(92.0, 345.0)        # board.lua:328
const AMOUNT_TITLE_POS: Vector2 = Vector2(90.0, 310.0)  # board.lua:65
const MONEY_BOARD_POS: Vector2 = Vector2(144.0, 100.0)  # ofpackage:58
const LEFT_BTN_POS: Vector2 = Vector2(82.0, 40.0)     # ofpackage:115 卖出
const RIGHT_BTN_POS: Vector2 = Vector2(212.0, 40.0)   # ofpackage:162 动态
const BTN_SIZE: Vector2 = Vector2(125.0, 49.0)
const CLOSE_POS: Vector2 = Vector2(286.0, 358.0)      # board.lua:441
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"  # board.lua:437
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"  # board.lua:438

# ── 资源 ──
const FRAME_PATH: String = "res://assets/ui/alpha/HVGA/package_detail_bg.png"

# ── 文本（源 LSTR）──
const TEXT_SELL: String = "卖出"          # PACKAGE.SELL
const TEXT_DETAIL: String = "详情"        # PACKAGE.DETAIL
const TEXT_USE: String = "使用"           # MIDAS.USE
const TEXT_COMPOSE: String = "合成"       # EQUIPCRAFT.SYNTHESIS
const TEXT_SOLD: String = "已卖出"        # 卖出成功 toast

signal sold(item_id: int)           # 卖出后通知调用方刷新（PackagePanel 重 classify）

var cm: Variant = null
var pd: PlayerData = null
var _cell_data: Dictionary = {}
var _item_id: int = 0       # 装备/物品/碎片 id（源 param.id）
var _make_id: int = 0       # 产物 tid（fragment 合成用，源 makeId）
var _prop_type: String = PROPTYPE_PROP


# 源 cocos(800×480 左下) → Godot(960×640 左上)：cx+80, 560-cy（全屏元素 _g，同 fragment_compose_panel 范式）。
func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


# frame(package_detail_bg)内子元素：源相对 frame CCSprite 左下角 y-up（Cocos CCSprite 子节点原点=左下角），
# Godot frame 是 Control（子节点相对左上角 y-down），故 _gl 翻 Y（x 不变）。
func _gl(pos: Vector2) -> Vector2:
	return Vector2(pos.x, FRAME_SIZE.y - pos.y)


# 源 create(param) :264-278。param={id, doSell, doUse, doCheck, doCompose}（package.lua 注入）。
# 本项目 cell_data 含 {id, makeId, amount, category, type, needAmount}（EquipmentClassifier 输出）。
func setup_panel(p_cell_data: Dictionary, p_cm: Variant, p_pd: PlayerData) -> void:
	_cell_data = p_cell_data
	cm = p_cm
	pd = p_pd
	_item_id = int(p_cell_data.get("id", 0))
	_make_id = int(p_cell_data.get("makeId", _item_id))
	_prop_type = _judge_prop_type()
	setup()
	_build_ui()
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


# 源 refreshPropType :233-253 查 Category==FRAGMENT（源单一 equip_qunty，碎片=Category FRAGMENT 物品）。
# 本项目双容器：fragment cell 来自 HeroManager.fragments（**魂石**，Category=SOUL_STONE，Fragment 表映射召唤英雄），
# 故用 cell_data.type==2 判 fragment（适配本项目数据模型，魂石有配方 makeId!=id → 可合成）。
# items 的 EXPERIENCE_PILL → consume；其他 → prop。
func _judge_prop_type() -> String:
	var cell_type: int = int(_cell_data.get("type", 1))
	if cell_type == 2:   # fragments 容器（魂石）
		return PROPTYPE_FRAGMENT if _make_id != _item_id else PROPTYPE_PROP
	var equip_row: Dictionary = cm.get_raw_table(&"Equip").get(str(_item_id), {})
	if String(equip_row.get(&"Category", "")) == CAT_CONSUMABLES:
		if String(equip_row.get(&"Consume Type", "")) == CONSUME_EXPERIENCE_PILL:
			return PROPTYPE_CONSUME
	return PROPTYPE_PROP


# 源 initFrame + initTitle + initAmount + initWindow。
func _build_ui() -> void:
	var frame := Control.new()
	frame.position = _g(FRAME_POS) - FRAME_SIZE / 2.0
	frame.size = FRAME_SIZE
	container.add_child(frame)
	if ResourceLoader.exists(FRAME_PATH):
		var bg := TextureRect.new()
		bg.texture = load(FRAME_PATH)
		bg.size = FRAME_SIZE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(bg)
	# icon（源 initTitle :320 createIcon）
	var icon: Control = ReadequipIcon.create_icon(_item_id, 0, cm)
	icon.position = _gl(ICON_POS)
	frame.add_child(icon)
	# name（源 initTitle :328）
	var name_lbl := Label.new()
	name_lbl.text = _equip_name()
	name_lbl.position = _gl(NAME_POS)
	frame.add_child(name_lbl)
	# 持有量（源 initAmount :65 "持有 X 个"）
	var amount_lbl := Label.new()
	amount_lbl.text = "持有: %d" % int(_cell_data.get("amount", 0))
	amount_lbl.position = _gl(AMOUNT_TITLE_POS)
	frame.add_child(amount_lbl)
	# 卖出价（源 refreshPrice + money_board，price<=0 隐藏）
	var sell_price: int = _sell_price()
	if sell_price > 0:
		var price_lbl := Label.new()
		price_lbl.text = "售价: %d" % sell_price
		price_lbl.position = _gl(MONEY_BOARD_POS)
		frame.add_child(price_lbl)
	# 左卖出按钮（源 left_button :109，始终）
	var sell_btn := Button.new()
	sell_btn.text = TEXT_SELL
	sell_btn.position = _gl(LEFT_BTN_POS)
	sell_btn.size = BTN_SIZE
	sell_btn.pressed.connect(_on_sell_pressed)
	frame.add_child(sell_btn)
	# 右动态按钮（源 right_button :154，按 propType 切文本）
	var right_btn := Button.new()
	right_btn.text = _right_button_label()
	right_btn.position = _gl(RIGHT_BTN_POS)
	right_btn.size = BTN_SIZE
	right_btn.pressed.connect(_on_right_pressed)
	frame.add_child(right_btn)
	# 关闭（源 board.lua close :437 herodetail-detail-close）
	var close_btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, _gl(CLOSE_POS))
	close_btn.pressed.connect(_on_close_pressed)
	frame.add_child(close_btn)


# 源 refreshButton :219-232：prop=详情/consume=使用/fragment=合成。
func _right_button_label() -> String:
	match _prop_type:
		PROPTYPE_CONSUME:
			return TEXT_USE
		PROPTYPE_FRAGMENT:
			return TEXT_COMPOSE
		_:
			return TEXT_DETAIL


# 源 refreshPrice :207-217：Equip[id]["Sell Price"]。
func _sell_price() -> int:
	return int(cm.get_raw_table(&"Equip").get(str(_item_id), {}).get(&"Sell Price", 0))


func _equip_name() -> String:
	return String(cm.get_raw_table(&"Equip").get(str(_item_id), {}).get(&"Name", str(_item_id)))


# 卖出（源 param.doSell → package.getSellHandler :76-96 → equipboard ofsell）。
# 本项目直接 pd.sell_equip（PlayerData 已有，第 17 段）+ toast + emit sold。
func _on_sell_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var income: int = pd.sell_equip(_item_id, 1)
	if income < 0:
		return   # 持有量不足（防御，cell 数据应同步）
	_show_toast("%s %d 金币" % [TEXT_SOLD, income])
	sold.emit(_item_id)
	remove_window()


# 右按钮（源 registerTouchHandler right_button :24-39，按 propType 路由）。
func _on_right_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	match _prop_type:
		PROPTYPE_FRAGMENT:
			_open_compose()
		PROPTYPE_CONSUME:
			_open_eatexp()   # consume → EatexpPanel（第 27 段）
		_:
			_open_detail()   # prop → EquipdetailPanel（第 26 段）


# 合成（源 param.doCompose → package.getComposeHandler :113-129 → fragmentcompose.create(id)）。
# 源传 param.id（碎片物品 id），fragmentcompose 内部反查得 makeId；本项目 FragmentComposePanel 接产物 tid（第 21 段接口），传 _make_id。
func _open_compose() -> void:
	var panel := FragmentComposePanel.new("fragmentcompose", {})
	panel.setup_panel(_make_id, cm, pd)
	panel.show_window(get_parent())


# 详情（源 param.doCheck → equipdetail.create(id)）。第 26 段接 EquipdetailPanel。
func _open_detail() -> void:
	var panel := EquipdetailPanel.new("equipdetail", {})
	panel.setup_panel(_item_id, cm, pd)
	panel.show_window(get_parent())


# 使用经验药（源 param.doUse → eatexplist.create(id, amount, param)）。第 27 段接 EatexpPanel。
func _open_eatexp() -> void:
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(_item_id, cm, pd)
	panel.show_window(get_parent())


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()


func _show_toast(text: String) -> void:
	if Engine.is_editor_hint():
		return
	var toast_node: Node = Engine.get_main_loop().root.get_node_or_null("/root/Toast")
	if toast_node != null and toast_node.has_method("show_text"):
		toast_node.show_text(text)
