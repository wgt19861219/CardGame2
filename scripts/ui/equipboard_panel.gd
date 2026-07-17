class_name EquipboardPanel
extends PopWindow

## 装备浮层（View 层）— 照源 equipboard ofpackage.lua（299 行，2 按钮动态浮层）。
## Phase A 重构（2026-07-17）：base 节点（frame+bg+icon+name+amount+price+2 button+close）静态化进
## equipboard_content.tscn（instantiate + fill），位置/size 编辑器可视化调。照 hero_detail 范式（无 builder，
## 单 panel 内 fill）。信号/业务逻辑/行为保留不变。
## 接 PackagePanel.cell_clicked 弹出。左卖出（始终）+ 右动态（prop 查看/consume 使用/fragment 合成）。
## propType 判定照源 refreshPropType :233-253（Category=FRAGMENT→fragment / CONSUMABLES+EXPERIENCE_PILL→consume / 其他→prop）。
## sell 接 PlayerData.sell_equip + compose 接 FragmentComposePanel + check 接 EquipdetailPanel + use 接 EatexpPanel。

# base + frame 子场景（Phase A 静态化：位置+size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/equipboard_content.tscn")

# ── propType（源 refreshPropType）──
const PROPTYPE_PROP: String = "prop"
const PROPTYPE_CONSUME: String = "consume"
const PROPTYPE_FRAGMENT: String = "fragment"

# ── Equip.json 字段值（源 LSTR key）──
const CAT_FRAGMENT: String = "EQUIP.FRAGMENT"
const CAT_CONSUMABLES: String = "EQUIP.CONSUMABLES"
const CONSUME_EXPERIENCE_PILL: String = "EQUIP.EXPERIENCE_PILL"

# ── frame 内子节点坐标（源 cocos 值经 _gl 转 Frame Control 内左上 y-down）──
# ICON_POS = 源 board.lua:320 ccp(50,328) → _gl(50, 385-328=57)。icon 动态建（ReadequipIcon.create_icon
# 返回 size=72×72 Control），fill 时挂 %IconHost 并设 position=ICON_POS（frame 内左上）。
const ICON_POS: Vector2 = Vector2(50.0, 57.0)

# ── Scale9 按钮（源 ofpackage.lua:108-119 left_button / :154-165 right_button）──
# 源 Scale9Sprite package_button.png + package_button_down.png，capInsets CCRectMake(10,10,236,29)。
# .tscn 普通 Button 套 StyleBoxTexture 补九宫格（normal/hover=package_button，pressed=package_button_down）。
const BTN_NORMAL_RES: String = "res://assets/ui/alpha/HVGA/package_button.png"
const BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/package_button_down.png"
const BTN_CAP: Rect2 = Rect2(10.0, 10.0, 236.0, 29.0)

# ── 文本 LSTR key（源 ofpackage.lua:140 PACKAGE.SELL / :225 PACKAGE.DETAIL / :227 MIDAS.USE /
# :229 EQUIPCRAFT.SYNTHESIS；卖出 toast 用 ofsell.lua:427 EQUIPINFO.MONEY_GAINED）──
const LSTR_SELL: String = "PACKAGE.SELL"
const LSTR_DETAIL: String = "PACKAGE.DETAIL"
const LSTR_USE: String = "MIDAS.USE"
const LSTR_COMPOSE: String = "EQUIPCRAFT.SYNTHESIS"
const LSTR_MONEY_GAINED: String = "EQUIPINFO.MONEY_GAINED"
const LSTR_HAVE: String = "EQUIPINFO.HAVE"        # board.lua:60 持有量标题
const LSTR_ITEM: String = "EQUIPINFO.ITEM"        # board.lua:87 持有量后缀
const LSTR_SALE_COST: String = "EQUIPINFO.UNIT_SALE_COST"  # ofpackage.lua:66 售价标题

signal sold(item_id: int)           # 卖出后通知调用方刷新（PackagePanel 重 classify）

