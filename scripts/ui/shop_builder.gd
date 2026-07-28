class_name ShopBuilder
extends RefCounted

## ShopPanel 视觉工厂（2026-07-17 重构）。
## base 层（frame/title/head/refresh/time/talk/close/money + bg.jpg）位置+size 静态化进 shop_content.tscn。
## 本类只往 .tscn 节点填动态数据（fill_*）：依 shop_id 的 frameRes/headRes/titleText/refresh cost/money/time。
## 商品列表（build_goods）仍 procedural 建节点（数量/内容动态），挂 %ItemLayer。

const OFFSET_X: float = 80.0
const BASE_Y: float = 560.0
const CONTENT_SCALE: float = 1.28125
# 源 shop.lua:198 商品 panel 按下 setScale(0.95)：press→缩 0.95，release→回弹 1.0（视觉反馈）。
const ITEM_PRESS_SCALE: Vector2 = Vector2(0.95, 0.95)
const ITEM_PRESS_SEC: float = 0.1

# ── 源 marketconfig.lua framePos（shop.lua:786 readNode layout.position = ui_config.framePos）──
# id=1 普通商人 framePos=ccp(400,225)。源 frame sprite anchor 0.5,0.5 中心。
# Godot PanelLayer.position = to_godot(framePos) - frame_display_size/2。
const FRAME_COCOS_CENTER: Vector2 = Vector2(400.0, 225.0)

# ── 商品列表（源 shop.lua:363-382 getItemPos）──
# lineCount=ceil(N/2)；index<=lineCount 上排，>lineCount 下排（y=oy-dy）。
const LIST_OX: float = 185.0
const LIST_DX: float = 205.0
const LIST_OY: float = 256.0
const LIST_DY: float = 150.0
# productBg display size = 源 shop_product_bg.png 261×187 / CS。
const ITEM_SIZE: Vector2 = Vector2(204.0, 146.0)
# 子元素相对 item 左上（源相对 productBg 左下 y-up → Godot y-down：y = ITEM_SIZE.y - cocos_y）。
const ITEM_ICON_POS: Vector2 = Vector2(100.0, 71.0)
const ITEM_NAME_POS: Vector2 = Vector2(100.0, 21.0)
const ITEM_COIN_POS: Vector2 = Vector2(40.0, 121.0)
const ITEM_PRICE_POS: Vector2 = Vector2(110.0, 121.0)
const ITEM_SOLDOUT_POS: Vector2 = Vector2(55.0, 60.0)
# C7（2026-07-23）：源 shop.lua:468-486 saleIcon + tagIcon
const ITEM_SALE_POS: Vector2 = Vector2(75.0, 96.0)
const ITEM_TAG_POS: Vector2 = Vector2(55.0, 91.0)
const SALE_ICON: String = "shop_sale_6.png"
const TAG_HOT_ICON: String = "shop_new.png"
const TAG_OLD_ICON: String = "shop_hot.png"
# C7 资源缺 Label 降级（shop_sale_6.png / shop_new.png / shop_hot.png 源 + 本项目均缺）
const SALE_FALLBACK_TEXT: String = "SALE"                # 打折标
const SALE_FALLBACK_COLOR: Color = Color(1.0, 0.3, 0.3) # 红色打折标
const TAG_FALLBACK: Dictionary = {
	"hot": {"text": "NEW", "color": Color(0.2, 0.8, 0.2)},
	"old": {"text": "HOT", "color": Color(1.0, 0.5, 0.1)},
}


static func _get_tag_icon(tag: String) -> String:
	match tag:
		"hot":
			return TAG_HOT_ICON
		"old":
			return TAG_OLD_ICON
		_:
			return ""


