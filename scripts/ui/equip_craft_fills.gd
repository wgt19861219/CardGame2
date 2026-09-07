class_name EquipCraftFills
extends RefCounted

## EquipCraftPanel 纯数据填充（两件套范式，批 1 Task 10）。
## 只做动态 fill：装备详情（icon/名/拥有量/属性行）+ 合成历史栏动态行构建。
## 静态结构与样式归 equip_craft_content.tscn + default_theme（禁建静态节点、禁样式 override，
## 对齐 hero_detail_fills 范式）。panel 只留业务/信号/流程。

# 源 board.lua:320 initTitle icon@ccp(50,328)：createIcon(id) 未传 length → frame 73.37×74.17
# 原尺寸显示（readequip.lua:764-767 length 缩放仅显式传入时生效），ccp(50,328) 系 frame
# 中心（Cocos sprite 默认 anchor 0.5,0.5）→ 左上 = (50-36.7, 385-328-37.1) = (13.3, 19.9)。
# 旧值 (14,21) 系中心−容器 72/2 的误算（frame 94×95÷CS=73.37×74.17 溢出容器，半尺寸应为 36.7/37.1），
# 且旧实现误加 ROOT_ICON_SCALE 0.817（那是合成树 equipcraft.lua:1031 createIcon(id,60) 的产物
# 缩放，初始详情面板源码无此参）→ 图标缩小 0.82 倍 + 偏左上（2026-09-06 修复）。
const ICON_POS: Vector2 = Vector2(13.3, 19.9)
# 源 board.lua:55-70 拥有量 "EQUIPINFO.HAVE %d EQUIPINFO.ITEM"
const LSTR_HAVE: String = "EQUIPINFO.HAVE"
const LSTR_ITEM: String = "EQUIPINFO.ITEM"
# 历史栏（源 equipcraft.lua:843-872：ori=(55,350) + arrow 分隔；createSmallIcon →
# readequip.lua:877 createIcon(id,38) → 显示 38 点，2026-08-22 巡检订正旧注释 40）
const HISTORY_ICON_SCALE: float = 38.0 / (94.0 / 1.28125)
# 历史项 frame 缩放后显示尺寸（73.37×74.17 × 0.518 ≈ 38×38.4）——wrapper min size 用。
const HISTORY_ICON_DISP: Vector2 = Vector2(94.0 / 1.28125, 95.0 / 1.28125) * (38.0 / (94.0 / 1.28125))
const HISTORY_ARROW_PATH: String = "res://assets/ui/alpha/HVGA/view_history_arrow.png"
# history layer 挂 %HistoryClip（源 draglist cliprect 原点 bg 局部 (12,300)）。
# 源 setHistory :848-855 ori=ccp(55,350) 系 createSmallIcon 产物 sprite（中心锚）首项**中心**，
# 相对 clip 左上 = (55-12, 80-(350-300)) = (43,30)；HBox 摆的是 wrapper **左上** → 须再减
# icon 半显示尺寸（38×38.4 /2 = 19×19.2）= (24,10.8)。旧值 (43,30) 直用致整体偏右下 19px
#（2026-09-07 复验实测图标中心 (477.5,99) vs 源 (459,82) 修正）。
const HISTORY_CLIP_ORIGIN: Vector2 = Vector2(43.0, 30.0) - HISTORY_ICON_DISP * 0.5
# 源 board.lua:259-263 att_bg:setContentSize(bw, attListHeight+12)：bg 高 = 属性行总高 + 12
#（宽度不变 254.4 = package_detail_bg_2 326÷CS，静态进 tscn）。旧实现静态固定 160 → 属性 1 行
# 时框内 130px 空白（2026-09-06 修复）。
const ATT_BG_PAD_Y: float = 12.0


