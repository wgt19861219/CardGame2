class_name ShopPanel
extends PopWindow

## 商店主面板（View 层）— 照源 ui/market/shop.lua create(764-917) + createCommon(325-510)。
## 底框 + NPC 头像 + 标题 + 刷新按钮 + 商品列表（两行三列 getItemPos）+ 购买闭环。
## 单机化：源 net shop_* → ShopManager Logic；NPC 对话 + 自动刷新时刻照源实现（热门标签暂不实现）。
## 坐标参考源 cocos 相对关系重新定位（Godot 左上原点）；标题/售罄图缺 → Label 降级（项目范式）。

const PANEL_POS: Vector2 = Vector2(80.0, 80.0)
const PANEL_SIZE: Vector2 = Vector2(800.0, 480.0)
const HEAD_POS: Vector2 = Vector2(40.0, 270.0)
const HEAD_SIZE: Vector2 = Vector2(180.0, 200.0)
const TITLE_POS: Vector2 = Vector2(350.0, 18.0)
const TITLE_FONT_SIZE: int = 24
const CLOSE_BTN_POS: Vector2 = Vector2(20.0, 15.0)  # 左上角留小边（用户偏好更靠左上角）
const CLOSE_BTN_SIZE: Vector2 = Vector2(40.0, 32.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
const REFRESH_BTN_POS: Vector2 = Vector2(590.0, 20.0)
const REFRESH_BTN_SIZE: Vector2 = Vector2(140.0, 32.0)
# 源 shop.lua:884/895 refresh 按钮 shop_refresh_button.png + shop_refresh_button_down.png。
const REFRESH_BTN_RES: String = "res://assets/ui/alpha/HVGA/shop_refresh_button.png"
const REFRESH_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/shop_refresh_button_down.png"
const MONEY_LABEL_POS: Vector2 = Vector2(40.0, 25.0)
const LIST_ORIGIN: Vector2 = Vector2(260.0, 110.0)
const LIST_CELL: Vector2 = Vector2(170.0, 165.0)
const LIST_COLS: int = 3
const ITEM_SIZE: Vector2 = Vector2(160.0, 150.0)
const ITEM_ICON_POS: Vector2 = Vector2(44.0, 12.0)
const ITEM_NAME_POS: Vector2 = Vector2(10.0, 95.0)
const ITEM_COIN_POS: Vector2 = Vector2(30.0, 120.0)
const ITEM_COIN_SIZE: Vector2 = Vector2(24.0, 24.0)
const ITEM_PRICE_POS: Vector2 = Vector2(70.0, 120.0)
const ITEM_SOLDOUT_POS: Vector2 = Vector2(55.0, 60.0)
const SOLDOUT_OPACITY: float = 0.5   # 源 :108 setOpacity(120/255≈0.47)
const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
const UNKNOWN_NAME: String = "???"
const AUTO_REFRESH_CHECK_INTERVAL: float = 1.0   # _process 自动刷新轮询间隔（秒，源客户端 auto_refresh 轮询）

var shop_id: int = 1
var shop_mgr: ShopManager
var cm: Variant = null
var pd: PlayerData = null
var rng: BattleRng
var _config: Dictionary = {}
var _panel: Control
var _item_layer: Control
var _money_label: Label
var _refresh_btn: TextureButton
var _refresh_cost_label: Label       # 源按钮附近 cost 显示（shop_refresh_cost_bg + 价格）
var _talk_label: Label             # NPC 对话气泡（照源 shop.lua:19 showTalk）
var _next_refresh_label: Label     # 下次自动刷新时刻（照源 getShopNextAutoRefreshPointDesc）
var _talk_tween: Tween = null      # 对话淡出动画（doSpeak 范式）
var _head_touch: Control           # NPC 头像触摸层（点头像→Touch，源 shop.lua:940 head_button）
var _auto_refresh_accum: float = 0.0   # _process 自动刷新轮询累加器


func setup_panel(p_shop_id: int, p_mgr: ShopManager, p_pd: PlayerData, p_rng: BattleRng) -> void:
	shop_id = p_shop_id
	shop_mgr = p_mgr
	pd = p_pd
	rng = p_rng
	cm = pd.cm
	_config = MarketConfig.get_type_config(shop_id)
	setup()
	shop_mgr.open_shop(shop_id, rng, cm)
	shop_mgr.init_auto_refresh(shop_id, pd, _now())         # 源 local_server:1219 open_shop 设 _last_auto_refresh_time
	shop_mgr.init_expire(shop_id, pd, _now())               # 源 local_server:1316 open_shop 设 _expire_time（地精/黑市停留计时）
	shop_mgr.check_auto_refresh(shop_id, pd, _now(), rng)   # 源 up.proto:260 到点 auto_refresh 触发
	_build_ui()
	register_on_enter(func() -> void:
		AudioPlayer.play_sfx("common_popup_window")
		_show_talk("Welcome"))   # 源 shop.lua:920 进店 Welcome（进场后触发，已入树）


func _build_ui() -> void:
	_panel = Control.new()
	_panel.position = PANEL_POS
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(_panel)
	_add_texture(_panel, UI_DIR + String(_config["frameRes"]), Vector2.ZERO, PANEL_SIZE)
	_add_texture(_panel, UI_DIR + String(_config["headRes"]), HEAD_POS, HEAD_SIZE)
	_add_title()
	_add_close_button()
	_add_refresh_button()
	_money_label = Label.new()
	_money_label.position = MONEY_LABEL_POS
	_panel.add_child(_money_label)
	_item_layer = Control.new()
	_item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_item_layer)
	_refresh_money()
	_build_goods()
	_add_npc_area()
	_add_next_refresh_label()


