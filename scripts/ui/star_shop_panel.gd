class_name StarShopPanel
extends PopWindow

## 星际商店面板（View 层）— 照源 ui/market/shop.lua create("starshop") + createStarList(:512)。
## 5 件灵魂石商品单行布局 + box icon + 灵魂石消耗显示 + 点击弹 StarShopBuyWindow 确认。
## 单机化：源 tavern_draw stone net → ShopManager.buy_star（roll_tavern_loot stone 分支已支持）。
## FCA 开箱 eff_UI_shop_star_box_*.abc Phase 3 骨骼阻塞，PopTavernLoot 自动降级（box 不在 BOX_FCA_MAP 跳过动画）。
##
## 重构（2026-07-18，hero_detail 范式）：chrome（framework bg.jpg + frame + title + close + stone_label
## + scroll）静态化进 scenes/ui/star_shop_content.tscn（位置/size 编辑器可视化调）。商品项 8 节点模板
## 保留 procedural 挂 %ItemLayer（5 件动态装配）。源 cocos(800×480 左下) → Godot(960×640 左上)
## via (cx+80, 560-cy)；CS=1.28125，纹理显示=纹理/CS。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/star_shop_content.tscn")
const CONTENT_SCALE: float = 1.28125   # 源 hello.lua:311 setContentScaleFactor(1.28125)，cocos sprite 显示=纹理/CS（无 fix 时）
const LIST_AREA_SIZE: Vector2 = Vector2(740.0, 350.0)
# 源 createStarList :514-518 ox=90 oy=35 dx=212；item_bg fix_wh 207×286（itemstarshop）
const ITEM_W: float = 207.0
const ITEM_H: float = 287.0
const ITEM_DX: float = 212.0
const ITEM_OX: float = 40.0
const ITEM_OY: float = 30.0
const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
const STAR_BOX_RES: Array[String] = ["shop_star_box_1.png", "shop_star_box_2.png", "shop_star_box_3.png"]
# 源 getStarGoodsName → parameter.lua:36-38 LSTR key（type 0/1/2 → stone_green/blue/purple）
const GOODS_NAME_LSTR: Array[String] = ["PARAMETER.SMALL_PLANET_DEBRIS_BOX", "PARAMETER.MEDIUM_STELLAR_SUITCASE", "PARAMETER.LARGE_INTERSTELLAR_GALLERY"]
# 源 itemstarshop 节点坐标（cocos anchor→Godot 左上，item 207×287）
const ITEM_NAME_POS: Vector2 = Vector2(32.0, 29.0)
const ITEM_NAME_SIZE: Vector2 = Vector2(140.0, 22.0)
const ICON_CONTAINER_POS: Vector2 = Vector2(35.0, 18.0)
const ICON_CONTAINER_SIZE: Vector2 = Vector2(156.0, 156.0)
const COST_TITLE_POS: Vector2 = Vector2(46.0, 188.0)
const COST_TITLE_SIZE: Vector2 = Vector2(114.0, 20.0)
const COST_TITLE_COLOR: Color = Color(150.0 / 255.0, 236.0 / 255.0, 255.0 / 255.0)
const COST_BG_POS: Vector2 = Vector2(45.0, 224.0)
const COST_BG_SIZE: Vector2 = Vector2(135.0, 29.0)
const ITEM_PRESS_POS: Vector2 = Vector2.ZERO
const STONE_CONTAINER_POS: Vector2 = Vector2(26.0, 216.0)
const STONE_CONTAINER_SIZE: Vector2 = Vector2(45.0, 45.0)
const STONE_NAME_POS: Vector2 = Vector2(102.0, 226.0)
const STONE_NAME_COLOR: Color = Color(39.0 / 255.0, 209.0 / 255.0, 232.0 / 255.0)
const NONE_TAG_POS: Vector2 = Vector2.ZERO
const SOLDOUT_OPACITY: float = 0.5