# 装备详情 fill（源 board.lua refreshAmount:22-42 + initTitle:322-341 + initAtt:106-259）：
# icon 挂 %IconHost + %NameLabel/%AmountLabel 文本 + %AttHost 属性多行动态行。
static func fill_equip_layer(panel) -> void:
	if panel._equip_layer == null:
		return
	for c in panel._icon_host.get_children():
		c.free()
	if panel._target_id > 0:
		var icon: Control = ReadequipIcon.create_icon(panel._target_id, panel._get_amount(panel._target_id), panel.cm)
		icon.position = ICON_POS
		panel._icon_host.add_child(icon)
	panel._name_label.text = panel._equip_name(panel._target_id)
	var amt: int = panel._get_amount(panel._target_id)
	panel._amount_label.text = "%s %d %s" % [String(panel.cm.get_lstr(LSTR_HAVE)), amt, String(panel.cm.get_lstr(LSTR_ITEM))]
	for c in panel._att_host.get_children():
		c.free()
	var rows: Array = ReadequipData.get_description(panel._target_id, 0, panel.cm)
	for row in rows:
		var r: Dictionary = row as Dictionary
		var lbl := Label.new()
		lbl.text = String(r.get("att", "")) + String(r.get("add", ""))
		lbl.theme_type_variation = &"EquipCraftAttLabel"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel._att_host.add_child(lbl)
	# 源 board.lua:231-237：非碎片装备 lineCount<5 时补 1 空行（att_bg 高度兜底，防 1 行属性贴顶孤框）
	if rows.size() < 5:
		var blank := Label.new()
		blank.text = " "
		blank.theme_type_variation = &"EquipCraftAttLabel"
		blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel._att_host.add_child(blank)
	# 源 board.lua:259-263：att_bg 高度随行数动态 setContentHeight（AttBg 静态 254.4 宽 + fill 动态高）。
	# fill 时 content 尚未随 show_window 挂树，Label theme 沿树解析不到 → combined minimum size 为 0
	#（实测首帧 AttBg 高度塌成 12=纯 padding），须 deferred 到帧末挂树后再量。
	var att_bg: Control = panel._content.get_node("EquipLayer/AttBg") as Control
	_update_att_bg_height.call_deferred(panel._att_host, att_bg)


# 帧末（content 已挂树、theme 可解析）按属性行实际高度设 AttBg 高度。
static func _update_att_bg_height(host: VBoxContainer, att_bg: Control) -> void:
	att_bg.size.y = host.get_combined_minimum_size().y + ATT_BG_PAD_Y


# 历史栏容器（源 createHistoryLayer :799-816 draglist.listLayer → HBox 挂 %HistoryClip 裁剪域）。
# separation 走全局 HBoxContainer/separation=8（default_theme，源 icon 间距 58 由 icon+arrow 尺寸合成）。
static func create_history_layer(panel) -> Control:
	if panel._history_layer != null and is_instance_valid(panel._history_layer):
		return panel._history_layer
	var layer := HBoxContainer.new()
	layer.position = HISTORY_CLIP_ORIGIN
	var clip: Control = panel._content.get_node("%HistoryClip") as Control
	clip.add_child(layer)
	panel._history_layer = layer
	return layer


# 追加一个历史节点（源 setHistory :848-872：len>0 时先加 view_history_arrow，再加 icon）。
# 返 iconBg wrapper（panel 连 gui_input handler 并存 _history）。
# ⚠️ HBoxContainer 布局会重置直接子节点的 scale（headless 实验实锤：add 后 0.518→1.0，
# 2026-09-07 顶部历史图标偏大 1.9 倍根因）——38 点缩放须经 wrapper 隔离：HBox 子=wrapper
#（min=frame 显示 38×38.4），icon_bg 挂 wrapper 内施 scale。
static func append_history_node(panel, layer: Control, id: int) -> Control:
	var len_: int = panel._history.size()
	var icon_bg: Control = ReadequipIcon.create_icon(id, 0, panel.cm)
	icon_bg.scale = Vector2(HISTORY_ICON_SCALE, HISTORY_ICON_SCALE)
	var wrapper := Control.new()
	wrapper.custom_minimum_size = HISTORY_ICON_DISP
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.add_child(icon_bg)
	if len_ > 0:
		# HBoxContainer 管子节点 layout，须用 custom_minimum_size（非 size）分配空间 + EXPAND_IGNORE_SIZE 让纹理 stretch 入框。
		var arrow := TextureRect.new()
		arrow.texture = load(HISTORY_ARROW_PATH)
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.custom_minimum_size = TexDisplaySize.display_size(HISTORY_ARROW_PATH)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(arrow)
	layer.add_child(wrapper)
	return wrapper
