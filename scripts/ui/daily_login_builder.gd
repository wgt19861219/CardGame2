class_name DailyLoginBuilder
extends RefCounted

## dailylogin 月签到 View 工厂（照源 ui/popwindow/dailylogin.lua）。
## create :734-887 主框架 + createSubhead :653-720 累计签到 +
## createList :380-420 网格 + createRewardItem :222-378 单格 + getRewardData :147-181 查表。
## 源 draglist（cliprect 滚动）→ Godot ScrollContainer（引擎适配，铁律允许）。
## 坐标源 cocos(800×480 左下) → Godot(960×640 左上)：to_godot(cx+80, 560-cy)（同 handbook_builder）。
## 单机化：源 status common/vip（VIP 双倍选项）→ 仅 common（领后 received）；VIP 角标保留装饰。

const OFFSET_X: float = 80.0
const BASE_Y: float = 560.0
const FALLBACK_YEAR: int = 2018
const COLS: int = 5   # 源 :241 wa=5 五列
# 源 create :749-874 主框架坐标（cocos）
const FRAME_CENTER: Vector2 = Vector2(400.0, 240.0)
const FRAME_SIZE: Vector2 = Vector2(578.0, 420.0)
const FRAME_CAP: Rect2 = Rect2(50.0, 50.0, 478.0, 50.0)
const TITLE_BG_CRUSADE_CENTER: Vector2 = Vector2(400.0, 441.0)
const ACT_BG_CENTER: Vector2 = Vector2(400.0, 420.0)
const ACT_BG_H: float = 35.0   # 源 :811 fix_size (0,35)
const TITLE_CENTER: Vector2 = Vector2(400.0, 444.0)
const CLOSE_CENTER: Vector2 = Vector2(675.0, 440.0)
const EXPLAIN_CENTER: Vector2 = Vector2(190.0, 400.0)
const EXPLAIN_SIZE: Vector2 = Vector2(105.0, 50.0)
const EXPLAIN_CAP: Rect2 = Rect2(20.0, 15.0, 88.0, 19.0)
const SUBHEAD_CENTER: Vector2 = Vector2(400.0, 386.0)
# 源 createListLayer :636 cliprect（cocos）→ Godot 滚动区
const CLIP_COCOS: Rect2 = Rect2(140.0, 40.0, 520.0, 335.0)
# 源 createRewardItem :231-243 网格（content 内坐标，godot 左上原点）
const CELL_OX: float = 58.0    # 源 ox=140+58，相对 reward_bg 左上
const CELL_OY: float = 56.0    # 源 oy=372-56，y 翻转后 56
const CELL_DX: float = 103.0   # 源 :233 dx
const CELL_DY: float = 101.0   # 源 :233 dy
const GRID_PAD_X: float = 12.0   # 源 :393 w=103*5+12
const GRID_PAD_Y: float = 14.0   # 源 :394 h=101*ha+14
# 源 createRewardItem board 内偏移（cocos (51,52) 等 → godot board 内左上原点，y 翻转）
const ICON_CENTER_LOCAL: Vector2 = Vector2(51.0, 78.0)    # 源 icon ccp(51,52)
const AMOUNT_LOCAL: Vector2 = Vector2(92.0, 108.0)        # 源 amount ccp(92,22) anchor(1,0.5)
const VIP_BG_TOPLEFT_LOCAL: Vector2 = Vector2(0.0, 28.0)  # 源 vip_bg ccp(0,102) anchor(0,1)
const VIP_TAG_LOCAL: Vector2 = Vector2(24.0, 50.0)        # 源 vipTag ccp(24,80) rot -45
const LIGHT_CENTER_LOCAL: Vector2 = Vector2(51.0, 80.0)   # 源 light ccp(51,50)
# 颜色（源 ccc3）
const TITLE_COLOR: Color = Color(231.0 / 255.0, 206.0 / 255.0, 19.0 / 255.0)
const SUBHEAD_PRE_COLOR: Color = Color(238.0 / 255.0, 204.0 / 255.0, 119.0 / 255.0)
const SUBHEAD_NUM_COLOR: Color = Color(1.0, 1.0, 1.0)
const SUBHEAD_SUF_COLOR: Color = Color(1.0, 204.0 / 255.0, 91.0 / 255.0)
const EXPLAIN_LABEL_COLOR: Color = Color(225.0 / 255.0, 209.0 / 255.0, 186.0 / 255.0)
const AMOUNT_STROKE_COLOR: Color = Color(95.0 / 255.0, 64.0 / 255.0, 43.0 / 255.0)
const VIP_NUM_COLOR: Color = Color(231.0 / 255.0, 206.0 / 255.0, 19.0 / 255.0)
# 字号（源 size）
const FONT_TITLE: int = 18
const FONT_SUBHEAD: int = 16
const FONT_AMOUNT: int = 24
const FONT_VIP: int = 14
# 资源
const FRAME_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_frame.png"
const TITLE_BG_RES: String = "res://assets/ui/alpha/HVGA/crusade_title_short_bg.png"
const ACT_BG_RES: String = "res://assets/ui/alpha/HVGA/act/act_popup_bg.png"
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const EXPLAIN_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_1.png"
const EXPLAIN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_2.png"
const REWARD_BG_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_reward_bg.png"
const REWARD_BG_CAP: Rect2 = Rect2(15.0, 15.0, 24.0, 25.0)
const MATRIX_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_matrix.png"
const MATRIX_YELLOW_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_matrix_yellow.png"
const CHECKED_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_checked.png"
const VIP_BG_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_vip_bg.png"
const LIGHT_RES: String = "res://assets/ui/alpha/HVGA/tavern_get_item_bg_light_orange.png"
const ICON_DIAMOND_RES: String = "res://assets/ui/alpha/HVGA/task_rmb_icon.png"
const ICON_GOLD_RES: String = "res://assets/ui/alpha/HVGA/task_gold_icon.png"
# 源 getRewardData :148-152 icon_res 映射（PlayerEXP 缺 task_exp_icon → 降级 Label）
const STATIC_ICON_MAP: Dictionary = {"Diamond": ICON_DIAMOND_RES, "Gold": ICON_GOLD_RES}


