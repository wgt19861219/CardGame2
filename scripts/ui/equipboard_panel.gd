class_name EquipboardPanel
extends PopWindow

## 装备浮层（View 层）— 照源 equipboard board.lua（459 行基类：frame/title/att/amount）+
## ofpackage.lua（299 行：侧滑浮层 + 2 按钮 + 售价板）。两件套范式（批 4 Task 6，2026-08-17）：
## 静态结构与样式全在 equipboard_content.tscn + default_theme（字号/颜色/阴影/按钮九宫格走
## theme variation），panel 只做业务 + 信号 connect + fill 动态数据，零运行时主题 override。
## 接 PackagePanel.cell_clicked 弹出。左卖出（始终）+ 右动态（prop 查看/consume 使用/fragment 合成）。
## propType 判定照源 refreshPropType :233-253（Category=FRAGMENT→fragment / CONSUMABLES+EXPERIENCE_PILL→consume / 其他→prop）。
## sell 接 PlayerData.sell_equip + compose 接 FragmentComposePanel + check 接 EquipdetailPanel + use 接 EatexpPanel。

# base + frame 子场景（静态化：位置+size 在 .tscn 可视化）。
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
# ICON_POS = 源 board.lua:320 ccp(50,328)。icon 未显式 setAnchorPoint → Cocos 默认 anchor(0.5,0.5)
# = 中心；源中心(50,328) → Godot 中心(50,57) → Control 左上 = 中心 - 半显示尺寸 (36.7,37.1)
# （frame 纹理 94/CS×95/CS 的一半；旧值 (14,21) 误用容器 72 的半尺寸 36，2026-09-08 巡检清偿，
# 同源误算 equipcraft 已于 2026-09-06 先修定口径。ICON_SCALE 1.025 下 frame 中心偏 <1px 忽略）。
const ICON_POS: Vector2 = Vector2(13.3, 19.9)
# 用户视觉偏好：定稿时产物 frame 原像素 94 直显 ×0.8=75.2（用户验收观感）；9bc640e 统一
# ÷CS 后产物显示 94/CS=73.37，×0.8 会缩到 58.7——乘回 CS 恢复 75.2 基数（2026-08-22 修）。
const ICON_SCALE: float = 0.8 * 1.28125
# att_bg 顶边固定（icon 正下方；源 att_bg anchor 0.5,1 顶固定 ccp(143,287) → Godot 顶 y=385-287=98，向下扩）。
const ATT_TOP: float = 98.0
# name 框宽上限（源 board.lua:338 长名溢出 scale 缩小）：NameLabel offset 92→300 = 208px。
const NAME_MAX_W: float = 208.0
# desc 行 wrap 宽（源 board.lua:135 dimensions CCSizeMake(252,0)，Description 分支专用）
const ATT_WRAP_W: float = 252.0
# AttBg 最小框高：1 行属性不缩成孤框的兜底（≈2 行行高+12，bridge 实测校准）。
# 受控偏离源：源 board.lua:231-237「<5 补空格行撑高」在 4 行属性时底部空出一整行
# （2026-09-09 用户观感裁决「下边间距太大」），改最小框高等价实现；fragment 分支的
# 合成行前空行（源 :193-198）是视觉分隔，保留不受影响。
const ATT_BG_MIN_H: float = 78.0
# frame 切换 fadeIn（源 board.lua:406-413 refresh 时 frame modulate.a 0→1）。
const FRAME_FADE_DUR: float = 0.15

# ── 侧滑动画（源 ofpackage.lua:292-298 popin：起始 ccp(-142,213) 屏幕左外 → CCMoveTo 0.2 CCEaseOut → ccp(182,213)）──
# 起始 ccp(-142,213) 中心 → Godot frame 左上 x=-206（屏幕左外），y 不变。
const SLIDE_START_X: float = -206.0
const SLIDE_TIME: float = 0.2