func _add_texture(parent: Control, path: String, pos: Vector2, sz: Vector2) -> void:
	if not ResourceLoader.exists(path):
		return
	var tr := TextureRect.new()
	tr.position = pos
	tr.size = sz
	tr.texture = load(path)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)


func _add_title() -> void:
	# 源 shop_title_1/2/3.png 缺 → Label 降级（项目资源缺图范式）
	var lbl := Label.new()
	lbl.text = String(_config["titleText"])
	lbl.position = TITLE_POS
	lbl.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_panel.add_child(lbl)


func _add_close_button() -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_BTN_POS)
	btn.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")   # 源 closeWindow
		remove_window())
	_panel.add_child(btn)


# 源 shop.lua:878-916 refresh 按钮：shop_refresh_button.png 贴图 + 中心 "刷新" Label（:905 硬编码字面量，
# 源未 LSTR 化）。cost 在按钮上方独立 Label（源 shop_refresh_cost_bg + 价格，:884 附近）。
func _add_refresh_button() -> void:
	_refresh_btn = TextureButton.new()
	_refresh_btn.texture_normal = load(REFRESH_BTN_RES) as Texture2D
	_refresh_btn.texture_pressed = load(REFRESH_BTN_PRESS_RES) as Texture2D
	_refresh_btn.ignore_texture_size = true
	_refresh_btn.position = REFRESH_BTN_POS
	_refresh_btn.size = REFRESH_BTN_SIZE
	_refresh_btn.pressed.connect(_on_refresh)
	_panel.add_child(_refresh_btn)
	var lbl := Label.new()
	lbl.text = "刷新"   # 源 :905 硬编码 "刷新"（非 LSTR）
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_btn.add_child(lbl)
	_refresh_cost_label = Label.new()
	_refresh_cost_label.position = Vector2(REFRESH_BTN_POS.x, REFRESH_BTN_POS.y - 18.0)
	_refresh_cost_label.add_theme_font_size_override("font_size", 14)
	_refresh_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_refresh_cost_label)
	_update_refresh_label()


func _update_refresh_label() -> void:
	var cost: int = shop_mgr.get_refresh_cost(shop_id, cm)
	# cost 显示在按钮上方 Label（源按钮本身只显"刷新"，cost 在 confirm dialog SPEND_XXX_TO_REFRESH 内）。
	_refresh_cost_label.text = "%d钻" % cost


# 源 createCommon：两行三列商品列表（getItemPos :371-382 两行布局）。
func _build_goods() -> void:
	var goods: Array = shop_mgr.get_goods(shop_id)
	for i in goods.size():
		var g: Dictionary = goods[i]
		var col: int = i % LIST_COLS
		var row: int = i / LIST_COLS
		var pos: Vector2 = Vector2(LIST_ORIGIN.x + col * LIST_CELL.x, LIST_ORIGIN.y + row * LIST_CELL.y)
		_item_layer.add_child(_create_item(g, i, pos))