# 源 cocos(cx,cy) → Godot(cx+80, 560-cy)（同 handbook_builder 范式）。
static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# 源 create :734-887 主框架。返 {title, close, explain, subhead_num}（供 panel 接线/刷新）。
static func create_chrome(parent: Control, title_text: String, checkin_num: int) -> Dictionary:
	_add_nine_patch(parent, FRAME_RES, FRAME_CAP, to_godot(FRAME_CENTER.x, FRAME_CENTER.y) - FRAME_SIZE * 0.5, FRAME_SIZE)
	_add_centered(parent, TITLE_BG_RES, TITLE_BG_CRUSADE_CENTER)
	var act_tex: Texture2D = load(ACT_BG_RES) as Texture2D
	if act_tex != null:
		var act := TextureRect.new()
		act.texture = act_tex
		act.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		act.size = Vector2(act_tex.get_size().x, ACT_BG_H)
		act.position = to_godot(ACT_BG_CENTER.x, ACT_BG_CENTER.y) - act.size * 0.5
		act.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(act)
	var close: TextureButton = UiButton.make(CLOSE_RES, CLOSE_PRESS_RES, to_godot(CLOSE_CENTER.x, CLOSE_CENTER.y))
	parent.add_child(close)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	title.position = to_godot(TITLE_CENTER.x, TITLE_CENTER.y) - title.get_minimum_size() * 0.5
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(title)
	var explain: Button = UiScale9Button.make_centered(EXPLAIN_RES, EXPLAIN_PRESS_RES, to_godot(EXPLAIN_CENTER.x, EXPLAIN_CENTER.y), EXPLAIN_SIZE, EXPLAIN_CAP, "奖励说明", EXPLAIN_LABEL_COLOR)
	parent.add_child(explain)
	var subhead_num: Label = _create_subhead(parent, checkin_num)
	return {"title": title, "close": close, "explain": explain, "subhead_num": subhead_num}


# 源 createSubhead :653-720。返 subhead 数字 Label（供 refreshSubhead 更新）。
static func _create_subhead(parent: Control, checkin_num: int) -> Label:
	var anchor: Vector2 = to_godot(SUBHEAD_CENTER.x, SUBHEAD_CENTER.y)
	var pre := Label.new()
	pre.text = "本月累计签到"
	pre.add_theme_font_size_override("font_size", FONT_SUBHEAD)
	pre.add_theme_color_override("font_color", SUBHEAD_PRE_COLOR)
	pre.position = anchor
	pre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pre)
	var num := Label.new()
	num.text = str(checkin_num)
	num.add_theme_font_size_override("font_size", FONT_SUBHEAD)
	num.add_theme_color_override("font_color", SUBHEAD_NUM_COLOR)
	num.position = anchor + Vector2(pre.get_minimum_size().x + 5.0, 0.0)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(num)
	var suf := Label.new()
	suf.text = "次"
	suf.add_theme_font_size_override("font_size", FONT_SUBHEAD)
	suf.add_theme_color_override("font_color", SUBHEAD_SUF_COLOR)
	suf.position = num.position + Vector2(num.get_minimum_size().x + 5.0, 0.0)
	suf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(suf)
	return num


