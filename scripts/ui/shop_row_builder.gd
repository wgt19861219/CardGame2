class_name ShopRowBuilder
extends RefCounted

## 商店商品行动态构建（两件套范式 2026-08-14）：静态结构在 shop_item.tscn 模板，
## 本类只定位行 + 填动态数据 + 徽标/售罄切换（源 shop.lua:363-382 getItemPos + createCommon item）。
## saleIcon/tagIcon 资源缺（源+本项目均无）→ Label 徽标直出（受控简化，美术到位改模板节点）。

const ITEM_SCENE: PackedScene = preload("res://scenes/ui/shop_item.tscn")
const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
const OFFSET_X: float = 80.0
const BASE_Y: float = 560.0
# 源 shop.lua:363-382 getItemPos：lineCount=ceil(N/2)；上排 y=oy，下排 y=oy-dy。
const LIST_OX: float = 185.0
const LIST_DX: float = 205.0
const LIST_OY: float = 256.0
const LIST_DY: float = 150.0
const ITEM_SIZE: Vector2 = Vector2(204.0, 146.0)
# 源 shop.lua createListLayer cliprect CCRectMake(65,35,670,325) → to_godot 左上 (145,200)，ItemLayer 裁剪层原点。
const LIST_CLIP_ORIGIN: Vector2 = Vector2(145.0, 200.0)
const UNKNOWN_NAME: String = "???"
const SOLDOUT_OPACITY: float = 0.5
# C7（2026-07-23）照源 shop.lua:468-486：saleIcon 打折标 + tagIcon hot/old 标（资源缺 Label 降级文案/配色）。
const SALE_TEXT: String = "SALE"
const SALE_COLOR: Color = Color(1.0, 0.3, 0.3)
const TAG_FALLBACK: Dictionary = {
	"hot": {"text": "NEW", "color": Color(0.2, 0.8, 0.2)},
	"old": {"text": "HOT", "color": Color(1.0, 0.5, 0.1)},
}


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# 建商品行列表（panel 先 free 老子节点再调）。返 item 列表（已 add 到 item_layer，含 shop_slot meta）。
static func build_goods(item_layer: Control, goods: Array, config: Dictionary, p_cm: Variant) -> Array:
	var items: Array = []
	var line_count: int = int(ceil(float(goods.size()) / 2.0))
	for i in goods.size():
		var g: Dictionary = goods[i]
		var cocos_pos: Vector2 = _get_item_pos(i + 1, line_count)
		var top_left: Vector2 = to_godot(cocos_pos.x, cocos_pos.y) - ITEM_SIZE * 0.5 - LIST_CLIP_ORIGIN
		var item: Control = _create_item(g, top_left, config, p_cm)
		item.set_meta(&"shop_slot", i)
		item_layer.add_child(item)
		items.append(item)
	return items


# x = ox + (col-1)*dx；上排 col=index，下排 col=index-lineCount（源 getItemPos）。
static func _get_item_pos(index: int, line_count: int) -> Vector2:
	if index <= line_count:
		return Vector2(LIST_OX + float(index - 1) * LIST_DX, LIST_OY)
	var col: int = index - line_count
	return Vector2(LIST_OX + float(col - 1) * LIST_DX, LIST_OY - LIST_DY)


static func _create_item(g: Dictionary, top_left: Vector2, config: Dictionary, p_cm: Variant) -> Control:
	var item: Control = ITEM_SCENE.instantiate() as Control
	item.position = top_left
	item.size = ITEM_SIZE
	var bg_rect: TextureRect = item.get_node("%ProductBg") as TextureRect
	var bg_path: String = UI_DIR + String(config.get("productBgRes", ""))
	if ResourceLoader.exists(bg_path):
		bg_rect.texture = load(bg_path) as Texture2D   # id=2/3 商店行底图切 shop_product_bg_2.png（market_config.gd:41）
	var equip_row: Dictionary = p_cm.get_raw_table(&"Equip").get(str(g["id"]), {})
	var icon: Control = ReadequipIcon.create_icon(int(g["id"]), int(g.get("amount", 1)), p_cm)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(item.get_node("%IconHost") as Control).add_child(icon)
	(item.get_node("%NameLabel") as Label).text = String(p_cm.get_lstr(String(equip_row.get("Name", UNKNOWN_NAME))))
	_add_texture(item.get_node("%CoinHost") as Control, UI_DIR + MarketConfig.get_coin_res(String(g["type"])))
	(item.get_node("%PriceLabel") as Label).text = str(int(g["price"]))
	_fill_badge(item.get_node("%SaleBadge") as Label, SALE_TEXT, SALE_COLOR, int(g.get("is_sale", 0)) == 1)
	var tag_str: String = String(g.get("tag", ""))
	var fb: Dictionary = TAG_FALLBACK.get(tag_str, {})
	_fill_badge(item.get_node("%TagBadge") as Label, String(fb.get("text", "")), Color(fb.get("color", Color.WHITE)), not fb.is_empty())
	if int(g.get("amount", 0)) <= 0:
		var sold: Label = item.get_node("%SoldoutLabel") as Label
		sold.modulate = Color.RED
		sold.visible = true
		item.modulate.a = SOLDOUT_OPACITY
	return item


static func _fill_badge(badge: Label, text: String, color: Color, show: bool) -> void:
	badge.visible = show and text != ""
	if not badge.visible:
		return
	badge.text = text
	badge.modulate = color


# CS 校正（源 CCSprite 显示=纹理/CS，hello.lua:311 CS=1.28125）：size = 纹理 / CS。
static func _add_texture(parent: Control, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.size = TexDisplaySize.display_size(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
