class_name StarShopPanel
extends PopWindow

## 星辰商店面板（View 层）— 照源 ui/market/shop.lua create("starshop") + createStarList(:512)。
## 5 件灵魂石商品单行横滚布局 + box icon + 灵魂石消耗显示 + 点击弹 StarShopBuyWindow 确认。
## 单机化：源 tavern_draw stone net → ShopManager.buy_star；源 time 行/showTalk 气泡/
## head_rect 点击区无对应系统裁剪（记录于批 2 Task 4 验收）。
##
## 批 2 两件套改造（2026-08-16）：chrome 静态化进 scenes/ui/star_shop_content.tscn
## （frame/title 图÷CS 照源 rect + draglist cliprect 直译），商品格 8 节点模板化
## scenes/ui/star_shop_item.tscn（itemstarshop.lua 声明表直译，item_press 由 root
## pressed 态承担），panel 仅 fill（LSTR 文案/box 图/价格色/售罄态）。
## 源 cocos(800×480 左下) → Godot 场景空间 (cx+80, 560-cy)；CS=1.28125。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/star_shop_content.tscn")
const ITEM_SCENE: PackedScene = preload("res://scenes/ui/star_shop_item.tscn")

# 商品行布局（源 createStarList :512-531：getItemPos ox=90 oy=35 dx=212，listLayer=场景
# 原点；ItemLayer 挂裁剪层 (145,200) 内 → 局部 x = 90+80-145 = 25、行顶 = 560-(35+286.72)-200 = 38.28）
const ITEM_LOCAL_X: float = 25.0
const ITEM_LOCAL_Y: float = 38.28
const ITEM_DX: float = 212.0
const LIST_MIN_W: float = 1100.0
const LIST_MIN_H: float = 325.0
# 灵魂石 icon（源 :571 createIcon(stone_id, 46) → 显示 46 点）：ReadequipIcon 的 frame
# Sprite2D 按纹理原尺寸渲染（94×95px，hero_detail 装备槽同口径），故 scale 基准取纹理
# 像素宽 94 而非 container 72（task-11 修：旧 72 基准致视觉 1.28× 偏大溢出容器）
const STONE_ICON_SIDE: float = 46.0
const STONE_ICON_BASE: float = 94.0
const STONE_FRAME_H: float = 95.0
const STONE_HOST_SIDE: float = 45.31
const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
const STAR_BOX_RES: Array[String] = ["shop_star_box_1.png", "shop_star_box_2.png", "shop_star_box_3.png"]
const GOODS_NAME_LSTR: Array[String] = ["PARAMETER.SMALL_PLANET_DEBRIS_BOX", "PARAMETER.MEDIUM_STELLAR_SUITCASE", "PARAMETER.LARGE_INTERSTELLAR_GALLERY"]
const COST_TITLE_LSTR: String = "ITEMSTARSHOP.NEED_TO_CONSUME_THE_SOUL_STONE"
const STONE_SHORT_LSTR: String = "SHOP.SOUL_STONE_QUANTITY_IS_INSUFFICIENT_YOU_CANNOT_BUY_"
# 价格色（源 marketconfig costLabelColor + refreshCostLabel :75-86 不足红）
const COST_COLOR_OK: Color = Color(150.0 / 255.0, 236.0 / 255.0, 255.0 / 255.0)
const COST_COLOR_SHORT: Color = Color(1.0, 0.0, 0.0)

var shop_mgr: ShopManager
var cm: Variant = null
var pd: PlayerData = null
var rng: BattleRng
var _item_layer: Control
var _rows: Array = []   # 行 fill 句柄 {root,stone_name,none_tag,stone_id,cost,amount}


func setup_panel(p_mgr: ShopManager, p_pd: PlayerData, p_rng: BattleRng) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类
	shop_mgr = p_mgr
	pd = p_pd
	rng = p_rng
	cm = pd.cm
	setup()
	hud_identity = "starshop"   # 2026-08-18 修复轮二 R2：主城直开——切子场景 StatusBar（无头像，excavate 判例），用户反馈主头像透到二级界面
	shop_mgr.open_star_shop()
	# 本项目单机化 pushScene→PopWindow，故 shade 透明 + .tscn %FrameworkBg 补 bg.jpg 还原源视觉（同 PackagePanel 范式）。
	_build_content()


# 建 UI 内容：chrome 从 .tscn instantiate（位置/size 可视化）；商品格走 item 模板 fill。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")
		remove_window())
	_item_layer = content.get_node("%ItemLayer") as Control
	_item_layer.custom_minimum_size = Vector2(LIST_MIN_W, LIST_MIN_H)
	_build_goods()