# 源 createList :380-420 + createListLayer :634-652。返 {scroll, content, cells}。
static func create_grid(parent: Control, data_list: Array, cell_statuses: Array, cm: Variant) -> Dictionary:
	var da: int = data_list.size()
	var scroll := ScrollContainer.new()
	scroll.position = to_godot(CLIP_COCOS.position.x, CLIP_COCOS.position.y + CLIP_COCOS.size.y)
	scroll.size = CLIP_COCOS.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)
	var ha: int = maxi(1, int(ceil(float(da) / float(COLS))))
	var gw: float = CELL_DX * float(COLS) + GRID_PAD_X
	var gh: float = CELL_DY * float(ha) + GRID_PAD_Y
	var content := Control.new()
	content.custom_minimum_size = Vector2(gw, gh)
	content.size = Vector2(gw, gh)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(content)
	_add_nine_patch(content, REWARD_BG_RES, REWARD_BG_CAP, Vector2.ZERO, Vector2(gw, gh))
	var cells: Array = []
	for i in range(da):
		var st: String = String(cell_statuses[i]) if i < cell_statuses.size() else "future"
		cells.append(create_reward_cell(content, i + 1, data_list[i], st, cm))
	return {"scroll": scroll, "content": content, "cells": cells}


# 源 createRewardItem :222-378。返 {button, data, day, status}（status 供 panel/测试）。
static func create_reward_cell(content: Control, day: int, data: Dictionary, status: String, cm: Variant) -> Dictionary:
	var x: int = (day - 1) % COLS
	var y: int = int((day - 1) / COLS)
	var center: Vector2 = Vector2(CELL_OX + CELL_DX * float(x), CELL_OY + CELL_DY * float(y))
	var board_res: String = MATRIX_YELLOW_RES if status == "common" else MATRIX_RES
	var board_tex: Texture2D = load(board_res) as Texture2D
	var bsz: Vector2 = board_tex.get_size() if board_tex != null else Vector2(133.0, 130.0)
	var board := TextureButton.new()
	board.texture_normal = board_tex
	board.ignore_texture_size = true
	board.size = bsz
	board.position = center - bsz * 0.5
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(board)
	var icon: Control = _make_reward_icon(data, cm)
	if icon != null:
		icon.position = ICON_CENTER_LOCAL - icon.size * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(icon)
	var amt_lbl := Label.new()
	amt_lbl.text = "x%d" % int(data.get("amount", 1))
	amt_lbl.add_theme_font_size_override("font_size", FONT_AMOUNT)
	amt_lbl.add_theme_color_override("font_color", Color.WHITE)
	amt_lbl.add_theme_color_override("font_outline_color", AMOUNT_STROKE_COLOR)
	amt_lbl.add_theme_constant_override("outline_size", 2)
	amt_lbl.position = AMOUNT_LOCAL - Vector2(amt_lbl.get_minimum_size().x, amt_lbl.get_minimum_size().y * 0.5)
	amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(amt_lbl)
	if status == "past":   # 源 :277-294 已领勾
		_add_image_to_board(board, CHECKED_RES, bsz * 0.5, 10, false)
	var vip: int = int(data.get("vip", 0))
	if vip > 0:   # 源 :335-355 VIP 角标
		_add_vip_tag(board, vip)
	if String(data.get("type", "")) == "Hero" and (status == "future" or status == "common"):   # 源 :297-316 光效
		_add_light(board)
	return {"button": board, "data": data, "day": day, "status": status}


# 源 getRewardData :147-181 + getRewardAt :37-54。查 DailyLoginReward 当月 1..N 天。
static func build_reward_data(cm: Variant) -> Array:
	var table: Dictionary = cm.get_raw_table(&"DailyLoginReward")
	var now_dict: Dictionary = Time.get_datetime_dict_from_system()
	var year: int = int(now_dict.get("year", FALLBACK_YEAR))
	var month: int = int(now_dict.get("month", 1))
	var month_data: Dictionary = {}
	for try_year in [year, FALLBACK_YEAR]:
		var md: Dictionary = table.get(str(try_year), {}).get(str(month), {})
		if not md.is_empty():
			month_data = md
			break
	if month_data.is_empty():
		return []
	var da: int = month_day_amount(month_data)
	var out: Array = []
	for i in range(1, da + 1):
		var row: Dictionary = month_data.get(str(i), {})
		if row.is_empty():
			break
		out.append({
			"type": String(row.get("Reward Type", "")),
			"id": int(row.get("Reward ID", 0)),
			"amount": int(row.get("Reward Amount", 0)),
			"vip": int(row.get("Double Reward VIP Level", 0)),
			"day": i,
		})
	return out