# ── 文本 LSTR key（源 ofpackage.lua:140 PACKAGE.SELL / :225 PACKAGE.DETAIL / :227 MIDAS.USE /
# :229 EQUIPCRAFT.SYNTHESIS；卖出 toast 用 ofsell.lua:427 EQUIPINFO.MONEY_GAINED；
# 碎片行 board.lua:212 EQUIPINFO.SYNTHESIS_REQUIRES_FRAGMENT_）──
const LSTR_SELL: String = "PACKAGE.SELL"
const LSTR_DETAIL: String = "PACKAGE.DETAIL"
const LSTR_USE: String = "MIDAS.USE"
const LSTR_COMPOSE: String = "EQUIPCRAFT.SYNTHESIS"
const LSTR_MONEY_GAINED: String = "EQUIPINFO.MONEY_GAINED"
const LSTR_HAVE: String = "EQUIPINFO.HAVE"        # board.lua:60 持有量标题
const LSTR_ITEM: String = "EQUIPINFO.ITEM"        # board.lua:87 持有量后缀
const LSTR_SALE_COST: String = "EQUIPINFO.UNIT_SALE_COST"  # ofpackage.lua:66 售价标题
const LSTR_SYNTHESIS_REQ: String = "EQUIPINFO.SYNTHESIS_REQUIRES_FRAGMENT_"  # board.lua:212 碎片行标题

signal sold(item_id: int)           # 卖出后通知调用方刷新（PackagePanel 重 classify）
signal composed(item_id: int)       # 碎片合成后通知调用方刷新（PackagePanel 重 classify，源 downFragmentCompose）

var cm: Variant = null
var pd: PlayerData = null
var _cell_data: Dictionary = {}
var _item_id: int = 0       # 装备/物品/碎片 id（源 param.id）
var _make_id: int = 0       # 产物 tid（fragment 合成用，源 makeId）
var _prop_type: String = PROPTYPE_PROP
var _frame: Control = null  # .tscn %Frame（base 容器，fill 动态数据的锚点）


# 本项目 cell_data 含 {id, makeId, amount, category, type, needAmount}（EquipmentClassifier 输出）。
func setup_panel(p_cell_data: Dictionary, p_cm: Variant, p_pd: PlayerData, p_modal: bool = false) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	hud_occlude = false   # 源例外族：equipboardofpackage 挂 package mainLayer z=0 无遮罩悬浮（唯一刻意低于 statusbar 的"弹窗"）——不遮蔽 HUD（2026-09-08 通用治理梳理）
	cm = p_cm
	pd = p_pd
	_update_cell_fields(p_cell_data)
	setup()
	if p_modal:
		# 模态浮层（handbook 等场景用）：shade 半透明 + STOP 吞点击，点 shade 关闭弹窗
		if shade_layer != null:
			shade_layer.color.a = 0.6
			shade_layer.mouse_filter = Control.MOUSE_FILTER_STOP
			if not shade_layer.gui_input.is_connected(_on_shade_click_outside):
				shade_layer.gui_input.connect(_on_shade_click_outside)
	else:
		# 非模态浮层（package 场景照源 equipboard.mainLayer 挂 package.mainLayer 无遮罩）：
		# shade 透明 + IGNORE，不拦底层 cell 点击——用户可点其他物品切换 equipboard 内容
		# （源 doSelectEquip :197-198 refresh）。
		if shade_layer != null:
			shade_layer.color.a = 0
			shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# PopWindow 根 Control 默认 STOP（吞底层点击=模态弹窗）；非模态须根 IGNORE，
		# 让 frame 外区域（cell 网格）点击穿透到下层 package（根 IGNORE 不影响子按钮 STOP 独立命中）。
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	# 模态弹窗 frame 居中（package 非模态用 .tscn 固定 offset 38,74.5 在右侧，
	# handbook 模态需居中屏幕：(800-frame_w)/2, (480-frame_h)/2）
	if p_modal and _frame != null:
		var fw: float = _frame.offset_right - _frame.offset_left
		var fh: float = _frame.offset_bottom - _frame.offset_top
		_frame.offset_left = (800.0 - fw) * 0.5
		_frame.offset_top = (480.0 - fh) * 0.5
		_frame.offset_right = _frame.offset_left + fw
		_frame.offset_bottom = _frame.offset_top + fh
	register_on_enter(_play_slide_in)
	register_on_enter(_relayout_att_bg)   # 首次入树后重算 att_bg（setup 时未入树 min 不可靠，致首次介绍/定价重叠）


