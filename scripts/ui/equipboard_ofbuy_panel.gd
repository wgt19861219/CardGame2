class_name EquipboardOfbuyPanel
extends PopWindow

## 装备购买确认浮层（View 层）— 照源 ui/equipboard/ofbuy.lua（202 行）+ 继承链
## board.lua（create 链：initFrame→initContainer→initTitle→initAtt + initAmount）。
## shop 商品点击购买时弹出：icon + name + 拥有行 + 属性/描述面板 + 购买数量行 +
## 货币图标 + 总价 + 确认按钮。弹窗确认语义近 confirm_dialog 家族但内容富（icon/属性/
## 价格），按批5 规约维持独立文件不过度抽象。
## 批5 两件套（2026-08-18 Task 3）：静态 chrome 全量进 equipboard_ofbuy_content.tscn
## （照源声明序直译坐标/贴图/字号），本文件只做业务 + 信号 connect + fill；
## icon/att 行是动态数据保留 procedural（%IconHost/%AttHost 挂载）。
## 单机化：源 param.doBuy 闭包 → confirmed 信号（ShopPanel 连接执行 shop_mgr.buy）。

signal confirmed()

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/equipboard_ofbuy_content.tscn")

# icon 定位（源 board.lua:320 ccp(50,328) 中心锚 → 左上 (14,21)，同 EquipboardPanel 实证口径）
const ICON_POS: Vector2 = Vector2(14.0, 21.0)
# 用户视觉偏好：EquipboardPanel 定稿 0.8×CS=75.2 基数（9bc640e 统一 ÷CS 后乘回 CS，
# 2026-08-22 修——ofbuy 漏跟姊妹文件同批修复，旧 0.8 缩到 58.7）；源 createIcon 无 scale。
const ICON_SCALE: float = 0.8 * CONTENT_SCALE
# name 长名缩放（源 board.lua:338-341 w>160 → setScale(160/w)）
const NAME_MAX_W: float = 160.0
# att_bg 高度自适应（源 board.lua:263 setContentSize(bw, attListHeight + 12)）
const ATT_BG_PAD: float = 12.0
# 描述行 wrap 宽（源 board.lua:153 dimensions CCSizeMake(252, 0)）
const ATT_WRAP_W: float = 252.0
# att 行最少行数（源 board.lua:241-249 lineCount<5 补一行空白）
const ATT_MIN_LINES: int = 5
# money icon 中心锚（源 ofbuy.lua:131 ccp(145,95) → Godot (145, 290)）
const MONEY_ICON_CENTER: Vector2 = Vector2(145.0, 290.0)
# CS：贴图显示尺寸 = 原始像素 ÷ 1.28125（本弹窗贴图均无 TextureConfig 条目）
const CONTENT_SCALE: float = 1.28125

const CAT_FRAGMENT: String = "EQUIP.FRAGMENT"
const LSTR_PURCHASE: String = "EQUIPINFO.PURCHASE"
const LSTR_ITEM: String = "EQUIPINFO.ITEM"
const LSTR_HAVE: String = "EQUIPINFO.HAVE"
const LSTR_CONFIRM: String = "EQUIPINFO.CONFIRM_PURCHASE"
const LSTR_SYNTHESIS: String = "EQUIPINFO.SYNTHESIS_REQUIRES_FRAGMENT_"

var cm: Variant = null
var pd: PlayerData = null
var _param: Dictionary = {}
var _content: Control = null   # .tscn instantiate 根（container 子）
var _frame: Control = null     # %Frame（chrome 容器，fill 锚点）


func setup_panel(p_param: Dictionary, p_cm: Variant, p_pd: PlayerData = null) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	_param = p_param
	cm = p_cm
	pd = p_pd
	setup()
	if shade_layer != null:
		shade_layer.color.a = 0.4   # 源 popwindow 半透遮罩口径（点遮罩关闭由基类 _on_shade_clicked）
	_build_content()
	_schedule_dynamic_layout()