# 源 createCommon item：panel(productBgRes) + icon(createIconWithAmount) + name + coinIcon + costLabel + noneTag。
func _create_item(g: Dictionary, slot: int, pos: Vector2) -> Control:
	var item := Control.new()
	item.position = pos
	item.size = ITEM_SIZE
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.gui_input.connect(_make_buy_handler(slot))
	_add_texture(item, UI_DIR + String(_config["productBgRes"]), Vector2.ZERO, ITEM_SIZE)
	var equip_row: Dictionary = cm.get_raw_table(&"Equip").get(str(g["id"]), {})
	var icon: Control = ReadequipIcon.create_icon(int(g["id"]), int(g.get("amount", 1)), cm)
	icon.position = ITEM_ICON_POS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = cm.get_lstr(String(equip_row.get("Name", UNKNOWN_NAME)))   # 源 T(LSTR(Equip.Name)) 中文化
	name_lbl.position = ITEM_NAME_POS
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(name_lbl)
	_add_texture(item, UI_DIR + MarketConfig.get_coin_res(String(g["type"])), ITEM_COIN_POS, ITEM_COIN_SIZE)
	var price_lbl := Label.new()
	price_lbl.text = str(int(g["price"]))
	price_lbl.position = ITEM_PRICE_POS
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(price_lbl)
	if int(g.get("amount", 0)) <= 0:
		var sold := Label.new()
		sold.text = "售罄"   # 源 :110/491 noneTag 贴图（noneTagRes），无 LSTR → Label 降级
		sold.position = ITEM_SOLDOUT_POS
		sold.modulate = Color.RED
		sold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(sold)
		item.modulate.a = SOLDOUT_OPACITY   # 源 :108 panel:setOpacity(120)
	return item


func _make_buy_handler(slot: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_on_buy(slot)


# 源 doClickInProduct + shop_consume + buyReply。
func _on_buy(slot: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var ok: bool = shop_mgr.buy(shop_id, slot, pd, cm)
	if ok:
		Toast.show_message("购买成功")   # 源 shop.lua:122 硬编码字面量（非 LSTR）
		_show_talk("Purchase")   # 源 shop.lua:130 购买后对话
	else:
		# 照源 buy 失败区分：slot 越界 / amount<=0 → 售罄；否则货币不足。
		var goods: Array = shop_mgr.get_goods(shop_id)
		var sold_out: bool = true
		if slot >= 0 and slot < goods.size():
			var g: Dictionary = goods[slot]
			sold_out = int(g.get("amount", 0)) <= 0
		if sold_out:
			_show_talk("Soldout")   # 源 shop.lua:246 点售罄商品
		# 源 shop.lua:173/175 "金币不足"/"钻石不足" 硬编码字面量；interfax/gladiator 才走 LSTR（本项目统一降级字面量）。
		Toast.show_message("已售罄" if sold_out else "货币不足")
	call_deferred("_rebuild")


# 源 doClickRefresh + shop_refresh（:302-313）。P1-8 照源 showConfirmDialog → 独立 ShopRefreshConfirm。
func _on_refresh() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var cost: int = shop_mgr.get_refresh_cost(shop_id, cm)
	if pd.diamond < cost:
		Toast.show_message("钻石不足（需 %d）" % cost)
		return
	# 源 :307-308 SHOP.SPEND_XXX_TO_REFRESH（3 参：cost/coinname/refreshshoptimes）。
	# coinname 源 config.getRefreshCoinName 返 i18n 货币名，本项目降级"钻石"字面量（无对应货币名 LSTR key）。
	# refreshshoptimes 源 getRefreshShopTimes 返剩余次数，本项目 get_refresh_times 返已用次数（无刷新上限，语义差异）。
	var coinname: String = "钻石"
	var times: int = shop_mgr.get_refresh_times(shop_id)
	var popup := ShopRefreshConfirm.new()
	popup.set_message(cm.get_lstr("SHOP.SPEND_XXX_TO_REFRESH") % [cost, coinname, times], cm)
	popup.confirmed.connect(_on_refresh_confirmed)
	container.add_child(popup)


# 源 :309 rightHandler（确认框确认）→ doSendRefresh。
func _on_refresh_confirmed() -> void:
	if shop_mgr.refresh(shop_id, pd, rng, cm):
		Toast.show_message("刷新成功")
		_show_talk("Refresh")   # 源 shop.lua:281 手动刷新对话
	else:
		Toast.show_message("钻石不足")
	call_deferred("_rebuild")


func _rebuild() -> void:
	for c in _item_layer.get_children():
		c.free()
	_build_goods()
	_update_refresh_label()
	_update_next_refresh_label()
	_refresh_money()


func _refresh_money() -> void:
	_money_label.text = "金币:%d 钻石:%d" % [pd.hero_manager.gold, pd.diamond]


func _now() -> int:
	return int(Time.get_unix_time_from_system())


# 源 shop.lua:19-73 showTalk：getTalkContent 选词 + 显示气泡 + 淡出（doSpeak 范式）。无台词静默。
func _show_talk(key: String) -> void:
	var ttype: String = shop_mgr.get_time_type(shop_id, pd, _now())
	var text: String = MerchantTalkData.get_talk_content(shop_id, key, ttype, rng, cm)
	if text == "":
		return
	if _talk_tween and _talk_tween.is_valid():
		_talk_tween.kill()
	_talk_label.text = text
	_talk_label.modulate.a = 1.0
	if is_inside_tree():   # 未入树（setup 早期）只显示不动画，避 create_tween 失效
		_talk_tween = create_tween()
		_talk_tween.tween_interval(2.5)
		_talk_tween.tween_property(_talk_label, "modulate:a", 0.0, 0.8)


# 源 shop.lua:940 head_button（点头像→Touch）+ 头顶对话气泡（skill_talk_bg 缺→Label 降级，项目范式）。
func _add_npc_area() -> void:
	_head_touch = Control.new()
	_head_touch.position = HEAD_POS
	_head_touch.size = HEAD_SIZE
	_head_touch.mouse_filter = Control.MOUSE_FILTER_STOP
	_head_touch.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_show_talk("Touch"))
	_panel.add_child(_head_touch)
	_talk_label = Label.new()
	_talk_label.position = Vector2(HEAD_POS.x - 20.0, HEAD_POS.y - 50.0)
	_talk_label.size = Vector2(HEAD_SIZE.x + 220.0, 40.0)
	_talk_label.add_theme_font_size_override("font_size", 16)
	_talk_label.modulate.a = 0.0
	_talk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_talk_label)