# C7：资源存在 → TextureRect；资源缺 → Label 降级（项目资源缺范式，同 soldout Label）
static func _add_texture_or_label(parent: Control, path: String, pos: Vector2, fallback_text: String, fallback_color: Color) -> void:
	if ResourceLoader.exists(path):
		_add_texture(parent, path, pos)
		return
	var lbl := Label.new()
	lbl.text = fallback_text
	lbl.position = pos
	lbl.modulate = fallback_color
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
const SOLDOUT_OPACITY: float = 0.5
const UNKNOWN_NAME: String = "???"
const UI_DIR: String = "res://assets/ui/alpha/HVGA/"


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# ==================== PanelLayer 位置 + Bg/Head/Title fill ====================

# 统一准备 PanelLayer 动态位置（依 frameRes display size）+ Bg/Head texture + Title text。
static func setup_panel_layer(panel_layer: Control, config: Dictionary) -> void:
	var frame_size: Vector2 = _frame_display_size(String(config["frameRes"]))
	panel_layer.position = to_godot(FRAME_COCOS_CENTER.x, FRAME_COCOS_CENTER.y) - frame_size * 0.5
	panel_layer.size = frame_size
	fill_bg(panel_layer.get_node("%Bg"), String(config["frameRes"]))
	fill_head(panel_layer.get_node("%Head"), String(config.get("headRes", "")))
	fill_title(panel_layer.get_node("%Title") as Label, String(config.get("titleText", "")))


# frame sprite display size = texture/CS（源 CCSprite 无 fix_size → 显示=纹理/CS）。
static func _frame_display_size(frame_res: String) -> Vector2:
	var path: String = UI_DIR + frame_res
	if not ResourceLoader.exists(path):
		return Vector2(702.0, 424.0)   # shop_bg.png 900×543 / CS fallback
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return Vector2(702.0, 424.0)
	return TexDisplaySize.display_size(path)


static func fill_bg(bg: TextureRect, frame_res: String) -> void:
	var path: String = UI_DIR + frame_res
	if not ResourceLoader.exists(path):
		return
	bg.texture = load(path) as Texture2D


static func fill_head(head: TextureRect, head_res: String) -> void:
	if head_res.is_empty():
		return
	var path: String = UI_DIR + head_res
	if not ResourceLoader.exists(path):
		return
	head.texture = load(path) as Texture2D


# 源 shop_title_1/2/3.png 缺 → Label 降级（项目资源缺图范式），fill titleText。
static func fill_title(label: Label, title_text: String) -> void:
	label.text = title_text


# ==================== 货币 / 刷新 cost / 时刻 fill ====================

static func fill_money(label: Label, p_pd: PlayerData) -> void:
	label.text = "金币:%d 钻石:%d" % [p_pd.hero_manager.gold, p_pd.diamond]


static func fill_refresh_cost(label: Label, cost: int) -> void:
	label.text = "%d钻" % cost


# 否则显下次刷新时刻。两者皆空则 Label 清空。
static func fill_time_label(label: Label, shop_id: int, shop_mgr: ShopManager, p_pd: PlayerData, now_ts: int, p_cm: Variant) -> void:
	var tt: String = shop_mgr.get_time_type(shop_id, p_pd, now_ts)
	if tt == "expire":
		var exp: String = shop_mgr.get_expire_desc(shop_id, p_pd, now_ts)
		if exp == "":
			label.text = ""
		else:
			label.text = String(p_cm.get_lstr("SHOP.MERCHANT_LEAVES_AFTER")) + " " + exp + " " + String(p_cm.get_lstr("SHOP.TIMES"))
		return
	var desc: String = shop_mgr.get_next_refresh_desc(shop_id, p_pd, now_ts)
	label.text = String(p_cm.get_lstr("SHOP.NEXT_AUTOMATICALLY_REFRESH_TIME")) + desc if desc != "" else ""


# ==================== 商品列表（动态 procedural，挂 %ItemLayer）====================