# 模态 shade 点击外部关闭弹窗（handbook 等场景）
func _on_shade_click_outside(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		remove_window()


# 更新 cell 字段（setup_panel 首次 + refresh 切换共用，源 doSelectEquip self.selectid=id + refreshPropType）。
func _update_cell_fields(p_cell_data: Dictionary) -> void:
	_cell_data = p_cell_data
	_item_id = int(p_cell_data.get("id", 0))
	_make_id = int(p_cell_data.get("makeId", _item_id))
	_prop_type = _judge_prop_type()


func refresh(p_cell_data: Dictionary) -> void:
	_update_cell_fields(p_cell_data)
	_refresh_content()


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


# 位置/size/样式 .tscn + theme variation 已固化（编辑器可视化调），fill 只填 texture/text/visible。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_frame = content.get_node("%Frame") as Control
	var sell_btn: Button = _frame.get_node("%SellBtn") as Button
	# fill 独立 Label 子节点 %SellLabel（Button.text 内嵌 label 受 stylebox content_margin 干扰字偏左上，
	# 改独立 Label anchors_preset=15 full_rect + horizontal/vertical_alignment=1 稳定居中，范式同 hero_detail）。
	(_frame.get_node("%SellLabel") as Label).text = cm.get_lstr(LSTR_SELL)
	sell_btn.pressed.connect(_on_sell_pressed)
	var right_btn: Button = _frame.get_node("%RightBtn") as Button
	right_btn.pressed.connect(_on_right_pressed)
	var close_btn: TextureButton = _frame.get_node("%CloseBtn") as TextureButton
	close_btn.visible = false
	close_btn.pressed.connect(_on_close_pressed)   # 连接保留（visible=false 不触发，无害）
	_refresh_content()


# 刷新动态数据（icon/name/amount/price/right label）——_build_content 首次 + refresh 切换共用。
func _refresh_content() -> void:
	var host: Control = _frame.get_node("%IconHost") as Control
	for c in host.get_children():
		c.free()
	_fill_icon()
	# 源 board.lua:338：长名溢出时 scale 缩小（按字符宽估算，超 NAME_MAX_W 等比缩）。
	var name_lbl: Label = _frame.get_node("%NameLabel") as Label
	name_lbl.text = _equip_name()
	name_lbl.scale = Vector2.ONE   # 重置上次缩放，避免短名残留长名 scale
	var name_w: float = name_lbl.get_combined_minimum_size().x
	if name_w > NAME_MAX_W:
		name_lbl.scale = Vector2(NAME_MAX_W / name_w, NAME_MAX_W / name_w)
	var amt: int = int(_cell_data.get("amount", 0))
	(_frame.get_node("%AmountLabel") as Label).text = "%s %d %s" % [cm.get_lstr(LSTR_HAVE), amt, cm.get_lstr(LSTR_ITEM)]
	_fill_sell_price()
	_fill_att()
	# fill 独立 Label 子节点 %RightLabel（范式同 SellLabel）。
	(_frame.get_node("%RightLabel") as Label).text = _right_button_label()
	# 源 board.lua:406-413：refresh 时 frame modulate.a 0→1 fadeIn（仅在 panel 已入树后切装备时触发，
	# 首次显示由 register_on_enter 入场动画覆盖；用 is_inside_tree 区分）。
	if is_inside_tree():
		_frame.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(_frame, "modulate:a", 1.0, FRAME_FADE_DUR)


func _fill_att() -> void:
	var host: VBoxContainer = _frame.get_node("%AttHost") as VBoxContainer
	for c in host.get_children():
		c.free()
	# 源 board.lua:127-135：Equip.Description 存在 → 单行描述覆盖属性行（wrap 252）。
	# 魂石/碎片/卷轴/消耗品全走此分支（属性全 0，get_description 返空）；装备类无 Description 走属性行。
	var desc_key: String = String(cm.get_raw_table(&"Equip").get(str(_item_id), {}).get(&"Description", ""))
	if desc_key != "":
		var lbl := Label.new()
		lbl.text = String(cm.get_lstr(desc_key))
		lbl.theme_type_variation = &"EquipboardAttLabel"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(ATT_WRAP_W, 0.0)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(lbl)
	else:
		var rows: Array = ReadequipData.get_description(_item_id, 0, cm)   # level 0（package 物品未装备无强化等级）
		for row in rows:
			var r: Dictionary = row as Dictionary
			var lbl := Label.new()
			lbl.text = String(r.get("att", "")) + String(r.get("add", ""))
			lbl.theme_type_variation = &"EquipboardAttLabel"
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			host.add_child(lbl)
	# fragment 合成信息（碎片类，源 initAtt :197-240 fragment_title LSTR + fragment_amount "X/Y"；
	# 源判定 uinfo.isFragment = Category==FRAGMENT，本项目 fragments 容器=魂石模型以 prop_type
	# 判定（2026-07-19 定稿适配保留）。合成行前补源空行（源 :193-198）。
	if _prop_type == PROPTYPE_FRAGMENT:
		_add_blank_row(host)
		var frag_lbl := Label.new()
		frag_lbl.text = "%s %d/%d" % [cm.get_lstr(LSTR_SYNTHESIS_REQ), int(_cell_data.get("amount", 0)), int(_cell_data.get("needAmount", 0))]
		frag_lbl.theme_type_variation = &"EquipboardFragmentLabel"
		frag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(frag_lbl)
	_relayout_att_bg()


# att 空行占位（源 board.lua:195-201/:231-237 text=" " 撑行数，同属性行样式）。
func _add_blank_row(host: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = " "
	lbl.theme_type_variation = &"EquipboardAttLabel"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)


# att_bg + host 自适应属性内容高度（源 board.lua:263 att_bg setContentSize(bw, attListHeight+12)）。
# 顶固定（ATT_TOP = icon 正下方），向下扩（att_list 标签堆叠，源 att_bg anchor 0.5,1 顶固定）。
# 首次 setup 时 panel 未入树，host.get_combined_minimum_size 不可靠（Label 字体布局未就绪 → 偏小 →
# labels 溢出到 money_board 致首次介绍/定价重叠），故 setup_panel 另 register_on_enter 入树后重算。
func _relayout_att_bg() -> void:
	var host: VBoxContainer = _frame.get_node("%AttHost") as VBoxContainer
	var host_min: Vector2 = host.get_combined_minimum_size()
	var bg: NinePatchRect = _frame.get_node("%AttBg") as NinePatchRect
	var bg_h: float = max(host_min.y + 12.0, ATT_BG_MIN_H)
	bg.offset_top = ATT_TOP
	bg.size.y = bg_h
	# host 在框内垂直居中：min 兜底撑高时（单/少行属性）顶=底对称（2026-09-09 二轮观感裁决：
	# 旧 +6 贴顶使 1 行属性底空 ~42 vs 顶 6）；多行时 (bg_h-内容)/2 = 6 与旧值不变。
	host.offset_top = ATT_TOP + (bg_h - host_min.y) * 0.5
	host.size.y = host_min.y


func _play_slide_in() -> void:
	var target_pos: Vector2 = _frame.position   # .tscn offset 目标 (38, 74.5)
	_frame.position = Vector2(SLIDE_START_X, target_pos.y)   # 起始屏幕左外
	var tw: Tween = create_tween()
	tw.tween_property(_frame, "position", target_pos, SLIDE_TIME).set_ease(Tween.EASE_OUT)


func _fill_icon() -> void:
	var host: Control = _frame.get_node("%IconHost") as Control
	var icon: Control = ReadequipIcon.create_icon(_item_id, 0, cm)
	icon.position = ICON_POS
	icon.scale = Vector2(ICON_SCALE, ICON_SCALE)   # 缩小（用户偏好，源 createIcon 原 size）
	host.add_child(icon)


func _fill_sell_price() -> void:
	var price: int = _sell_price()
	var board: TextureRect = _frame.get_node("%MoneyBoard") as TextureRect
	if price > 0:
		(board.get_node("%SellTitleLabel") as Label).text = cm.get_lstr(LSTR_SALE_COST)
		(board.get_node("%SellNumberLabel") as Label).text = str(price)
		board.visible = true
	else:
		board.visible = false


func _right_button_label() -> String:
	match _prop_type:
		PROPTYPE_CONSUME:
			return cm.get_lstr(LSTR_USE)
		PROPTYPE_FRAGMENT:
			return cm.get_lstr(LSTR_COMPOSE)
		_:
			return cm.get_lstr(LSTR_DETAIL)


func _sell_price() -> int:
	return int(cm.get_raw_table(&"Equip").get(str(_item_id), {}).get(&"Sell Price", 0))


# 装备名（源 board.lua:322 readequip.value(id,"Name")——源 datatable.lua:110 数据表加载即
# 翻译 → 本项目 Equip.json Name 存 LSTR key，须过 get_lstr；查无时 get_lstr 返回 key 本身兜底。
func _equip_name() -> String:
	var name_key: String = String(cm.get_raw_table(&"Equip").get(str(_item_id), {}).get(&"Name", str(_item_id)))
	return String(cm.get_lstr(name_key))


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
func _open_compose() -> void:
	var panel := FragmentComposePanel.new("fragmentcompose", {})
	panel.setup_panel(_make_id, cm, pd)
	panel.composed.connect(_on_frag_composed)
	panel.show_window(get_parent())


# 本项目 emit composed 通知 PackagePanel 重 classify（碎片 cell 数量/角标变化），并关闭浮层
# （合成后碎片 cell 数据失效，照源 consumeAmount :55 amount<=0 equipLayer:popout 等价）。
func _on_frag_composed() -> void:
	composed.emit(_item_id)
	remove_window()


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