var cm: Variant = null
var pd: PlayerData = null
var _cell_data: Dictionary = {}
var _item_id: int = 0       # 装备/物品/碎片 id（源 param.id）
var _make_id: int = 0       # 产物 tid（fragment 合成用，源 makeId）
var _prop_type: String = PROPTYPE_PROP
var _frame: Control = null  # .tscn %Frame（base 容器，fill 动态数据的锚点）


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
	_build_content()
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


# 源 initFrame + initTitle + initAmount + initWindow。Phase A：从 .tscn instantiate + fill 动态数据。
# 位置/size .tscn 已固化（编辑器可视化调），fill 只填 texture/text/visible/stylebox。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_frame = content.get_node("%Frame") as Control
	_fill_icon()
	(_frame.get_node("%NameLabel") as Label).text = _equip_name()   # 源 initTitle :328
	var amt: int = int(_cell_data.get("amount", 0))   # 源 board.lua:60 text=HAVE..amount..ITEM
	(_frame.get_node("%AmountLabel") as Label).text = "%s %d %s" % [cm.get_lstr(LSTR_HAVE), amt, cm.get_lstr(LSTR_ITEM)]
	_fill_sell_price()
	var sell_btn: Button = _frame.get_node("%SellBtn") as Button   # 源 left_button :109
	_apply_button_style(sell_btn)
	sell_btn.text = cm.get_lstr(LSTR_SELL)
	sell_btn.pressed.connect(_on_sell_pressed)
	var right_btn: Button = _frame.get_node("%RightBtn") as Button   # 源 right_button :154
	_apply_button_style(right_btn)
	right_btn.text = _right_button_label()
	right_btn.pressed.connect(_on_right_pressed)
	(_frame.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close_pressed)   # 源 board.lua:437 close


# 源 initTitle :320 createIcon — 挂 %IconHost，position=ICON_POS（frame 内 _gl 后）。
func _fill_icon() -> void:
	var host: Control = _frame.get_node("%IconHost") as Control
	var icon: Control = ReadequipIcon.create_icon(_item_id, 0, cm)
	icon.position = ICON_POS
	host.add_child(icon)


# 源 refreshPrice :207-217：price<=0 隐藏 money_board（本 项目用 %SellPriceLabel visible 切换）。
func _fill_sell_price() -> void:
	var price: int = _sell_price()
	var lbl: Label = _frame.get_node("%SellPriceLabel") as Label
	if price > 0:
		lbl.text = cm.get_lstr(LSTR_SALE_COST) + str(price)
		lbl.visible = true
	else:
		lbl.visible = false


# 源 Scale9Sprite package_button/package_button_down → .tscn Button 套 StyleBoxTexture（九宫格）。
func _apply_button_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_button_stylebox(BTN_NORMAL_RES))
	btn.add_theme_stylebox_override("hover", _make_button_stylebox(BTN_NORMAL_RES))
	btn.add_theme_stylebox_override("pressed", _make_button_stylebox(BTN_PRESS_RES))


static func _make_button_stylebox(res_path: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var tex: Texture2D = load(res_path) as Texture2D
	sb.texture = tex
	sb.texture_margin_left = BTN_CAP.position.x
	sb.texture_margin_top = BTN_CAP.position.y
	if tex != null:
		sb.texture_margin_right = tex.get_width() - BTN_CAP.position.x - BTN_CAP.size.x
		sb.texture_margin_bottom = tex.get_height() - BTN_CAP.position.y - BTN_CAP.size.y
	return sb


# 源 refreshButton :219-232：prop=详情/consume=使用/fragment=合成。
func _right_button_label() -> String:
	match _prop_type:
		PROPTYPE_CONSUME:
			return cm.get_lstr(LSTR_USE)
		PROPTYPE_FRAGMENT:
			return cm.get_lstr(LSTR_COMPOSE)
		_:
			return cm.get_lstr(LSTR_DETAIL)


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
	_show_toast("%s%d" % [cm.get_lstr(LSTR_MONEY_GAINED), income])
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