# shop 直挂 container.add_child（不走 show_window）：_ready 兜底触发动态布局。
func _ready() -> void:
	_schedule_dynamic_layout()


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_frame = _content.get_node("%Frame") as Control
	_fill_icon()
	(_frame.get_node("%NameLabel") as Label).text = _equip_name()
	_fill_have_row()
	(_frame.get_node("%PurchaseTitle") as Label).text = String(cm.get_lstr(LSTR_PURCHASE))
	(_frame.get_node("%AmountLabel") as Label).text = str(int(_param.get("amount", 1)))
	(_frame.get_node("%ItemSuffix") as Label).text = String(cm.get_lstr(LSTR_ITEM))
	_fill_money_row()
	_fill_att()
	var confirm_btn: TextureButton = _frame.get_node("%ConfirmBtn") as TextureButton
	(confirm_btn.get_node("Label") as Label).text = String(cm.get_lstr(LSTR_CONFIRM))
	confirm_btn.pressed.connect(_on_confirm)
	(_frame.get_node("%CloseBtn") as TextureButton).pressed.connect(_on_close)


# icon（源 board.lua:303-321 initTitle：createIcon(id) 无 level）。
func _fill_icon() -> void:
	var icon: Control = ReadequipIcon.create_icon(int(_param.get("id", 0)), 0, cm)
	icon.position = ICON_POS
	icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_frame.get_node("%IconHost") as Control).add_child(icon)


# 拥有行（源 board.lua:44-103 initAmount：equip_qunty[id] → pd.items；
# 文本 HAVE + " " + 拥有数 + " " + ITEM；amount_label/amount_title_suffix 源 visible=false 死节点已裁）。
func _fill_have_row() -> void:
	var item_id: int = int(_param.get("id", 0))
	var owned: int = int(pd.items.get(item_id, 0)) if pd != null else 0
	(_frame.get_node("%HaveLabel") as Label).text = "%s %d %s" % [
		String(cm.get_lstr(LSTR_HAVE)), owned, String(cm.get_lstr(LSTR_ITEM))]


# 货币行（源 ofbuy.lua:113-150：money_icon pay 二选一中心锚 + money 总价；
# cost 源 :57 自算 price×max(amount,1)，shop 已传则直用）。
func _fill_money_row() -> void:
	var amount: int = maxi(int(_param.get("amount", 1)), 1)
	var cost: int = int(_param.get("cost", int(_param.get("price", 0)) * amount))
	(_frame.get_node("%MoneyLabel") as Label).text = str(cost)
	var icon: TextureRect = _frame.get_node("%MoneyIcon") as TextureRect
	var icon_res: String = _pay_icon_path(String(_param.get("pay", "gold")))
	var tex: Texture2D = load(icon_res) as Texture2D if ResourceLoader.exists(icon_res) else null
	if tex == null:
		icon.visible = false   # 资产缺失防御：icon 隐藏（bg/label 保留）
		return
	icon.texture = tex
	var icon_size: Vector2 = tex.get_size() / CONTENT_SCALE
	icon.size = icon_size
	icon.position = MONEY_ICON_CENTER - icon_size * 0.5


# att 面板（源 board.lua:106-281 initAtt）：
# Equip.Description 存在 → 单行描述（wrap 252，源 :131-137）；碎片类再补空行 + 合成所需碎片
# X/Y（源 :197-240）；否则 getDescription 属性行；行数不足 5 补一行空白（源 :241-249，
# 与碎片分支 if/elseif 互斥——碎片路径不走 <5 补行）。
func _fill_att() -> void:
	var host: VBoxContainer = _frame.get_node("%AttHost") as VBoxContainer
	for c in host.get_children():
		c.free()
	var item_id: int = int(_param.get("id", 0))
	var equip_row: Dictionary = cm.get_raw_table(&"Equip").get(str(item_id), {})
	var line_count: int = 0
	var is_frag_branch: bool = false   # 源 uinfo 仅在 equipDesc 分支赋值 → 碎片行只在 desc 分支内触发
	var desc_key: String = String(equip_row.get(&"Description", ""))
	if desc_key != "":
		_add_att_label(host, String(cm.get_lstr(desc_key)), "desc")
		line_count = 1
		var is_fragment: bool = String(equip_row.get(&"Category", "")) == CAT_FRAGMENT
		if is_fragment:
			is_frag_branch = true
			var owned: int = int(pd.items.get(item_id, 0)) if pd != null else 0
			var need: int = _fragment_need(item_id)
			_add_att_label(host, " ", "row")
			_add_att_label(host, String(cm.get_lstr(LSTR_SYNTHESIS)) + "%d/%d" % [owned, need], "synthesis")
			line_count += 2
	else:
		var rows: Array = ReadequipData.get_description(item_id, 0, cm)
		for row in rows:
			var r: Dictionary = row as Dictionary
			_add_att_label(host,
				String(r.get("att", "")) + String(r.get("add", "")) + String(r.get("suffix", "")), "row")
		line_count = rows.size()
	# 补行互斥（源 board.lua:197-249 if isFragment ... elseif lineCount<5：碎片路径不走 <5 补行）
	if not is_frag_branch and line_count < ATT_MIN_LINES:
		_add_att_label(host, " ", "row")