var shop_mgr: ShopManager
var cm: Variant = null
var pd: PlayerData = null
var rng: BattleRng
var _panel_layer: Control
var _item_layer: Control
var _stone_label: Label
var _item_presses: Array = []   # item_press 高亮节点（源 :204 点击 setVisible(true)）


func setup_panel(p_mgr: ShopManager, p_pd: PlayerData, p_rng: BattleRng) -> void:
	shop_mgr = p_mgr
	pd = p_pd
	rng = p_rng
	cm = pd.cm
	setup()
	shop_mgr.open_star_shop()
	# 源 shop.lua create("starshop") pushScene 独立场景（framework.lua:749 自动建全屏 bg.jpg），
	# 本项目单机化 pushScene→PopWindow，故 shade 透明 + .tscn %FrameworkBg 补 bg.jpg 还原源视觉（同 PackagePanel 范式）。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


# 建 UI 内容：chrome 从 .tscn instantiate（位置/size 可视化）；5 件商品项保留 procedural 挂 %ItemLayer。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_panel_layer = content.get_node("%PanelLayer") as Control
	(_panel_layer.get_node("%CloseBtn") as BaseButton).pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")
		remove_window())
	_stone_label = _panel_layer.get_node("%StoneLabel") as Label
	_item_layer = _panel_layer.get_node("%ItemLayer") as Control
	# 源 draglist 横滚（createStarList :519-531 getListWidth dx*len+40）
	_item_layer.custom_minimum_size = Vector2(ITEM_OX * 2.0 + ITEM_DX * 5.0, LIST_AREA_SIZE.y)
	_refresh_stone()
	_build_goods()


func _add_texture(parent: Control, path: String, pos: Vector2, sz: Vector2) -> void:
	if not ResourceLoader.exists(path):
		return
	var tr := TextureRect.new()
	tr.position = pos
	tr.size = sz
	tr.texture = load(path)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parent.add_child(tr)


# 源 createStarList :535-594：5 件商品，每件 container 定位 getItemPos + 填充 8 节点。
func _build_goods() -> void:
	_item_presses.clear()
	var goods: Array = shop_mgr.get_star_goods()
	for i in goods.size():
		var g: Dictionary = goods[i]
		var pos: Vector2 = Vector2(ITEM_OX + ITEM_DX * float(i), ITEM_OY)
		_item_layer.add_child(_create_item(g, i, pos))