# 商品行装配（源 createStarList :535-594）：逐件实例化 item 模板 + 定位 + fill + 点击绑定。
func _build_goods() -> void:
	_rows.clear()
	var goods: Array = shop_mgr.get_star_goods()
	for i in goods.size():
		var g: Dictionary = goods[i]
		var row := ITEM_SCENE.instantiate() as TextureButton
		row.position = Vector2(ITEM_LOCAL_X + ITEM_DX * float(i), ITEM_LOCAL_Y)
		_item_layer.add_child(row)
		_fill_row(row, g)
		row.pressed.connect(_open_buy_window.bind(i))
		_rows.append({
			"root": row,
			"stone_name": row.get_node("%StoneName") as Label,
			"none_tag": row.get_node("%NoneTag") as TextureRect,
			"stone_id": int(g.get("stone_id", 0)),
			"cost": int(g.get("stone_amount", 0)),
			"amount": int(g.get("amount", 0)),
		})
	_apply_cost_colors()


# 单行 fill：LSTR 文案/box 图/灵魂石 icon/售罄态/价格色。
func _fill_row(row: TextureButton, g: Dictionary) -> void:
	var t: int = int(g.get("type", 0))
	(row.get_node("%ItemName") as Label).text = cm.get_lstr(GOODS_NAME_LSTR[t])
	(row.get_node("%CostTitleLabel") as Label).text = cm.get_lstr(COST_TITLE_LSTR)
	(row.get_node("%StoneName") as Label).text = "x" + str(int(g.get("stone_amount", 0)))
	var box: TextureRect = row.get_node("%BoxIcon") as TextureRect
	var box_path: String = UI_DIR + STAR_BOX_RES[t]
	if ResourceLoader.exists(box_path):
		box.texture = load(box_path) as Texture2D
	_fill_stone_icon(row.get_node("%StoneHost") as Control, int(g.get("stone_id", 0)))
	# 售罄（源 :577-588 noneTag visible=amount<1；refreshGoods :118 成交后价格隐藏）
	var soldout: bool = int(g.get("amount", 0)) < 1
	(row.get_node("%NoneTag") as TextureRect).visible = soldout
	(row.get_node("%StoneName") as Label).visible = not soldout


# 灵魂石消耗 icon（源 :568-576 createIcon(stone_id,46) anchor(0,0) at(0,0)）：
# scale=46/94 → 视觉 46×46.49（源显示 74.13×46/73.37 同值）；左下对齐（Godot y=容器高-视觉高）；
# Equip 表缺 8/9/10 条目 → 默认降级框，数据补齐自动恢复。
func _fill_stone_icon(host: Control, stone_id: int) -> void:
	var icon := ReadequipIcon.create_icon(stone_id, 0, cm)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.scale = Vector2.ONE * (STONE_ICON_SIDE / STONE_ICON_BASE)
	var vis_h: float = STONE_FRAME_H * STONE_ICON_SIDE / STONE_ICON_BASE
	icon.position = Vector2(0.0, STONE_HOST_SIDE - vis_h)
	host.add_child(icon)


# 价格色（源 refreshCostLabel :75-86）：amount>=1 且余额不足 → 红；否则 costLabelColor。
func _apply_cost_colors() -> void:
	for r in _rows:
		var row: Dictionary = r
		var label: Label = row["stone_name"]
		if not is_instance_valid(label) or not label.visible:
			continue
		var enough: bool = _stone_count(int(row["stone_id"])) >= int(row["cost"])
		label.modulate = COST_COLOR_OK if enough else COST_COLOR_SHORT


func _stone_count(stone_id: int) -> int:
	return int(pd.items.get(stone_id, 0))


# 点击商品（源 doClickInProduct stone 分支 :239-277）：售罄 toast / 灵魂石不足 toast / 开确认窗。
func _open_buy_window(slot: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var goods: Array = shop_mgr.get_star_goods()
	if slot >= goods.size():
		return
	var g: Dictionary = goods[slot]
	if int(g.get("amount", 0)) <= 0:
		Toast.show_message("已售罄")
		return
	if _stone_count(int(g.get("stone_id", 0))) < int(g.get("stone_amount", 0)):
		Toast.show_message(cm.get_lstr(STONE_SHORT_LSTR))
		return
	var win := StarShopBuyWindow.new("starshopbuy", {})
	win.setup_buy(shop_mgr, pd, rng, slot, self)
	win.show_window(get_parent())


# 兑换后刷新（buy window 回调）：清行重建（noneTag/价格隐藏/价格色随 fill 恢复）。
func _rebuild() -> void:
	for c in _item_layer.get_children():
		c.free()
	_build_goods()