# 源 getMonthDayAmount :96-108。
static func month_day_amount(month_data: Dictionary) -> int:
	var i: int = 1
	while month_data.has(str(i)) and not String(month_data[str(i)].get("Reward Type", "")).is_empty():
		i += 1
	return i - 1


# 源 createRewardItem :317-334 icon（Item/Hero→readequip.createIcon；else→静态图）。
static func _make_reward_icon(data: Dictionary, cm: Variant) -> Control:
	var type: String = String(data.get("type", ""))
	var id: int = int(data.get("id", 0))
	if type == "Item" or type == "Hero":
		if id > 0:
			return ReadequipIcon.create_icon(id, 0, cm)
		return null
	var res_path: String = String(STATIC_ICON_MAP.get(type, ""))
	if res_path.is_empty():   # PlayerEXP 缺 task_exp_icon → 降级 Label
		var lbl := Label.new()
		lbl.text = "EXP"
		lbl.add_theme_font_size_override("font_size", FONT_AMOUNT)
		lbl.custom_minimum_size = Vector2(40.0, 30.0)
		lbl.size = Vector2(40.0, 30.0)
		return lbl
	var tex: Texture2D = load(res_path) as Texture2D
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = tex.get_size()
	return rect


# 源 createvipTag :202-221 + vip_bg。dailylogin_vip_<n>.png 缺 → 降级 vip_bg + Label。
static func _add_vip_tag(board: TextureButton, vip: int) -> void:
	_add_image_to_board(board, VIP_BG_RES, VIP_BG_TOPLEFT_LOCAL, 0, true)
	var num := Label.new()
	num.text = "VIP%d" % vip
	num.add_theme_font_size_override("font_size", FONT_VIP)
	num.add_theme_color_override("font_color", VIP_NUM_COLOR)
	num.add_theme_color_override("font_outline_color", Color.BLACK)
	num.add_theme_constant_override("outline_size", 1)
	num.position = VIP_TAG_LOCAL - num.get_minimum_size() * 0.5
	num.rotation = -PI / 4.0
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(num)


# 源 :297-316 Hero 光效 CCRotateBy(5,360) RepeatForever。
static func _add_light(board: TextureButton) -> void:
	var tex: Texture2D = load(LIGHT_RES) as Texture2D
	if tex == null:
		return
	var light := TextureRect.new()
	light.texture = tex
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.size = tex.get_size()
	light.pivot_offset = light.size * 0.5
	light.position = LIGHT_CENTER_LOCAL - light.pivot_offset
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(light)
	var tw := light.create_tween().set_loops()
	tw.tween_property(light, "rotation", TAU, 5.0).as_relative()


# NinePatchRect 九宫格（源 Scale9Sprite capInsets）。
static func _add_nine_patch(parent: Control, res_path: String, cap: Rect2, top_left: Vector2, target_size: Vector2) -> void:
	var np := NinePatchRect.new()
	var tex: Texture2D = load(res_path) as Texture2D
	np.texture = tex
	np.patch_margin_left = int(cap.position.x)
	np.patch_margin_top = int(cap.position.y)
	if tex != null:
		np.patch_margin_right = int(tex.get_width()) - int(cap.position.x) - int(cap.size.x)
		np.patch_margin_bottom = int(tex.get_height()) - int(cap.position.y) - int(cap.size.y)
	np.position = top_left
	np.custom_minimum_size = target_size
	np.size = target_size
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(np)


# Sprite 中心定位（源 anchor 0.5,0.5）。
static func _add_centered(parent: Control, res_path: String, cocos_center: Vector2) -> void:
	var tex: Texture2D = load(res_path) as Texture2D
	if tex == null:
		return
	var s := TextureRect.new()
	s.texture = tex
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.size = tex.get_size()
	s.position = to_godot(cocos_center.x, cocos_center.y) - tex.get_size() * 0.5
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


# board 内贴图（checked/vip_bg）。is_topleft=true 用左上定位否则中心。
static func _add_image_to_board(board: TextureButton, res_path: String, local_pos: Vector2, z: int, is_topleft: bool) -> void:
	var tex: Texture2D = load(res_path) as Texture2D
	if tex == null:
		return
	var s := TextureRect.new()
	s.texture = tex
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.size = tex.get_size()
	s.position = local_pos if is_topleft else (local_pos - tex.get_size() * 0.5)
	s.z_index = z
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(s)