# 下次自动刷新时刻（源 getShopNextAutoRefreshPointDesc），刷新按钮下方 Label。无自动刷新则空。
func _add_next_refresh_label() -> void:
	_next_refresh_label = Label.new()
	_next_refresh_label.position = Vector2(REFRESH_BTN_POS.x, REFRESH_BTN_POS.y + REFRESH_BTN_SIZE.y + 4.0)
	_next_refresh_label.add_theme_font_size_override("font_size", 13)
	_next_refresh_label.modulate = Color(0.9, 0.85, 0.6)
	_next_refresh_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_next_refresh_label)
	_update_next_refresh_label()


# 更新时刻文字（setup + _rebuild + _process 每秒共用）。expire 态显停留倒计时（源 :757 SHOP.MERCHANT_LEAVES_AFTER），
# 否则显下次刷新时刻（源 :751 SHOP.NEXT_AUTOMATICALLY_REFRESH_TIME）。两者皆空则 Label 清空。
func _update_next_refresh_label() -> void:
	var tt: String = shop_mgr.get_time_type(shop_id, pd, _now())
	if tt == "expire":
		# 源 :757-758 SHOP.MERCHANT_LEAVES_AFTER(商人将于) + time + SHOP.TIMES(后离开)。
		var exp: String = shop_mgr.get_expire_desc(shop_id, pd, _now())
		if exp == "":
			_next_refresh_label.text = ""
		else:
			_next_refresh_label.text = cm.get_lstr("SHOP.MERCHANT_LEAVES_AFTER") + " " + exp + " " + cm.get_lstr("SHOP.TIMES")
		return
	var desc: String = shop_mgr.get_next_refresh_desc(shop_id, pd, _now())
	_next_refresh_label.text = cm.get_lstr("SHOP.NEXT_AUTOMATICALLY_REFRESH_TIME") + desc if desc != "" else ""


# 运行中轮询（源 shop.lua timeRefresh:648-698 每秒）：① 到期检查（地精/黑市停留 3600s）② 自动刷新（Refresh Times 点）③ 时刻 Label 刷新。
func _process(delta: float) -> void:
	_auto_refresh_accum += delta
	if _auto_refresh_accum < AUTO_REFRESH_CHECK_INTERVAL:
		return
	_auto_refresh_accum = 0.0
	# 源 shop.lua:686-694 tc<0 and state=="expire" → showTalk(Expire)+alertDialog+popScene+停 update
	if shop_mgr.check_expire(shop_id, pd, _now()):
		_on_expire()
		return
	if shop_mgr.check_auto_refresh(shop_id, pd, _now(), rng):
		_rebuild()
		_show_talk("Refresh")
	_update_next_refresh_label()   # 源 :662 每秒 setString（expire 倒计时 / refresh 描述）


# 源 shop.lua:686-694 到期：showTalk(Expire) + alertDialog("神秘商人已漂走") + popScene。
# 单机化：Toast 替 alertDialog + remove_window + clear_expire（常驻按钮再点重计，源 NPC 消失等价）。
func _on_expire() -> void:
	_show_talk("Expire")
	Toast.show_message(cm.get_lstr("SHOP.THE_MYSTERIOUS_BUSINESSMAN_HAS_DRIFTED_AWAY_PLEASE_BE_QUICK_NEXT_TIME"))
	shop_mgr.clear_expire(shop_id, pd)
	call_deferred("remove_window")
