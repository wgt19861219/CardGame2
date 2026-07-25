class_name DailyLoginBuilder
extends RefCounted

## dailylogin 月签到 View 工厂（照源 ui/popwindow/dailylogin.lua）。
## create :734-887 主框架 + createSubhead :653-720 累计签到 +
## createList :380-420 网格 + createRewardItem :222-378 单格 + getRewardData :147-181 查表。
## 重构（2026-07-18，hero_detail 范式）：chrome（frame/title_bg/act_bg/close/title/explain/subhead 3 label/
## grid ScrollContainer）静态化进 daily_login_content.tscn，panel 用 preload + get_node("%..")；
## 本 builder 仅保留 fill_grid（content + 单格 procedural 挂 %GridScroll）+ 数据查表。
## 单机化：源 status common/vip（VIP 双倍选项）→ 仅 common（领后 received）；VIP 角标保留装饰。

const CONTENT_SCALE: float = 1.28125
const FALLBACK_YEAR: int = 2018
const COLS: int = 5
const CELL_OX: float = 58.0
const CELL_OY: float = 56.0
const CELL_DX: float = 103.0
const CELL_DY: float = 101.0
const GRID_PAD_X: float = 12.0
const GRID_PAD_Y: float = 14.0
# board 显示高 101.5 = raw 130 / CONTENT_SCALE 1.28125；y 翻转用 101.5 - cocos_y（非 raw 130）。
const ICON_CENTER_LOCAL: Vector2 = Vector2(51.0, 49.5)
const AMOUNT_LOCAL: Vector2 = Vector2(92.0, 79.5)
const VIP_BG_TOPLEFT_LOCAL: Vector2 = Vector2(0.0, -0.5)
const VIP_TAG_LOCAL: Vector2 = Vector2(24.0, 21.5)
const LIGHT_CENTER_LOCAL: Vector2 = Vector2(51.0, 51.5)
# 颜色（源 ccc3）
const AMOUNT_STROKE_COLOR: Color = Color(95.0 / 255.0, 64.0 / 255.0, 43.0 / 255.0)
const VIP_NUM_COLOR: Color = Color(231.0 / 255.0, 206.0 / 255.0, 19.0 / 255.0)
# 字号（源 size）
const FONT_AMOUNT: int = 24
const FONT_VIP: int = 14
# 资源
const REWARD_BG_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_reward_bg.png"
const REWARD_BG_CAP: Rect2 = Rect2(15.0, 15.0, 24.0, 25.0)
const MATRIX_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_matrix.png"
const MATRIX_YELLOW_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_matrix_yellow.png"
const CHECKED_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_checked.png"
const VIP_BG_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_vip_bg.png"
const LIGHT_RES: String = "res://assets/ui/alpha/HVGA/tavern_get_item_bg_light_orange.png"
const ICON_DIAMOND_RES: String = "res://assets/ui/alpha/HVGA/task_rmb_icon.png"
const ICON_GOLD_RES: String = "res://assets/ui/alpha/HVGA/task_gold_icon.png"
const STATIC_ICON_MAP: Dictionary = {"Diamond": ICON_DIAMOND_RES, "Gold": ICON_GOLD_RES}


# scroll 由 .tscn 静态化（位置/size 固化），content + cells 动态挂 scroll。
static func fill_grid(scroll: ScrollContainer, data_list: Array, cell_statuses: Array, cm: Variant) -> Dictionary:
	var da: int = data_list.size()
	for c in scroll.get_children():
		c.queue_free()
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
	return {"content": content, "cells": cells}


static func create_reward_cell(content: Control, day: int, data: Dictionary, status: String, cm: Variant) -> Dictionary:
	var x: int = (day - 1) % COLS
	var y: int = int((day - 1) / COLS)
	var center: Vector2 = Vector2(CELL_OX + CELL_DX * float(x), CELL_OY + CELL_DY * float(y))
	var board_res: String = MATRIX_YELLOW_RES if status == "common" else MATRIX_RES
	var board_tex: Texture2D = load(board_res) as Texture2D
	var bsz: Vector2 = TexDisplaySize.display_size(board_res) if board_tex != null else Vector2(133.0, 130.0) / CONTENT_SCALE
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
	if status == "past":
		_add_image_to_board(board, CHECKED_RES, bsz * 0.5, 10, false)
	var vip: int = int(data.get("vip", 0))
	if vip > 0:
		_add_vip_tag(board, vip)
	if String(data.get("type", "")) == "Hero" and (status == "future" or status == "common"):
		_add_light(board)
	return {"button": board, "data": data, "day": day, "status": status}


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


static func month_day_amount(month_data: Dictionary) -> int:
	var i: int = 1
	while month_data.has(str(i)) and not String(month_data[str(i)].get("Reward Type", "")).is_empty():
		i += 1
	return i - 1


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
	rect.size = TexDisplaySize.display_size(res_path)
	return rect


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


static func _add_light(board: TextureButton) -> void:
	var tex: Texture2D = load(LIGHT_RES) as Texture2D
	if tex == null:
		return
	var light := TextureRect.new()
	light.texture = tex
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.size = TexDisplaySize.display_size(LIGHT_RES)
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


# board 内贴图（checked/vip_bg）。is_topleft=true 用左上定位否则中心。
static func _add_image_to_board(board: TextureButton, res_path: String, local_pos: Vector2, z: int, is_topleft: bool) -> void:
	var tex: Texture2D = load(res_path) as Texture2D
	if tex == null:
		return
	var s := TextureRect.new()
	s.texture = tex
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var sz: Vector2 = TexDisplaySize.display_size(res_path)
	s.size = sz
	s.position = local_pos if is_topleft else (local_pos - sz * 0.5)
	s.z_index = z
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(s)