# att 行 Label：kind "desc"=描述行（wrap 252）/"row"=普通行（OfbuyAttLabel）/
# "synthesis"=碎片合成行（OfbuySynthesisLabel，源 ccc3(66,45,28)）。
func _add_att_label(host: VBoxContainer, text: String, kind: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.theme_type_variation = &"OfbuySynthesisLabel" if kind == "synthesis" else &"OfbuyAttLabel"
	if kind == "desc":
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(ATT_WRAP_W, 0.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)


# 碎片合成需求数（源 board.lua:222-227 遍历 fragment 表 Fragment ID == id 取 Fragment Count）。
func _fragment_need(item_id: int) -> int:
	var frag_table: Dictionary = cm.get_raw_table(&"Fragment")
	for key in frag_table:
		var fr: Dictionary = frag_table[key]
		if int(fr.get(&"Fragment ID", 0)) == item_id:
			return int(fr.get(&"Fragment Count", 0))
	return 0


# 动态布局（须入树后度量，variation 树内才解析）：
# name 长名缩放 + att_bg 高度自适应。setup 时已入树立即执行，否则 register_on_enter
# （show_window 流程）或 _ready（shop 直挂 add_child 流程）兜底。
func _schedule_dynamic_layout() -> void:
	if _content == null:
		return
	if is_inside_tree():
		_layout_dynamic()
	else:
		register_on_enter(_layout_dynamic)


func _layout_dynamic() -> void:
	if _content == null or not is_instance_valid(_content):
		return
	var name_lbl: Label = _frame.get_node("%NameLabel") as Label
	name_lbl.scale = Vector2.ONE   # 重置上次缩放，避免短名残留长名 scale
	var name_w: float = name_lbl.get_combined_minimum_size().x
	if name_w > NAME_MAX_W:
		name_lbl.scale = Vector2(NAME_MAX_W / name_w, NAME_MAX_W / name_w)
	var host: VBoxContainer = _frame.get_node("%AttHost") as VBoxContainer
	var host_min: Vector2 = host.get_combined_minimum_size()
	(_frame.get_node("%AttBg") as NinePatchRect).size.y = host_min.y + ATT_BG_PAD


func _on_close() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()


func _on_confirm() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	confirmed.emit()
	remove_window()


# 装备名（源 board.lua:322 readequip.value(id,"Name")——源 datatable.lua:110 数据表加载即
# 翻译 → 本项目 get_lstr 等价；ofbuy.lua:60 amount>1 → "%sx%d"）。
func _equip_name() -> String:
	var item_id: int = int(_param.get("id", 0))
	var row: Dictionary = cm.get_raw_table(&"Equip").get(str(item_id), {})
	var name_key: String = String(row.get(&"Name", str(item_id)))
	var raw_name: String = String(cm.get_lstr(name_key))
	var amount: int = int(_param.get("amount", 1))
	return raw_name + "x" + str(amount) if amount > 1 else raw_name


func _pay_icon_path(pay: String) -> String:
	return MarketConfig.UI_DIR + MarketConfig.get_coin_res(pay)