# panel 先 free 老子节点再调本方法。返新建 item Control 列表（已 add 到 item_layer）。
static func build_goods(item_layer: Control, goods: Array, config: Dictionary, p_cm: Variant) -> Array:
	var items: Array = []
	var line_count: int = int(ceil(float(goods.size()) / 2.0))
	for i in goods.size():
		var g: Dictionary = goods[i]
		var cocos_pos: Vector2 = _get_item_pos(i + 1, line_count)
		var top_left: Vector2 = to_godot(cocos_pos.x, cocos_pos.y) - ITEM_SIZE * 0.5
		var item: Control = _create_item(g, top_left, config, p_cm)
		item.set_meta(&"shop_slot", i)   # 标记商品 slot（panel 连信号 + 测试识别）
		item_layer.add_child(item)
		items.append(item)
	return items


# x = ox + (col-1)*dx；上排 col=index，下排 col=index-lineCount。
static func _get_item_pos(index: int, line_count: int) -> Vector2:
	if index <= line_count:
		return Vector2(LIST_OX + float(index - 1) * LIST_DX, LIST_OY)
	var col: int = index - line_count
	return Vector2(LIST_OX + float(col - 1) * LIST_DX, LIST_OY - LIST_DY)


static func _create_item(g: Dictionary, top_left: Vector2, config: Dictionary, p_cm: Variant) -> Control:
	var item := Control.new()
	item.position = top_left
	item.size = ITEM_SIZE
	# pivot 居中：源 panel anchor(0.5,0.5) 按中心 setScale → Godot Control scale 绕 pivot_offset。
	item.pivot_offset = ITEM_SIZE * 0.5
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_texture(item, UI_DIR + String(config["productBgRes"]), Vector2.ZERO)
	var equip_row: Dictionary = p_cm.get_raw_table(&"Equip").get(str(g["id"]), {})
	var icon: Control = ReadequipIcon.create_icon(int(g["id"]), int(g.get("amount", 1)), p_cm)
	icon.position = ITEM_ICON_POS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = String(p_cm.get_lstr(String(equip_row.get("Name", UNKNOWN_NAME))))
	name_lbl.position = ITEM_NAME_POS
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(name_lbl)
	_add_texture(item, UI_DIR + MarketConfig.get_coin_res(String(g["type"])), ITEM_COIN_POS)
	var price_lbl := Label.new()
	price_lbl.text = str(int(g["price"]))
	price_lbl.position = ITEM_PRICE_POS
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(price_lbl)
	# C7（2026-07-23）：源 shop.lua:468-486 saleIcon（data.sale==1）+ tagIcon（tagRes 非空）。
	# 项目 ShopManager.get_goods 字段名 is_sale（照源 _is_sale 翻译），tag 暂无（isShowHotTag 缺口）。
	# shop_sale_6.png / shop_new.png / shop_hot.png 资源缺（源 + 本项目均缺）→ Label 降级（与 soldout 范式一致）。
	if int(g.get("is_sale", 0)) == 1:
		_add_texture_or_label(item, UI_DIR + SALE_ICON, ITEM_SALE_POS, SALE_FALLBACK_TEXT, SALE_FALLBACK_COLOR)
	var tag_str: String = String(g.get("tag", ""))
	var tag_icon: String = _get_tag_icon(tag_str)
	if tag_icon != "":
		var fb: Dictionary = TAG_FALLBACK.get(tag_str, {"text": "", "color": Color.WHITE})
		_add_texture_or_label(item, UI_DIR + tag_icon, ITEM_TAG_POS, String(fb.get("text", "")), Color(fb.get("color", Color.WHITE)))
	if int(g.get("amount", 0)) <= 0:
		var sold := Label.new()
		sold.text = "售罄"
		sold.position = ITEM_SOLDOUT_POS
		sold.modulate = Color.RED
		sold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(sold)
		item.modulate.a = SOLDOUT_OPACITY
	return item


# 统一 CS 校正：源 CCSprite 无 fix_size → 显示=纹理/CS；Godot TextureRect 默认 KEEP_SIZE 偏大 1.28。
# EXPAND_IGNORE_SIZE 让 TextureRect 接受手动 size，避免按纹理原尺寸撑大；size = 纹理 / CS 还原源显示尺寸。
static func _add_texture(parent: Control, path: String, pos: Vector2) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.position = pos
	tr.size = TexDisplaySize.display_size(path)
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