# 源 itemstarshop 8 节点模板 + createStarList 填充（item_name/getStarGoodsRes/stone_name/noneTag）。
func _create_item(g: Dictionary, slot: int, pos: Vector2) -> Control:
	var item := Control.new()
	item.position = pos
	item.size = Vector2(ITEM_W, ITEM_H)
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.gui_input.connect(_make_click_handler(slot))
	# 1. item_bg
	_add_texture(item, UI_DIR + "shop_star_item_bg.png", Vector2.ZERO, Vector2(ITEM_W, ITEM_H))
	# 6. item_press 高亮（visible=false 点击 show，源 :204/220/233/259）
	var press := TextureRect.new()
	if ResourceLoader.exists(UI_DIR + "shop_star_item_light.png"):
		press.texture = load(UI_DIR + "shop_star_item_light.png")
	press.position = ITEM_PRESS_POS
	press.size = Vector2(ITEM_W, ITEM_H)
	press.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	press.mouse_filter = Control.MOUSE_FILTER_IGNORE
	press.visible = false
	item.add_child(press)
	_item_presses.append(press)
	# 2. item_name（源 :593 setString getStarGoodsName → LSTR）
	var name_lbl := Label.new()
	name_lbl.text = cm.get_lstr(GOODS_NAME_LSTR[int(g["type"])])
	name_lbl.position = ITEM_NAME_POS
	name_lbl.size = ITEM_NAME_SIZE
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(name_lbl)
	# 3. item_icon_container 装 box icon（源 :559-567 getStarGoodsRes type）
	var icon_container := Control.new()
	icon_container.position = ICON_CONTAINER_POS
	icon_container.size = ICON_CONTAINER_SIZE
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(icon_container)
	_add_texture(icon_container, UI_DIR + STAR_BOX_RES[int(g["type"])], Vector2.ZERO, ICON_CONTAINER_SIZE)
	# 4. cost_title_label（源 :77 LSTR NEED_TO_CONSUME_THE_SOUL_STONE）
	var cost_title := Label.new()
	cost_title.text = cm.get_lstr("ITEMSTARSHOP.NEED_TO_CONSUME_THE_SOUL_STONE")
	cost_title.position = COST_TITLE_POS
	cost_title.size = COST_TITLE_SIZE
	cost_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_title.add_theme_font_size_override("font_size", 19)
	cost_title.modulate = COST_TITLE_COLOR
	cost_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(cost_title)
	# 5. cost_bg（价格背景）
	_add_texture(item, UI_DIR + "shop_star_price_bg.png", COST_BG_POS, COST_BG_SIZE)
	# 7. stone_container（源 :568-576 createIcon(stone_id,46)；Equip 表无灵魂石 8/9/10 → 留空容器照源结构）
	var stone_container := Control.new()
	stone_container.position = STONE_CONTAINER_POS
	stone_container.size = STONE_CONTAINER_SIZE
	stone_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(stone_container)
	# 8. stone_name（"x{amount}" 青色，源 :589-592 setString + ccpAdd(30,0)）
	var stone_name := Label.new()
	stone_name.text = "x" + str(int(g["stone_amount"]))
	stone_name.position = STONE_NAME_POS
	stone_name.add_theme_font_size_override("font_size", 19)
	stone_name.modulate = STONE_NAME_COLOR
	stone_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(stone_name)
	# noneTag 售罄图（源 :577-588 noneTagRes visible=amount<1）
	if int(g.get("amount", 0)) < 1:
		_add_none_tag(item)
		item.modulate.a = SOLDOUT_OPACITY
	return item


func _add_none_tag(parent: Control) -> void:
	if not ResourceLoader.exists(UI_DIR + "shop_star_none_tag.png"):
		return
	var none_tag := TextureRect.new()
	var tag_tex: Texture2D = load(UI_DIR + "shop_star_none_tag.png")
	none_tag.texture = tag_tex
	none_tag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	none_tag.size = tag_tex.get_size() / CONTENT_SCALE   # 源 shop.lua:577-588 noneTag t="Sprite" 无 fix
	none_tag.position = NONE_TAG_POS
	none_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(none_tag)


func _make_click_handler(slot: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			# 源 :204 item_press:setVisible(true) 按压高亮
			if slot < _item_presses.size() and is_instance_valid(_item_presses[slot]):
				(_item_presses[slot] as TextureRect).visible = true
			_open_buy_window(slot)


# 源 doClickInProduct stone 分支(:258-273) → 弹 starshopbuywindow。
func _open_buy_window(slot: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var goods: Array = shop_mgr.get_star_goods()
	if slot >= goods.size():
		return
	if int(goods[slot].get("amount", 0)) <= 0:
		Toast.show_message("已售罄")
		return
	var win := StarShopBuyWindow.new("starshopbuy", {})
	win.setup_buy(shop_mgr, pd, rng, slot, self)
	win.show_window(get_parent())


func _refresh_stone() -> void:
	# 灵魂石 id 8/9/10（源 generateStarGoods stoneIds；本项目 Equip 无定义，items 通用背包存）
	var s_green: int = int(pd.items.get(ShopManager.STAR_STONE_IDS[0], 0))
	var s_blue: int = int(pd.items.get(ShopManager.STAR_STONE_IDS[1], 0))
	var s_purple: int = int(pd.items.get(ShopManager.STAR_STONE_IDS[2], 0))
	_stone_label.text = "灵魂石 绿:%d 蓝:%d 紫:%d" % [s_green, s_blue, s_purple]


func _rebuild() -> void:
	for c in _item_layer.get_children():
		c.free()
	_build_goods()
	_refresh_stone()
